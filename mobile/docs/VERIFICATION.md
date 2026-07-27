# Verification

## Automated

Run from the repository root:

```sh
jac clean --all --force
jac install
jac check .
jac test tests/protocol_tests.jac tests/operations_tests.jac -v
jac build --client web
```

For Android:

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME="$HOME/Library/Android/sdk"
jac build --client mobile --platform android
```

Confirm the merged manifest contains BLE scan/connect/advertise permissions,
the typed foreground service, boot receiver, microphone/location permissions,
and the BLE feature.

Browser interaction verification should cover onboarding persistence, every
primary tab, disaster refresh, offline tiles, ultrasonic controls, guarded
distress, automatic cloud retry, settings scrolling, the attempt ledger,
responder handoff QR/digest, and zero error-level console messages.

## Physical iPhone radio matrix

Use two Apple Intelligence-capable physical iPhones on iOS 27. Keep Wi-Fi and
cellular unavailable during every matrix row and record results for:

| Sender | Receiver | App state | Expected evidence |
| --- | --- | --- | --- |
| iPhone A | iPhone B | foreground | advertise, discover, connect, packet receipt |
| iPhone B | iPhone A | foreground | advertise, discover, connect, packet receipt |
| iPhone A | iPhone B | background/locked | native receipt notification |
| iPhone B | iPhone A | background/locked | native receipt notification |
| iPhone A | iPhone B | system-terminated, not force-quit | CoreBluetooth restoration and receipt |
| iPhone B | iPhone A | system-terminated, not force-quit | CoreBluetooth restoration and receipt |

For every run capture timestamps, packet bytes, sender/sequence, RSSI, app
state, OS version, and whether the receipt was a read, write, or notification.
Do not mark the path verified from emulator, simulator, or single-device proof.
Do not use a swipe-up force-quit as a background test: iOS records that as an
instruction not to relaunch the app for Bluetooth events.

### 2026-07-26 physical iPhone evidence

The same signed Debug artifact was installed on an iPhone 15 Pro Max and an
iPhone 17 Pro Max, both running iOS 27.0. Device Hub and native console output
showed Bluetooth permission granted, notifications granted, Background App
Refresh available, central scanning active, peripheral advertising active, and
a connected peer.

| Test | Result |
| --- | --- |
| iPhone 15 Pro Max to iPhone 17 Pro Max, receiver foreground | Passed: emergency frame received and retained in local history |
| Active foreign report while app is open | Passed: persistent red `SOMEONE ELSE NEEDS HELP` alert remained visible above the active view and opened the map |
| Settings notification self-test while app is open | Passed: authorization returned `granted`, native scheduling returned `scheduled: true`, and an iOS banner appeared in the foreground |
| Background App Refresh after rebuilt app relaunch | Passed on both phones: native status reported `available`; denied/restricted states now link to iOS Settings and refresh when the app becomes active |
| Mobile incident map data | Passed on physical iPhone: only stored mesh reports and the device position are rendered; synthetic markers and hard-coded incident coordinates are absent |
| iPhone 17 Pro Max to iPhone 15 Pro Max, receiver on Home Screen | Passed: native medical-emergency notification displayed and frame retained after relaunch |
| iPhone 17 Pro Max to locked iPhone 15 Pro Max | Passed: a second native receipt notification woke the lock screen |
| Bidirectional native transport | Passed: both send calls returned `published: true`; frames used the SafeRelay GATT service |
| Settings scrolling | Passed in Device Hub on the installed iPhone 17 Pro Max artifact: the settings surface moved between delivery/display controls and lower storage/cloud sections |
| JacHammer sandbox relay | Passed with the platform preview token: health accepted requests, first ingestion created a receipt, and replay returned the same duplicate receipt |
| Reinstall of the current source artifact | Blocked: the arm64 iPhoneOS 27 build compiles, but Xcode has no signed-in account or provisioning profile for team `PV5R7RPV34` |
| Wi-Fi/cellular unavailable for the complete matrix | Not proven in this run; Device Hub showed Wi-Fi available after development-profile verification |
| System-terminated restoration in both directions | Not run |

These results prove native Bluetooth exchange and receipt handling while the
receiving UI is foregrounded, backgrounded, and locked. They do not replace the
remaining network-isolated and system-termination matrix rows above.

## Physical three-iPhone multi-hop matrix

Use three qualifying physical iPhones arranged as A-to-B-to-C. Verify first
that A and C cannot discover or exchange a fresh control packet directly, while
A-to-B and B-to-C remain reliable. Keep Wi-Fi and cellular unavailable.

| Sender | Relay | Receiver | Relay state | Expected evidence |
| --- | --- | --- | --- | --- |
| A | B | C | foreground | C receives A sender/sequence at hop `1` |
| C | B | A | foreground | A receives C sender/sequence at hop `1` |
| A | B | C | background/locked | C receives through native forwarding |
| A | B | C | temporarily disconnected | B stores, then delivers when C returns |
| A | removed | C | unavailable | no receipt, proving no direct A-to-C path |
| A | B | C | five-hop fixture | B does not forward beyond hop `5` |

Capture native logs on all three devices, the exact frame bytes at each link,
sender/sequence, hop count, timestamps, and receipt source. A passing build,
codec test, two-phone exchange, or an A-to-C path that was not independently
excluded does not prove multi-hop delivery. This matrix remains unverified until
all three physical phones are available and the evidence is recorded here.

### 2026-07-26 multi-hop implementation evidence

- `jac check .` completed with the repository's existing type warnings.
- All 35 focused protocol and operations tests passed.
- A signed arm64 iPhoneOS 27 build succeeded and compiled the native relay.
- The same build installed on both qualifying connected phones. It launched on
  `Phoney`, where Device Hub showed the native shell with the mesh active.
- `Physical iPhone` rejected launch with Apple's `Unable to Verify App` gate,
  although installation succeeded.
- Physical A-to-B-to-C validation remains blocked. The third connected iPhone
  runs iOS 26.5.2 and is ineligible for this iOS 27 application; no simulator,
  iPad, or Android device was substituted.

These checks cover the reliability hardening statically and at build time, but
do not prove scanning, advertising, background continuity, or multi-hop radio
delivery.
