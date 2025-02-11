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

   late VideoPlayerController _videoController;
   late ChewieController _chewieController;
   late Chewie playerWidget;




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

     return data.asMap().entries.map((entry) {

       int index = entry.key; // index in the array
       Map<String, dynamic> item = entry.value;

       String runtimeStr = item['runtime'];
       double runtimeSeconds = _parseRuntime(runtimeStr);


       return FlSpot(index.toDouble(), runtimeSeconds.toDouble());
     }).toList();
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

  @override
  initState() {
    super.initState();
    getTimes();
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

              });
            },
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        child: Column(
          children: [

            Center(
              child: Container(
                height: 35,
                width: s.screenWidth(context) * 0.7,
                margin: EdgeInsets.only(top: 10),
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

            Center(
        child: Container(
        height: s.screenHeight(context) * 0.31,
          width: s.screenWidth(context) * 0.9,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: times.length,
            padding: const EdgeInsets.only(top: 8),
            itemBuilder: (context, indexTimes) {
              return Container(
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
              );
            },
          ),
        ),
      ),

            Container(
              height: 40,
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
                    height: 40,
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
                          height: 40, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
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
                          height: 40, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
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
                          height: 40, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
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
                          height: 40, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
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
                          height: 40, // Füge eine Höhe hinzu, um die Klickelemente größer zu machen
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
            
            Center(
              child: Container(
                margin: EdgeInsets.only(top: s.screenHeight(context) * 0.01),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Container(
                      height: 40,
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
                    Container(
                      height: 40,
                      width: s.screenWidth(context) * 0.45,
                      decoration: BoxDecoration(
                        color: basicContainerColor,
                        borderRadius: BorderRadius.circular(10)
                      ),

                      child: Center(
                        child: Text(
                          "$formatedRrightSpanBorder  -  $formatedLeftSpanBorder",
                          style: GoogleFonts.roboto(fontSize: 15, color: Colors.white),

                        ),
                      ),
                    )


                  ],
                ),
              ),
            ),

            Row(
              children: [
                Container(
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
                Container(
                    height: s.screenHeight(context) * 0.35,
                    width: s.screenWidth(context) * 0.8,
                    margin: const EdgeInsets.only(top: 15),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: SimpleLineChart(
                      dataPoints: makePoints(times),
                    )
                ),
              ],
            ),

            /*Container(
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
            ),  */

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




