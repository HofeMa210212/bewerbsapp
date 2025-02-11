import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'db_times.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS times (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              runtime TEXT, -- Zeit im Format HH:MM:SS.mmm
              runTimeDate DATETIME DEFAULT CURRENT_TIMESTAMP,
              videoFileName VARCHAR(255) DEFAULT '',
              formatedDate TEXT GENERATED ALWAYS AS (strftime('%d.%m.%Y', runTimeDate)) STORED
          )
          ''');
      },
    );
  }


  Future<void> execute(String sql) async{
    final db = await database;
    await db.execute(sql);
  }

  Future<void> insertData(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('times', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> inserNewTime(String runTime, int id, DateTime date, String filenmae ) async {
    final db = await database;
    await db.execute('''INSERT INTO times (runtime,id,runTimeDate,videoFileName) VALUES ('$runTime', '$id', '$date', '$filenmae');''');

  }

  Future<void> deleteTime(String id) async {
    final db = await database;
    await db.execute('''DELETE FROM times WHERE id = $id''');
  }

  Future<void> deleteTable(String table) async{
    final db = await database;
    await db.execute("DELETE FROM $table");
  }

  Future<List<Map<String, dynamic>>> getAllData() async {
    final db = await database;
    return await db.query('times');
  }

  Future<List<Map<String, Object?>>> getData(String sql) async {
    final db = await database; // Deine Datenbankverbindung
    var data = await db.rawQuery(sql); // rawQuery für SELECT-Abfragen

    return data; // Gibt die abgerufenen Daten als Liste von Maps zurück
  }


}
