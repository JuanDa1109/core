import 'dart:io';

import 'package:intl/intl.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../domain/models.dart';

class ManifestParser {
  static const Map<String, List<String>> _columnAliases = {
    'fecha': ['fecha', 'date'],
    'liner': ['liner', 'liners'],
    'closer': ['closer', 'closers'],
    'contrato': ['contrato', 'contract', 'cto'],
    'vlr_venta': ['vlrventa', 'vlr_venta', 'valorventa', 'valventa', 'venta'],
    'cash': ['cash', 'abono', 'recaudo'],
    'pagda_gl': ['pagda', 'pagdagl', 'pagda(gl)', 'gl'],
    'calif': ['calif', 'calificacion'],
    'obs': ['obs', 'observacion', 'observaciones'],
  };
  static const List<String> _idAliases = ['id', 'codigo', 'code'];

  Future<List<ManifestRecord>> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final workbook = SpreadsheetDecoder.decodeBytes(bytes, update: false);

    if (workbook.tables.isEmpty) {
      throw const FormatException('El archivo no contiene hojas legibles.');
    }

    final sheet = workbook.tables.values.firstWhere(
      (s) => s.maxRows > 0,
      orElse: () => workbook.tables.values.first,
    );

    final rows = sheet.rows;
    final headerInfo = _detectHeader(rows);
    final headerRow = headerInfo.$1;
    final columns = headerInfo.$2;
    final idColumn = _findOptionalColumn(rows[headerRow], _idAliases);

    final records = <ManifestRecord>[];
    for (var i = headerRow + 1; i < rows.length; i++) {
      final row = rows[i];

      final fechaCell = _valueAt(row, columns['fecha']!);
      final liner = _cellText(_valueAt(row, columns['liner']!));
      final closer = _cellText(_valueAt(row, columns['closer']!));
      final sourceId = idColumn == null
          ? ''
          : _cellText(_valueAt(row, idColumn));
      final contract = _cellText(_valueAt(row, columns['contrato']!));
      final vlrVenta = _parseNumber(_valueAt(row, columns['vlr_venta']!));
      final cash = _parseNumber(_valueAt(row, columns['cash']!));
      final gl = _parseNumber(_valueAt(row, columns['pagda_gl']!));
      final calif = _cellText(_valueAt(row, columns['calif']!));
      final obs = _cellText(_valueAt(row, columns['obs']!));

      final fecha = _parseDate(fechaCell);

      final isBlank =
          fecha == null &&
          liner.isEmpty &&
          closer.isEmpty &&
          contract.isEmpty &&
          vlrVenta == 0 &&
          cash == 0 &&
          gl == 0 &&
          calif.isEmpty &&
          obs.isEmpty;
      if (isBlank) {
        continue;
      }

      if (fecha == null) {
        continue;
      }

      final saleStatus = _classifySaleStatus(
        obs: obs,
        contract: contract,
        vlrVenta: vlrVenta,
      );

      records.add(
        ManifestRecord(
          fecha: DateTime(fecha.year, fecha.month, fecha.day),
          sourceId: sourceId.trim(),
          liner: liner.trim(),
          closer: closer.trim(),
          contract: contract.trim(),
          vlrVenta: vlrVenta,
          cash: cash,
          gl: gl,
          calif: calif.trim().toUpperCase(),
          obs: obs.trim(),
          saleStatus: saleStatus,
          sourceRow: i + 1,
        ),
      );
    }

    return records;
  }

  int? _findOptionalColumn(List<dynamic> headerRow, List<String> aliases) {
    for (var colIndex = 0; colIndex < headerRow.length; colIndex++) {
      final normalized = _normalize(_cellText(headerRow[colIndex]));
      if (normalized.isEmpty) continue;
      if (aliases.any((alias) => normalized == _normalize(alias))) {
        return colIndex;
      }
    }
    return null;
  }

  (int, Map<String, int>) _detectHeader(List<List<dynamic>> rows) {
    for (
      var rowIndex = 0;
      rowIndex < rows.length && rowIndex < 80;
      rowIndex++
    ) {
      final row = rows[rowIndex];
      final found = <String, int>{};

      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final normalized = _normalize(_cellText(row[colIndex]));
        if (normalized.isEmpty) continue;

        for (final entry in _columnAliases.entries) {
          if (found.containsKey(entry.key)) continue;

          if (entry.value.any((alias) => normalized == _normalize(alias))) {
            found[entry.key] = colIndex;
            break;
          }
        }
      }

      if (found.length == _columnAliases.length) {
        return (rowIndex, found);
      }
    }

    throw const FormatException(
      'No se detectaron todas las columnas requeridas: Fecha, Liner, Closer, Contrato, Vlr_Venta, Cash, PagDA (GL), Calif, Obs.',
    );
  }

  dynamic _valueAt(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return null;
    return row[index];
  }

  String _cellText(dynamic cell) {
    if (cell == null) return '';
    if (cell is DateTime) {
      return DateFormat('yyyy-MM-dd').format(cell);
    }
    return cell.toString().trim();
  }

  DateTime? _parseDate(dynamic cell) {
    if (cell == null) return null;

    if (cell is DateTime) {
      return cell;
    }

    if (cell is num) {
      final base = DateTime(1899, 12, 30);
      return base.add(Duration(days: cell.floor()));
    }

    final text = cell.toString().trim();
    if (text.isEmpty) return null;

    if (RegExp(r'^\d{5,}$').hasMatch(text)) {
      final serial = int.tryParse(text);
      if (serial != null) {
        final base = DateTime(1899, 12, 30);
        return base.add(Duration(days: serial));
      }
    }

    final formats = <DateFormat>[
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('M/d/yyyy'),
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(text);
      } catch (_) {
        // Continue.
      }
    }

    return DateTime.tryParse(text);
  }

  double _parseNumber(dynamic cell) {
    if (cell == null) return 0;
    if (cell is num) return cell.toDouble();

    var text = cell.toString().trim();
    if (text.isEmpty) return 0;

    text = text
        .replaceAll(r'$', '')
        .replaceAll('COP', '')
        .replaceAll(' ', '')
        .replaceAll('%', '');

    if (text.contains(',') && text.contains('.')) {
      if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
        text = text.replaceAll('.', '').replaceAll(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    } else if (text.contains(',')) {
      text = text.replaceAll(',', '.');
    }

    return double.tryParse(text) ?? 0;
  }

  SaleStatus _classifySaleStatus({
    required String obs,
    required String contract,
    required double vlrVenta,
  }) {
    final normalizedObs = _normalize(obs);

    if (normalizedObs.contains('inactiva')) {
      return SaleStatus.inactive;
    }

    if (normalizedObs.contains('activa')) {
      final match = RegExp(r'([-+]?\d+(?:[\.,]\d+)?)\s*%').firstMatch(obs);
      if (match != null) {
        final valueText = match.group(1) ?? '0';
        final percentage = _parseNumber(valueText);
        return percentage == 0
            ? SaleStatus.activeZero
            : SaleStatus.activePercent;
      }

      if (normalizedObs.contains('0%')) {
        return SaleStatus.activeZero;
      }

      return SaleStatus.activePercent;
    }

    if (contract.trim().isNotEmpty || vlrVenta != 0) {
      return SaleStatus.activePercent;
    }

    return SaleStatus.none;
  }

  String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    final replaced = lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');

    return replaced.replaceAll(RegExp(r'[^a-z0-9%]'), '');
  }
}
