import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_filex/open_filex.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('tr_TR', null);
  
  runApp(const PalletApp());
}

// ---------------------------------------------------------------------------
// 1. THEME & COLORS
// ---------------------------------------------------------------------------
class AppColors {
  static const Color primary = Color(0xFF007AFF); 
  static const Color secondary = Color(0xFF5856D6); 
  static const Color background = Color(0xFFF2F2F7); 
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF1C1C1E);
  static const Color textDim = Color(0xFF8E8E93);
  static const Color danger = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  
  static const Color wood = Color(0xFF8D6E63);
  static const Color woodLight = Color(0xFFD7CCC8);
  static const Color plastic = Color(0xFF039BE5);
  static const Color plasticLight = Color(0xFFB3E5FC);
}

// ---------------------------------------------------------------------------
// 2. MODELS
// ---------------------------------------------------------------------------
class PalletRecord {
  final String localId;
  final String displayId; 
  final String firmName;
  final String palletType;
  final int boxCount;
  final String vehiclePlate;
  final String entryDate;
  final String note;
  final String status; 
  int isSynced; 

  PalletRecord({
    required this.localId,
    required this.displayId,
    required this.firmName,
    required this.palletType,
    required this.boxCount,
    required this.vehiclePlate,
    required this.entryDate,
    this.note = '',
    this.status = 'IN_STOCK',
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'display_id': displayId,
      'firm_name': firmName,
      'pallet_type': palletType,
      'box_count': boxCount,
      'vehicle_plate': vehiclePlate,
      'entry_date': entryDate,
      'note': note,
      'status': status,
      'is_synced': isSynced,
    };
  }

  factory PalletRecord.fromMap(Map<String, dynamic> map) {
    return PalletRecord(
      localId: map['local_id'],
      displayId: map['display_id'] ?? 'N/A',
      firmName: map['firm_name'],
      palletType: map['pallet_type'],
      boxCount: map['box_count'],
      vehiclePlate: map['vehicle_plate'],
      entryDate: map['entry_date'],
      note: map['note'] ?? '',
      status: map['status'] ?? 'IN_STOCK',
      isSynced: map['is_synced'] ?? 0,
    );
  }

  PalletRecord copyWith({
    String? firmName,
    String? palletType,
    int? boxCount,
    String? vehiclePlate,
    String? entryDate,
    String? note,
  }) {
    return PalletRecord(
      localId: localId,
      displayId: displayId,
      firmName: firmName ?? this.firmName,
      palletType: palletType ?? this.palletType,
      boxCount: boxCount ?? this.boxCount,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      entryDate: entryDate ?? this.entryDate,
      note: note ?? this.note,
      status: status,
      isSynced: 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. DATABASE HELPER
// ---------------------------------------------------------------------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('palet_v4.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = p.join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pallets (
        local_id TEXT PRIMARY KEY,
        display_id TEXT,
        firm_name TEXT NOT NULL,
        pallet_type TEXT NOT NULL,
        box_count INTEGER,
        vehicle_plate TEXT,
        entry_date TEXT,
        note TEXT,
        status TEXT DEFAULT 'IN_STOCK',
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> create(PalletRecord record) async {
    final db = await instance.database;
    return await db.insert('pallets', record.toMap());
  }

  Future<List<PalletRecord>> getAll() async {
    final db = await instance.database;
    final result = await db.query('pallets', orderBy: "local_id DESC");
    return result.map((json) => PalletRecord.fromMap(json)).toList();
  }

  Future<List<PalletRecord>> getRecordsByDate(String date) async {
    final db = await instance.database;
    // We want records entered ON this date OR returned ON this date
    // Current schema: entry_date is YYYY-MM-DD. 
    // Returned items have status='RETURNED' and note starts with YYYY-MM-DD.
    final result = await db.query('pallets', 
      where: 'entry_date = ? OR (status = ? AND note LIKE ?)', 
      whereArgs: [date, 'RETURNED', '$date%'], 
      orderBy: "local_id DESC"
    );
    return result.map((json) => PalletRecord.fromMap(json)).toList();
  }

  Future<List<PalletRecord>> getRecents({int limit = 5}) async {
    final db = await instance.database;
    final result = await db.query('pallets', orderBy: "display_id DESC", limit: limit);
    return result.map((json) => PalletRecord.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getStats(String date) async {
    final db = await instance.database;
    // Boxes (Sum of box_count for entries on this date)
    final totalBoxes = Sqflite.firstIntValue(await db.rawQuery("SELECT SUM(box_count) FROM pallets WHERE entry_date = ?", [date])) ?? 0;
    
    // Pallets breakdown
    final plastic = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM pallets WHERE entry_date = ? AND pallet_type = 'Plastik'", [date])) ?? 0;
    final wood = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM pallets WHERE entry_date = ? AND pallet_type = 'Tahta'", [date])) ?? 0;

    return {
      'plastic': plastic,
      'wood': wood,
      'boxes': totalBoxes
    };
  }

  Future<String> generateNextId(DateTime date) async {
    final db = await instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final datePart = DateFormat('yyyyMMdd').format(date);
    
    final result = await db.rawQuery(
      "SELECT display_id FROM pallets WHERE entry_date = ? AND display_id LIKE 'PLT-$datePart-%'", 
      [dateStr]
    );

    int maxSeq = 0;
    for (var row in result) {
      final id = row['display_id'] as String;
      final parts = id.split('-');
      if (parts.length == 3) {
        final seq = int.tryParse(parts[2]) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }

    final nextSeq = (maxSeq + 1).toString().padLeft(4, '0');
    return 'PLT-$datePart-$nextSeq';
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete('pallets', where: 'local_id = ?', whereArgs: [id]);
  }

  Future<int> update(PalletRecord record) async {
    final db = await instance.database;
    return await db.update('pallets', record.toMap(), where: 'local_id = ?', whereArgs: [record.localId]);
  }

  Future<int> getTotalStock() async {
    final db = await instance.database;
    final entries = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM pallets WHERE status = 'IN_STOCK'")) ?? 0;
    final returns = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM pallets WHERE status = 'RETURNED'")) ?? 0;
    return entries - returns;
  }

  Future<String> processReturn(String type, int count, String date, String info) async {
    final db = await instance.database;
    final id = await generateNextId(DateTime.now()); 
    
    final batch = db.batch();
    for (int i = 0; i < count; i++) {
        final record = PalletRecord(
          localId: const Uuid().v4(),
          displayId: '$id-${i+1}', 
          firmName: 'BEYPILIC', 
          palletType: type,
          boxCount: 0, 
          vehiclePlate: '', 
          entryDate: date, 
          status: 'RETURNED',
          isSynced: 0,
          note: info,
        );
        batch.insert('pallets', record.toMap());
    }
    await batch.commit();
    return 'OK'; // UI expects 'OK'
  }

  Future<void> seedDummyData() async {
     final dates = ['2025-12-12', '2025-12-14', '2025-12-15'];
     final firms = ['BEYPILIC', 'ER-PILIC', 'SENPILIC', 'KOY-TAV', 'GEDIK'];
     final types = ['Tahta', 'Plastik'];

     for (var date in dates) {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
        for (var i = 0; i < 5; i++) {
           final firm = firms[i % firms.length];
           final type = types[i % 2];
           final boxes = (i + 1) * 20 + 20;
           
           final count = (await getRecordsByDate(date)).length;
           final nextSeq = (count + 1 + i).toString().padLeft(4, '0');
           final dateId = DateFormat('yyyyMMdd').format(parsedDate);
           final id = 'PLT-$dateId-$nextSeq';
           
           final record = PalletRecord(
              localId: const Uuid().v4(),
              displayId: id,
              firmName: firm,
              palletType: type,
              boxCount: boxes,
              vehiclePlate: '34 DUMMY ${10+i}',
              entryDate: date,
              status: 'IN_STOCK', // Dummy entries should be IN_STOCK
              isSynced: 0,
              note: 'Dummy Data',
           );
           await create(record);
        }
     }


  }

  Future<void> deleteAll() async {
    final db = await instance.database;
    await db.delete('pallets');
  }
}

// ---------------------------------------------------------------------------
// 4. MAIN APP & HELPERS
// ---------------------------------------------------------------------------
class PalletApp extends StatelessWidget {
  const PalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atılım Gıda Palet Takip',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
        brightness: Brightness.light, 
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          )
        )
      ),
      home: const DashboardScreen(),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ---------------------------------------------------------------------------
// 5. DASHBOARD SCREEN
// ---------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _plateController = TextEditingController(); 
  
  Map<String, dynamic> stats = {'wood': 0, 'plastic': 0, 'boxes': 0};
  int _totalStock = 0;
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final s = await DatabaseHelper.instance.getStats(_today);
    final stock = await DatabaseHelper.instance.getTotalStock();
    setState(() {
      stats = s;
      _totalStock = stock;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        centerTitle: false,
        actions: [],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Stats Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF00C6FF)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    const Text('TOPLAM ELDE KALAN PALET', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                    Text('$_totalStock', style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                       decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), 
                       child: Text(
                         'Bugün: ${stats['plastic']} Plastik / ${stats['wood']} Tahta - ${stats['boxes']} Koli', 
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                       )
                     )
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('Hızlı İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // Menu Grid
              Row(
                children: [
                  Expanded(child: _buildMenuCard('Günlük Sayım', Icons.add_circle, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(plateController: _plateController)))
                        .then((_) => _loadStats());
                  })),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMenuCard('Raporlar', Icons.bar_chart, Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(plateController: _plateController)))
                      .then((_) => _loadStats());
                  })),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMenuCard('Palet İade', Icons.assignment_return, Colors.orange, () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnScreen()))
                      .then((_) => _loadStats());
                  })),
                  const SizedBox(width: 16),
                   Expanded(child: _buildMenuCard('Kayıtlı Raporlar', Icons.folder_special, Colors.teal, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedReportsScreen()));
                  })),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. ENTRY SCREEN ("Günlük Sayım")
// ---------------------------------------------------------------------------
class EntryScreen extends StatefulWidget {
  final TextEditingController plateController;
  final PalletRecord? editingRecord; 

  const EntryScreen({super.key, required this.plateController, this.editingRecord});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'Tahta'; 
  String _selectedFirm = '';
  int _boxCount = 1;
  bool _isLoading = false;
  late TextEditingController _boxCountController;
  late TextEditingController _firmController; // Custom firm input
  List<PalletRecord> _recents = [];

  final List<Map<String, dynamic>> firms = const [
    {'name': 'BEYPILIC', 'logo': 'assets/images/ic_beypilic.png'},
    {'name': 'METRO', 'logo': 'assets/images/ic_metro.png'},
    {'name': 'POPEYES', 'logo': 'assets/images/ic_popeyes.png'},
    {'name': 'DİĞER', 'icon': Icons.category}, 
  ];

  @override
  void initState() {
    super.initState();
    _firmController = TextEditingController();

    if (widget.editingRecord != null) {
      try {
        _selectedDate = DateTime.parse(widget.editingRecord!.entryDate);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
      _boxCount = widget.editingRecord!.boxCount;
      _selectedType = widget.editingRecord!.palletType;
      
      // Check if firm is one of the predefined ones
      final dbFirm = widget.editingRecord!.firmName;
      final isPredefined = firms.any((f) => f['name'] == dbFirm && f['name'] != 'DİĞER');
      
      if (isPredefined) {
        _selectedFirm = dbFirm;
      } else {
        _selectedFirm = 'DİĞER';
        _firmController.text = dbFirm;
      }

      widget.plateController.text = widget.editingRecord!.vehiclePlate; 
    } else {
       if (firms.isNotEmpty) _selectedFirm = firms.first['name'] as String;
    }
    _boxCountController = TextEditingController(text: _boxCount.toString());
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    if (widget.editingRecord != null) return;
    final data = await DatabaseHelper.instance.getRecents();
    setState(() => _recents = data);
  }

  @override
  void dispose() {
    _boxCountController.dispose();
    _firmController.dispose();
    super.dispose();
  }

  void _updateBoxCount(int newValue) {
    if (newValue < 1) return;
    setState(() {
      _boxCount = newValue;
      _boxCountController.text = _boxCount.toString();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _delete(String id) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sil?'),
      content: const Text('Kayıt silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL', style: TextStyle(color: Colors.red))),
      ],
    ));
    
    if (confirm == true) {
      await DatabaseHelper.instance.delete(id);
      _loadRecents();
    }
  }

  Future<void> _save() async {
    if (widget.plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen Plaka Giriniz')));
      return;
    }
    
    final currentBox = int.tryParse(_boxCountController.text) ?? _boxCount;
    if (currentBox < 1) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koli sayısı en az 1 olmalı')));
       return;
    }

    // Determine Firm Name
    String finalFirmName = _selectedFirm;
    if (_selectedFirm == 'DİĞER') {
      finalFirmName = _firmController.text.trim();
      if (finalFirmName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen Firma Adı Giriniz')));
        return;
      }
    }

    setState(() => _isLoading = true);
    
    // UPDATE
    if (widget.editingRecord != null) {
       final updated = widget.editingRecord!.copyWith(
          firmName: finalFirmName, // Use resolved name
          palletType: _selectedType,
          boxCount: currentBox,
          vehiclePlate: widget.plateController.text.toUpperCase(),
          entryDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
       );
       await DatabaseHelper.instance.update(updated);
       
       if (!mounted) return;
       Navigator.pop(context); 
       return;
    }

    // CREATE
    final nextId = await DatabaseHelper.instance.generateNextId(_selectedDate);

    final record = PalletRecord(
      localId: const Uuid().v4(),
      displayId: nextId,
      firmName: finalFirmName.toUpperCase(), // Auto Uppercase for custom
      palletType: _selectedType,
      boxCount: currentBox,
      vehiclePlate: widget.plateController.text.toUpperCase(),
      entryDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      status: 'IN_STOCK',
    );

    await DatabaseHelper.instance.create(record);
    
    await Future.delayed(const Duration(milliseconds: 300));
    _loadRecents();

    if (!mounted) return;
    setState(() => _isLoading = false);
    _firmController.clear(); // Clear custom firm input

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('$nextId kaydedildi!'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingRecord != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Kayıt Düzenle' : 'Günlük Sayım')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // ROW: DATE & PLATE
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // DATE
                   Expanded(
                     flex: 4,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildSectionTitle('TARİH'),
                         InkWell(
                           onTap: _pickDate,
                           child: Container(
                             height: 56,
                             padding: const EdgeInsets.symmetric(horizontal: 12),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: Colors.grey.shade300)
                             ),
                             child: Row(
                               children: [
                                 const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                                 const SizedBox(width: 8),
                                 Expanded(child: Text(DateFormat('dd.MM.yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold))),
                               ],
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(width: 12),
                   // PLATE
                   Expanded(
                     flex: 6,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildSectionTitle('PLAKA'),
                         TextField(
                           controller: widget.plateController,
                           textCapitalization: TextCapitalization.characters,
                           inputFormatters: [UpperCaseTextFormatter()],
                           style: const TextStyle(fontWeight: FontWeight.bold),
                           decoration: InputDecoration(
                             hintText: '34AB123',
                             filled: true, fillColor: Colors.white,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
              const SizedBox(height: 20),

              // PALLET TYPE
              _buildSectionTitle('PALET TİPİ'),
              Row(
                children: [
                  Expanded(child: _buildTypeOption('Tahta', AppColors.wood, AppColors.woodLight)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTypeOption('Plastik', AppColors.plastic, AppColors.plasticLight)),
                ],
              ),
              const SizedBox(height: 20),

              // BOX COUNT
              _buildSectionTitle('KOLİ ADEDİ'),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _counterButton(Icons.remove, () => _updateBoxCount(_boxCount - 1)),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          Container(
                            width: 120,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _boxCountController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text),
                              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                              onChanged: (val) {
                                final v = int.tryParse(val);
                                if (v != null) setState(() => _boxCount = v);
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Koli', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      _counterButton(Icons.add, () => _updateBoxCount(_boxCount + 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _quickAddBtn(10),
                      _quickAddBtn(25),
                      _quickAddBtn(50),
                      _quickAddBtn(100),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // FIRMS GRID
              _buildSectionTitle('FİRMA'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: firms.length,
                itemBuilder: (ctx, index) {
                   final f = firms[index];
                   final isSelected = _selectedFirm == f['name'];
                   return InkWell(
                     onTap: () => setState(() => _selectedFirm = f['name'] as String),
                     child: Container(
                       decoration: BoxDecoration(
                         color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                         border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: 2),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       alignment: Alignment.center,
                       child: f['logo'] != null 
                           ? Padding(
                               padding: const EdgeInsets.all(12.0),
                               child: Image.asset(f['logo'] as String, fit: BoxFit.contain),
                             )
                           : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                               Icon(f['icon'] as IconData, size: 24, color: isSelected ? AppColors.primary : AppColors.textDim),
                               const SizedBox(width: 8),
                               Flexible(child: Text(f['name'] as String, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textDim)))
                             ]),
                     ),
                   );
                },
              ),
              
              // CUSTOM FIRM INPUT
              if (_selectedFirm == 'DİĞER') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _firmController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: InputDecoration(
                     labelText: 'Firma Adını Giriniz',
                     labelStyle: const TextStyle(color: AppColors.primary),
                     filled: true, fillColor: Colors.white,
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                     focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                     prefixIcon: const Icon(Icons.edit, color: AppColors.primary),
                  ),
                ),
              ],

              const SizedBox(height: 30),
              
              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isEditing ? Icons.save : Icons.add_circle, size: 28),
                      const SizedBox(width: 10),
                      Text(isEditing ? 'GÜNCELLE' : 'EKLE', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              
              // RECENT RECORDS
              if (!isEditing && _recents.isNotEmpty) ...[
                 const SizedBox(height: 30),
                 const Divider(),
                 _buildSectionTitle('SON İŞLEMLER'),
                 ListView.builder(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: _recents.length,
                   itemBuilder: (ctx, index) {
                     final r = _recents[index];
                     return Card(
                       margin: const EdgeInsets.only(bottom: 8),
                       elevation: 1,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       child: ListTile(
                         dense: true,
                         leading: CircleAvatar(
                            backgroundColor: r.palletType == 'Tahta' ? AppColors.wood : AppColors.plastic,
                            radius: 16,
                            child: Icon(r.palletType == 'Tahta' ? Icons.crop_square : Icons.grid_on, color: Colors.white, size: 16),
                         ),
                         title: Text('${r.displayId} • ${r.firmName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text('${r.boxCount} Koli • ${r.vehiclePlate}'),
                         trailing: PopupMenuButton(
                           padding: EdgeInsets.zero,
                           icon: const Icon(Icons.more_vert),
                           itemBuilder: (ctx) => [
                             const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                             const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                           ],
                           onSelected: (v) {
                             if (v == 'delete') _delete(r.localId);
                             if (v == 'edit') {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(plateController: widget.plateController, editingRecord: r)))
                                 .then((_) => _loadRecents());
                             }
                           },
                         ),
                       ),
                     );
                   },
                 )
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title, style: const TextStyle(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTypeOption(String label, Color color, Color lightColor) {
    final isSelected = _selectedType == label;
    return InkWell(
      onTap: () => setState(() => _selectedType = label),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,4))] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(label == 'Tahta' ? Icons.crop_square : Icons.grid_on, color: isSelected ? Colors.white : color, size: 30),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.text, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(icon, color: AppColors.text, size: 28),
      ),
    );
  }
  
  Widget _quickAddBtn(int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: () => _updateBoxCount(_boxCount + amount),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text('+$amount', style: const TextStyle(color: AppColors.textDim, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. REPORTS SCREEN
// ---------------------------------------------------------------------------
class ReportsScreen extends StatefulWidget {
  final TextEditingController plateController;
  const ReportsScreen({super.key, required this.plateController});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  List<PalletRecord> _allRecords = [];
  bool _showSummary = false;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final list = await DatabaseHelper.instance.getRecordsByDate(dateStr);
    setState(() => _allRecords = list);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _load();
    }
  }

  Future<void> _delete(String id) async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sil?'),
      content: const Text('Bu kayıt kalıcı olarak silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await DatabaseHelper.instance.delete(id);
          _load();
        }, child: const Text('SİL', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
  
  void _edit(PalletRecord record) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(
       plateController: widget.plateController, 
       editingRecord: record
     ))).then((_) => _load());
  }

  Future<void> _savePdf(Uint8List bytes, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory(p.join(dir.path, 'reports'));
      if (!await saveDir.exists()) await saveDir.create(recursive: true);
      
      final file = File(p.join(saveDir.path, fileName));
      await file.writeAsBytes(bytes);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt edildi: ${file.path}')));
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onPrintPressed() async {
    final dbDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    if (_tabController.index == 0) {
      // Print Entries
      final entries = _allRecords.where((r) => r.entryDate == dbDate).toList();
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazdırılacak Giriş Kaydı Yok')));
        return;
      }
      await _printEntryReport(entries);
    } else {
      // Print Returns
      final returns = _allRecords.where((r) => r.status == 'RETURNED' && r.note.startsWith(dbDate)).toList();
      if (returns.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazdırılacak İade Kaydı Yok')));
        return;
      }
      await _printReturnReport(returns);
    }
  }

  Future<void> _printEntryReport(List<PalletRecord> records) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);

    // Calculate Stats
    final totalPallets = records.length;
    final totalPlastic = records.where((r) => r.palletType == 'Plastik').length;
    final totalWood = records.where((r) => r.palletType == 'Tahta').length;
    final totalBoxes = records.fold(0, (sum, r) => sum + r.boxCount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Row(
           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
           children: [
              pw.Text('ATILIM GIDA PALET TAKİP SİSTEMİ', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8)),
           ]
        ),
        build: (pw.Context context) => [
          // Header
          pw.Header(
             level: 0, 
             child: pw.Row(
               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
               children: [
                  pw.Text('GÜNLÜK SAYIM RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                  pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 14)),
               ]
             )
          ),
          pw.SizedBox(height: 20),

          // High Level Stats Box
          pw.Container(
             padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
             decoration: pw.BoxDecoration(
               border: pw.Border.all(color: PdfColors.grey400), 
               borderRadius: pw.BorderRadius.circular(8),
               color: PdfColors.grey50
             ),
             child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                   _buildStatItem('TOPLAM PALET', '$totalPallets', fontBold, font),
                   pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                   _buildStatItem('PLASTİK', '$totalPlastic', fontBold, font),
                   pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                   _buildStatItem('TAHTA', '$totalWood', fontBold, font),
                   pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                   _buildStatItem('TOPLAM KOLİ', '$totalBoxes', fontBold, font),
                ]
             )
          ),
          pw.SizedBox(height: 20),
          
          pw.Text('DETAYLI LİSTE', style: pw.TextStyle(font: fontBold, fontSize: 14)),
          pw.SizedBox(height: 10),

          // Detail Table
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerLeft,
            },
            columnWidths: {
                0: const pw.FixedColumnWidth(60), // ID
                1: const pw.FlexColumnWidth(2),   // Firma
                2: const pw.FixedColumnWidth(50), // Tip
                3: const pw.FixedColumnWidth(50), // Koli
                4: const pw.FlexColumnWidth(1.5), // Plaka
            },
            headers: ['ID', 'Firma', 'Tip', 'Koli', 'Plaka'],
            data: records.map((r) => [
              r.displayId,
              r.firmName,
              r.palletType,
              '${r.boxCount}',
              r.vehiclePlate
            ]).toList(),
          ),
          
          pw.SizedBox(height: 40),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
               _buildSignatureBlock('TESLİM ALAN', fontBold, font),
               _buildSignatureBlock('ONAYLAYAN', fontBold, font),
            ]
          )
        ]
      )
    );
    final bytes = await pdf.save();
    await _savePdf(bytes, 'GirisRaporu_$dateStr.pdf');
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  pw.Widget _buildStatItem(String label, String value, pw.Font fontBold, pw.Font font) {
     return pw.Column(
        children: [
           pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
           pw.SizedBox(height: 4),
           pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 16)),
        ]
     );
  }

  pw.Widget _buildSignatureBlock(String title, pw.Font fontBold, pw.Font font) {
     return pw.Column(
       crossAxisAlignment: pw.CrossAxisAlignment.start,
       children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12)),
          pw.SizedBox(height: 15),
          pw.Row(children: [pw.Text('Ad Soyad: ', style: pw.TextStyle(font: font, fontSize: 10)), pw.Container(width: 100, height: 1, color: PdfColors.grey400)]),
          pw.SizedBox(height: 20),
          pw.Row(children: [pw.Text('İmza: ', style: pw.TextStyle(font: font, fontSize: 10)), pw.Container(width: 120, height: 1, color: PdfColors.grey400)]),
       ]
     );
  }

  Future<void> _printReturnReport(List<PalletRecord> records) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);

     // Group by note for Transactions
     final Map<String, List<PalletRecord>> returnTransactions = {};
     for (var r in records) {
       returnTransactions.putIfAbsent(r.note, () => []).add(r);
     }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('ATILIM GIDA', style: pw.TextStyle(font: fontBold, fontSize: 24)),
            pw.Text('GÜNLÜK PALET İADE RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 18)),
          ])),
          pw.SizedBox(height: 10),
          pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 14)),
          pw.SizedBox(height: 20),

           pw.Table.fromTextArray(
             border: pw.TableBorder.all(),
             headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
             headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
             cellStyle: pw.TextStyle(font: font, fontSize: 10),
             columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(0.5)},
             headers: ['Firma / Tip', 'Detay (Şoför/Plaka)', 'Toplam Palet'],
             data: returnTransactions.values.map((list) {
               final first = list.first;
               String info = first.note;
               if (info.contains('|')) {
                  final parts = info.split('|');
                  if (parts.length > 1) {
                     info = parts.sublist(1).join('\n').trim();
                  }
               }
               info = info.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2} İade\s*'), '').trim();
               
               return [
                 '${first.firmName}\n${first.palletType}',
                 info,
                 '${list.length}'
               ];
             }).toList(),
           ),
           pw.SizedBox(height: 20),
           pw.Divider(),
           pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Toplam İade İşlemi: ${returnTransactions.length}', style: pw.TextStyle(font: fontBold))),
        ]
      )
    );
    final bytes = await pdf.save();
    await _savePdf(bytes, 'IadeRaporu_$dateStr.pdf');
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final dbDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    // Strict Filtering Logic
    final entries = _allRecords.where((r) => r.entryDate == dbDate).toList();
    final returns = _allRecords.where((r) => r.status == 'RETURNED' && r.note.startsWith(dbDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
             borderRadius: BorderRadius.circular(12),
             color: Colors.white.withOpacity(0.2), // Or a contrasting color/shade
             border: Border.all(color: Colors.white, width: 1.5)
          ),
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tabs: const [
            Tab(text: 'Palet Giriş (Stok)'),
            Tab(text: 'Palet İade (İşlemler)'),
          ]
        ),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: _allRecords.isEmpty ? null : _onPrintPressed),
        ],
      ),
      body: Column(
        children: [
            // Filter / Date Picker
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: InkWell(
                 onTap: _pickDate,
                 borderRadius: BorderRadius.circular(12),
                 child: Container(
                   padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                   decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.calendar_month, color: AppColors.primary),
                       const SizedBox(width: 8),
                       Text(
                         DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                       ),
                       const Icon(Icons.keyboard_arrow_down, color: AppColors.textDim),
                     ],
                   ),
                 ),
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                   // Tab 1: Entries
                   _buildEntriesTab(entries),
                   
                   // Tab 2: Returns
                   _buildReturnsTab(returns),
                ]
              )
            ),
        ],
      ),
    );
  }
  
  // ------------------------- ENTRIES TAB -------------------------
  
  Widget _buildEntriesTab(List<PalletRecord> records) {
    // Local toggle state for entries is tricky if I wrap it in a separate widget or use state.
    // I will use _showSummary state for Entries ONLY.
    return Column(
      children: [
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16),
           child: Row(
             children: [
               Expanded(child: _buildToggleBtn('Liste', !_showSummary, () => setState(() => _showSummary = false))),
               const SizedBox(width: 16),
               Expanded(child: _buildToggleBtn('Özet', _showSummary, () => setState(() => _showSummary = true))),
             ],
           ),
         ),
         const SizedBox(height: 10),
         Expanded(child: _showSummary ? _buildEntrySummary(records) : _buildDetailList(records, false)),
      ],
    );
  }

  Widget _buildEntrySummary(List<PalletRecord> records) {
    if (records.isEmpty) return const Center(child: Text("Giriş Kaydı Yok"));
    
    // Group Logic
    final wood = records.where((r) => r.palletType == 'Tahta').length;
    final plastic = records.where((r) => r.palletType == 'Plastik').length;
    // final total = records.length;

    // Group for List: Firm -> Type -> Count
    final Map<String, Map<String, int>> firmStats = {};
    for (var r in records) {
       firmStats.putIfAbsent(r.firmName, () => {'Tahta': 0, 'Plastik': 0});
       final key = r.palletType;
       if (key == 'Tahta' || key == 'Plastik') {
          firmStats[r.firmName]![key] = (firmStats[r.firmName]![key] ?? 0) + 1;
       }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // PIE CHART
          if (wood > 0 || plastic > 0)
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                     if (wood > 0) PieChartSectionData(value: wood.toDouble(), color: AppColors.wood, title: '$wood', radius: 60, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                     if (plastic > 0) PieChartSectionData(value: plastic.toDouble(), color: AppColors.plastic, title: '$plastic', radius: 60, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                )
              ),
            ),
          if (wood > 0 || plastic > 0) ...[
            const SizedBox(height: 10),
            Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 _legendItem('Tahta', AppColors.wood),
                 const SizedBox(width: 16),
                 _legendItem('Plastik', AppColors.plastic),
               ],
            ),
          ],
          const SizedBox(height: 20),
          
          // LIST
          ...firmStats.entries.map((e) {
             final firm = e.key;
             final stats = e.value;
             return Column(
               children: [
                 if (stats['Tahta']! > 0)
                   _summaryRow(firm, stats['Tahta']!, 'Tahta', AppColors.wood),
                 if (stats['Plastik']! > 0)
                   _summaryRow(firm, stats['Plastik']!, 'Plastik', AppColors.plastic),
               ],
             );
          }).toList()
        ],
      ),
    );
  }
  
  Widget _legendItem(String title, Color color) {
    return Row(children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 4), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]);
  }
  
  Widget _summaryRow(String firm, int count, String type, Color color) {
    return Container(
       margin: const EdgeInsets.only(bottom: 8),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
       child: Row(children: [
          Text(firm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Text('$count palet ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
       ]),
    );
  }

  // ------------------------- RETURNS TAB -------------------------

  Widget _buildReturnsTab(List<PalletRecord> records) {
     // User wants "Simple". Group by Transaction (Note).
     if (records.isEmpty) return const Center(child: Text("İade Kaydı Yok"));
     
     // Group by note
     final Map<String, List<PalletRecord>> transactions = {};
     for (var r in records) {
       transactions.putIfAbsent(r.note, () => []).add(r);
     }
     
     return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: transactions.length,
       itemBuilder: (ctx, index) {
         final note = transactions.keys.elementAt(index);
         final list = transactions[note]!;
         final first = list.first;
         final totalCount = list.length;
         
         // Clean note
         String info = note;
          if (info.contains('|')) {
            final parts = info.split('|');
            if (parts.length > 1) {
                info = parts.sublist(1).join(' | ').trim();
            }
          } else {
             // Fallback: Remove date prefix 2023-12-15 İade
             info = info.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2} İade\s*'), '').trim();
          }

         return Card(
           margin: const EdgeInsets.only(bottom: 16),
           elevation: 2,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200, width: 1)),
           child: Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(first.firmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                       child: Text('$totalCount Adet Palet', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                     )
                   ]
                 ),
                 const SizedBox(height: 8),
                 Text(first.palletType, style: TextStyle(fontWeight: FontWeight.w600, color: first.palletType == 'Tahta' ? AppColors.wood : AppColors.plastic)),
                 const Divider(height: 16),
                 Text(info, style: const TextStyle(fontSize: 14, color: AppColors.textDim)),
               ],
             ),
           ),
         );
       },
     );
  }

  Widget _buildToggleBtn(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.text, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildDetailList(List<PalletRecord> records, bool isReturn) {
    if (records.isEmpty) return const Center(child: Text("Kayıt Yok"));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (ctx, index) {
        final r = records[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isReturn ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isReturn ? Colors.red.shade100 : (r.palletType == 'Tahta' ? AppColors.wood : AppColors.plastic),
              child: Icon(
                isReturn ? Icons.reply : (r.palletType == 'Tahta' ? Icons.crop_square : Icons.grid_on), 
                color: isReturn ? Colors.red : Colors.white, 
                size: 20
              ),
            ),
            title: Text(r.displayId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isReturn ? Colors.red.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    child: Text(r.firmName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isReturn ? Colors.red : Colors.black87)),
                   ),
                   const SizedBox(height: 4),
                   if (isReturn)
                     const Text('BOŞ PALET İADESİ (1 Adet)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                   else
                     Text('${r.boxCount} Koli • ${r.vehiclePlate}', style: const TextStyle(color: AppColors.textDim)),
                ],
              ),
            ),
            trailing: PopupMenuButton(
              itemBuilder: (ctx) => [
                 if (!isReturn) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Düzenle')])),
                 const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Sil')])),
              ],
              onSelected: (v) {
                if (v == 'delete') _delete(r.localId);
                if (v == 'edit') _edit(r);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(String key, int value, bool isReturn) {
    final firm = key.split(' (')[0];
    final type = key.split(' (')[1].replaceAll(')', '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isReturn ? Border.all(color: Colors.red.shade200) : null,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(firm, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isReturn ? Colors.red : Colors.black)),
              Text(type, style: TextStyle(color: type == 'Tahta' ? AppColors.wood : AppColors.plastic, fontWeight: FontWeight.w600)),
            ],
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isReturn ? Colors.red : AppColors.primary)),
                TextSpan(text: isReturn ? ' palet' : ' koli', style: const TextStyle(fontSize: 16, color: AppColors.textDim)),
              ]
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. RETURN SCREEN
// ---------------------------------------------------------------------------
class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  DateTime _selectedDate = DateTime.now();
  final String _selectedFirm = 'BEYPILIC'; // Hardcoded
  String _selectedType = 'Tahta';
  final TextEditingController _countController = TextEditingController(text: '');
  
  final TextEditingController _returnerController = TextEditingController(); // İade Eden
  final TextEditingController _driverController = TextEditingController();   // Şoför
  final TextEditingController _plateController = TextEditingController();    // Plaka

  bool _isLoading = false;

  Future<void> _processReturn() async {
    final count = int.tryParse(_countController.text) ?? 0;
    if (count < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir adet giriniz')));
      return;
    }
    if (_returnerController.text.isEmpty || _driverController.text.isEmpty || _plateController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurunuz')));
      return;
    }

    setState(() => _isLoading = true);

    final info = 'İade Eden: ${_returnerController.text} | Şoför: ${_driverController.text} | Plaka: ${_plateController.text}';

    final res = await DatabaseHelper.instance.processReturn(
      _selectedType, 
      count, 
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      info
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res == 'OK') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İade İşlemi Başarılı!'), backgroundColor: AppColors.success));
      
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (ctx) => AlertDialog(
          title: const Text('İşlem Başarılı'),
          content: const Text('İade fişi yazdırmak ister misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); 
                Navigator.pop(context); 
              },
              child: const Text('Hayır')
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _printReceipt();
              }, 
              child: const Text('Yazdır')
            )
          ],
        )
      );
    } else {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Hata'),
        content: Text(res),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))]
      ));
    }
  }

  Future<void> _savePdf(Uint8List bytes, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory(p.join(dir.path, 'reports'));
      if (!await saveDir.exists()) await saveDir.create(recursive: true);
      
      final file = File(p.join(saveDir.path, fileName));
      await file.writeAsBytes(bytes);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Makbuz kaydedildi: ${file.path}')));
    } catch (e) {
      print(e);
    }
  }

  Future<void> _printReceipt() async {
    final pdf = pw.Document();
    
    // Use fallback font if assets not loaded properly or just standard
    // Ideally we load Inter-Regular.ttf from assets if declared in pubspec
    // We will attempt to use standard Helvetica for simplicity and speed if bold/regular concerns
    // But user wants "Professional". 
    // We'll stick to Printing package defaults which handle fonts gracefully usually. 
    // Or use PdfGoogleFonts.
    
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0, 
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ATILIM GIDA', style: pw.TextStyle(font: fontBold, fontSize: 24)),
                    pw.Text('PALET İADE FİŞİ', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tarih: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}', style: pw.TextStyle(font: font, fontSize: 12)),
                  pw.Text('Firma: $_selectedFirm', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ]
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('TESLİMAT BİLGİLERİ', style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Teslim Eden: ${_returnerController.text}', style: pw.TextStyle(font: font))),
                pw.Expanded(child: pw.Text('Şoför: ${_driverController.text}', style: pw.TextStyle(font: font))),
                pw.Expanded(child: pw.Text('Araç Plaka: ${_plateController.text}', style: pw.TextStyle(font: font))),
              ]),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                data: <List<String>>[
                  <String>['Palet Tipi', 'Adet'],
                  <String>[_selectedType, _countController.text],
                ]
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Text('TESLİM EDEN (Atılım Gıda)', style: pw.TextStyle(font: fontBold)),
                    pw.SizedBox(height: 40),
                    pw.Text('${_returnerController.text}', style: pw.TextStyle(font: font)),
                    pw.Container(height: 1, width: 120, color: PdfColors.black),
                    pw.Text('İmza', style: pw.TextStyle(font: font, fontSize: 10)),
                  ]),
                   pw.Column(children: [
                    pw.Text('NAKLYİE / ŞOFÖR', style: pw.TextStyle(font: fontBold)),
                    pw.SizedBox(height: 40),
                    pw.Text('${_driverController.text}', style: pw.TextStyle(font: font)),
                    pw.Container(height: 1, width: 120, color: PdfColors.black),
                    pw.Text('İmza', style: pw.TextStyle(font: font, fontSize: 10)),
                  ]),
                  pw.Column(children: [
                    pw.Text('TESLİM ALAN (BEYPİLİÇ)', style: pw.TextStyle(font: fontBold)),
                    pw.SizedBox(height: 40),
                    pw.Container(height: 1, width: 150, color: PdfColors.black),
                     pw.Text('Ad Soyad / İmza', style: pw.TextStyle(font: font, fontSize: 10)),
                  ]),
                ]
              )
            ]
          );
        }
      )
    );


    final bytes = await pdf.save();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    await _savePdf(bytes, 'IadeFisi_$dateStr.pdf');
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  Widget _buildTextField(String label, TextEditingController controller, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.orange) : null,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Palet İade (BEYPİLİÇ)'), backgroundColor: Colors.orange),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Date Selector
               InkWell(
                 onTap: () async {
                   final d = await showDatePicker(
                     context: context, 
                     initialDate: _selectedDate, 
                     firstDate: DateTime(2020), 
                     lastDate: DateTime(2030),
                     locale: const Locale('tr', 'TR'),
                   );
                   if (d != null) setState(() => _selectedDate = d);
                 },
                 child: Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.white),
                   child: Row(children: [
                     const Icon(Icons.calendar_today, color: Colors.orange),
                     const SizedBox(width: 10),
                     Text('Tarih: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   ]),
                 ),
               ),
               
               const SizedBox(height: 20),
               const Text('Palet Tipi', style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.bold)),
               Row(
                 children: [
                   Expanded(child: RadioListTile(title: const Text('Tahta'), value: 'Tahta', groupValue: _selectedType, activeColor: Colors.orange, onChanged: (v) => setState(() => _selectedType = v!))),
                   Expanded(child: RadioListTile(title: const Text('Plastik'), value: 'Plastik', groupValue: _selectedType, activeColor: Colors.orange, onChanged: (v) => setState(() => _selectedType = v!))),
                 ],
               ),

               const SizedBox(height: 10),
               TextField(
                 controller: _countController,
                 keyboardType: TextInputType.number,
                 decoration: InputDecoration(
                   labelText: 'İade Edilecek Adet',
                   filled: true, fillColor: Colors.white,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   suffixIcon: const Icon(Icons.numbers, color: Colors.orange),
                   labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)
                 ),
                 style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               ),

               const Divider(height: 30, thickness: 1),
               const Text('Teslimat Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               
               _buildTextField('İade Eden (Personel)', _returnerController, Icons.person_outline),
               Row(children: [
                 Expanded(child: _buildTextField('Şoför Adı', _driverController, Icons.drive_eta)),
                 const SizedBox(width: 10),
                 Expanded(child: _buildTextField('Araç Plaka', _plateController, Icons.confirmation_number)),
               ]),
               
               const SizedBox(height: 20),
               SizedBox(
                 width: double.infinity,
                 height: 56,
                 child: ElevatedButton(
                   onPressed: _isLoading ? null : _processReturn,
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                   child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('İADE OLUŞTUR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 ),
               ),
               const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. SAVED REPORTS SCREEN
// ---------------------------------------------------------------------------
class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory(p.join(dir.path, 'reports'));
    if (await saveDir.exists()) {
       setState(() {
         _files = saveDir.listSync()
            .where((e) => e.path.endsWith('.pdf'))
            .toList()
            ..sort((a,b) => b.statSync().modified.compareTo(a.statSync().modified));
         _isLoading = false;
       });
    } else {
       setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sil?'),
      content: const Text('Rapor silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL', style: TextStyle(color: Colors.red))),
      ]
    ));
    
    if (confirm == true) {
      await file.delete();
      _loadFiles();
    }
  }
  
  Future<void> _openFile(String path) async {
     await OpenFilex.open(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıtlı Raporlar')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _files.isEmpty 
           ? const Center(child: Text('Kayıtlı rapor bulunamadı'))
           : ListView.builder(
               padding: const EdgeInsets.all(16),
               itemCount: _files.length,
               itemBuilder: (ctx, index) {
                 final file = _files[index];
                 final name = p.basename(file.path);
                 final time = file.statSync().modified;
                 return Card(
                   margin: const EdgeInsets.only(bottom: 12),
                   child: ListTile(
                     leading: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 32),
                     title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(time)),
                     onTap: () => _openFile(file.path),
                     trailing: IconButton(
                       icon: const Icon(Icons.delete, color: Colors.grey),
                       onPressed: () => _deleteFile(file),
                     ),
                   ),
                 );
               },
             ),
    );
  }
}
