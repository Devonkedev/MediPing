package com.devonkedev.remedi

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager

object AlarmSoundPlayer {

    private var player: MediaPlayer? = null

    fun play(context: Context) {
        if (player != null) return

        // Use device's default alarm tone; fallback to ringtone if none set
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        try {
            player = MediaPlayer().apply {
                setDataSource(context, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            player = null
        }
    }

    fun stop() {
        player?.stop()
        player?.release()
        player = null
    }
}
