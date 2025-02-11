import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:list_all_videos/model/thumbnail_controller.dart';
import 'package:list_all_videos/thumbnail/ThumbnailTile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../data/db_controller.dart';
import '../data/global_data.dart';
import '../data/online_db_controller.dart';
import 'data_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail_imageview/video_thumbnail_imageview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class VideoPage extends StatefulWidget{

  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>{
  DatabaseHelper db = DatabaseHelper();
  OnlineDataBase db_online = OnlineDataBase();
  int stackIndex =0;
  
  var times = [];
  var urls = [];
  List<FileSystemEntity> localVideos = [];

  var selectedOrder = 0;
  var orderDirection =0;
  bool withVideo = false;

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

  Future<void> getLocalTimes(int orderStyle, int orderDirection, bool withVideo) async {
    var sql = "SELECT * FROM times";

    // Add WHERE clause if needed
    if (withVideo) {
      sql += " WHERE videoFileName != ''";
    }

    // Add ORDER BY clause if needed
    switch (orderStyle) {
      case 1:
        sql += " ORDER BY runTimeDate";
        break;
      case 2:
        sql += " ORDER BY runtime";
        break;
    }

    // Add sorting direction
    switch (orderDirection) {
      case 1:
        sql += " ASC";
        break;
      case 2:
        sql += " DESC";
        break;
    }



    var newTimes =  await db.getData(sql);

    setState(() {
        times = newTimes;
      });

  }

  Future<void> getData() async{
    await syncTimes();
    await getLocalTimes(0,0,false);
    await fetchVideoUrls();
  }

  Future<void> getLocalVideoPaths() async{
    var directory = await getApplicationDocumentsDirectory();
    final mediaFolder = Directory('${directory.path}/Media');

    if (!await mediaFolder.exists()) {
      await mediaFolder.create(recursive: true);
    }
    print(mediaFolder.path);

     directory = Directory(mediaFolder.path);
    if (await directory.exists()) {
      List<FileSystemEntity> files = directory.listSync();
      List<FileSystemEntity> videoFiles = files.where((file) {
        String path = file.path.toLowerCase();
        return path.endsWith('.mp4') || path.endsWith('.mov');
      }).toList();

      setState(() {
        localVideos.clear();
        for (var file in videoFiles) {
          localVideos.add(file);
        }
      });
    }

  }

  Future<void> _openVideo(String videoFilePath) async {
    final fileUri = Uri.parse('content://com.example.bewerbsapp.provider/media_files/${videoFilePath}');

    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri);
    } else {
      throw 'Video konnte nicht geöffnet werden: ${videoFilePath}';
    }
  }


  String filterUrl(String filename){
    var videoUrl = "";

    for(var url in urls){
      if(url.contains(filename))  videoUrl =url;
    }

    return videoUrl;
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: const Text("Videos"),
        backgroundColor: basicAppRed,
        centerTitle: true,

        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            color: Colors.black87,
            onPressed: () {
              setState(()  {
                if(stackIndex ==0) getData();
                if(stackIndex == 1) getLocalVideoPaths();
              });
            },
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Container(
            margin: EdgeInsets.only(left: 10, top: 10),
            child: Text(
              "Sotieren nach",
              style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 20
              ),
            ),
          ),

          Container(
            margin: EdgeInsets.only(top: 10, bottom: 10),
            width: s.screenWidth(context) * 1,

            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: (){
                      setState(() {
                        if(orderDirection == 1) orderDirection =2;
                        else orderDirection =1;

                        selectedOrder = 2;
                        getLocalTimes(selectedOrder, orderDirection,withVideo);
                      });
                    },
                    child: Container(
                      height: 40,
                      width: s.screenWidth(context) * 0.3,
                      decoration: BoxDecoration(
                          color: (selectedOrder ==2) ? basicSelectedContainerColor : basicContainerColor,
                          borderRadius: BorderRadius.circular(10)
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(Icons.timer, color: Colors.white70, size: 18,),
                          Text(
                            "Zeit",
                            style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 20
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: (){
                      setState(() {

                        if(orderDirection == 1) orderDirection =2;
                        else orderDirection =1;

                        selectedOrder = 1;
                        getLocalTimes(selectedOrder, orderDirection, withVideo);

                      });
                    },
                    child: Container(
                      height: 40,
                      width: s.screenWidth(context) * 0.3,
                      decoration: BoxDecoration(
                          color: (selectedOrder == 1) ? basicSelectedContainerColor : basicContainerColor,
                          borderRadius: BorderRadius.circular(10)
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(Icons.date_range, color: Colors.white70, size: 18,),
                          Text(
                            "Datum",
                            style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 20
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: (){
                      setState(() {
                        if(withVideo) withVideo = false;
                        else withVideo = true;
                        getLocalTimes(selectedOrder, orderDirection, withVideo);
                      });
                    },
                    child: Container(
                      height: 40,
                      width: s.screenWidth(context) * 0.3,
                      decoration: BoxDecoration(
                          color: (withVideo) ? basicSelectedContainerColor : basicContainerColor,
                          borderRadius: BorderRadius.circular(10)
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(Icons.ondemand_video_outlined, color: Colors.white70, size: 18,),
                          Text(
                            "Video",
                            style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 20
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: Center(
              child: Container(
                width: s.screenWidth(context) * 0.95,
                child: ListView.builder(
                  itemCount: times.length,
                  itemBuilder: (context, index) {
                    return Container(
                      height: 70,
                      margin: EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                          color: basicContainerColor,
                          borderRadius: BorderRadius.circular(8)
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: s.screenWidth(context) * 0.3,
                            margin: EdgeInsets.only(left: s.screenWidth(context) * 0.03),
                            child: Text(
                              times[index]["runtime"],
                              style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 20
                              ),
                            ),
                          ),
                          Container(
                            width: s.screenWidth(context) * 0.3,
                            margin: EdgeInsets.only(left: s.screenWidth(context) * 0.03),
                            child: Text(
                              times[index]["formatedDate"],
                              style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 20
                              ),
                            ),
                          ),

                          if(times[index]["videoFileName"] !="")...[
                            Container(
                              width: s.screenWidth(context) * 0.26,
                              margin: EdgeInsets.only(left: s.screenWidth(context) * 0.01),
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    var videoUrl = "";
                                    for (var url in urls) {
                                      if (url.contains(times[index]["videoFileName"])) {
                                        videoUrl = url;
                                      }
                                    }
                                    print("Opening URL: $videoUrl");
                                    _openUrl(videoUrl); // Ensure this function works
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
                                ),
                              ),
                            )

                          ]

                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),




        ],
      ),
    );
  }

}


