import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportacion lista para operacion diaria',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const _RuleLine('Genera tablas LINERS y CLOSERS.'),
                const _RuleLine(
                  'Respeta formulas de caja, tours y conversion.',
                ),
                const _RuleLine('Guarda local y abre compartir en un paso.'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: controller.loading
                      ? null
                      : () async {
                          try {
                            final path = await controller.exportAndShare();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Exportado en: $path')),
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo generar el archivo de exportacion.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    controller.loading
                        ? 'Procesando exportacion...'
                        : 'Exportar y compartir',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
