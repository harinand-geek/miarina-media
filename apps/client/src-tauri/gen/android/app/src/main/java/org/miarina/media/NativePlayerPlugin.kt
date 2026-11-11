package org.miarina.media

import android.app.Activity
import android.content.ComponentName
import android.graphics.Color
import android.net.Uri
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.core.content.ContextCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.media3.ui.PlayerView
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import com.google.common.util.concurrent.ListenableFuture
import java.io.File

/** One queue entry, resolved by Rust from the library (never a page path). */
@InvokeArg
class QueueItem {
  var id: Long = 0
  var path: String = ""
  var title: String = ""
  var artist: String? = null
  var album: String? = null
  var artwork: String? = null
  var video: Boolean = false
}

@InvokeArg
class OpenArgs {
  var items: Array<QueueItem> = arrayOf()
  var startIndex: Int = 0
  var positionMs: Long = 0
}

@InvokeArg
class QueueArgs {
  var items: Array<QueueItem> = arrayOf()
  var currentIndex: Int = 0
}

@InvokeArg
class SkipArgs {
  var index: Int = 0
}

@InvokeArg
class RepeatArgs {
  var mode: String = "off"
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
 * Native playback controller for the React player screens.
 *
 * The player itself lives in [PlaybackService] (MediaSessionService), so it
 * keeps playing with the screen off and shows the system media controls;
 * this plugin talks to it through a MediaController. The WebView cannot
 * stream local files on Android (docs/spikes/android-emulator.md): React
 * keeps the approved UI, decoding happens here. Video frames are drawn by a
 * PlayerView placed over the screen's "video surface" area. Commands run on
 * the main thread, the controller's application thread.
 */
@TauriPlugin
class NativePlayerPlugin(private val activity: Activity) : Plugin(activity) {
  private var webView: WebView? = null
  private var controllerFuture: ListenableFuture<MediaController>? = null
  private var controller: MediaController? = null
  private var surface: PlayerView? = null
  private var error: String? = null

  private val listener = object : Player.Listener {
    override fun onPlayerError(e: PlaybackException) {
      error = e.errorCodeName
    }

    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
      error = null
      // A track change can switch between audio and video.
      if (!currentIsVideo()) surface?.visibility = View.GONE
    }
  }

  override fun load(webView: WebView) {
    this.webView = webView
  }

  /** Runs [block] once the service is connected (the first call starts it). */
  private fun withController(invoke: Invoke, block: (MediaController) -> Unit) {
    controller?.let {
      block(it)
      return
    }
    val future = controllerFuture ?: MediaController.Builder(
      activity,
      SessionToken(activity, ComponentName(activity, PlaybackService::class.java)),
    ).buildAsync().also { controllerFuture = it }
    future.addListener({
      try {
        val connected = future.get()
        if (controller == null) {
          controller = connected
          connected.addListener(listener)
        }
        block(connected)
      } catch (e: Exception) {
        controllerFuture = null
        invoke.reject("The playback service is unavailable: ${e.message}")
      }
    }, ContextCompat.getMainExecutor(activity))
  }

  private fun mediaItem(item: QueueItem): MediaItem {
    val uri = if (item.path.startsWith("content://")) Uri.parse(item.path) else Uri.fromFile(File(item.path))
    val metadata = MediaMetadata.Builder()
      .setTitle(item.title)
      .setArtist(item.artist)
      .setAlbumTitle(item.album)
      .setArtworkUri(item.artwork?.let { Uri.fromFile(File(it)) })
      .setMediaType(if (item.video) MediaMetadata.MEDIA_TYPE_VIDEO else MediaMetadata.MEDIA_TYPE_MUSIC)
      .build()
    return MediaItem.Builder()
      .setMediaId(item.id.toString())
      .setUri(uri)
      .setMediaMetadata(metadata)
      .build()
  }

  private fun currentIsVideo(): Boolean =
    controller?.currentMediaItem?.mediaMetadata?.mediaType == MediaMetadata.MEDIA_TYPE_VIDEO

  @Command
  fun open(invoke: Invoke) {
    val args = invoke.parseArgs(OpenArgs::class.java)
    if (args.items.isEmpty()) {
      invoke.reject("Nothing to play")
      return
    }
    withController(invoke) { c ->
      val start = args.startIndex.coerceIn(0, args.items.size - 1)
      c.setMediaItems(args.items.map(::mediaItem), start, args.positionMs.coerceAtLeast(0))
      c.prepare()
      c.play()
      error = null
      invoke.resolve()
    }
  }

  /**
   * Replaces the rest of the queue around the current item (reorder, remove,
   * shuffle) without interrupting it. `items[currentIndex]` is the current one.
   */
  @Command
  fun setQueue(invoke: Invoke) {
    val args = invoke.parseArgs(QueueArgs::class.java)
    val c = controller
    if (c == null || c.mediaItemCount == 0 || args.items.isEmpty()) {
      invoke.resolve()
      return
    }
    val keep = c.currentMediaItemIndex
    val at = args.currentIndex.coerceIn(0, args.items.size - 1)
    if (keep + 1 < c.mediaItemCount) c.removeMediaItems(keep + 1, c.mediaItemCount)
    if (keep > 0) c.removeMediaItems(0, keep)
    val items = args.items.map(::mediaItem)
    if (at > 0) c.addMediaItems(0, items.subList(0, at))
    if (at + 1 < items.size) c.addMediaItems(items.subList(at + 1, items.size))
    invoke.resolve()
  }

  @Command
  fun skip(invoke: Invoke) {
    val args = invoke.parseArgs(SkipArgs::class.java)
    val c = controller
    if (c != null && args.index in 0 until c.mediaItemCount) {
      c.seekToDefaultPosition(args.index)
      c.play()
    }
    invoke.resolve()
  }

  @Command
  fun setRepeat(invoke: Invoke) {
    val args = invoke.parseArgs(RepeatArgs::class.java)
    controller?.repeatMode = when (args.mode) {
      "all" -> Player.REPEAT_MODE_ALL
      "one" -> Player.REPEAT_MODE_ONE
      else -> Player.REPEAT_MODE_OFF
    }
    invoke.resolve()
  }

  /**
   * Connects to the service if needed: after the app is reopened, music the
   * service is still playing shows up here (CDC AND-05).
   */
  @Command
  fun status(invoke: Invoke) {
    withController(invoke) { c -> invoke.resolve(statusOf(c)) }
  }

  private fun statusOf(c: MediaController): JSObject {
    val result = JSObject()
    if (c.mediaItemCount == 0) {
      result.put("open", false)
    } else {
      result.put("open", true)
      result.put("positionMs", c.currentPosition)
      result.put("durationMs", if (c.duration == C.TIME_UNSET) -1 else c.duration)
      result.put("bufferedMs", c.bufferedPosition)
      result.put("playing", c.isPlaying)
      result.put("ended", c.playbackState == Player.STATE_ENDED)
      result.put("rate", c.playbackParameters.speed.toDouble())
      result.put("index", c.currentMediaItemIndex)
      c.currentMediaItem?.mediaId?.toLongOrNull()?.let { result.put("mediaId", it) }
      error?.let { result.put("error", it) }
    }
    return result
  }

  @Command
  fun play(invoke: Invoke) {
    controller?.let {
      if (it.playbackState == Player.STATE_ENDED) it.seekToDefaultPosition(it.currentMediaItemIndex)
      it.play()
    }
    invoke.resolve()
  }

  @Command
  fun pause(invoke: Invoke) {
    controller?.pause()
    invoke.resolve()
  }

  @Command
  fun seek(invoke: Invoke) {
    val args = invoke.parseArgs(SeekArgs::class.java)
    controller?.seekTo(args.positionMs.coerceAtLeast(0))
    invoke.resolve()
  }

  @Command
  fun setRate(invoke: Invoke) {
    val args = invoke.parseArgs(RateArgs::class.java)
    controller?.playbackParameters = PlaybackParameters(args.rate)
    invoke.resolve()
  }

  @Command
  fun setSurface(invoke: Invoke) {
    val args = invoke.parseArgs(SurfaceArgs::class.java)
    val c = controller
    if (c == null || !currentIsVideo() || !args.visible || args.width <= 0 || args.height <= 0) {
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
    view.player = c
    // CSS pixels are density-independent pixels in the WebView, positioned
    // from the WebView's own place in the shared parent.
    val density = activity.resources.displayMetrics.density
    view.layoutParams = view.layoutParams.also {
      it.width = (args.width * density).toInt()
      it.height = (args.height * density).toInt()
    }
    view.translationX = web.left - container.paddingLeft + args.x.toFloat() * density
    view.translationY = web.top - container.paddingTop + args.y.toFloat() * density
    view.visibility = View.VISIBLE
    invoke.resolve()
  }

  /** Stops playback and empties the queue; the service then leaves the foreground. */
  @Command
  fun close(invoke: Invoke) {
    val result = JSObject()
    controller?.let {
      result.put("positionMs", it.currentPosition)
      result.put("durationMs", if (it.duration == C.TIME_UNSET) -1 else it.duration)
      it.stop()
      it.clearMediaItems()
    }
    hideSurface()
    error = null
    invoke.resolve(result)
  }

  /** Video stops when the app leaves the screen; audio keeps playing. */
  override fun onPause() {
    if (currentIsVideo()) controller?.pause()
  }

  override fun onDestroy() {
    hideSurface()
    controller?.removeListener(listener)
    controllerFuture?.let { MediaController.releaseFuture(it) }
    controllerFuture = null
    controller = null
  }

  private fun hideSurface() {
    surface?.let {
      it.player = null
      (it.parent as? ViewGroup)?.removeView(it)
    }
    surface = null
  }
}
