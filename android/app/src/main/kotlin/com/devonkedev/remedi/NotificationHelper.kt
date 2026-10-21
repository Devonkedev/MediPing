package com.devonkedev.remedi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationHelper {

    private const val CHANNEL_ID = "alarm_channel"
    const val ACTION_STOP_ALARM = "com.devonkedev.remedi.STOP_ALARM"

    fun show(context: Context, title: String, body: String) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarms",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        // PendingIntent that stops the alarm sound —
        // fired both when the notification is swiped away and when it is tapped.
        val stopIntent = Intent(context, StopAlarmReceiver::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            stopIntent,
            flags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            // Swipe away → stop sound
            .setDeleteIntent(stopPendingIntent)
            // Tap notification → stop sound
            .setContentIntent(stopPendingIntent)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
