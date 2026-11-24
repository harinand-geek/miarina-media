package org.miarina.media

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.util.Rational
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The video player's screen controls (A-04 / A-04b): the window's
 * brightness (only while the player shows; the system setting is never
 * changed), the media volume, picture in picture with a play / pause
 * button, and the orientation. Channel org.miarina.media/screen_control.
 */
class ScreenControlChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
  private val togglePlay: () -> Unit,
) : MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/screen_control")
  private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
  private var aspect = Rational(16, 9)
  private var autoPip = false
  private var playing = false

  private val receiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      if (intent?.action == ACTION_TOGGLE) togglePlay()
    }
  }

  init {
    channel.setMethodCallHandler(this)
    ContextCompat.registerReceiver(
      activity,
      receiver,
      IntentFilter(ACTION_TOGGLE),
      ContextCompat.RECEIVER_NOT_EXPORTED,
    )
  }

  private val pipSupported: Boolean
    get() = Build.VERSION.SDK_INT >= 26 &&
      activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "brightness" -> {
        // The window's own value, else the system's (0..255).
        val own = activity.window.attributes.screenBrightness
        val value = if (own >= 0f) own else try {
          android.provider.Settings.System.getInt(
            activity.contentResolver,
            android.provider.Settings.System.SCREEN_BRIGHTNESS,
          ) / 255f
        } catch (e: Exception) {
          0.5f
        }
        result.success(value.toDouble())
      }
      "setBrightness" -> {
        // -1 gives the screen back to the system setting.
        val v = (call.argument<Number>("value") ?: -1).toFloat()
        val attrs = activity.window.attributes
        attrs.screenBrightness = if (v < 0f) -1f else v.coerceIn(0.01f, 1f)
        activity.window.attributes = attrs
        result.success(null)
      }
      "volume" -> {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        result.success(audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max)
      }
      "setVolume" -> {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val v = (call.argument<Number>("value") ?: 0).toDouble().coerceIn(0.0, 1.0)
        try {
          audio.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(v * max).toInt(), 0)
        } catch (e: SecurityException) {
          // Do Not Disturb may refuse it.
        }
        result.success(null)
      }
      "pipSupported" -> result.success(pipSupported)
      "setVideo" -> {
        // The picture's size and whether it plays: the PiP window's shape,
        // its button, and whether leaving the app opens it.
        val w = call.argument<Number>("width")?.toInt() ?: 16
        val h = call.argument<Number>("height")?.toInt() ?: 9
        aspect = clampAspect(w, h)
        autoPip = call.argument<Boolean>("autoPip") ?: false
        playing = call.argument<Boolean>("playing") ?: false
        if (pipSupported) {
          try {
            activity.setPictureInPictureParams(params())
          } catch (e: Exception) {
            // Some devices refuse params while not visible.
          }
        }
        result.success(null)
      }
      "enterPip" -> {
        if (!pipSupported) {
          result.success(false)
          return
        }
        result.success(
          try {
            activity.enterPictureInPictureMode(params())
          } catch (e: Exception) {
            false
          },
        )
      }
      "setOrientation" -> {
        activity.requestedOrientation = when (call.argument<String>("mode")) {
          "landscape" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
          "portrait" -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
          else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun params(): PictureInPictureParams {
    val builder = PictureInPictureParams.Builder().setAspectRatio(aspect)
    val icon = if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
    val intent = PendingIntent.getBroadcast(
      activity,
      1,
      Intent(ACTION_TOGGLE).setPackage(activity.packageName),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val label = if (playing) "Pause" else "Lecture"
    builder.setActions(listOf(RemoteAction(Icon.createWithResource(activity, icon), label, label, intent)))
    if (Build.VERSION.SDK_INT >= 31) {
      builder.setAutoEnterEnabled(autoPip)
      builder.setSeamlessResizeEnabled(true)
    }
    return builder.build()
  }

  /** Android accepts ratios between 1:2.39 and 2.39:1. */
  private fun clampAspect(w: Int, h: Int): Rational {
    if (w <= 0 || h <= 0) return Rational(16, 9)
    val r = w.toDouble() / h
    return when {
      r > 2.39 -> Rational(239, 100)
      r < 1 / 2.39 -> Rational(100, 239)
      else -> Rational(w, h)
    }
  }

  /** Before Android 12 there is no auto-enter: leaving the app does it. */
  fun onUserLeaveHint() {
    if (Build.VERSION.SDK_INT in 26..30 && autoPip && pipSupported) {
      try {
        activity.enterPictureInPictureMode(params())
      } catch (e: Exception) {
        // Not allowed now.
      }
    }
  }

  fun onPipChanged(inPip: Boolean) {
    channel.invokeMethod("pip", inPip)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    try {
      activity.unregisterReceiver(receiver)
    } catch (e: Exception) {
      // Already gone.
    }
  }

  companion object {
    private const val ACTION_TOGGLE = "org.miarina.media.PIP_TOGGLE"
  }
}
