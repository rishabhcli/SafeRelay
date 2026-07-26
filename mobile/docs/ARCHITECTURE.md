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
| `services/handoff.cl.jac` | Copy, file, share, print, QR payload, and SHA-256 transfer support |
| `tests/*.jac` | Codec, compatibility, policy, utility, and operational tests |
| `android/`, `ios/` | Generated Capacitor shells plus required native configuration |

Jac currently compiles server and client variants into different codespaces.
The client protocol symbols use a `Client`/`client_` prefix so both variants
remain importable during whole-project checking without duplicate declarations.
Their wire constants and algorithms are intentionally kept equivalent.

## Runtime flow

1. Jac renders the operator shell inside Capacitor.
2. Starting the mesh requests BLE permission.
3. The BLE plugin creates both a central scanner and a peripheral GATT server.
4. The central subscribes to the SafeRelay characteristic on discovered peers.
5. The peripheral advertises the same service and accepts peer writes.
6. Valid packets enter Jac policy, local persistence, notification, and relay.
7. Android starts an app-owned foreground service; iOS relies on declared
   CoreBluetooth background modes.
8. USGS, NOAA, and GDACS data is cached locally; cloud upload remains explicitly
   privacy-gated and creates attempt and receipt evidence.

Packets stay on the device unless relay policy allows forwarding. Cloud Bridge
uploads only packets relayed by this device through the original Supabase RPC.
An upload is marked synced only after a successful server response, and even a
durable receipt is not presented as responder acknowledgement.

## Native boundary

The mobile product is Jac application code in a real Capacitor shell. Native
Java and generated Swift project metadata exist only where the operating
systems require a service, entitlement, permission, resource, or plugin bridge.
The app identifier remains `com.development.saferelay`.
