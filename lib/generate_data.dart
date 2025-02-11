import 'dart:math';

import 'data/db_controller.dart';



Future<void> insertTimes(List<Map<String, dynamic>> times) async {
  DatabaseHelper db = DatabaseHelper();



  for (var time in times) {
    for (var time in times) {
      await db.insertData(time);  // Verwende die `insert`-Methode von sqflite
    }

}
}


// Funktion zum Generieren von Beispieldaten für das letzte Jahr
 Future<void> generateExampleData() async {
   DatabaseHelper db = DatabaseHelper();


DateTime endDate = DateTime(2024, 11, 12); // Enddatum: 12.11.2024
DateTime startDate = DateTime(2023, 11, 12); // Startdatum: 12.11.2023
Random random = Random();

List<Map<String, dynamic>> times = [];

// Berechne den Zeitraum in Tagen
int totalDays = endDate.difference(startDate).inDays;

// Gehe jeden Tag im Zeitraum durch
for (int i = 0; i <= totalDays; i++) {
DateTime currentDate = startDate.add(Duration(days: i));

// Generiere eine zufällige Anzahl von Datensätzen (zwischen 5 und 10)
int entriesPerDay = random.nextInt(6) + 5; // 5-10 Einträge pro Tag

// Generiere für jeden Eintrag eine zufällige runtime und ein entsprechendes Datum
for (int j = 0; j < entriesPerDay; j++) {
// Berechne die `runtime`, die über das Jahr hinweg abnimmt
double runtimeValue = max(18, 30 - (i / totalDays) * 12); // Reduziere runtime mit der Zeit
int runtimeInSeconds = runtimeValue.toInt();

// Erstelle ein `runtime` im Format HH:MM:SS.mmm
String formattedRuntime = _formatRuntime(runtimeInSeconds);

// Erstelle ein Datum, das zum aktuellen Tag passt
DateTime runtimeDate = currentDate.add(Duration(minutes: random.nextInt(24 * 60))); // zufällige Uhrzeit im Tag

times.add({
'runtime': formattedRuntime,
'runTimeDate': runtimeDate.toIso8601String(),
});
}
}

// Daten in die DB einfügen
await insertTimes(times);
}

 String _formatRuntime(int seconds) {
int minutes = seconds ~/ 60;
int remainingSeconds = seconds % 60;
return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}:000';
}
