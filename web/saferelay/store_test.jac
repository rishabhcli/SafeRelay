"""Evidence-boundary tests for the SafeRelay public hazard feed."""

import from .store {
    DisasterCache,
    DisasterCacheEvent,
    DisasterEvent,
    MobileRelaySignal,
    cloud_relay_health,
    get_disaster_feed,
    get_mobile_signal_feed,
    ingest_mobile_signal,
}


def _clear_disaster_cache {
    for cache in [root -->[?:DisasterCache]] {
        for event in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
            cache del ->:DisasterCacheEvent:-> event;
            del event;
        }
        root del --> cache;
        del cache;
    }
    commit();
}


def _clear_mobile_signals {
    for signal in [root -->][?:MobileRelaySignal] {
        root del --> signal;
        del signal;
    }
    commit();
}


test "cloud relay health declares its evidence boundary" {
    health = cloud_relay_health();
    assert health["accepting"];
    assert health["service"] == "SafeRelay Jac cloud relay";
    assert health["evidenceState"] == "unverified-mobile-report";
}


test "mobile signal ingestion is durable and idempotent" {
    _clear_mobile_signals();
    first = ingest_mobile_signal(
        "00abc123_7",
        "00abc123",
        34.0522,
        -118.2437,
        2,
        1785100000,
        -64,
        "00def456",
        1,
    );
    duplicate = ingest_mobile_signal(
        "00abc123_7",
        "00abc123",
        34.0522,
        -118.2437,
        2,
        1785100000,
        -64,
        "00def456",
        1,
    );

    assert first.success;
    assert first.is_new;
    assert duplicate.success;
    assert not duplicate.is_new;
    assert len([root -->][?:MobileRelaySignal]) == 1;
}


test "mobile signal feed exposes stored evidence newest first" {
    _clear_mobile_signals();
    first = ingest_mobile_signal(
        "feed-older",
        "phone-a",
        37.8044,
        -122.2712,
        1,
        1700000000,
        -75,
        "phone-b",
        1,
    );
    second = ingest_mobile_signal(
        "feed-newer",
        "phone-c",
        37.8050,
        -122.2700,
        2,
        1700000010,
        -68,
        "phone-d",
        2,
    );
    feed = get_mobile_signal_feed(1);

    assert first.success and second.success;
    assert feed.total == 2;
    assert len(feed.signals) == 1;
    assert feed.signals[0].message_id == "feed-newer";
    assert feed.signals[0].evidence_state == "unverified-mobile-report";
}


test "invalid mobile signals do not enter the cloud graph" {
    _clear_mobile_signals();
    receipt = ingest_mobile_signal(
        "invalid",
        "00abc123",
        120.0,
        -118.2437,
        9,
        1785100000,
        -64,
        "00def456",
        1,
    );

    assert not receipt.success;
    assert len([root -->][?:MobileRelaySignal]) == 0;
}


test "unavailable sources remain an honest empty state" {
    _clear_disaster_cache();
    feed = get_disaster_feed();
    assert feed.total == 0;
    assert feed.earthquake_count == 0;
    assert feed.weather_count == 0;
    assert feed.severe_count == 0;
    assert feed.source_status == "unavailable";
}

test "legacy generated continuity records are purged" {
    _clear_disaster_cache();
    cache: DisasterCache = root ++> DisasterCache(
        refreshed_at="Continuity snapshot",
        source_status="cached",
    );
    cache +>:DisasterCacheEvent():+> DisasterEvent(
        disaster_id="USGS-DEMO",
        source="USGS",
        event_type="earthquake",
        severity="major",
        title="Legacy generated record",
        area="Unknown",
        occurred_at="Continuity snapshot",
    );
    commit();

    feed = get_disaster_feed();
    assert feed.total == 0;
    assert feed.source_status == "unavailable";
    assert feed.refreshed_at == "No successful source refresh";
}
