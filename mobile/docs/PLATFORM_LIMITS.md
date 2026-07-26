# Platform Limits

## iOS

- `bluetooth-central` and `bluetooth-peripheral` are declared in `Info.plist`.
- Background scanning must use a service UUID, which SafeRelay does.
- iOS may coalesce discoveries and advertising intervals while backgrounded.
- The operating system controls suspension, radio scheduling, and termination.
- A full iOS build requires full Xcode, not Command Line Tools alone.

## Android

- Android 12 and later require runtime scan, connect, and advertise grants.
- Android 13 and later can separately deny notification display.
- Android 14 and later require a typed foreground service and its permission.
- SafeRelay supplies a `connectedDevice` foreground service because the BLE
  package's published 8.2.0 foreground-service method is currently a no-op.
- The service improves process continuity; the OS can still terminate the
  process under exceptional pressure or policy.
- The boot receiver restores a previously enabled foreground-service intent.
  Because the BLE managers live in the Capacitor runtime, scanning and
  advertising are recreated when the app/WebView runs; boot alone does not
  prove an autonomous radio restart.

## Product truth

- Browser preview never reports native BLE as active.
- "Packet created" is not "packet received."
- "Packet received" is not "responder acknowledged."
- RSSI distance is an estimate, not a measured range.
- Background and dual-role behavior require physical-device verification.
- GDACS browser access can be blocked by CORS; native builds use Capacitor's
  native HTTP transport for that feed.
- Filesystem, share, and print availability still follows the native OS and
  installed destination apps/printers.
