import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/reports/chart_image_renderer.dart';
import 'package:habit_tracker/core/reports/export_report_use_case.dart';
import 'package:habit_tracker/core/reports/share_report_helper.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/reports/presentation/providers/reports_providers.dart';
import 'package:habit_tracker/features/reports/presentation/recap_share_usecase.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/monthly_recap_card.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Weekly/monthly/yearly cross-module reports (FR-C-12/14).
class ReportsScreen extends ConsumerStatefulWidget {
  /// Creates the reports screen.
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;
  late LocalDate _anchor = localDayKey(clock.now());
  bool _exporting = false;
  DateRange? _customRange;

  void _shiftPeriod(int direction) {
    // Custom/all-time ranges have no natural "previous/next" step — the
    // chevrons are disabled for those periods (see build()).
    setState(() {
      _anchor = switch (_period) {
        ReportPeriod.week => _anchor.addDays(7 * direction),
        ReportPeriod.month => LocalDate(
          _anchor.year,
          _anchor.month + direction,
          1,
        ),
        ReportPeriod.year => LocalDate(
          _anchor.year + direction,
          _anchor.month,
          1,
        ),
        ReportPeriod.custom || ReportPeriod.allTime => _anchor,
      };
    });
  }

  /// Selects [period], gating the premium [ReportPeriod.custom]/
  /// [ReportPeriod.allTime] options behind [isPremiumUserProvider] — a
  /// non-premium tap shows an upsell snackbar instead of changing
  /// anything (`docs/superpowers/specs/04-premium/
  /// 08-extended-stats-range-multi-year-trends-design.md`).
  Future<void> _selectPeriod(ReportPeriod period) async {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.read(isPremiumUserProvider);
    if ((period == ReportPeriod.custom || period == ReportPeriod.allTime) &&
        !isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportsPremiumRangeUpsell)),
      );
      return;
    }
    if (period == ReportPeriod.allTime) {
      final installDate = ref.read(appSettingsProvider).value?.installDate;
      final today = localDayKey(clock.now());
      final start = installDate == null
          ? today.addDays(-365 * 5)
          : LocalDate.fromDateTime(installDate);
      setState(() {
        _period = period;
        _customRange = DateRange(start: start, end: today);
      });
      return;
    }
    if (period == ReportPeriod.custom) {
      final today = clock.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime.utc(2000),
        lastDate: today,
        initialDateRange: DateTimeRange(
          start: today.subtract(const Duration(days: 30)),
          end: today,
        ),
        helpText: l10n.reportsCustomRangePickerTitle,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _period = period;
        _customRange = DateRange(
          start: LocalDate.fromDateTime(picked.start),
          end: LocalDate.fromDateTime(picked.end),
        );
      });
      return;
    }
    setState(() => _period = period);
  }

  Future<void> _shareMonth(List<ModuleReport> reports) async {
    final overlayState = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      // Renders off-screen (far outside the visible viewport) so it
      // lays out and paints without ever being shown to the user — the
      // standard way to use `RenderRepaintBoundary` for a widget that
      // isn't part of the normal visible layout (design doc, "Entry
      // point").
      builder: (context) => Positioned(
        left: -9999,
        top: 0,
        child: Material(
          child: RecapCardCapture(
            child: MonthlyRecapCard(reports: reports, monthAnchor: _anchor),
          ),
        ),
      ),
    );
    overlayState.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    await completer.future;
    try {
      await shareMonthlyRecap(reports: reports, monthAnchor: _anchor);
    } on Object {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportsShareMonthFailed)),
        );
      }
    } finally {
      entry.remove();
    }
  }

  /// Opens the export format picker, gated behind [isPremiumUserProvider]
  /// (`docs/superpowers/specs/04-premium/05-exportable-pdf-csv-reports-
  /// IMPLEMENTATION-PLAN.md`) — exports whatever period is currently
  /// selected on this screen rather than duplicating a second range
  /// picker inside the sheet.
  Future<void> _openExportSheet(List<ModuleReport> reports) async {
    final l10n = AppLocalizations.of(context)!;
    if (!ref.read(isPremiumUserProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportsExportPremiumRequired)),
      );
      return;
    }
    final moduleNames = reports.map((r) => r.displayName).join(', ');
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.reportsExportSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                reports.isEmpty
                    ? l10n.reportsExportEmptyWarning
                    : l10n.reportsExportIncludes(moduleNames),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_export(true, reports)),
                      child: Text(l10n.reportsExportFormatPdf),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_export(false, reports)),
                      child: Text(l10n.reportsExportFormatCsv),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders each report's `PeriodBarChart` off-screen (same
  /// far-outside-the-viewport `Overlay` technique as [_shareMonth]) and
  /// captures it to PNG, one module at a time so each capture's
  /// [ChartImageRenderer] boundary key never collides with another's.
  Future<Map<String, Uint8List>> _captureChartImages(
    List<ModuleReport> reports,
  ) async {
    final overlayState = Overlay.of(context);
    final images = <String, Uint8List>{};
    for (final report in reports) {
      if (report.points.isEmpty) continue;
      final renderer = ChartImageRenderer();
      final completer = Completer<void>();
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999,
          top: 0,
          child: Material(
            child: SizedBox(
              width: 400,
              child: renderer.wrap(
                PeriodBarChart(
                  points: report.points,
                  color: report.accentColor,
                ),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(entry);
      try {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => completer.complete(),
        );
        await completer.future;
        images[report.moduleId] = await renderer.capture();
      } finally {
        // Always remove the off-screen entry, even if capture() throws —
        // otherwise a failed capture mid-loop leaks it into the app's
        // Overlay permanently.
        entry.remove();
      }
    }
    return images;
  }

  Future<void> _export(bool asPdf, List<ModuleReport> reports) async {
    if (_exporting) return;
    _exporting = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context)
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.reportsExportInProgress),
          duration: const Duration(seconds: 30),
        ),
      );
    try {
      final modules = ref.read(habitModulesProvider);
      final periodLabel = switch (_period) {
        ReportPeriod.week => l10n.reportsPeriodWeek,
        ReportPeriod.month => l10n.reportsPeriodMonth,
        ReportPeriod.year => l10n.reportsPeriodYear,
        ReportPeriod.allTime => l10n.reportsPeriodAllTime,
        ReportPeriod.custom => l10n.reportsPeriodCustom,
      };
      final Result<String> result;
      if (asPdf) {
        final chartImages = await _captureChartImages(reports);
        final logoData = await rootBundle.load('assets/icon/icon.png');
        result = await const ExportReportUseCase().exportPdf(
          modules: modules,
          period: _period,
          anchor: _anchor,
          periodLabel: periodLabel,
          logoBytes: logoData.buffer.asUint8List(),
          chartImages: chartImages,
          customRange: _customRange,
        );
      } else {
        result = await const ExportReportUseCase().exportCsv(
          modules: modules,
          period: _period,
          anchor: _anchor,
          customRange: _customRange,
        );
      }
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      if (result case Failure(:final error)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.reportsExportFailed(error.toString()))),
        );
        return;
      }
      await shareReportFile((result as Success<String>).value);
    } on Object catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.reportsExportFailed(e.toString()))),
        );
      }
    } finally {
      _exporting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);
    final canShift =
        _period != ReportPeriod.custom && _period != ReportPeriod.allTime;
    final reportsAsync = ref.watch(
      moduleReportsProvider((
        period: _period,
        anchor: _anchor,
        customRange: _customRange,
      )),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.reportsExportButton,
            onPressed: () =>
                unawaited(_openExportSheet(reportsAsync.value ?? [])),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.reportsShareMonthButton,
            onPressed:
                _period == ReportPeriod.month &&
                    (reportsAsync.value?.isNotEmpty ?? false)
                ? () => unawaited(_shareMonth(reportsAsync.value!))
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canShift ? () => _shiftPeriod(-1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canShift ? () => _shiftPeriod(1) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.heatmap),
                icon: const Icon(Icons.grid_view),
                label: Text(l10n.heatmapTitle),
              ),
            ),
          ),
          SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(
                value: ReportPeriod.week,
                label: Text(l10n.reportsPeriodWeek),
              ),
              ButtonSegment(
                value: ReportPeriod.month,
                label: Text(l10n.reportsPeriodMonth),
              ),
              ButtonSegment(
                value: ReportPeriod.year,
                label: Text(l10n.reportsPeriodYear),
              ),
              ButtonSegment(
                value: ReportPeriod.allTime,
                label: Text(l10n.reportsPeriodAllTime),
                icon: isPremium ? null : const Icon(Icons.lock, size: 14),
              ),
              ButtonSegment(
                value: ReportPeriod.custom,
                label: Text(l10n.reportsPeriodCustom),
                icon: isPremium ? null : const Icon(Icons.lock, size: 14),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => unawaited(_selectPeriod(s.first)),
          ),
          Expanded(
            child: reportsAsync.when(
              data: (reports) => reports.isEmpty
                  ? Center(child: Text(l10n.reportsEmptyState))
                  : ListView(
                      children: [
                        for (final report in reports)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    l10n.reportsLongestStreak(
                                      report.longestStreak,
                                    ),
                                  ),
                                  PeriodBarChart(
                                    points: report.points,
                                    color: report.accentColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
              error: (error, stack) => Center(child: Text('$error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
