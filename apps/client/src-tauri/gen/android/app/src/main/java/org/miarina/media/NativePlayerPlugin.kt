package org.miarina.media

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import java.io.File

@InvokeArg
class OpenArgs {
  lateinit var path: String
  var positionMs: Long = 0
  var video: Boolean = false
}

@InvokeArg
class SeekArgs {
  var positionMs: Long = 0
}

@InvokeArg
class RateArgs {
  var rate: Float = 1f
}

/** Video area in CSS pixels, relative to the WebView viewport. */
@InvokeArg
class SurfaceArgs {
  var x: Double = 0.0
  var y: Double = 0.0
  var width: Double = 0.0
  var height: Double = 0.0
  var visible: Boolean = false
}

/**
 * Native playback (Media3 ExoPlayer) driven by the React player screen.
 *
 * The WebView cannot stream local files on Android (asset protocol, see
 * docs/spikes/android-emulator.md), so the approved player UI stays in React
 * and only decoding moves here. Video frames are drawn by a PlayerView placed
 * over the screen's "video surface" area. Paths are resolved by Rust from the
 * library (never taken from the page). Commands run on the main thread,
 * which is also ExoPlayer's application thread.
 */
@TauriPlugin
class NativePlayerPlugin(private val activity: Activity) : Plugin(activity) {
  private var webView: WebView? = null
  private var player: ExoPlayer? = null
  private var surface: PlayerView? = null
  private var video = false
  private var error: String? = null

  override fun load(webView: WebView) {
    this.webView = webView
  }

  @Command
  fun open(invoke: Invoke) {
    val args = invoke.parseArgs(OpenArgs::class.java)
    release()
    val uri = if (args.path.startsWith("content://")) Uri.parse(args.path) else Uri.fromFile(File(args.path))
    val exo = ExoPlayer.Builder(activity).build()
    exo.setAudioAttributes(
      AudioAttributes.Builder()
        .setUsage(C.USAGE_MEDIA)
        .setContentType(if (args.video) C.AUDIO_CONTENT_TYPE_MOVIE else C.AUDIO_CONTENT_TYPE_MUSIC)
        .build(),
      /* handleAudioFocus = */ true,
    )
    // Unplugging headphones pauses instead of playing out loud.
    exo.setHandleAudioBecomingNoisy(true)
    exo.addListener(object : Player.Listener {
      override fun onPlayerError(e: PlaybackException) {
        error = e.errorCodeName
      }
    })
    exo.setMediaItem(MediaItem.fromUri(uri), args.positionMs.coerceAtLeast(0))
    exo.prepare()
    exo.playWhenReady = true
    player = exo
    video = args.video
    error = null
    invoke.resolve()
  }

  @Command
  fun status(invoke: Invoke) {
    val exo = player
    val result = JSObject()
    if (exo == null) {
      result.put("open", false)
    } else {
      result.put("open", true)
      result.put("positionMs", exo.currentPosition)
      result.put("durationMs", if (exo.duration == C.TIME_UNSET) -1 else exo.duration)
      result.put("bufferedMs", exo.bufferedPosition)
      result.put("playing", exo.isPlaying)
      result.put("ended", exo.playbackState == Player.STATE_ENDED)
      result.put("rate", exo.playbackParameters.speed.toDouble())
      error?.let { result.put("error", it) }
    }
    invoke.resolve(result)
  }

  @Command
  fun play(invoke: Invoke) {
    player?.let {
      if (it.playbackState == Player.STATE_ENDED) it.seekTo(0)
      it.play()
    }
    invoke.resolve()
  }

  @Command
  fun pause(invoke: Invoke) {
    player?.pause()
    invoke.resolve()
  }

  @Command
  fun seek(invoke: Invoke) {
    val args = invoke.parseArgs(SeekArgs::class.java)
    player?.seekTo(args.positionMs.coerceAtLeast(0))
    invoke.resolve()
  }

  @Command
  fun setRate(invoke: Invoke) {
    val args = invoke.parseArgs(RateArgs::class.java)
    player?.playbackParameters = PlaybackParameters(args.rate)
    invoke.resolve()
  }

  @Command
  fun setSurface(invoke: Invoke) {
    val args = invoke.parseArgs(SurfaceArgs::class.java)
    val exo = player
    if (exo == null || !video || !args.visible || args.width <= 0 || args.height <= 0) {
      surface?.visibility = View.GONE
      invoke.resolve()
      return
    }
    val web = webView
    val container = web?.parent as? ViewGroup
    if (web == null || container == null) {
      invoke.reject("The page view is not ready")
      return
    }
    val view = surface ?: PlayerView(activity).also {
      it.useController = false
      it.setShutterBackgroundColor(Color.BLACK)
      it.setBackgroundColor(Color.BLACK)
      // Above the WebView, which is drawn in the same window.
      (it.videoSurfaceView as? SurfaceView)?.setZOrderMediaOverlay(true)
      container.addView(it)
      surface = it
    }
    view.player = exo
    // CSS pixels are density-independent pixels in the WebView. Positioned
    // from the WebView's own place in the shared parent, so insets and
    // padding applied to the parent are already accounted for.
    val density = activity.resources.displayMetrics.density
    // Keep the parameters the container created (its own type), size only.
    view.layoutParams = view.layoutParams.also {
      it.width = (args.width * density).toInt()
      it.height = (args.height * density).toInt()
    }
    // A FrameLayout child sits at the parent's padding corner; the offset is
    // a translation from there (setX/setY would depend on layout timing).
    view.translationX = web.left - container.paddingLeft + args.x.toFloat() * density
    view.translationY = web.top - container.paddingTop + args.y.toFloat() * density
    view.visibility = View.VISIBLE
    invoke.resolve()
  }

  @Command
  fun close(invoke: Invoke) {
    val result = JSObject()
    player?.let {
      result.put("positionMs", it.currentPosition)
      result.put("durationMs", if (it.duration == C.TIME_UNSET) -1 else it.duration)
    }
    release()
    invoke.resolve(result)
  }

  /** Video stops when the app leaves the screen; audio keeps playing. */
  override fun onPause() {
    if (video) player?.pause()
  }

  override fun onDestroy() {
    release()
  }

  private fun release() {
    surface?.let {
      it.player = null
      (it.parent as? ViewGroup)?.removeView(it)
    }
    surface = null
    player?.release()
    player = null
    error = null
  }
}
