package org.miarina.media

import android.net.Uri

/**
 * Online listening (decision 0011): the headers a stream URL must be
 * requested with. Media3EnginePlugin records them before the item reaches
 * the player; PlaybackService's data source adds them to its requests (same
 * process). Only the latest few are kept: a stream URL expires in hours and
 * is never stored.
 */
object OnlineHeaders {
  private const val MAX = 8
  private val byUri = LinkedHashMap<String, Map<String, String>>()

  @Synchronized
  fun put(uri: String, headers: Map<String, String>?) {
    if (headers.isNullOrEmpty()) return
    byUri.remove(uri)
    byUri[uri] = headers
    while (byUri.size > MAX) byUri.remove(byUri.keys.first())
  }

  @Synchronized
  fun of(uri: Uri): Map<String, String>? = byUri[uri.toString()]
}
