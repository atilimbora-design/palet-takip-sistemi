import 'dart:async';
import 'dart:io';
import 'dart:math';
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
  final String status;   // 'IN_STOCK', 'RETURNED'
  int isSynced;      // 0: No, 1: Yes
  final String? temperature; // New
  final String? entryTime;   // New

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
    this.temperature,
    this.entryTime,
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
      'temperature': temperature,
      'entry_time': entryTime,
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
      temperature: map['temperature'],
      entryTime: map['entry_time'],
    );
  }

  PalletRecord copyWith({
    String? firmName,
    String? palletType,
    int? boxCount,
    String? vehiclePlate,
    String? entryDate,
    String? note,
    String? temperature,
    String? entryTime,
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
      temperature: temperature ?? this.temperature,
      entryTime: entryTime ?? this.entryTime,
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
    _database = await _initDB('paletsayim_v9.db'); // v9 Final Reset
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 1, 
      onCreate: _createDB,
      // onUpgrade not needed for fresh DB
    );
  }

  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE pallets ADD COLUMN temperature TEXT");
      await db.execute("ALTER TABLE pallets ADD COLUMN entry_time TEXT");
    }
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
        is_synced INTEGER DEFAULT 0,
        temperature TEXT,
        entry_time TEXT
      )
    ''');
    
    // No seeding. Data will come from Sync.
  }

  Future<void> _seedLegacyData(Database db) async {
     // Legacy Data from Server
     const jsonData = '''
{"count":39,"data":[{"local_id":"fde53b4a-b6a3-4578-9daf-55b7573fd4be","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":70,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"cd3efca1-7b65-4e42-a5f5-598c4fba2c89","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":70,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"129618fa-e52d-4809-ae6f-cf3dd455d899","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":70,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"e9216dc6-45ca-4d29-8d3f-18b3ca708d30","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":70,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"f1c1f8e7-e39e-4c36-a2b5-3beb7ae7c081","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":70,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"dab4831d-9a9c-4279-adf2-faf8a78b62b6","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":16,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"86762720-b219-45aa-b058-bfbd05eed262","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":39,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"57666692-d22c-4905-bec3-b5ace79eeb80","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":23,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"b87bc9c4-a47c-4b62-a426-8af8a71ab16a","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":16,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"669f6257-ddec-4db8-baa8-934530d81324","firm_name":"ISLAK MENDİL","pallet_type":"Plastik","box_count":1,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"7972b01d-0acc-4d58-88db-b44fa956c274","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":56,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"2760df85-b931-4110-8051-72dc718050f8","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":62,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"2603d951-9da4-4c08-8700-f0cbb4e2567e","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":51,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"0aa0d053-5978-4e9b-b4c9-ad730642a738","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":50,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"3b69c42c-458c-4173-bf0a-b588add5d2ea","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":50,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"ff2c7777-179d-4a6f-adf9-edff64b4f9b0","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":26,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"66c5a5ea-bc3b-4400-91b4-6a6bf9336154","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":47,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"ea4b3a8c-f4af-4818-8055-b7e0063ea5a0","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":55,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"2fb99409-a2da-4e3c-b0f5-dcc97ec50ef2","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":60,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"27db8f9a-e45c-403b-86e3-82c68507aa05","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":33,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"c3687b35-97c0-425f-b3ba-b5062027158b","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":54,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"616ea838-d9df-4eaa-91c1-c04b3cd23063","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":58,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"75386bc9-3492-4f50-876b-7a8f2687a329","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":36,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"4f8ffb5d-3245-4de2-8583-9555a2bf40af","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":60,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"f2f1ca94-40cb-4e94-9e9b-ec64eef6d05d","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":44,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"b077b16b-e81a-4bb5-9373-c423a1ec8cc6","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":35,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"72aa2526-aa37-4c14-ae5e-1931da6b49fa","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":32,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"8c2f3568-0f89-4412-b572-f96dcb038b2e","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":32,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"916620c3-8515-4bd2-9bf2-2dcb7b7c0a01","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":32,"vehicle_plate":"14GH361","entry_date":"2025-12-23","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"cec657cd-01c4-4897-a31e-861203faf4ee","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":51,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"RETURNED","is_synced":1},{"local_id":"70ba65d2-cc03-4542-87cf-572f1a3efbb0","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":51,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"RETURNED","is_synced":1},{"local_id":"15ed57d0-7081-477e-9a5f-2be76d454c0d","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":51,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"RETURNED","is_synced":1},{"local_id":"51ee6c28-02a7-45cc-adcf-91265c76f383","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":76,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"6b7a2cc9-e926-4775-b2cb-2294e72d2452","firm_name":"BEYPILIC","pallet_type":"Tahta","box_count":76,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"69526f67-055f-467d-8043-a8eb1acd8c1d","firm_name":"METRO","pallet_type":"Plastik","box_count":78,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"RETURNED","is_synced":1},{"local_id":"7afeaddd-02df-42d0-91e8-af1cdb1bbe51","firm_name":"METRO","pallet_type":"Plastik","box_count":78,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"d2d375d9-ef41-420e-a1ff-cfe0b1d1e992","firm_name":"METRO","pallet_type":"Plastik","box_count":78,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"94c16952-e784-4214-b995-cdcb45e7424e","firm_name":"METRO","pallet_type":"Plastik","box_count":78,"vehicle_plate":"34ZJ45","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1},{"local_id":"3059f6a1-685f-483d-8426-4fa5b06bc271","firm_name":"BEYPILIC","pallet_type":"Plastik","box_count":26,"vehicle_plate":"44DD","entry_date":"2025-12-22","note":"","status":"IN_STOCK","is_synced":1}]}
''';

     try {
       final List<dynamic> records = jsonDecode(jsonData)['data'];
       // Sort by entry_date just to generate display_id roughly in order if needed, but display_id is missing in json, we can generate index 1..N
       // But wait, display_id is not in json. We should probably generate it sequentially.
       // However, the user said generate fake times and temperature.
       
       final random = Random();
       final tempIndices = <int>{};
       // Pick 5 random indices (only check status IN_STOCK and pallet type if logical, but lets just pick any 5).
       // User said "5 palete", implies entered pallets.
       final validIndices = List.generate(records.length, (i) => i);
       validIndices.shuffle();
       final selectedForTemperature = validIndices.take(5).toSet();
       
       for (var i = 0; i < records.length; i++) {
          var r = records[i];
          
          // Generate Display ID: 0001, 0002... based on index + 1
          final displayId = (i + 1).toString().padLeft(4, '0');
          
          // Random Time: 06:45 (6*60 + 45 = 405 min) to 07:48 (7*60 + 48 = 468 min)
          // Range: 468 - 405 = 63 minutes
          final totalMinutes = 405 + random.nextInt(63);
          final h = totalMinutes ~/ 60;
          final m = totalMinutes % 60;
          final timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
          
          String temp = "";
          if (selectedForTemperature.contains(i)) {
             // -0.8 to 2.4
             double val = -0.8 + random.nextDouble() * (2.4 - (-0.8));
             temp = val.toStringAsFixed(1);
          }
          
          await db.insert('pallets', {
            'local_id': r['local_id'],
            'display_id': displayId, // Generate ID
            'firm_name': r['firm_name'],
            'pallet_type': r['pallet_type'],
            'box_count': r['box_count'],
            'vehicle_plate': r['vehicle_plate'],
            'entry_date': r['entry_date'],
            'note': r['note'] ?? '',
            'status': r['status'],
            'is_synced': 1,
            'temperature': temp,
            'entry_time': timeStr
          });
       }
     } catch (e) {
       print("Seed Error: $e");
     }
  }

  Future<int> create(PalletRecord record) async {
    final db = await instance.database;
    return await db.insert('pallets', record.toMap());
  }

  Future<bool> exists(String localId) async {
    final db = await instance.database;
    final result = await db.query(
      'pallets',
      columns: ['local_id'],
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    return result.isNotEmpty;
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
    // Sort chronological: Date DESC, Time DESC, then Created ID DESC
    final result = await db.query('pallets', orderBy: "entry_date DESC, entry_time DESC, local_id DESC", limit: limit);
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

  Future<int> getPlasticStock() async {
    final db = await instance.database;
    // Count only Plastic pallets that are currently IN_STOCK
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM pallets WHERE status = 'IN_STOCK' AND pallet_type = 'Plastik'")) ?? 0;
  }

  Future<String> processReturn(String type, int count, String date, String info) async {
    final db = await instance.database;
    
    // Find candidate records to return (FIFO or just any IN_STOCK of that type)
    // Important: We need 'count' number of records
    final List<Map<String, dynamic>> candidates = await db.query(
      'pallets',
      columns: ['local_id'],
      where: "pallet_type = ? AND status = 'IN_STOCK'",
      whereArgs: [type],
      limit: count
    );

    if (candidates.length < count) {
      // Not enough stock locally
      return 'Yetersiz Stok (Local): ${candidates.length} adet bulundu.';
    }

    final batch = db.batch();
    for (var row in candidates) {
      batch.update(
        'pallets',
        {'status': 'RETURNED', 'note': info}, // Update status and add note
        where: 'local_id = ?',
        whereArgs: [row['local_id']]
      );
    }
    
    await batch.commit();
    return 'OK';
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
  Timer? _syncTimer;
  
  Map<String, dynamic> stats = {'wood': 0, 'plastic': 0, 'boxes': 0};
  int _totalStock = 0;
  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Auto-Sync every 10 seconds (Two-Way Sync)
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _pullFromServer(); // Quiet background sync
      _loadStats(); // Update UI stats
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final s = await DatabaseHelper.instance.getStats(_today);
    final stock = await DatabaseHelper.instance.getPlasticStock();
    setState(() {
      stats = s;
      _totalStock = stock;
    });
  }

  Future<void> _pullFromServer() async {
    // Show spinner if you want, or just snackbar
    // Removed Snackbar for auto-sync to avoid spamming UI
    // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veriler Sunucudan Çekiliyor... ⏳')));
    
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/pallets');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> serverData = json['data'];
        
        int addedCount = 0;
        
        for (var item in serverData) {
          final record = PalletRecord(
            localId: item['local_id'],
            displayId: 'SYNC-${item['local_id'].toString().substring(0,4)}', 
            firmName: item['firm_name'],
            palletType: item['pallet_type'],
            boxCount: item['box_count'],
            vehiclePlate: item['vehicle_plate'],
            entryDate: item['entry_date'],
            note: item['note'] ?? '',
            status: item['status'] ?? 'IN_STOCK',
            temperature: item['temperature'],
            entryTime: item['entry_time'],
            isSynced: 1 
          );

          final exists = await DatabaseHelper.instance.exists(item['local_id']);
          if (exists) {
            // Update existing record (crucial for status updates like IN_STOCK -> RETURNED)
            await DatabaseHelper.instance.update(record);
          } else {
            // Create new
            await DatabaseHelper.instance.create(record);
            addedCount++;
          }
        }
        
        if (addedCount > 0) {
           print('Synced $addedCount new records');
        }
        // Silent success for background sync

      }
    } catch (e) {
      print('Pull Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata: Sunucuya Erişilemedi ❌')));
    }
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
                    const Text('TOPLAM ELDE KALAN PLASTİK', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
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
              // ROW 1
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
              
              // ROW 2
              Row(
                children: [
                  Expanded(child: _buildMenuCard('Palet İade', Icons.assignment_return, Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnScreen()))
                      .then((_) => _loadStats());
                  })),
                   const SizedBox(width: 16),
                  Expanded(child: _buildMenuCard('Veri Eşitle', Icons.sync, Colors.redAccent, () async {
                     await _pullFromServer();
                     _loadStats();
                  })),
                ],
              ),
              const SizedBox(height: 16),

              // ROW 3
              Row(
                children: [
                   Expanded(child: _buildMenuCard('Kayıtlı Raporlar', Icons.folder_special, Colors.teal, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedReportsScreen()));
                  })),
                ]
              )
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
  late TextEditingController _tempController; // Temperature input
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
    _tempController = TextEditingController(); // Init temp

    if (widget.editingRecord != null) {
      try {
        _selectedDate = DateTime.parse(widget.editingRecord!.entryDate);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
      _boxCount = widget.editingRecord!.boxCount;
      _selectedType = widget.editingRecord!.palletType;
      
      // Load temperature if exists
      if (widget.editingRecord!.temperature != null) {
        _tempController.text = widget.editingRecord!.temperature!;
      }

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
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _pullFromServer() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/pallets');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> serverData = json['data'];
        
        int addedCount = 0;
        
        for (var item in serverData) {
          // Check if exists locally
          final exists = await DatabaseHelper.instance.exists(item['local_id']);
          if (!exists) {
            // Map server item to PalletRecord
            final record = PalletRecord(
              localId: item['local_id'],
              displayId: 'SYNC-${item['local_id'].toString().substring(0,4)}', // Handle display ID
              firmName: item['firm_name'],
              palletType: item['pallet_type'],
              boxCount: item['box_count'],
              vehiclePlate: item['vehicle_plate'],
              entryDate: item['entry_date'],
              note: item['note'] ?? '',
              status: item['status'] ?? 'IN_STOCK',
              isSynced: 1 // Coming from server, so it is synced
            );
            await DatabaseHelper.instance.create(record);
            addedCount++;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Senkronizasyon Tamamlandı: $addedCount yeni kayıt eklendi ⬇️'), 
          backgroundColor: Colors.blue
        ));
        _loadRecents(); // Refresh list
      }
    } catch (e) {
      print('Pull Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucudan veri çekilemedi ❌')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _deleteFromServer(String id) async {
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/pallets/$id');
      final response = await http.delete(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sunucudan Silindi 🗑️'), 
          backgroundColor: Colors.orange
        ));
      } else {
        print('Server delete failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete Sync Error: $e');
    }
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
      // Fire and forget delete sync
      _deleteFromServer(id);
      
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
          temperature: _tempController.text,
          entryTime: widget.editingRecord!.entryTime ?? DateFormat('HH:mm').format(DateTime.now()),
       );
       
       // Update Server Sync
       _updateServer(updated);

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
      temperature: _tempController.text,
      entryTime: DateFormat('HH:mm').format(DateTime.now()),
    );

    // Sync with Server (Fire and Forget)
    _syncWithServer(record);

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

  Future<void> _updateServer(PalletRecord record) async {
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/pallets/${record.localId}');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(record.toMap()),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sunucuda Güncellendi 📝'), 
          backgroundColor: Colors.blue
        ));
      } else {
         print('Update failed: ${response.body}');
      }
    } catch (e) {
      print('Update Sync Error: $e');
    }
  }

  Future<void> _syncWithServer(PalletRecord record) async {
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/sync');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(record.toMap()),
      ).timeout(const Duration(seconds: 20)); // Increased timeout for stability

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sunucuya Gönderildi ✅'), 
          backgroundColor: Colors.green
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sunucu Hatası: ${response.statusCode}'), 
          backgroundColor: Colors.red
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bağlantı Hatası: $e'), 
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }
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
              
              // TEMPERATURE (NEW)
              _buildSectionTitle('SICAKLIK'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.thermostat, color: Colors.orange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ürün Derecesi', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                          TextField(
                            controller: _tempController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: 'örn: -18',
                              border: InputBorder.none,
                              suffixText: '°C',
                              suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                         subtitle: Text('${r.boxCount} Koli • ${r.vehiclePlate} • ${r.entryTime ?? '--:--'} • ${r.temperature != null && r.temperature!.isNotEmpty ? "${r.temperature} °C" : ""}', style: const TextStyle(fontSize: 12)),
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

  Future<void> _deleteFromServer(String id) async {
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/pallets/$id');
      final response = await http.delete(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sunucudan Silindi 🗑️'), 
          backgroundColor: Colors.orange
        ));
      }
    } catch (e) {
      print('Delete Sync Error: $e');
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
          _deleteFromServer(id);
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
      final returns = _allRecords.where((r) => 
        r.status == 'RETURNED' && (r.note.startsWith(dbDate) || r.entryDate == dbDate)
      ).toList();
      if (returns.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazdırılacak İade Kaydı Yok')));
        return;
      }
      await _printReturnReport(returns);
    }
  }

  Future<void> _printEntryReport(List<PalletRecord> records) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);

    // Load Logo
    final logoData = await rootBundle.load('assets/images/atilim_logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    // Calculate Stats
    final totalPallets = records.length;
    final totalPlastic = records.where((r) => r.palletType == 'Plastik').length;
    final totalWood = records.where((r) => r.palletType == 'Tahta').length;
    final totalBoxes = records.fold(0, (sum, r) => sum + r.boxCount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => pw.Container(
           alignment: pw.Alignment.centerRight,
           margin: const pw.EdgeInsets.only(top: 10),
           child: pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (pw.Context context) => [
          // 1. Header with Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
               pw.Image(logo, width: 120),
               pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.end,
                 children: [
                   pw.Text('GÜNLÜK SAYIM RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue800)),
                   pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                 ]
               )
            ]
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 1, height: 20),
          pw.SizedBox(height: 10),

          // 2. Statistics Cards & Chart Row
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Stats Column
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  children: [
                     _buildPdfStatCard('TOPLAM PALET', '$totalPallets', PdfColors.blue800, fontBold),
                     pw.SizedBox(height: 8),
                     pw.Row(
                       children: [
                         pw.Expanded(child: _buildPdfStatCard('PLASTİK', '$totalPlastic', PdfColors.orange700, fontBold)),
                         pw.SizedBox(width: 8),
                         pw.Expanded(child: _buildPdfStatCard('TAHTA', '$totalWood', PdfColors.brown700, fontBold)),
                       ]
                     ),
                     pw.SizedBox(height: 8),
                     _buildPdfStatCard('TOPLAM KOLİ', '$totalBoxes', PdfColors.green700, fontBold),
                  ]
                )
              ),
              pw.SizedBox(width: 20),
              // Chart Column (Simple Ratio Bar)
              pw.Expanded(
                 flex: 1,
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   children: [
                      pw.Text('DAĞILIM', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 5),
                      // Plastic Bar
                      pw.Row(children: [
                        pw.Container(width: 60, child: pw.Text('Plastik', style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Expanded(child: pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.orange700, borderRadius: pw.BorderRadius.circular(2)))),
                        pw.SizedBox(width: 8),
                        pw.Text('%${(totalPallets > 0 ? (totalPlastic / totalPallets * 100).toStringAsFixed(0) : "0")}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ]),
                      pw.SizedBox(height: 4),
                      // Wood Bar
                      pw.Row(children: [
                        pw.Container(width: 60, child: pw.Text('Tahta', style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Expanded(child: pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.brown700, borderRadius: pw.BorderRadius.circular(2)))), 
                        // Note: Real bar width logic would need separate containers or Flex, but full width looks okay as "legend" style or we can calculate width.
                        // Lets make it simpler: Just Legend colors.
                        pw.SizedBox(width: 8),
                        pw.Text('%${(totalPallets > 0 ? (totalWood / totalPallets * 100).toStringAsFixed(0) : "0")}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      ]),
                   ]
                 )
              )
            ]
          ),
          
          pw.SizedBox(height: 20),
          pw.Text('DETAYLI LİSTE', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue800)),
          pw.SizedBox(height: 10),

          // 3. Data Table
          pw.Table.fromTextArray(
            border: null, 
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center, // Temp
                4: pw.Alignment.center, // Time
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerLeft,
            },
            columnWidths: {
                0: const pw.FixedColumnWidth(25),  // ID (Daralttım)
                1: const pw.FlexColumnWidth(1.8),  // Firma
                2: const pw.FixedColumnWidth(40),  // Tip
                3: const pw.FixedColumnWidth(45),  // Derece (Genişlettim)
                4: const pw.FixedColumnWidth(40),  // Saat
                5: const pw.FixedColumnWidth(30),  // Koli
                6: const pw.FlexColumnWidth(1.2),  // Plaka
            },
            headers: ['ID', 'Firma', 'Tip', 'Isı', 'Saat', 'Koli', 'Plaka'],
            data: records.map((r) => [
              r.displayId.split('-').last,
              r.firmName,
              r.palletType,
              (r.temperature != null && r.temperature != "") ? '${r.temperature}' : '-', // Simplified check
              r.entryTime ?? '-',
              '${r.boxCount}',
              r.vehiclePlate
            ]).toList(),
          ),
          
          pw.SizedBox(height: 30),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                   pw.Text('Teslim Alan / Onay', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                   pw.SizedBox(height: 40),
                   pw.Container(width: 100, height: 1, color: PdfColors.black),
                ]
              )
            ]
          )
        ]
      )
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Gunluk_Sayim_${dateStr}.pdf');
    final bytes = await pdf.save();
    _savePdf(bytes, 'Rapor_$dateStr.pdf');
  }

  pw.Widget _buildPdfStatCard(String title, String value, PdfColor color, pw.Font fontBold) {
     return pw.Container(
       padding: const pw.EdgeInsets.all(10),
       decoration: pw.BoxDecoration(
         color: PdfColors.white,
         border: pw.Border.all(color: color, width: 1.5),
         borderRadius: pw.BorderRadius.circular(6)
       ),
       child: pw.Row(
         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
         children: [
            pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 9, color: color)),
            pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 14)),
         ]
       )
     );
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
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final dateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);

    // Load Logo
    final logoData = await rootBundle.load('assets/images/atilim_logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    // Calculate Return Stats
    final totalPallets = records.length;
    final totalPlastic = records.where((r) => r.palletType == 'Plastik').length;
    final totalWood = records.where((r) => r.palletType == 'Tahta').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => pw.Container(
           alignment: pw.Alignment.centerRight,
           margin: const pw.EdgeInsets.only(top: 10),
           child: pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (pw.Context context) => [
          // 1. Header with Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
               pw.Image(logo, width: 120),
               pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.end,
                 children: [
                   pw.Text('İADE FİŞİ RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.red800)),
                   pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                 ]
               )
            ]
          ),
          pw.Divider(color: PdfColors.grey300, thickness: 1, height: 20),
          pw.SizedBox(height: 10),

          // 2. Stats Cards
          pw.Row(
              children: [
                  pw.Expanded(child: _buildPdfStatCard('TOPLAM İADE', '$totalPallets', PdfColors.red800, fontBold)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _buildPdfStatCard('PLASTİK İADE', '$totalPlastic', PdfColors.orange700, fontBold)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _buildPdfStatCard('TAHTA İADE', '$totalWood', PdfColors.brown700, fontBold)),
              ]
          ),
          pw.SizedBox(height: 20),

          // 3. Return Table
          pw.Table.fromTextArray(
            border: null,
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerLeft,
            },
            columnWidths: {
                0: const pw.FixedColumnWidth(40),  // ID
                1: const pw.FlexColumnWidth(2),    // Firma
                2: const pw.FixedColumnWidth(50),  // Tip
                3: const pw.FlexColumnWidth(2),    // Not (İade Bilgisi)
            },
            headers: ['ID', 'Firma', 'Tip', 'İade Bilgisi / Not'],
            data: records.map((r) => [
              r.displayId.split('-').last,
              r.firmName,
              r.palletType,
              r.note
            ]).toList(),
          ),
          
          pw.SizedBox(height: 40),
          
          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                   pw.Text('Teslim Eden / Onay', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                   pw.SizedBox(height: 40),
                   pw.Container(width: 100, height: 1, color: PdfColors.black),
                ]
              )
            ]
          )
        ]
      )
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Iade_Raporu_${dateStr}.pdf');
    final bytes = await pdf.save();
    _savePdf(bytes, 'Iade_$dateStr.pdf');
  }


  @override
  Widget build(BuildContext context) {
    final dbDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    // Strict Filtering Logic
    final entries = _allRecords.where((r) => r.entryDate == dbDate).toList();
    // Relaxed Filter: Show if Note starts with Date OR if Entry Date matches (Assuming same-day return in many cases)
    // Ideally we need a separate 'returnDate' field, but this is a quick fix.
    final returns = _allRecords.where((r) => 
      r.status == 'RETURNED' && (r.note.startsWith(dbDate) || r.entryDate == dbDate)
    ).toList();

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

  Future<void> _syncReturnFromServer(String firm, String type, int count) async {
    try {
      final url = Uri.parse('http://192.168.1.104:3000/api/return');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firm_name': firm,
          'pallet_type': type,
          'count': count
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucuya İade Bildirildi 📤'), backgroundColor: Colors.blue));
      } else {
        print('Return Sync Error: ${response.body}');
      }
    } catch (e) {
      print('Return Sync Connection Error: $e');
    }
  }

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

    // Local Process
    final res = await DatabaseHelper.instance.processReturn(
      _selectedType, 
      count, 
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      info
    );

    // Sync with Server (Fire and Forget)
    if (res == 'OK') {
      _syncReturnFromServer(_selectedFirm, _selectedType, count);
    }

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
    
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

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
