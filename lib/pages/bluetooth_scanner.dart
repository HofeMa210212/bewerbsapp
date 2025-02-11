import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BlePage extends StatefulWidget {
  @override
  _BlePageState createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  DiscoveredDevice? _device;
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  String? receivedData;

  @override
  void dispose() {
    _scanSubscription?.cancel();  // Stoppe den Scan, wenn die Seite verlassen wird
    _ble.deinitialize();
    super.dispose();
  }

  void _startScan() {
    _scanSubscription = _ble.scanForDevices(withServices: []).listen(
          (device) {
        if (device.name == "ESP32_Bluetooth_Device") {
          setState(() {
            _device = device;
          });
          _scanSubscription?.cancel(); // Scan stoppen
          _connectToDevice(device.id);
          print("Mit Bewerbs ESP verbunden");
        }
      },
      onError: (error) {
        print("Scan Fehler: $error");
      },
    );
  }

  void _connectToDevice(String deviceId) {
    _ble.connectToDevice(id: deviceId).listen(
          (connectionState) {
        print("Verbindungsstatus: ${connectionState.connectionState}");
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          print("Verbunden mit $deviceId");
          _ble.subscribeToCharacteristic(
            QualifiedCharacteristic(
              serviceId: Uuid.parse("12345678-1234-1234-1234-1234567890ab"),
              characteristicId: Uuid.parse("12345678-1234-1234-1234-1234567890cd"),
              deviceId: deviceId,
            ),
          ).listen(
                (data) {
              setState(() {
                receivedData = String.fromCharCodes(data);
                print("Empfangene Daten: $receivedData");
                if (receivedData == "1") {
                  // Hier kannst du den Timer stoppen oder eine andere Aktion auslösen
                }
              });
            },
            onError: (error) {
              print("Fehler beim Empfangen von Daten: $error");
            },
          );
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          print("Verbindung zu $deviceId getrennt");
        }
      },
      onError: (error) {
        print("Fehler bei der Verbindung: $error");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Geräte"),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning
                ? null
                : () {
              _startScan();
              setState(() {
                _isScanning = true;
              });
            },
          ),
        ],
      ),
      body: _device == null
          ? Center(
        child: _isScanning
            ? const CircularProgressIndicator()
            : const Text("Keine Geräte gefunden. Starte einen Scan."),
      )
          : ListView(
        children: [
          ListTile(
            title: Text(_device!.name.isEmpty
                ? "Unbekanntes Gerät"
                : _device!.name),
            subtitle: Text("ID: ${_device!.id}"),
            trailing: ElevatedButton(
              onPressed: () {
                _connectToDevice(_device!.id);
              },
              child: const Text("Verbinden"),
            ),
          ),
          if (receivedData != null)
            ListTile(
              title: Text("Empfangene Daten: $receivedData"),
            ),
        ],
      ),
    );
  }
}
