# Fixes & Changes

- Translate everything to Dutch
- Change client data to "Naam", "Kenteken", "Km-stand", "Datum" - Optional: "Adres", "Telefoonnummer"
- Change invoice items to "Omschrijving", "Aantal", "Prijs Ex. BTW", "Prijs Incl. BTW"
- Change invoice details layout to include a \n between each field, and change "Terms" to "Opmerkingen"
- Remove due date
- When adding an item from products, make it so the quantity is easily editable without having to go into the item details (e.g. a small input field in the invoice item list)
- Change it so all 'Continue' buttons appear on the right side of the screen, and all 'Back' buttons appear on the left side of the screen
- Remove payment terms
- In each invoice, for the notes. Dont show the text "Notes" above the notes field, just show the text that the user has inputted. If there is no text, then show "No notes added"
- For the email message, change it so it can be edited in a separate tab so it's standardized across all invoices. The user can add variables like {client_name} and {invoice_number} that will be replaced with the actual client name and invoice number when sending the email.
- Make 'Send Invoice' button directly send the invoice without showing the share sheet.
- Make the invoice file name format "Factuur {invoice_number} - {Kenteken}.pdf", and pass this correctly to the share sheet and email attachment.
- Make business logo saved in firestore as a base64 string instead of a URL, and load it from there when generating the invoice PDF. This way the logo will be included in the PDF even if the user deletes the image from their device or if there are issues with Firebase Storage access.
- Make Classic template the default and remove the rest.
