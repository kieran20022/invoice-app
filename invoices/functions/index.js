const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

// Configure SMTP transport.
// For Gmail: use App Password or OAuth. For SendGrid: use smtp.sendgrid.net
// Set these in Firebase environment config:
//   firebase functions:config:set smtp.host="smtp.sendgrid.net" smtp.port="587"
//   smtp.user="apikey" smtp.pass="YOUR_SENDGRID_API_KEY"
//   smtp.from="noreply@yourdomain.com"

const createTransport = () =>
  nodemailer.createTransporter({
    host: functions.config().smtp?.host || "smtp.sendgrid.net",
    port: parseInt(functions.config().smtp?.port || "587"),
    secure: false,
    auth: {
      user: functions.config().smtp?.user || "apikey",
      pass: functions.config().smtp?.pass || "",
    },
  });

exports.sendInvoiceEmail = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const { to, subject, html, pdfBase64, pdfFilename, invoiceNumber } = req.body;

  if (!to || !subject || !html || !pdfBase64) {
    res.status(400).json({ error: "Missing required fields" });
    return;
  }

  try {
    const transport = createTransport();
    const fromAddress =
      functions.config().smtp?.from || "invoices@yourdomain.com";

    await transport.sendMail({
      from: fromAddress,
      to: to,
      subject: subject,
      html: html,
      attachments: [
        {
          filename: pdfFilename || `invoice_${invoiceNumber}.pdf`,
          content: Buffer.from(pdfBase64, "base64"),
          contentType: "application/pdf",
        },
      ],
    });

    res.status(200).json({ success: true });
  } catch (err) {
    console.error("Email send error:", err);
    res.status(500).json({ error: err.message });
  }
});
