"""Durable device-local state backed by Capacitor Preferences."""

import from "@capacitor/preferences" { Preferences }
import from "@capacitor/device" { Device }
import from ..domain.protocol { ClientSosPacket as SosPacket }

glob _preferences: any = Preferences;  # jac:ignore[W1037]
glob PACKETS_KEY: str = "saferelay.packets.v2";
glob USER_ID_KEY: str = "saferelay.user-id";
glob SEQUENCE_KEY: str = "saferelay.sequence";
glob ONBOARDING_KEY: str = "saferelay.onboarding";
glob:pub PRIVACY_KEY: str = "saferelay.privacy";
glob:pub BATTERY_KEY: str = "saferelay.battery";
glob:pub SYNC_ATTEMPTS_KEY: str = "saferelay.sync-attempts.v1";
glob:pub SYNC_RECEIPTS_KEY: str = "saferelay.sync-receipts.v1";
glob:pub ADJUDICATIONS_KEY: str = "saferelay.adjudications.v1";
glob:pub DISASTER_CACHE_KEY: str = "saferelay.disasters.v1";
glob:pub REGION_CACHE_KEY: str = "saferelay.offline-regions.v1";


async def:pub load_setting(key: str, fallback: str) -> str {
    try {
        result = await _preferences["get"]({"key": key});
        if result.value { return str(result.value); }
    } except Exception {
        return fallback;
    }
    return fallback;
}


async def:pub save_setting(key: str, value: str) {
    await Preferences.set({"key": key, "value": value});
}


async def:pub load_records(key: str) -> list[dict[str, object]] {
    try {
        result = await _preferences["get"]({"key": key});
        if not result.value { return []; }
        return JSON.parse(result.value) as list[dict[str, object]];  # jac:ignore[W2001]
    } except Exception {
        return [];
    }
}


async def:pub save_records(key: str, records: list[dict[str, object]]) {
    await Preferences.set({
        "key": key,
        "value": JSON.stringify(records)  # jac:ignore[W2001]
    });
}


async def:pub append_record(
    key: str,
    record: dict[str, object],
    limit: int = 100
) {
    records = await load_records(key);
    await save_records(key, [record] + records[:limit - 1]);
}


async def:pub load_onboarding_complete -> bool {
    return await load_setting(ONBOARDING_KEY, "false") == "true";
}


async def:pub complete_onboarding {
    await save_setting(ONBOARDING_KEY, "true");
}


async def:pub get_or_create_user_id -> int {
    stored = await load_setting(USER_ID_KEY, "");
    if stored {
        try { return int(stored); }
        except ValueError {}
    }

    identity = await Device.getId();
    identifier = str(identity.identifier);
    user_id = 2166136261;
    for character in identifier {
        user_id = (user_id * 16777619 + ord(character)) % 4294967295;
    }
    if user_id == 0 { user_id = 1; }
    await save_setting(USER_ID_KEY, str(user_id));
    return user_id;
}


async def:pub next_sequence -> int {
    stored = await load_setting(SEQUENCE_KEY, "0");
    sequence = 0;
    try { sequence = int(stored); }
    except ValueError { sequence = 0; }
    sequence = (sequence + 1) % 65536;
    await save_setting(SEQUENCE_KEY, str(sequence));
    return sequence;
}


async def:pub save_packets(packets: list[SosPacket]) {
    records: list[dict[str, object]] = [
        packet.to_record() for packet in packets
    ];
    await Preferences.set({
        "key": PACKETS_KEY,
        "value": JSON.stringify(records)  # jac:ignore[W2001]
    });
}


def _packet_from_record(item: dict[str, object]) -> SosPacket {
    return SosPacket(
        user_id=item["userId"] as int,
        sequence=item["sequence"] as int,
        latitude_e7=item["latitudeE7"] as int,
        longitude_e7=item["longitudeE7"] as int,
        status_code=item["status"] as int,
        timestamp=item["timestamp"] as int,
        target_id=item["targetId"] as int,
        rssi=item["rssi"] as int,
        is_synced=item["isSynced"] as bool,
        relay_hops=item["relayHops"] as int
    );
}


async def:pub load_packets -> list[SosPacket] {
    try {
        result = await _preferences["get"]({"key": PACKETS_KEY});
        if not result.value { return []; }
        records = JSON.parse(result.value) as list[dict[str, object]];  # jac:ignore[W2001]
        packets: list[SosPacket] = [];
        for item in records {
            try { packets.append(_packet_from_record(item)); }
            except Exception {}
        }
        return packets;
    } except Exception {
        return [];
    }
}


async def:pub clear_packets {
    await _preferences["remove"]({"key": PACKETS_KEY});
}


async def:pub clear_operational_history {
    await _preferences["remove"]({"key": SYNC_ATTEMPTS_KEY});
    await _preferences["remove"]({"key": SYNC_RECEIPTS_KEY});
    await _preferences["remove"]({"key": ADJUDICATIONS_KEY});
}
