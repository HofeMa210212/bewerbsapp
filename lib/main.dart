import 'package:bewerbsapp/pages/home_page.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const backgroundDarkMode = Color(0xFF121212);
const supabaseUrl = 'https://lephqbybmcnjrohtidfq.supabase.co';
const supabaseKey = String.fromEnvironment('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxlcGhxYnlibWNuanJvaHRpZGZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI0Nzg2ODYsImV4cCI6MjA0ODA1NDY4Nn0.AwNH0RTVdCUsU8N3vtli9oMD9l3OGnlnSVjPVgTkFVY');

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://lephqbybmcnjrohtidfq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxlcGhxYnlibWNuanJvaHRpZGZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI0Nzg2ODYsImV4cCI6MjA0ODA1NDY4Nn0.AwNH0RTVdCUsU8N3vtli9oMD9l3OGnlnSVjPVgTkFVY',
  );

  runApp(MyApp());

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        scaffoldBackgroundColor: backgroundDarkMode,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: backgroundDarkMode,
        ),
      ),
      home: HomePage(),
    );
  }
}

