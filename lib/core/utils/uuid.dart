import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID v7 (D-12) — every table's primary key, time-ordered so
/// it sorts naturally by creation order.
String generateId() => _uuid.v7();
