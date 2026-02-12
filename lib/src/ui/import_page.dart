import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../domain/models.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final imports = controller.imports;
    final latest = imports.isEmpty ? null : imports.first;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Importa el manifiesto para recalcular estadisticas',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Compatible con archivo .xlsx. Se guarda en base local y evita duplicados.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B83),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: controller.loading
                        ? null
                        : () async {
                            try {
                              final result = await controller
                                  .importFromPicker();
                              if (result == null || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_message(result))),
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo importar el archivo.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(
                      controller.loading
                          ? 'Procesando importacion...'
                          : 'Seleccionar manifiesto (.xlsx)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Imports',
                  value: '${imports.length}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Ultimo',
                  value: latest == null
                      ? '--'
                      : '${latest.importedAt.day.toString().padLeft(2, '0')}/${latest.importedAt.month.toString().padLeft(2, '0')}/${latest.importedAt.year}',
                  icon: Icons.event_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Historial de importaciones',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (imports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aun no hay importaciones registradas.'),
              ),
            )
          else
            ...imports.map(_ImportItem.new),
        ],
      ),
    );
  }

  String _message(ImportResult result) {
    return 'Import #${result.importId}: ${result.insertedRows} insertados, ${result.skippedRows} omitidos de ${result.totalRows} filas.';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D6B83),
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportItem extends StatelessWidget {
  const _ImportItem(this.item);

  final ImportHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart_outlined, size: 20),
          ),
          title: Text(
            item.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Insertados: ${item.insertedRows}  |  Omitidos: ${item.skippedRows}',
          ),
          trailing: Text(
            '${item.importedAt.day.toString().padLeft(2, '0')}/${item.importedAt.month.toString().padLeft(2, '0')}/${item.importedAt.year}',
          ),
        ),
      ),
    );
  }
}
