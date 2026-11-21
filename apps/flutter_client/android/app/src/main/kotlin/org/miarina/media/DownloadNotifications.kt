package org.miarina.media

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Download notifications (design_handoff_android_v2, notification concepts),
 * ported from DownloadsPlugin of the Tauri app. While downloads run, a
 * foreground service keeps the process (and the Rust download manager in
 * it) alive and shows the first download with its percent, size, speed and
 * time left, plus Pause, Cancel and Pause all; a finished download gets
 * "Download complete · tap to play". Dart sends the state at most once a
 * second, with the texts in the app's language; the buttons pressed are
 * returned with the next reply.
 */
class DownloadNotificationsChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/download_notifications")

  init {
    channel.setMethodCallHandler(this)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "update") {
      result.notImplemented()
      return
    }
    val context = activity.applicationContext
    val labels = Labels.from(call.argument<Map<String, Any?>>("labels"))
    val active = (call.argument<List<Map<String, Any?>>>("active") ?: emptyList()).map(Active::from)
    val finished = (call.argument<List<Map<String, Any?>>>("finished") ?: emptyList()).map(Finished::from)
    ensureChannels(context, labels)
    if (active.isNotEmpty()) askNotificationPermissionOnce()

    if (active.isEmpty()) {
      DownloadService.stop(context)
    } else {
      DownloadService.show(context, progressNotification(context, active, labels))
    }
    finished.forEach { postFinished(context, it, labels) }

    val actions = ArrayList<Map<String, String>>()
    while (true) {
      val action = pending.poll() ?: break
      actions.add(mapOf("action" to action.first, "id" to action.second))
    }
    result.success(actions)
  }

  private class Labels(
    val pause: String,
    val cancel: String,
    val pauseAll: String,
    val complete: String,
    val several: String,
    val channelProgress: String,
    val channelDone: String,
  ) {
    companion object {
      fun from(raw: Map<String, Any?>?): Labels {
        fun get(key: String, fallback: String) = (raw?.get(key) as? String) ?: fallback
        return Labels(
          pause = get("pause", "Pause"),
          cancel = get("cancel", "Cancel"),
          pauseAll = get("pauseAll", "Pause all"),
          complete = get("complete", "Download complete"),
          several = get("several", "%d downloading"),
          channelProgress = get("channelProgress", "Downloads in progress"),
          channelDone = get("channelDone", "Finished downloads"),
        )
      }
    }
  }

  private class Active(val id: String, val title: String, val text: String, val percent: Int) {
    companion object {
      fun from(m: Map<String, Any?>) = Active(
        id = (m["id"] as? String).orEmpty().take(64),
        title = (m["title"] as? String).orEmpty().take(300),
        text = (m["text"] as? String).orEmpty().take(200),
        percent = (m["percent"] as? Number)?.toInt() ?: -1,
      )
    }
  }

  private class Finished(val id: String, val title: String, val text: String) {
    companion object {
      fun from(m: Map<String, Any?>) = Finished(
        id = (m["id"] as? String).orEmpty().take(64),
        title = (m["title"] as? String).orEmpty().take(300),
        text = (m["text"] as? String).orEmpty().take(200),
      )
    }
  }

  private fun progressNotification(context: Context, active: List<Active>, labels: Labels): Notification {
    val first = active.first()
    val builder = NotificationCompat.Builder(context, CHANNEL_PROGRESS)
      .setSmallIcon(R.drawable.ic_stat_miarina)
      .setContentTitle(first.title)
      .setContentText(first.text)
      .setSubText(if (active.size > 1) labels.several.format(active.size) else null)
      .setProgress(100, first.percent.coerceIn(0, 100), first.percent < 0)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setSilent(true)
      .setCategory(NotificationCompat.CATEGORY_PROGRESS)
      .setContentIntent(openApp(context, null, 0))
      .addAction(0, labels.pause, actionIntent(context, ACTION_PAUSE, first.id))
      .addAction(0, labels.cancel, actionIntent(context, ACTION_CANCEL, first.id))
    if (active.size > 1) builder.addAction(0, labels.pauseAll, actionIntent(context, ACTION_PAUSE_ALL, ""))
    return builder.build()
  }

  private fun postFinished(context: Context, done: Finished, labels: Labels) {
    if (!canNotify(context)) return
    val notification = NotificationCompat.Builder(context, CHANNEL_DONE)
      .setSmallIcon(R.drawable.ic_stat_miarina)
      .setContentTitle(labels.complete)
      .setContentText("${done.title} · ${done.text}")
      .setAutoCancel(true)
      .setContentIntent(openApp(context, done.id, done.id.hashCode()))
      .build()
    try {
      NotificationManagerCompat.from(context).notify(done.id.hashCode(), notification)
    } catch (_: SecurityException) {
      // Permission withdrawn meanwhile: the in-app list still shows it.
    }
  }

  /** Opens the app; with a task id, plays its file (OpenWithChannel). */
  private fun openApp(context: Context, playTask: String?, requestCode: Int): PendingIntent {
    val intent = Intent(context, MainActivity::class.java)
      .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    playTask?.let { intent.putExtra(EXTRA_PLAY_TASK, it) }
    return PendingIntent.getActivity(
      context, requestCode, intent,
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
  }

  private fun actionIntent(context: Context, action: String, id: String): PendingIntent {
    val intent = Intent(context, DownloadActionReceiver::class.java)
      .setAction(action)
      .putExtra(EXTRA_TASK, id)
    return PendingIntent.getBroadcast(
      context, (action + id).hashCode(), intent,
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
  }

  /**
   * Android 13+: asked once, when the first download starts, unless the
   * explanation screen (A-06) already asked.
   */
  private fun askNotificationPermissionOnce() {
    if (Build.VERSION.SDK_INT < 33 || canNotify(activity)) return
    val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    if (prefs.getBoolean(KEY_ASKED, false)) return
    prefs.edit().putBoolean(KEY_ASKED, true).apply()
    ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7001)
  }

  companion object {
    const val CHANNEL_PROGRESS = "downloads"
    const val CHANNEL_DONE = "downloads_done"
    const val ACTION_PAUSE = "org.miarina.media.action.PAUSE"
    const val ACTION_CANCEL = "org.miarina.media.action.CANCEL"
    const val ACTION_PAUSE_ALL = "org.miarina.media.action.PAUSE_ALL"
    const val EXTRA_TASK = "org.miarina.media.extra.TASK"

    /** Set by the "Download complete" notification, read by OpenWithChannel. */
    const val EXTRA_PLAY_TASK = "org.miarina.media.extra.PLAY_TASK"
    private const val PREFS = "miarina_notifications"
    private const val KEY_ASKED = "permission_asked"

    /** Buttons pressed in the notification, until Dart takes them. */
    val pending = ConcurrentLinkedQueue<Pair<String, String>>()

    fun canNotify(context: Context): Boolean =
      Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED

    private fun ensureChannels(context: Context, labels: Labels) {
      if (Build.VERSION.SDK_INT < 26) return
      val manager = context.getSystemService(NotificationManager::class.java)
      manager.createNotificationChannel(
        NotificationChannel(CHANNEL_PROGRESS, labels.channelProgress, NotificationManager.IMPORTANCE_LOW),
      )
      manager.createNotificationChannel(
        NotificationChannel(CHANNEL_DONE, labels.channelDone, NotificationManager.IMPORTANCE_DEFAULT),
      )
    }
  }
}

/** Pause / Cancel / Pause all from the notification (not exported). */
class DownloadActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val action = when (intent.action) {
      DownloadNotificationsChannel.ACTION_PAUSE -> "pause"
      DownloadNotificationsChannel.ACTION_CANCEL -> "cancel"
      DownloadNotificationsChannel.ACTION_PAUSE_ALL -> "pause_all"
      else -> return
    }
    // Bounded: only the latest few presses matter.
    if (DownloadNotificationsChannel.pending.size < 32) {
      val id = (intent.getStringExtra(DownloadNotificationsChannel.EXTRA_TASK) ?: "").take(64)
      DownloadNotificationsChannel.pending.add(action to id)
    }
  }
}

/**
 * Keeps the process running while downloads are active (the Rust download
 * manager lives in it) and carries the progress notification.
 */
class DownloadService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notification = latest ?: run {
      stopSelf()
      return START_NOT_STICKY
    }
    if (Build.VERSION.SDK_INT >= 29) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
    running = true
    // Not restarted by the system: the manager resumes tasks on next start.
    return START_NOT_STICKY
  }

  /** Android 15 limits data-sync services to 6 h a day: stop cleanly. */
  override fun onTimeout(startId: Int, fgsType: Int) {
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
  }

  override fun onDestroy() {
    running = false
    super.onDestroy()
  }

  companion object {
    private const val NOTIFICATION_ID = 7000

    @Volatile
    private var latest: Notification? = null

    @Volatile
    private var running = false

    fun show(context: Context, notification: Notification) {
      latest = notification
      if (running) {
        if (DownloadNotificationsChannel.canNotify(context)) {
          try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
          } catch (_: SecurityException) {
          }
        }
      } else {
        try {
          ContextCompat.startForegroundService(context, Intent(context, DownloadService::class.java))
        } catch (_: Exception) {
          // Not allowed from the background: downloads go on while the app lives.
        }
      }
    }

    fun stop(context: Context) {
      latest = null
      if (running) context.stopService(Intent(context, DownloadService::class.java))
    }
  }
}
