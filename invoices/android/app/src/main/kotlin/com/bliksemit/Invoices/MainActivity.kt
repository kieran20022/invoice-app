package com.bliksemit.Invoices

import android.Manifest
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Adds two channels of our own:
 *
 *  - whatsapp: hands a PDF straight to one WhatsApp contact. The plain share
 *    sheet cannot preselect a recipient, so this needs an explicit intent.
 *  - share: the ordinary share sheet, but with the URI granted to the
 *    receiving apps explicitly (see [grantToTargets]).
 *  - files: writes a generated file into the device's Downloads, which an app
 *    cannot do by simply opening a path.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.bliksemit.Invoices/whatsapp"
        const val FILES_CHANNEL = "com.bliksemit.Invoices/files"
        const val SHARE_CHANNEL = "com.bliksemit.Invoices/share"

        // Consumer WhatsApp first, then WhatsApp Business.
        val WHATSAPP_PACKAGES = listOf("com.whatsapp", "com.whatsapp.w4b")

        /** Request code for the storage permission the legacy save path needs. */
        const val WRITE_STORAGE_REQUEST = 4711
    }

    /** A save waiting on the storage permission dialog (Android 9 and below). */
    private var pendingSave: (() -> Unit)? = null

    /** Answers that same waiting channel call when the permission is refused. */
    private var pendingDenied: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(installedWhatsapp() != null)
                    "shareFileToNumber" -> shareFileToNumber(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> shareFile(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> saveToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /** The first installed WhatsApp flavour, or null when neither is present. */
    private fun installedWhatsapp(): String? =
        WHATSAPP_PACKAGES.firstOrNull { pkg ->
            try {
                packageManager.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }

    private fun shareFileToNumber(call: MethodCall, result: MethodChannel.Result) {
        val pkg = installedWhatsapp()
        if (pkg == null) {
            result.error("NOT_INSTALLED", "WhatsApp is niet geïnstalleerd", null)
            return
        }

        val filePath = call.argument<String>("filePath")
        val phone = call.argument<String>("phone")
        if (filePath.isNullOrEmpty() || phone.isNullOrEmpty()) {
            result.error("BAD_ARGS", "filePath en phone zijn verplicht", null)
            return
        }

        val file = File(filePath)
        if (!file.exists()) {
            result.error("NO_FILE", "Bestand niet gevonden: $filePath", null)
            return
        }

        val uri = FileProvider.getUriForFile(this, "$packageName.provider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            setPackage(pkg)
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            // No EXTRA_TEXT: WhatsApp discards a caption sent with a document
            // anyway, and sending one costs the page preview — see
            // [withoutTextForWhatsapp]. The message goes to the clipboard.
            clipData = ClipData.newUri(contentResolver, file.name, uri)
            // Undocumented but long-standing WhatsApp extra: opens this
            // contact's chat instead of WhatsApp's own contact picker.
            putExtra("jid", "$phone@s.whatsapp.net")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // Outlives the receiving activity, so WhatsApp's thumbnail worker can
        // still read the PDF — see [shareFile].
        grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        try {
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }

    /**
     * Opens the share sheet for [file], with the document attached.
     *
     * This does the same as the share_plus plugin with one difference that
     * decides whether WhatsApp shows a page preview of the PDF or just its
     * name: the read permission on the URI is granted to the target packages
     * *explicitly*. The flag on the intent only lasts as long as the activity
     * that received it, and WhatsApp renders the document thumbnail on a
     * background worker afterwards — by which time that grant is gone and all
     * it can still show is the filename it was handed.
     */
    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
        val subject = call.argument<String>("subject").orEmpty()
        val text = call.argument<String>("text").orEmpty()
        if (filePath.isNullOrEmpty()) {
            result.error("BAD_ARGS", "filePath is verplicht", null)
            return
        }

        val file = File(filePath)
        if (!file.exists()) {
            result.error("NO_FILE", "Bestand niet gevonden: $filePath", null)
            return
        }

        val uri = FileProvider.getUriForFile(this, "$packageName.provider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (subject.isNotEmpty()) putExtra(Intent.EXTRA_SUBJECT, subject)
            if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
            // The document carried as ClipData as well as EXTRA_STREAM. This
            // is how a file manager hands a document over, and it is what
            // gives the receiving app the name and type of the attachment
            // up front rather than only a URI to go and query.
            clipData = ClipData.newUri(contentResolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // Resolve against the plain send intent, not the chooser: a chooser
        // resolves to the system resolver alone, so granting off that would
        // hand the permission to the picker rather than to the app picked.
        grantToTargets(send, uri)

        val chooser = Intent.createChooser(send, null).apply {
            withoutTextForWhatsapp()?.let {
                putExtra(Intent.EXTRA_REPLACEMENT_EXTRAS, it)
            }
        }

        try {
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }

    /**
     * Per-target extras that hand WhatsApp the document *without* a message.
     *
     * A share carrying both a document and EXTRA_TEXT is a captioned send to
     * WhatsApp, and it lists the attachment as a plain filename; the same
     * document on its own gets the page preview. Nothing is lost by leaving
     * the text out here — WhatsApp discards it either way, which is why the
     * message is put on the clipboard to paste. Every other app in the sheet
     * still receives the full subject and body.
     */
    private fun withoutTextForWhatsapp(): Bundle? {
        val installed = WHATSAPP_PACKAGES.filter { pkg ->
            try {
                packageManager.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
        if (installed.isEmpty()) return null

        return Bundle().apply {
            installed.forEach { pkg ->
                putBundle(pkg, Bundle().apply { putString(Intent.EXTRA_TEXT, null) })
            }
        }
    }

    /** Grants read access to [uri] to every app that can handle [intent]. */
    private fun grantToTargets(intent: Intent, uri: Uri) {
        packageManager
            .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .forEach { info ->
                grantUriPermission(
                    info.activityInfo.packageName,
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
    }

    /**
     * Writes bytes into the public Downloads folder and answers with the
     * location to show the user.
     *
     * From Android 10 this goes through MediaStore, which needs no permission
     * and numbers a repeated filename itself. Below that, Downloads is a plain
     * directory that may only be written with WRITE_EXTERNAL_STORAGE, so the
     * permission is asked for first and the save resumed from the callback.
     */
    private fun saveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val filename = call.argument<String>("filename")
        val mimeType = call.argument<String>("mimeType")
            ?: "application/octet-stream"
        if (bytes == null || filename.isNullOrEmpty()) {
            result.error("BAD_ARGS", "bytes en filename zijn verplicht", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(bytes, filename, mimeType, result)
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            saveToPublicDirectory(bytes, filename, result)
            return
        }

        // Both outcomes are answered from onRequestPermissionsResult, so the
        // channel call never hangs on a dialog the user dismissed.
        pendingSave = { saveToPublicDirectory(bytes, filename, result) }
        pendingDenied = {
            result.error(
                "NO_PERMISSION",
                "Geen toestemming om bestanden op te slaan",
                null,
            )
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            WRITE_STORAGE_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != WRITE_STORAGE_REQUEST) return

        val save = pendingSave
        val denied = pendingDenied
        pendingSave = null
        pendingDenied = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) save?.invoke() else denied?.invoke()
    }

    private fun saveViaMediaStore(
        bytes: ByteArray,
        filename: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            // Hides the file from other apps until it is fully written.
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("SAVE_FAILED", "Kon het bestand niet aanmaken", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Geen schrijftoegang")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            // MediaStore may have numbered a repeated name; report what it
            // actually stored rather than what was asked for.
            result.success("Downloads/${storedName(uri) ?: filename}")
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            result.error("SAVE_FAILED", e.message, null)
        }
    }

    /** The display name MediaStore gave [uri], or null when it cannot be read. */
    private fun storedName(uri: android.net.Uri): String? =
        try {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            null
        }

    private fun saveToPublicDirectory(
        bytes: ByteArray,
        filename: String,
        result: MethodChannel.Result,
    ) {
        try {
            val dir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            )
            if (!dir.exists()) dir.mkdirs()

            // Keep an earlier export: "naam (1).xlsx", as MediaStore would.
            val dot = filename.lastIndexOf('.')
            val stem = if (dot == -1) filename else filename.substring(0, dot)
            val ext = if (dot == -1) "" else filename.substring(dot)
            var file = File(dir, filename)
            var n = 1
            while (file.exists()) {
                file = File(dir, "$stem ($n)$ext")
                n++
            }

            file.writeBytes(bytes)
            result.success("Downloads/${file.name}")
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}
