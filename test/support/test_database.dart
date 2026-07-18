import 'package:drift/native.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// An in-memory [AppDatabase] for tests — never touches disk/path_provider.
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());
