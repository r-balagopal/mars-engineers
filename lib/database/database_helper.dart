import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../models/team_member.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('mars_engineers.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        workType TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        invoiceNumber TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

Future _upgradeDB(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE invoices ADD COLUMN pdfPath TEXT',
    );
  }

  if (oldVersion < 3) {
    await db.execute(
      'ALTER TABLE sites ADD COLUMN workOrderPath TEXT',
    );
  }

  if (oldVersion < 4) {
    await db.execute('''
      CREATE TABLE work_orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL
      )
    ''');
  }
  if (oldVersion < 5) {
  await db.execute('''
    CREATE TABLE team_members(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      siteId INTEGER NOT NULL,
      name TEXT NOT NULL,
      designation TEXT NOT NULL,
      dailyRate REAL NOT NULL,
      startDate TEXT NOT NULL,
      endDate TEXT
    )
  ''');
}
}

  // ---------- SITE METHODS ----------

  Future<int> insertSite(
    String name,
    String workType,
    String status,
  ) async {
    final db = await instance.database;

    return await db.insert(
      'sites',
      {
        'name': name,
        'workType': workType,
        'status': status,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getSites() async {
    final db = await instance.database;

    return await db.query('sites');
  }

  Future<int> updateSite(
    int id,
    String name,
    String workType,
    String status,
  ) async {
    final db = await instance.database;

    return await db.update(
      'sites',
      {
        'name': name,
        'workType': workType,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

 Future<int> deleteSite(int id) async {
  final db = await instance.database;

  // Delete all invoices belonging to this site
  await db.delete(
    'invoices',
    where: 'siteId = ?',
    whereArgs: [id],
  );

  // Delete the site
  return await db.delete(
    'sites',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  // ---------- INVOICE METHODS ----------

  Future<int> insertInvoice(
    int siteId,
    String invoiceNumber,
    double amount,
    String status,
    String? pdfPath,
  ) async {
    final db = await instance.database;

    final result = await db.insert(
      'invoices',
      {
        'siteId': siteId,
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'status': status,
        'pdfPath': pdfPath,
      },
    );

    print("Inserted invoice ID = $result");

    return result;
  }

  Future<List<Map<String, dynamic>>> getInvoicesBySite(int siteId) async {
    final db = await instance.database;

    return await db.query(
      'invoices',
      where: 'siteId = ?',
      whereArgs: [siteId],
    );
  }

  Future<int> updateInvoice(
    int id,
    String invoiceNumber,
    double amount,
    String status,
  ) async {
    final db = await instance.database;

    return await db.update(
      'invoices',
      {
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInvoice(int id) async {
    final db = await instance.database;

    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT invoices.id,
             invoices.invoiceNumber,
             invoices.amount,
             invoices.status,
             invoices.pdfPath,
             sites.name AS siteName
      FROM invoices
      INNER JOIN sites
      ON invoices.siteId = sites.id
      ORDER BY invoices.id DESC
    ''');
  }

  Future<int> getActiveSiteCount() async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sites WHERE status='Active'",
    );

    return result.first['count'] as int;
  }

  Future<int> getClosedSiteCount() async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sites WHERE status='Closed'",
    );

    return result.first['count'] as int;
  }

  Future<double> getTotalInvoiced() async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM invoices",
    );

    final total = result.first['total'];

    if (total == null) return 0;

    return (total as num).toDouble();
  }

  Future<double> getOutstandingAmount() async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM invoices WHERE status='Pending'",
    );

    final total = result.first['total'];

    if (total == null) return 0;

    return (total as num).toDouble();
  }

  Future<int> getInvoiceCount() async {
    final db = await instance.database;

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM invoices",
    );

    return result.first['count'] as int;
  }

  Future<void> clearAllData() async {
    final db = await instance.database;

    await db.delete('invoices');
    await db.delete('sites');

    print("ALL DATA CLEARED");
  }
  Future<String> backupDatabase() async {
  final db = await database;

  final backupDir = await getApplicationDocumentsDirectory();

  final backupPath =
      '${backupDir.path}/mars_engineers_backup.db';

  await File(db.path).copy(backupPath);

  return backupPath;
}
Future<void> restoreDatabase(String backupPath) async {
  final db = await database;

  final dbPath = db.path;

  await db.close();

  final databaseFile = File(dbPath);

  if (await databaseFile.exists()) {
    await databaseFile.delete();
  }

  await File(backupPath).copy(dbPath);

  _database = null;
}
Future<void> removeOrphanInvoices() async {
  final db = await instance.database;

  await db.rawDelete('''
    DELETE FROM invoices
    WHERE siteId NOT IN (
      SELECT id FROM sites
    )
  ''');
}
Future<void> updateWorkOrderPath(
  int siteId,
  String path,
) async {
  final db = await database;

  await db.update(
    'sites',
    {
      'workOrderPath': path,
    },
    where: 'id = ?',
    whereArgs: [siteId],
  );
}
Future<Site?> getSiteById(int id) async {
  final db = await database;

  final result = await db.query(
    'sites',
    where: 'id = ?',
    whereArgs: [id],
  );

  if (result.isEmpty) return null;

  return Site.fromMap(result.first);
}

Future<int> insertWorkOrder(
  int siteId,
  String fileName,
  String filePath,
) async {
  final db = await database;

  return await db.insert(
    'work_orders',
    {
      'siteId': siteId,
      'fileName': fileName,
      'filePath': filePath,
    },
  );
}
Future<List<Map<String, dynamic>>> getWorkOrdersBySite(
  int siteId,
) async {
  final db = await database;

  return await db.query(
    'work_orders',
    where: 'siteId = ?',
    whereArgs: [siteId],
    orderBy: 'id DESC',
  );
}

Future<int> deleteWorkOrder(int id) async {
  final db = await database;

  return await db.delete(
    'work_orders',
    where: 'id = ?',
    whereArgs: [id],
  );
}
Future<int> insertTeamMember(TeamMember member) async {
  final db = await instance.database;

  return await db.insert(
    'team_members',
    member.toMap(),
  );
}
Future<List<Map<String, dynamic>>> getTeamMembersBySite(int siteId) async {
  final db = await instance.database;

  return await db.query(
    'team_members',
    where: 'siteId = ?',
    whereArgs: [siteId],
    orderBy: 'id DESC',
  );
}
Future<int> updateTeamMember(TeamMember member) async {
  final db = await instance.database;

  return await db.update(
    'team_members',
    member.toMap(),
    where: 'id = ?',
    whereArgs: [member.id],
  );
}
Future<int> deleteTeamMember(int id) async {
  final db = await instance.database;

  return await db.delete(
    'team_members',
    where: 'id = ?',
    whereArgs: [id],
  );
}
}