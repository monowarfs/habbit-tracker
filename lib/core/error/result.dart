import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/error/app_exception.dart';

part 'result.freezed.dart';

/// A repository/use-case outcome: either a value or an [AppException].
///
/// Hand-rolled rather than a third-party `Either`/FP package
/// (`strategies/error-handling-logging.md`) — Freezed already generates
/// the exhaustive-`switch`-friendly sealed class this needs, so this is a
/// same-file addition, not a new dependency.
@freezed
sealed class Result<T> with _$Result<T> {
  /// A successful outcome.
  const factory Result.success(T value) = Success<T>;

  /// A failed outcome.
  const factory Result.failure(AppException error) = Failure<T>;
}
