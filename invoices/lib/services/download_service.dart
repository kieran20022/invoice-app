/// Saves a generated file where the user can find it again.
///
/// Sharing hands a file to another app; downloading puts it in the device's
/// own Downloads, which is what an export like the Inkomsten overzicht wants —
/// it is opened in a spreadsheet later, not sent to someone.
///
/// The implementation differs per platform (Android's MediaStore, the
/// browser's download, a Downloads folder on desktop), so the right one is
/// picked at compile time.
library;

export 'download_service_io.dart'
    if (dart.library.js_interop) 'download_service_web.dart';
