# Packet Protocol

SafeRelay uses a fixed 25-byte big-endian packet:

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

The decoder also accepts the legacy 21-byte form and assigns target ID `0`.
Packets older than 24 hours are expired. Status codes are:

- `0`: safe
- `1`: emergency
- `2`: medical
- `3`: trapped
- `4`: supplies
- `5`: shelter

Packet identity is `sender_id + sequence`. A newer sequence from the same
sender replaces the older local observation. Bluetooth routing cannot be
disabled by a privacy label. Relay policy stops SAFE propagation, drops expired
or over-hop packets, preserves critical reports under queue pressure, and can
defer lower-priority traffic in Battery Saver mode.
