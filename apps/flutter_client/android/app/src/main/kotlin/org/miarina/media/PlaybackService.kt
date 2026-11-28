package org.miarina.media

import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Owns the Media3 player so playback survives the screen turning off and the
 * app going to the background; the system shows the media notification and
 * lock-screen controls, and headset/Bluetooth buttons reach the session.
 * Flutter only controls it through Media3EnginePlugin (a MediaController).
 * Audio focus and "becoming noisy" are handled by ExoPlayer.
 */
class PlaybackService : MediaSessionService() {
  private var session: MediaSession? = null

  @OptIn(UnstableApi::class)
  override fun onCreate() {
    super.onCreate()
    // Files, content URIs and streams as before; an online stream also gets
    // the headers it was resolved with (OnlineHeaders, decision 0011).
    val data = ResolvingDataSource.Factory(DefaultDataSource.Factory(this)) { spec ->
      OnlineHeaders.of(spec.uri)?.let { spec.withAdditionalHeaders(it) } ?: spec
    }
    val player = ExoPlayer.Builder(this)
      .setMediaSourceFactory(DefaultMediaSourceFactory(data))
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(C.USAGE_MEDIA)
          .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
          .build(),
        /* handleAudioFocus = */ true,
      )
      .setHandleAudioBecomingNoisy(true)
      .setWakeMode(C.WAKE_MODE_LOCAL)
      .build()
    val openApp = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
    session = MediaSession.Builder(this, player).setSessionActivity(openApp).build()
    current = player
    player.skipSilenceEnabled = skipSilence
    // The equalizer follows the player's audio session.
    MiarinaEqualizer.attach(player.audioSessionId)
    player.addListener(object : Player.Listener {
      override fun onAudioSessionIdChanged(audioSessionId: Int) {
        MiarinaEqualizer.attach(audioSessionId)
      }

      // The home screen player shows play or pause (PlayerWidget).
      override fun onIsPlayingChanged(isPlaying: Boolean) {
        PlayerWidget.setPlaying(this@PlaybackService, isPlaying)
      }
    })
  }

  override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

  /** Swiping the app away stops a paused or empty player; playing media goes on. */
  override fun onTaskRemoved(rootIntent: Intent?) {
    val player = session?.player
    if (player == null || !player.playWhenReady || player.mediaItemCount == 0) {
      stopSelf()
    }
  }

  override fun onDestroy() {
    current = null
    PlayerWidget.setPlaying(this, false)
    MiarinaEqualizer.release()
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
     * session: a sideloaded subtitle configuration (same process).
     */
    var current: ExoPlayer? = null

    /** Focus: skip silences (Media3's audio processor). */
    @Volatile
    var skipSilence = false
  }
}
