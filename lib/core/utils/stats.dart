/// The median of [values]; average of the two middle values when the count
/// is even. Callers must pass a non-empty list.
int median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
