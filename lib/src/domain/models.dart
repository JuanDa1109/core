enum SaleStatus { activePercent, activeZero, inactive, none }

class ManifestRecord {
  ManifestRecord({
    required this.fecha,
    required this.sourceId,
    required this.liner,
    required this.closer,
    required this.contract,
    required this.vlrVenta,
    required this.cash,
    required this.gl,
    required this.calif,
    required this.obs,
    required this.saleStatus,
    required this.sourceRow,
  });

  final DateTime fecha;
  final String sourceId;
  final String liner;
  final String closer;
  final String contract;
  final double vlrVenta;
  final double cash;
  final double gl;
  final String calif;
  final String obs;
  final SaleStatus saleStatus;
  final int sourceRow;
}

class ImportResult {
  ImportResult({
    required this.importId,
    required this.totalRows,
    required this.insertedRows,
    required this.skippedRows,
    this.backupPath,
  });

  final int importId;
  final int totalRows;
  final int insertedRows;
  final int skippedRows;
  final String? backupPath;
}

class StatsRow {
  StatsRow({required this.name});

  final String name;
  double salesActive = 0;
  double salesActiveZero = 0;
  double salesInactive = 0;
  double salesQ = 0;
  double salesNq = 0;
  double volume = 0;
  double cash = 0;
  double gl = 0;
  double q = 0;
  double nq = 0;

  double get totalSales => salesActive + salesInactive;
  double get totalCaja => cash + gl;
  double get tours => q + nq;
  double get percentTour => tours == 0 ? 0 : totalSales / tours;
  double get percentVtaQ => q == 0 ? 0 : salesQ / q;
  double get percentVtaNq => nq == 0 ? 0 : salesNq / nq;
}

class ContractSummary {
  ContractSummary({
    required this.contract,
    required this.status,
    required this.vlrVenta,
    required this.baseCash,
    required this.paymentsCash,
  });

  final String contract;
  final SaleStatus status;
  final double vlrVenta;
  final double baseCash;
  final double paymentsCash;

  double get totalCash => baseCash + paymentsCash;
}

class PaymentEntry {
  PaymentEntry({
    required this.id,
    required this.contract,
    required this.amount,
    required this.paymentDate,
    this.note,
  });

  final int id;
  final String contract;
  final double amount;
  final DateTime paymentDate;
  final String? note;
}

class DashboardData {
  DashboardData({required this.liners, required this.closers});

  final List<StatsRow> liners;
  final List<StatsRow> closers;
}

class ImportHistoryItem {
  ImportHistoryItem({
    required this.id,
    required this.fileName,
    required this.importedAt,
    required this.totalRows,
    required this.insertedRows,
    required this.skippedRows,
  });

  final int id;
  final String fileName;
  final DateTime importedAt;
  final int totalRows;
  final int insertedRows;
  final int skippedRows;
}
