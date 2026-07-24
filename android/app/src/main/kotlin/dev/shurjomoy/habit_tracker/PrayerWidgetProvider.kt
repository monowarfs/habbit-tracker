package dev.shurjomoy.habit_tracker

import android.content.Context

/**
 * Widget provider for the Prayer Countdown widget.
 * Overrides module ID to "prayer" while inheriting all rendering
 * logic from [HabitWidgetProvider].
 */
class PrayerWidgetProvider : HabitWidgetProvider() {
    override fun getModuleId(context: Context, appWidgetId: Int): String {
        return "prayer"
    }
}