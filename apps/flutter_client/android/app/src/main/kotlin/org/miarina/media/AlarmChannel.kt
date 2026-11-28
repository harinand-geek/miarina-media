package org.miarina.media

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Music alarm (decision 0013, proposal 8): the system wakes the app at the
 * time asked (setAlarmClock, as clock apps do; the status bar shows the
 * alarm), the app opens over the lock screen and Flutter plays. Flutter
 * computes the next time; it is kept here too, so a reboot sets it again
 * (AlarmBootReceiver). Channel org.miarina.media/alarm.
 */
class AlarmChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/alarm")

  /** The activity was started by the alarm and Flutter was not told yet. */
  private var pending = false

  init {
    channel.setMethodCallHandler(this)
  }

  /** From MainActivity: started, or brought back, by the alarm. */
  fun onAlarmIntent() {
    pending = true
    channel.invokeMethod("fired", null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "schedule" -> {
        val at = call.argument<Number>("atMs")?.toLong()
        if (at == null) return result.error("bad_argument", "atMs", null)
        result.success(schedule(activity, at))
      }
      "cancel" -> {
        cancel(activity)
        result.success(null)
      }
      "canExact" -> result.success(canExact(activity))
      "requestExact" -> {
        if (Build.VERSION.SDK_INT >= 31) {
          activity.startActivity(
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
              .setData(Uri.parse("package:${activity.packageName}")),
          )
        }
        result.success(null)
      }
      // Asked once at launch: whether the app was opened by the alarm.
      "takeLaunch" -> {
        result.success(pending)
        pending = false
      }
      // The alarm was stopped: the app no longer shows over the lock screen.
      "release" -> {
        pending = false
        if (Build.VERSION.SDK_INT >= 27) {
          activity.setShowWhenLocked(false)
          activity.setTurnScreenOn(false)
        }
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  companion object {
    const val EXTRA_ALARM = "org.miarina.media.ALARM"
    private const val PREFS = "mm_alarm"

    fun canExact(context: Context): Boolean {
      if (Build.VERSION.SDK_INT < 31) return true
      val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      return manager.canScheduleExactAlarms()
    }

    private fun operation(context: Context): PendingIntent = PendingIntent.getActivity(
      context,
      40,
      Intent(context, MainActivity::class.java)
        .putExtra(EXTRA_ALARM, true)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun show(context: Context): PendingIntent = PendingIntent.getActivity(
      context,
      41,
      Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Sets the alarm at [atMs]; false when exact alarms are not allowed. */
    fun schedule(context: Context, atMs: Long): Boolean {
      context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putLong("at", atMs).apply()
      if (!canExact(context)) return false
      val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      return try {
        manager.setAlarmClock(
          AlarmManager.AlarmClockInfo(atMs, show(context)),
          operation(context),
        )
        true
      } catch (_: SecurityException) {
        false
      }
    }

    fun cancel(context: Context) {
      context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove("at").apply()
      val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      manager.cancel(operation(context))
    }

    /** After a reboot: the alarm still ahead is set again. */
    fun restore(context: Context) {
      val at = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("at", 0)
      if (at > System.currentTimeMillis()) schedule(context, at)
    }
  }
}

/** Sets the music alarm again after the phone restarts. */
class AlarmBootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_BOOT_COMPLETED) AlarmChannel.restore(context)
  }
}
