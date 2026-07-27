# Platform Limits

## iOS

- `bluetooth-central` and `bluetooth-peripheral` are declared in `Info.plist`.
- SafeRelay owns iOS scanning, advertising, GATT exchange, deduplication, and
  receipt notifications in a native CoreBluetooth service. The central and
  peripheral managers use restoration identifiers and start from
  `AppDelegate` when relay was previously enabled.
- The native service persists a bounded store-and-forward queue, increments the
  on-wire hop count, rejects stale or malformed frames, and stops every packet
  at five relay hops even while the WebView is suspended.
- Queue replay covers both GATT roles: discovered peripherals receive
  acknowledged writes, while newly subscribed centrals receive the retained
  queue. Failed writes retry twice and failed connections back off to 30 seconds.
- Radio queues, duplicate history, and tracked peer counts are bounded to
  prevent malformed or high-volume traffic from growing memory without limit.
- Background scanning must use a service UUID, which SafeRelay does.
- iOS may coalesce discoveries and advertising intervals while backgrounded.
- A received distress frame schedules a local notification in native code, so
  delivery does not depend on the suspended WebView running JavaScript.
- While the app is open, every active, unexpired distress from another device
  also holds a persistent in-app alert above the current view until the report
  is marked safe, replaced, or expires.
- Settings includes a notification self-test. On iOS it checks the current
  authorization and schedules through the same native queue used for received
  distress frames.
- Background App Refresh is checked at launch and whenever SafeRelay returns to
  the foreground. A denied or restricted state becomes an actionable Settings
  warning. Bluetooth restoration uses the Bluetooth background modes and is
  not a periodic background-fetch loop.
- The operating system controls suspension, radio scheduling, and termination.
  iOS does not relaunch any Bluetooth application after the user explicitly
  force-quits it; background, locked, and system-terminated states are the
  supported continuity cases.
- A locally provisioned development build may need a one-time internet
  connection for Apple to verify its signing profile. That verification is an
  installation constraint, not a SafeRelay transport dependency.
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
- A direct two-phone test proves one radio link, not an A-to-B-to-C relay.
- Offline receipt alerts are local notifications triggered by BLE receipt, not
  APNs remote push notifications.
- GDACS browser access can be blocked by CORS; native builds use Capacitor's
  native HTTP transport for that feed.
- Filesystem, share, and print availability still follows the native OS and
  installed destination apps/printers.
