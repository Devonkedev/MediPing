package com.devonkedev.remedi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {

        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "Reminder"
        val body = intent.getStringExtra("body") ?: ""
        val repeat = intent.getStringExtra("repeat") ?: "none"

        // 🔊 START SOUND
        AlarmSoundPlayer.play(context)

        // 🔔 SHOW NOTIFICATION
        NotificationHelper.show(context, title, body)

        // 🔁 REPEAT LOGIC
        val nextTime = when (repeat) {
            "daily" -> System.currentTimeMillis() + 24 * 60 * 60 * 1000
            "weekly" -> System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000
            else -> null
        }

        nextTime?.let {
            AlarmHelper.schedule(
                context,
                id,
                it,
                title,
                body,
                repeat
            )
        }
    }
}
