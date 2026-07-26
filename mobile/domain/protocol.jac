"""SafeRelay wire protocol and offline mesh policy."""

glob PACKET_HEADER: int = 65535;
glob PACKET_SIZE: int = 25;
glob LEGACY_PACKET_SIZE: int = 21;
glob MAX_PACKET_AGE_SECONDS: int = 86400;
glob MAX_RELAY_HOPS: int = 5;


obj:pub SosPacket {
    has user_id: int,
        sequence: int,
        latitude_e7: int,
        longitude_e7: int,
        status_code: int,
        timestamp: int;
    has target_id: int = 0,
        rssi: int = -127,
        is_synced: bool = False,
        relay_hops: int = 0;

    def latitude -> float {
        return self.latitude_e7 / 10000000.0;
    }

    def longitude -> float {
        return self.longitude_e7 / 10000000.0;
    }

    def unique_id -> str {
        return str(self.user_id) + "_" + str(self.sequence);
    }

    def age_seconds(now_seconds: int) -> int {
        return now_seconds - self.timestamp;
    }

    def is_expired(now_seconds: int) -> bool {
        return self.age_seconds(now_seconds) > MAX_PACKET_AGE_SECONDS;
    }

    def to_record -> dict[str, object] {
        return {
            "userId": self.user_id,
            "sequence": self.sequence,
            "latitudeE7": self.latitude_e7,
            "longitudeE7": self.longitude_e7,
            "status": self.status_code,
            "timestamp": self.timestamp,
            "targetId": self.target_id,
            "rssi": self.rssi,
            "isSynced": self.is_synced,
            "relayHops": self.relay_hops
        };
    }
}


obj:pub RelayResult {
    has decision: str,
        reason: str,
        facts: list[str];
    has unknowns: list[str] = [];

    def should_relay -> bool {
        return self.decision == "relay";
    }
}


def:pub status_label(code: int) -> str {
    if code == 0 { return "SAFE"; }
    if code == 1 { return "EMERGENCY"; }
    if code == 2 { return "MEDICAL"; }
    if code == 3 { return "TRAPPED"; }
    if code == 4 { return "SUPPLIES"; }
    if code == 5 { return "SHELTER"; }
    return "UNKNOWN";
}


def:pub status_description(code: int) -> str {
    if code == 0 { return "I am safe"; }
    if code == 1 { return "Need rescue"; }
    if code == 2 { return "Medical emergency"; }
    if code == 3 { return "Trapped or pinned"; }
    if code == 4 { return "Need water, food, or supplies"; }
    if code == 5 { return "Shelter status report"; }
    return "Unsupported status";
}


def status_priority(code: int) -> int {
    if code == 1 or code == 3 { return 3; }
    if code == 2 { return 2; }
    if code == 4 or code == 5 { return 1; }
    return 0;
}


def status_color(code: int) -> str {
    if code == 0 { return "#48c78e"; }
    if code == 1 { return "#ff4d5e"; }
    if code == 2 { return "#ff7b54"; }
    if code == 3 { return "#ffb020"; }
    if code == 4 { return "#f2cc60"; }
    if code == 5 { return "#49a8ff"; }
    return "#8c98a8";
}


def:pub create_packet(
    user_id: int,
    sequence: int,
    latitude: float,
    longitude: float,
    status_code: int,
    timestamp: int,
    target_id: int = 0
) -> SosPacket {
    validate_status(status_code);
    return SosPacket(
        user_id=user_id,
        sequence=sequence,
        latitude_e7=int(round(latitude * 10000000.0)),
        longitude_e7=int(round(longitude * 10000000.0)),
        status_code=status_code,
        timestamp=timestamp,
        target_id=target_id
    );
}


def validate_status(code: int) {
    if code < 0 or code > 5 {
        raise ValueError("Unsupported SOS status: " + str(code));
    }
}


def _byte(value: int, shift: int) -> int {
    return (value >> shift) & 255;
}


def:pub packet_to_bytes(packet: SosPacket) -> list[int] {
    validate_status(packet.status_code);
    return [
        255,
        255,
        _byte(packet.user_id, 24),
        _byte(packet.user_id, 16),
        _byte(packet.user_id, 8),
        _byte(packet.user_id, 0),
        _byte(packet.sequence, 8),
        _byte(packet.sequence, 0),
        _byte(packet.latitude_e7, 24),
        _byte(packet.latitude_e7, 16),
        _byte(packet.latitude_e7, 8),
        _byte(packet.latitude_e7, 0),
        _byte(packet.longitude_e7, 24),
        _byte(packet.longitude_e7, 16),
        _byte(packet.longitude_e7, 8),
        _byte(packet.longitude_e7, 0),
        packet.status_code,
        _byte(packet.timestamp, 24),
        _byte(packet.timestamp, 16),
        _byte(packet.timestamp, 8),
        _byte(packet.timestamp, 0),
        _byte(packet.target_id, 24),
        _byte(packet.target_id, 16),
        _byte(packet.target_id, 8),
        _byte(packet.target_id, 0)
    ];
}


def _u16(bytes: list[int], offset: int) -> int {
    return bytes[offset] * 256 + bytes[offset + 1];
}


def _u32(bytes: list[int], offset: int) -> int {
    return (
        bytes[offset] * 16777216
        + bytes[offset + 1] * 65536
        + bytes[offset + 2] * 256
        + bytes[offset + 3]
    );
}


def _i32(bytes: list[int], offset: int) -> int {
    value = _u32(bytes, offset);
    return value - 4294967296 if value >= 2147483648 else value;
}


def:pub packet_from_bytes(bytes: list[int], rssi: int = -127) -> SosPacket {
    if len(bytes) != LEGACY_PACKET_SIZE and len(bytes) != PACKET_SIZE {
        raise ValueError(
            "Invalid packet size: " + str(len(bytes)) + ", expected 21 or 25"
        );
    }
    if _u16(bytes, 0) != PACKET_HEADER {
        raise ValueError("Invalid SafeRelay packet header");
    }
    validate_status(bytes[16]);
    return SosPacket(
        user_id=_u32(bytes, 2),
        sequence=_u16(bytes, 6),
        latitude_e7=_i32(bytes, 8),
        longitude_e7=_i32(bytes, 12),
        status_code=bytes[16],
        timestamp=_u32(bytes, 17),
        target_id=_u32(bytes, 21) if len(bytes) == PACKET_SIZE else 0,
        rssi=rssi
    );
}


def:pub replace_packet(
    packets: list[SosPacket],
    incoming: SosPacket
) -> list[SosPacket] {
    result: list[SosPacket] = [];
    keep_incoming = True;
    for packet in packets {
        if packet.user_id != incoming.user_id {
            result.append(packet);
        } elif packet.sequence > incoming.sequence {
            result.append(packet);
            keep_incoming = False;
        }
    }
    return [incoming] + result if keep_incoming else result;
}


def:pub contains_packet(packets: list[SosPacket], packet_id: str) -> bool {
    for packet in packets {
        if packet.unique_id() == packet_id { return True; }
    }
    return False;
}


def:pub evaluate_relay(
    packet: SosPacket,
    now_seconds: int,
    privacy_mode: str,
    battery_mode: str,
    queue_depth: int,
    max_queue_depth: int = 100
) -> RelayResult {
    facts = [
        "Privacy mode: " + privacy_mode,
        "Battery mode: " + battery_mode,
        "Queue depth: " + str(queue_depth) + "/" + str(max_queue_depth),
        "Status: " + status_label(packet.status_code),
        "Relay hops: " + str(packet.relay_hops) + "/" + str(MAX_RELAY_HOPS)
    ];
    unknowns = [
        "A policy decision is not physical multi-device relay proof."
    ];

    if privacy_mode == "Local Only" {
        return RelayResult(
            decision="blocked",
            reason="Privacy mode blocks forwarding",
            facts=facts,
            unknowns=unknowns
        );
    }
    if packet.status_code == 0 {
        return RelayResult(
            decision="drop",
            reason="SAFE packets stop distress propagation",
            facts=facts,
            unknowns=unknowns
        );
    }
    if packet.is_expired(now_seconds) or packet.timestamp > now_seconds + 300 {
        return RelayResult(
            decision="drop",
            reason="Packet timestamp is outside the replay window",
            facts=facts,
            unknowns=unknowns
        );
    }
    if packet.relay_hops >= MAX_RELAY_HOPS and status_priority(packet.status_code) < 3 {
        return RelayResult(
            decision="drop",
            reason="Relay hop limit reached",
            facts=facts,
            unknowns=unknowns
        );
    }
    if queue_depth >= max_queue_depth and status_priority(packet.status_code) < 2 {
        return RelayResult(
            decision="drop",
            reason="Queue pressure preserved urgent traffic",
            facts=facts,
            unknowns=unknowns
        );
    }
    if battery_mode == "Battery Saver" and status_priority(packet.status_code) < 2 {
        return RelayResult(
            decision="defer",
            reason="Battery reserve preserved for urgent traffic",
            facts=facts,
            unknowns=unknowns
        );
    }
    return RelayResult(
        decision="relay",
        reason="Packet is eligible for local forwarding",
        facts=facts,
        unknowns=unknowns
    );
}


def:pub estimated_distance_meters(rssi: int, tx_power: int = -59) -> float {
    if rssi >= 0 { return 0.0; }
    ratio = rssi / float(tx_power);
    if ratio < 1.0 { return ratio ** 10.0; }
    return 0.89976 * (ratio ** 7.7095) + 0.111;
}


def:pub readiness_score(
    ble_ready: bool,
    location_ready: bool,
    notifications_ready: bool,
    mesh_active: bool
) -> int {
    score = 15;
    if ble_ready { score += 30; }
    if location_ready { score += 20; }
    if notifications_ready { score += 15; }
    if mesh_active { score += 20; }
    return score;
}


glob MORSE: dict[str, str] = {
    "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".",
    "F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
    "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---",
    "P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
    "U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--",
    "Z": "--..", "0": "-----", "1": ".----", "2": "..---",
    "3": "...--", "4": "....-", "5": ".....", "6": "-....",
    "7": "--...", "8": "---..", "9": "----."
};


def:pub to_morse(message: str) -> str {
    words: list[str] = [];
    for word in message.upper().split() {
        letters: list[str] = [];
        for letter in word {
            if letter in MORSE { letters.append(MORSE[letter]); }
        }
        words.append(" ".join(letters));
    }
    return " / ".join(words);
}
