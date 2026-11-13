package org.miarina.media

import android.app.PendingIntent
import android.content.Intent
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Owns the Media3 player (CDC AND-01/02/03/04): playback survives the screen
 * turning off and the app going to the background, the system shows a media
 * notification and lock-screen controls, and headset/Bluetooth buttons reach
 * the session. The React screens only control it (NativePlayerPlugin through
 * a MediaController). Audio focus and "becoming noisy" (headphones unplugged)
 * are handled by ExoPlayer: calls pause playback, unplugging pauses it.
 */
class PlaybackService : MediaSessionService() {
  private var session: MediaSession? = null

  override fun onCreate() {
    super.onCreate()
    val player = ExoPlayer.Builder(this)
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(C.USAGE_MEDIA)
          .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
          .build(),
        /* handleAudioFocus = */ true,
      )
      .setHandleAudioBecomingNoisy(true)
      // Keeps the CPU awake for local files while playing with the screen off.
      .setWakeMode(C.WAKE_MODE_LOCAL)
      .build()
    // Tapping the notification returns to the app (not a new task).
    val openApp = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
    session = MediaSession.Builder(this, player).setSessionActivity(openApp).build()
    current = player
  }

  override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

  /** Swiping the app away stops a paused or empty player; music that plays goes on. */
  override fun onTaskRemoved(rootIntent: Intent?) {
    val player = session?.player
    if (player == null || !player.playWhenReady || player.mediaItemCount == 0) {
      stopSelf()
    }
  }

  override fun onDestroy() {
    current = null
    session?.run {
      player.release()
      release()
    }
    session = null
    super.onDestroy()
  }

  companion object {
    /**
     * The player itself, for changes a MediaController does not carry to the
     * session: a sideloaded subtitle file (NativePlayerPlugin, same process).
     */
    var current: ExoPlayer? = null
  }
}
