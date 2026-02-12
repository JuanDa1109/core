import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import 'manifest_parser.dart';

class CoreRepository {
  CoreRepository({ManifestParser? parser})
    : _parser = parser ?? ManifestParser();

  static const _dbName = 'core_stats.db';

  final ManifestParser _parser;
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE imports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_name TEXT NOT NULL,
            file_hash TEXT NOT NULL UNIQUE,
            imported_at TEXT NOT NULL,
            total_rows INTEGER NOT NULL,
            inserted_rows INTEGER NOT NULL,
            skipped_rows INTEGER NOT NULL,
            backup_path TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            import_id INTEGER NOT NULL,
            source_row INTEGER NOT NULL,
            record_key TEXT NOT NULL UNIQUE,
            fecha TEXT NOT NULL,
            liner TEXT NOT NULL,
            closer TEXT NOT NULL,
            contract TEXT NOT NULL,
            vlr_venta REAL NOT NULL DEFAULT 0,
            cash REAL NOT NULL DEFAULT 0,
            gl REAL NOT NULL DEFAULT 0,
            calif TEXT NOT NULL,
            obs TEXT NOT NULL,
            sale_status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (import_id) REFERENCES imports (id)
          )
        ''');

        await db.execute('CREATE INDEX idx_records_fecha ON records(fecha)');
        await db.execute(
          'CREATE INDEX idx_records_contract ON records(contract)',
        );

        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contract TEXT NOT NULL,
            amount REAL NOT NULL,
            payment_date TEXT NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_payments_contract ON payments(contract)',
        );
      },
    );

    return _db!;
  }

  Future<ImportResult> importManifest(String filePath) async {
    final records = await _parser.parseFile(filePath);
    if (records.isEmpty) {
      throw const FormatException(
        'No se encontraron registros vÃ¡lidos en el archivo.',
      );
    }

    final file = File(filePath);
    final fileHash = await _hashFile(file);
    final db = await _database;

    final existingImport = await db.query(
      'imports',
      columns: ['id', 'total_rows', 'inserted_rows'],
      where: 'file_hash = ?',
      whereArgs: [fileHash],
      limit: 1,
    );

    if (existingImport.isNotEmpty) {
      final existingId = existingImport.first['id'] as int;
      final totalRows = (existingImport.first['total_rows'] as num).toInt();
      final insertedRows =
          (existingImport.first['inserted_rows'] as num?)?.toInt() ?? 0;

      if (insertedRows >= totalRows && totalRows == records.length) {
        return ImportResult(
          importId: existingId,
          totalRows: totalRows,
          insertedRows: 0,
          skippedRows: totalRows,
        );
      }

      final repaired = await db.transaction((txn) async {
        await txn.delete(
          'records',
          where: 'import_id = ?',
          whereArgs: [existingId],
        );

        final nowIso = DateTime.now().toIso8601String();
        var inserted = 0;
        var skipped = 0;

        for (final record in records) {
          final rowId = await txn.insert('records', {
            'import_id': existingId,
            'source_row': record.sourceRow,
            'record_key': _recordKey(record),
            'fecha': DateFormat('yyyy-MM-dd').format(record.fecha),
            'liner': record.liner,
            'closer': record.closer,
            'contract': record.contract,
            'vlr_venta': record.vlrVenta,
            'cash': record.cash,
            'gl': record.gl,
            'calif': record.calif,
            'obs': record.obs,
            'sale_status': record.saleStatus.name,
            'created_at': nowIso,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          if (rowId > 0) {
            inserted++;
          } else {
            skipped++;
          }
        }

        await txn.update(
          'imports',
          {
            'imported_at': nowIso,
            'total_rows': records.length,
            'inserted_rows': inserted,
            'skipped_rows': skipped,
          },
          where: 'id = ?',
          whereArgs: [existingId],
        );

        return ImportResult(
          importId: existingId,
          totalRows: records.length,
          insertedRows: inserted,
          skippedRows: skipped,
        );
      });

      return repaired;
    }

    final backupPath = await _backupDatabase();
    final nowIso = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final importId = await txn.insert('imports', {
        'file_name': p.basename(filePath),
        'file_hash': fileHash,
        'imported_at': nowIso,
        'total_rows': records.length,
        'inserted_rows': 0,
        'skipped_rows': 0,
        'backup_path': backupPath,
      });

      var inserted = 0;
      var skipped = 0;

      for (final record in records) {
        final recordKey = _recordKey(record);
        final rowId = await txn.insert('records', {
          'import_id': importId,
          'source_row': record.sourceRow,
          'record_key': recordKey,
          'fecha': DateFormat('yyyy-MM-dd').format(record.fecha),
          'liner': record.liner,
          'closer': record.closer,
          'contract': record.contract,
          'vlr_venta': record.vlrVenta,
          'cash': record.cash,
          'gl': record.gl,
          'calif': record.calif,
          'obs': record.obs,
          'sale_status': record.saleStatus.name,
          'created_at': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (rowId > 0) {
          inserted++;
        } else {
          skipped++;
        }
      }

      await txn.update(
        'imports',
        {'inserted_rows': inserted, 'skipped_rows': skipped},
        where: 'id = ?',
        whereArgs: [importId],
      );

      return ImportResult(
        importId: importId,
        totalRows: records.length,
        insertedRows: inserted,
        skippedRows: skipped,
        backupPath: backupPath,
      );
    });
  }

  Future<List<ImportHistoryItem>> listImports({int limit = 20}) async {
    final db = await _database;
    final rows = await db.query('imports', orderBy: 'id DESC', limit: limit);

    return rows
        .map(
          (row) => ImportHistoryItem(
            id: (row['id'] as num).toInt(),
            fileName: (row['file_name'] as String?) ?? '',
            importedAt: DateTime.parse(row['imported_at'] as String),
            totalRows: (row['total_rows'] as num).toInt(),
            insertedRows: (row['inserted_rows'] as num).toInt(),
            skippedRows: (row['skipped_rows'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<DateTimeRange?> latestMonthRange() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT MAX(fecha) AS max_fecha FROM records',
    );

    if (rows.isEmpty) return null;
    final maxText = rows.first['max_fecha'] as String?;
    if (maxText == null || maxText.trim().isEmpty) return null;

    final maxDate = DateTime.tryParse(maxText);
    if (maxDate == null) return null;

    final start = DateTime(maxDate.year, maxDate.month, 1);
    final end = DateTime(maxDate.year, maxDate.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  Future<DashboardData> loadDashboard({DateTimeRange? range}) async {
    final db = await _database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    if (range != null) {
      whereParts.add('fecha BETWEEN ? AND ?');
      whereArgs.add(DateFormat('yyyy-MM-dd').format(range.start));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(range.end));
    }

    final records = await db.query(
      'records',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'fecha ASC',
    );

    final contracts = records
        .map((row) => (row['contract'] as String?)?.trim() ?? '')
        .where((contract) => contract.isNotEmpty)
        .toSet()
        .toList();

    final paymentsByContract = await _paymentsByContract(contracts);

    final linerMap = <String, StatsRow>{};
    final closerMap = <String, StatsRow>{};

    for (final row in records) {
      final status = SaleStatus.values.firstWhere(
        (value) => value.name == row['sale_status'],
        orElse: () => SaleStatus.none,
      );

      final contract = (row['contract'] as String?)?.trim() ?? '';
      final paymentCash = paymentsByContract[contract] ?? 0;
      final baseCash = (row['cash'] as num?)?.toDouble() ?? 0;
      final baseGl = (row['gl'] as num?)?.toDouble() ?? 0;
      final volume = (row['vlr_venta'] as num?)?.toDouble() ?? 0;
      final calif = ((row['calif'] as String?) ?? '').trim().toUpperCase();

      _accumulate(
        table: linerMap,
        peopleRaw: (row['liner'] as String?) ?? '',
        status: status,
        volume: volume,
        baseCash: baseCash,
        gl: baseGl,
        paymentCash: paymentCash,
        calif: calif,
      );

      _accumulate(
        table: closerMap,
        peopleRaw: (row['closer'] as String?) ?? '',
        status: status,
        volume: volume,
        baseCash: baseCash,
        gl: baseGl,
        paymentCash: paymentCash,
        calif: calif,
      );
    }

    final liners =
        linerMap.values.where((row) => !_hideAnonymousEmptyRow(row)).toList()
          ..sort((a, b) {
            final bySales = b.totalSales.compareTo(a.totalSales);
            if (bySales != 0) return bySales;
            return b.totalCaja.compareTo(a.totalCaja);
          });

    final closers =
        closerMap.values.where((row) => !_hideAnonymousEmptyRow(row)).toList()
          ..sort((a, b) {
            final byCaja = b.totalCaja.compareTo(a.totalCaja);
            if (byCaja != 0) return byCaja;
            return b.totalSales.compareTo(a.totalSales);
          });

    return DashboardData(liners: liners, closers: closers);
  }

  Future<List<String>> searchContracts(String query, {int limit = 25}) async {
    final db = await _database;
    final normalized = query.trim();

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT contract
      FROM records
      WHERE contract <> ''
        AND contract LIKE ?
      ORDER BY contract ASC
      LIMIT ?
      ''',
      ['%$normalized%', limit],
    );

    return rows
        .map((row) => (row['contract'] as String?) ?? '')
        .where((contract) => contract.isNotEmpty)
        .toList();
  }

  Future<ContractSummary?> contractSummary(String contract) async {
    final db = await _database;
    final normalized = contract.trim();
    if (normalized.isEmpty) return null;

    final recordRows = await db.query(
      'records',
      where: 'contract = ?',
      whereArgs: [normalized],
      orderBy: 'fecha DESC, id DESC',
      limit: 1,
    );
    if (recordRows.isEmpty) return null;

    final row = recordRows.first;
    final status = SaleStatus.values.firstWhere(
      (value) => value.name == row['sale_status'],
      orElse: () => SaleStatus.none,
    );

    final paymentRows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE contract = ?',
      [normalized],
    );

    final paymentsCash =
        ((paymentRows.first['total'] as num?)?.toDouble() ?? 0);

    return ContractSummary(
      contract: normalized,
      status: status,
      vlrVenta: (row['vlr_venta'] as num?)?.toDouble() ?? 0,
      baseCash: (row['cash'] as num?)?.toDouble() ?? 0,
      paymentsCash: paymentsCash,
    );
  }

  Future<List<PaymentEntry>> paymentsForContract(String contract) async {
    final db = await _database;
    final rows = await db.query(
      'payments',
      where: 'contract = ?',
      whereArgs: [contract],
      orderBy: 'payment_date DESC, id DESC',
    );

    return rows
        .map(
          (row) => PaymentEntry(
            id: (row['id'] as num).toInt(),
            contract: (row['contract'] as String?) ?? '',
            amount: (row['amount'] as num).toDouble(),
            paymentDate: DateTime.parse(row['payment_date'] as String),
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<void> addPayment({
    required String contract,
    required double amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    final db = await _database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('payments', {
      'contract': contract.trim(),
      'amount': amount,
      'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'created_at': nowIso,
      'updated_at': nowIso,
    });
  }

  Future<void> updatePayment({
    required int id,
    required double amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    final db = await _database;

    await db.update(
      'payments',
      {
        'amount': amount,
        'payment_date': DateFormat('yyyy-MM-dd').format(paymentDate),
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePayment(int id) async {
    final db = await _database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> exportDashboardData({
    required DashboardData data,
    DateTimeRange? range,
  }) async {
    final workbook = Excel.createExcel();
    const sheetName = 'Hoja1';

    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }

    final sheet = workbook[sheetName];
    _configureTemplateLayout(sheet);

    final effectiveRange = await _resolveExportDateRange(range);
    final title = _buildExportTitle(effectiveRange);

    workbook.merge(
      sheetName,
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 1),
    );
    _setCell(sheet, 1, 1, title, style: _titleStyle());

    final nextRow = _writeStatsBlock(
      sheet: sheet,
      startRow: 2,
      sectionTitle: 'LINERS ',
      salesHeader: 'VENTAS',
      inactiveSalesHeader: 'VENTAS INACTIVAS',
      rows: data.liners,
    );

    _writeStatsBlock(
      sheet: sheet,
      startRow: nextRow,
      sectionTitle: 'CLOSER',
      salesHeader: 'Ventas',
      inactiveSalesHeader: 'Ventas Inactivas',
      rows: data.closers,
    );

    final rawBytes = workbook.encode();
    if (rawBytes == null) {
      throw StateError('No fue posible generar el archivo de exportacion.');
    }
    final bytes = _disableWorksheetGridlines(Uint8List.fromList(rawBytes));

    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(docsDir.path, 'exports'));
    await exportDir.create(recursive: true);

    final fileName =
        'estadisticas_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = p.join(exportDir.path, fileName);
    await File(filePath).writeAsBytes(bytes, flush: true);

    return filePath;
  }

  void _configureTemplateLayout(Sheet sheet) {
    sheet.setColumnWidth(0, 5.25);
    sheet.setColumnWidth(1, 33.625);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 15.75);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 10);
    sheet.setColumnWidth(7, 11.25);
    sheet.setColumnWidth(8, 8);
    sheet.setColumnWidth(9, 8);
    sheet.setColumnWidth(10, 8);
    sheet.setColumnWidth(11, 8);
    sheet.setColumnWidth(12, 10);
    sheet.setColumnWidth(13, 10);
    sheet.setColumnWidth(14, 10);
    sheet.setColumnWidth(15, 10);

    sheet.setRowHeight(0, 24);
    sheet.setRowHeight(1, 19.9);
    sheet.setRowHeight(2, 15);
  }

  int _writeStatsBlock({
    required Sheet sheet,
    required int startRow,
    required String sectionTitle,
    required String salesHeader,
    required String inactiveSalesHeader,
    required List<StatsRow> rows,
  }) {
    final headerStyle = _headerStyle();
    final sectionStyle = _sectionStyle();
    final textStyle = _nameStyle();
    final decimalStyle = _decimalStyle();
    final moneyStyle = _moneyStyle();
    final percentStyle = _percentStyle();
    final totalTextStyle = _totalTextStyle();
    final totalDecimalStyle = _totalDecimalStyle();
    final totalMoneyStyle = _totalMoneyStyle();
    final totalPercentStyle = _totalPercentStyle();

    final headers = <String>[
      salesHeader,
      inactiveSalesHeader,
      'VOLUMEN',
      'CASH',
      'GL',
      'TOTAL CAJA',
      'Q',
      'VENTAS Q',
      '% VTA Q',
      'NQ',
      'VENTAS NQ',
      '% VTA NQ',
      'Tours',
      '% TOUR',
    ];

    _setCell(sheet, 1, startRow, sectionTitle, style: sectionStyle);

    for (var i = 0; i < headers.length; i++) {
      _setCell(sheet, 2 + i, startRow, headers[i], style: headerStyle);
    }

    final dataStartRow = startRow + 1;
    for (var i = 0; i < rows.length; i++) {
      final rowIndex = dataStartRow + i;
      final excelRow = rowIndex + 1;
      final row = rows[i];

      _setCell(sheet, 1, rowIndex, row.name, style: textStyle);
      _setCell(sheet, 2, rowIndex, row.salesActive, style: decimalStyle);
      _setCell(sheet, 3, rowIndex, row.salesInactive, style: decimalStyle);
      _setCell(sheet, 4, rowIndex, row.volume, style: moneyStyle);
      _setCell(sheet, 5, rowIndex, row.cash, style: moneyStyle);
      _setCell(sheet, 6, rowIndex, row.gl, style: moneyStyle);
      _setCell(
        sheet,
        7,
        rowIndex,
        '=SUM(F$excelRow:G$excelRow)',
        style: moneyStyle,
      );
      _setCell(sheet, 8, rowIndex, row.q, style: decimalStyle);
      _setCell(sheet, 9, rowIndex, row.salesQ, style: decimalStyle);
      _setCell(
        sheet,
        10,
        rowIndex,
        '=IFERROR(J$excelRow/I$excelRow,0)',
        style: percentStyle,
      );
      _setCell(sheet, 11, rowIndex, row.nq, style: decimalStyle);
      _setCell(sheet, 12, rowIndex, row.salesNq, style: decimalStyle);
      _setCell(
        sheet,
        13,
        rowIndex,
        '=IFERROR(M$excelRow/L$excelRow,0)',
        style: percentStyle,
      );
      _setCell(
        sheet,
        14,
        rowIndex,
        '=I$excelRow+L$excelRow',
        style: decimalStyle,
      );
      _setCell(
        sheet,
        15,
        rowIndex,
        '=IFERROR(AVERAGE((C$excelRow+D$excelRow)/O$excelRow),0)',
        style: percentStyle,
      );
    }

    final totalRow = dataStartRow + rows.length;
    final totalRowExcel = totalRow + 1;
    _setCell(sheet, 1, totalRow, 'TOTALES', style: totalTextStyle);

    if (rows.isEmpty) {
      for (var c = 2; c <= 15; c++) {
        final style = _isMoneyColumn(c)
            ? totalMoneyStyle
            : _isPercentColumn(c)
            ? totalPercentStyle
            : totalDecimalStyle;
        _setCell(sheet, c, totalRow, 0, style: style);
      }
      return totalRow + 1;
    }

    final startExcel = dataStartRow + 1;
    final endExcel = totalRow;
    _setCell(
      sheet,
      2,
      totalRow,
      '=SUM(C$startExcel:C$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      3,
      totalRow,
      '=SUM(D$startExcel:D$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      4,
      totalRow,
      '=SUM(E$startExcel:E$endExcel)',
      style: totalMoneyStyle,
    );
    _setCell(
      sheet,
      5,
      totalRow,
      '=SUM(F$startExcel:F$endExcel)',
      style: totalMoneyStyle,
    );
    _setCell(
      sheet,
      6,
      totalRow,
      '=SUM(G$startExcel:G$endExcel)',
      style: totalMoneyStyle,
    );
    _setCell(
      sheet,
      7,
      totalRow,
      '=SUM(F$totalRowExcel:G$totalRowExcel)',
      style: totalMoneyStyle,
    );
    _setCell(
      sheet,
      8,
      totalRow,
      '=SUM(I$startExcel:I$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      9,
      totalRow,
      '=SUM(J$startExcel:J$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      10,
      totalRow,
      '=IFERROR(J$totalRowExcel/I$totalRowExcel,0)',
      style: totalPercentStyle,
    );
    _setCell(
      sheet,
      11,
      totalRow,
      '=SUM(L$startExcel:L$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      12,
      totalRow,
      '=SUM(M$startExcel:M$endExcel)',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      13,
      totalRow,
      '=IFERROR(M$totalRowExcel/L$totalRowExcel,0)',
      style: totalPercentStyle,
    );
    _setCell(
      sheet,
      14,
      totalRow,
      '=I$totalRowExcel+L$totalRowExcel',
      style: totalDecimalStyle,
    );
    _setCell(
      sheet,
      15,
      totalRow,
      '=IFERROR(AVERAGE((C$totalRowExcel+D$totalRowExcel)/O$totalRowExcel),0)',
      style: totalPercentStyle,
    );

    return totalRow + 1;
  }

  Future<DateTimeRange?> _resolveExportDateRange(
    DateTimeRange? preferred,
  ) async {
    if (preferred != null) {
      return DateTimeRange(
        start: DateTime(
          preferred.start.year,
          preferred.start.month,
          preferred.start.day,
        ),
        end: DateTime(
          preferred.end.year,
          preferred.end.month,
          preferred.end.day,
        ),
      );
    }

    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT MIN(fecha) AS min_fecha, MAX(fecha) AS max_fecha FROM records',
    );
    if (rows.isEmpty) return null;

    final minText = rows.first['min_fecha'] as String?;
    final maxText = rows.first['max_fecha'] as String?;
    if (minText == null || maxText == null) {
      return null;
    }

    final minDate = DateTime.tryParse(minText);
    final maxDate = DateTime.tryParse(maxText);
    if (minDate == null || maxDate == null) {
      return null;
    }

    return DateTimeRange(
      start: DateTime(minDate.year, minDate.month, minDate.day),
      end: DateTime(maxDate.year, maxDate.month, maxDate.day),
    );
  }

  String _buildExportTitle(DateTimeRange? range) {
    if (range == null) {
      return 'ESTADISTICAS SALA CARTAGENA';
    }

    final start = range.start;
    final end = range.end;
    final startMonth = _monthName(start);
    final endMonth = _monthName(end);

    if (start.year == end.year && start.month == end.month) {
      return 'ESTADISTICAS ${start.day} AL ${end.day}  $startMonth SALA CARTAGENA';
    }

    return 'ESTADISTICAS ${start.day} $startMonth AL ${end.day} $endMonth SALA CARTAGENA';
  }

  String _monthName(DateTime date) {
    try {
      return DateFormat('MMMM', 'es_CO').format(date).toUpperCase();
    } catch (_) {
      return DateFormat('MMMM').format(date).toUpperCase();
    }
  }

  CellStyle _titleStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('FFFFFF00'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _headerStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('FF92D050'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _sectionStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('FF92D050'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _nameStyle() {
    return CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _decimalStyle() {
    return CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_0,
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _moneyStyle() {
    return CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.custom(formatCode: r'"$"#,##0'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _percentStyle() {
    return CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_9,
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _totalTextStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('FFFFC000'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _totalDecimalStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_0,
      backgroundColorHex: ExcelColor.fromHexString('FFFFC000'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _totalMoneyStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.custom(formatCode: r'"$"#,##0'),
      backgroundColorHex: ExcelColor.fromHexString('FFFFC000'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  CellStyle _totalPercentStyle() {
    return CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_9,
      backgroundColorHex: ExcelColor.fromHexString('FFFFC000'),
      leftBorder: _tableBorder(),
      rightBorder: _tableBorder(),
      topBorder: _tableBorder(),
      bottomBorder: _tableBorder(),
    );
  }

  Border _tableBorder() {
    return Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.black,
    );
  }

  bool _isMoneyColumn(int column) {
    return column == 4 || column == 5 || column == 6 || column == 7;
  }

  bool _isPercentColumn(int column) {
    return column == 10 || column == 13 || column == 15;
  }

  bool _hideAnonymousEmptyRow(StatsRow row) {
    if (row.name.trim().isNotEmpty) {
      return false;
    }

    return _isNearlyZero(row.salesActive) &&
        _isNearlyZero(row.salesInactive) &&
        _isNearlyZero(row.salesQ) &&
        _isNearlyZero(row.salesNq) &&
        _isNearlyZero(row.volume) &&
        _isNearlyZero(row.cash) &&
        _isNearlyZero(row.gl) &&
        _isNearlyZero(row.q) &&
        _isNearlyZero(row.nq);
  }

  bool _isNearlyZero(double value) => value.abs() < 0.0000001;

  Uint8List _disableWorksheetGridlines(Uint8List zippedBytes) {
    final archive = ZipDecoder().decodeBytes(zippedBytes);
    final out = Archive();

    for (final file in archive) {
      if (!file.isFile) {
        out.addFile(file);
        continue;
      }

      if (file.name == 'xl/worksheets/sheet1.xml') {
        final original = utf8.decode(file.content as List<int>);
        var updated = original;

        if (RegExp(r'<sheetView[^>]*showGridLines=').hasMatch(updated)) {
          updated = updated.replaceAll(
            'showGridLines="1"',
            'showGridLines="0"',
          );
        } else {
          updated = updated.replaceFirst(
            '<sheetView ',
            '<sheetView showGridLines="0" ',
          );
        }

        final content = utf8.encode(updated);
        out.addFile(ArchiveFile(file.name, content.length, content));
        continue;
      }

      out.addFile(file);
    }

    final encoded = ZipEncoder().encode(out);
    if (encoded == null) {
      return zippedBytes;
    }
    return Uint8List.fromList(encoded);
  }

  void _setCell(
    Sheet sheet,
    int col,
    int row,
    Object value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );

    if (value is String && value.startsWith('=')) {
      cell.setFormula(value);
      if (style != null) {
        cell.cellStyle = style;
      }
      return;
    }
    if (value is int) {
      cell.value = IntCellValue(value);
      if (style != null) {
        cell.cellStyle = style;
      }
      return;
    }
    if (value is num) {
      cell.value = DoubleCellValue(value.toDouble());
      if (style != null) {
        cell.cellStyle = style;
      }
      return;
    }
    if (value is bool) {
      cell.value = BoolCellValue(value);
      if (style != null) {
        cell.cellStyle = style;
      }
      return;
    }
    cell.value = TextCellValue(value.toString());
    if (style != null) {
      cell.cellStyle = style;
    }
  }

  void _accumulate({
    required Map<String, StatsRow> table,
    required String peopleRaw,
    required SaleStatus status,
    required double volume,
    required double baseCash,
    required double gl,
    required double paymentCash,
    required String calif,
  }) {
    final people = _splitPeople(peopleRaw);
    final weight = people.isEmpty ? 1 : 1 / people.length;
    final targets = people.isEmpty ? [''] : people;

    for (final person in targets) {
      final row = table.putIfAbsent(person, () => StatsRow(name: person));

      if (calif == 'Q') {
        row.q += weight;
      } else if (calif == 'NQ') {
        row.nq += weight;
      }

      final countsAsSale =
          status == SaleStatus.activePercent ||
          status == SaleStatus.activeZero ||
          status == SaleStatus.inactive;
      if (countsAsSale) {
        if (calif == 'Q') {
          row.salesQ += weight;
        } else if (calif == 'NQ') {
          row.salesNq += weight;
        }
      }

      switch (status) {
        case SaleStatus.activePercent:
          row.salesActive += weight;
          row.volume += volume * weight;
          row.cash += (baseCash + paymentCash) * weight;
          row.gl += gl * weight;
          break;
        case SaleStatus.activeZero:
          row.salesActive += weight;
          row.salesActiveZero += weight;
          row.cash += paymentCash * weight;
          break;
        case SaleStatus.inactive:
          row.salesInactive += weight;
          break;
        case SaleStatus.none:
          break;
      }
    }
  }

  List<String> _splitPeople(String source) {
    final cleaned = source.trim();
    if (cleaned.isEmpty) return const [];

    final parts = cleaned
        .split(RegExp(r'\s*-\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return parts.isEmpty ? [cleaned] : parts;
  }

  Future<Map<String, double>> _paymentsByContract(
    List<String> contracts,
  ) async {
    if (contracts.isEmpty) return const {};

    final db = await _database;
    final placeholders = List.filled(contracts.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT contract, COALESCE(SUM(amount), 0) AS total FROM payments WHERE contract IN ($placeholders) GROUP BY contract',
      contracts,
    );

    final result = <String, double>{};
    for (final row in rows) {
      final contract = (row['contract'] as String?) ?? '';
      if (contract.isEmpty) continue;
      result[contract] = (row['total'] as num?)?.toDouble() ?? 0;
    }
    return result;
  }

  String _recordKey(ManifestRecord record) {
    final rowIdentity = record.sourceId.trim().isNotEmpty
        ? record.sourceId.trim().toLowerCase()
        : 'row_${record.sourceRow}';

    final buffer = StringBuffer()
      ..write(DateFormat('yyyy-MM-dd').format(record.fecha))
      ..write('|')
      ..write(rowIdentity)
      ..write('|')
      ..write(record.liner.trim().toLowerCase())
      ..write('|')
      ..write(record.closer.trim().toLowerCase())
      ..write('|')
      ..write(record.contract.trim().toLowerCase())
      ..write('|')
      ..write(record.vlrVenta.toStringAsFixed(2))
      ..write('|')
      ..write(record.cash.toStringAsFixed(2))
      ..write('|')
      ..write(record.gl.toStringAsFixed(2))
      ..write('|')
      ..write(record.calif.trim().toUpperCase())
      ..write('|')
      ..write(record.obs.trim().toLowerCase());

    return sha1.convert(buffer.toString().codeUnits).toString();
  }

  Future<String> _hashFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha1.convert(bytes).toString();
  }

  Future<String?> _backupDatabase() async {
    final dbPath = await getDatabasesPath();
    final sourcePath = p.join(dbPath, _dbName);
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return null;
    }

    final docs = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docs.path, 'backups'));
    await backupDir.create(recursive: true);

    final backupName =
        'core_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db';
    final backupPath = p.join(backupDir.path, backupName);

    await sourceFile.copy(backupPath);
    return backupPath;
  }
}
