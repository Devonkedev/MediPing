import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PrescriptionDb {
  static final PrescriptionDb _instance = PrescriptionDb._();
  factory PrescriptionDb() => _instance;
  PrescriptionDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'prescriptions.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE prescriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT,
            createdAt INTEGER
          )
        ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _database;
    return db.query(
      'prescriptions',
      orderBy: 'createdAt DESC',
    );
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert('prescriptions', data);
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final db = await _database;
    await db.update(
      'prescriptions',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(
      'prescriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
