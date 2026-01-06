
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/pallet_record.dart';

class ThermalService {
  
  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      // Request permissions first
      /* 
      // We need to request permissions explicitly for Android 12+
      // This part requires 'permission_handler' which we added.
      */
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothConnect] != PermissionStatus.granted && 
          statuses[Permission.bluetooth] != PermissionStatus.granted) {
         // Handle permission denied if critical, but let's try to fetch anyway or return empty with print
         print("Bluetooth permissions denied");
         // On some devices, it might still work if pre-granted or logic differs, but usually acts as gatekeeper.
      }

      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      print("Error getting devices: $e");
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    // Check if already connected to this device? API doesn't easily support that check per device.
    // Just try connect.
    final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    return connected;
  }

  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }
  
  Future<bool> disconnect() async {
      try {
        final bool status = await PrintBluetoothThermal.disconnect;
        return status;
      } catch (e) {
        return false;
      }
  }

  Future<void> printEntryReport(List<PalletRecord> records, DateTime date) async {
    // Note: Connection check logic is handled by caller or we trust it.
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Logo
    try {
      final ByteData data = await rootBundle.load('assets/images/atilim_logo.png');
      final Uint8List bytesImg = data.buffer.asUint8List();
      final img.Image? image = img.decodeImage(bytesImg);
      if (image != null) {
        final resized = img.copyResize(image, width: 370);
         bytes += generator.image(resized);
      }
    } catch (e) {
      print("Logo Error: $e");
    }

    // Header
    bytes += generator.text('GUNLUK GIRIS RAPORU', styles: const PosStyles(align: PosAlign.center, bold: true, width: PosTextSize.size2, height: PosTextSize.size2));
    bytes += generator.text('Tarih: ${DateFormat('dd.MM.yyyy').format(date)}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // Group by Plate
    // Key: Plate, Value: Records
    final Map<String, List<PalletRecord>> grouped = {};
    for (var r in records) {
       final plate = r.vehiclePlate.isEmpty ? 'PLAKASIZ' : r.vehiclePlate;
       if (!grouped.containsKey(plate)) grouped[plate] = [];
       grouped[plate]!.add(r);
    }

    // Iterate plates
    grouped.forEach((plate, plateRecords) {
        // Calculate totals for this plate
        // CORRECT LOGIC: 1 Record = 1 Pallet. boxCount is Boxes ON the pallet.
        
        int totalPlastic = 0;
        int totalWood = 0;
        int totalEuro = 0;
        
        final Map<String, int> firmCounts = {};

        for (var r in plateRecords) {
            // Count Records!
            if (r.palletType == 'Plastik') totalPlastic++;
            else if (r.palletType == 'Tahta') totalWood++;
            else if (r.palletType == 'Euro') totalEuro++;

            if (!firmCounts.containsKey(r.firmName)) firmCounts[r.firmName] = 0;
            firmCounts[r.firmName] = firmCounts[r.firmName]! + 1; // Count record
        }

        final totalTotal = plateRecords.length;

        // Plate Header
        bytes += generator.text('PLAKA: $plate', styles: const PosStyles(bold: true, width: PosTextSize.size1, height: PosTextSize.size1));
        
        // Summary
        bytes += generator.row([
            PosColumn(text: 'TOPLAM:', width: 6),
            PosColumn(text: '$totalTotal Palet', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        
        if (totalPlastic > 0) {
           bytes += generator.text('- $totalPlastic Plastik');
        }
        if (totalWood > 0) {
           bytes += generator.text('- $totalWood Tahta');
        }
        if (totalEuro > 0) {
           bytes += generator.text('- $totalEuro Euro');
        }

        bytes += generator.text('DAGILIM (Firma):', styles: const PosStyles(bold: true, underline: true));
        firmCounts.forEach((firm, count) {
            // "30 Beypilic" style
            bytes += generator.text('- $firm : $count Adet'); 
        });

        bytes += generator.hr();
    });

    // Signature Area
    bytes += generator.feed(1);
    bytes += generator.row([
        PosColumn(text: '.', width: 1),
        PosColumn(text: 'TESLIM ALAN', width: 10, styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: '.', width: 1),
    ]);
     bytes += generator.feed(3);
    bytes += generator.row([
        PosColumn(text: '.', width: 1),
        PosColumn(text: '( Imza )', width: 10, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: '.', width: 1),
    ]);
    bytes += generator.text('......................', styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(2);
    
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printReturnReport(List<PalletRecord> records, DateTime date) async {
    // Simply summary: "KAÇ ADET PLASTİK İADE EDİLDİ ONDAN İBARET OLSUN"
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Logo
    try {
      final ByteData data = await rootBundle.load('assets/images/atilim_logo.png');
      final Uint8List bytesImg = data.buffer.asUint8List();
      final img.Image? image = img.decodeImage(bytesImg);
      if (image != null) {
        final resized = img.copyResize(image, width: 370);
         bytes += generator.image(resized);
      }
    } catch (e) {
      print("Logo Error: $e");
    }

    // Header
    bytes += generator.text('IADE PALET MAKBUZU', styles: const PosStyles(align: PosAlign.center, bold: true, width: PosTextSize.size2, height: PosTextSize.size2));
    bytes += generator.text('Tarih: ${DateFormat('dd.MM.yyyy').format(date)}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // Calculate Totals (1 Record = 1 Pallet)
    int totalPlastic = 0;
    int totalWood = 0;
    
    for (var r in records) {
        if (r.palletType == 'Plastik') totalPlastic++;
        else if (r.palletType == 'Tahta') totalWood++;
    }
    
    final totalTotal = records.length;

    bytes += generator.text('IADE EDILEN:', styles: const PosStyles(bold: true, underline: true));
    
    if (totalPlastic > 0) {
      bytes += generator.row([
        PosColumn(text: 'PLASTIK:', width: 6),
        PosColumn(text: '$totalPlastic ADET', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size2, height: PosTextSize.size2)),
      ]);
    }
    
    if (totalWood > 0) {
      bytes += generator.row([
        PosColumn(text: 'TAHTA:', width: 6),
        PosColumn(text: '$totalWood ADET', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size2, height: PosTextSize.size2)),
      ]);
    }
    
    bytes += generator.hr();
    bytes += generator.row([
        PosColumn(text: 'GENEL TOPLAM:', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: '$totalTotal Palet', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, width: PosTextSize.size1, height: PosTextSize.size1)),
    ]);
    bytes += generator.hr();
    
    bytes += generator.feed(1);

    // Extract Driver/Plate info from notes
    // Format: 'İade Eden: X | Şoför: Y | Plaka: Z'
    Set<String> drivers = {};
    Set<String> plates = {};
    Set<String> deliverers = {}; // İade Eden

    for (var r in records) {
       if (r.note.contains('|')) {
          final parts = r.note.split('|');
          for (var p in parts) {
             p = p.trim();
             if (p.startsWith('Şoför:')) drivers.add(p.replaceFirst('Şoför:', '').trim());
             if (p.startsWith('Plaka:')) plates.add(p.replaceFirst('Plaka:', '').trim());
             if (p.startsWith('İade Eden:')) deliverers.add(p.replaceFirst('İade Eden:', '').trim());
          }
       }
    }

    if (drivers.isNotEmpty || plates.isNotEmpty || deliverers.isNotEmpty) {
        bytes += generator.text('TESLIMAT BILGILERI:', styles: const PosStyles(bold: true, underline: true));
        if (deliverers.isNotEmpty) bytes += generator.text('Teslim Eden: ${deliverers.join(", ")}');
        if (drivers.isNotEmpty) bytes += generator.text('Sofor: ${drivers.join(", ")}');
        if (plates.isNotEmpty) bytes += generator.text('Plaka: ${plates.join(", ")}');
        bytes += generator.hr();
    }
    
    bytes += generator.feed(1);

    // Signatures (Eden LEFT, Alan RIGHT)
    bytes += generator.row([
        PosColumn(text: 'TESLIM EDEN', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: 'TESLIM ALAN', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
    ]);
     bytes += generator.feed(3);
    bytes += generator.row([
        PosColumn(text: '( Imza )', width: 6, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: '( Imza )', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    
    bytes += generator.feed(2);
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printReturnReceipt(String firm, String type, int count, String entryDate, String info) async {
     if (!await isConnected()) return;
     
     final profile = await CapabilityProfile.load();
     final generator = Generator(PaperSize.mm58, profile);
     List<int> bytes = [];
     
     // Logo
    try {
      final ByteData data = await rootBundle.load('assets/images/atilim_logo.png');
      final Uint8List bytesImg = data.buffer.asUint8List();
      final img.Image? image = img.decodeImage(bytesImg);
      if (image != null) {
        final resized = img.copyResize(image, width: 370);
         bytes += generator.image(resized);
      }
    } catch (e) {
      print("Logo Error: $e");
    }
    
    bytes += generator.text('IADE FISI', styles: const PosStyles(align: PosAlign.center, bold: true, width: PosTextSize.size2, height: PosTextSize.size2));
    bytes += generator.text('Tarih: $entryDate', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    
    bytes += generator.text('Firma:', styles: const PosStyles(bold: true));
    bytes += generator.text(firm, styles: const PosStyles(width: PosTextSize.size2, height: PosTextSize.size2));
    bytes += generator.feed(1);
    
    bytes += generator.row([
       PosColumn(text: 'Tip:', width: 6),
       PosColumn(text: type, width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
       PosColumn(text: 'Adet:', width: 6),
       PosColumn(text: '$count', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
    ]);
    
    bytes += generator.hr();
    // Parse Info
    String deliverer = '';
    String driver = '';
    String plate = '';

    if (info.contains('|')) {
        final parts = info.split('|');
        for (var p in parts) {
            p = p.trim();
            if (p.startsWith('İade Eden:')) deliverer = p.replaceFirst('İade Eden:', '').trim();
            if (p.startsWith('Şoför:')) driver = p.replaceFirst('Şoför:', '').trim();
            if (p.startsWith('Plaka:')) plate = p.replaceFirst('Plaka:', '').trim();
        }
    } else {
        // Fallback
        deliverer = info;
    }

    bytes += generator.text('TESLIMAT BILGILERI:', styles: const PosStyles(bold: true, underline: true));
    if (deliverer.isNotEmpty) bytes += generator.text('Teslim Eden: $deliverer');
    if (driver.isNotEmpty) bytes += generator.text('Sofor: $driver');
    if (plate.isNotEmpty) bytes += generator.text('Plaka: $plate');
    
    bytes += generator.hr();
    bytes += generator.feed(1);
    
    // Signatures (Eden LEFT, Alan RIGHT)
    bytes += generator.row([
        PosColumn(text: 'TESLIM EDEN', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(text: 'TESLIM ALAN', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
    ]);
     bytes += generator.feed(3);
    bytes += generator.row([
        PosColumn(text: '( Imza )', width: 6, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: '( Imza )', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    
    bytes += generator.feed(2);
    
    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
