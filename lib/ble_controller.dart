import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  final FlutterReactiveBle ble = FlutterReactiveBle();
  late final Stream<List<DiscoveredDevice>> scanResult;

  BleController() {
    scanResult = ble.scanForDevices(
      withServices: [], // Hier kannst du bestimmte Service-UUIDs angeben, falls benötigt
      scanMode: ScanMode.balanced,
    ).map((device) => [device]).asBroadcastStream(); // Mappt die Scan-Ergebnisse auf eine Liste von Geräten
  }

  Future<void> scanDevices() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted) {
      // Starte den Scan
      ble.scanForDevices(withServices: []).listen((device) {
        print('Gefundenes Gerät: ${device.name}, RSSI: ${device.rssi}');
      });


    } else {
      print("Bluetooth-Berechtigungen nicht erteilt.");
    }
  }
}
