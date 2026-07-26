"""Evidence-boundary tests for the SafeRelay public hazard feed."""

import from .store {
    DisasterCache,
    DisasterCacheEvent,
    DisasterEvent,
    get_disaster_feed,
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
