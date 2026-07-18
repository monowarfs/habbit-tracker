import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_exception.freezed.dart';

/// The app's failure taxonomy (`strategies/error-handling-logging.md`) —
/// every repository/use-case failure is one of these, never an arbitrary
/// thrown exception crossing the domain/presentation boundary.
@freezed
sealed class AppException with _$AppException implements Exception {
  /// User-input validation failure (expected, not a bug).
  const factory AppException.validation(String field, String message) =
      ValidationException;

  /// The referenced entity no longer exists.
  const factory AppException.notFound(String entity, String id) =
      NotFoundException;

  /// A storage-layer (DB/disk) operation failed.
  const factory AppException.storage(String operation, Object cause) =
      StorageException;

  /// A required OS permission was denied.
  const factory AppException.permission(String permission) =
      PermissionException;

  /// An unanticipated failure.
  const factory AppException.unexpected(Object cause, StackTrace trace) =
      UnexpectedException;
}

/// How severely each [AppException] variant should be logged
/// (`strategies/error-handling-logging.md`'s "what gets logged" table).
enum LogSeverity {
  /// Expected, user-initiated outcome — not a failure.
  info,

  /// Expected user-input/state issue.
  warning,

  /// A real failure worth full cause + stack trace.
  error,
}

/// Pure mapping from an [AppException] variant to its documented
/// [LogSeverity] — kept separate from the actual logging I/O so it's
/// trivially unit-testable.
LogSeverity severityOf(AppException exception) => switch (exception) {
  ValidationException() => LogSeverity.warning,
  NotFoundException() => LogSeverity.warning,
  StorageException() => LogSeverity.error,
  PermissionException() => LogSeverity.info,
  UnexpectedException() => LogSeverity.error,
};
