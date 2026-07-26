package com.development.saferelay;

import android.graphics.Color;
import android.os.Bundle;
import android.view.View;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(SafeRelayBackgroundPlugin.class);
        super.onCreate(savedInstanceState);
        installNativeInsets();
    }

    private void installNativeInsets() {
        View container = (View) getBridge().getWebView().getParent();
        container.setBackgroundColor(Color.rgb(8, 11, 15));
        ViewCompat.setOnApplyWindowInsetsListener(container, (view, windowInsets) -> {
            int insetTypes = WindowInsetsCompat.Type.systemBars()
                | WindowInsetsCompat.Type.displayCutout();
            Insets systemBars = windowInsets.getInsets(insetTypes);
            Insets ime = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
            boolean keyboardVisible = windowInsets.isVisible(
                WindowInsetsCompat.Type.ime()
            );

            view.setPadding(
                systemBars.left,
                systemBars.top,
                systemBars.right,
                keyboardVisible ? ime.bottom : systemBars.bottom
            );

            return new WindowInsetsCompat.Builder(windowInsets)
                .setInsets(insetTypes, Insets.NONE)
                .build();
        });
        ViewCompat.requestApplyInsets(container);
    }
}
