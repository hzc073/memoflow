import 'app_database.dart';

class DatabaseRegistry {
  DatabaseRegistry._();

  static final Map<String, _DatabaseRegistryEntry> _databases =
      <String, _DatabaseRegistryEntry>{};

  static AppDatabase acquire(String dbName, {AppDatabase Function()? create}) {
    final existing = _databases[dbName];
    if (existing != null) {
      existing.activeLeases += 1;
      return existing.db;
    }

    final db = (create ?? (() => AppDatabase(dbName: dbName)))();
    _databases[dbName] = _DatabaseRegistryEntry(db: db, activeLeases: 1);
    return db;
  }

  static void release(String dbName) {
    final entry = _databases[dbName];
    if (entry == null) return;
    if (entry.activeLeases > 0) {
      entry.activeLeases -= 1;
    }
  }

  static Future<void> closeAll() async {
    final snapshot = _databases.values
        .map((entry) => entry.db)
        .toList(growable: false);
    _databases.clear();
    for (final db in snapshot) {
      try {
        await db.close();
      } catch (_) {}
    }
  }
}

class _DatabaseRegistryEntry {
  _DatabaseRegistryEntry({required this.db, required this.activeLeases});

  final AppDatabase db;
  int activeLeases;
}
