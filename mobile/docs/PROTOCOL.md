# Packet Protocol

SafeRelay uses a versioned 27-byte big-endian packet:

| Offset | Width | Field |
| --- | ---: | --- |
| 0 | 2 | Header `0xFFFF` |
| 2 | 4 | Unsigned sender ID |
| 6 | 2 | Unsigned sequence |
| 8 | 4 | Signed latitude multiplied by `10^7` |
| 12 | 4 | Signed longitude multiplied by `10^7` |
| 16 | 1 | Status code |
| 17 | 4 | Unsigned Unix timestamp |
| 21 | 4 | Unsigned target ID, `0` for broadcast |
| 25 | 1 | Protocol version, currently `1` |
| 26 | 1 | Relay hops already traversed, `0...5` |

The decoder also accepts the legacy 21-byte form and the unversioned 25-byte
form. Both enter as hop `0`; a native relay upgrades either form to version `1`
before forwarding it. The origin transmits hop `0`, the first intermediate
relay transmits hop `1`, and forwarding stops at hop `5`.

Packets older than 24 hours are expired. Status codes are:

- `0`: safe
- `1`: emergency
- `2`: medical
- `3`: trapped
- `4`: supplies
- `5`: shelter

Packet identity is `sender_id + sequence`. A newer sequence from the same
sender replaces the older local observation. Bluetooth routing cannot be
disabled by a privacy label. Relay policy stops SAFE propagation after direct
neighbors, drops expired or over-hop packets, preserves critical reports under
queue pressure, and can defer lower-priority traffic in Battery Saver mode.

On iOS, hop validation and mutation happen in the native CoreBluetooth service
before retransmission, so forwarding does not depend on the Jac WebView being
awake. Packet identity excludes the mutable hop field, which lets every device
suppress loops by sender and sequence.

Native and Jac decoders reject coordinates outside valid latitude and longitude
bounds. The retained relay queue coalesces each sender to its newest timestamp
and sequence so an older distress cannot be replayed after a newer SAFE update.
