package org.miarina.media

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.content.ContextCompat
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.VideoSize
import androidx.media3.common.text.CueGroup
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

/**
 * Android side of the Dart MediaEngine contract (Media3Engine). The player
 * lives in PlaybackService; this class drives it through a MediaController,
 * renders the picture into a Flutter texture and pushes full state snapshots
 * on an event channel, throttled to [POSITION_INTERVAL_MS] while playing.
 */
class Media3EnginePlugin(
  private val context: Context,
  messenger: BinaryMessenger,
  private val textures: TextureRegistry,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  private val methods = MethodChannel(messenger, "org.miarina.media/engine")
  private val events = EventChannel(messenger, "org.miarina.media/engine/events")
  private val main = Handler(Looper.getMainLooper())
  private var sink: EventChannel.EventSink? = null
  private var controllerFuture: ListenableFuture<MediaController>? = null
  private var controller: MediaController? = null
  private var producer: TextureRegistry.SurfaceProducer? = null
  private var error: Map<String, Any?>? = null
  private var cues: List<String> = emptyList()

  init {
    methods.setMethodCallHandler(this)
    events.setStreamHandler(this)
  }

  /** The picture-in-picture window's play / pause button. */
  fun togglePlay() {
    controller?.let { if (it.isPlaying) it.pause() else it.play() }
  }

  private val ticker = object : Runnable {
    override fun run() {
      push()
      if (controller?.isPlaying == true) main.postDelayed(this, POSITION_INTERVAL_MS)
    }
  }

  private val listener = object : Player.Listener {
    override fun onPlayerError(e: PlaybackException) {
      error = mapOf("message" to (e.message ?: e.errorCodeName), "code" to e.errorCodeName, "recoverable" to false)
    }

    override fun onCues(cueGroup: CueGroup) {
      cues = cueGroup.cues.mapNotNull { it.text?.toString() }
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
      if (videoSize.width > 0 && videoSize.height > 0) producer?.setSize(videoSize.width, videoSize.height)
    }

    override fun onEvents(player: Player, events: Player.Events) {
      push()
      main.removeCallbacks(ticker)
      if (player.isPlaying) main.postDelayed(ticker, POSITION_INTERVAL_MS)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    sink = events
    push()
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  private fun withController(result: MethodChannel.Result, block: (MediaController) -> Unit) {
    controller?.let {
      block(it)
      return
    }
    val future = controllerFuture ?: MediaController.Builder(
      context,
      SessionToken(context, ComponentName(context, PlaybackService::class.java)),
    ).buildAsync().also { controllerFuture = it }
    future.addListener({
      try {
        val connected = future.get()
        if (controller == null) {
          controller = connected
          connected.addListener(listener)
          producer?.let { connected.setVideoSurface(it.surface) }
        }
        block(connected)
      } catch (e: Exception) {
        controllerFuture = null
        result.error("service_unavailable", e.message, null)
      }
    }, ContextCompat.getMainExecutor(context))
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "texture" -> result.success(texture())
      "setEqualizer" -> {
        val gains = call.argument<List<Double>>("gains")
        MiarinaEqualizer.set(gains != null, gains ?: emptyList())
        // null until the service has a player session: the setting is kept
        // and applied when it attaches.
        result.success(MiarinaEqualizer.supported)
      }
      // Focus: silences skipped by ExoPlayer itself (same process), kept for
      // the player the service creates next.
      "setSkipSilence" -> {
        val on = call.argument<Boolean>("on") == true
        PlaybackService.skipSilence = on
        PlaybackService.current?.skipSilenceEnabled = on
        result.success(null)
      }
      "dispose" -> {
        dispose()
        result.success(null)
      }
      else -> withController(result) { c ->
        try {
          handle(c, call, result)
        } catch (e: IllegalArgumentException) {
          result.error("bad_argument", e.message, null)
        }
      }
    }
  }

  private fun handle(c: MediaController, call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "open" -> {
        val uri = call.argument<String>("uri") ?: throw IllegalArgumentException("uri")
        val item = MediaItem.Builder()
          .setMediaId(uri)
          .setUri(parseUri(uri))
          .setMediaMetadata(MediaMetadata.Builder().setTitle(call.argument<String>("title")).build())
          .build()
        error = null
        cues = emptyList()
        c.setMediaItem(item, (call.argument<Number>("startMs") ?: 0).toLong())
        c.prepare()
        c.playWhenReady = call.argument<Boolean>("autoplay") ?: true
      }
      "prepareNext" -> {
        // Gapless: the next file waits after the current one in Media3's
        // own list (only those two), and plays right after it. The item id
        // tells Dart when it started.
        val index = c.currentMediaItemIndex
        if (c.mediaItemCount > index + 1) c.removeMediaItems(index + 1, c.mediaItemCount)
        if (index > 0) c.removeMediaItems(0, index)
        val uri = call.argument<String>("uri")
        if (uri != null && c.mediaItemCount > 0) {
          c.addMediaItem(
            MediaItem.Builder()
              .setMediaId(uri)
              .setUri(parseUri(uri))
              .setMediaMetadata(MediaMetadata.Builder().setTitle(call.argument<String>("title")).build())
              .build(),
          )
        }
      }
      "play" -> {
        if (c.playbackState == Player.STATE_ENDED) c.seekTo(0)
        c.play()
      }
      "pause" -> c.pause()
      "stop" -> {
        c.stop()
        c.clearMediaItems()
        error = null
        cues = emptyList()
      }
      "seek" -> c.seekTo((call.argument<Number>("ms") ?: 0).toLong().coerceAtLeast(0))
      "setVolume" -> c.volume = (call.argument<Number>("value") ?: 1).toFloat().coerceIn(0f, 1f)
      "setSpeed" -> c.playbackParameters = PlaybackParameters((call.argument<Number>("value") ?: 1).toFloat().coerceIn(0.25f, 4f))
      "setRepeat" -> c.repeatMode = when (call.argument<String>("mode")) {
        "one" -> Player.REPEAT_MODE_ONE
        "all" -> Player.REPEAT_MODE_ALL
        else -> Player.REPEAT_MODE_OFF
      }
      "selectTrack" -> {
        val type = if (call.argument<String>("kind") == "text") C.TRACK_TYPE_TEXT else C.TRACK_TYPE_AUDIO
        selectTrack(c, type, call.argument<String>("id"))
      }
      "setSubtitlesEnabled" -> c.trackSelectionParameters = c.trackSelectionParameters.buildUpon()
        .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, call.argument<Boolean>("enabled") != true)
        .build()
      "loadSubtitle" -> loadSubtitle(call.argument<String>("uri") ?: throw IllegalArgumentException("uri"))
      // Settings › Playback: preferred subtitle language, none when null.
      "setPreferredSubtitle" -> c.trackSelectionParameters = c.trackSelectionParameters.buildUpon()
        .setPreferredTextLanguage(call.argument<String>("language"))
        .build()
      else -> return result.notImplemented()
    }
    result.success(null)
    push()
  }

  private fun parseUri(value: String): Uri =
    if (value.startsWith("content://") || value.startsWith("file://")) Uri.parse(value) else Uri.fromFile(File(value))

  private fun texture(): Long {
    producer?.let { return it.id() }
    val created = textures.createSurfaceProducer()
    created.setSize(1280, 720)
    created.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
      override fun onSurfaceAvailable() {
        controller?.setVideoSurface(created.surface)
      }

      override fun onSurfaceCleanup() {
        controller?.clearVideoSurface()
      }
    })
    producer = created
    controller?.setVideoSurface(created.surface)
    return created.id()
  }

  private fun selectTrack(c: MediaController, type: Int, id: String?) {
    val builder = c.trackSelectionParameters.buildUpon()
    if (id == null) {
      require(type == C.TRACK_TYPE_TEXT) { "an audio track is required" }
      builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
    } else {
      val parts = id.split(':').mapNotNull { it.toIntOrNull() }
      val group = parts.getOrNull(0)?.let { c.currentTracks.groups.getOrNull(it) }
      val track = parts.getOrNull(1)
      require(group != null && track != null && group.type == type && track in 0 until group.length) {
        "track $id is no longer available"
      }
      builder.setTrackTypeDisabled(type, false)
      builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, track))
    }
    c.trackSelectionParameters = builder.build()
  }

  private fun loadSubtitle(value: String) {
    val uri = parseUri(value)
    val name = displayName(uri)
    val head = try {
      context.contentResolver.openInputStream(uri)?.use { stream ->
        val buffer = ByteArray(4096)
        val n = stream.read(buffer)
        if (n > 0) String(buffer, 0, n, Charsets.UTF_8) else ""
      } ?: ""
    } catch (e: Exception) {
      throw IllegalArgumentException("unreadable subtitle file: ${e.javaClass.simpleName}")
    }
    val ext = name.substringAfterLast('.', "").lowercase()
    val mime = when {
      head.removePrefix(BOM).trimStart().startsWith("WEBVTT") -> MimeTypes.TEXT_VTT
      head.contains("[Script Info]") || ext == "ass" || ext == "ssa" -> MimeTypes.TEXT_SSA
      SRT_TIMING.containsMatchIn(head) -> MimeTypes.APPLICATION_SUBRIP
      else -> throw IllegalArgumentException("unsupported subtitle format")
    }
    // Directly on the service's player: a replaced item's subtitle
    // configuration does not reach the session through the controller.
    val player = PlaybackService.current ?: throw IllegalArgumentException("nothing is playing")
    val item = player.currentMediaItem ?: throw IllegalArgumentException("nothing is playing")
    val config = MediaItem.SubtitleConfiguration.Builder(uri)
      .setMimeType(mime)
      .setLabel(name)
      .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
      .build()
    val existing = item.localConfiguration?.subtitleConfigurations ?: emptyList()
    val position = player.currentPosition
    val playing = player.playWhenReady
    // replaceMediaItem() keeps the loaded source when the URI does not change,
    // so the subtitle would be ignored: insert the new item after the current
    // one, move to it at the same position, then drop the old one.
    val index = player.currentMediaItemIndex
    player.addMediaItem(index + 1, item.buildUpon().setSubtitleConfigurations(existing + config).build())
    player.seekTo(index + 1, position)
    player.removeMediaItem(index)
    player.playWhenReady = playing
    player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
      .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
      .build()
  }

  private fun displayName(uri: Uri): String =
    if (uri.scheme == "content") {
      context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { if (it.moveToFirst()) it.getString(0) else null } ?: (uri.lastPathSegment ?: "")
    } else {
      uri.lastPathSegment ?: ""
    }

  private fun push() {
    val s = sink ?: return
    s.success(snapshot())
  }

  private fun snapshot(): Map<String, Any?> {
    val c = controller ?: return mapOf("status" to "idle")
    val audio = mutableListOf<Map<String, Any?>>()
    val text = mutableListOf<Map<String, Any?>>()
    var selectedAudio: String? = null
    var selectedText: String? = null
    c.currentTracks.groups.forEachIndexed { gi, group ->
      if (group.type != C.TRACK_TYPE_AUDIO && group.type != C.TRACK_TYPE_TEXT) return@forEachIndexed
      for (ti in 0 until group.length) {
        if (!group.isTrackSupported(ti)) continue
        val f = group.getTrackFormat(ti)
        val id = "$gi:$ti"
        val entry = mapOf(
          "id" to id,
          "title" to f.label,
          "language" to f.language,
          "codec" to codecName(f),
        )
        if (group.type == C.TRACK_TYPE_AUDIO) {
          audio += entry
          if (group.isTrackSelected(ti)) selectedAudio = id
        } else {
          text += entry
          if (group.isTrackSelected(ti)) selectedText = id
        }
      }
    }
    val duration = c.duration.takeIf { it != C.TIME_UNSET && it > 0 } ?: 0L
    // videoSize stays 0x0 until frames reach a surface; the track format tells
    // Flutter there is a picture so it can attach the texture in the first place.
    val video = c.videoSize.takeIf { it.width > 0 && it.height > 0 } ?: videoTrackSize(c)
    val status = when {
      error != null -> "error"
      c.mediaItemCount == 0 -> "idle"
      c.playbackState == Player.STATE_ENDED -> "ended"
      c.playbackState == Player.STATE_IDLE || (c.playbackState == Player.STATE_BUFFERING && duration == 0L) -> "loading"
      c.playWhenReady -> "playing"
      else -> "paused"
    }
    return mapOf(
      "status" to status,
      "item" to c.currentMediaItem?.mediaId,
      "positionMs" to c.currentPosition,
      "durationMs" to duration,
      "buffering" to (c.playbackState == Player.STATE_BUFFERING),
      "volume" to c.volume.toDouble(),
      "speed" to c.playbackParameters.speed.toDouble(),
      "repeat" to when (c.repeatMode) {
        Player.REPEAT_MODE_ONE -> "one"
        Player.REPEAT_MODE_ALL -> "all"
        else -> "off"
      },
      "audioTracks" to audio,
      "subtitleTracks" to text,
      "selectedAudio" to selectedAudio,
      "selectedSubtitle" to selectedText,
      "subtitlesEnabled" to !c.trackSelectionParameters.disabledTrackTypes.contains(C.TRACK_TYPE_TEXT),
      "videoWidth" to video.width,
      "videoHeight" to video.height,
      "cues" to cues,
      "error" to error,
    )
  }

  private fun videoTrackSize(c: MediaController): VideoSize {
    for (group in c.currentTracks.groups) {
      if (group.type != C.TRACK_TYPE_VIDEO) continue
      for (ti in 0 until group.length) {
        if (!group.isTrackSelected(ti)) continue
        val f = group.getTrackFormat(ti)
        if (f.width <= 0 || f.height <= 0) continue
        val quarterTurn = f.rotationDegrees == 90 || f.rotationDegrees == 270
        return if (quarterTurn) VideoSize(f.height, f.width) else VideoSize(f.width, f.height)
      }
    }
    return VideoSize.UNKNOWN
  }

  private fun codecName(f: Format): String? = when (f.sampleMimeType) {
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
    // Sideloaded files are parsed during extraction: no useful codec name.
    MimeTypes.APPLICATION_MEDIA3_CUES -> null
    else -> f.sampleMimeType?.substringAfter('/')?.uppercase()
  }

  fun dispose() {
    main.removeCallbacks(ticker)
    controller?.removeListener(listener)
    controller?.clearVideoSurface()
    controllerFuture?.let { MediaController.releaseFuture(it) }
    controllerFuture = null
    controller = null
    producer?.release()
    producer = null
  }

  companion object {
    private const val POSITION_INTERVAL_MS = 250L
    private const val BOM = "﻿"
    private val SRT_TIMING = Regex("""\d{1,2}:\d{2}:\d{2}[,.]\d{3}\s*-->""")
  }
}
