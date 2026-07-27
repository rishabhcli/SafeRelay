# Architecture

## Source layout

| Path | Responsibility |
| --- | --- |
| `main.jac` | Jac client entry point |
| `components/AppShell.cl.jac` | Mobile operator UI and application state |
| `domain/protocol.jac` | Server/test protocol and relay policy |
| `domain/protocol.cl.jac` | Client-build protocol and relay policy |
| `domain/operations.jac` | Testable incident, drill, reconciliation, trust, and handoff domain |
| `domain/operations.cl.jac` | Client mirror of the operational domain |
| `services/mesh.cl.jac` | Capacitor BLE, device, location, alert, and torch bindings |
| `services/storage.cl.jac` | Capacitor Preferences persistence |
| `services/field.cl.jac` | Disaster feeds, reachability, maps, cloud sync, and ultrasonic I/O |
| `components/IncidentMap.cl.jac` | Mapbox GL map, signal markers, selection, zoom, pan, and recenter behavior |
| `services/handoff.cl.jac` | Copy, file, share, print, QR payload, and SHA-256 transfer support |
| `services/foundation_models.cl.jac` | iOS-only local Apple Foundation Models survival-chat bridge |
| `tests/*.jac` | Codec, compatibility, policy, utility, and operational tests |
| `android/`, `ios/` | Generated Capacitor shells plus required native configuration |

Jac currently compiles server and client variants into different codespaces.
The client protocol symbols use a `Client`/`client_` prefix so both variants
remain importable during whole-project checking without duplicate declarations.
Their wire constants and algorithms are intentionally kept equivalent.

## Runtime flow

1. Jac renders the operator shell inside Capacitor.
2. Native launch and every foreground transition start or restore the mesh and
   request BLE permission when needed.
3. The BLE plugin creates both a central scanner and a peripheral GATT server.
4. The central subscribes to the SafeRelay characteristic on discovered peers.
5. The peripheral advertises the same service and accepts peer writes.
6. Valid packets enter native age, duplicate, and hop validation before the
   native service increments the hop and stores the frame for forwarding.
7. Jac receives the unmodified observation for policy, local persistence, UI,
   and cloud reconciliation; iOS does not republish that lower-hop frame.
8. Android starts an app-owned foreground service; iOS relies on declared
   CoreBluetooth background modes.
9. USGS, NOAA, and GDACS data is cached locally.
10. Every locally created or received signal attempts the configured JacHammer
   cloud endpoint; unreachable signals stay queued for the next connectivity
   event or periodic probe.

Bluetooth scanning, advertising, and eligible packet forwarding do not depend
on cloud reachability. Cloud upload does not depend on a privacy-mode switch.
An upload is marked synced only after a successful Jac server response, and
even a durable receipt is not presented as responder acknowledgement.

The iOS bridge retains the newest fresh frame for up to 100 senders and 500
packet identities in `UserDefaults`. Both expire with the 24-hour packet window.
SAFE resolutions and critical reports are ordered ahead of lower-priority
traffic. Queued frames replay both when SafeRelay connects as a central and when
a remote central subscribes, so store-and-forward does not depend on which
phone established the GATT connection.

Central-to-peripheral delivery uses ATT writes with response. One frame is in
flight per peer, failed acknowledgements receive two bounded retries, and failed
connections use CoreBluetooth auto-reconnect plus capped exponential backoff.
Notification and write queues are bounded to 100 frames, tracked peers are
bounded to 64, and CoreBluetooth readiness callbacks resume flow after radio
backpressure.

## Native boundary

The mobile product is Jac application code in a real Capacitor shell. Native
Java and generated Swift project metadata exist only where the operating
systems require a service, entitlement, permission, resource, or plugin bridge.
The app identifier remains `com.development.saferelay`.

`SafeRelayFoundationModelsPlugin.swift` is an iOS 26 Capacitor bridge to
`SystemLanguageModel.default`. It receives at most 12 recent local chat messages
and a bounded evidence snapshot, then creates one advisory Survival Guide reply
with a fresh native session. Conversation history is retained only in Capacitor
Preferences, is never included in radio packets, cloud sync, responder handoffs,
or QR artifacts, and can be cleared in Field Tools. The Guide is hidden in the
browser, on Android, and when Apple Intelligence is unavailable; relay packet
codec, policy, and delivery claims remain deterministic Jac.
`SafeRelayBridgeViewController` registers the app-local plugin after Capacitor
creates its bridge, so normal Capacitor sync operations do not need to alter the
generated plugin list. On iOS it also installs the primary navigation as a
native `UITabBar`. UIKit owns its Liquid Glass appearance, safe-area behavior,
light and dark appearance, SF Symbols, selection state, and accessibility. The
center SOS tab remains red and invokes the corresponding stable Jac navigation
element. The web header is hidden on iOS so content begins at the top safe area
without an additional toolbar; the original HTML navigation and header remain
the fallback when native chrome is absent.
