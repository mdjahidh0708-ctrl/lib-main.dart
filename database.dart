import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;

  Future<void> init() async {
    final base = await getDatabasesPath();
    final path = join(base, 'dainik_ay_bay.db');
    _db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE wallets (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)');
          await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_income INTEGER NOT NULL DEFAULT 0)');
          for (final w in ['Cash', 'Bank', 'bKash', 'Nagad', 'Rocket']) {
            await db.insert('wallets', {'name': w});
          }
          for (final c in ['খাবার', 'যাতায়াত', 'বাজার', 'বিল', 'স্বাস্থ্য', 'অন্যান্য']) {
            await db.insert('categories', {'name': c, 'is_income': 0});
          }
          for (final c in ['বেতন', 'ব্যবসা', 'ফ্রিল্যান্স', 'অন্যান্য আয়']) {
            await db.insert('categories', {'name': c, 'is_income': 1});
          }
        }
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_income INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE transactions ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT NOT NULL, category TEXT NOT NULL, '
          'amount REAL NOT NULL, is_income INTEGER NOT NULL, '
          'wallet TEXT NOT NULL, date TEXT NOT NULL)',
        );
      },
    );
  }

  Database get db => _db!;

  Future<int> insert(Map<String, Object?> data) =>
      db.insert('transactions', data);

  Future<List<Map<String, Object?>>> all() =>
      db.query('transactions', orderBy: 'id DESC');

  Future<int> delete(int id) =>
      db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> exportAll() =>
      db.query('transactions', orderBy: 'id ASC');

  Future<void> replaceAll(List<Map<String, Object?>> rows) async {
    await db.transaction((txn) async {
      await txn.delete('transactions');
      for (final row in rows) {
        final data = Map<String, Object?>.from(row);
        data.remove('id');
        await txn.insert('transactions', data);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getWallets() async {
    final db = await database;
    return db.query('wallets', orderBy: 'name ASC');
  }

  Future<int> addWallet(String name) async {
    final db = await database;
    return db.insert('wallets', {'name': name.trim()});
  }

  Future<int> deleteWallet(int id) async {
    final db = await database;
    return db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getCategories({bool? income}) async {
    final db = await database;
    if (income == null) {
      return db.query('categories', orderBy: 'name ASC');
    }
    return db.query('categories',
        where: 'is_income = ?', whereArgs: [income ? 1 : 0],
        orderBy: 'name ASC');
  }

  Future<int> addCategory(String name, bool income) async {
    final db = await database;
    return db.insert('categories', {
      'name': name.trim(),
      'is_income': income ? 1 : 0,
    });
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
