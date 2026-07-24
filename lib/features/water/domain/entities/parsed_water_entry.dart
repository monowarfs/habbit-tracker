import 'package:freezed_annotation/freezed_annotation.dart';

part 'parsed_water_entry.freezed.dart';

/// A natural-language quick-add input, parsed into a candidate water log
/// (`docs/superpowers/plans/ai-powered/
/// 02-natural-language-quick-add-impl-plan.md`). `null` fields mean the
/// parser couldn't extract that part from [rawText].
@freezed
sealed class ParsedWaterEntry with _$ParsedWaterEntry {
  /// Creates a [ParsedWaterEntry].
  const factory ParsedWaterEntry({
    required String confidence, required String rawText, int? amountMl,
    DateTime? loggedAt,
  }) = _ParsedWaterEntry;
}
