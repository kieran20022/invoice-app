# Project Idea

Invoice app. Used for generating invoices for clients. Simple interface where users input client information, services/products being billed, and amounts. The app generates professional invoices that can be sent to clients.

# Features

1. User authentication: Login with Google account via Firebase Authentication.
2. Business information: Input business name, address, contact details, logo, invoice prefix, default tax rate, default payment terms, starting invoice number.
3. Business logo: Upload logo (stored in Firebase Storage) included in PDF invoices.
4. Client information: Input client name, company, address, email, phone.
5. Invoice details: Services/products billed, amounts, notes, terms, tax rate, issue date, due date.
6. Invoice generation: Professional PDF invoice — 3 templates (Modern, Classic, Minimal). Download as PDF or send via email/WhatsApp.
7. Invoice history: List of all invoices with search, filter by status (draft/paid/quotes), and revenue stats. A card is swiped right and up for Contant Betaald, right and down for Pin Betaald, and left to delete. Long-pressing a card starts a selection; the bar that
   replaces the search field shares or downloads the selected PDFs, marks them
   Contant/Pin betaald, or deletes them.
8. Products: Saved product/service list with name, description, price, unit. Organised in categories and optional sub-categories (created when adding a product, or in bulk by long-pressing products in one category and selecting them). Quickly added to invoices.
9. Custom one-time products: Custom items added to invoices without saving to product list.
10. Voertuigen: Vehicles currently in the shop, each tied to a "current" invoice. Adding a vehicle (phone number + optional name + plate, geel or blauw)
    immediately creates its invoice in the workshop buffer; tapping the vehicle opens that invoice at the Producten step, and closing the screen persists the items added. The card shows the name when there is one, the number otherwise. The ⋮ menu has "Concept delen" (shares the still-unnumbered PDF), "Afronden" (takes the vehicle out of the shop, numbers its invoice and releases it into the Facturen tab), "Afronden en delen" (the same, then opens the share sheet for the numbered invoice) and "Verwijderen" (throws the record away — vehicle *and* invoice — so nothing reaches the Facturen tab and no invoice number is used).
11. Direct WhatsApp send: When the invoice carries a client phone number, a green "Direct naar <nummer> via WhatsApp" option appears on `email_editor_screen.dart`, opening that contact's chat with the PDF attached. Android only (needs an explicit intent); hidden elsewhere and when WhatsApp is not installed. NOTE: nothing currently navigates to `EmailEditorScreen`, so this option has no entry point in the running app.
12. Offertes: An "Offerte Maken" button next to "Nieuwe Factuur" on the
    Facturen tab runs the same 4-step flow, but the document is a quote: it
    numbers from its own sequence (`OFF-0001`), says OFFERTE instead of
    BETAALD/TE BETALEN, carries no payment state or payment details, is left
    out of the revenue stats, and its items may be estimated as ranges
    ("1-4 uur arbeid"), which widen the totals into a span. On the Details
    step a quote can be issued as a **Schaderapport** instead, which only
    renames it. Its shared PDF is named after what it is rather than its
    number: `Offerte - Jan - AB-12-CD.pdf`. The badge on its card in the
    Facturen tab converts it into a real invoice.
13. Send email: Share invoice PDF with subject and message via native share sheet (email clients receive subject + body; WhatsApp receives `*Subject*\n\nMessage`). Optional server-side sending via Firebase Cloud Functions + SMTP.
14. Inkomsten overzicht: An Excel (`.xlsx`) export of a year's invoices,
    downloaded from the ⊞ button in the stats screen. Lists every invoice of
    the chosen year with its VAT split and totals each quarter beside it,
    cumulative through the year. It is saved to the device's Downloads rather
    than shared.

# App Workflow

1. User logs in with Google account.
2. On first login, user is prompted to set up business information.
3. User creates invoices via a 4-step flow: Client Info → Template → Items → Details.
4. Invoice is saved to Firestore with an auto-incremented invoice number.
5. User previews the invoice (live PDF preview), then downloads or sends it.
6. User can view all past invoices in the Invoices tab, search/filter, and mark as paid/sent.

# Design

Clean and professional, Material 3. Primary colour: `#2563EB` (blue).

- Bottom navigation: Invoices | Vehicles | Products | Settings
- 4-step Stepper for invoice creation — user can tap back to any previous step.
- Invoice history shows running totals (total, paid, unpaid) and overdue highlighting.
- Facturen tab filter chips: Facturen | Concept | Betaald | Offertes — the
  first lists the invoices, quotes only appear under their own chip. A sort
  button beside the search field orders by number (high-low, the default) or
  amount.
- Invoice numbers auto-generated (e.g. `INV-0001`). Starting number configurable in Settings.

# Technology Stack

- **Flutter** 3.41.9 / Dart 3.11.5 — cross-platform (Android + Web)
- **Firebase** — Auth (Google Sign-In), Cloud Firestore, Firebase Storage
- **pdf** + **printing** packages — PDF generation and in-app preview
- **provider** — state management (`ChangeNotifierProxyProvider` pattern)
- **flutter_dotenv** — Firebase credentials loaded from `.env` asset
- **share_plus** — sharing PDF with subject/text via `Share.shareXFiles`
- **image_picker** — business logo upload
- **Firebase Cloud Functions** (optional, `functions/index.js`) — server-side email via nodemailer/SMTP

# Architecture

## File Structure

```
lib/
  main.dart                    MultiProvider root + _AuthWrapper
  firebase_options.dart        Reads Firebase config from .env
  config/
    theme.dart                 Material 3 theme, AppTheme constants
  models/
    business_info.dart         Business profile + invoice settings
    client.dart                Client contact info
    product.dart               Saved product/service
    invoice.dart               Invoice + InvoiceItem (snapshots, no FK refs)
    vehicle.dart               Vehicle in the shop (phone, name, plate) + invoice id
  services/
    auth_service.dart          Google Sign-In (web popup / mobile native)
    firestore_service.dart     CRUD for all Firestore collections
    storage_service.dart       Firebase Storage upload/delete for logo
    pdf_service.dart           3 PDF templates (Modern, Classic, Minimal)
    email_service.dart         shareInvoice() via Share.shareXFiles + cloud function
    excel_service.dart         Inkomsten overzicht: xlsx built as raw OOXML
    download_service.dart      Saves an export to Downloads (per-platform)
    download_service_io.dart   Android MediaStore channel / desktop folder
    download_service_web.dart  Browser download via a blob URL
    whatsapp_service.dart      Direct-to-number WhatsApp share via platform channel
  providers/
    auth_provider.dart         Wraps FirebaseAuth.authStateChanges()
    business_provider.dart     Streams business info; setUserId() pattern
    product_provider.dart      Streams product list; setUserId() pattern
    invoice_provider.dart      Streams history + manages draft state
    vehicle_provider.dart      Streams vehicles in the shop; setUserId() pattern
  screens/
    auth/login_screen.dart
    home/home_screen.dart
    business/business_info_screen.dart
    products/products_screen.dart
    invoices/create_invoice_screen.dart
    invoices/invoice_preview_screen.dart
    invoices/invoice_history_screen.dart
    vehicles/vehicles_screen.dart
    email/email_editor_screen.dart
  utils/
    price.dart                 Price rounding, money display, decimal input parsing
    phone_format.dart          PhonePairFormatter — pairs digits while typing
functions/
  index.js                     Firebase Cloud Function: sendInvoiceEmail
  package.json
android/
  app/google-services.json     Firebase Android config (gitignored)
  app/build.gradle.kts         Applies com.google.gms.google-services plugin
  settings.gradle.kts          Declares google-services plugin 4.4.2
.env                           Firebase credentials (gitignored)
```

## State Management Pattern

Each provider has a `setUserId(String? userId)` method. `ChangeNotifierProxyProvider` in `main.dart` calls this whenever `AuthProvider` notifies, starting/stopping Firestore stream subscriptions automatically.

## Firestore Structure

```
users/{uid}/
  settings/business        BusinessInfo document (also stores nextInvoiceNumber)
  clients/{id}             Client documents
  products/{id}            Product documents
  vehicles/{id}            Vehicles in the shop (phone, name, plate, invoiceId)
                           Legacy docs carry `ownerName`; read as `name`
  invoices/{id}            Invoice documents (full snapshots, not references)
                           `isQuote: true` marks an offerte
```

Invoice number is auto-incremented via a Firestore transaction on `nextInvoiceNumber` in the business settings document; quotes use `nextQuoteNumber` in the same document.

## PDF Templates

Documents are written as **PDF 1.4**, not the `pdf` package's 1.5 default:
1.5 stores the cross-reference as a compressed stream, which WhatsApp's
document thumbnailer does not read — it then shows the shared invoice as a
bare filename instead of a page preview. A classic xref table is what ordinary
PDFs carry and nothing here needs 1.5.

Three templates in `pdf_service.dart`. All use `const PdfColor(r, g, b)` float constructors — `PdfColor.fromInt()` is not a const constructor and cannot be used in const contexts.

- **Modern**: Blue header block, alternating row colours, coloured totals
- **Classic**: Full bordered table, traditional layout
- **Minimal**: Clean lines, accent colour totals box

## Offertes

An offerte is an `Invoice` with `isQuote: true` rather than a separate model —
same client snapshot, items, template and PDF. What differs:

- **Numbering** runs off `nextQuoteNumber` / `quotePrefix` (default `OFF`) in
  the business settings, so a quote never consumes an invoice number and
  leaves a gap in the Facturen sequence. The draft carries whichever prefix
  its own sequence uses in `businessInvoicePrefix`, so numbering only has to
  pick the counter.
- **No payment state.** The status badge is a plain "Offerte", the swipe-to-paid
  gesture and the "Markeer als betaald" menu item are gone, and the PDF prints
  OFFERTE where an invoice prints BETAALD / TE BETALEN. The payment details
  block is left off entirely.
- **Not revenue.** The Facturen tab's stats row and `InvoiceStatsScreen` are fed
  the non-quote invoices; the "Offertes" filter chip lists the quotes.
- **Email wording.** `EmailService.renderTemplate` swaps the whole word
  "factuur" for whatever the document is, so the one stored template serves an
  invoice, an offerte and a schaderapport alike.
- **No number on the document.** The header box prints only the date for a
  quote; the number still exists (it identifies the record in the app) but a
  customer identifies a quote by its subject, not a sequence number.
- **No Opmerkingen block.** The notes section is printed on invoices only; on
  a quote the field stays available in the app (and in its preview bar) but
  does not reach the customer's document.
- **Filename.** `Invoice.pdfFilename` leads an invoice with its number but a
  quote with its kind, name and vehicle reference
  (`Offerte - Jan - AB-12-CD.pdf`), which is what a customer recognises. Parts
  that are empty are dropped rather than leaving hanging separators, and
  characters a path cannot carry are replaced.

### Schaderapport

`isDamageReport` is a quote issued as a damage report. It changes nothing but
the wording — `documentLabel` returns "Schaderapport", which then drives the
app-bar title, the PDF heading and badge, the email wording and the filename.
`shortDocumentLabel` is the same thing shortened to "Rapport" for the badge on
an invoice card and for the create flow's "Naar Rapport" button, where
the full word runs past its edge. It is chosen with the
segmented button on the Details step, which only appears for quotes.

### Converting a quote into an invoice

The card's badge in the Facturen tab opens "Omzetten naar factuur"
(`convertQuoteToInvoice`). `InvoiceProvider.convertToInvoice` takes the next
*invoice* number, clears the quote wording and rewrites the snapshot's prefix
to the invoice sequence's. Because an invoice bills an exact quantity, every
estimated range has to be settled first: `_SettleRangesSheet` asks for a number
per ranged item, defaulting to the low bound and validated to stay inside the
span the customer was quoted. Those quantities are applied with
`clearAantalTot`, so the resulting invoice carries no ranges at all. The
converted invoice is dated the day of the conversion (`issueDate` and
`clientDatum`), not the day the quote was drawn up — the same rule the workshop
buffer follows when a vehicle is afgerond.

### Quantity ranges

`InvoiceItem.aantalTot` is an optional upper bound, offered as a second
"Aantal tot" field in the item form on quotes only. It counts as a range just
when it is strictly above `aantal`, so an equal or lower value is stored as no
range at all. A ranged item shows `1-4` in place of the +/- stepper (stepping
one bound would silently change the estimate — edit it in the form instead),
and the document totals gain `...Max` counterparts that `formatAmountRange`
renders as `€12.10 - €48.40`.

## Workshop Buffer

An invoice created for a vehicle is saved with `status: 'werkplaats'`
(`InvoiceProvider.workshopStatus`) instead of `'concept'`. `InvoiceProvider`
exposes two lists:

- `invoices` — everything outside the buffer. This is what the Facturen tab and
  the revenue stats read, so a job still in the shop does not count as an
  invoice yet.
- `allInvoices` — including the buffer. The Voertuigen tab needs it to find a
  vehicle's invoice by id.

Taking a vehicle out of the shop flips its invoice to `'concept'` *before*
deleting the vehicle — a vehicle deleted while its invoice were still buffered
would leave that invoice unreachable from either tab.

The invoice number is assigned when the vehicle leaves the shop, not when it is
booked in (`InvoiceProvider.releaseFromWorkshop`), so a job sitting in the
buffer for days does not burn a number and leave a gap in the Facturen
sequence. While buffered, `invoiceNumber` is empty and `Invoice.numberLabel`
renders it as `Concept` (app bar, vehicle card, PDF, share subject/filename).

The invoice is also *dated* at that moment: `releaseFromWorkshop` stamps
`issueDate` and `clientDatum` with the day the job is finished, not the day the
vehicle was booked in — a car can sit in the shop for days and the customer's
document should carry the completion date. `createdAt` is stamped along with it,
because the Facturen tab is ordered by that field: it records when the invoice
*entered* the list, so a released job sits on top rather than among the invoices
that were made while it was in the shop. Converting a quote
(`convertToInvoice`) restamps it for the same reason.

## Inkomsten Overzicht (Excel)

`ExcelService` (`lib/services/excel_service.dart`) builds the yearly income
overview as an `.xlsx`. It is reached from the grid button in the stats
screen's app bar, which offers every year that has invoices (plus the current
one, even when empty).

The file is **downloaded, not shared**: an overview is opened in a spreadsheet
later rather than sent to someone, so it goes to the device's Downloads and a
snackbar says where it landed. `DownloadService`
(`lib/services/download_service.dart`) picks the way per platform through a
conditional export — Android's MediaStore over the `files` channel, the
browser's own download on web, the Downloads folder on desktop.

The workbook is written as raw OOXML — six small XML parts zipped with
`archive` — rather than through a spreadsheet package: the parts are short, and
writing them here keeps the currency/date formats and the quarter block under
our own control without pulling in a dependency.

- **The list** (columns A-J, one row per invoice): number, date, client,
  kenteken, km stand, ex. VAT, VAT %, VAT, incl. VAT and how it was settled.
  A totals row closes the list.
- **Paid invoices only.** An open invoice is not income, so it is left off
  entirely rather than listed as outstanding; quotes and the workshop buffer
  never reach the overview either. The last column therefore only ever names a
  payment method.
- **Dated and ordered on the payment date** (`Invoice.paymentDate`), not the
  issue date: income counts on the day the money came in, so an invoice
  written in December and paid in January belongs to January — and to the new
  year's overview. Within one day the rows run by invoice number, compared by
  its sequence rather than as text so `F9` sorts before `F10`. An invoice with
  no payment stamp (settled before the stamp existed) falls back to its issue
  date.
- **The quarter block** (columns L-S, beside the first five rows): Q1-Q4 and a
  year total, each with ex. VAT / VAT / incl. VAT, an invoice count, and a
  cumulative running through the year.
- **The sums are formulas**, `SUMIFS` over the date column rather than baked-in
  numbers, so correcting an amount or a date in the list updates the quarters.
- Rows are collected per row number and emitted in order: on a year with fewer
  than four invoices the quarter block runs past the totals row, and Excel
  rejects a sheet whose rows are out of order.
- Dates are Excel serials counted **in UTC** — a local difference across the
  start of summer time is 23 hours and would round the date back a day.
- A repeated export does not overwrite the earlier one: it becomes
  "Inkomsten 2025 (1).xlsx", the way a browser numbers a repeat download.
  MediaStore does this itself; the other platforms do it in code.

Covered by `test/income_overview_test.dart`.

## Money and Number Input

`formatMoney` (`lib/utils/price.dart`) is the single money formatter: thousands
grouped with a non-breaking space (`€1 234,56`, `€250 000 000`), so an amount
never wraps mid-number. `decimals` drops to 0 for the stats/summary tiles and
`decimalSeparator` is `,` on the PDF (Dutch convention) and `.` on screen.
`formatAmountRange` builds a quote's span out of it. Covered by
`test/money_format_test.dart`.

`parseDecimalInput` is the reverse: it reads a typed number with either
separator (`8,25` and `8.25` both give 8.25), since a Dutch keyboard offers a
comma while `double.tryParse` only accepts a point. Every numeric field parses
through it; fields holding decimals use `numberWithOptions(decimal: true)`.

## Invoice States

`paidAt` records *when* an invoice was settled. It is stamped by
`FirestoreService.updateInvoiceStatus`, the one write both the card's swipe and
the preview's menu go through, and cleared again when an invoice moves back out
of a paid state — `Invoice.paidAtFor(status)` decides which. `paymentDate` is
what to read: `paidAt`, or the issue date when there is none (an open invoice,
or one settled before the stamp existed). The Inkomsten overzicht dates and
orders by it.


`status` carries how an invoice was settled, not just that it was:
`Invoice.paidCash` (`'contant'`) and `Invoice.paidCard` (`'pin'`) next to
`'concept'` and the workshop buffer's `'werkplaats'`. `'betaald'` is the older
paid state, from before the method was recorded, and still counts everywhere.

- `Invoice.isPaid` is what every "is this settled" check reads — revenue stats,
  the Betaald filter chip, the PDF's BETAALD / TE BETALEN badge. Never compare
  `status` to `'betaald'` directly.
- `Invoice.statusLabel` renders the state for the app ("Contant betaald"),
  used by the card badge, the preview's badge and its snackbar.
- Colours follow the method and live in one place, `AppTheme.cash` (green
  `#10B981`) and `AppTheme.card` (violet `#8B5CF6`) — violet rather than the
  app's blue because the pin line runs alongside the blue "Totaal" line on the
  stats chart. Used by the swipe panel, both status badges and the stats
  screen.

The stats screen covers one or more months, picked in the title's month grid
(toggled on and off, across years, applied with "Toepassen"; "Hele jaar" ticks
the shown year). The chart is always day by day: the selected months' days are
laid end to end in calendar order (loose months sit side by side, without the
gap between them). With several months the axis labels where each month starts
and the tooltip shows the date.

The stats screen keeps the two apart throughout: separate chart lines (with
the paid line split in two), a Contant and a Pin card under Analyse showing
what came in each way, and their own rows in the status breakdown. Invoices
carrying the older `'betaald'` state count towards the paid total but towards
neither method, and get their own breakdown row only when there are any.

Covered by `test/invoice_status_test.dart`.

## Swipeable Invoice Cards

A card in the Facturen tab acts on the swipe itself — there is nothing to tap
afterwards (`MovableInvoiceCard`,
`lib/screens/invoices/movable_invoice_card.dart`). The direction is the
choice:

- **Right and up** → Contant Betaald.
- **Right and down** → Pin Betaald.
- **Left** → delete, which asks for confirmation.

While the finger is down, the panel behind the card shows both payment
options and fills in the half the swipe is currently aimed at, so letting go
never surprises. A swipe shorter than the threshold, or one to the right with
no up or down to it, springs back and does nothing. A quote passes neither
payment action, leaving that side inert.

Details worth keeping:

- The gesture is a **horizontal** drag, so the list still scrolls normally. A
  horizontal recognizer zeroes the vertical delta, so the up/down half is read
  off `globalPosition.dy` against where the swipe started, not off `delta`.
- `verticalThreshold` (8px) is what keeps a dead-straight swipe from picking a
  payment method by rounding noise.
- The `AnimationController` is built in `initState`, not lazily: a card that is
  never swiped would otherwise have its controller created by its own
  `dispose()`, which throws.

### Selecting cards

A long-press ticks a card and puts the list into selection mode: taps toggle
cards instead of opening them, the badge menus go inert, and the swipe is off
(`swipeEnabled: false`) so a stray drag cannot pay or delete a card on the
side. A bar stands in for the search field and filter chips, with select-all
(the list as currently filtered), **share** (one document goes out exactly as
the preview's "Versturen" sends it; several go out together through
`EmailService.shareInvoices` - `ACTION_SEND_MULTIPLE` on Android, each URI
granted like a single share - under a subject listing their numbers, since the
email template speaks about one invoice), **download** (each PDF saved to Downloads
through `DownloadService` under its `pdfFilename`), **mark paid** (Contant or
Pin; quotes are skipped, and invoices already paid that way are left alone so
they keep their `paidAt`) and **delete** (one confirmation for the lot). Back
or the ✕ ends the selection.

Covered by `test/movable_card_test.dart`, which drives the real gestures.

## Phone Input

`PhonePairFormatter` (`lib/utils/phone_format.dart`) groups a number's digits in
pairs (`06 12 34 56 78`) while it is typed, keeping a leading `+` intact. The
grouping is cosmetic: the vehicle form strips the spaces before saving, so
Firestore and `WhatsappService` only ever see the compact number. The formatter
tracks the caret by counting the digits ahead of it rather than its raw offset,
so inserting mid-number does not throw the cursor to the end. Covered by
`test/phone_pair_test.dart`.

## Saving to Downloads (Android)

An app cannot write to the public Downloads by opening a path, so the export
goes through a second channel (`com.bliksemit.Invoices/files`, method
`saveToDownloads`) in the same MainActivity:

- **Android 10+** writes through `MediaStore.Downloads` with `IS_PENDING` set
  while the bytes go in — no permission needed, and MediaStore numbers a
  repeated filename itself. The name it actually stored is read back and
  returned, so the snackbar does not claim a name it did not use.
- **Android 9 and below** has no MediaStore Downloads collection: the file is
  written straight into the public directory, which needs
  `WRITE_EXTERNAL_STORAGE` (declared with `maxSdkVersion="28"`). The permission
  is requested and the save resumed from `onRequestPermissionsResult`; both
  outcomes answer the channel call, so it never hangs on a dismissed dialog.

## Direct WhatsApp Send

The share sheet cannot preselect a recipient, so sending to a known number uses
a platform channel (`com.bliksemit.Invoices/whatsapp`) handled in
`android/app/src/main/kotlin/com/bliksemit/Invoices/MainActivity.kt`:

- `isAvailable` — is `com.whatsapp` or `com.whatsapp.w4b` installed. The
  `<package>` entries in the manifest's `<queries>` are required for this to
  see them on Android 11+.
- `shareFileToNumber` — `ACTION_SEND` with the PDF as `EXTRA_STREAM` (through
  the existing `${applicationId}.provider` FileProvider), `setPackage(...)`, and
  the undocumented `jid` extra (`<number>@s.whatsapp.net`) that opens that
  contact's chat rather than WhatsApp's picker.

`WhatsappService.normalizePhone()` converts numbers as typed into the
digits-only international form (`06-12345678` → `31612345678`); a leading `+`
means the number already carries its own country code. Default country code is
`31`.

WhatsApp drops `EXTRA_TEXT` when a document is attached, so the message is
copied to the clipboard for the user to paste — same as the plain share flow.

## Email / Share

On **Android** `EmailService.shareInvoice()` opens the share sheet through our
own channel (`com.bliksemit.Invoices/share`, method `shareFile` in
MainActivity) instead of share_plus. The difference that matters is the URI
permission: `FLAG_GRANT_READ_URI_PERMISSION` on the intent lasts only as long
as the activity that received it, while WhatsApp renders the PDF's page
preview on a background worker afterwards — with only the intent flag it is
left with the filename and no preview. MainActivity therefore also calls
`grantUriPermission` for every package that resolves the send intent (resolved
against the plain intent, not the chooser, which resolves to the system picker
alone). The direct-to-number send grants the same way.

Two things about the intent decide whether WhatsApp shows a page preview of
the PDF or only its filename:

- **No caption for WhatsApp.** A send carrying a document *and* `EXTRA_TEXT`
  is a captioned share, which WhatsApp lists as a bare filename; the document
  alone gets the preview. `EXTRA_REPLACEMENT_EXTRAS` on the chooser drops the
  text for the WhatsApp packages only, so every other app in the sheet still
  gets the subject and body. Nothing is lost — WhatsApp discards the caption
  regardless, which is why the message goes to the clipboard to paste. The
  direct-to-number send leaves the text off for the same reason.
- **The document as `ClipData` too**, not only `EXTRA_STREAM`: that is how a
  file manager hands a document over, and it carries the name and type with
  the attachment instead of leaving the receiver to query for them.

Elsewhere, and if the channel call fails, it falls back to `Share.shareXFiles`
(share_plus 10.1.4 static API — no `SharePlus`/`ShareParams` classes in this
version):

```dart
Share.shareXFiles([XFile.fromData(pdfBytes, ...)], subject: subject, text: text);
```

Text is formatted as `*Subject*\n\nMessage` so WhatsApp renders the subject bold. Email clients receive subject via `Intent.EXTRA_SUBJECT`.

## Android

- `android/app/google-services.json` must be present (gitignored).
- SHA-1 debug fingerprint must be registered in Firebase Console under the Android app.
- Get debug SHA-1: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`
- Package name: `com.bliksemit.Invoices`
- Google Services Gradle plugin (4.4.2) is declared in `settings.gradle.kts` and applied in `app/build.gradle.kts`.

## Web

The `.env` app ID must be the **web** app ID (`1:...:web:...`), not the Android one. Create a Web app in Firebase Console if needed.

## Cloud Functions (optional)

Requires Firebase Blaze (pay-as-you-go) plan.

```bash
cd functions
npm install
firebase functions:config:set smtp.host="smtp.sendgrid.net" smtp.port="587" smtp.user="apikey" smtp.pass="YOUR_KEY" smtp.from="you@domain.com"
firebase deploy --only functions
```

Then set `CLOUD_FUNCTION_BASE_URL` in `.env`.
