import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../domain/models.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _queryController = TextEditingController();

  List<String> _results = const [];
  String? _selectedContract;
  ContractSummary? _summary;
  List<PaymentEntry> _payments = const [];
  bool _busy = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Busqueda de contrato',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Contrato',
                          prefixText: 'CTB',
                          hintText: 'Ej: 0000442',
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _search,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _results
                        .map(
                          (contract) => ChoiceChip(
                            label: Text(contract),
                            selected: _selectedContract == contract,
                            onSelected: _busy
                                ? null
                                : (_) {
                                    _selectContract(contract);
                                  },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_selectedContract != null) ...[
          _SummaryCard(summary: _summary),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _openPaymentDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Registrar abono'),
            ),
          ),
          const SizedBox(height: 12),
          _PaymentsTable(
            payments: _payments,
            onEdit: _busy ? null : _openPaymentDialog,
            onDelete: _busy ? null : _deletePayment,
          ),
        ] else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Busca y selecciona un contrato para ver detalles.'),
            ),
          ),
      ],
    );
  }

  Future<void> _search() async {
    final contractDigits = _queryController.text.trim();
    if (contractDigits.isEmpty) return;
    final normalized = 'CTB$contractDigits';

    setState(() => _busy = true);
    try {
      var results = await widget.controller.searchContracts(normalized);
      if (results.isEmpty) {
        results = await widget.controller.searchContracts(contractDigits);
      }
      setState(() {
        _results = results;
      });

      if (results.length == 1) {
        await _selectContract(results.first);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _selectContract(String contract) async {
    setState(() {
      _busy = true;
      _selectedContract = contract;
    });

    try {
      final summary = await widget.controller.contractSummary(contract);
      final payments = await widget.controller.paymentsForContract(contract);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _payments = payments;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPaymentDialog([PaymentEntry? payment]) async {
    final contract = _selectedContract;
    if (contract == null) return;

    final amountController = TextEditingController(
      text: payment == null ? '' : _moneyInput(payment.amount),
    );
    final noteController = TextEditingController(text: payment?.note ?? '');
    DateTime selectedDate = payment?.paymentDate ?? DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(payment == null ? 'Nuevo abono' : 'Editar abono'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_MoneyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Monto a aplicar',
                      prefixText: r'$ ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota opcional',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2010),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Fecha'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final amount = _parseAmount(amountController.text);
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor a cero.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (payment == null) {
        await widget.controller.addPayment(
          contract: contract,
          amount: amount,
          date: selectedDate,
          note: noteController.text,
        );
      } else {
        await widget.controller.updatePayment(
          id: payment.id,
          amount: amount,
          date: selectedDate,
          note: noteController.text,
        );
      }
      await _selectContract(contract);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePayment(PaymentEntry payment) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar abono'),
            content: const Text('Esta accion no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final contract = _selectedContract;
    if (contract == null) return;

    setState(() => _busy = true);
    try {
      await widget.controller.deletePayment(payment.id);
      await _selectContract(contract);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _parseAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ContractSummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Selecciona un contrato valido.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: 'Contrato', value: summary!.contract),
            _Pill(label: 'Estado', value: summary!.status.name),
            _Pill(label: 'Vlr Venta', value: _money(summary!.vlrVenta)),
            _Pill(label: 'Cash base', value: _money(summary!.baseCash)),
            _Pill(label: 'Abonos', value: _money(summary!.paymentsCash)),
            _Pill(label: 'Cash total', value: _money(summary!.totalCash)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFD7E5FA)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({
    required this.payments,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PaymentEntry> payments;
  final ValueChanged<PaymentEntry>? onEdit;
  final ValueChanged<PaymentEntry>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay abonos registrados para este contrato.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Monto')),
              DataColumn(label: Text('Nota')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: payments
                .map(
                  (payment) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('dd/MM/yyyy').format(payment.paymentDate),
                        ),
                      ),
                      DataCell(Text(_money(payment.amount))),
                      DataCell(
                        SizedBox(width: 220, child: Text(payment.note ?? '')),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              onPressed: onEdit == null
                                  ? null
                                  : () => onEdit!(payment),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: onDelete == null
                                  ? null
                                  : () => onDelete!(payment),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

String _money(double value) => NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
).format(value);

String _moneyInput(double value) =>
    NumberFormat.decimalPattern('es_CO').format(value.round());

class _MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.tryParse(digits);
    if (number == null) {
      return oldValue;
    }

    final formatted = NumberFormat.decimalPattern('es_CO').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
