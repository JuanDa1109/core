import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import '../services/centra_repository.dart';

class AppController extends ChangeNotifier {
  AppController({required CentraRepository repository})
    : _repository = repository;

  final CentraRepository _repository;

  DashboardData _dashboard = DashboardData(liners: const [], closers: const []);
  List<ImportHistoryItem> _imports = const [];
  DateTimeRange? _dateRange;
  bool _loading = false;
  String? _error;

  DashboardData get dashboard => _dashboard;
  List<ImportHistoryItem> get imports => _imports;
  DateTimeRange? get dateRange => _dateRange;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      _dateRange ??= await _repository.latestMonthRange();
      final imports = await _repository.listImports();
      final dashboard = await _repository.loadDashboard(range: _dateRange);
      _imports = imports;
      _dashboard = dashboard;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<ImportResult?> importFromPicker() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: false,
    );

    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) return null;

    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.importManifest(path);
      _dateRange = await _repository.latestMonthRange();
      await refresh();
      return result;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setDateRange(DateTimeRange? value) async {
    _dateRange = value ?? await _repository.latestMonthRange();
    await refresh();
  }

  Future<String> exportAndShare() async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final data = await _repository.loadDashboard(range: _dateRange);
      final path = await _repository.exportDashboardData(
        data: data,
        range: _dateRange,
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      return path;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<List<String>> searchContracts(String query) {
    if (query.trim().isEmpty) {
      return Future.value(const <String>[]);
    }
    return _repository.searchContracts(query);
  }

  Future<ContractSummary?> contractSummary(String contract) {
    return _repository.contractSummary(contract);
  }

  Future<List<PaymentEntry>> paymentsForContract(String contract) {
    return _repository.paymentsForContract(contract);
  }

  Future<void> addPayment({
    required String contract,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _repository.addPayment(
      contract: contract,
      amount: amount,
      paymentDate: date,
      note: note,
    );
    await refresh();
  }

  Future<void> updatePayment({
    required int id,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    await _repository.updatePayment(
      id: id,
      amount: amount,
      paymentDate: date,
      note: note,
    );
    await refresh();
  }

  Future<void> deletePayment(int id) async {
    await _repository.deletePayment(id);
    await refresh();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
  }
}
