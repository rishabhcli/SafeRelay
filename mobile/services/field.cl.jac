"""Online/offline field services implemented in Jac over native web APIs."""

import from "@capacitor/core" { Capacitor, CapacitorHttp }
import from .storage {
    DISASTER_CACHE_KEY,
    SYNC_ATTEMPTS_KEY,
    SYNC_RECEIPTS_KEY,
    append_record,
    load_records,
    save_records
}

glob USGS_DAY_URL: str = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";
glob NOAA_ALERTS_URL: str = "https://api.weather.gov/alerts/active?severity=Severe,Extreme";
glob GDACS_RSS_URL: str = "https://www.gdacs.org/xml/rss.xml";
glob SUPABASE_URL: str = "https://iiompuquacigtguvizfa.supabase.co";
glob SUPABASE_ANON_KEY: str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb21wdXF1YWNpZ3RndXZpemZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4NDMwMTMsImV4cCI6MjA4MzQxOTAxM30.Ml2JbvYVmMDur1lr5gT81Uathm5VwUEQFWhuZExsdoo";

glob _internet_failures: int = 0;
glob _last_disaster_fetch_ms: int = 0;
glob _ultrasonic_context: any = None;  # jac:ignore[W1037]
glob _ultrasonic_stream: any = None;  # jac:ignore[W1037]
glob _ultrasonic_timer: any = None;  # jac:ignore[W1037]
glob _window: any = window;  # jac:ignore[W1037, W2001]
glob _navigator: any = navigator;  # jac:ignore[W1037, W2001]
glob _capacitor: any = Capacitor;  # jac:ignore[W1037]
glob _http: any = CapacitorHttp;  # jac:ignore[W1037]


def _now_ms -> int {
    return int(Date.now());  # jac:ignore[W2001]
}


async def:pub verify_internet -> dict[str, object] {
    targets = [
        "https://earthquake.usgs.gov/fdsnws/event/1/version",
        "https://api.weather.gov/"
    ];
    for target in targets {
        try {
            response = await fetch(target, {  # jac:ignore[W2001]
                "method": "GET",
                "cache": "no-store",
                "headers": {"Accept": "text/plain, application/json"}
            });
            if response.ok {
                _internet_failures = 0;
                return {
                    "online": True,
                    "failures": 0,
                    "autoMesh": False,
                    "target": target
                };
            }
        } except Exception {}
    }
    _internet_failures += 1;
    return {
        "online": False,
        "failures": _internet_failures,
        "autoMesh": _internet_failures >= 3,
        "target": ""
    };
}


def _earthquake_events(payload: any) -> list[dict[str, object]] {  # jac:ignore[W1037]
    events: list[dict[str, object]] = [];
    features = payload.features or [];
    for feature in features[:80] {
        try {
            item: any = feature;  # jac:ignore[W1037]
            coordinates: any = item.geometry.coordinates;  # jac:ignore[W1037]
            properties: any = item.properties;  # jac:ignore[W1037]
            magnitude = float(properties.mag or 0.0);
            events.append({
                "id": str(item.id),
                "kind": "Earthquake",
                "title": str(properties.title or "Earthquake"),
                "detail": "Magnitude " + f"{magnitude:.1f}",
                "severity": "High" if magnitude >= 6.0 else ("Medium" if magnitude >= 4.5 else "Low"),
                "timestamp": int(properties.time or 0),
                "latitude": float(coordinates[1]),
                "longitude": float(coordinates[0]),
                "source": "USGS"
            });
        } except Exception {}
    }
    return events;
}


def _weather_events(payload: any) -> list[dict[str, object]] {  # jac:ignore[W1037]
    events: list[dict[str, object]] = [];
    features = payload.features or [];
    for feature in features[:80] {
        try {
            item: any = feature;  # jac:ignore[W1037]
            properties: any = item.properties;  # jac:ignore[W1037]
            geometry: any = item.geometry;  # jac:ignore[W1037]
            latitude = 0.0;
            longitude = 0.0;
            if geometry and geometry.coordinates {
                coordinates: any = geometry.coordinates;  # jac:ignore[W1037]
                if str(geometry.type) == "Point" {
                    longitude = float(coordinates[0]);
                    latitude = float(coordinates[1]);
                } elif str(geometry.type) == "Polygon" and len(coordinates) > 0 and len(coordinates[0]) > 0 {
                    longitude = float(coordinates[0][0][0]);
                    latitude = float(coordinates[0][0][1]);
                }
            }
            event_name = str(properties.event or "Weather alert");
            lower_event = event_name.lower();
            kind = "Weather";
            if "tornado" in lower_event { kind = "Tornado"; }
            elif "hurricane" in lower_event or "tropical" in lower_event { kind = "Hurricane"; }
            elif "flood" in lower_event or "hydrologic" in lower_event { kind = "Flood"; }
            elif "fire" in lower_event { kind = "Fire"; }
            elif "wind" in lower_event { kind = "Cyclone"; }
            events.append({
                "id": str(item.id),
                "kind": kind,
                "title": event_name,
                "detail": str(properties.headline or properties.areaDesc or "Area unavailable"),
                "severity": str(properties.severity or "Unknown"),
                "timestamp": int(Date.parse(properties.effective or properties.sent or "") or _now_ms()),
                "latitude": latitude,
                "longitude": longitude,
                "source": "NOAA"
            });
        } except Exception {}
    }
    return events;
}


def _xml_text(element: any, tag_name: str) -> str {  # jac:ignore[W1037]
    nodes: any = element.getElementsByTagName(tag_name);  # jac:ignore[W1037]
    if nodes and int(nodes.length) > 0 {
        return str(nodes[0].textContent or "").strip();
    }
    return "";
}


def _gdacs_events(xml_text: str) -> list[dict[str, object]] {
    events: list[dict[str, object]] = [];
    parser: any = _window.Reflect.construct(_window.DOMParser, []);  # jac:ignore[W1037]
    xml: any = parser.parseFromString(xml_text, "application/xml");  # jac:ignore[W1037]
    items: any = xml.getElementsByTagName("item");  # jac:ignore[W1037]
    for index in range(min(80, int(items.length))) {
        try {
            item: any = items[index];  # jac:ignore[W1037]
            title = _xml_text(item, "title") or "Global disaster alert";
            detail = _xml_text(item, "description");
            latitude_text = _xml_text(item, "geo:lat") or _xml_text(item, "lat");
            longitude_text = _xml_text(item, "geo:long") or _xml_text(item, "long");
            if not latitude_text or not longitude_text { continue; }
            published = _xml_text(item, "pubDate");
            timestamp = int(Date.parse(published) or _now_ms());  # jac:ignore[W2001]
            lower_title = title.lower();
            kind = "Weather";
            if "earthquake" in lower_title { kind = "Earthquake"; }
            elif "flood" in lower_title { kind = "Flood"; }
            elif "cyclone" in lower_title or "hurricane" in lower_title or "typhoon" in lower_title { kind = "Hurricane"; }
            elif "volcano" in lower_title { kind = "Volcano"; }
            severity = "Medium";
            lower_detail = detail.lower();
            if "red" in lower_detail or "high" in lower_detail { severity = "High"; }
            elif "green" in lower_detail or "low" in lower_detail { severity = "Low"; }
            latitude = float(latitude_text);
            longitude = float(longitude_text);
            events.append({
                "id": "gdacs-" + str(latitude) + "-" + str(longitude) + "-" + str(timestamp),
                "kind": kind,
                "title": title,
                "detail": detail,
                "severity": severity,
                "timestamp": timestamp,
                "latitude": latitude,
                "longitude": longitude,
                "source": "GDACS",
                "url": _xml_text(item, "link")
            });
        } except Exception {}
    }
    return events;
}


async def _fetch_gdacs -> list[dict[str, object]] {
    if _capacitor.isNativePlatform() {
        response = await _http["get"]({
            "url": GDACS_RSS_URL,
            "headers": {"Accept": "application/rss+xml, application/xml"},
            "responseType": "text",
            "connectTimeout": 15000,
            "readTimeout": 15000
        });
        if int(response["status"]) != 200 {
            raise RuntimeError("GDACS returned " + str(response["status"]));
        }
        return _gdacs_events(str(response["data"]));
    }
    response = await fetch(GDACS_RSS_URL, {  # jac:ignore[W2001]
        "headers": {"Accept": "application/rss+xml, application/xml"}
    });
    if not response.ok { raise RuntimeError("GDACS returned " + str(response.status)); }
    return _gdacs_events(await response.text());
}


def _fresh_deduplicated(
    cached: list[dict[str, object]],
    live: list[dict[str, object]],
    now: int
) -> list[dict[str, object]] {
    seen: dict[str, bool] = {};
    output: list[dict[str, object]] = [];
    for item in live + cached {
        try {
            identifier = str(item["source"]) + ":" + str(item["id"]);
            timestamp = int(item["timestamp"]);
            if identifier in seen { continue; }
            if now - timestamp > 86400000 or timestamp > now + 300000 { continue; }
            seen[identifier] = True;
            output.append(item);
        } except Exception {}
    }
    return output;
}


async def:pub fetch_disaster_events(force: bool = False) -> dict[str, object] {
    cached = await load_records(DISASTER_CACHE_KEY);
    now = _now_ms();
    if not force and len(cached) > 0 and now - _last_disaster_fetch_ms < 1200000 {
        return {"events": cached, "source": "cached", "updatedAt": _last_disaster_fetch_ms};
    }

    events: list[dict[str, object]] = [];
    failures: list[str] = [];
    try {
        response = await fetch(USGS_DAY_URL, {"headers": {"Accept": "application/geo+json"}});  # jac:ignore[W2001]
        if response.ok {
            events = events + _earthquake_events(await response.json());
        } else {
            failures.append("USGS returned " + str(response.status));
        }
    } except Exception as error {
        failures.append("USGS unavailable: " + str(error));
    }
    try {
        response = await fetch(NOAA_ALERTS_URL, {  # jac:ignore[W2001]
            "headers": {
                "Accept": "application/geo+json",
                "User-Agent": "SafeRelay/1.0"
            }
        });
        if response.ok {
            events = events + _weather_events(await response.json());
        } else {
            failures.append("NOAA returned " + str(response.status));
        }
    } except Exception as error {
        failures.append("NOAA unavailable: " + str(error));
    }
    try {
        events = events + await _fetch_gdacs();
    } except Exception as error {
        failures.append("GDACS unavailable: " + str(error));
    }

    merged = _fresh_deduplicated(cached, events, now);
    if len(merged) > 0 {
        _last_disaster_fetch_ms = now;
        await save_records(DISASTER_CACHE_KEY, merged);
        return {
            "events": merged,
            "source": "live" if len(events) > 0 else "cached",
            "updatedAt": now,
            "failures": failures
        };
    }
    return {
        "events": cached,
        "source": "cached" if len(cached) > 0 else "unavailable",
        "updatedAt": _last_disaster_fetch_ms,
        "failures": failures
    };
}


def:pub map_tile_urls(
    latitude: float,
    longitude: float,
    zoom: int = 13,
    radius: int = 1
) -> list[str] {
    scale = float(2 ** zoom);
    x = int((longitude + 180.0) / 360.0 * scale);
    latitude_radians = (
        max(-85.0511, min(85.0511, latitude)) * Math.PI / 180.0  # jac:ignore[W2001]
    );
    tangent = Math.tan(latitude_radians);  # jac:ignore[W2001]
    mercator = Math.log(tangent + Math.sqrt(tangent * tangent + 1.0));  # jac:ignore[W2001]
    y = int(
        (1.0 - mercator / Math.PI)  # jac:ignore[W2001]
        / 2.0 * scale
    );
    urls: list[str] = [];
    for row in range(y - radius, y + radius + 1) {
        for column in range(x - radius, x + radius + 1) {
            urls.append(
                "https://tile.openstreetmap.org/"
                + str(zoom) + "/" + str(column) + "/" + str(row) + ".png"
            );
        }
    }
    return urls;
}


async def:pub cache_map_region(
    latitude: float,
    longitude: float,
    zoom: int = 13
) -> dict[str, object] {
    urls = map_tile_urls(latitude, longitude, zoom, 2);
    cached = 0;
    failed = 0;
    try {
        cache_storage: any = _window.caches;  # jac:ignore[W1037]
        cache: any = await cache_storage.open("saferelay-osm-v1");  # jac:ignore[W1037]
        for url in urls {
            try {
                existing = await cache.match(url);
                if existing {
                    cached += 1;
                    continue;
                }
                response = await fetch(url, {"headers": {"Accept": "image/png"}});  # jac:ignore[W2001]
                if response.ok {
                    await cache.put(url, response.clone());
                    cached += 1;
                } else {
                    failed += 1;
                }
            } except Exception {
                failed += 1;
            }
        }
        return {
            "cached": cached,
            "failed": failed,
            "total": len(urls),
            "zoom": zoom,
            "boundary": "25 OpenStreetMap tiles around the current position"
        };
    } except Exception as error {
        return {
            "cached": 0,
            "failed": len(urls),
            "total": len(urls),
            "zoom": zoom,
            "boundary": "Offline tile cache unavailable: " + str(error)
        };
    }
}


def _attempt(
    attempt_id: str,
    status: str,
    pending: int,
    synced: int,
    failed: int,
    duplicates: int,
    privacy_mode: str,
    message: str
) -> dict[str, object] {
    return {
        "attemptId": attempt_id,
        "timestamp": _now_ms(),
        "status": status,
        "pending": pending,
        "synced": synced,
        "failed": failed,
        "duplicates": duplicates,
        "privacyMode": privacy_mode,
        "message": message
    };
}


async def:pub sync_relayed_packets(
    packets: list[any],  # jac:ignore[W1037]
    local_user_id: int,
    privacy_mode: str,
    online: bool,
    platform: str
) -> dict[str, object] {
    pending = [
        packet for packet in packets
        if not packet.is_synced and packet.user_id != local_user_id
    ];
    attempt_id = "sync-" + str(_now_ms());
    if privacy_mode != "Cloud Bridge" {
        item = _attempt(attempt_id, "blocked", len(pending), 0, 0, 0, privacy_mode, "Privacy Bridge blocked cloud upload.");
        await append_record(SYNC_ATTEMPTS_KEY, item);
        return item | {"syncedIds": [], "receipts": []};
    }
    if not online {
        item = _attempt(attempt_id, "offline", len(pending), 0, 0, 0, privacy_mode, "Internet was unavailable; packets remain local.");
        await append_record(SYNC_ATTEMPTS_KEY, item);
        return item | {"syncedIds": [], "receipts": []};
    }
    if len(pending) == 0 {
        item = _attempt(attempt_id, "empty", 0, 0, 0, 0, privacy_mode, "No relayed packets need cloud upload.");
        await append_record(SYNC_ATTEMPTS_KEY, item);
        return item | {"syncedIds": [], "receipts": []};
    }

    synced = 0;
    failed = 0;
    duplicates = 0;
    synced_ids: list[str] = [];
    receipts: list[dict[str, object]] = [];
    device_id = hex(local_user_id)[2:].zfill(8);
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": "Bearer " + SUPABASE_ANON_KEY,
        "Content-Type": "application/json"
    };
    for packet in pending {
        packet_id = packet.unique_id();
        origin_id = hex(packet.user_id)[2:].zfill(8);
        try {
            response = await fetch(SUPABASE_URL + "/rest/v1/rpc/sync_sos_packet", {  # jac:ignore[W2001]
                "method": "POST",
                "headers": headers,
                "body": JSON.stringify({  # jac:ignore[W2001]
                    "p_message_id": origin_id + "_" + str(packet.sequence),
                    "p_device_id": origin_id,
                    "p_latitude": packet.latitude(),
                    "p_longitude": packet.longitude(),
                    "p_status_code": packet.status_code,
                    "p_timestamp": packet.timestamp,
                    "p_rssi": packet.rssi,
                    "p_delivered_by": device_id,
                    "p_hop_count": max(1, packet.relay_hops)
                })
            });
            body: any = await response.json();  # jac:ignore[W1037]
            result: any = body[0] if isinstance(body, list) and len(body) > 0 else body;  # jac:ignore[W1037]
            success = bool(response.ok and result.success);
            is_new = bool(result.is_new) if success else False;
            if success {
                synced_ids.append(packet_id);
                if is_new { synced += 1; }
                else { duplicates += 1; }
            } else {
                failed += 1;
            }
            receipt = {
                "attemptId": attempt_id,
                "packetId": packet_id,
                "timestamp": _now_ms(),
                "serverReceipted": success,
                "isNew": is_new,
                "deliveredBy": device_id
            };
            receipts.append(receipt);
            await append_record(SYNC_RECEIPTS_KEY, receipt, 250);
        } except Exception as error {
            failed += 1;
            receipt = {
                "attemptId": attempt_id,
                "packetId": packet_id,
                "timestamp": _now_ms(),
                "serverReceipted": False,
                "message": str(error)
            };
            receipts.append(receipt);
            await append_record(SYNC_RECEIPTS_KEY, receipt, 250);
        }
    }
    status = "succeeded" if failed == 0 else ("partial" if synced + duplicates > 0 else "failed");
    item = _attempt(
        attempt_id,
        status,
        len(pending),
        synced,
        failed,
        duplicates,
        privacy_mode,
        "Cloud upload completed." if failed == 0 else "Cloud upload completed with failures."
    );
    await append_record(SYNC_ATTEMPTS_KEY, item);
    return item | {"syncedIds": synced_ids, "receipts": receipts, "platform": platform};
}


def _encode_ultrasonic_bits(message: str) -> list[int] {
    bits: list[int] = [];
    values: list[int] = [170, 170];
    for index in range(len(message)) {
        values.append(ord(message[index]) & 255);
    }
    for value in values {
        bits.append(0);
        for offset in range(8) { bits.append((value >> offset) & 1); }
        bits = bits + [1, 1];
    }
    return bits;
}


async def:pub transmit_ultrasonic(
    message: str,
    base_frequency: float = 17000.0
) -> dict[str, object] {
    context_constructor: any = _window.AudioContext or _window.webkitAudioContext;  # jac:ignore[W1037]
    if not context_constructor {
        return {"sent": False, "message": "Web Audio is unavailable."};
    }
    context: any = new(context_constructor);  # jac:ignore[W1037, W2001]
    if str(context.state) == "suspended" {
        await context.resume();
    }
    oscillator: any = context.createOscillator();  # jac:ignore[W1037]
    gain: any = context.createGain();  # jac:ignore[W1037]
    oscillator.connect(gain);
    gain.connect(context.destination);
    bits = _encode_ultrasonic_bits(message);
    start: float = float(context.currentTime) + 0.05;
    seconds_per_bit = 0.05;
    gain.gain.setValueAtTime(0.0, float(context.currentTime));
    gain.gain.setValueAtTime(0.18, start);
    for (index, bit) in enumerate(bits) {
        oscillator.frequency.setValueAtTime(
            base_frequency + (1000.0 if bit == 1 else 0.0),
            start + float(index) * seconds_per_bit
        );
    }
    end = start + float(len(bits)) * seconds_per_bit;
    gain.gain.setValueAtTime(0.18, end - 0.01);
    gain.gain.linearRampToValueAtTime(0.0, end);
    oscillator.addEventListener("ended", lambda { context.close(); }, {"once": True});
    oscillator.start(start);
    oscillator.stop(end);
    return {
        "sent": True,
        "message": message,
        "bits": len(bits),
        "durationMs": int(float(len(bits)) * seconds_per_bit * 1000.0),
        "baseFrequency": base_frequency
    };
}


async def:pub start_ultrasonic_listener(sink: any) -> dict[str, object] {  # jac:ignore[W1037]
    try {
        context_constructor: any = _window.AudioContext or _window.webkitAudioContext;  # jac:ignore[W1037]
        _ultrasonic_context = new(context_constructor);  # jac:ignore[W2001]
        _ultrasonic_stream = await _navigator.mediaDevices.getUserMedia({"audio": True});
        source: any = _ultrasonic_context.createMediaStreamSource(_ultrasonic_stream);  # jac:ignore[W1037]
        analyser: any = _ultrasonic_context.createAnalyser();  # jac:ignore[W1037]
        analyser.fftSize = 2048;
        source.connect(analyser);
        data = new(Uint8Array, analyser.frequencyBinCount);  # jac:ignore[W2001]
        _ultrasonic_timer = setInterval(lambda {
            analyser.getByteFrequencyData(data);
            sample_rate = float(_ultrasonic_context.sampleRate);
            first_bin = int(15000.0 * float(analyser.fftSize) / sample_rate);
            last_bin = min(int(analyser.frequencyBinCount) - 1, int(21000.0 * float(analyser.fftSize) / sample_rate));
            peak = 0;
            peak_bin = first_bin;
            for index in range(first_bin, last_bin + 1) {
                if int(data[index]) > peak {
                    peak = int(data[index]);
                    peak_bin = index;
                }
            }
            sink.call(None, {
                "frequency": float(peak_bin) * sample_rate / float(analyser.fftSize),
                "energy": float(peak) / 255.0
            });
        }, 120);
        return {"listening": True, "message": "Microphone spectrum listener active."};
    } except Exception as error {
        await stop_ultrasonic_listener();
        return {"listening": False, "message": "Microphone unavailable: " + str(error)};
    }
}


async def:pub stop_ultrasonic_listener -> dict[str, object] {
    if _ultrasonic_timer { clearInterval(_ultrasonic_timer); }
    _ultrasonic_timer = None;
    if _ultrasonic_stream {
        for track in _ultrasonic_stream.getTracks() { track.stop(); }
    }
    _ultrasonic_stream = None;
    if _ultrasonic_context {
        try { await _ultrasonic_context.close(); }
        except Exception {}
    }
    _ultrasonic_context = None;
    return {"listening": False, "message": "Ultrasonic listener stopped."};
}
