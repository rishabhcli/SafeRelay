package com.development.saferelay;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

public final class SafeRelayRelayService extends Service {
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_BODY = "body";

    private static final String CHANNEL_ID = "saferelay_mesh_relay";
    private static final int NOTIFICATION_ID = 7301;

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Mesh relay",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription(
                "Keeps the SafeRelay Bluetooth relay active in the background."
            );
            getSystemService(NotificationManager.class)
                .createNotificationChannel(channel);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String title = intent == null
            ? "SafeRelay relay active"
            : intent.getStringExtra(EXTRA_TITLE);
        String body = intent == null
            ? "Listening for nearby emergency packets."
            : intent.getStringExtra(EXTRA_BODY);

        Intent launchIntent = new Intent(this, MainActivity.class);
        int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingFlags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingFlags
        );
        Notification notification = new NotificationCompat.Builder(
            this,
            CHANNEL_ID
        )
            .setSmallIcon(R.drawable.ic_stat_safe_relay)
            .setContentTitle(
                title == null ? "SafeRelay relay active" : title
            )
            .setContentText(
                body == null
                    ? "Listening for nearby emergency packets."
                    : body
            )
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent)
            .build();

        startForeground(NOTIFICATION_ID, notification);
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE);
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
