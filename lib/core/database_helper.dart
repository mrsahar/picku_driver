import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper extends GetxService {
  static DatabaseHelper get to => Get.find();

  static const String _dbName = 'picku_driver.db';
  // Bump DB version whenever we add/modify tables.
  static const int _dbVersion = 2;

  static const String offlineLocationsTable = 'offline_locations';
  static const String rideChatMessagesTable = 'ride_chat_messages';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // Offline locations table (existing)
        await db.execute('''
          CREATE TABLE $offlineLocationsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            ride_id TEXT,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Ride chat messages table (new)
        await db.execute('''
          CREATE TABLE $rideChatMessagesTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ride_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            sender_role TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $rideChatMessagesTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ride_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              sender_role TEXT NOT NULL,
              message TEXT NOT NULL,
              timestamp INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ==================== Offline Location APIs ====================

  Future<void> insertLocation(double lat, double lng, String rideId) async {
    try {
      final db = await database;
      await db.insert(
        offlineLocationsTable,
        {
          'lat': lat,
          'lng': lng,
          'ride_id': rideId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ SAHAr DB insertLocation error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations({int limit = 50}) async {
    try {
      final db = await database;
      return await db.query(
        offlineLocationsTable,
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
        limit: limit,
      );
    } catch (e) {
      print('❌ SAHAr DB getUnsyncedLocations error: $e');
      return [];
    }
  }

  Future<void> markLocationsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final idPlaceholders = List.filled(ids.length, '?').join(',');
      await db.update(
        offlineLocationsTable,
        {'synced': 1},
        where: 'id IN ($idPlaceholders)',
        whereArgs: ids,
      );
    } catch (e) {
      print('❌ SAHAr DB markLocationsAsSynced error: $e');
    }
  }

  Future<void> deleteSyncedLocations() async {
    try {
      final db = await database;
      await db.delete(
        offlineLocationsTable,
        where: 'synced = ?',
        whereArgs: [1],
      );
    } catch (e) {
      print('❌ SAHAr DB deleteSyncedLocations error: $e');
    }
  }

  Future<int> getLocationCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $offlineLocationsTable WHERE synced = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ SAHAr DB getLocationCount error: $e');
      return 0;
    }
  }

  // ==================== Ride Chat Message APIs ====================

  Future<void> insertRideChatMessage({
    required String rideId,
    required String senderId,
    required String senderRole,
    required String message,
    required DateTime timestamp,
  }) async {
    try {
      final db = await database;
      await db.insert(
        rideChatMessagesTable,
        {
          'ride_id': rideId,
          'sender_id': senderId,
          'sender_role': senderRole,
          'message': message,
          'timestamp': timestamp.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ SAHAr DB insertRideChatMessage error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRideChatMessages(
    String rideId, {
    int limit = 200,
  }) async {
    try {
      final db = await database;
      return await db.query(
        rideChatMessagesTable,
        where: 'ride_id = ?',
        whereArgs: [rideId],
        orderBy: 'timestamp ASC',
        limit: limit,
      );
    } catch (e) {
      print('❌ SAHAr DB getRideChatMessages error: $e');
      return [];
    }
  }

  Future<void> clearRideChatMessages(String rideId) async {
    try {
      final db = await database;
      await db.delete(
        rideChatMessagesTable,
        where: 'ride_id = ?',
        whereArgs: [rideId],
      );
    } catch (e) {
      print('❌ SAHAr DB clearRideChatMessages error: $e');
    }
  }

  /// Optional retention policy: delete messages older than [olderThanDays].
  Future<void> deleteOldRideChatMessages({required int olderThanDays}) async {
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: olderThanDays))
          .millisecondsSinceEpoch;
      final db = await database;
      await db.delete(
        rideChatMessagesTable,
        where: 'timestamp < ?',
        whereArgs: [cutoff],
      );
    } catch (e) {
      print('❌ SAHAr DB deleteOldRideChatMessages error: $e');
    }
  }
}

