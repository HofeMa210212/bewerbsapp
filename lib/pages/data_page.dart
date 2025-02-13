import 'dart:async';
import 'dart:ui';
import 'package:bewerbsapp/ble_controller.dart';
import 'package:bewerbsapp/custom_widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/db_controller.dart';
import '../data/global_data.dart';
import '../data/online_db_controller.dart';
import '../generate_data.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';



class s {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
}

class DataPage extends StatefulWidget {
  const DataPage({super.key});
  @override
  State<DataPage> createState() => _DataPageState();


}

class _DataPageState extends State<DataPage> {
    late var times;
   DatabaseHelper db = DatabaseHelper();
   OnlineDataBase db_online = OnlineDataBase();

   var runTimeSpanValue = 0;
   var marginContainerRunTimSpanValue = 0.0;

   bool leftArrowTaped = false;
   bool rightArrowTaped = false;

   var leftSpanBorder;
   var rightSpanBorder;

   var changeSpanTime = 200;

   var formatedLeftSpanBorder;
   var formatedRrightSpanBorder;


   var ZeitMinus =0;
   var currentTimeSpan =0;

   Timer? _leftArrowLoopTimer;
   Timer? _rightArrowLoopTimer;

   List<String> xAchseTitles = [];

   var bestThreeTimes = [];
   var urls = [];

   late VideoPlayerController _videoController;
   late ChewieController _chewieController;
   late Chewie playerWidget;


    Future<void> deleteVideo(String fileName) async {
      final bucketName = 'bewerbsViedeos'; // Name deines Buckets
      final folderPath = 'bewerbsVideos'; // Pfad zum Ordner innerhalb des Buckets
      final storage = Supabase.instance.client.storage;
      final supabase = Supabase.instance.client;

      try {
        final authResponse = await supabase.auth.signInWithPassword(
          email: 'marvin-hofer@gmx.at',
          password: 'marcmarvin',
        );

        if (authResponse.user != null) {
          print('Benutzer angemeldet: ${authResponse.user!.email}');
        } else {
          print('Fehler bei der Anmeldung');
          return;
        }
      } catch (e) {
        print('Fehler bei der Anmeldung: $e');
        return;
      }

      try {
        await storage.from(bucketName).remove(['$fileName']);
        print('Video erfolgreich gelöscht: $fileName');

      } catch (e) {
        print('Fehler beim Löschen des Videos: $e');
      }
    }

    Future<void> fetchVideoUrls() async {
      final bucketName = 'bewerbsViedeos'; // Name deines Buckets
      final folderPath = 'bewerbsVideos'; // Pfad zum Ordner innerhalb des Buckets
      final storage = Supabase.instance.client.storage;
      final supabase = Supabase.instance.client;

      try {
        final authResponse = await supabase.auth.signInWithPassword(
          email: 'marvin-hofer@gmx.at',
          password: 'marcmarvin',
        );

        if (authResponse.user != null) {
          print('Benutzer angemeldet: ${authResponse.user!.email}');
        } else {
          print('Fehler bei der Anmeldung');
          return; // Keine weiteren Schritte, wenn Auth fehlgeschlagen ist
        }
      } catch (e) {
        print('Fehler bei der Anmeldung: $e');
        return;
      }

      try {
        // Liste aller Dateien im Bucket abrufen
        final fileListResponse = await storage.from(bucketName).list(path: folderPath);

        if (fileListResponse.isEmpty) {
          print('Keine Dateien gefunden.');
          return;
        }

        List<String> videoUrls = [];

        for (var file in fileListResponse) {
          final url = await storage.from(bucketName).getPublicUrl('$folderPath/${file.name}');
          videoUrls.add(url);
        }

        print(videoUrls);
        setState(() {
          urls = videoUrls;
        });

      } catch (e) {
        print('Fehler beim Abrufen der URLs: $e');
      }
    }

   Future<void> getTimes() async {
     await syncTimes();
     await setRunTimesSpan(1);
     await setBestThreeTimes();

   }

   Future<void> getLocalTimes() async{
     var newTimes = await db.getAllData();
     setState(() {
       times = newTimes;
     });

   }

   List<FlSpot> makePoints(List<Map<String, dynamic>> data) {

     if (!data.isEmpty) {
     return data.asMap().entries.map((entry) {

       int index = entry.key;
       Map<String, dynamic> item = entry.value;

       String runtimeStr = item['runtime'];
       double runtimeSeconds = _parseRuntime(runtimeStr);


       return FlSpot(index.toDouble(), runtimeSeconds.toDouble());
     }).toList();
     }else{
       return [
         FlSpot(0, 0),
       ];
     }
   }

   Future<void> setRunTimesSpan(int value,) async {
     runTimeSpanValue = value;
     marginContainerRunTimSpanValue = (0.7 / 4 * value) - 0.7 /4;

     makeSpanDates(0);

   }

   Future<void> setTimesBySpans(DateTime leftSpan, DateTime rightSpan) async {
     

     var newTimes = await db.getData('SELECT * FROM times WHERE date(runTimeDate) BETWEEN date("$rightSpan") AND date("$leftSpan")');

     setState(() {
       times = newTimes;
       makeXAchseTitles();
     });

   }

   Future<void> makeSpanDates(int minusZeit) async {
     DateTime now = DateTime.now();
     now = DateTime(now.year, now.month, now.day); 

     switch (runTimeSpanValue) {
       case 1:
         rightSpanBorder = now.subtract(Duration(days: minusZeit));
         leftSpanBorder = now.subtract(Duration(days: minusZeit));
         break;

       case 2:
         rightSpanBorder = now.subtract(Duration(days: minusZeit*6+7));
         leftSpanBorder = now.subtract(Duration(days: (minusZeit-1) *7 +7) );
         break;

       case 3:
         int targetYear = now.year;
         int targetMonth = now.month - minusZeit;
         while (targetMonth < 1) {
           targetMonth += 12;
           targetYear -= 1;
         }
          rightSpanBorder = DateTime(targetYear, targetMonth, 1);
          leftSpanBorder = DateTime(targetYear, targetMonth + 1, 1).subtract(const Duration(days: 1));
          break;
       case 4:
         int targetYear = now.year - minusZeit;
         rightSpanBorder = DateTime(targetYear, 1, 1);
         leftSpanBorder = DateTime(targetYear + 1, 1, 1).subtract(const Duration(days: 1)); break;
       
       case 5:
       // Query to get the earliest and latest runTimeDate
         var rightSpanBorderResult = await db.getData("SELECT * FROM times ORDER BY runTimeDate ASC LIMIT 1");
         var leftSpanBorderResult = await db.getData("SELECT * FROM times ORDER BY runTimeDate DESC LIMIT 1");

         String rightSpanBorderString = rightSpanBorderResult[0]['runTimeDate'].toString(); // Adjust based on actual result format
         String leftSpanBorderString = leftSpanBorderResult[0]['runTimeDate'].toString();  // Adjust based on actual result format

         rightSpanBorder = DateTime.parse(rightSpanBorderString);
         leftSpanBorder = DateTime.parse(leftSpanBorderString);
         
     }


     setState(() {
       formatedLeftSpanBorder = "${leftSpanBorder.year}-${leftSpanBorder.month.toString().padLeft(2, '0')}-${leftSpanBorder.day.toString().padLeft(2, '0')}";
        formatedRrightSpanBorder = "${rightSpanBorder.year}-${rightSpanBorder.month.toString().padLeft(2, '0')}-${rightSpanBorder.day.toString().padLeft(2, '0')}";
     });

    setTimesBySpans(leftSpanBorder, rightSpanBorder);
   }

   void makeXAchseTitles(){

     switch(runTimeSpanValue){

       case 1:
        xAchseTitles.clear();
        List<double> timeList = [];
        for(var time in times){
          timeList.add(_parseRuntime(time["runtime"]));
        }
        timeList.sort((a, b) => b.compareTo(a));

        setState(() {
          var firstTime = timeList[0];
          for(var i = 0; i < timeList[0]; i = i+2){
            xAchseTitles.add(i.toString());
          }
          xAchseTitles = xAchseTitles.reversed.toList();
        });


     }
   }

   Future<void> setBestThreeTimes() async{
     var newBestThreeTimes = await db.getData("SELECT * FROM times ORDER BY runtime ASC");

     setState(() {
       bestThreeTimes = newBestThreeTimes;
     });


   }

   Future<void> syncTimes() async{
     await db_online.connect();
     var newTimes = await db_online.getData("SELECT * FROM times");
      db.deleteTable("times");


     for(var time in newTimes){
       print(time['runTimeDate'].runtimeType);
       print(time['runtime'].runtimeType);
       print(time['videoFileName'].runtimeType); // Gibt den Typ der zurückgegebenen Spalte aus

       db.inserNewTime( time["runtime"], time["id"], time["runTimeDate"], time["videoFileName"]);
     }

     await db_online.closeConnection();

   }

   String filterUrl(String filename){
      var videoUrl = "";

      for(var url in urls){
        if(url.contains(filename))  videoUrl =url;
      }

      return videoUrl;
    }

    Future<void> _openUrl(String url) async {

      print(url);
      try {
        final Uri uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Externe App wie den Browser verwenden
          );
        } else {
          throw 'Konnte URL nicht öffnen: $url';
        }
      } catch (e) {
        print('Fehler beim Öffnen der URL: $e');
      }
    }



    @override
  initState() {
    super.initState();
    getTimes();
    fetchVideoUrls();
  }

  @override
  void dispose() {
    super.dispose();
    _videoController.dispose();
    _chewieController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: const Text("Daten"),
        backgroundColor: basicAppRed,
        centerTitle: true,

        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            color: Colors.black87,
            onPressed: () {
              setState(()  {
                 getTimes();
                 fetchVideoUrls();

              });
            },
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        child: Column(
          children: [

            //Container zum Anzeigen der Anzahl der Läufe
            Center(
              child: Container(
                height: s.screenHeight(context) * 0.04,
                width: s.screenWidth(context) * 0.7,
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.01),
                decoration: BoxDecoration(
                  color: basicContainerColor,
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Center(
                  child: Text(
                    "${times.length} Läufe",
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 20
                    ),
                  ),
                ),
              ),
            ),

            //Container zum Anzeigen der Zeiten
            Center(
              child: Container(
              height: s.screenHeight(context) * 0.28,
              width: s.screenWidth(context) * 0.9,
              margin:  EdgeInsets.only(top: s.screenHeight(context) * 0.01),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: times.length,
                padding: const EdgeInsets.only(top: 8),
                itemBuilder: (context, indexTimes) {
                  return GestureDetector(
                    onLongPress: (){
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                        transitionDuration: Duration(milliseconds: 150),

                        pageBuilder: (context, anim1, anim2) {
                          return AlertDialog(

                            backgroundColor: Colors
                                .grey[900], // Hintergrundfarbe des Dialogs
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16), // Abgerundete Ecken
                            ),
                            title: Text(
                              "Lauf mit der Id: "+times[indexTimes]["id"].toString(),
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 20,
                              ),
                            ),
                            content: Container(
                              height: 250,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Datum: " + times[indexTimes]["runTimeDate"].toString().substring(0,10),
                                    style: GoogleFonts.roboto(
                                      color: Colors.white70,
                                      fontSize: 17,
                                    ),

                                  ),
                                  Text(
                                    "Uhrzeit: " + times[indexTimes]["runTimeDate"].toString().substring(10,16),
                                    style: GoogleFonts.roboto(
                                      color: Colors.white70,
                                      fontSize: 17,
                                    ),

                                  ),
                                  Text(
                                    "Laufzeit: " + times[indexTimes]["runtime"].toString(),
                                    style: GoogleFonts.roboto(
                                      color: Colors.white70,
                                      fontSize: 17,
                                    ),

                                  ),
                                  
                              (times[indexTimes]["videoFileName"] != "") ?
                              GestureDetector(
                                onTap: () {
                                  _openUrl(filterUrl(times[indexTimes]["videoFileName"]));
                                },
                                child: Container(
                                  width: 45,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Image(
                                    fit: BoxFit.cover,
                                    image: AssetImage('assets/img/placeholder.png')
                                    ,

                                  ),
                                ),
                              ) : Container(),


                                ],
                              ),
                            ),


                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pop(); // Dialog schließen, wenn abgebrochen wird
                                },
                                child: Text(
                                  "Abbrechen",
                                  style: GoogleFonts.roboto(
                                    color: Colors.white70,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(context)
                                      .pop(); // Dialog schließen nach dem Löschen
                                },
                                child: Text(
                                  "Löschen",
                                  style: GoogleFonts.roboto(
                                    color: Colors
                                        .red, // Rote Farbe für die Löschen-Schaltfläche
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        transitionBuilder: (context, anim1, anim2, child) {
                          return Transform.scale(
                            scale: anim1.value,
                            child: Opacity(
                              opacity: anim1.value,
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: s.screenWidth(context) * 0.8,
                      height: 40,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: basicContainerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                                await db_online.connect();
                              db.deleteTime(times[indexTimes]["id"].toString());

                              if(times[indexTimes]["videoFileName"] != "") {
                                deleteVideo(times[indexTimes]["videoFileName"]);
                              }

                              await db_online.deleteTime(times[indexTimes]["id"]);

                              await db_online.closeConnection();
                              getLocalTimes();
                            },
                            child: SizedBox(
                              width: s.screenWidth(context) * 0.1,
                              height: 40,
                              child: Icon(
                                Icons.remove_circle_outline,
                                color: basicAppRed,
                                size: 25,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                times[indexTimes]["runtime"],
                                style: GoogleFonts.roboto(fontSize: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      ),

            //Cotainer zum auswählen der Zeitspannen
            Container(
              height: s.screenHeight(context) * 0.045,
              width: s.screenWidth(context) * 0.875,
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
                    height: s.screenHeight(context) * 0.05,
                    width: s.screenWidth(context) * 0.7 / 4,
                    margin: EdgeInsets.only(left: s.screenWidth(context) * marginContainerRunTimSpanValue),
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
                            setRunTimesSpan(1);
                            ZeitMinus = 0;
                            currentTimeSpan = 0;
                          });
                        },
                        child: Container(
                          width: s.screenWidth(context) * 0.7 / 4,
                          height: s.screenHeight(context) * 0.05, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                          alignment: Alignment.center, // Zentriert den Text
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Setzt eine transparente Farbe
                          ),
                          child: const Center(child: Text("Heute", style: TextStyle(color: Colors.white))),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            setRunTimesSpan(2);
                            ZeitMinus = 0;
                            currentTimeSpan =1;
                          });
                        },
                        child: Container(
                          width: s.screenWidth(context) * 0.7 / 4,
                          height: s.screenHeight(context) * 0.05, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                          alignment: Alignment.center, // Zentriert den Text
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Setzt eine transparente Farbe
                          ),
                          child: const Center(child: Text("1 W", style: TextStyle(color: Colors.white))),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            setRunTimesSpan(3);
                            ZeitMinus = 0;
                            currentTimeSpan =2;

                          });
                        },
                        child: Container(
                          width: s.screenWidth(context) * 0.7 / 4,
                          height: s.screenHeight(context) * 0.05, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                          alignment: Alignment.center, // Zentriert den Text
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Setzt eine transparente Farbe
                          ),
                          child: const Center(child: Text("1 M", style: TextStyle(color: Colors.white))),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            setRunTimesSpan(4);
                            ZeitMinus = 0;
                            currentTimeSpan = 3;

                          });
                        },
                        child: Container(
                          width: s.screenWidth(context) * 0.7 / 4,
                          height: s.screenHeight(context) * 0.05,
                          alignment: Alignment.center, // Zentriert den Text
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Setzt eine transparente Farbe
                          ),
                          child: const Center(child: Text("1 J", style: TextStyle(color: Colors.white))),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            setRunTimesSpan(5);
                            ZeitMinus = 0;
                            currentTimeSpan = 4;

                          });
                        },
                        child: Container(
                          width: s.screenWidth(context) * 0.7 / 4,
                          height: s.screenHeight(context) * 0.05, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
                          alignment: Alignment.center, // Zentriert den Text
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Setzt eine transparente Farbe
                          ),
                          child: const Center(child: Text("Alle", style: TextStyle(color: Colors.white))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            //Container zum wechseln der Zeitspannen und Anzeige der aktuellen Zeitspanne
            Center(
              child: Container(
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.01),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    //Container zum wechseln der Zeitspanne
                    Container(
                      height: s.screenHeight(context) * 0.045,
                      width: s.screenWidth(context) * 0.3,
                      decoration: BoxDecoration(
                        color: basicContainerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Row(

                        children: [
                          GestureDetector(
                            onTapDown: (_) {

                              setState(() {
                                leftArrowTaped = true;
                              });

                              _leftArrowLoopTimer = Timer.periodic(Duration(milliseconds: changeSpanTime), (timer) {
                                setState(() {
                                 
                                  ZeitMinus ++;

                                  makeSpanDates(ZeitMinus);
                                   
                                });
                              });


                              
                            },
                            onTapUp: (_) {


                              if (_leftArrowLoopTimer != null) {
                                _leftArrowLoopTimer!.cancel();
                                _leftArrowLoopTimer = null;
                              }

                              setState(() {
                                leftArrowTaped = false;
                                ZeitMinus ++;
                                makeSpanDates(ZeitMinus);
                              });
                            },



                            child: Container(
                              height: 40,
                              width: s.screenWidth(context) * 0.15,
                              decoration: BoxDecoration(
                                  color: leftArrowTaped ? basicAppRed : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10)
                              ),
                              child: Center(
                                child: Container(
                                  child: const Icon(
                                    Icons.arrow_left,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(

                            onTapDown: (_) {
                              _rightArrowLoopTimer = Timer.periodic(Duration(milliseconds: changeSpanTime), (timer) {
                                setState(() {
                                  if(ZeitMinus> 0) ZeitMinus --;


                                  makeSpanDates(ZeitMinus);
                                });
                              });

                              setState(() {
                                rightArrowTaped = true;
                              });
                            },
                            onTapUp: (_) {


                              if (_rightArrowLoopTimer != null) {
                                _rightArrowLoopTimer!.cancel();
                                _rightArrowLoopTimer = null;
                              }

                              setState(() {
                                rightArrowTaped = false;
                                if(ZeitMinus > 0) ZeitMinus --;

                                makeSpanDates(ZeitMinus);
                              });
                            },


                            child: Container(
                              height: 40,
                              width: s.screenWidth(context) * 0.15,
                              decoration: BoxDecoration(
                                  color: rightArrowTaped ? basicAppRed : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10)
                              ),
                              child: Center(
                                child: Container(
                                  child: const Icon(
                                    Icons.arrow_right,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    //Container zum Anzeigen der aktuellen Zeitspanne
                    Container(
                      height: s.screenHeight(context) * 0.045,
                      width: s.screenWidth(context) * 0.45,
                      decoration: BoxDecoration(
                        color: basicContainerColor,
                        borderRadius: BorderRadius.circular(10)
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: FittedBox(
                          child: Text(
                            "$formatedRrightSpanBorder  -  $formatedLeftSpanBorder",
                            style: GoogleFonts.roboto(fontSize: 15, color: Colors.white),

                          ),
                        ),
                      ),
                    )


                  ],
                ),
              ),
            ),

            //Container zum anzeigen der Daten
            Container(
              height: s.screenHeight(context) * 0.37,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /*Container(
                    height: s.screenHeight(context) * 0.35,
                    width: s.screenWidth(context) * 0.1,
                    color: Colors.transparent,

                    child: Column(
                      children: List.generate(xAchseTitles.length, (indexXAxes){
                        return Container(
                          height: s.screenHeight(context) * 0.35 / xAchseTitles.length,
                          child: Center(
                            child: Text(xAchseTitles[indexXAxes]),
                          ),
                        );
                      })
                    ),
                  ),

                   */


                  Container(
                      height: s.screenHeight(context) * 0.45,
                      width: s.screenWidth(context) * 0.9,
                      margin: const EdgeInsets.only(top: 15),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: SimpleLineChart(
                        dataPoints: makePoints(times),
                        times: times,
                      )
                  ),
                ],
              ),
            ),

            /*
             Container(
              margin: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    height: 140,
                    width: s.screenWidth(context) * 0.4,
                    decoration: BoxDecoration(
                      color: basicContainerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(min(max(bestThreeTimes.length, bestThreeTimes.length), 5), (indexBestTimes){
                          return Container(
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Color(0x77121212))
                                )
                            ),
                            child: Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(left: 10),
                                    child: Text(
                                      (indexBestTimes +1).toString() + ".",
                                      style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontSize: 20
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(left: 30),
                                    child: Text(
                                      _parseRuntime(bestThreeTimes[indexBestTimes]["runtime"]).toString() + " s",
                                      style: GoogleFonts.roboto(
                                          color: Colors.white, fontSize: 20),
                                    ),
                                  ),
                                ]
                            ),
                          );
                        })
                    ),
                  ),
                  Container(
                    height: 140,
                    width: s.screenWidth(context) * 0.4,
                    decoration: BoxDecoration(
                      color: basicContainerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(

                    ),
                  ),
                ],
              ),
            ),
             */

          ]
        ),
      ),
    );
  }
}

double _parseRuntime(String runtime) {
  List<String> parts = runtime.split(':');
  int minutes = int.parse(parts[0]);
  int seconds = int.parse(parts[1]);
  double mSeconds =(double.parse(parts[2]) / 1000 * 100).floor() / 100;
  return minutes * 60 + seconds + mSeconds;
}




