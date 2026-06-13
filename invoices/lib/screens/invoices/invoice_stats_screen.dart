import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';

class InvoiceStatsScreen extends StatelessWidget {
  final List<Invoice> invoices;
  final DateTime month;

  const InvoiceStatsScreen({
    super.key,
    required this.invoices,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final currency = invoices.isNotEmpty ? invoices.first.currency : '€';

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

    final maxY = totalSpots
        .map((s) => s.y)
        .fold(0.0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY == 0 ? 100.0 : maxY * 1.3;

    final monthTotal = invoices.fold(0.0, (s, i) => s + i.totaalInclBtw);
    final monthPaid = invoices
        .where((i) => i.status == 'betaald')
        .fold(0.0, (s, i) => s + i.totaalInclBtw);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(month)),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 24, 16),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surf(context),
                      tooltipBorder: BorderSide(
                        color: AppTheme.borderOf(context),
                      ),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) => spots.map((spot) {
                        const colors = [
                          AppTheme.primary,
                          Color(0xFF10B981),
                          AppTheme.error,
                        ];
                        const labels = ['Totaal', 'Betaald', 'Openstaand'];
                        return LineTooltipItem(
                          '${labels[spot.barIndex]}\n',
                          TextStyle(
                            color: colors[spot.barIndex],
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: '$currency${spot.y.toStringAsFixed(0)}',
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
                          if (value == meta.min || value == meta.max) {
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
          const SizedBox(height: 20),
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
        belowBarData: BarAreaData(
          show: true,
          color: color.withAlpha(18),
        ),
      );
}

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
        _Cell(
          'Totaal',
          '$currency${total.toStringAsFixed(0)}',
          AppTheme.onSurface(context),
        ),
        _divider(context),
        _Cell(
          'Betaald',
          '$currency${paid.toStringAsFixed(0)}',
          const Color(0xFF10B981),
        ),
        _divider(context),
        _Cell(
          'Openstaand',
          '$currency${(total - paid).toStringAsFixed(0)}',
          AppTheme.error,
        ),
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
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
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
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    ],
  );
}
