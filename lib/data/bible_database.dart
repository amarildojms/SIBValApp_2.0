import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Espelha app/src/main/java/com/sibval/app/data/local/BibleDatabaseHelper.kt:
/// copia o asset `.sqlite` (só-leitura, Almeida 1911, schema OpenLP) para o
/// armazenamento do app na primeira execução, depois só reabre — nunca é
/// reescrito, então mantemos uma única conexão para o processo inteiro.
class BibleDatabase {
  BibleDatabase._();

  static Database? _db;

  static Future<Database> instance() async {
    final existing = _db;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'alm1911.sqlite');

    if (!await File(dbPath).exists()) {
      final bytes = await rootBundle.load('assets/bible/alm1911.sqlite');
      await Directory(databasesPath).create(recursive: true);
      await File(dbPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    final db = await openDatabase(dbPath, readOnly: true);
    _db = db;
    return db;
  }
}
