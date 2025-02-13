import 'dart:async';

import 'package:bewerbsapp/ble_controller.dart';
import 'package:bewerbsapp/custom_widgets.dart';
import 'package:bewerbsapp/pages/timer_page.dart';
import 'package:bewerbsapp/pages/video_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

import '../data/global_data.dart';
import 'data_page.dart';



class HomePage extends StatefulWidget{
  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  var _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index; // Update the current index
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

     body: IndexedStack(
       index: _currentIndex,
       children: [
         TimerPage(),
         DataPage(),
         VideoPage(),
       ],
     ),


      bottomNavigationBar: BottomNavigationBar(

        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: 'Stopuhr',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_graph_rounded),
            label: 'Ergebnise',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_call),
            label: 'Videos',
          ),

        ],
        selectedItemColor: Colors.red,
        unselectedItemColor: const Color(0xFFC5C5C5),
      ),
    );
  }
}



