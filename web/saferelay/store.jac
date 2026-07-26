"""Persistent public-source hazard evidence for SafeRelay operations."""

import json;
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


def _empty_disaster_cache -> DisasterCache {
    return root ++> DisasterCache(
        refreshed_at="No successful source refresh",
        source_status="unavailable",
    );
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

def:protect get_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root -->[?:DisasterCache]];
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

def:protect refresh_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root -->[?:DisasterCache]];
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
        }
        cache.refreshed_at = "Latest successful USGS/NWS server refresh";
        cache.source_status = "partial" if failed_sources > 0 else "live";
    }
    commit();
    return _disaster_feed(cache);
}
