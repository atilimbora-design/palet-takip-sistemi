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
  final String? temperature; 
  final String? entryTime;
  final String? returnDate; // New
  
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
    this.returnDate,
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
      'return_date': returnDate,
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
      returnDate: map['return_date'],
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
    String? returnDate,
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
      returnDate: returnDate ?? this.returnDate,
    );
  }
}
