package dev.shurjomoy.habit_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * AppWidgetProvider for all habit-tracker home-screen widgets.
 * Reads module summary data from HomeWidgetPlugin's shared storage
 * and renders a simple RemoteViews layout with headline + optional
 * action button.
 */
open class HabitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_habit)
            val moduleId = getModuleId(context, appWidgetId)
            val summaryJson = HomeWidgetPlugin.getData(context)
                .getString("widget_summary_$moduleId", null)

            if (summaryJson != null) {
                val headline = extractField(summaryJson, "headline") ?: moduleId
                // Append countdown if target time is present and in the future.
                val countdownTargetAt = extractFieldNumeric(summaryJson, "countdownTargetAt")
                val now = System.currentTimeMillis()
                if (countdownTargetAt != null) {
                    val remaining = countdownTargetAt - now
                    if (remaining > 0) {
                        val countdownText = formatCountdown(remaining)
                        views.setTextViewText(R.id.widget_headline, "$headline\n$countdownText")
                    } else {
                        views.setTextViewText(R.id.widget_headline, headline)
                    }
                } else {
                    views.setTextViewText(R.id.widget_headline, headline)
                }

                val actionLabel = extractField(summaryJson, "primaryActionLabel")
                val sourceId = extractField(summaryJson, "primaryActionSourceId")
                if (actionLabel != null && sourceId != null) {
                    views.setViewVisibility(R.id.widget_action_button, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.widget_action_button, actionLabel)
                    val intent = Intent(context, HabitWidgetProvider::class.java).apply {
                        action = "es.antonborri.home_widget.action.INTERACTIVE_CALLBACK"
                        data = Uri.parse("habittracker://widget-tap?moduleId=$moduleId&sourceId=$sourceId")
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        appWidgetId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                    )
                    views.setOnClickPendingIntent(R.id.widget_action_button, pendingIntent)
                } else {
                    views.setViewVisibility(R.id.widget_action_button, android.view.View.GONE)
                }

                val deepLink = extractField(summaryJson, "deepLinkRoute") ?: "/$moduleId"
                val tapIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    putExtra("route", deepLink)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val tapPendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    tapIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_container, tapPendingIntent)
            } else {
                views.setTextViewText(R.id.widget_headline, moduleId.replaceFirstChar { it.uppercase() })
                views.setViewVisibility(R.id.widget_action_button, android.view.View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    open fun getModuleId(context: Context, appWidgetId: Int): String {
        // Default to 'water' for single-widget setups; can be extended
        // with per-widget-instance metadata if multiple widget types ship.
        return "water"
    }

    /** Minimal JSON field extractor — avoids pulling in a JSON library. */
    private fun extractField(json: String, field: String): String? {
        val pattern = "\"$field\":\\s*\"([^\"]*)\"".toRegex()
        return pattern.find(json)?.groupValues?.get(1)
    }

    /** Extracts a numeric (Long) field from a JSON string. */
    private fun extractFieldNumeric(json: String, field: String): Long? {
        val pattern = "\"$field\":\\s*(\\d+)".toRegex()
        return pattern.find(json)?.groupValues?.get(1)?.toLongOrNull()
    }

    /** Formats remaining milliseconds as "Xh Ym" or "Y min". */
    private fun formatCountdown(millis: Long): String {
        val totalMinutes = millis / 60000
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours > 0 -> "${hours}h ${minutes}m"
            else -> "${minutes} min"
        }
    }
}
