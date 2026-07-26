"""SafeRelay full-stack entry point."""

import from saferelay.store {
    DisasterEventView,
    DisasterFeedView,
    get_disaster_feed as _get_disaster_feed,
    refresh_disaster_feed as _refresh_disaster_feed,
}


def:priv get_disaster_feed -> DisasterFeedView {
    return _get_disaster_feed();
}

def:priv refresh_disaster_feed -> DisasterFeedView {
    return _refresh_disaster_feed();
}


cl {
    import ".styles.global.css";
    import from .saferelay.AppShell { SafeRelayApp }

    def:pub app -> JsxElement {
        return <SafeRelayApp />;
    }
}
