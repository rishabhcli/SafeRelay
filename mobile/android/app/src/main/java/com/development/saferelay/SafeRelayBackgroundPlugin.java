package com.development.saferelay;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "SafeRelayBackground")
public class SafeRelayBackgroundPlugin extends Plugin {
    public static final String PREFS_NAME = "saferelay_native";
    public static final String RELAY_ENABLED_KEY = "relay_enabled";

    private void setRelayEnabled(boolean enabled) {
        getContext()
            .getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
            .edit()
            .putBoolean(RELAY_ENABLED_KEY, enabled)
            .apply();
    }

    @PluginMethod
    public void start(PluginCall call) {
        Intent intent = new Intent(getContext(), SafeRelayRelayService.class);
        intent.putExtra(
            SafeRelayRelayService.EXTRA_TITLE,
            call.getString("title", "SafeRelay relay active")
        );
        intent.putExtra(
            SafeRelayRelayService.EXTRA_BODY,
            call.getString("body", "Listening for nearby emergency packets.")
        );

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getContext().startForegroundService(intent);
        } else {
            getContext().startService(intent);
        }
        setRelayEnabled(true);

        JSObject result = new JSObject();
        result.put("running", true);
        call.resolve(result);
    }

    @PluginMethod
    public void stop(PluginCall call) {
        getContext().stopService(
            new Intent(getContext(), SafeRelayRelayService.class)
        );
        setRelayEnabled(false);
        JSObject result = new JSObject();
        result.put("running", false);
        call.resolve(result);
    }

    @PluginMethod
    public void status(PluginCall call) {
        SharedPreferences preferences = getContext().getSharedPreferences(
            PREFS_NAME,
            android.content.Context.MODE_PRIVATE
        );
        JSObject result = new JSObject();
        result.put(
            "enabled",
            preferences.getBoolean(RELAY_ENABLED_KEY, false)
        );
        call.resolve(result);
    }
}
