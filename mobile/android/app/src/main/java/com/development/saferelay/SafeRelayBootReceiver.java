package com.development.saferelay;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public final class SafeRelayBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent == null ? "" : intent.getAction();
        boolean supportedAction =
            Intent.ACTION_BOOT_COMPLETED.equals(action)
            || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action);
        if (!supportedAction) {
            return;
        }

        boolean enabled = context
            .getSharedPreferences(
                SafeRelayBackgroundPlugin.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            .getBoolean(SafeRelayBackgroundPlugin.RELAY_ENABLED_KEY, false);
        if (!enabled) {
            return;
        }

        Intent serviceIntent = new Intent(
            context,
            SafeRelayRelayService.class
        );
        serviceIntent.putExtra(
            SafeRelayRelayService.EXTRA_TITLE,
            "SafeRelay relay recovery"
        );
        serviceIntent.putExtra(
            SafeRelayRelayService.EXTRA_BODY,
            "Background relay was enabled before restart. Open SafeRelay to verify the radio."
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent);
        } else {
            context.startService(serviceIntent);
        }
    }
}
