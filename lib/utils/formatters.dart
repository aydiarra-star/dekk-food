String formatFcfa(int amount) {
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  final prefix = amount < 0 ? '-' : '';
  return '$prefix${groups.join(' ')} FCFA';
}

String formatOrderDate(DateTime dateTime) {
  const months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year} à $hour:$minute';
}

String normalizePhoneNumber(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');

bool isValidSenegalPhone(String value) {
  final digits = normalizePhoneNumber(value);
  return RegExp(r'^(221)?[23778][0-9]{8}$').hasMatch(digits);
}
