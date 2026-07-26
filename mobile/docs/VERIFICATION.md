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
distress, cloud privacy blocking, attempt ledger, responder handoff QR/digest,
and zero error-level console messages.

## Physical radio matrix

Use two physical devices and record results for:

| Sender | Relay | App state | Expected evidence |
| --- | --- | --- | --- |
| Android | iOS | foreground | advertise, discover, connect, packet receipt |
| iOS | Android | foreground | advertise, discover, connect, packet receipt |
| Android | iOS | background | service notification and relayed receipt |
| iOS | Android | background | CoreBluetooth wake and relayed receipt |

For every run capture timestamps, packet bytes, sender/sequence, RSSI, app
state, OS version, and whether the receipt was a read, write, or notification.
Do not mark the path verified from emulator, simulator, or single-device proof.
