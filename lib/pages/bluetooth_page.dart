import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart';



class BluetoothScanPage extends StatefulWidget {
  @override
  _BluetoothScanPageState createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDiscoveryResult> _devicesList = [];

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
    _startScanning();
  }

  // Überprüfe den Status des Bluetooth-Adapters
  Future<void> _checkBluetoothState() async {
    BluetoothState state = await FlutterBluetoothSerial.instance.state;
    setState(() {
      _bluetoothState = state;
    });
  }

  // Scanne nach Bluetooth Classic-Geräten
  Future<void> _startScanning() async {
    List<BluetoothDiscoveryResult> devices = [];

    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        devices.add(r);  // Füge entdeckte Geräte der Liste hinzu
      });
    }).onDone(() {
      setState(() {
        _devicesList = devices;  // Speichere alle gefundenen Geräte
      });
    });
  }

  // Verbinde mit einem Bluetooth Classic-Gerät
  Future<void> _connectToDevice(BluetoothDiscoveryResult device) async {
    await FlutterBluetoothSerial.instance.connect(device.device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Classic Scan'),
      ),
      body: Column(
        children: <Widget>[
          Text('Bluetooth State: $_bluetoothState',
            style: GoogleFonts.roboto(
              color: Colors.white70
            ),

          ),

          ElevatedButton(
            onPressed: _startScanning,
            child: Text('Start Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                BluetoothDiscoveryResult device = _devicesList[index];
                return ListTile(
                  title: Text(device.device.name ?? 'Unbekanntes Gerät'),
                  subtitle: Text(device.device.address),
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}