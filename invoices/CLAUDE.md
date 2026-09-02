# Project Idea

Invoice app. Used for generating invoices for clients. Simple interface where users input client information, services/products being billed, and amounts. The app generates professional invoices that can be sent to clients.

# Features

1. User authentication: Login with Google account via Firebase Authentication.
2. Business information: Input business name, address, contact details, logo, invoice prefix, default tax rate, default payment terms, starting invoice number.
3. Business logo: Upload logo (stored in Firebase Storage) included in PDF invoices.
4. Client information: Input client name, company, address, email, phone.
5. Invoice details: Services/products billed, amounts, notes, terms, tax rate, issue date, due date.
6. Invoice generation: Professional PDF invoice — 3 templates (Modern, Classic, Minimal). Download as PDF or send via email/WhatsApp.
7. Invoice history: List of all invoices with search, filter by status (draft/sent/paid), and revenue stats.
8. Products: Saved product/service list with name, description, price, unit. Organised in categories and optional sub-categories (created when adding a product, or in bulk by long-pressing products in one category and selecting them). Quickly added to invoices.
9. Custom one-time products: Custom items added to invoices without saving to product list.
10. Voertuigen: Vehicles currently in the shop, each tied to a "current" invoice. Adding a vehicle (phone number + optional name + plate) immediately creates its invoice in the workshop buffer; tapping the vehicle opens that invoice at the Producten step, and closing the screen persists the items added. The card shows the name when there is one, the number otherwise. The ⋮ menu has "Concept delen" (shares the still-unnumbered PDF), "Afronden" (takes the vehicle out of the shop, numbers its invoice and releases it into the Facturen tab), "Afronden en delen" (the same, then opens the share sheet for the numbered invoice) and "Verwijderen" (throws the record away — vehicle *and* invoice — so nothing reaches the Facturen tab and no invoice number is used).
11. Direct WhatsApp send: When the invoice carries a client phone number, a green "Direct naar <nummer> via WhatsApp" option appears on `email_editor_screen.dart`, opening that contact's chat with the PDF attached. Android only (needs an explicit intent); hidden elsewhere and when WhatsApp is not installed. NOTE: nothing currently navigates to `EmailEditorScreen`, so this option has no entry point in the running app.
12. Send email: Share invoice PDF with subject and message via native share sheet (email clients receive subject + body; WhatsApp receives `*Subject*\n\nMessage`). Optional server-side sending via Firebase Cloud Functions + SMTP.

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
    price.dart                 Price rounding/formatting at stored precision
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
```

Invoice number is auto-incremented via a Firestore transaction on `nextInvoiceNumber` in the business settings document.

## PDF Templates

Three templates in `pdf_service.dart`. All use `const PdfColor(r, g, b)` float constructors — `PdfColor.fromInt()` is not a const constructor and cannot be used in const contexts.

- **Modern**: Blue header block, alternating row colours, coloured totals
- **Classic**: Full bordered table, traditional layout
- **Minimal**: Clean lines, accent colour totals box

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

## Phone Input

`PhonePairFormatter` (`lib/utils/phone_format.dart`) groups a number's digits in
pairs (`06 12 34 56 78`) while it is typed, keeping a leading `+` intact. The
grouping is cosmetic: the vehicle form strips the spaces before saving, so
Firestore and `WhatsappService` only ever see the compact number. The formatter
tracks the caret by counting the digits ahead of it rather than its raw offset,
so inserting mid-number does not throw the cursor to the end. Covered by
`test/phone_pair_test.dart`.

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

`EmailService.shareInvoice()` uses `Share.shareXFiles` (share_plus 10.1.4 static API — no `SharePlus`/`ShareParams` classes in this version):

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
