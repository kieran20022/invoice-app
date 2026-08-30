package com.bliksemit.Invoices

import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Adds a channel that hands a PDF straight to one WhatsApp contact.
 *
 * The plain share sheet cannot preselect a recipient, so sharing to a known
 * phone number needs an explicit intent at the Android level.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.bliksemit.Invoices/whatsapp"

        // Consumer WhatsApp first, then WhatsApp Business.
        val WHATSAPP_PACKAGES = listOf("com.whatsapp", "com.whatsapp.w4b")
    }

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
        val text = call.argument<String>("text").orEmpty()
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
            putExtra(Intent.EXTRA_TEXT, text)
            // Undocumented but long-standing WhatsApp extra: opens this
            // contact's chat instead of WhatsApp's own contact picker.
            putExtra("jid", "$phone@s.whatsapp.net")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }
}
