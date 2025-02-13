import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:bewerbsapp/custom_widgets.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/db_controller.dart';
import '../data/global_data.dart';
import '../data/online_db_controller.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:gal/gal.dart';


class s {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
}

class TimerPage extends StatefulWidget {
  @override
  _TimerpageState createState() => _TimerpageState();
}

class _TimerpageState extends State<TimerPage> {
  final _stopWatch = StopWatchTimer(mode: StopWatchMode.countUp);
  AudioPlayer audioPlayer = AudioPlayer();
  AudioPlayer stopSoundPlayer = AudioPlayer();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  late DiscoveredDevice _device;
  var _connectedDevice;
  var connectionStatus;
  String receivedData = "";
  StreamSubscription? _scanSubscription;

  DatabaseHelper db = DatabaseHelper();
  OnlineDataBase db_online = OnlineDataBase();
  var _currentTime = "0:00:00";

  String temperature = "";

  int waitTime = 0;

  var remeaningTime = 0;


  var timerDeleyValue = 0;
  var marginContainerDelayValue = 0.0;

  var withSound = false;
  var withVideo = false;

  //variables for the camera
  var cameras = [];
  late var camera;

  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  late Future<void> _cameraInitFuture;

  String currentVideoFileName = "";

  late FlutterSerialCommunication _flutterSerialCommunicationPlugin;
  late EventChannel _eventChannel;

  double rotation = 0;



  @override
  void initState() {
    super.initState();
    _startScan();
    _requestPermissions();
    _cameraInitFuture = getCameras();

    _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
    _eventChannel = _flutterSerialCommunicationPlugin.getSerialMessageListener();
    _connectToSerialDevice();
    _startListening();
  }

  void _connectToSerialDevice() async {
    List<DeviceInfo> availableDevices = await _flutterSerialCommunicationPlugin.getAvailableDevices();
    if (availableDevices.isNotEmpty) {
      DeviceInfo device = availableDevices[0];
      int baudRate = 115200; // Beispiel: Baudrate

      bool isConnectionSuccess = await _flutterSerialCommunicationPlugin.connect(device, baudRate,);
      if (isConnectionSuccess) {
        print("Verbindung erfolgreich");
      } else {
        print("Verbindung fehlgeschlagen");
      }
    } else {
      print("Keine verfügbaren Geräte gefunden");
    }
  }

  void _startListening() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _stopWatch.onStopTimer();
        print(event);

      });
    });
  }

  Future<void> _requestPermissions() async {
    // Liste der Berechtigungen
    Map<String, PermissionStatus> permissions = {
      "Bluetooth": await Permission.bluetooth.request(),
      "Standort": await Permission.locationWhenInUse.request(),
      "Bluetooth Connect": await Permission.bluetoothConnect.request(),
      "Bluetooth Scan": await Permission.bluetoothScan.request(),
      "USB": await Permission.manageExternalStorage.request(),
      "Kamera": await Permission.camera.request(),
      "Speicher": await Permission.storage.request(),
    };

    // Überprüfen, ob alle Berechtigungen erteilt wurden
    bool allGranted = permissions.values.every((status) => status.isGranted);

    if (allGranted) {
      print("Alle Berechtigungen erteilt. Du kannst Bluetooth, USB, Kamera und Speicher verwenden.");
      _startScan(); // Starte das Scannen
    } else {
      print("Einige Berechtigungen wurden verweigert. Funktionen könnten eingeschränkt sein.");
      permissions.forEach((permissionName, status) {
        if (!status.isGranted) {
          print("$permissionName-Berechtigung fehlt.");
        }
      });
    }
  }

  void _startScan() {
    _scanSubscription = _ble.scanForDevices(withServices: []).listen(
          (device) {
            print(device.name);
        if (device.name == "ESP32_Bluetooth_Device") {
          setState(() {
            _device = device;
          });
          _scanSubscription?.cancel(); // Stoppt das Scannen
          _connectToDevice(device.id, device.name);
          print("Mit Bewerbs ESP verbunden");
        }
      },
      onError: (error) {
        print("Scan Fehler: $error");
      },
    );
  }

  void _connectToDevice(String deviceId, String deviceName) {
    _ble.connectToDevice(id: deviceId).listen(
          (connectionState) {
        print("Verbindungsstatus: ${connectionState.connectionState}");

        setState(() {
          connectionStatus = connectionState.connectionState.toString();
        });

        if (connectionState.connectionState == DeviceConnectionState.connected) {
          print("Verbunden mit $deviceId");

          setState(() {
            _connectedDevice = deviceName;
          });


          // Subscribe to the characteristic
          _ble.subscribeToCharacteristic(
            QualifiedCharacteristic(
              serviceId: Uuid.parse("12345678-1234-1234-1234-1234567890ab"),
              characteristicId: Uuid.parse("12345678-1234-1234-1234-1234567890cd"),
              deviceId: deviceId,
            ),
          ).listen( (data) async {
            receivedData = String.fromCharCodes(data);
            print(receivedData);

            // Hier werden die empfangenen Daten verarbeiten
            buzzerBleReact(receivedData);

            },
            onError: (error) {
              print("Fehler beim Empfangen von Daten: $error");
            },
          );
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          print("Verbindung zu $deviceId getrennt");

          setState(() {
            // Wenn die Verbindung getrennt wurde, das Gerät entfernen
            _connectedDevice = null;
          });
        }
      },
      onError: (error) {
        print("Fehler bei der Verbindung: $error");
        setState(() {
          // Fehler beim Verbinden - das verbundene Gerät zurücksetzen
          _connectedDevice = null;
        });
      },
    );
  }

  void _sendDataToDevice(String deviceId, List<int> dataToSend) async {
    // Erstellen Sie die Instanz von FlutterBluePlus
    FlutterBluePlus flutterBlue = FlutterBluePlus();

    // Suchen Sie das verbundene Gerät
    BluetoothDevice? device = FlutterBluePlus.connectedDevices.firstWhere((d) => d.id.id == deviceId);

    if (device == null) {
      print("Gerät nicht verbunden");
      return;
    }

    // Definieren Sie die Service- und Charakteristik-UUIDs
    final serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");
    final characteristicUuid = Guid("12345678-1234-1234-1234-1234567890cd");

    // Entdecken Sie die Services und Charakteristiken des Geräts
    List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;

    for (BluetoothService service in services) {
      if (service.uuid == serviceUuid) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            targetCharacteristic = characteristic;
            break;
          }
        }
      }
    }

    if (targetCharacteristic == null) {
      print("Charakteristik nicht gefunden");
      return;
    }


    try {
      await targetCharacteristic.write(dataToSend, withoutResponse: false);
      print("Daten erfolgreich gesendet");
    } catch (e) {
      print("Fehler beim Senden der Daten: $e");
    }
  }

  void setTimerValue(int value){
    timerDeleyValue = value;

    marginContainerDelayValue = (0.7 / 4 * value) - 0.7 /4;

  }

  Future<void> getCameras() async {
    cameras = await availableCameras();
    camera = cameras[0];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg, // Format setzen
    );

    _initializeControllerFuture = _cameraController.initialize().then((_) async {
      if (Platform.isAndroid) {
        await _cameraController.setExposureMode(ExposureMode.auto);
        await _cameraController.lockCaptureOrientation();
      }
      setState(() {});
    });
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;

      // Bild aufnehmen
      final XFile picture = await _cameraController.takePicture();

      // Zielverzeichnis für das Bild
      final Directory externalDir = Directory('/storage/emulated/0/Pictures/BewerbsApp');
      if (!externalDir.existsSync()) {
        externalDir.createSync(recursive: true); // Ordner erstellen, falls er nicht existiert
      }

      // Neues Dateipfad
      final String newPath = '${externalDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Bild speichern
      final File savedFile = File(picture.path);
      await savedFile.copy(newPath);

      print('Bild erfolgreich gespeichert unter: $newPath');
    } catch (e) {
      print('Fehler beim Aufnehmen oder Speichern des Bildes: $e');
    }
  }

  Future<void> _stopAndSaveVideo(String name) async {
    String filename = name;
    final supabase = Supabase.instance.client;
    final storage = supabase.storage.from('bewerbsViedeos');
    String newPath = "";
    late File _file;

    try {

      final XFile videoFile = await _cameraController.stopVideoRecording();

      var directory = await getApplicationDocumentsDirectory();
      final mediaFolder = Directory('${directory.path}/Media');


      final Directory externalDir = Directory(mediaFolder.path);
      if (!externalDir.existsSync()) {
        externalDir.createSync(recursive: true); // Ordner erstellen, falls nicht vorhanden
      }

      newPath = '${externalDir.path}/$filename';

      // Video speichern
      final File savedFile = File(videoFile.path);
      await savedFile.copy(newPath);
      await Gal.putVideo('$newPath');

      print('Video erfolgreich gespeichert unter: $newPath');
    } catch (e) {
      print('Fehler beim Stoppen oder Speichern des Videos: $e');
    }


    try {
      final response = await supabase.auth.signInWithPassword(
        email: 'marvin-hofer@gmx.at',
        password: 'marcmarvin',
      );
      if (response.user != null) {
        print('Benutzer angemeldet: ${response.user!.email}');
      } else {
        print('Fehler bei der Anmeldung');
      }
    } catch (e) {
      print('Fehler bei der Anmeldung: $e');
    }


    try {
      _file = File(newPath);
      final response = await storage.upload('bewerbsVideos/${_file.uri.pathSegments.last}', _file);
      if (response.contains("error")) {
        print(response);
      }else{

        showFloatingSnackbar(context,'Datei erfolgreich hochgeladen' );
      }

    } catch (e) {
      showFloatingSnackbar(context,'Fehler beim Hochladen der Datei: $e' );

    }


  }

  void startRecordingWithDelay() {
    // Starte die Verzögerung, aber blockiere nicht das UI oder andere Prozesse
    Future.delayed(Duration(seconds: 15), () async {
      // Starte die Videoaufnahme nach 10 Sekunden
      await _cameraController.startVideoRecording();
    });
  }

  void buzzerBleReact(String data){
    if (receivedData == "1") {
      if (_stopWatch.isRunning) {
        setState(() {
          _stopWatch.onStopTimer();
          print("gestopt");
        });
        stopSoundPlayer.play(AssetSource('sounds/buzzer_sound_stop.mp3'));
      }
      else {
        print(_currentTime);
        if(_currentTime == "0:00:00"){
          withSound = true;
          if((_currentTime == "0:00:00" && withVideo) || !withVideo){
            if(_currentTime == "0:00:00"){

              final StopWatchTimer topStopwatch = StopWatchTimer(
                  mode: StopWatchMode.countDown, presetMillisecond: 1000 * waitTime,
                  onEnded: () async {

                    if(withVideo && _currentTime == "0:00:00"){

                      if(_cameraController.value.isRecordingVideo || _cameraController.value.isRecordingPaused){
                        _cameraController.stopVideoRecording();

                        startRecordingWithDelay();

                      }else{
                        startRecordingWithDelay();

                      }
                    }

                    if(withSound){
                      audioPlayer.onPlayerComplete.listen((_) {
                        setState(() {
                          _stopWatch.onStartTimer();
                        });
                      });

                      if (_currentTime == "0:00:00") {
                        await audioPlayer.play(AssetSource('sounds/angriffsBefehl.mp3'));
                      }else{
                        setState(() {
                          _stopWatch.onStartTimer();
                        });
                      }
                    }else{
                      setState(() {
                        _stopWatch.onStartTimer();
                      });
                    }


                  },
                  onChangeRawSecond: (value){
                    setState(() {
                      remeaningTime = value;
                    });
                  }
              );
              topStopwatch.onStartTimer();

            }else{
              setState(() {
                _stopWatch.onStartTimer();
              });
            }
          }
        }
      }

    }

    if(receivedData.endsWith("°C")){
      setState(() {
        temperature = receivedData.split("Â")[0];
      });
    }

  }

  @override
  void dispose() async {
    super.dispose();
    await _stopWatch.dispose();
    _cameraController.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        title: Text("Stoppuhr"),
        backgroundColor: basicAppRed,
        centerTitle: true,
        leading:
        /*Container(

          margin: EdgeInsets.only(top: 17, left: 5),
          child: Text(
            temperature + "°C",
            style: GoogleFonts.roboto(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15
            ),
          ),
        ),

         */

        IconButton(
          icon: Icon(Icons.crop_rotate),
          color: Colors.black87,
          onPressed: () {
            setState(() {
              _cameraInitFuture = getCameras();
            });

          },
        ),



        actions: [
          IconButton(
            icon: Icon(Icons.connect_without_contact),
            color: Colors.black87,
            onPressed: () {
              _startScan();
            },
          ),
          IconButton(
            icon: Icon(Icons.usb),
            color: Colors.black87,
            onPressed: () {
              _connectToSerialDevice();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              //Container zum Anzeigen des Verbuindungsstatuses mit dem Esp_32 (Buzzer)
              Container(
                height: MediaQuery.of(context).size.height * 0.04,

                child: Column(
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.02,

                      child: FittedBox(
                        child: Text(
                          (_connectedDevice != null)? _connectedDevice : "nicht verbunden",
                          style: TextStyle(
                            color: Colors.white70,

                          ),
                        ),
                      ),
                    ),

                    Container(
                      height: MediaQuery.of(context).size.height * 0.02,

                      child: FittedBox(
                        child: Text(
                          (connectionStatus != null)? connectionStatus : "",
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              //Container zum Anzeigen der Zeit
              Container(
                height: s.screenHeight(context) * 0.13,
                width: s.screenWidth(context) * 0.9,
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.03),
                child: Center(
                  child: Column(
                    children: [
                      if(remeaningTime ==0)...[
                        StreamBuilder<int>(
                          stream: _stopWatch.rawTime,
                          builder: (context, snapshot) {
                            final rawTime = snapshot.data ?? 0;
                            final minutes = (rawTime / 60000).floor();
                            final seconds = ((rawTime % 60000) / 1000).floor();
                            final milliseconds = (rawTime % 1000);

                            // Formatierung ohne führende Null bei Minute
                            _currentTime = '$minutes:${seconds.toString().padLeft(2, '0')}:${milliseconds.toString().padLeft(2, '0')}';

                            return Container(
                              height: s.screenHeight(context) * 0.13,
                              child: FittedBox(
                                child: Text(
                                  minutes > 0
                                      ? '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}'
                                      : '${seconds.toString()}.${milliseconds.toString().padLeft(3, '0')}',
                                  style: GoogleFonts.roboto( color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ]else...[
                        Center(
                          child: Container(
                            height: s.screenHeight(context) * 0.13,
                            child: FittedBox(
                              child: Text(
                                (remeaningTime).toString(),
                                style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 88
                                ),
                              ),
                            ),
                          ),

                        ),
                      ]


                    ],
                  ),


                ),
              ),

              //Container zum Anzeigen des Videos
              Container(
                height: s.screenHeight(context) * 0.25,
                color: Colors.transparent,
                child: FutureBuilder<void>(
                  future: _cameraInitFuture,
                  builder: (context, snapshot) {
                    bool isVisible = snapshot.connectionState == ConnectionState.done;

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Fehler: ${snapshot.error}'));
                    } else {
                      return Center(
                        child: Visibility(
                          visible: withVideo ? isVisible : false, // Steuert die Sichtbarkeit
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: s.screenHeight(context) * 0.25,
                              width: s.screenHeight(context) * 0.2,
                              child: RotatedBox(
                                quarterTurns: 1, // 90° im Uhrzeigersinn drehen
                                child: CameraPreview(_cameraController),
                              )

                            ),
                          ),
                        ),
                      );
                    }



                  },
                ),
              ),

              //Container zum einstellen ob mit oder ohne Video
              Container(
                height: s.screenHeight(context) * 0.045,
                width: s.screenWidth(context) * 0.5,
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.01),
                decoration: BoxDecoration(
                  color: basicContainerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: s.screenHeight(context) * 0.045,
                      width: s.screenWidth(context) * 0.5 / 2,
                      margin: EdgeInsets.only(left: withVideo ? s.screenWidth(context) * 0.5/2 : 0.0),
                      decoration: BoxDecoration(
                        color: basicAppRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              withVideo = false;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.5 / 2,
                            height: s.screenHeight(context) * 0.045,
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("Ohne Video", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              withVideo = true;
                              withSound = true;

                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.5 / 2,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("Mit Video", style: TextStyle(color: Colors.white))),
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
              ),

              //Container zum einstellen ob mit oder ohne Befehl
              Container(
                height: s.screenHeight(context) * 0.045,
                width: s.screenWidth(context) * 0.5,
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.02),
                decoration: BoxDecoration(
                  color: basicContainerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: s.screenHeight(context) * 0.045,
                      width: s.screenWidth(context) * 0.5 / 2,
                      margin: EdgeInsets.only(left: withSound ? s.screenWidth(context) * 0.5/2 : 0.0),
                      decoration: BoxDecoration(
                        color: basicAppRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              withSound = false;
                              withVideo = false;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.5 / 2,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("Ohne Befehl", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              withSound = true;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.5 / 2,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("Mit Befehl", style: TextStyle(color: Colors.white))),
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
              ),

              //Container zum einstellen der Zeit bis zum Befehl
              Container(
                height: s.screenHeight(context) * 0.045,
                width: s.screenWidth(context) * 0.7,
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.02),
                decoration: BoxDecoration(
                  color: basicContainerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: s.screenHeight(context) * 0.045,
                      width: s.screenWidth(context) * 0.7 / 4,
                      margin: EdgeInsets.only(left: s.screenWidth(context) * marginContainerDelayValue),
                      decoration: BoxDecoration(
                        color: basicAppRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              setTimerValue(1);
                              waitTime = 0;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.7 / 4,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("0 s", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              setTimerValue(2);
                              waitTime = 5;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.7 / 4,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("5 s", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              setTimerValue(3);
                              waitTime = 10;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.7 / 4,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("10 s", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              setTimerValue(4);
                              waitTime = 20;
                            });
                          },
                          child: Container(
                            width: s.screenWidth(context) * 0.7 / 4,
                            height: s.screenHeight(context) * 0.045, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                            alignment: Alignment.center, // Zentriert den Text
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Setzt eine transparente Farbe
                            ),
                            child: Center(child: Text("20 s", style: TextStyle(color: Colors.white))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              //Container für die BUttons
              Container(
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.03),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [

                    actionButton(context, 80, basicContainerColor, Colors.grey, Icon(Icons.refresh), 50, (){

                      setState(() {

                        if(_cameraController.value.isRecordingPaused || _cameraController.value.isRecordingVideo){
                          _cameraController.stopVideoRecording();
                        }

                        _stopWatch.onResetTimer();
                        audioPlayer.stop();
                      });
                    }),

                    if(_stopWatch.isRunning)...[
                      actionButton(context, 120, basicContainerColor, basicAppRed, Icon(Icons.pause), 80, (){
                        setState(() {

                          if(_cameraController.value.isRecordingVideo){
                            _cameraController.pauseVideoRecording();
                          }

                          _stopWatch.onStopTimer();
                        });
                      }),
                    ],

                    if(!_stopWatch.isRunning)...[
                      actionButton(context, 120, basicContainerColor, basicAppRed, Icon(Icons.play_arrow), 80, () async {

                        if((_currentTime == "0:00:00" && withVideo) || !withVideo){
                          if(_currentTime == "0:00:00"){

                            final StopWatchTimer topStopwatch = StopWatchTimer(
                                mode: StopWatchMode.countDown, presetMillisecond: 1000 * waitTime,
                                onEnded: () async {

                                  if(withVideo && _currentTime == "0:00:00"){

                                    if(_cameraController.value.isRecordingVideo || _cameraController.value.isRecordingPaused){
                                      _cameraController.stopVideoRecording();

                                      startRecordingWithDelay();

                                    }else{
                                      startRecordingWithDelay();

                                    }
                                  }

                                  if(withSound){
                                    audioPlayer.onPlayerComplete.listen((_) {
                                      setState(() {
                                        _stopWatch.onStartTimer();
                                      });
                                    });

                                    if (_currentTime == "0:00:00") {
                                      await audioPlayer.play(AssetSource('sounds/angriffsBefehl.mp3'));
                                    }else{
                                      setState(() {
                                        _stopWatch.onStartTimer();
                                      });
                                    }
                                  }else{
                                    setState(() {
                                      _stopWatch.onStartTimer();
                                    });
                                  }


                                },
                                onChangeRawSecond: (value){
                                  setState(() {
                                    remeaningTime = value;
                                  });
                                }
                            );
                            topStopwatch.onStartTimer();

                          }else{
                            setState(() {
                              _stopWatch.onStartTimer();
                            });
                          }
                        }

                      }),
                    ],

                    actionButton(context, 80, basicContainerColor, Colors.grey, Icon(Icons.save), 50, () async {

                      await db_online.connect();
                      await db_online.createTable();

                      setState(() {

                        if(withVideo) currentVideoFileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
                       else currentVideoFileName = "";

                        _stopWatch.onResetTimer();

                        if(withVideo) _stopAndSaveVideo(currentVideoFileName);

                      });

                      if(_currentTime != "0:00:00"){

                        await db_online.insertData(_currentTime, filename: currentVideoFileName);
                        currentVideoFileName = "";

                      }
                      await db_online.closeConnection();

                    })

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

