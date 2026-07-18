import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/app_exception.dart';

void main() {
  test('severityOf maps each variant to its documented log level', () {
    expect(
      severityOf(const AppException.validation('goal', 'too small')),
      LogSeverity.warning,
    );
    expect(
      severityOf(const AppException.notFound('Medicine', 'abc')),
      LogSeverity.warning,
    );
    expect(
      severityOf(const AppException.storage('insert', 'disk full')),
      LogSeverity.error,
    );
    expect(
      severityOf(const AppException.permission('location')),
      LogSeverity.info,
    );
    expect(
      severityOf(const AppException.unexpected('boom', StackTrace.empty)),
      LogSeverity.error,
    );
  });
}
