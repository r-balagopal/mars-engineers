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
      version: 10,
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
        status TEXT NOT NULL,
        workOrderPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        invoiceNumber TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        pdfPath TEXT,
        invoiceDate TEXT,
        poId INTEGER,
        dataJson TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE work_orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        poNumber TEXT,
        poValue REAL,
        poDate TEXT,
        paymentTermsDays INTEGER NOT NULL DEFAULT 30
      )
    ''');

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

    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        amount REAL NOT NULL,
        paidDate TEXT NOT NULL,
        reference TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memberId INTEGER NOT NULL,
        siteId INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_attendance_member_date ON attendance(memberId, date)',
    );

    await db.execute('''
      CREATE TABLE work_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_worklog_site_date ON work_log(siteId, date)',
    );

    await db.execute('''
      CREATE TABLE gst_returns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL UNIQUE,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        addedOn TEXT NOT NULL
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

  if (oldVersion < 6) {
    await db.execute(
      'ALTER TABLE invoices ADD COLUMN invoiceDate TEXT',
    );
    await db.execute(
      "UPDATE invoices SET invoiceDate = date('now')",
    );
  }

  if (oldVersion < 7) {
    await db.execute('ALTER TABLE work_orders ADD COLUMN poNumber TEXT');
    await db.execute('ALTER TABLE work_orders ADD COLUMN poValue REAL');
    await db.execute('ALTER TABLE work_orders ADD COLUMN poDate TEXT');
    await db.execute(
      'ALTER TABLE work_orders ADD COLUMN paymentTermsDays INTEGER NOT NULL DEFAULT 30',
    );
    await db.execute('ALTER TABLE invoices ADD COLUMN poId INTEGER');

    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        amount REAL NOT NULL,
        paidDate TEXT NOT NULL,
        reference TEXT
      )
    ''');

    // Invoices already marked Paid become one full payment each.
    await db.execute('''
      INSERT INTO payments(invoiceId, amount, paidDate, reference)
      SELECT id, amount, COALESCE(invoiceDate, date('now')), 'Migrated'
      FROM invoices WHERE status = 'Paid'
    ''');
  }

  if (oldVersion < 8) {
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memberId INTEGER NOT NULL,
        siteId INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_attendance_member_date ON attendance(memberId, date)',
    );

    await db.execute('''
      CREATE TABLE work_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_worklog_site_date ON work_log(siteId, date)',
    );
  }

  if (oldVersion < 9) {
    await db.execute('ALTER TABLE invoices ADD COLUMN dataJson TEXT');
  }

  if (oldVersion < 10) {
    await db.execute('''
      CREATE TABLE gst_returns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL UNIQUE,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        addedOn TEXT NOT NULL
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

    await db.rawDelete(
      'DELETE FROM payments WHERE invoiceId IN (SELECT id FROM invoices WHERE siteId = ?)',
      [id],
    );
    await db.delete('attendance', where: 'siteId = ?', whereArgs: [id]);
    await db.delete('work_log', where: 'siteId = ?', whereArgs: [id]);
    await db.delete('invoices', where: 'siteId = ?', whereArgs: [id]);
    await db.delete('work_orders', where: 'siteId = ?', whereArgs: [id]);
    await db.delete('team_members', where: 'siteId = ?', whereArgs: [id]);

    return await db.delete('sites', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- INVOICE METHODS ----------

  Future<int> insertInvoice(
    int siteId,
    String invoiceNumber,
    double amount,
    String? pdfPath, {
    int? poId,
    DateTime? invoiceDate,
    String? dataJson,
  }) async {
    final db = await instance.database;

    return await db.insert(
      'invoices',
      {
        'siteId': siteId,
        'poId': poId,
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'status': 'Pending',
        'pdfPath': pdfPath,
        'invoiceDate': (invoiceDate ?? DateTime.now()).toIso8601String(),
        'dataJson': dataJson,
      },
    );
  }

  Future<List<String>> getAllInvoiceNumbers() async {
    final db = await instance.database;
    final rows = await db.query('invoices', columns: ['invoiceNumber']);
    return rows.map((r) => '${r['invoiceNumber']}'.trim()).toList();
  }

  Future<bool> invoiceNumberExists(String number) async {
    final db = await instance.database;
    final rows = await db.query(
      'invoices',
      columns: ['id'],
      where: 'invoiceNumber = ?',
      whereArgs: [number.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getInvoicesBySite(int siteId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT i.*,
             COALESCE((SELECT SUM(p.amount) FROM payments p
                       WHERE p.invoiceId = i.id), 0) AS paid
      FROM invoices i
      WHERE i.siteId = ?
      ORDER BY i.id DESC
    ''', [siteId]);
  }

  Future<void> updateInvoice(
    int id,
    String invoiceNumber,
    double amount, {
    int? poId,
    String? pdfPath,
  }) async {
    final db = await instance.database;
    await db.update(
      'invoices',
      {
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'poId': poId,
        'pdfPath': pdfPath,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await recomputeInvoiceStatus(id);
  }

  Future<int> deleteInvoice(int id) async {
    final db = await instance.database;
    await db.delete('payments', where: 'invoiceId = ?', whereArgs: [id]);
    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Status is derived from payments: Pending / Part paid / Paid.
  Future<void> recomputeInvoiceStatus(int invoiceId) async {
    final db = await instance.database;
    final r = await db.rawQuery('''
      SELECT amount,
             COALESCE((SELECT SUM(amount) FROM payments WHERE invoiceId = ?), 0) AS paid
      FROM invoices WHERE id = ?
    ''', [invoiceId, invoiceId]);
    if (r.isEmpty) return;

    final amount = (r.first['amount'] as num).toDouble();
    final paid = (r.first['paid'] as num).toDouble();
    final status =
        paid <= 0 ? 'Pending' : (paid + 0.5 >= amount ? 'Paid' : 'Part paid');

    await db.update('invoices', {'status': status},
        where: 'id = ?', whereArgs: [invoiceId]);
  }

  // ---------- PAYMENTS ----------

  Future<void> insertPayment(
    int invoiceId,
    double amount,
    String paidDate,
    String? reference,
  ) async {
    final db = await instance.database;
    await db.insert('payments', {
      'invoiceId': invoiceId,
      'amount': amount,
      'paidDate': paidDate,
      'reference': reference,
    });
    await recomputeInvoiceStatus(invoiceId);
  }

  Future<List<Map<String, dynamic>>> getPaymentsByInvoice(int invoiceId) async {
    final db = await instance.database;
    return await db.query(
      'payments',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
      orderBy: 'paidDate DESC, id DESC',
    );
  }

  Future<void> deletePayment(int id, int invoiceId) async {
    final db = await instance.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
    await recomputeInvoiceStatus(invoiceId);
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

    final result = await db.rawQuery('''
      SELECT SUM(i.amount - COALESCE((SELECT SUM(p.amount) FROM payments p
                                      WHERE p.invoiceId = i.id), 0)) AS total
      FROM invoices i
      WHERE i.amount - COALESCE((SELECT SUM(p.amount) FROM payments p
                                 WHERE p.invoiceId = i.id), 0) > 0
    ''');

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

    await db.delete('attendance');
    await db.delete('work_log');
    await db.delete('gst_returns');
    await db.delete('payments');
    await db.delete('invoices');
    await db.delete('work_orders');
    await db.delete('team_members');
    await db.delete('sites');
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

  for (final table in ['invoices', 'work_orders', 'team_members']) {
    await db.rawDelete(
      'DELETE FROM $table WHERE siteId NOT IN (SELECT id FROM sites)',
    );
  }
  await db.rawDelete(
    'DELETE FROM payments WHERE invoiceId NOT IN (SELECT id FROM invoices)',
  );
  await db.rawDelete(
    'DELETE FROM attendance WHERE memberId NOT IN (SELECT id FROM team_members)',
  );
  await db.rawDelete(
    'DELETE FROM work_log WHERE siteId NOT IN (SELECT id FROM sites)',
  );
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

  await db.update('invoices', {'poId': null},
      where: 'poId = ?', whereArgs: [id]);

  return await db.delete(
    'work_orders',
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> insertPo(WorkOrder po) async {
  final db = await database;
  final map = po.toMap()..remove('id');
  return await db.insert('work_orders', map);
}

Future<int> updatePo(WorkOrder po) async {
  final db = await database;
  return await db.update(
    'work_orders',
    po.toMap(),
    where: 'id = ?',
    whereArgs: [po.id],
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

  await db.delete('attendance', where: 'memberId = ?', whereArgs: [id]);

  return await db.delete(
    'team_members',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  // ---------- HOME SCREEN QUERIES ----------

  Future<double> getPaidAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments '
      'WHERE invoiceId IN (SELECT id FROM invoices)',
    );
    final total = result.first['total'];
    if (total == null) return 0;
    return (total as num).toDouble();
  }

  /// Invoices with money still to collect, with the PO's payment terms.
  Future<List<Map<String, dynamic>>> getPendingInvoicesWithSite() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT i.id,
             i.invoiceNumber,
             i.amount,
             i.invoiceDate,
             s.id AS siteId,
             s.name AS siteName,
             COALESCE(w.paymentTermsDays, 30) AS termsDays,
             i.amount - COALESCE((SELECT SUM(p.amount) FROM payments p
                                  WHERE p.invoiceId = i.id), 0) AS balance
      FROM invoices i
      INNER JOIN sites s ON i.siteId = s.id
      LEFT JOIN work_orders w ON w.id = i.poId
      WHERE i.amount - COALESCE((SELECT SUM(p.amount) FROM payments p
                                 WHERE p.invoiceId = i.id), 0) > 0.5
    ''');
  }

  /// POs on active projects that have no invoice yet.
  /// Legacy file-only POs (no PO value) fall back to "project has no invoices".
  Future<List<Map<String, dynamic>>> getPosAwaitingInvoice() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT w.id AS poId,
             w.siteId AS siteId,
             s.name AS siteName,
             COALESCE(NULLIF(w.poNumber, ''), w.fileName) AS label
      FROM work_orders w
      INNER JOIN sites s ON s.id = w.siteId
      WHERE s.status = 'Active'
        AND (
          (w.poValue IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM invoices i WHERE i.poId = w.id))
          OR
          (w.poValue IS NULL
             AND NOT EXISTS (SELECT 1 FROM invoices i WHERE i.siteId = w.siteId))
        )
      GROUP BY CASE WHEN w.poValue IS NULL THEN 's' || w.siteId
                    ELSE 'p' || w.id END
    ''');
  }

  // ---------- ATTENDANCE ----------

  /// Rows are present days only: {memberId, siteId, date 'yyyy-MM-dd'}.
  Future<List<Map<String, dynamic>>> getAttendanceInRange(
    int siteId,
    String from,
    String to,
  ) async {
    final db = await instance.database;
    return await db.query(
      'attendance',
      where: 'siteId = ? AND date >= ? AND date <= ?',
      whereArgs: [siteId, from, to],
    );
  }

  Future<void> setAttendance(
    int memberId,
    int siteId,
    String date,
    bool present,
  ) async {
    final db = await instance.database;
    if (present) {
      await db.insert(
        'attendance',
        {'memberId': memberId, 'siteId': siteId, 'date': date},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        'attendance',
        where: 'memberId = ? AND date = ?',
        whereArgs: [memberId, date],
      );
    }
  }

  /// Marks many (memberId, date) pairs present in one go.
  Future<void> fillAttendance(int siteId, List<(int, String)> pairs) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final p in pairs) {
      batch.insert(
        'attendance',
        {'memberId': p.$1, 'siteId': siteId, 'date': p.$2},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearDayAttendance(int siteId, String date) async {
    final db = await instance.database;
    await db.delete(
      'attendance',
      where: 'siteId = ? AND date = ?',
      whereArgs: [siteId, date],
    );
  }

  Future<Map<String, String>> getWorkLogs(
    int siteId,
    String from,
    String to,
  ) async {
    final db = await instance.database;
    final rows = await db.query(
      'work_log',
      where: 'siteId = ? AND date >= ? AND date <= ?',
      whereArgs: [siteId, from, to],
    );
    return {for (final r in rows) '${r['date']}': '${r['description']}'};
  }

  Future<void> setWorkLog(int siteId, String date, String text) async {
    final db = await instance.database;
    final t = text.trim();
    if (t.isEmpty) {
      await db.delete(
        'work_log',
        where: 'siteId = ? AND date = ?',
        whereArgs: [siteId, date],
      );
    } else {
      await db.insert(
        'work_log',
        {'siteId': siteId, 'date': date, 'description': t},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ---------- HOME SCREEN (v2) ----------

  Future<double> getReceivedBetween(String from, String to) async {
    final db = await instance.database;
    final r = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM payments '
      'WHERE paidDate >= ? AND paidDate < ? '
      'AND invoiceId IN (SELECT id FROM invoices)',
      [from, to],
    );
    final v = r.first['total'];
    return v == null ? 0 : (v as num).toDouble();
  }

  Future<double> getBilledBetween(String from, String to) async {
    final db = await instance.database;
    final r = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM invoices '
      'WHERE invoiceDate >= ? AND invoiceDate < ?',
      [from, to],
    );
    final v = r.first['total'];
    return v == null ? 0 : (v as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getActiveProjectSummaries() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.id AS id,
             s.name AS name,
             COALESCE((SELECT SUM(w.poValue) FROM work_orders w
                       WHERE w.siteId = s.id), 0) AS poValue,
             COALESCE((SELECT SUM(i.amount) FROM invoices i
                       WHERE i.siteId = s.id), 0) AS billed,
             COALESCE((SELECT SUM(i.amount - COALESCE(
                         (SELECT SUM(p.amount) FROM payments p
                          WHERE p.invoiceId = i.id), 0))
                       FROM invoices i WHERE i.siteId = s.id), 0) AS due
      FROM sites s
      WHERE s.status = 'Active'
      ORDER BY s.name COLLATE NOCASE
    ''');
  }

  /// Active projects with team members working in [monthStart]..[monthEnd]
  /// but no attendance at all entered for that month.
  Future<List<Map<String, dynamic>>> getSitesMissingAttendance(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final db = await instance.database;
    final ms = '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}-01';
    final me = '${monthEnd.year}-${monthEnd.month.toString().padLeft(2, '0')}-'
        '${monthEnd.day.toString().padLeft(2, '0')}';
    return await db.rawQuery('''
      SELECT s.id AS siteId, s.name AS siteName, COUNT(t.id) AS workers
      FROM sites s
      INNER JOIN team_members t ON t.siteId = s.id
      WHERE s.status = 'Active'
        AND substr(t.startDate, 1, 10) <= ?
        AND (t.endDate IS NULL OR t.endDate = '' OR substr(t.endDate, 1, 10) >= ?)
        AND NOT EXISTS (SELECT 1 FROM attendance a
                        WHERE a.siteId = s.id AND a.date >= ? AND a.date <= ?)
      GROUP BY s.id
    ''', [me, ms, ms, me]);
  }

  /// POs on active projects with their billed total (for the 90% alert).
  Future<List<Map<String, dynamic>>> getPoBillingStatus() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT w.id AS poId,
             w.siteId AS siteId,
             s.name AS siteName,
             COALESCE(NULLIF(w.poNumber, ''), w.fileName) AS label,
             w.poValue AS poValue,
             COALESCE((SELECT SUM(i.amount) FROM invoices i
                       WHERE i.poId = w.id), 0) AS billed
      FROM work_orders w
      INNER JOIN sites s ON s.id = w.siteId
      WHERE s.status = 'Active' AND w.poValue IS NOT NULL AND w.poValue > 0
    ''');
  }

  // ---------- GST RETURNS (GSTR-3B PDFs by month) ----------

  /// Saved returns keyed by month ('yyyy-MM').
  Future<Map<String, Map<String, dynamic>>> getGstReturns() async {
    final db = await instance.database;
    final rows = await db.query('gst_returns');
    return {for (final r in rows) '${r['month']}': Map<String, dynamic>.from(r)};
  }

  Future<void> saveGstReturn(
    String month,
    String fileName,
    String filePath,
  ) async {
    final db = await instance.database;
    await db.insert(
      'gst_returns',
      {
        'month': month,
        'fileName': fileName,
        'filePath': filePath,
        'addedOn': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteGstReturn(String month) async {
    final db = await instance.database;
    await db.delete('gst_returns', where: 'month = ?', whereArgs: [month]);
  }
}
