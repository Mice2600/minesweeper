import 'dart:math';

const _alphabet =
    'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

/// Short random ID, URL-safe, ambiguity-free (no 0/O/1/l/I).
String shortId([int length = 10]) {
  final rng = Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.write(_alphabet[rng.nextInt(_alphabet.length)]);
  }
  return buf.toString();
}

/// Six-digit join code used as a fallback for manual entry.
String joinCode() {
  final rng = Random.secure();
  final n = rng.nextInt(900000) + 100000;
  return n.toString();
}
