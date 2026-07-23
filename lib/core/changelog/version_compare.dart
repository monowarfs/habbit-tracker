/// Compares two dotted-integer version strings numerically.
///
/// Falls back to `0` on a malformed segment rather than throwing — a
/// corrupt/missing version string must never crash startup.
int compareVersions(String a, String b) {
  final partsA = a.split('.').map(_parseIntOrZero);
  final partsB = b.split('.').map(_parseIntOrZero);
  final len = partsA.length > partsB.length ? partsA.length : partsB.length;

  final listA = partsA.toList();
  final listB = partsB.toList();
  while (listA.length < len) {
    listA.add(0);
  }
  while (listB.length < len) {
    listB.add(0);
  }

  for (var i = 0; i < len; i++) {
    if (listA[i] > listB[i]) return 1;
    if (listA[i] < listB[i]) return -1;
  }
  return 0;
}

int _parseIntOrZero(String s) => int.tryParse(s) ?? 0;
