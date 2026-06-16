import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';

class InvoiceStatsScreen extends StatefulWidget {
  final List<Invoice> allInvoices;

  const InvoiceStatsScreen({super.key, required this.allInvoices});

  @override
  State<InvoiceStatsScreen> createState() => _InvoiceStatsScreenState();
}

class _InvoiceStatsScreenState extends State<InvoiceStatsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Future<void> _pickMonth(BuildContext context) async {
    int year = _selectedMonth.year;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setDialogState(() => year--),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$year',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setDialogState(() => year++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final month = DateTime(year, i + 1);
                final isSelected = month.year == _selectedMonth.year &&
                    month.month == _selectedMonth.month;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMonth = month);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderOf(ctx),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('MMM').format(month),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.onSurface(ctx),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = widget.allInvoices
        .where(
          (inv) =>
              inv.issueDate.year == _selectedMonth.year &&
              inv.issueDate.month == _selectedMonth.month,
        )
        .toList();

    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final currency = invoices.isNotEmpty ? invoices.first.currency : '€';

    final monthTotal = invoices.fold(0.0, (s, i) => s + i.totaalInclBtw);
    final monthPaid = invoices
        .where((i) => i.status == 'betaald')
        .fold(0.0, (s, i) => s + i.totaalInclBtw);

    final totalSpots = <FlSpot>[];
    final paidSpots = <FlSpot>[];
    final outstandingSpots = <FlSpot>[];

    for (int d = 1; d <= daysInMonth; d++) {
      final day = invoices.where((inv) => inv.issueDate.day == d).toList();
      final total = day.fold(0.0, (s, i) => s + i.totaalInclBtw);
      final paid = day
          .where((i) => i.status == 'betaald')
          .fold(0.0, (s, i) => s + i.totaalInclBtw);
      totalSpots.add(FlSpot(d.toDouble(), total));
      paidSpots.add(FlSpot(d.toDouble(), paid));
      outstandingSpots.add(FlSpot(d.toDouble(), total - paid));
    }

    final maxY = totalSpots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY == 0 ? 100.0 : maxY * 1.3;

    // Additional stats
    final avgValue = invoices.isNotEmpty ? monthTotal / invoices.length : 0.0;
    final taxTotal = invoices.fold(
      0.0,
      (s, i) => s + i.subtotaalExBtw * (i.taxRate / 100),
    );
    final paymentRate = monthTotal > 0 ? monthPaid / monthTotal * 100 : 0.0;
    final largestInvoice = invoices.isEmpty
        ? null
        : invoices.reduce(
            (a, b) => a.totaalInclBtw >= b.totaalInclBtw ? a : b,
          );

    final clientTotals = <String, double>{};
    for (final inv in invoices) {
      clientTotals[inv.clientNaam] =
          (clientTotals[inv.clientNaam] ?? 0) + inv.totaalInclBtw;
    }
    final topClients = (clientTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    final conceptCount =
        invoices.where((i) => i.status == 'concept').length;
    final betaaldCount =
        invoices.where((i) => i.status == 'betaald').length;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _pickMonth(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        backgroundColor: AppTheme.surf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          _SummaryRow(
            currency: currency,
            total: monthTotal,
            paid: monthPaid,
            count: invoices.length,
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chart
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
                    child: SizedBox(
                      height: 240,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppTheme.surf(context),
                              tooltipBorder: BorderSide(
                                color: AppTheme.borderOf(context),
                              ),
                              tooltipRoundedRadius: 8,
                              getTooltipItems: (spots) =>
                                  spots.map((spot) {
                                    const colors = [
                                      AppTheme.primary,
                                      Color(0xFF10B981),
                                      AppTheme.error,
                                    ];
                                    const labels = [
                                      'Totaal',
                                      'Betaald',
                                      'Openstaand',
                                    ];
                                    return LineTooltipItem(
                                      '${labels[spot.barIndex]}\n',
                                      TextStyle(
                                        color: colors[spot.barIndex],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '$currency${spot.y.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: AppTheme.onSurface(context),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: chartMaxY / 4,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: AppTheme.borderOf(context).withAlpha(100),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 7,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final day = value.toInt();
                                  if (value == meta.min || value == meta.max) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '$day',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                interval: chartMaxY / 4,
                                getTitlesWidget: (value, meta) {
                                  if (value == meta.min ||
                                      value == meta.max) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = value >= 1000
                                      ? '$currency${(value / 1000).toStringAsFixed(1)}k'
                                      : '$currency${value.toStringAsFixed(0)}';
                                  return Text(
                                    label,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: daysInMonth.toDouble(),
                          minY: 0,
                          maxY: chartMaxY,
                          lineBarsData: [
                            _bar(totalSpots, AppTheme.primary),
                            _bar(paidSpots, const Color(0xFF10B981)),
                            _bar(outstandingSpots, AppTheme.error),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const _Legend(),
                  const SizedBox(height: 28),

                  // ── Analyse ───────────────────────────────────────────────
                  if (invoices.isNotEmpty) ...[
                    _SectionHeader('Analyse'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Gemiddeld',
                              value:
                                  '$currency${avgValue.toStringAsFixed(0)}',
                              icon: Icons.calculate_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'BTW afdracht',
                              value:
                                  '$currency${taxTotal.toStringAsFixed(0)}',
                              icon: Icons.account_balance_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Betaald',
                              value: '${paymentRate.toStringAsFixed(0)}%',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Grootste factuur',
                              value: largestInvoice != null
                                  ? '$currency${largestInvoice.totaalInclBtw.toStringAsFixed(0)}'
                                  : '—',
                              icon: Icons.trending_up_rounded,
                              color: AppTheme.primary,
                              subtitle: largestInvoice?.invoiceNumber,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Status verdeling ──────────────────────────────────
                    _SectionHeader('Status'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _StatusBreakdown(
                        concept: conceptCount,
                        betaald: betaaldCount,
                        total: invoices.length,
                      ),
                    ),

                    // ── Top klanten ───────────────────────────────────────
                    if (topClients.isNotEmpty) ...[
                      _SectionHeader('Top klanten'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            for (int i = 0; i < topClients.length; i++)
                              _ClientRow(
                                rank: i + 1,
                                name: topClients[i].key,
                                amount: topClients[i].value,
                                share: monthTotal > 0
                                    ? topClients[i].value / monthTotal
                                    : 0,
                                currency: currency,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Empty state below chart
                  if (invoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 32,
                      ),
                      child: Center(
                        child: Text(
                          'Geen facturen in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static LineChartBarData _bar(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withAlpha(18)),
      );
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String currency;
  final double total, paid;
  final int count;

  const _SummaryRow({
    required this.currency,
    required this.total,
    required this.paid,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.surf(context),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(
      children: [
        _Cell('Totaal', '$currency${total.toStringAsFixed(0)}',
            AppTheme.onSurface(context)),
        _divider(context),
        _Cell('Betaald', '$currency${paid.toStringAsFixed(0)}',
            const Color(0xFF10B981)),
        _divider(context),
        _Cell('Openstaand', '$currency${(total - paid).toStringAsFixed(0)}',
            AppTheme.error),
        _divider(context),
        _Cell('Aantal', '$count', AppTheme.onSurfaceVariant(context)),
      ],
    ),
  );

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: AppTheme.borderOf(context),
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );
}

class _Cell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Cell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ],
  );
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _LegendDot('Totaal', AppTheme.primary),
      const SizedBox(width: 20),
      _LegendDot('Betaald', Color(0xFF10B981)),
      const SizedBox(width: 20),
      _LegendDot('Openstaand', AppTheme.error),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    ],
  );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurfaceVariant(context),
        letterSpacing: 0.4,
      ),
    ),
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle ?? '',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Status breakdown ──────────────────────────────────────────────────────────

class _StatusBreakdown extends StatelessWidget {
  final int concept, betaald, total;
  const _StatusBreakdown({
    required this.concept,
    required this.betaald,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        children: [
          _StatusRow(
            label: 'Betaald',
            count: betaald,
            total: total,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Concept',
            count: concept,
            total: total,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _StatusRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final share = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${(share * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 5,
            backgroundColor: color.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Client row ────────────────────────────────────────────────────────────────

class _ClientRow extends StatelessWidget {
  final int rank;
  final String name, currency;
  final double amount, share;
  const _ClientRow({
    required this.rank,
    required this.name,
    required this.amount,
    required this.share,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppTheme.primary.withAlpha(26)
                  : AppTheme.borderOf(context).withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank == 1
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor: AppTheme.primary.withAlpha(20),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
