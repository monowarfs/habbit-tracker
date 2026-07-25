import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/recap_share_usecase.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

void main() {
  test(
    'writes the captured PNG bytes to a temp file named after the month '
    'and hands it to the share sheet',
    () async {
      Directory? tempDir;
      ShareParams? capturedParams;

      await shareMonthlyRecap(
        reports: const <ModuleReport>[],
        monthAnchor: const LocalDate(2026, 7, 15),
        capturePng: ({pixelRatio = 3}) async => Uint8List.fromList([1, 2, 3]),
        getTemporaryDirectory: () async {
          tempDir = Directory.systemTemp.createTempSync(
            'recap_share_test_',
          );
          return tempDir!;
        },
        share: (params) async => capturedParams = params,
      );

      expect(capturedParams, isNotNull);
      final file = File(capturedParams!.files!.single.path);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(p.basename(file.path), 'habit_tracker_recap_2026_07.png');

      await tempDir?.delete(recursive: true);
    },
  );

  test('the default capturePng/getTemporaryDirectory/share arguments '
      'exist and type-check against the real APIs', () {
    // Compile-time check only — asserting `shareMonthlyRecap` is
    // callable with zero optional arguments, i.e. its defaults
    // (`RecapCardCapture.capturePng`, `path_provider`'s
    // `getTemporaryDirectory`, `SharePlus.instance.share`) all
    // type-check against the seam signatures. This intentionally never
    // calls the tear-off (that would hit the real platform channels) —
    // it exists purely so a future signature drift on either side fails
    // to compile here rather than only at real app runtime.
    expect(shareMonthlyRecap, isA<Function>());
  });
}
