"""Persistent public-source hazard evidence for SafeRelay operations."""

import json;
import datetime;
import urllib.request;


node DisasterCache {
    has refreshed_at: str,
        source_status: str;
}

node DisasterEvent {
    has disaster_id: str,
        source: str,
        event_type: str,
        severity: str,
        title: str,
        area: str,
        occurred_at: str,
        detail_url: str = "";
}

edge DisasterCacheEvent: DisasterCache --> DisasterEvent {}


node MobileRelaySignal {
    has message_id: str,
        origin_device_id: str,
        latitude: float,
        longitude: float,
        status_code: int,
        packet_timestamp: int,
        rssi: int,
        delivered_by: str,
        hop_count: int,
        received_at: str,
        evidence_state: str = "unverified-mobile-report";
}


obj DisasterEventView {
    has disaster_id: str,
        source: str,
        event_type: str,
        severity: str,
        title: str,
        area: str,
        occurred_at: str,
        detail_url: str;
}

obj DisasterFeedView {
    has refreshed_at: str,
        source_status: str,
        total: int,
        earthquake_count: int,
        weather_count: int,
        severe_count: int,
        events: list[DisasterEventView];
}


obj CloudRelayReceipt {
    has success: bool,
        is_new: bool,
        message_id: str,
        received_at: str,
        message: str,
        evidence_state: str = "unverified-mobile-report";
}


obj MobileRelaySignalView {
    has message_id: str,
        origin_device_id: str,
        latitude: float,
        longitude: float,
        status_code: int,
        packet_timestamp: int,
        rssi: int,
        delivered_by: str,
        hop_count: int,
        received_at: str,
        evidence_state: str;
}


obj MobileRelayFeedView {
    has checked_at: str,
        total: int,
        signals: list[MobileRelaySignalView];
}


def:pub cloud_relay_health -> dict[str, object] {
    return {
        "accepting": True,
        "service": "SafeRelay Jac cloud relay",
        "evidenceState": "unverified-mobile-report",
    };
}


def:pub ingest_mobile_signal(  # jac:ignore[W3030]
    message_id: str,
    origin_device_id: str,
    latitude: float,
    longitude: float,
    status_code: int,
    packet_timestamp: int,
    rssi: int,
    delivered_by: str,
    hop_count: int,
) -> CloudRelayReceipt {
    received_at: str = datetime.datetime.now(datetime.timezone.utc).isoformat();
    valid: bool = (
        len(message_id) > 0
        and len(message_id) <= 64
        and len(origin_device_id) > 0
        and len(origin_device_id) <= 64
        and len(delivered_by) > 0
        and len(delivered_by) <= 64
        and latitude >= -90.0
        and latitude <= 90.0
        and longitude >= -180.0
        and longitude <= 180.0
        and status_code >= 0
        and status_code <= 5
        and packet_timestamp >= 0
        and packet_timestamp <= 4294967295
        and rssi >= -127
        and rssi <= 20
        and hop_count >= 0
        and hop_count <= 8
    );
    if not valid {
        return CloudRelayReceipt(
            success=False,
            is_new=False,
            message_id=message_id[:64],
            received_at=received_at,
            message="Signal payload failed validation.",
        );
    }

    for signal in [root.shared -->][?:MobileRelaySignal] {
        if signal.message_id == message_id {
            return CloudRelayReceipt(
                success=True,
                is_new=False,
                message_id=message_id,
                received_at=signal.received_at,
                message="Signal already stored.",
            );
        }
    }

    signal: MobileRelaySignal = root.shared ++> MobileRelaySignal(
        message_id=message_id,
        origin_device_id=origin_device_id,
        latitude=latitude,
        longitude=longitude,
        status_code=status_code,
        packet_timestamp=packet_timestamp,
        rssi=rssi,
        delivered_by=delivered_by,
        hop_count=hop_count,
        received_at=received_at,
    );
    grant(signal, level=ReadPerm);
    commit();
    return CloudRelayReceipt(
        success=True,
        is_new=True,
        message_id=message_id,
        received_at=received_at,
        message="Signal stored by the Jac cloud relay.",
    );
}


def _mobile_signal_sort_key(signal: MobileRelaySignal) -> str {
    return signal.received_at;
}


def _mobile_signal_view(signal: MobileRelaySignal) -> MobileRelaySignalView {
    return MobileRelaySignalView(
        message_id=signal.message_id,
        origin_device_id=signal.origin_device_id,
        latitude=signal.latitude,
        longitude=signal.longitude,
        status_code=signal.status_code,
        packet_timestamp=signal.packet_timestamp,
        rssi=signal.rssi,
        delivered_by=signal.delivered_by,
        hop_count=signal.hop_count,
        received_at=signal.received_at,
        evidence_state=signal.evidence_state,
    );
}


def:pub get_mobile_signal_feed(limit: int = 50) -> MobileRelayFeedView {
    safe_limit: int = max(1, min(100, limit));
    stored: list[MobileRelaySignal] = sorted(
        [root.shared -->][?:MobileRelaySignal],
        key=_mobile_signal_sort_key,
        reverse=True,
    );
    return MobileRelayFeedView(
        checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        total=len(stored),
        signals=[
            _mobile_signal_view(signal)
            for signal in stored[:safe_limit]
        ],
    );
}


def _empty_disaster_cache -> DisasterCache {
    cache: DisasterCache = root.shared ++> DisasterCache(
        refreshed_at="No successful source refresh",
        source_status="unavailable",
    );
    grant(cache, level=WritePerm);
    return cache;
}

def _disaster_feed(cache: DisasterCache) -> DisasterFeedView {
    events: list[DisasterEventView] = [];
    earthquake_count: int = 0;
    weather_count: int = 0;
    severe_count: int = 0;
    for item in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
        if item.event_type == "earthquake" { earthquake_count += 1; }
        if item.event_type == "weather" { weather_count += 1; }
        if item.severity.lower() in ["severe", "extreme", "major"] { severe_count += 1; }
        events.append(DisasterEventView(
            disaster_id=item.disaster_id,
            source=item.source,
            event_type=item.event_type,
            severity=item.severity,
            title=item.title,
            area=item.area,
            occurred_at=item.occurred_at,
            detail_url=item.detail_url,
        ));
    }
    return DisasterFeedView(
        refreshed_at=cache.refreshed_at,
        source_status=cache.source_status,
        total=len(events),
        earthquake_count=earthquake_count,
        weather_count=weather_count,
        severe_count=severe_count,
        events=events,
    );
}

def _remove_generated_legacy_events(cache: DisasterCache) -> bool {
    removed: bool = False;
    for event in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
        if "DEMO" in event.disaster_id.upper() or event.occurred_at == "Continuity snapshot" {
            cache del ->:DisasterCacheEvent:-> event;
            del event;
            removed = True;
        }
    }
    return removed;
}

def:pub get_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root.shared -->[?:DisasterCache]];
    cache: DisasterCache;
    if not caches {
        cache = _empty_disaster_cache();
        commit();
    } else {
        cache = caches[0];
    }
    if _remove_generated_legacy_events(cache) {
        cache.source_status = (
            "cached"
            if len([cache ->:DisasterCacheEvent:->[?:DisasterEvent]]) > 0
            else "unavailable"
        );
        cache.refreshed_at = (
            cache.refreshed_at
            if cache.source_status == "cached"
            else "No successful source refresh"
        );
        commit();
    }
    return _disaster_feed(cache);
}

def:pub refresh_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root.shared -->[?:DisasterCache]];
    cache: DisasterCache = caches[0] if caches else _empty_disaster_cache();
    fresh_events: list[dict[str, str]] = [];
    successful_sources: int = 0;
    failed_sources: int = 0;

    try {
        earthquake_request = urllib.request.Request(
            "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson",
            headers={"User-Agent": "SafeRelay/1.0"},
        );
        earthquake_response = urllib.request.urlopen(earthquake_request, timeout=6);
        earthquake_payload: dict = json.loads(
            earthquake_response.read().decode("utf-8")
        );
        successful_sources += 1;
        for raw_feature in (earthquake_payload.get("features") or [])[:20] {
            feature: dict[str, object] = dict(raw_feature);
            properties: dict[str, object] = dict(feature.get("properties") or {});
            magnitude: float = float(str(properties.get("mag") or 0));
            severity: str = "major" if magnitude >= 6 else ("severe" if magnitude >= 5 else "moderate");
            fresh_events.append({
                "id": str(feature.get("id") or f"USGS-{len(fresh_events)}"),
                "source": "USGS",
                "type": "earthquake",
                "severity": severity,
                "title": str(properties.get("title") or "USGS earthquake"),
                "area": str(properties.get("place") or "Location pending"),
                "occurred": str(properties.get("time") or ""),
                "url": str(properties.get("url") or "https://earthquake.usgs.gov/"),
            });
        }
    } except Exception {
        failed_sources += 1;
    }

    try {
        weather_request = urllib.request.Request(
            "https://api.weather.gov/alerts/active?severity=Severe,Extreme",
            headers={"User-Agent": "SafeRelay/1.0 operations@saferelay.local"},
        );
        weather_response = urllib.request.urlopen(weather_request, timeout=6);
        weather_payload: dict = json.loads(
            weather_response.read().decode("utf-8")
        );
        successful_sources += 1;
        for raw_feature in (weather_payload.get("features") or [])[:20] {
            feature: dict[str, object] = dict(raw_feature);
            properties: dict[str, object] = dict(feature.get("properties") or {});
            fresh_events.append({
                "id": str(feature.get("id") or f"NWS-{len(fresh_events)}"),
                "source": "NWS",
                "type": "weather",
                "severity": str(properties.get("severity") or "unknown").lower(),
                "title": str(properties.get("headline") or properties.get("event") or "NWS alert"),
                "area": str(properties.get("areaDesc") or "Area pending"),
                "occurred": str(properties.get("effective") or ""),
                "url": str(properties.get("@id") or "https://www.weather.gov/alerts"),
            });
        }
    } except Exception {
        failed_sources += 1;
    }

    if successful_sources == 0 {
        cache.source_status = (
            "cached"
            if len([cache ->:DisasterCacheEvent:->[?:DisasterEvent]]) > 0
            else "unavailable"
        );
        if cache.source_status == "unavailable" {
            cache.refreshed_at = "No successful source refresh";
        }
    } else {
        for event in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
            cache del ->:DisasterCacheEvent:-> event;
            del event;
        }
        for item in fresh_events {
            event: DisasterEvent = DisasterEvent(
                disaster_id=item["id"],
                source=item["source"],
                event_type=item["type"],
                severity=item["severity"],
                title=item["title"],
                area=item["area"],
                occurred_at=item["occurred"],
                detail_url=item["url"],
            );
            cache +>:DisasterCacheEvent():+> event;
            grant(event, level=WritePerm);
        }
        cache.refreshed_at = "Latest successful USGS/NWS server refresh";
        cache.source_status = "partial" if failed_sources > 0 else "live";
    }
    commit();
    return _disaster_feed(cache);
}
