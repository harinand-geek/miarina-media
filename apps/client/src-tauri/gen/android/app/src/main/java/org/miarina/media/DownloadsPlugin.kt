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
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSArray
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import java.util.concurrent.ConcurrentLinkedQueue

@InvokeArg
class ActiveDownload {
  lateinit var id: String
  lateinit var title: String
  /** "712 MB of 1.12 GB · 6.4 MB/s · 1 min left" (composed in Rust). */
  lateinit var text: String
  /** 0–100, or -1 when the size is unknown. */
  var percent: Int = -1
}

@InvokeArg
class FinishedDownload {
  lateinit var id: String
  lateinit var title: String
  /** "612 MB · tap to play". */
  lateinit var text: String
}

@InvokeArg
class DownloadsUpdate {
  var active: Array<ActiveDownload> = emptyArray()
  var finished: Array<FinishedDownload> = emptyArray()
}

/**
 * Download notifications (design "B · Notification concepts"): while
 * downloads run, a foreground service keeps the app alive and shows the
 * first one with its percent, size, speed and time left, plus Pause,
 * Cancel and Pause all; finished downloads get "Download complete · tap
 * to play". Rust sends the state at most once a second; buttons pressed in
 * the notification are queued and returned with the next reply.
 */
@TauriPlugin
class DownloadsPlugin(private val activity: Activity) : Plugin(activity) {
  @Command
  fun update(invoke: Invoke) {
    val update = invoke.parseArgs(DownloadsUpdate::class.java)
    val context = activity.applicationContext
    ensureChannels(context)
    if (update.active.isNotEmpty()) askNotificationPermissionOnce()

    if (update.active.isEmpty()) {
      DownloadService.stop(context)
    } else {
      DownloadService.show(context, progressNotification(context, update.active))
    }
    update.finished.forEach { postFinished(context, it) }

    val actions = JSArray()
    while (true) {
      val action = pending.poll() ?: break
      actions.put(JSObject().apply {
        put("action", action.first)
        put("id", action.second)
      })
    }
    invoke.resolve(JSObject().apply { put("actions", actions) })
  }

  private fun progressNotification(context: Context, active: Array<ActiveDownload>): Notification {
    val first = active.first()
    val builder = NotificationCompat.Builder(context, CHANNEL_PROGRESS)
      .setSmallIcon(R.drawable.ic_stat_miarina)
      .setContentTitle(first.title)
      .setContentText(first.text)
      .setSubText(if (active.size > 1) "${active.size} downloading" else null)
      .setProgress(100, first.percent.coerceIn(0, 100), first.percent < 0)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setSilent(true)
      .setCategory(NotificationCompat.CATEGORY_PROGRESS)
      .setContentIntent(openApp(context, null, 0))
      .addAction(0, "Pause", actionIntent(context, ACTION_PAUSE, first.id))
      .addAction(0, "Cancel", actionIntent(context, ACTION_CANCEL, first.id))
    if (active.size > 1) builder.addAction(0, "Pause all", actionIntent(context, ACTION_PAUSE_ALL, ""))
    return builder.build()
  }

  private fun postFinished(context: Context, done: FinishedDownload) {
    if (!canNotify(context)) return
    val notification = NotificationCompat.Builder(context, CHANNEL_DONE)
      .setSmallIcon(R.drawable.ic_stat_miarina)
      .setContentTitle("Download complete")
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

  /** Opens the app; with a task id, plays its file (AppShellPlugin). */
  private fun openApp(context: Context, playTask: String?, requestCode: Int): PendingIntent {
    val intent = Intent(context, MainActivity::class.java)
      .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    playTask?.let { intent.putExtra(AppShellPlugin.EXTRA_PLAY_TASK, it) }
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

  /** Android 13+: asked once, when the first download starts. */
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
    private const val PREFS = "miarina_notifications"
    private const val KEY_ASKED = "permission_asked"

    /** Buttons pressed in the notification, until Rust takes them. */
    val pending = ConcurrentLinkedQueue<Pair<String, String>>()

    fun canNotify(context: Context): Boolean =
      Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED

    fun ensureChannels(context: Context) {
      if (Build.VERSION.SDK_INT < 26) return
      val manager = context.getSystemService(NotificationManager::class.java)
      manager.createNotificationChannel(
        NotificationChannel(CHANNEL_PROGRESS, "Downloads in progress", NotificationManager.IMPORTANCE_LOW),
      )
      manager.createNotificationChannel(
        NotificationChannel(CHANNEL_DONE, "Finished downloads", NotificationManager.IMPORTANCE_DEFAULT),
      )
    }
  }
}

/** Pause / Cancel / Pause all from the notification (not exported). */
class DownloadActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val action = when (intent.action) {
      DownloadsPlugin.ACTION_PAUSE -> "pause"
      DownloadsPlugin.ACTION_CANCEL -> "cancel"
      DownloadsPlugin.ACTION_PAUSE_ALL -> "pause_all"
      else -> return
    }
    // Bounded: only the latest few presses matter.
    if (DownloadsPlugin.pending.size < 32) {
      DownloadsPlugin.pending.add(action to (intent.getStringExtra(DownloadsPlugin.EXTRA_TASK) ?: ""))
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
        if (DownloadsPlugin.canNotify(context)) {
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
