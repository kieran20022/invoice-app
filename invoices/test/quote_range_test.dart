import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/invoice.dart';
import 'package:invoices/services/email_service.dart';
import 'package:invoices/utils/price.dart';

InvoiceItem _item({required double aantal, double? tot, double prijs = 10}) =>
    InvoiceItem(
      id: 'i',
      omschrijving: 'Arbeid',
      aantal: aantal,
      aantalTot: tot,
      prijsExBtw: prijs,
    );

Invoice _invoice({
  required List<InvoiceItem> items,
  bool isQuote = false,
  bool damage = false,
}) =>
    Invoice(
      id: '1',
      invoiceNumber: 'OFF-0001',
      issueDate: DateTime(2026, 1, 1),
      clientNaam: 'Jan',
      clientKenteken: 'AB-12-CD',
      businessName: 'Garage',
      items: items,
      taxRate: 21,
      createdAt: DateTime(2026, 1, 1),
      isQuote: isQuote,
      isDamageReport: damage,
    );

void main() {
  group('item quantity ranges', () {
    test('an upper bound above the lower one reads as a range', () {
      final item = _item(aantal: 1, tot: 4);
      expect(item.isRange, isTrue);
      expect(item.aantalLabel, '1-4');
      expect(item.totalExBtw(), 10);
      expect(item.totalExBtwMax(), 40);
    });

    test('an upper bound at or below the lower one is not a range', () {
      expect(_item(aantal: 2, tot: 2).isRange, isFalse);
      expect(_item(aantal: 2, tot: 1).isRange, isFalse);
      expect(_item(aantal: 2, tot: 1).aantalMax, 2);
      expect(_item(aantal: 2, tot: 2).aantalLabel, '2');
    });

    test('a fractional quantity keeps its decimals in the label', () {
      expect(_item(aantal: 1.5, tot: 2.5).aantalLabel, '1.5-2.5');
    });

    test('the range survives a round trip through the map', () {
      final restored = InvoiceItem.fromMap(_item(aantal: 1, tot: 4).toMap());
      expect(restored.aantalTot, 4);
      expect(restored.aantalLabel, '1-4');
    });
  });

  group('document totals', () {
    test('a ranged item widens the totals', () {
      final inv = _invoice(items: [_item(aantal: 1, tot: 4)], isQuote: true);
      expect(inv.hasRange, isTrue);
      expect(inv.subtotaalExBtw, 10);
      expect(inv.subtotaalExBtwMax, 40);
      expect(inv.totaalInclBtw, closeTo(12.10, 0.001));
      expect(inv.totaalInclBtwMax, closeTo(48.40, 0.001));
    });

    test('without ranges both bounds are the same total', () {
      final inv = _invoice(items: [_item(aantal: 2)]);
      expect(inv.hasRange, isFalse);
      expect(inv.totaalInclBtwMax, inv.totaalInclBtw);
    });

    test('formatAmountRange collapses to one amount when they match', () {
      expect(formatAmountRange(12.1, 12.1, '€'), '€12.10');
      expect(formatAmountRange(12.1, 48.4, '€'), '€12.10 - €48.40');
    });
  });

  group('quote wording', () {
    test('a quote names itself an offerte', () {
      expect(_invoice(items: const [], isQuote: true).documentLabel, 'Offerte');
      expect(_invoice(items: const []).documentLabel, 'Factuur');
    });

    test('the email template swaps the word for a quote', () {
      const template = 'Bijgevoegd vindt u factuur {factuur_nummer}.';
      final quote = _invoice(items: const [], isQuote: true);
      expect(
        EmailService.renderTemplate(template, quote),
        'Bijgevoegd vindt u offerte OFF-0001.',
      );
      expect(
        EmailService.renderTemplate(template, _invoice(items: const [])),
        'Bijgevoegd vindt u factuur OFF-0001.',
      );
    });

    test('the swap leaves other words starting with factuur alone', () {
      final quote = _invoice(items: const [], isQuote: true);
      expect(
        EmailService.renderTemplate('Zie factuurregels en de factuur.', quote),
        'Zie factuurregels en de offerte.',
      );
    });

    test('isQuote survives a round trip through the map', () {
      final quote = _invoice(items: const [], isQuote: true);
      expect(Invoice.fromMap('1', quote.toMap()).isQuote, isTrue);
      expect(
        Invoice.fromMap('1', _invoice(items: const []).toMap()).isQuote,
        isFalse,
      );
    });
  });

  group('document kind', () {
    test('a damage report renames the quote', () {
      final report = _invoice(items: const [], isQuote: true, damage: true);
      expect(report.documentLabel, 'Schaderapport');
      expect(report.isQuote, isTrue);
    });

    test('the damage flag survives a round trip through the map', () {
      final report = _invoice(items: const [], isQuote: true, damage: true);
      expect(Invoice.fromMap('1', report.toMap()).isDamageReport, isTrue);
    });

    test('the badge label shortens the damage report but nothing else', () {
      final report = _invoice(items: const [], isQuote: true, damage: true);
      expect(report.shortDocumentLabel, 'Rapport');
      expect(
        _invoice(items: const [], isQuote: true).shortDocumentLabel,
        'Offerte',
      );
      expect(_invoice(items: const []).shortDocumentLabel, 'Factuur');
    });

    test('an invoice ignores the damage flag in its label', () {
      expect(_invoice(items: const [], damage: true).documentLabel, 'Factuur');
    });

    test('the email template names the damage report', () {
      final report = _invoice(items: const [], isQuote: true, damage: true);
      expect(
        EmailService.renderTemplate('Bijgevoegd vindt u factuur.', report),
        'Bijgevoegd vindt u schaderapport.',
      );
    });
  });

  group('pdf filename', () {
    test('a quote leads with its kind, name and reference — no number', () {
      final quote = _invoice(items: const [], isQuote: true);
      expect(quote.pdfFilename, 'Offerte - Jan - AB-12-CD.pdf');
    });

    test('a damage report swaps the leading word', () {
      final report = _invoice(items: const [], isQuote: true, damage: true);
      expect(report.pdfFilename, 'Schaderapport - Jan - AB-12-CD.pdf');
    });

    test('missing parts are left out rather than leaving empty separators', () {
      final quote = Invoice(
        id: '1',
        invoiceNumber: 'OFF-0001',
        issueDate: DateTime(2026, 1, 1),
        clientNaam: '',
        businessName: 'Garage',
        items: const [],
        createdAt: DateTime(2026, 1, 1),
        isQuote: true,
      );
      expect(quote.pdfFilename, 'Offerte.pdf');
    });

    test('an invoice still leads with its number', () {
      expect(_invoice(items: const []).pdfFilename, 'OFF-0001 - AB-12-CD.pdf');
    });

    test('characters a path cannot carry are replaced', () {
      final quote = Invoice(
        id: '1',
        invoiceNumber: '',
        issueDate: DateTime(2026, 1, 1),
        clientNaam: 'Jan/Piet',
        clientKenteken: 'AB:12',
        businessName: 'Garage',
        items: const [],
        createdAt: DateTime(2026, 1, 1),
        isQuote: true,
      );
      expect(quote.pdfFilename, 'Offerte - Jan-Piet - AB-12.pdf');
    });
  });
}
