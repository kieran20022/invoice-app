/// The sequence number at the end of an invoice number (`F-0055` → 55), or
/// null for one that carries none (a workshop invoice is still unnumbered).
int? sequenceOf(String invoiceNumber) {
  final match = RegExp(r'(\d+)\s*$').firstMatch(invoiceNumber);
  return match == null ? null : int.parse(match.group(1)!);
}

/// Where a numbering counter should stand after deleting the invoices
/// numbered [deleted], given the numbers still in use in that sequence
/// ([remaining]) and the counter's current value (the next number to hand
/// out).
///
/// What decides it is the number just below the counter — the last one
/// handed out. When that one was deleted, the counter goes back to just above
/// the highest number left: delete 55 while the counter is at 56 and the next
/// invoice is 55 again. That works however the deletes came: 56 then 55, both
/// at once, or 56 after an earlier gap at the end. A number in the middle of
/// the list cannot be given back without renumbering the invoices after it,
/// so deleting one leaves the counter alone, as does a counter set ahead of
/// the list on purpose (Settings' starting number) — the number below it was
/// never deleted.
int rolledBackCounter({
  required int counter,
  required Iterable<int> remaining,
  required Iterable<int> deleted,
}) {
  final gone = deleted.toSet();
  final lastHandedOut = counter - 1;
  if (!gone.contains(lastHandedOut) || remaining.contains(lastHandedOut)) {
    return counter;
  }

  if (remaining.isNotEmpty) {
    final target = remaining.reduce((a, b) => a > b ? a : b) + 1;
    return target < counter ? target : counter;
  }
  // Nothing left in the sequence: the list's start is unknown, so walk down
  // only through numbers known to be deleted.
  var next = counter;
  while (gone.contains(next - 1)) {
    next--;
  }
  return next;
}
