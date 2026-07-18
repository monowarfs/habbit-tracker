import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';

void main() {
  test('success carries its value through exhaustive pattern matching', () {
    const result = Result<int>.success(42);
    final matched = switch (result) {
      Success(:final value) => value,
      Failure() => -1,
    };
    expect(matched, 42);
  });

  test('failure carries its AppException through exhaustive pattern '
      'matching', () {
    const result = Result<int>.failure(AppException.notFound('Widget', 'x'));
    final matched = switch (result) {
      Success() => null,
      Failure(:final error) => error,
    };
    expect(matched, isA<NotFoundException>());
  });
}
