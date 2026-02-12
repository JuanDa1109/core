import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../domain/models.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final range = controller.dateRange;
    final snapshot = _DashboardSnapshot.fromData(controller.dashboard);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _FilterBar(controller: controller, range: range),
          const SizedBox(height: 14),
          _KpiGrid(snapshot: snapshot),
          const SizedBox(height: 14),
          _PodiumCard(title: 'Liners', rows: snapshot.topLinersBySales),
          const SizedBox(height: 12),
          _PodiumCard(title: 'Closers', rows: snapshot.topClosersByCaja),
          const SizedBox(height: 14),
          _DualPieCard(snapshot: snapshot),
          const SizedBox(height: 14),
          _DetailsTables(controller: controller, data: controller.dashboard),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.range});

  final AppController controller;
  final DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: controller.loading
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final initial =
                          range ??
                          DateTimeRange(
                            start: DateTime(now.year, now.month, 1),
                            end: DateTime(now.year, now.month, now.day),
                          );

                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2010),
                        lastDate: DateTime(2100),
                        initialDateRange: initial,
                        locale: const Locale('es', 'CO'),
                      );

                      if (picked != null) {
                        await controller.setDateRange(picked);
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Rango'),
            ),
            if (range != null)
              InputChip(
                label: Text(
                  '${DateFormat('dd/MM/yyyy').format(range!.start)} - ${DateFormat('dd/MM/yyyy').format(range!.end)}',
                ),
                onDeleted: controller.loading
                    ? null
                    : () {
                        controller.setDateRange(null);
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final totalCaja = _KpiItem(
      'Total Caja',
      _money(snapshot.totalCaja),
      Icons.account_balance_wallet_outlined,
      tone: _KpiTone.success,
      context: 'Cash + GL',
    );
    final rowVentas = [
      _KpiItem(
        'Ventas',
        _fmt(snapshot.totalSales),
        Icons.point_of_sale_outlined,
        tone: _KpiTone.primary,
        context: '${_fmt(snapshot.totalTours)} tours',
      ),
      _KpiItem(
        'Inactivas',
        _fmt(snapshot.totalInactiveSales),
        Icons.block_outlined,
        tone: _KpiTone.danger,
        context: 'Estado inactivo',
      ),
    ];
    final rowTours = [
      _KpiItem(
        'Tours',
        _fmt(snapshot.totalTours),
        Icons.groups_outlined,
        tone: _KpiTone.primary,
        context: 'Q + NQ',
      ),
      _KpiItem(
        'Q',
        _fmt(snapshot.totalQ),
        Icons.verified_outlined,
        tone: _KpiTone.success,
        context: '${_fmt(snapshot.totalSalesQ)} ventas Q',
      ),
      _KpiItem(
        'NQ',
        _fmt(snapshot.totalNq),
        Icons.report_gmailerrorred_outlined,
        tone: _KpiTone.warning,
        context: '${_fmt(snapshot.totalSalesNq)} ventas NQ',
      ),
    ];
    final rowRates = [
      _KpiItem(
        '% Tour',
        _percent(snapshot.tourRate),
        Icons.query_stats_outlined,
        tone: _KpiTone.primary,
        context: 'Ventas / Tours',
      ),
      _KpiItem(
        '% VTA Q',
        _percent(snapshot.vtaQRate),
        Icons.trending_up_outlined,
        tone: _KpiTone.success,
        context: 'Ventas Q / Q',
      ),
      _KpiItem(
        '% VTA NQ',
        _percent(snapshot.vtaNqRate),
        Icons.insights_outlined,
        tone: _KpiTone.warning,
        context: 'Ventas NQ / NQ',
      ),
    ];

    return Column(
      children: [
        _KpiHeroCard(item: totalCaja),
        const SizedBox(height: 8),
        _KpiRow(items: rowVentas),
        const SizedBox(height: 8),
        _KpiRow(items: rowTours),
        const SizedBox(height: 8),
        _KpiRow(items: rowRates),
      ],
    );
  }
}

class _KpiItem {
  const _KpiItem(
    this.label,
    this.value,
    this.icon, {
    required this.tone,
    required this.context,
  });

  final String label;
  final String value;
  final IconData icon;
  final _KpiTone tone;
  final String context;
}

enum _KpiTone { primary, success, warning, danger }

class _KpiPalette {
  const _KpiPalette({
    required this.bgStart,
    required this.bgEnd,
    required this.border,
    required this.iconStart,
    required this.iconEnd,
    required this.valueColor,
    required this.chipBg,
    required this.chipText,
  });

  final Color bgStart;
  final Color bgEnd;
  final Color border;
  final Color iconStart;
  final Color iconEnd;
  final Color valueColor;
  final Color chipBg;
  final Color chipText;
}

_KpiPalette _paletteFor(_KpiTone tone) {
  switch (tone) {
    case _KpiTone.primary:
      return const _KpiPalette(
        bgStart: Color(0xFFF3F8FF),
        bgEnd: Color(0xFFE8F1FF),
        border: Color(0xFFD7E7FF),
        iconStart: Color(0xFF4386FF),
        iconEnd: Color(0xFF245BD8),
        valueColor: Color(0xFF18386E),
        chipBg: Color(0xFFDDEAFF),
        chipText: Color(0xFF1B4DAE),
      );
    case _KpiTone.success:
      return const _KpiPalette(
        bgStart: Color(0xFFF2FCF8),
        bgEnd: Color(0xFFE6F8F1),
        border: Color(0xFFD3F0E5),
        iconStart: Color(0xFF1BAA8B),
        iconEnd: Color(0xFF0F7A66),
        valueColor: Color(0xFF0F4D45),
        chipBg: Color(0xFFD8F3EA),
        chipText: Color(0xFF0D6A57),
      );
    case _KpiTone.warning:
      return const _KpiPalette(
        bgStart: Color(0xFFFFFAF1),
        bgEnd: Color(0xFFFFF4E2),
        border: Color(0xFFF8E8C8),
        iconStart: Color(0xFFF29B38),
        iconEnd: Color(0xFFD97706),
        valueColor: Color(0xFF7A4A10),
        chipBg: Color(0xFFFFECCC),
        chipText: Color(0xFF9A5D10),
      );
    case _KpiTone.danger:
      return const _KpiPalette(
        bgStart: Color(0xFFFFF5F5),
        bgEnd: Color(0xFFFFECEC),
        border: Color(0xFFFAD8D8),
        iconStart: Color(0xFFE95F5F),
        iconEnd: Color(0xFFC62828),
        valueColor: Color(0xFF812626),
        chipBg: Color(0xFFFEDCDC),
        chipText: Color(0xFF9D2E2E),
      );
  }
}

class _KpiHeroCard extends StatelessWidget {
  const _KpiHeroCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(item.tone);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [palette.bgStart, palette.bgEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.iconStart, palette.iconEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5A6780),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: palette.valueColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.context,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.chipText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});

  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: _KpiMiniCard(item: items[i])),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _KpiMiniCard extends StatelessWidget {
  const _KpiMiniCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(item.tone);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF5A6780),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.iconStart, palette.iconEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(item.icon, size: 12, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: palette.valueColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: palette.chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.context,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.chipText,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.title, required this.rows});

  final String title;
  final List<StatsRow> rows;

  @override
  Widget build(BuildContext context) {
    final top = rows
        .where((row) => row.name.trim().isNotEmpty)
        .take(3)
        .toList();

    if (top.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title: sin datos'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _PodiumLegendChip(
                  icon: Icons.bar_chart_rounded,
                  label: 'Vtas',
                  color: Color(0xFF2F6FED),
                ),
                _PodiumLegendChip(
                  icon: Icons.payments_outlined,
                  label: 'Cash',
                  color: Color(0xFF0F766E),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const order = [1, 0, 2];

                Widget slot({required int slotIndex, required bool center}) {
                  if (slotIndex >= top.length) {
                    return const SizedBox.shrink();
                  }
                  return _PodiumPersonTile(
                    row: top[slotIndex],
                    rank: slotIndex + 1,
                    highlighted: center,
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 10,
                      child: slot(slotIndex: order[0], center: false),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 12,
                      child: slot(slotIndex: order[1], center: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 10,
                      child: slot(slotIndex: order[2], center: false),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumPersonTile extends StatelessWidget {
  const _PodiumPersonTile({
    required this.row,
    required this.rank,
    required this.highlighted,
  });

  final StatsRow row;
  final int rank;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final avatarSize = highlighted ? 76.0 : 60.0;
    final rankColors = <int, Color>{
      1: const Color(0xFFEAB308),
      2: const Color(0xFF94A3B8),
      3: const Color(0xFFB45309),
    };
    final accent = rankColors[rank] ?? const Color(0xFF64748B);
    final shortName = _toPodiumName(row.name);
    final initials = _podiumInitials(row.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: rank == 1
              ? Icon(Icons.workspace_premium, color: accent, size: 18)
              : const SizedBox.shrink(),
        ),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.85),
                    const Color(0xFF2F6FED),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: accent, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: highlighted ? 20 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -9,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 11,
              color: Color(0xFF2F6FED),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _fmt(row.totalSales),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 11,
              color: Color(0xFF0F766E),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _money(row.cash),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PodiumLegendChip extends StatelessWidget {
  const _PodiumLegendChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DualPieCard extends StatelessWidget {
  const _DualPieCard({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final chartHeight = constraints.maxWidth < 380 ? 112.0 : 132.0;
            final qVsNq = _PieTile(
              title: 'Q vs NQ',
              subtitle: 'Distribucion de calificacion',
              chartHeight: chartHeight,
              sections: [
                _PieSlice('Q', snapshot.totalQ, const Color(0xFF2F6FED)),
                _PieSlice('NQ', snapshot.totalNq, const Color(0xFF59A3FF)),
              ],
            );
            final salesVsInactive = _PieTile(
              title: 'Ventas vs Inactivas',
              subtitle: 'Incluye ventas 0%',
              chartHeight: chartHeight,
              sections: [
                _PieSlice(
                  'Ventas >0%',
                  snapshot.totalSalesWithCash,
                  const Color(0xFF0F9D87),
                ),
                _PieSlice(
                  'Ventas 0%',
                  snapshot.totalSalesZero,
                  const Color(0xFFF59E0B),
                ),
                _PieSlice(
                  'Inactivas',
                  snapshot.totalInactiveSales,
                  const Color(0xFFFF7043),
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribuciones clave',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (isWide)
                  Row(
                    children: [
                      Expanded(child: qVsNq),
                      const SizedBox(width: 12),
                      Expanded(child: salesVsInactive),
                    ],
                  )
                else
                  Column(
                    children: [
                      qVsNq,
                      const SizedBox(height: 12),
                      salesVsInactive,
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _PieTile extends StatelessWidget {
  const _PieTile({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.chartHeight,
  });

  final String title;
  final String subtitle;
  final List<_PieSlice> sections;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final total = sections.fold<double>(0, (sum, item) => sum + item.value);
    final hasData = total > 0;
    final centerRadius = chartHeight * 0.22;
    final pieRadius = chartHeight * 0.34;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E6FA)),
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFF1F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: const Color(0xFF5B6A82)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: chartHeight,
            child: hasData
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: centerRadius,
                          sections: sections
                              .map(
                                (item) => PieChartSectionData(
                                  value: item.value,
                                  color: item.color,
                                  radius: pieRadius,
                                  title: _percent(item.value / total),
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      Container(
                        width: centerRadius * 1.7,
                        height: centerRadius * 1.7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _fmt(total),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: Text('Sin datos')),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sections
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${item.label}: ${_fmt(item.value)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DetailsTables extends StatelessWidget {
  const _DetailsTables({required this.controller, required this.data});

  final AppController controller;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle de tablas',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          const Text('Liners y closers con todas las metricas'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ExportTablesButton(
                      controller: controller,
                      compact: compact,
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDDE7F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                _StatsTable(title: 'LINERS', rows: data.liners),
                const SizedBox(height: 12),
                _StatsTable(title: 'CLOSERS', rows: data.closers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportTablesButton extends StatelessWidget {
  const _ExportTablesButton({required this.controller, required this.compact});

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: controller.loading
          ? null
          : () async {
              try {
                final path = await controller.exportAndShare();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Exportado en: $path')));
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
      icon: const Icon(Icons.file_download_outlined, size: 18),
      label: Text(
        controller.loading
            ? 'Exportando...'
            : (compact ? 'Exportar' : 'Exportar Excel'),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2F6FED),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF9CB6EE),
        disabledForegroundColor: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x332F6FED),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 10 : 11,
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.title, required this.rows});

  final String title;
  final List<StatsRow> rows;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,##0.##', 'es_CO');
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: const Color(0xFF1E3A5F),
    );
    final totals = StatsRow(name: 'TOTALES')
      ..salesActive = rows.fold(0, (sum, row) => sum + row.salesActive)
      ..salesInactive = rows.fold(0, (sum, row) => sum + row.salesInactive)
      ..volume = rows.fold(0, (sum, row) => sum + row.volume)
      ..cash = rows.fold(0, (sum, row) => sum + row.cash)
      ..gl = rows.fold(0, (sum, row) => sum + row.gl)
      ..q = rows.fold(0, (sum, row) => sum + row.q)
      ..salesQ = rows.fold(0, (sum, row) => sum + row.salesQ)
      ..nq = rows.fold(0, (sum, row) => sum + row.nq)
      ..salesNq = rows.fold(0, (sum, row) => sum + row.salesNq);

    DataCell numberCell(
      String value, {
      bool emphasize = false,
      bool isTotal = false,
    }) {
      return DataCell(
        SizedBox(
          width: 88,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isTotal
                    ? FontWeight.w800
                    : (emphasize ? FontWeight.w800 : FontWeight.w600),
                color: isTotal
                    ? const Color(0xFF0F172A)
                    : (emphasize
                          ? const Color(0xFF0F4D45)
                          : const Color(0xFF334155)),
              ),
            ),
          ),
        ),
      );
    }

    DataColumn column(String label) =>
        DataColumn(label: Text(label, style: headerStyle));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E4F5)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              gradient: LinearGradient(
                colors: [Color(0xFFF3F8FF), Color(0xFFEAF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEAFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rows.length} filas',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4E89),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No hay datos para mostrar.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 10,
                headingRowHeight: 38,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFEFF5FF),
                ),
                border: TableBorder(
                  horizontalInside: const BorderSide(color: Color(0xFFE2EAF6)),
                  verticalInside: const BorderSide(color: Color(0xFFEDF2FA)),
                ),
                columns: [
                  column('Nombre'),
                  column('Ventas'),
                  column('Inactivas'),
                  column('Volumen'),
                  column('Cash'),
                  column('GL'),
                  column('Total Caja'),
                  column('Q'),
                  column('Ventas Q'),
                  column('% VTA Q'),
                  column('NQ'),
                  column('Ventas NQ'),
                  column('% VTA NQ'),
                  column('Tours'),
                  column('% TOUR'),
                ],
                rows: [
                  ...List.generate(rows.length, (index) {
                    final row = rows[index];
                    return DataRow.byIndex(
                      index: index,
                      color: WidgetStatePropertyAll(
                        index.isEven ? Colors.white : const Color(0xFFF9FBFF),
                      ),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              row.name.isEmpty ? '-' : row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                        numberCell(format.format(row.salesActive)),
                        numberCell(format.format(row.salesInactive)),
                        numberCell(format.format(row.volume)),
                        numberCell(format.format(row.cash)),
                        numberCell(format.format(row.gl)),
                        numberCell(
                          format.format(row.totalCaja),
                          emphasize: true,
                        ),
                        numberCell(format.format(row.q)),
                        numberCell(format.format(row.salesQ)),
                        numberCell(_percent(row.percentVtaQ)),
                        numberCell(format.format(row.nq)),
                        numberCell(format.format(row.salesNq)),
                        numberCell(_percent(row.percentVtaNq)),
                        numberCell(format.format(row.tours)),
                        numberCell(_percent(row.percentTour)),
                      ],
                    );
                  }),
                  DataRow(
                    color: const WidgetStatePropertyAll(Color(0xFFE8F1FF)),
                    cells: [
                      const DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            'TOTALES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      numberCell(
                        format.format(totals.salesActive),
                        isTotal: true,
                      ),
                      numberCell(
                        format.format(totals.salesInactive),
                        isTotal: true,
                      ),
                      numberCell(format.format(totals.volume), isTotal: true),
                      numberCell(format.format(totals.cash), isTotal: true),
                      numberCell(format.format(totals.gl), isTotal: true),
                      numberCell(
                        format.format(totals.totalCaja),
                        isTotal: true,
                      ),
                      numberCell(format.format(totals.q), isTotal: true),
                      numberCell(format.format(totals.salesQ), isTotal: true),
                      numberCell(_percent(totals.percentVtaQ), isTotal: true),
                      numberCell(format.format(totals.nq), isTotal: true),
                      numberCell(format.format(totals.salesNq), isTotal: true),
                      numberCell(_percent(totals.percentVtaNq), isTotal: true),
                      numberCell(format.format(totals.tours), isTotal: true),
                      numberCell(_percent(totals.percentTour), isTotal: true),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardSnapshot {
  const _DashboardSnapshot({
    required this.totalSales,
    required this.totalSalesZero,
    required this.totalSalesWithCash,
    required this.totalInactiveSales,
    required this.totalQ,
    required this.totalNq,
    required this.totalTours,
    required this.totalSalesQ,
    required this.totalSalesNq,
    required this.totalCaja,
    required this.tourRate,
    required this.vtaQRate,
    required this.vtaNqRate,
    required this.topLinersBySales,
    required this.topClosersByCaja,
  });

  final double totalSales;
  final double totalSalesZero;
  final double totalSalesWithCash;
  final double totalInactiveSales;
  final double totalQ;
  final double totalNq;
  final double totalTours;
  final double totalSalesQ;
  final double totalSalesNq;
  final double totalCaja;
  final double tourRate;
  final double vtaQRate;
  final double vtaNqRate;
  final List<StatsRow> topLinersBySales;
  final List<StatsRow> topClosersByCaja;

  factory _DashboardSnapshot.fromData(DashboardData data) {
    var totalSales = 0.0;
    var totalSalesZero = 0.0;
    var totalInactiveSales = 0.0;
    var totalQ = 0.0;
    var totalNq = 0.0;
    var totalTours = 0.0;
    var totalSalesQ = 0.0;
    var totalSalesNq = 0.0;
    var totalCaja = 0.0;

    for (final row in data.liners) {
      totalSales += row.salesActive;
      totalSalesZero += row.salesActiveZero;
      totalInactiveSales += row.salesInactive;
      totalQ += row.q;
      totalNq += row.nq;
      totalTours += row.tours;
      totalSalesQ += row.salesQ;
      totalSalesNq += row.salesNq;
      totalCaja += row.totalCaja;
    }

    final tourRate = totalTours == 0
        ? 0.0
        : (totalSales + totalInactiveSales) / totalTours;
    final vtaQRate = totalQ == 0 ? 0.0 : totalSalesQ / totalQ;
    final vtaNqRate = totalNq == 0 ? 0.0 : totalSalesNq / totalNq;
    final totalSalesWithCash = math.max(0.0, totalSales - totalSalesZero);

    final topLiners = [...data.liners]
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    final topClosers = [...data.closers]
      ..sort((a, b) => b.totalCaja.compareTo(a.totalCaja));

    return _DashboardSnapshot(
      totalSales: totalSales,
      totalSalesZero: totalSalesZero,
      totalSalesWithCash: totalSalesWithCash,
      totalInactiveSales: totalInactiveSales,
      totalQ: totalQ,
      totalNq: totalNq,
      totalTours: totalTours,
      totalSalesQ: totalSalesQ,
      totalSalesNq: totalSalesNq,
      totalCaja: totalCaja,
      tourRate: tourRate,
      vtaQRate: vtaQRate,
      vtaNqRate: vtaNqRate,
      topLinersBySales: topLiners,
      topClosersByCaja: topClosers,
    );
  }
}

String _fmt(double value) => NumberFormat('#,##0.##', 'es_CO').format(value);
String _money(double value) => NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
).format(value);
String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

String _toPodiumName(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = _toTitleWord(parts.first);
  if (parts.length == 1) return first;
  final nextInitial = parts[1][0].toUpperCase();
  return '$first $nextInitial.';
}

String _podiumInitials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
}

String _toTitleWord(String value) {
  if (value.isEmpty) return value;
  final lower = value.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}
