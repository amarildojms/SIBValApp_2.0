import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/hymn.dart';

/// Espelha app/src/main/java/com/sibval/app/data/local/HymnalDatabaseHelper.kt:
/// copia o `.sqlite` do hinário certo (Cantor Cristão ou Hinário Cristão) para
/// o armazenamento do app na primeira execução, e mantém as duas conexões
/// abertas simultaneamente (uma por hinário).
class HymnalDatabase {
  HymnalDatabase._();

  static final Map<String, Database> _dbs = {};

  static Future<Database> instance(Hymnal hymnal) async {
    final existing = _dbs[hymnal.dbName];
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, hymnal.dbName);

    if (!await File(dbPath).exists()) {
      final bytes = await rootBundle.load(hymnal.assetPath);
      await Directory(databasesPath).create(recursive: true);
      await File(dbPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    final db = await openDatabase(dbPath, readOnly: true);
    _dbs[hymnal.dbName] = db;
    return db;
  }
}
