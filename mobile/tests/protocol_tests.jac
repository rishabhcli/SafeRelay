"""Executable protocol and relay-policy specifications."""

import from domain.protocol {
    SosPacket,
    active_foreign_distress,
    contains_packet,
    estimated_distance_meters,
    evaluate_relay,
    packet_from_bytes,
    packet_to_bytes,
    readiness_score,
    replace_packet,
    to_morse
}


def fixture(status: int = 2) -> SosPacket {
    return SosPacket(
        user_id=305419896,
        sequence=42,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=status,
        timestamp=1778906400,
        target_id=16909060
    );
}


test "current packet round trips all 25 bytes" {
    packet = fixture();
    bytes = packet_to_bytes(packet);
    decoded = packet_from_bytes(bytes, -67);

    assert len(bytes) == 25;
    assert bytes == [
        255, 255, 18, 52, 86, 120, 0, 42, 22, 131, 254, 8, 183,
        8, 72, 48, 2, 106, 7, 245, 32, 1, 2, 3, 4
    ];
    assert decoded.user_id == packet.user_id;
    assert decoded.sequence == packet.sequence;
    assert decoded.latitude_e7 == packet.latitude_e7;
    assert decoded.longitude_e7 == packet.longitude_e7;
    assert decoded.status_code == 2;
    assert decoded.timestamp == packet.timestamp;
    assert decoded.target_id == packet.target_id;
    assert decoded.rssi == -67;
}


test "unsigned 32 bit identities survive the codec" {
    packet = SosPacket(
        user_id=4063516280,
        sequence=65535,
        latitude_e7=-338688000,
        longitude_e7=1512093000,
        status_code=1,
        timestamp=1778906400
    );
    decoded = packet_from_bytes(packet_to_bytes(packet));
    assert decoded.user_id == 4063516280;
    assert decoded.sequence == 65535;
    assert decoded.latitude_e7 == -338688000;
    assert decoded.longitude_e7 == 1512093000;
}


test "legacy 21 byte packet defaults to broadcast target" {
    current = packet_to_bytes(fixture(1));
    legacy = current[:21];
    decoded = packet_from_bytes(legacy);
    assert len(legacy) == 21;
    assert decoded.target_id == 0;
    assert decoded.status_code == 1;
}


test "malformed packet header is rejected" {
    bytes = packet_to_bytes(fixture());
    bytes[0] = 18;
    try {
        packet_from_bytes(bytes);
        assert False, "invalid header should raise";
    } except ValueError {
        assert True;
    }
}


test "newer sender sequence replaces stale local evidence" {
    first = fixture(1);
    other = SosPacket(
        user_id=99,
        sequence=1,
        latitude_e7=0,
        longitude_e7=0,
        status_code=4,
        timestamp=1778906400
    );
    newer = SosPacket(
        user_id=first.user_id,
        sequence=43,
        latitude_e7=first.latitude_e7,
        longitude_e7=first.longitude_e7,
        status_code=0,
        timestamp=1778906460
    );
    merged = replace_packet([first, other], newer);
    assert len(merged) == 2;
    assert merged[0].sequence == 43;
    assert contains_packet(merged, newer.unique_id());
    assert contains_packet(merged, other.unique_id());
}


test "legacy privacy labels cannot disable Bluetooth forwarding" {
    result = evaluate_relay(
        fixture(1),
        1778906460,
        "Local Only",
        "Bridge",
        0
    );
    assert result.decision == "relay";
    assert result.should_relay();
}


test "safe packet stops distress propagation" {
    result = evaluate_relay(
        fixture(0),
        1778906460,
        "Relay Only",
        "Bridge",
        0
    );
    assert result.decision == "drop";
    assert "SAFE" in result.reason;
}


test "active foreign distress excludes local safe and expired packets" {
    now = 200000;
    local = SosPacket(
        user_id=42,
        sequence=1,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=1,
        timestamp=now - 5
    );
    foreign = SosPacket(
        user_id=84,
        sequence=1,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=2,
        timestamp=now - 10
    );
    safe = SosPacket(
        user_id=126,
        sequence=1,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=0,
        timestamp=now - 10
    );
    expired = SosPacket(
        user_id=168,
        sequence=1,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=3,
        timestamp=now - 86401
    );

    active = active_foreign_distress(
        [local, foreign, safe, expired],
        42,
        now
    );

    assert len(active) == 1;
    assert active[0].unique_id() == foreign.unique_id();
}


test "critical packet survives pressure and battery saver" {
    packet = fixture(1);
    packet.relay_hops = 5;
    result = evaluate_relay(
        packet,
        1778906460,
        "Relay Only",
        "Battery Saver",
        100
    );
    assert result.decision == "relay";
}


test "non urgent packet defers for battery reserve" {
    result = evaluate_relay(
        fixture(4),
        1778906460,
        "Relay Only",
        "Battery Saver",
        0
    );
    assert result.decision == "defer";
}


test "offline field utilities stay deterministic" {
    assert to_morse("SOS 2") == "... --- ... / ..---";
    assert estimated_distance_meters(-59) > 0.9;
    assert estimated_distance_meters(-59) < 1.2;
    assert readiness_score(True, True, True, True) == 100;
}
