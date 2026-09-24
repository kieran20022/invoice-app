import 'dart:collection';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/invoice.dart';
import 'download_service.dart';

/// Builds the "Inkomsten overzicht": one spreadsheet per year listing every
/// invoice with its VAT split, and a quarter block on the right that totals
/// each quarter and carries a running cumulative through the year.
///
/// The workbook is written as raw OOXML rather than through a spreadsheet
/// package: the file is a handful of XML parts, and writing them here keeps
/// the formatting (currency, dates, the quarter block) under our own control
/// without a dependency beyond the zip encoder.
class ExcelService {
  static const String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Row the header sits on; the data starts directly under it.
  static const int _headerRow = 2;
  static const int _firstDataRow = _headerRow + 1;

  static String filename(int year, String businessName) {
    final name = businessName.trim().isEmpty ? '' : ' ${businessName.trim()}';
    return 'Inkomsten$name $year.xlsx'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
  }

  /// The invoices that belong on the overview of [year]: paid invoices, no
  /// quotes, counted on the day they were paid rather than the day they were
  /// written, oldest first and — within one day — by invoice number.
  ///
  /// An invoice that is still open is not income and stays off the overview
  /// entirely. One settled before the payment stamp existed carries no
  /// `paidAt` and falls back to its issue date; see [Invoice.paymentDate].
  static List<Invoice> invoicesForYear(List<Invoice> invoices, int year) =>
      invoices
          .where((i) => !i.isQuote && i.isPaid && i.paymentDate.year == year)
          .toList()
        ..sort(_byDateThenNumber);

  /// Date ascending, then invoice number ascending. Two invoices paid on the
  /// same day would otherwise land in whatever order the stream happened to
  /// carry them.
  static int _byDateThenNumber(Invoice a, Invoice b) {
    final byDay = _day(a.paymentDate).compareTo(_day(b.paymentDate));
    if (byDay != 0) return byDay;
    return _compareNumbers(a.invoiceNumber, b.invoiceNumber);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Compares invoice numbers by their sequence rather than as text, so
  /// `F9` sorts before `F10`. Numbers that carry no digits, or differ outside
  /// them, fall back to a plain string comparison.
  static int _compareNumbers(String a, String b) {
    final na = _sequence(a);
    final nb = _sequence(b);
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    return a.compareTo(b);
  }

  static int? _sequence(String number) {
    final match = RegExp(r'(\d+)\s*$').firstMatch(number);
    return match == null ? null : int.tryParse(match[1]!);
  }

  /// Every year that has at least one invoice, newest first. The current year
  /// is always offered, even when it is still empty.
  static List<int> availableYears(List<Invoice> invoices) {
    final years = <int>{DateTime.now().year};
    for (final inv in invoices) {
      if (!inv.isQuote && inv.isPaid) years.add(inv.paymentDate.year);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  static Uint8List build({
    required List<Invoice> invoices,
    required int year,
    String businessName = '',
  }) {
    final rows = invoicesForYear(invoices, year);
    final archive = Archive();
    void add(String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content));

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook(year));
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _styles);
    add(
      'xl/worksheets/sheet1.xml',
      _sheet(rows: rows, year: year, businessName: businessName),
    );

    return ZipEncoder().encodeBytes(archive);
  }

  /// Builds the workbook and downloads it — into the device's Downloads
  /// rather than through the share sheet: the overview is opened in a
  /// spreadsheet later, not sent to someone. Returns where it was saved.
  static Future<String> download({
    required List<Invoice> invoices,
    required int year,
    String businessName = '',
  }) =>
      DownloadService.save(
        bytes: build(
          invoices: invoices,
          year: year,
          businessName: businessName,
        ),
        filename: filename(year, businessName),
        mimeType: mimeType,
      );

  // ── Sheet ───────────────────────────────────────────────────────────────

  static String _sheet({
    required List<Invoice> rows,
    required int year,
    required String businessName,
  }) {
    final lastDataRow =
        rows.isEmpty ? _firstDataRow : _firstDataRow + rows.length - 1;
    final totalRow = lastDataRow + 1;

    // Cells are collected per row number and emitted in order: on a year with
    // fewer than four invoices the quarter block runs past the totals row, so
    // the rows are not written in the order they are built.
    final sheet = SplayTreeMap<int, StringBuffer>();
    void cells(int row, String xml, {String attrs = ''}) {
      if (xml.isEmpty) return;
      (sheet[row] ??= StringBuffer('<row r="$row"$attrs>')).write(xml);
    }

    // Title
    final titleName =
        businessName.trim().isEmpty ? '' : '${businessName.trim()} ';
    cells(1, _str('A1', 'Inkomsten $titleName$year', _sTitle),
        attrs: ' ht="21" customHeight="1"');

    // Header — the invoice list and the quarter block share one header row.
    const headers = [
      'Nummer',
      'Datum',
      'Klant',
      'Kenteken',
      'KM Stand',
      'Prijs excl. btw',
      'Btw %',
      'Btw bedrag',
      'Incl. btw',
      'Betaald',
    ];
    const quarterHeaders = [
      'Kwartaal',
      'Excl. btw',
      'Btw',
      'Incl. btw',
      'Facturen',
      'Cum. excl. btw',
      'Cum. btw',
      'Cum. incl. btw',
    ];
    final header = StringBuffer();
    for (var i = 0; i < headers.length; i++) {
      header.write(_str('${_col(i)}$_headerRow', headers[i], _sHeader));
    }
    for (var i = 0; i < quarterHeaders.length; i++) {
      header
          .write(_str('${_col(i + 11)}$_headerRow', quarterHeaders[i], _sHeader));
    }
    cells(_headerRow, header.toString(), attrs: ' ht="18" customHeight="1"');

    // Invoice rows.
    for (var i = 0; i < rows.length; i++) {
      final r = _firstDataRow + i;
      final inv = rows[i];
      final ref = inv.clientKenteken.isNotEmpty
          ? inv.clientKenteken
          : inv.clientProductType;
      final row = StringBuffer()
        ..write(_str('A$r', inv.numberLabel, _sText))
        ..write(_num('B$r', _excelDate(inv.paymentDate), _sDate))
        ..write(_str('C$r', inv.clientNaam, _sText))
        ..write(_str('D$r', ref, _sText))
        ..write(_str('E$r', inv.clientKmstand, _sText))
        ..write(_num('F$r', _round(inv.subtotaalExBtw), _sMoney))
        ..write(_num('G$r', _round(inv.taxRate), _sPercent))
        ..write(_num('H$r', _round(inv.btwBedrag), _sMoney))
        ..write(_num('I$r', _round(inv.totaalInclBtw), _sMoney))
        ..write(_str('J$r', inv.statusLabel, _sText));
      cells(r, row.toString());
    }

    // Totals under the list.
    final totals = StringBuffer()
      ..write(_str('A$totalRow', 'Totaal $year', _sTotalText))
      ..write(_str('B$totalRow', '', _sTotalText))
      ..write(_str('C$totalRow', '', _sTotalText))
      ..write(_str('D$totalRow', '', _sTotalText))
      ..write(_str(
        'E$totalRow',
        '${rows.length} ${rows.length == 1 ? 'factuur' : 'facturen'}',
        _sTotalText,
      ))
      ..write(_formula(
          'F$totalRow', 'SUM(F$_firstDataRow:F$lastDataRow)', _sTotalMoney))
      ..write(_str('G$totalRow', '', _sTotalText))
      ..write(_formula(
          'H$totalRow', 'SUM(H$_firstDataRow:H$lastDataRow)', _sTotalMoney))
      ..write(_formula(
          'I$totalRow', 'SUM(I$_firstDataRow:I$lastDataRow)', _sTotalMoney))
      ..write(_str('J$totalRow', '', _sTotalText));
    cells(totalRow, totals.toString());

    // The quarter block, to the right of whatever rows happen to be there:
    // four quarters and a year total, written last so its columns follow the
    // list's on a row they share.
    for (var r = _firstDataRow; r <= _firstDataRow + 4; r++) {
      cells(r, _quarterCells(r, year, lastDataRow));
    }

    final lastRow = totalRow > _firstDataRow + 4 ? totalRow : _firstDataRow + 4;
    final sheetData = sheet.values.map((r) => '$r</row>').join();

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<dimension ref="A1:S$lastRow"/>'
        '<sheetViews><sheetView tabSelected="1" workbookViewId="0">'
        '<pane ySplit="$_headerRow" topLeftCell="A$_firstDataRow" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>'
        '<sheetFormatPr defaultRowHeight="15"/>'
        '<cols>'
        '<col min="1" max="1" width="12" customWidth="1"/>'
        '<col min="2" max="2" width="11" customWidth="1"/>'
        '<col min="3" max="3" width="22" customWidth="1"/>'
        '<col min="4" max="4" width="12" customWidth="1"/>'
        '<col min="5" max="5" width="12" customWidth="1"/>'
        '<col min="6" max="6" width="14" customWidth="1"/>'
        '<col min="7" max="7" width="8" customWidth="1"/>'
        '<col min="8" max="9" width="13" customWidth="1"/>'
        '<col min="10" max="10" width="16" customWidth="1"/>'
        '<col min="11" max="11" width="3" customWidth="1"/>'
        '<col min="12" max="12" width="11" customWidth="1"/>'
        '<col min="13" max="15" width="13" customWidth="1"/>'
        '<col min="16" max="16" width="10" customWidth="1"/>'
        '<col min="17" max="19" width="15" customWidth="1"/>'
        '</cols>'
        '<sheetData>$sheetData</sheetData>'
        '</worksheet>';
  }

  /// The quarter block on the right of [row], or an empty string when that row
  /// carries none. Q1-Q4 sit on the four rows under the header, the year total
  /// on the fifth.
  ///
  /// The sums are formulas over the date column rather than baked-in numbers,
  /// so correcting an amount or a date in the list updates the quarters.
  static String _quarterCells(int row, int year, int lastDataRow) {
    final index = row - _firstDataRow; // 0..3 = Q1..Q4, 4 = year total
    if (index < 0 || index > 4) return '';

    String cell(int i) => '${_col(i + 11)}$row';
    final buf = StringBuffer();

    if (index == 4) {
      buf.write(_str(cell(0), 'Jaar $year', _sTotalText));
      for (final c in [1, 2, 3]) {
        final letter = _col(c + 11);
        buf.write(_formula(
          cell(c),
          'SUM($letter$_firstDataRow:$letter${_firstDataRow + 3})',
          _sTotalMoney,
        ));
      }
      buf.write(_formula(
        cell(4),
        'SUM(P$_firstDataRow:P${_firstDataRow + 3})',
        _sTotalCount,
      ));
      // The last cumulative is the year total by definition.
      buf.write(_formula(cell(5), 'M$row', _sTotalMoney));
      buf.write(_formula(cell(6), 'N$row', _sTotalMoney));
      buf.write(_formula(cell(7), 'O$row', _sTotalMoney));
      return buf.toString();
    }

    final quarter = index + 1;
    final from = _excelDate(DateTime(year, quarter * 3 - 2, 1));
    final until = _excelDate(DateTime(year, quarter * 3 + 1, 1));
    final dates = '\$B\$$_firstDataRow:\$B\$$lastDataRow';
    String sumOf(String column) =>
        'SUMIFS(\$$column\$$_firstDataRow:\$$column\$$lastDataRow,'
        '$dates,">="&$from,$dates,"<"&$until)';

    buf.write(_str(cell(0), 'Q$quarter', _sQuarterLabel));
    buf.write(_formula(cell(1), sumOf('F'), _sMoney));
    buf.write(_formula(cell(2), sumOf('H'), _sMoney));
    buf.write(_formula(cell(3), sumOf('I'), _sMoney));
    buf.write(_formula(
      cell(4),
      'COUNTIFS($dates,">="&$from,$dates,"<"&$until)',
      _sCount,
    ));
    // Cumulative: this quarter added to the ones before it.
    for (final c in [5, 6, 7]) {
      final source = _col(c + 7); // Q←M, R←N, S←O
      buf.write(_formula(
        cell(c),
        'SUM(\$$source\$$_firstDataRow:$source$row)',
        _sMoneyMuted,
      ));
    }
    return buf.toString();
  }

  // ── Cell writers ────────────────────────────────────────────────────────

  static String _str(String ref, String value, int style) => value.isEmpty
      ? '<c r="$ref" s="$style"/>'
      : '<c r="$ref" s="$style" t="inlineStr">'
          '<is><t xml:space="preserve">${_esc(value)}</t></is></c>';

  static String _num(String ref, num value, int style) =>
      '<c r="$ref" s="$style"><v>$value</v></c>';

  static String _formula(String ref, String formula, int style) =>
      '<c r="$ref" s="$style"><f>${_esc(formula)}</f></c>';

  static double _round(double v) => double.parse(v.toStringAsFixed(2));

  /// Excel's serial date: days since 1899-12-30. Counted in UTC — a local
  /// difference across the start of summer time is 23 hours short of a whole
  /// day and would round the date back by one.
  static int _excelDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(1899, 12, 30))
          .inDays;

  /// Column letter for a zero-based index (0 → A, 11 → L).
  static String _col(int index) {
    var i = index;
    var out = '';
    while (i >= 0) {
      out = String.fromCharCode(65 + i % 26) + out;
      i = i ~/ 26 - 1;
    }
    return out;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Workbook parts ──────────────────────────────────────────────────────

  // Style indices into cellXfs below.
  static const int _sTitle = 1;
  static const int _sHeader = 2;
  static const int _sText = 3;
  static const int _sMoney = 4;
  static const int _sDate = 5;
  static const int _sPercent = 6;
  static const int _sTotalText = 7;
  static const int _sTotalMoney = 8;
  static const int _sCount = 9;
  static const int _sTotalCount = 10;
  static const int _sQuarterLabel = 11;
  static const int _sMoneyMuted = 12;

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static String _workbook(int year) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Inkomsten $year" sheetId="1" r:id="rId1"/></sheets>'
      '<calcPr calcId="0" fullCalcOnLoad="1"/>'
      '</workbook>';

  static const String _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="3">'
      '<numFmt numFmtId="164" formatCode="&quot;€&quot;\\ #,##0.00"/>'
      '<numFmt numFmtId="165" formatCode="dd-mm-yyyy"/>'
      '<numFmt numFmtId="166" formatCode="0&quot;%&quot;"/>'
      '</numFmts>'
      '<fonts count="6">'
      '<font><sz val="11"/><color theme="1"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="16"/><color rgb="FF2563EB"/><name val="Calibri"/></font>'
      '<font><sz val="11"/><color rgb="FF64748B"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF2563EB"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF2563EB"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFEFF6FF"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="3">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FFE2E8F0"/></bottom><diagonal/></border>'
      '<border><left/><right/><top style="thin"><color rgb="FF2563EB"/></top><bottom style="thin"><color rgb="FF2563EB"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="13">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="3" borderId="2" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="1" fillId="3" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="3" borderId="2" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="5" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="4" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
