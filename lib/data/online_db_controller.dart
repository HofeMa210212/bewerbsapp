import 'package:mysql1/mysql1.dart';

class OnlineDataBase {
  static final OnlineDataBase _instance = OnlineDataBase._internal();

  factory OnlineDataBase() {
    return _instance;
  }

  OnlineDataBase._internal();

  late MySqlConnection _connection;

  // Verbindung zur MySQL-Datenbank herstellen
  Future<void> connect() async {
    try {
      final settings = ConnectionSettings(
        host: 's7l52.h.filess.io',
        port: 3307,
        user: 'bwgReichenau_saddletorn',
        password: 'af7f3a3851902c7f7decfab9b6ca4ab708c5f71e',
        db: 'bwgReichenau_saddletorn',
      );

      _connection = await MySqlConnection.connect(settings);
      print('Erfolgreich mit der Datenbank verbunden.');

      await createTable(); // Tabelle erstellen
    } catch (e) {
      print('Fehler bei der Verbindung zur Datenbank: $e');
    } finally {

      print('Verbindungsversuch abgeschlossen.');
    }
  }

  Future<void> createTable() async {


    await _connection.query('''    
      CREATE TABLE IF NOT EXISTS times (
      id INT AUTO_INCREMENT PRIMARY KEY,
      runtime VARCHAR(255),  -- Zeit im Format HH:MM:SS
      runTimeDate DATETIME DEFAULT CURRENT_TIMESTAMP,
      videoFileName VARCHAR(255) DEFAULT '',
      formatedDate VARCHAR(10) AS (DATE_FORMAT(runTimeDate, '%d.%m.%Y')) STORED
      );
    ''');
  }

  // Daten einfügen
  Future<void> insertData(String runTime, {String? filename}) async {
    if (filename != null) {
      // Wenn der filename angegeben ist, füge ihn auch ein
      await _connection.query(
        '''INSERT INTO times (runtime, videoFileName) VALUES ('$runTime', '$filename')''');
    } else {
      // Wenn nur runTime angegeben ist, füge nur dieses ein
      await _connection.query('''INSERT INTO times (runtime) VALUES ('$runTime')''');
    }
  }


  Future<void> insertDataID(String runTime, int id) async {
    await _connection.query('''INSERT INTO times (runtime, id) VALUES ('$runTime', '$id');''');
  }


  // Datensatz löschen
  Future<void> deleteTime(int id) async {
    await _connection.query(
      'DELETE FROM times WHERE id = ?',
      [id],
    );
  }

  Future<void> deleteTable(String table) async{
    await _connection.query("DELETE FROM $table");
  }

  // Alle Daten abrufen
  Future<List<Map<String, dynamic>>> getAllData() async {
    final results = await _connection.query('SELECT * FROM times');
    return results.map((row) => row.fields).toList();
  }

  Future<List<Map<String, dynamic>>> getData(String sql) async {
    final results = await _connection.query(sql);
    return results.map((row) => row.fields).toList();
  }

  Future<void> closeConnection() async {
    await _connection.close();
  }

  Future<void> addVideoUrlCollumn() async{

    await _connection.query('''
    ALTER TABLE times
    ADD COLUMN videoUrl VARCHAR(255) DEFAUL = ''  
    ''');
  }
}
