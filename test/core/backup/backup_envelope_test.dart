import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/backup/backup_envelope.dart';

void main() {
  test('toJson round-trips through jsonEncode/jsonDecode', () {
    final envelope = BackupEnvelope(
      schemaVersion: BackupEnvelope.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 6, 1, 12),
      appVersion: '1.0.0',
      modules: const {
        'water': {'goals': <Object?>[]},
      },
      common: const {'appSettings': <String, Object?>{}},
    );
    final decoded =
        jsonDecode(jsonEncode(envelope.toJson())) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 1);
    expect(decoded['exportedAt'], '2026-06-01T12:00:00.000Z');
    expect(decoded['appVersion'], '1.0.0');
    expect(decoded['modules'], {
      'water': {'goals': <Object?>[]},
    });
  });

  test('currentSchemaVersion is 1', () {
    expect(BackupEnvelope.currentSchemaVersion, 1);
  });
}
