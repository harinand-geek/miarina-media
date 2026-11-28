package org.miarina.media

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/**
 * Android Auto and other media browsers (decision 0013, proposal 11): a
 * few lists to browse (the day's mix, favourites, recently played, all
 * titles) and play from. Flutter writes them to a file (AutoChannel), so
 * they are there with the app closed; the player service reads it.
 * Items the app itself sends (with their URI) pass through unchanged.
 */
class AutoLibrary(private val context: Context) : MediaLibraryService.MediaLibrarySession.Callback {

  private class Track(
    val id: String,
    val title: String,
    val artist: String?,
    val album: String?,
    val path: String,
  )

  private class Section(val id: String, val title: String, val tracks: List<Track>)

  private var cachedAt = -1L
  private var cached: List<Section> = emptyList()

  private fun sections(): List<Section> {
    val file = File(context.filesDir, FILE)
    if (!file.isFile) return emptyList()
    if (file.lastModified() == cachedAt) return cached
    cached = try {
      val json = JSONObject(file.readText())
      val list = json.getJSONArray("sections")
      (0 until list.length()).map { i ->
        val s = list.getJSONObject(i)
        val items = s.getJSONArray("items")
        Section(
          s.getString("id"),
          s.getString("title"),
          (0 until items.length()).map { j ->
            val t = items.getJSONObject(j)
            Track(
              t.getString("id"),
              t.getString("title"),
              t.optString("artist").ifEmpty { null },
              t.optString("album").ifEmpty { null },
              t.getString("path"),
            )
          },
        )
      }
    } catch (_: Exception) {
      emptyList()
    }
    cachedAt = file.lastModified()
    return cached
  }

  private fun folder(id: String, title: String): MediaItem = MediaItem.Builder()
    .setMediaId(id)
    .setMediaMetadata(
      MediaMetadata.Builder()
        .setTitle(title)
        .setIsBrowsable(true)
        .setIsPlayable(false)
        .setMediaType(MediaMetadata.MEDIA_TYPE_FOLDER_MIXED)
        .build(),
    )
    .build()

  private fun item(section: Section, t: Track): MediaItem = MediaItem.Builder()
    .setMediaId("$TRACK${section.id}:${t.id}")
    .setUri(uriOf(t.path))
    .setMediaMetadata(
      MediaMetadata.Builder()
        .setTitle(t.title)
        .setArtist(t.artist)
        .setAlbumTitle(t.album)
        .setIsBrowsable(false)
        .setIsPlayable(true)
        .setMediaType(MediaMetadata.MEDIA_TYPE_MUSIC)
        .build(),
    )
    .build()

  private fun uriOf(path: String): Uri =
    if (path.startsWith("content://") || path.startsWith("file://")) Uri.parse(path)
    else Uri.fromFile(File(path))

  /** "track:<section>:<id>" → its section and index. */
  private fun find(mediaId: String): Pair<Section, Int>? {
    if (!mediaId.startsWith(TRACK)) return null
    val rest = mediaId.removePrefix(TRACK)
    val sectionId = rest.substringBefore(':')
    val trackId = rest.substringAfter(':')
    val section = sections().firstOrNull { it.id == sectionId } ?: return null
    val index = section.tracks.indexOfFirst { it.id == trackId }
    return if (index < 0) null else section to index
  }

  override fun onGetLibraryRoot(
    session: MediaLibraryService.MediaLibrarySession,
    browser: MediaSession.ControllerInfo,
    params: MediaLibraryService.LibraryParams?,
  ): ListenableFuture<LibraryResult<MediaItem>> =
    Futures.immediateFuture(LibraryResult.ofItem(folder(ROOT, "Miarina Media"), params))

  override fun onGetChildren(
    session: MediaLibraryService.MediaLibrarySession,
    browser: MediaSession.ControllerInfo,
    parentId: String,
    page: Int,
    pageSize: Int,
    params: MediaLibraryService.LibraryParams?,
  ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> {
    val all = sections()
    val children: List<MediaItem> = if (parentId == ROOT) {
      all.filter { it.tracks.isNotEmpty() }.map { folder(FOLDER + it.id, it.title) }
    } else {
      val section = all.firstOrNull { FOLDER + it.id == parentId }
      section?.tracks?.map { item(section, it) } ?: emptyList()
    }
    val from = (page * pageSize).coerceAtMost(children.size)
    val to = (from + pageSize).coerceAtMost(children.size)
    return Futures.immediateFuture(
      LibraryResult.ofItemList(ImmutableList.copyOf(children.subList(from, to)), params),
    )
  }

  override fun onGetItem(
    session: MediaLibraryService.MediaLibrarySession,
    browser: MediaSession.ControllerInfo,
    mediaId: String,
  ): ListenableFuture<LibraryResult<MediaItem>> {
    val found = find(mediaId)
      ?: return Futures.immediateFuture(LibraryResult.ofError(LibraryResult.RESULT_ERROR_BAD_VALUE))
    return Futures.immediateFuture(
      LibraryResult.ofItem(item(found.first, found.first.tracks[found.second]), null),
    )
  }

  /** The app's own items keep their URI; browsed ones get theirs. */
  override fun onAddMediaItems(
    mediaSession: MediaSession,
    controller: MediaSession.ControllerInfo,
    mediaItems: MutableList<MediaItem>,
  ): ListenableFuture<MutableList<MediaItem>> = Futures.immediateFuture(
    mediaItems.mapNotNull { m ->
      if (m.localConfiguration != null) m
      else find(m.mediaId)?.let { (s, i) -> item(s, s.tracks[i]) }
    }.toMutableList(),
  )

  /** A browsed track plays with the rest of its list after it. */
  override fun onSetMediaItems(
    mediaSession: MediaSession,
    controller: MediaSession.ControllerInfo,
    mediaItems: MutableList<MediaItem>,
    startIndex: Int,
    startPositionMs: Long,
  ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
    val single = mediaItems.singleOrNull()
    val found = if (single != null && single.localConfiguration == null) find(single.mediaId) else null
    if (found != null) {
      val (section, index) = found
      return Futures.immediateFuture(
        MediaSession.MediaItemsWithStartPosition(
          section.tracks.map { item(section, it) },
          index,
          C.TIME_UNSET,
        ),
      )
    }
    return super.onSetMediaItems(mediaSession, controller, mediaItems, startIndex, startPositionMs)
  }

  companion object {
    const val FILE = "auto_library.json"
    private const val ROOT = "root"
    private const val FOLDER = "folder:"
    private const val TRACK = "track:"
  }
}

/** Flutter writes the lists Android Auto browses. Channel org.miarina.media/auto. */
class AutoChannel(private val context: Context, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/auto")

  init {
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "library" -> {
        val json = call.arguments as? String ?: return result.error("bad_argument", "json", null)
        try {
          val tmp = File(context.filesDir, AutoLibrary.FILE + ".tmp")
          tmp.writeText(json)
          tmp.renameTo(File(context.filesDir, AutoLibrary.FILE))
          result.success(null)
        } catch (e: Exception) {
          result.error("write_failed", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }
}
