import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/price.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../services/excel_service.dart';

String? _invoiceCount(int count) =>
    count == 0 ? null : '$count ${count == 1 ? 'factuur' : 'facturen'}';

class InvoiceStatsScreen extends StatefulWidget {
  final List<Invoice> allInvoices;

  const InvoiceStatsScreen({super.key, required this.allInvoices});

  @override
  State<InvoiceStatsScreen> createState() => _InvoiceStatsScreenState();
}

/// The first of [date]'s month — the key a month is selected and matched by.
DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

/// Names the selected months for the app bar and the empty state: a single
/// month in full, a whole year as the year, an unbroken run as its two ends,
/// a few loose months one by one, and anything longer as a count.
String _periodLabel(List<DateTime> months) {
  if (months.length == 1) return DateFormat('MMMM yyyy').format(months.first);
  final first = months.first, last = months.last;
  final sameYear = first.year == last.year;
  if (sameYear && months.length == 12) return '${first.year}';
  final span = (last.year - first.year) * 12 + last.month - first.month + 1;
  if (span == months.length) {
    return sameYear
        ? '${DateFormat('MMM').format(first)} – '
              '${DateFormat('MMM yyyy').format(last)}'
        : '${DateFormat('MMM yyyy').format(first)} – '
              '${DateFormat('MMM yyyy').format(last)}';
  }
  if (sameYear && months.length <= 3) {
    return '${months.map(DateFormat('MMM').format).join(', ')} ${first.year}';
  }
  return '${months.length} maanden';
}

class _InvoiceStatsScreenState extends State<InvoiceStatsScreen> {
  /// The months the stats cover, each as the first of its month. Never empty.
  late Set<DateTime> _selectedMonths;

  @override
  void initState() {
    super.initState();
    _selectedMonths = {_monthOf(DateTime.now())};
  }

  static final _compactButton = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    minimumSize: const Size(0, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// The selection in calendar order — what the chart and the title run by.
  List<DateTime> get _sortedMonths =>
      _selectedMonths.toList()..sort((a, b) => a.compareTo(b));

  /// Months are toggled on and off, across years too, and only take effect on
  /// "Toepassen" — so cancelling leaves the stats as they were.
  Future<void> _pickMonth(BuildContext context) async {
    int year = _sortedMonths.last.year;
    final picked = {..._selectedMonths};
    final result = await showDialog<Set<DateTime>>(
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
                final isSelected = picked.contains(month);
                return GestureDetector(
                  onTap: () => setDialogState(() {
                    if (!picked.remove(month)) picked.add(month);
                  }),
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
          // One row under the grid rather than the dialog's own actions bar,
          // which stacks three buttons vertically once they do not fit beside
          // each other. Compact padding keeps them on one line; scaleDown
          // shrinks them rather than overflowing at a large text size.
          actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          actions: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    style: _compactButton,
                    // Ticks the shown year's twelve months, or clears them
                    // when they are all ticked already.
                    onPressed: () => setDialogState(() {
                      final yearMonths = [
                        for (var m = 1; m <= 12; m++) DateTime(year, m),
                      ];
                      if (yearMonths.every(picked.contains)) {
                        picked.removeAll(yearMonths);
                      } else {
                        picked.addAll(yearMonths);
                      }
                    }),
                    child: const Text('Hele jaar'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    style: _compactButton,
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuleren'),
                  ),
                  TextButton(
                    style: _compactButton,
                    onPressed: picked.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, picked),
                    child: const Text('Toepassen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedMonths = result);
    }
  }

  /// Offers a year and downloads it as the Inkomsten overzicht: an Excel file
  /// listing that year's invoices with the quarter totals beside them.
  Future<void> _downloadIncomeOverview(BuildContext context) async {
    final years = ExcelService.availableYears(widget.allInvoices);
    final year = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Inkomsten overzicht',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Excel-bestand met alle facturen van het jaar en de totalen '
                'per kwartaal. Wordt opgeslagen in Downloads.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            const Divider(height: 1),
            ...years.map((y) {
              final count = ExcelService.invoicesForYear(
                widget.allInvoices,
                y,
              ).length;
              return ListTile(
                leading: const Icon(
                  Icons.table_chart_outlined,
                  color: AppTheme.primary,
                ),
                title: Text(
                  '$y',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_invoiceCount(count) ?? 'Geen facturen'),
                trailing: const Icon(Icons.download_outlined, size: 20),
                onTap: () => Navigator.pop(ctx, y),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (year == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final location = await ExcelService.download(
        invoices: widget.allInvoices,
        year: year,
        businessName: widget.allInvoices.isEmpty
            ? ''
            : widget.allInvoices.first.businessName,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Opgeslagen: $location'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Downloaden mislukt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = _sortedMonths;
    final periodLabel = _periodLabel(months);
    final invoices = widget.allInvoices
        .where((inv) => _selectedMonths.contains(_monthOf(inv.issueDate)))
        .toList();

    // The chart runs day by day through the selected months, laid end to end
    // in calendar order: loose months sit side by side rather than across the
    // empty months between them. Day n of the run is plotted at x = n, so a
    // single month reads its day numbers straight off the axis.
    final days = [
      for (final m in months)
        for (var d = 1; d <= DateUtils.getDaysInMonth(m.year, m.month); d++)
          DateTime(m.year, m.month, d),
    ];
    final singleMonth = months.length == 1;
    final spanYears = months.first.year != months.last.year;
    // Several months label their first days instead of day numbers, thinned
    // to about six so they do not collide.
    final monthLabelEvery = (months.length / 6).ceil();
    final currency = invoices.isNotEmpty ? invoices.first.currency : '€';

    final monthTotal = invoices.fold(0.0, (s, i) => s + i.totaalInclBtw);
    final monthPaid = invoices
        .where((i) => i.isPaid)
        .fold(0.0, (s, i) => s + i.totaalInclBtw);

    final totalSpots = <FlSpot>[];
    final cashSpots = <FlSpot>[];
    final cardSpots = <FlSpot>[];
    final outstandingSpots = <FlSpot>[];

    final invoicesByDay = <DateTime, List<Invoice>>{};
    for (final inv in invoices) {
      final d = inv.issueDate;
      invoicesByDay
          .putIfAbsent(DateTime(d.year, d.month, d.day), () => [])
          .add(inv);
    }

    for (int p = 0; p < days.length; p++) {
      final x = p + 1;
      final point = invoicesByDay[days[p]] ?? const <Invoice>[];
      final total = point.fold(0.0, (s, i) => s + i.totaalInclBtw);
      final paid = point
          .where((i) => i.isPaid)
          .fold(0.0, (s, i) => s + i.totaalInclBtw);
      // The two methods are drawn apart, so a point's takings say how they
      // came in. A pre-method 'betaald' invoice counts towards neither line,
      // but still towards the paid total and Openstaand.
      totalSpots.add(FlSpot(x.toDouble(), total));
      cashSpots.add(
        FlSpot(
          x.toDouble(),
          point
              .where((i) => i.status == Invoice.paidCash)
              .fold(0.0, (s, i) => s + i.totaalInclBtw),
        ),
      );
      cardSpots.add(
        FlSpot(
          x.toDouble(),
          point
              .where((i) => i.status == Invoice.paidCard)
              .fold(0.0, (s, i) => s + i.totaalInclBtw),
        ),
      );
      outstandingSpots.add(FlSpot(x.toDouble(), total - paid));
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
        : invoices.reduce((a, b) => a.totaalInclBtw >= b.totaalInclBtw ? a : b);

    final clientTotals = <String, double>{};
    for (final inv in invoices) {
      clientTotals[inv.clientNaam] =
          (clientTotals[inv.clientNaam] ?? 0) + inv.totaalInclBtw;
    }
    final topClients =
        (clientTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .toList();

    final conceptCount = invoices.where((i) => i.status == 'concept').length;

    // Paid split by how it was paid. Invoices settled before the method was
    // recorded keep their own row rather than being guessed into one.
    final cash = invoices.where((i) => i.status == Invoice.paidCash).toList();
    final card = invoices.where((i) => i.status == Invoice.paidCard).toList();
    final legacyPaidCount = invoices.where((i) => i.status == 'betaald').length;
    final cashTotal = cash.fold(0.0, (s, i) => s + i.totaalInclBtw);
    final cardTotal = card.fold(0.0, (s, i) => s + i.totaalInclBtw);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _pickMonth(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  periodLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        backgroundColor: AppTheme.surf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_on_outlined),
            tooltip: 'Inkomsten overzicht',
            onPressed: () => _downloadIncomeOverview(context),
          ),
        ],
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
                              getTooltipItems: (spots) => spots.map((spot) {
                                const colors = [
                                  AppTheme.primary,
                                  AppTheme.cash,
                                  AppTheme.card,
                                  AppTheme.error,
                                ];
                                const labels = [
                                  'Totaal',
                                  'Contant',
                                  'Pin',
                                  'Openstaand',
                                ];
                                // Once several months are shown the axis
                                // names months rather than days, so the
                                // tooltip carries the date above its first
                                // line.
                                final date = spot == spots.first
                                    ? '${DateFormat('d MMM yyyy').format(days[spot.x.toInt() - 1])}\n'
                                    : '';
                                return LineTooltipItem(
                                  '$date${labels[spot.barIndex]}\n',
                                  TextStyle(
                                    color: colors[spot.barIndex],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: formatMoney(
                                        spot.y,
                                        currency: currency,
                                        decimals: 0,
                                      ),
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
                                // A single month labels every seventh day;
                                // several are asked about every day and label
                                // only where a (shown) month begins.
                                interval: singleMonth ? 7 : 1,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final x = value.toInt();
                                  if (value != x || x < 1 || x > days.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final day = days[x - 1];
                                  if (singleMonth) {
                                    if (value == meta.min ||
                                        value == meta.max) {
                                      return const SizedBox.shrink();
                                    }
                                  } else if (day.day != 1 ||
                                      months.indexOf(_monthOf(day)) %
                                              monthLabelEvery !=
                                          0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      singleMonth
                                          ? '$x'
                                          : DateFormat(
                                              spanYears ? 'MMM yy' : 'MMM',
                                            ).format(day),
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
                                      : formatMoney(
                                          value,
                                          currency: currency,
                                          decimals: 0,
                                        );
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
                          maxX: days.length.toDouble(),
                          minY: 0,
                          maxY: chartMaxY,
                          lineBarsData: [
                            _bar(totalSpots, AppTheme.primary),
                            _bar(cashSpots, AppTheme.cash),
                            _bar(cardSpots, AppTheme.card),
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
                              value: formatMoney(
                                avgValue,
                                currency: currency,
                                decimals: 0,
                              ),
                              icon: Icons.calculate_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'BTW afdracht',
                              value: formatMoney(
                                taxTotal,
                                currency: currency,
                                decimals: 0,
                              ),
                              icon: Icons.account_balance_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Contant',
                              value: formatMoney(
                                cashTotal,
                                currency: currency,
                                decimals: 0,
                              ),
                              icon: Icons.payments_rounded,
                              color: AppTheme.cash,
                              subtitle: _invoiceCount(cash.length),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Pin',
                              value: formatMoney(
                                cardTotal,
                                currency: currency,
                                decimals: 0,
                              ),
                              icon: Icons.credit_card_rounded,
                              color: AppTheme.card,
                              subtitle: _invoiceCount(card.length),
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
                                  ? formatMoney(
                                      largestInvoice.totaalInclBtw,
                                      currency: currency,
                                      decimals: 0,
                                    )
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
                        cash: cash.length,
                        card: card.length,
                        legacyPaid: legacyPaidCount,
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
                          'Geen facturen in $periodLabel',
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
        _Cell(
          'Totaal',
          formatMoney(total, currency: currency, decimals: 0),
          AppTheme.onSurface(context),
        ),
        _divider(context),
        _Cell(
          'Betaald',
          formatMoney(paid, currency: currency, decimals: 0),
          const Color(0xFF10B981),
        ),
        _divider(context),
        _Cell(
          'Openstaand',
          formatMoney((total - paid), currency: currency, decimals: 0),
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

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  // Four lines no longer fit on one row on a narrow phone, so the legend
  // wraps rather than overflowing.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 8,
      children: const [
        _LegendDot('Totaal', AppTheme.primary),
        _LegendDot('Contant', AppTheme.cash),
        _LegendDot('Pin', AppTheme.card),
        _LegendDot('Openstaand', AppTheme.error),
      ],
    ),
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
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
  final int concept, cash, card, total;

  /// Invoices paid before the method was recorded. Their row only appears
  /// when there are any, so a month of new invoices does not carry it.
  final int legacyPaid;

  const _StatusBreakdown({
    required this.concept,
    required this.cash,
    required this.card,
    required this.legacyPaid,
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
            label: 'Contant betaald',
            count: cash,
            total: total,
            color: AppTheme.cash,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Pin betaald',
            count: card,
            total: total,
            color: AppTheme.card,
          ),
          if (legacyPaid > 0) ...[
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Betaald',
              count: legacyPaid,
              total: total,
              color: const Color(0xFF10B981),
            ),
          ],
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                formatMoney(amount, currency: currency, decimals: 0),
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
