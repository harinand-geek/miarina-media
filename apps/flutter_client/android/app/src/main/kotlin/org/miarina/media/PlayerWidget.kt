package org.miarina.media

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Home screen player (decision 0013, proposal 7): the cover, title and
 * artist of the track playing, previous / play-pause / next; a tap
 * elsewhere opens the app. Flutter sends the track (HomeWidgetChannel);
 * the playing state comes from the player service itself, so it is right
 * even when the app's screen is gone. Without Flutter, play-pause goes to
 * the player directly and the other buttons open the app (the queue lives
 * in Flutter).
 */
class PlayerWidget : AppWidgetProvider() {

  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
    render(context)
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    when (intent.action) {
      ACTION_TOGGLE -> if (!HomeWidgetChannel.button("toggle")) toggleNatively(context)
      ACTION_NEXT -> HomeWidgetChannel.button("next")
      ACTION_PREVIOUS -> HomeWidgetChannel.button("previous")
    }
  }

  private fun toggleNatively(context: Context) {
    val pending = goAsync()
    val future = MediaController.Builder(
      context,
      SessionToken(context, ComponentName(context, PlaybackService::class.java)),
    ).buildAsync()
    future.addListener({
      try {
        val c = future.get()
        if (c.mediaItemCount > 0) {
          if (c.isPlaying) c.pause() else c.play()
        }
        c.release()
      } catch (_: Exception) {
      }
      pending.finish()
    }, ContextCompat.getMainExecutor(context))
  }

  companion object {
    const val ACTION_TOGGLE = "org.miarina.media.widget.TOGGLE"
    const val ACTION_NEXT = "org.miarina.media.widget.NEXT"
    const val ACTION_PREVIOUS = "org.miarina.media.widget.PREVIOUS"
    private const val PREFS = "mm_player_widget"
    private const val COVER_PX = 168

    fun saveTrack(context: Context, title: String?, artist: String?, art: String?) {
      context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putString("title", title)
        .putString("artist", artist)
        .putString("art", art)
        .apply()
      render(context)
    }

    /** From the player service: playing or not. */
    fun setPlaying(context: Context, playing: Boolean) {
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      if (prefs.getBoolean("playing", false) == playing) return
      prefs.edit().putBoolean("playing", playing).apply()
      render(context)
    }

    fun render(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val component = ComponentName(context, PlayerWidget::class.java)
      if (manager.getAppWidgetIds(component).isEmpty()) return
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val title = prefs.getString("title", null)
      val artist = prefs.getString("artist", null)
      val playing = prefs.getBoolean("playing", false)
      val views = RemoteViews(context.packageName, R.layout.widget_player)
      views.setTextViewText(
        R.id.widget_title,
        title ?: context.getString(R.string.widget_idle),
      )
      views.setTextViewText(
        R.id.widget_artist,
        artist ?: context.getString(R.string.widget_app),
      )
      val cover = prefs.getString("art", null)?.let { cover(it) }
      if (cover != null) {
        views.setImageViewBitmap(R.id.widget_cover, cover)
      } else {
        views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
      }
      views.setImageViewResource(
        R.id.widget_play,
        if (playing) R.drawable.widget_pause else R.drawable.widget_play,
      )
      val open = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
      )
      views.setOnClickPendingIntent(R.id.widget_root, open)
      views.setOnClickPendingIntent(R.id.widget_play, action(context, ACTION_TOGGLE, 1))
      // The queue lives in Flutter: without it, these open the app.
      val live = HomeWidgetChannel.alive
      views.setOnClickPendingIntent(
        R.id.widget_next,
        if (live) action(context, ACTION_NEXT, 2) else open,
      )
      views.setOnClickPendingIntent(
        R.id.widget_previous,
        if (live) action(context, ACTION_PREVIOUS, 3) else open,
      )
      manager.updateAppWidget(component, views)
    }

    private fun action(context: Context, action: String, code: Int): PendingIntent =
      PendingIntent.getBroadcast(
        context,
        code,
        Intent(context, PlayerWidget::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
      )

    /** The cover, small (widgets carry their pictures) and rounded. */
    private fun cover(path: String): Bitmap? {
      val file = File(path)
      if (!file.isFile) return null
      return try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= COVER_PX && bounds.outHeight / (sample * 2) >= COVER_PX) {
          sample *= 2
        }
        val raw = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
          ?: return null
        val side = minOf(raw.width, raw.height)
        val square = Bitmap.createBitmap(raw, (raw.width - side) / 2, (raw.height - side) / 2, side, side)
        val scaled = Bitmap.createScaledBitmap(square, COVER_PX, COVER_PX, true)
        val out = Bitmap.createBitmap(COVER_PX, COVER_PX, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
          shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        val r = COVER_PX * 0.22f
        Canvas(out).drawRoundRect(RectF(0f, 0f, COVER_PX.toFloat(), COVER_PX.toFloat()), r, r, paint)
        out
      } catch (_: Exception) {
        null
      }
    }
  }
}

/**
 * Flutter's side of the home screen player: "update" gives the track,
 * "button" carries the widget's buttons to the queue. Channel
 * org.miarina.media/home_widget.
 */
class HomeWidgetChannel(private val context: Context, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/home_widget")

  init {
    channel.setMethodCallHandler(this)
    instance = this
    PlayerWidget.render(context)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "update" -> {
        PlayerWidget.saveTrack(
          context,
          call.argument<String>("title"),
          call.argument<String>("artist"),
          call.argument<String>("art"),
        )
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    if (instance === this) instance = null
    PlayerWidget.render(context)
  }

  companion object {
    private var instance: HomeWidgetChannel? = null

    val alive: Boolean get() = instance != null

    /** Sends a widget button to Flutter; false when it is not running. */
    fun button(name: String): Boolean {
      val i = instance ?: return false
      i.channel.invokeMethod("button", name)
      return true
    }
  }
}
