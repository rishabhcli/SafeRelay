# Flutter-to-Jac Parity

This file maps the former Flutter product to the Jac implementation. "Built"
means the behavior exists in the Jac/Capacitor product. "Verified" is reserved
for evidence actually produced in this repository; a configured native surface
is not treated as physical end-to-end proof.

| Former Flutter behavior | Jac/Capacitor implementation | Status |
| --- | --- | --- |
| 25-byte SOS packet and 21-byte legacy decode | `domain/protocol*.jac` | Built; codec tests pass |
| Sender sequence, expiry, replay, targeting, and deduplication | Protocol and operational domain modules | Built; Jac tests pass |
| BLE central scan and GATT peripheral advertising | `services/mesh.cl.jac` with Capgo BLE | Built; both roles start in Android emulator |
| Store-and-forward relay and battery/privacy policy | Jac protocol policy and packet store | Built; policy tests pass |
| Android foreground continuity | App-owned `connectedDevice` service | Built; emulator service verified |
| Android reboot recovery | Boot receiver restores the saved service intent | Partial: radio resumes when the Capacitor app opens |
| iOS background central/peripheral modes | Native CoreBluetooth service plus `UIBackgroundModes` and restoration identifiers | Built; physical bidirectional relay, background receipt, and locked-screen alert verified |
| Local durable settings, packets, and evidence | Capacitor Preferences | Built; cold-restart persistence verified |
| Guarded SOS, medical, trapped, supplies, shelter, and safe reports | Distress console and Jac wire model | Built |
| Incoming alert, notification, haptic, and local history | Persistent foreground foreign-distress banner, native iOS receipt notification, and durable Jac packet history | Built; foreground banner plus foreground, background, and locked native notification delivery verified on physical iOS devices |
| RSSI locator and proximity estimate | Tools locator | Built |
| Compass pointer | Device orientation-backed compass | Built; sensor proof pending |
| Torch strobe and Morse translation | Torch plugin and Jac Morse utility | Built; hardware proof pending |
| 17-20 kHz FSK transmitter and FFT detector | Web Audio transmitter and microphone spectrum receiver | Built; acoustic proof pending |
| Local and global disaster sources | USGS, NOAA, and GDACS aggregation with 24-hour cache | Built; USGS/NOAA live browser fetch verified; GDACS uses native HTTP |
| Explorable local incident map | Full-screen Mapbox GL with drag, pinch zoom, clearly labeled synthetic map artifacts, current position, and recenter | Built; physical-device render verified |
| Three failed reachability probes activate offline relay | Reachability monitor and automatic mesh policy | Built |
| Offline OpenStreetMap tiles | Cache Storage-backed local tile region | Built; bounded 25-tile region |
| Cloud bridge, duplicate receipts, and sync attempt ledger | Supabase RPC bridge and durable evidence ledgers | Built; privacy-blocked path verified |
| Incident evidence, responder needs, field brief, trust, reconciliation | `domain/operations*.jac` and Command/Systems views | Built; Jac tests pass |
| Operator adjudication ledger | Device-local operational history | Built |
| Responder handoff copy, files, share, print, QR, and digest | Capacitor Filesystem/Share/Printer plus local QR | Built; browser copy/QR verified |
| Deterministic protocol fixtures | Jac drill domain retained for automated policy tests only; no generated drill values appear in the runtime UI | Jac tests pass |
| Physical proof/readiness boundary | Systems Proof view and verification docs | Built; does not manufacture proof |

## Deliberate implementation changes

- Jac owns application UI, state, protocol, policy, operations, and tests.
  Java/Swift project files exist only for the native shell, plugins, OS
  permissions, Android foreground service, and boot receiver.
- The offline map download is bounded to a useful local region instead of
  bulk-downloading world zoom levels from OpenStreetMap.
- The fixed field-console theme replaces Flutter's cosmetic theme selector.
  This does not change emergency, radio, storage, map, or handoff behavior.

## Evidence still required

- Android-to-iOS and iOS-to-Android BLE on two qualifying physical devices,
  foreground and background.
- Network-isolated iPhone matrix completion with Wi-Fi and cellular unavailable
  for every row, including system-terminated restoration in both directions.
- Android reboot testing on hardware. The boot receiver restores the foreground
  service, but a Capacitor WebView must run before the JavaScript BLE managers
  can be recreated.
- Physical torch, compass, microphone, speaker, and acoustic FSK tests.
- An authorized Cloud Bridge upload and durable Supabase receipt.
