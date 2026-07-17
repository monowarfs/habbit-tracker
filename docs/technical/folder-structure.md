# Folder Structure

Feature-first, per `00-project-context.md` and `architecture.md`. Full tree
below; `# NEW MODULE GOES HERE` marks the exact, only, insertion points a
future module (e.g. Sleep) needs to touch.

```
lib/
  core/
    database/
      app_database.dart          # @DriftDatabase table list, migration strategy
      tables/
        app_settings_table.dart
        modules_table.dart
        notification_ledger_table.dart
        achievements_table.dart
    router/
      app_router.dart            # GoRouter root config, /lock redirect guard
    theme/
      app_theme.dart             # Material 3 ColorScheme, light/dark
    jobs/
      dose_materialization_job.dart    # D-13, shared by medicine + prayer
      prayer_time_refresh_job.dart
    modules/
      habit_module.dart          # the HabitModule abstract contract
      module_registry.dart       # NEW MODULE GOES HERE — the one shared list
    notifications/
      notification_service.dart  # flutter_local_notifications wrapper
      boot_receiver.dart         # reboot re-registration, FR-C-08
    l10n/
      app_en.arb
      app_bn.arb
    widgets/
      app_scaffold.dart
      empty_state.dart
    utils/
      local_date.dart            # LocalDate/LocalTime value types (D-14)
      uuid.dart                  # UUID v7 generator (D-12)

  features/
    onboarding/
      presentation/
        screens/
          language_select_screen.dart
          module_select_screen.dart
          permission_explainer_screen.dart
        providers/

    dashboard/
      presentation/
        screens/
          dashboard_screen.dart
        providers/
          dashboard_aggregate_provider.dart   # watches each enabled module's own providers

    water/                                     # NEW MODULE GOES HERE (template)
      domain/
        entities/
          water_goal.dart
          water_entry.dart
        repositories/
          water_repository.dart               # abstract interface
        usecases/
          log_water_entry.dart
          calculate_water_streak.dart
          resolve_goal_for_date.dart
      data/
        tables/
          water_goals_table.dart
          water_logs_table.dart
        daos/
          water_dao.dart
        repositories/
          water_repository_impl.dart
      presentation/
        screens/
          water_home_screen.dart
          water_add_entry_screen.dart
          water_stats_screen.dart
        widgets/
          water_progress_ring.dart
          quick_add_button.dart
        providers/
          water_providers.dart
      water_module.dart                        # implements HabitModule

    medicine/                                   # same domain/data/presentation shape
      domain/
        entities/
          medicine.dart
          medicine_schedule.dart
          repeat_rule.dart                      # sealed union, data-models.md
          medicine_dose.dart
          medicine_stock_event.dart
        repositories/
          medicine_repository.dart
        usecases/
          create_medicine_schedule.dart
          mark_dose_done.dart
          calculate_adherence_stats.dart
      data/
        tables/
        daos/
        repositories/
      presentation/
        screens/
        widgets/
        providers/
      medicine_module.dart

    prayer/                                      # same shape
      domain/
        entities/
          prayer_settings.dart
          prayer_record.dart
          prayer_qadha_counter.dart
        repositories/
          prayer_repository.dart
        usecases/
          calculate_prayer_times.dart
          resolve_qadha_cutoff.dart
      data/
        tables/
        daos/
        repositories/
      presentation/
        screens/
        widgets/
        providers/
      prayer_module.dart

    settings/
      presentation/
        screens/
          settings_home_screen.dart
          modules_settings_screen.dart
          pin_settings_screen.dart
        providers/

    lock/
      domain/
        pin_lock_service.dart                    # hash/verify, lock-state machine
      presentation/
        screens/
          pin_entry_screen.dart
        providers/

  main.dart

test/
  core/
    jobs/
      dose_materialization_job_test.dart
  features/
    water/
      domain/
        calculate_water_streak_test.dart
        resolve_goal_for_date_test.dart          # FR-W-04 mid-day goal change case
      data/
        water_repository_impl_test.dart          # against in-memory Drift DB
    medicine/
      domain/
        repeat_rule_every_n_days_test.dart        # D-03, includes the DST-transition case
        mark_dose_done_test.dart                  # grace window / missed transition, D-05
      data/
        medicine_repository_impl_test.dart
    prayer/
      domain/
        qadha_counter_test.dart                    # D-08 auto-increment/floor-at-0
        jumuah_toggle_test.dart                     # D-07
      data/
        prayer_repository_impl_test.dart
  widget_test.dart                                  # default scaffold test, updated per feature

docs/
  product/          # run 01 outputs (prd, FRs, NFRs, personas, ..., decisions.md)
  technical/         # run 02 outputs (this run)
```

## Adding a future module — the only files touched

For a hypothetical `sleep` module: create `lib/features/sleep/` following the
exact `domain/data/presentation` + `sleep_module.dart` shape shown for
`water/` above, add its Drift tables to `core/database/app_database.dart`'s
table list, and add one line, `SleepModule()`, to
`core/modules/module_registry.dart`. No file under `lib/features/water/`,
`lib/features/medicine/`, `lib/features/prayer/`, or any other existing
module's folder is edited — this is the folder-structure-level proof of the
plugin contract described in `architecture.md`.
