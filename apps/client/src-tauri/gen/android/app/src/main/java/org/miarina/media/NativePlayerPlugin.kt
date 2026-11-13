package org.miarina.media

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Rational
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.activity.result.ActivityResult
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.media3.ui.PlayerView
import app.tauri.annotation.ActivityCallback
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

@InvokeArg
class FullscreenArgs {
  var on: Boolean = false
  var landscape: Boolean = true
}

@InvokeArg
class SelectTrackArgs {
  var kind: String = "audio"
  /** "group:track" from [NativePlayerPlugin.tracks]; null turns subtitles off. */
  var id: String? = null
}

@InvokeArg
class LevelArgs {
  var kind: String = "volume"
  /** 0..1; null only reads the current level. */
  var value: Double? = null
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
  /** Screen 13: the picture fills the screen behind the transparent page. */
  private var fullscreen = false

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
    instance = this
  }

  /** Picture-in-picture entered or left (MainActivity): the page hides its controls. */
  fun onPictureInPicture(active: Boolean) {
    trigger("pip", JSObject().put("active", active))
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

  /** The video view, created once (TextureView, see mm_player_texture.xml). */
  private fun videoView(container: ViewGroup): PlayerView =
    surface ?: (LayoutInflater.from(activity)
      .inflate(R.layout.mm_player_texture, container, false) as PlayerView).also {
      // Subtitles as in the design: 20/600 on a dark rounded box.
      it.subtitleView?.setStyle(
        CaptionStyleCompat(
          Color.WHITE,
          Color.argb(166, 0, 0, 0),
          Color.TRANSPARENT,
          CaptionStyleCompat.EDGE_TYPE_NONE,
          Color.TRANSPARENT,
          null,
        ),
      )
      surface = it
    }

  /**
   * Portrait player: the view is drawn above the page in the given box.
   * Fullscreen: it fills the screen behind the transparent page.
   */
  private fun place(view: PlayerView, container: ViewGroup, web: WebView, args: SurfaceArgs?) {
    val behind = fullscreen
    val index = container.indexOfChild(view)
    val webIndex = container.indexOfChild(web)
    if (index < 0 || (behind && index > webIndex) || (!behind && index < webIndex)) {
      if (index >= 0) container.removeView(view)
      if (behind) container.addView(view, container.indexOfChild(web)) else container.addView(view)
    }
    if (behind) {
      view.layoutParams = view.layoutParams.also {
        it.width = ViewGroup.LayoutParams.MATCH_PARENT
        it.height = ViewGroup.LayoutParams.MATCH_PARENT
      }
      view.translationX = 0f
      view.translationY = 0f
    } else if (args != null) {
      // CSS pixels are density-independent pixels in the WebView, positioned
      // from the WebView's own place in the shared parent.
      val density = activity.resources.displayMetrics.density
      view.layoutParams = view.layoutParams.also {
        it.width = (args.width * density).toInt()
        it.height = (args.height * density).toInt()
      }
      view.translationX = web.left - container.paddingLeft + args.x.toFloat() * density
      view.translationY = web.top - container.paddingTop + args.y.toFloat() * density
    }
    web.setBackgroundColor(if (behind) Color.TRANSPARENT else ContextCompat.getColor(activity, R.color.mm_bg))
  }

  @Command
  fun setSurface(invoke: Invoke) {
    val args = invoke.parseArgs(SurfaceArgs::class.java)
    val c = controller
    val wanted = fullscreen || (args.visible && args.width > 0 && args.height > 0)
    // In fullscreen (and picture-in-picture, where the page reports itself
    // hidden) the picture stays: only leaving fullscreen hides it.
    if (c == null || !currentIsVideo() || !wanted) {
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
    val view = videoView(container)
    view.player = c
    place(view, container, web, args)
    view.visibility = View.VISIBLE
    invoke.resolve()
  }

  /** AND-07: immersive, landscape (or portrait) fullscreen; Back is the page's. */
  @Command
  fun setFullscreen(invoke: Invoke) {
    val args = invoke.parseArgs(FullscreenArgs::class.java)
    val window = activity.window
    val insets = WindowCompat.getInsetsController(window, window.decorView)
    fullscreen = args.on
    MainActivity.immersive = args.on
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      window.attributes = window.attributes.also {
        it.layoutInDisplayCutoutMode = if (args.on) {
          android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        } else {
          android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
        }
      }
    }
    activity.findViewById<View>(android.R.id.content)?.let { androidx.core.view.ViewCompat.requestApplyInsets(it) }
    if (args.on) {
      insets.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
      insets.hide(WindowInsetsCompat.Type.systemBars())
      activity.requestedOrientation = if (args.landscape) {
        ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
      } else {
        ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
      }
    } else {
      insets.show(WindowInsetsCompat.Type.systemBars())
      activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
      // Brightness set by the gesture only applies to the video.
      window.attributes = window.attributes.also { it.screenBrightness = -1f }
    }
    val web = webView
    val container = web?.parent as? ViewGroup
    val view = surface
    if (web != null && container != null && view != null) place(view, container, web, null)
    if (web != null && !args.on) web.setBackgroundColor(ContextCompat.getColor(activity, R.color.mm_bg))
    invoke.resolve()
  }

  private fun codecName(mime: String?): String? = when (mime) {
    MimeTypes.VIDEO_H264 -> "H.264"
    MimeTypes.VIDEO_H265 -> "H.265"
    MimeTypes.VIDEO_VP9 -> "VP9"
    MimeTypes.VIDEO_VP8 -> "VP8"
    MimeTypes.VIDEO_AV1 -> "AV1"
    MimeTypes.VIDEO_MP4V -> "MPEG-4"
    MimeTypes.AUDIO_AAC -> "AAC"
    MimeTypes.AUDIO_OPUS -> "Opus"
    MimeTypes.AUDIO_VORBIS -> "Vorbis"
    MimeTypes.AUDIO_MPEG -> "MP3"
    MimeTypes.AUDIO_FLAC -> "FLAC"
    MimeTypes.AUDIO_AC3 -> "AC-3"
    MimeTypes.AUDIO_E_AC3 -> "E-AC-3"
    MimeTypes.APPLICATION_SUBRIP -> "SRT"
    MimeTypes.TEXT_VTT -> "VTT"
    MimeTypes.TEXT_SSA -> "SSA"
    // Sideloaded files parsed during extraction: no useful codec name.
    MimeTypes.APPLICATION_MEDIA3_CUES -> null
    else -> mime?.substringAfter('/')?.uppercase()
  }

  private fun channels(n: Int): String? = when (n) {
    Format.NO_VALUE -> null
    1 -> "1.0"
    2 -> "2.0"
    6 -> "5.1"
    8 -> "7.1"
    else -> "$n ch"
  }

  /** AND-13: audio and subtitle tracks of the current file, plus a technical summary. */
  @Command
  fun tracks(invoke: Invoke) {
    val c = controller
    val result = JSObject()
    val audio = org.json.JSONArray()
    val text = org.json.JSONArray()
    var video: String? = null
    var sound: String? = null
    var textOn = false
    c?.currentTracks?.groups?.forEachIndexed { gi, group ->
      for (ti in 0 until group.length) {
        if (!group.isTrackSupported(ti)) continue
        val f = group.getTrackFormat(ti)
        val selected = group.isTrackSelected(ti)
        when (group.type) {
          C.TRACK_TYPE_VIDEO -> if (selected || video == null) {
            video = listOfNotNull(codecName(f.sampleMimeType), if (f.height > 0) "${f.height}p" else null)
              .joinToString(" ")
          }
          C.TRACK_TYPE_AUDIO -> {
            val codec = listOfNotNull(codecName(f.sampleMimeType), channels(f.channelCount)).joinToString(" ")
            if (selected) sound = codec
            audio.put(
              JSObject()
                .put("id", "$gi:$ti")
                .put("label", f.label ?: f.language)
                .put("language", f.language)
                .put("codec", codec)
                .put("selected", selected),
            )
          }
          C.TRACK_TYPE_TEXT -> {
            if (selected) textOn = true
            text.put(
              JSObject()
                .put("id", "$gi:$ti")
                .put("label", f.label ?: f.language)
                .put("language", f.language)
                .put("codec", codecName(f.sampleMimeType))
                .put("selected", selected),
            )
          }
        }
      }
    }
    result.put("audio", audio)
    result.put("text", text)
    result.put("textOff", !textOn)
    result.put("video", video)
    result.put("sound", sound)
    invoke.resolve(result)
  }

  @Command
  fun selectTrack(invoke: Invoke) {
    val args = invoke.parseArgs(SelectTrackArgs::class.java)
    val c = controller ?: return invoke.reject("Nothing is playing")
    val type = if (args.kind == "text") C.TRACK_TYPE_TEXT else C.TRACK_TYPE_AUDIO
    val builder = c.trackSelectionParameters.buildUpon()
    val id = args.id
    if (id == null) {
      if (type != C.TRACK_TYPE_TEXT) return invoke.reject("An audio track is required")
      builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
    } else {
      val parts = id.split(':').mapNotNull { it.toIntOrNull() }
      val group = parts.getOrNull(0)?.let { c.currentTracks.groups.getOrNull(it) }
      val track = parts.getOrNull(1)
      if (group == null || track == null || group.type != type || track !in 0 until group.length) {
        return invoke.reject("This track is no longer available")
      }
      builder.setTrackTypeDisabled(type, false)
      builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, track))
    }
    c.trackSelectionParameters = builder.build()
    invoke.resolve()
  }

  /** AND-13: a SRT or WebVTT file picked by the user, added to the current video. */
  @Command
  fun pickSubtitle(invoke: Invoke) {
    if (controller?.currentMediaItem == null) return invoke.reject("Nothing is playing")
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
      .addCategory(Intent.CATEGORY_OPENABLE)
      .setType("*/*")
    startActivityForResult(invoke, intent, "subtitlePicked")
  }

  @ActivityCallback
  fun subtitlePicked(invoke: Invoke, result: ActivityResult) {
    val uri = result.data?.data
    if (result.resultCode != Activity.RESULT_OK || uri == null) {
      invoke.resolve(JSObject().put("added", false))
      return
    }
    val name = activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
      ?.use { if (it.moveToFirst()) it.getString(0) else null }
      ?: uri.lastPathSegment
      ?: ""
    // The content decides (pickers do not always give the file name);
    // the document type and the name are the fallback.
    var readError: String? = null
    val head = try {
      activity.contentResolver.openInputStream(uri)?.use { stream ->
        val buffer = ByteArray(4096)
        val n = stream.read(buffer)
        if (n > 0) String(buffer, 0, n, Charsets.UTF_8) else ""
      } ?: ""
    } catch (e: Exception) {
      readError = e.javaClass.simpleName
      ""
    }
    val type = activity.contentResolver.getType(uri)
    val ext = name.substringAfterLast('.', "").lowercase()
    val mime = when {
      head.removePrefix(BOM).trimStart().startsWith("WEBVTT") -> MimeTypes.TEXT_VTT
      SRT_TIMING.containsMatchIn(head) -> MimeTypes.APPLICATION_SUBRIP
      head.isEmpty() && (ext == "vtt" || type == MimeTypes.TEXT_VTT) -> MimeTypes.TEXT_VTT
      head.isEmpty() && (ext == "srt" || type == MimeTypes.APPLICATION_SUBRIP) -> MimeTypes.APPLICATION_SUBRIP
      else -> return invoke.reject(
        "unsupported_subtitle (name=$name, type=$type, read=${head.length}, error=$readError)",
      )
    }
    // Directly on the service's player: the subtitle configuration of a
    // replaced item does not reach the session through the controller.
    val c = PlaybackService.current ?: return invoke.reject("Nothing is playing")
    val item = c.currentMediaItem ?: return invoke.reject("Nothing is playing")
    val config = MediaItem.SubtitleConfiguration.Builder(uri)
      .setMimeType(mime)
      .setLabel(name)
      .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
      .build()
    val existing = item.localConfiguration?.subtitleConfigurations ?: emptyList()
    val position = c.currentPosition
    val playing = c.playWhenReady
    // replaceMediaItem() keeps the loaded source when the URI does not change
    // (the subtitle would be ignored): the new item goes after the current
    // one, playback moves to it at the same position, the old one is removed.
    val index = c.currentMediaItemIndex
    c.addMediaItem(index + 1, item.buildUpon().setSubtitleConfigurations(existing + config).build())
    c.seekTo(index + 1, position)
    c.removeMediaItem(index)
    c.playWhenReady = playing
    c.trackSelectionParameters = c.trackSelectionParameters.buildUpon()
      .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
      .build()
    invoke.resolve(JSObject().put("added", true).put("name", name))
  }

  /** AND-14 gestures: screen brightness (this window only) or media volume, 0..1. */
  @Command
  fun level(invoke: Invoke) {
    val args = invoke.parseArgs(LevelArgs::class.java)
    val value = args.value?.coerceIn(0.0, 1.0)
    if (args.kind == "brightness") {
      val window = activity.window
      if (value != null) {
        window.attributes = window.attributes.also { it.screenBrightness = value.toFloat().coerceAtLeast(0.01f) }
      }
      var current = window.attributes.screenBrightness
      if (current < 0f) {
        current = android.provider.Settings.System.getInt(
          activity.contentResolver,
          android.provider.Settings.System.SCREEN_BRIGHTNESS,
          128,
        ) / 255f
      }
      invoke.resolve(JSObject().put("value", current.toDouble()))
      return
    }
    val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
    if (value != null) {
      audio.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(value * max).toInt(), 0)
    }
    invoke.resolve(JSObject().put("value", audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max))
  }

  /** AND-08: picture-in-picture when the device supports it (Android 8+). */
  @Command
  fun enterPip(invoke: Invoke) {
    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
      activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    if (!supported || !currentIsVideo()) {
      invoke.resolve(JSObject().put("entered", false))
      return
    }
    val size = controller?.videoSize
    val ratio = if (size != null && size.width > 0 && size.height > 0) {
      (size.width.toFloat() / size.height).coerceIn(1 / 2.39f, 2.39f)
    } else {
      16f / 9f
    }
    val params = PictureInPictureParams.Builder()
      .setAspectRatio(Rational((ratio * 1000).toInt(), 1000))
      .build()
    invoke.resolve(JSObject().put("entered", activity.enterPictureInPictureMode(params)))
  }

  /** Whether picture-in-picture can be offered at all. */
  @Command
  fun pipSupported(invoke: Invoke) {
    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
      activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    invoke.resolve(JSObject().put("supported", supported))
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

  /** Video stops when the app leaves the screen (not for picture-in-picture); audio keeps playing. */
  override fun onPause() {
    val pip = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity.isInPictureInPictureMode
    if (currentIsVideo() && !pip) controller?.pause()
  }

  override fun onDestroy() {
    if (instance === this) instance = null
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

  companion object {
    /** "00:00:01,000 --> 00:00:04,000": a SubRip cue. */
    private val SRT_TIMING = Regex("""\d{1,2}:\d{2}:\d{2},\d{3}\s*-->""")

    /** Byte order mark that may precede "WEBVTT". */
    private const val BOM = "\uFEFF"

    /** For MainActivity's picture-in-picture callback. */
    var instance: NativePlayerPlugin? = null
  }
}
