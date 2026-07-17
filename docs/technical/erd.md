# Entity-Relationship Diagram

Full schema per `database-design.md`. Polymorphic/loose references
(`notification_ledger.source_id`, `achievements.module_id`) are shown as
dashed relationships since they are application-enforced, not DB foreign
keys — see that document for why.

```mermaid
erDiagram
    APP_SETTINGS {
        text id PK
        text locale
        text theme_mode
        text water_unit
        bool pin_enabled
        text pin_hash
        int pin_lock_timeout_seconds
        int onboarding_completed_at
        int created_at
        int updated_at
    }

    MODULES {
        text id PK
        bool enabled
        int position
        int setup_completed_at
        int created_at
        int updated_at
    }

    NOTIFICATION_LEDGER {
        text id PK
        text module_id
        text source_type
        text source_id "app-enforced ref, not FK"
        int scheduled_for
        int fired_at
        text action
        int action_at
        int snooze_count
        text deep_link_route
        int created_at
        int updated_at
        int deleted_at
    }

    ACHIEVEMENTS {
        text id PK
        text module_id "app-enforced ref, not FK"
        text key
        int progress_current
        int progress_target
        int unlocked_at
        int created_at
        int updated_at
        int deleted_at
    }

    WATER_GOALS {
        text id PK
        int goal_ml
        int effective_from
        int created_at
        int updated_at
        int deleted_at
    }

    WATER_LOGS {
        text id PK
        int amount_ml
        int logged_at
        int created_at
        int updated_at
        int deleted_at
    }

    MEDICINES {
        text id PK
        text name
        text dosage_note
        bool stock_enabled
        int stock_count
        int stock_threshold
        bool stop_when_stock_depleted
        int consumption_per_dose
        int archived_at
        int created_at
        int updated_at
        int deleted_at
    }

    MEDICINE_SCHEDULES {
        text id PK
        text medicine_id FK
        text frequency_type
        int interval_days
        int weekdays_mask
        text times_of_day "JSON array"
        text start_date "local date"
        text end_date "local date"
        int grace_window_minutes
        int created_at
        int updated_at
        int deleted_at
    }

    MEDICINE_DOSES {
        text id PK
        text medicine_id FK
        text schedule_id FK
        int scheduled_for
        text status
        int status_changed_at
        int stock_delta_applied
        int created_at
        int updated_at
        int deleted_at
    }

    MEDICINE_STOCK_EVENTS {
        text id PK
        text medicine_id FK
        text dose_id FK
        int delta
        text reason
        int occurred_at
        int created_at
        int updated_at
        int deleted_at
    }

    PRAYER_SETTINGS {
        text id PK
        text calculation_method
        text asr_method
        bool observes_jumuah
        text location_mode
        real manual_latitude
        real manual_longitude
        text manual_timezone
        text isha_day_rollover_time
        int created_at
        int updated_at
    }

    PRAYER_RECORDS {
        text id PK
        text prayer_date "local date, materialized bucket"
        text prayer_name
        int scheduled_for
        text status
        int status_changed_at
        int created_at
        int updated_at
        int deleted_at
    }

    PRAYER_QADHA_COUNTERS {
        text id PK
        text prayer_name
        int count
        int updated_at
    }

    MEDICINES ||--o{ MEDICINE_SCHEDULES : "has"
    MEDICINES ||--o{ MEDICINE_DOSES : "denormalized ref"
    MEDICINE_SCHEDULES ||--o{ MEDICINE_DOSES : "generates"
    MEDICINES ||--o{ MEDICINE_STOCK_EVENTS : "has"
    MEDICINE_DOSES |o--o{ MEDICINE_STOCK_EVENTS : "optional trigger"
```

Deliberately excluded from FK arrows on the diagram (per `database-design.md`):
`NOTIFICATION_LEDGER.source_id` may reference `MEDICINE_DOSES.id`,
`PRAYER_RECORDS.id`, or a future module's own instance table — this is the
polymorphic seam that lets a new module plug into the shared notification
ledger without a schema migration (see `architecture.md`'s `HabitModule`
contract). `ACHIEVEMENTS.module_id` is the same kind of loose reference.
`WATER_GOALS`, `WATER_LOGS`, `PRAYER_SETTINGS`, `PRAYER_RECORDS`, and
`PRAYER_QADHA_COUNTERS` have no FKs at all — each module's tables are
self-contained, which is itself a plugin-architecture property (a module's
tables can be added or dropped without touching another module's schema).
