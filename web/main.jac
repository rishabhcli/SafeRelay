"""SafeRelay full-stack entry point."""

import from saferelay.store {
    CloudRelayReceipt,
    DisasterEventView,
    DisasterFeedView,
    cloud_relay_health as _cloud_relay_health,
    get_disaster_feed as _get_disaster_feed,
    ingest_mobile_signal as _ingest_mobile_signal,
    refresh_disaster_feed as _refresh_disaster_feed,
}


def:pub cloud_relay_health -> dict[str, object] {
    return _cloud_relay_health();
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
    return _ingest_mobile_signal(
        message_id,
        origin_device_id,
        latitude,
        longitude,
        status_code,
        packet_timestamp,
        rssi,
        delivered_by,
        hop_count,
    );
}

def:pub get_disaster_feed -> DisasterFeedView {
    return _get_disaster_feed();
}

def:pub refresh_disaster_feed -> DisasterFeedView {
    return _refresh_disaster_feed();
}


cl {
    import ".styles.global.css";
    import from .saferelay.AppShell { SafeRelayApp }

    def:pub app -> JsxElement {
        return <SafeRelayApp />;
    }
}
