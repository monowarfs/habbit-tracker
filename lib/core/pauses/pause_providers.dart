import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/pauses/pause_repository.dart';
import 'package:habit_tracker/core/pauses/pause_service.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';

/// Provides the [PauseRepository].
final pauseRepositoryProvider = Provider<PauseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PauseRepository(db);
});

/// Provides the [PauseService].
final pauseServiceProvider = Provider<PauseService>((ref) {
  final db = ref.watch(databaseProvider);
  return PauseService(
    pauseRepository: ref.watch(pauseRepositoryProvider),
    notificationLedger: NotificationLedgerRepository(db),
  );
});
