"""Evidence-scoped SafeRelay operations surface with no generated live state."""

import from "@jac/runtime" { Link }
import from "react" { useEffect }
import from "mapbox-gl" {
    Map as MapboxMap,
    Marker as MapboxMarker,
    NavigationControl,
}
import from "lucide-react" {
    Activity,
    ArrowLeft,
    BellRing,
    Clock3,
    Cloud,
    Database,
    ExternalLink,
    MapPin,
    Map as MapIcon,
    Radio,
    RefreshCw,
    Route as RouteIcon,
    ShieldCheck,
    Waypoints,
    Wind,
    X,
}

sv import from .store {
    DisasterFeedView,
    MobileRelayFeedView,
    MobileRelaySignalView,
    get_disaster_feed,
    get_mobile_signal_feed,
    refresh_disaster_feed,
}

glob MAPBOX_ACCESS_TOKEN: str = str(__MAPBOX_ACCESS_TOKEN__);  # jac:ignore[W2001]
glob _document: any = document;  # jac:ignore[W1037, W2001]


def relay_status_label(status_code: int) -> str {
    if status_code == 0 { return "SAFE"; }
    if status_code == 1 { return "RESCUE NEEDED"; }
    if status_code == 2 { return "MEDICAL EMERGENCY"; }
    if status_code == 3 { return "PERSON TRAPPED"; }
    if status_code == 4 { return "SUPPLIES NEEDED"; }
    if status_code == 5 { return "SHELTER REPORT"; }
    return "UNKNOWN REPORT";
}


def relay_status_instruction(status_code: int) -> str {
    if status_code == 1 { return "Immediate rescue was requested."; }
    if status_code == 2 { return "A device reported a medical emergency."; }
    if status_code == 3 { return "A device reported a trapped or pinned person."; }
    if status_code == 4 { return "A device requested water, food, or supplies."; }
    if status_code == 5 { return "A device submitted shelter status evidence."; }
    return "The originating device reported that it is safe.";
}


def:pub SyntheticEvidenceMap -> JsxElement {
    has map_container_ref: Ref[HTMLDivElement] = Ref();
    has map_ref: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has marker_refs: Ref[list[any]] = Ref([]);  # jac:ignore[W1037]

    artifacts: list[dict[str, any]] = [  # jac:ignore[W1037]
        {
            "label": "MAP ARTIFACT · RESCUE",
            "longitude": -122.2820,
            "latitude": 37.8060,
            "tone": "critical",
        },
        {
            "label": "MAP ARTIFACT · MEDICAL",
            "longitude": -122.2570,
            "latitude": 37.8210,
            "tone": "warning",
        },
        {
            "label": "MAP ARTIFACT · SUPPLIES",
            "longitude": -122.2390,
            "latitude": 37.7930,
            "tone": "info",
        },
    ];

    useEffect(
        lambda {
            if not map_container_ref.current or not MAPBOX_ACCESS_TOKEN {
                return;
            }
            map_instance: any = new(  # jac:ignore[W1037]
                MapboxMap,
                {
                    "accessToken": MAPBOX_ACCESS_TOKEN,
                    "container": map_container_ref.current,
                    "style": "mapbox://styles/mapbox/dark-v11",
                    "center": [-122.2630, 37.8060],
                    "zoom": 12.2,
                    "minZoom": 2.0,
                    "maxZoom": 18.0,
                    "dragRotate": False,
                },
            );
            map_instance.addControl(
                new(NavigationControl, {"showCompass": False}),
                "top-right",
            );
            map_ref.current = map_instance;
            next_markers: list[any] = [];  # jac:ignore[W1037]
            for artifact in artifacts {
                marker_element: any = _document.createElement("div");  # jac:ignore[W1037]
                marker_element.className = "verified-map-artifact verified-map-artifact--" + str(artifact["tone"]);
                marker_element.setAttribute("aria-label", str(artifact["label"]));
                marker_element.textContent = "MAP";
                marker: any = new(  # jac:ignore[W1037]
                    MapboxMarker,
                    {"element": marker_element, "anchor": "center"},
                );
                marker.setLngLat([
                    float(artifact["longitude"]),
                    float(artifact["latitude"]),
                ]);
                marker.addTo(map_instance);
                next_markers.append(marker);
            }
            marker_refs.current = next_markers;
            return lambda {
                for marker in next_markers {
                    marker.remove();
                }
                map_instance.remove();
                map_ref.current = None;
            };
        },
        [],
    );

    return <section className="panel verified-map-panel">
        <header className="panel__header">
            <div>
                <span className="eyebrow">SYNTHETIC MAP LAYER</span>
                <h2>Map artifacts</h2>
            </div>
            <span className="verified-source-state verified-source-state--artifact">NOT REPORTS</span>
        </header>
        <div className="verified-map-frame">
            <div ref={map_container_ref} className="verified-map-canvas"></div>
            <div className="verified-map-watermark">SYNTHETIC MAP ARTIFACTS</div>
            {if not MAPBOX_ACCESS_TOKEN {
                <div className="verified-map-unavailable">
                    <MapIcon size={20} />
                    <span>Map unavailable</span>
                </div>
            }}
        </div>
        <p className="verified-boundary">
            These markers exist only to exercise map interaction. They are not people,
            incidents, device reports, or responder activity.
        </p>
    </section>;
}


def:pub VerifiedCommandCenter -> JsxElement {
    has disaster_feed: DisasterFeedView | None = None;
    has refreshing: bool = True;
    has notice: str = "";
    has notice_error: bool = False;
    has relay_feed: MobileRelayFeedView | None = None;
    has relay_error: str = "";
    has active_relay_alert: MobileRelaySignalView | None = None;
    has dismissed_alert_ids: Ref[list[str]] = Ref([]);
    has presented_alert_id: Ref[str] = Ref("");

    async def refresh_mobile_signals {
        try {
            latest_feed: MobileRelayFeedView = await get_mobile_signal_feed(50);
            relay_feed = latest_feed;
            relay_error = "";
            if len(latest_feed.signals) > 0 {
                latest_signal: MobileRelaySignalView = latest_feed.signals[0];
                should_present: bool = (
                    latest_signal.status_code != 0
                    and latest_signal.message_id not in dismissed_alert_ids.current
                    and latest_signal.message_id != presented_alert_id.current
                );
                if should_present {
                    active_relay_alert = latest_signal;
                    presented_alert_id.current = latest_signal.message_id;
                }
            }
        } except Exception {
            relay_error = "Mobile relay feed is temporarily unreachable.";
        }
    }

    def dismiss_relay_alert(_event: MouseEvent) {
        if active_relay_alert {
            dismissed_alert_ids.current = (
                dismissed_alert_ids.current
                + [active_relay_alert.message_id]
            )[-100:];
        }
        active_relay_alert = None;
    }

    async can with entry {
        try {
            disaster_feed = await refresh_disaster_feed();
            notice = "";
            notice_error = False;
            if disaster_feed.source_status == "unavailable" {
                notice = "USGS and NWS are unavailable. No replacement data was generated.";
                notice_error = True;
            } elif disaster_feed.source_status == "cached" {
                notice = "Public sources are unavailable. Previously verified records are shown as cached.";
            }
        } except Exception {
            try {
                fallback_feed: DisasterFeedView = await get_disaster_feed();
                disaster_feed = fallback_feed;
                if fallback_feed.source_status in ["live", "partial"] {
                    notice = "";
                    notice_error = False;
                } elif fallback_feed.source_status == "cached" {
                    notice = "Public sources are unavailable. Previously verified records are shown as cached.";
                    notice_error = False;
                } else {
                    notice = "Public sources could not be reached. No replacement data was generated.";
                    notice_error = True;
                }
            } except Exception {
                notice = "Public sources could not be reached. No replacement data was generated.";
                notice_error = True;
            }
        }
        refreshing = False;
    }

    async can with entry {
        await refresh_mobile_signals();
    }

    useEffect(lambda {
        relay_poll = setInterval(
            lambda { refresh_mobile_signals(); },
            2000,
        );
        return lambda { clearInterval(relay_poll); };
    }, []);

    async def handle_refresh(_event: MouseEvent) {
        refreshing = True;
        notice = "";
        notice_error = False;
        try {
            disaster_feed = await refresh_disaster_feed();
            notice = "";
            notice_error = False;
            if disaster_feed.source_status == "unavailable" {
                notice = "USGS and NWS are unavailable. No replacement data was generated.";
                notice_error = True;
            } elif disaster_feed.source_status == "cached" {
                notice = "Public sources are unavailable. Previously verified records are shown as cached.";
            } else {
                notice = "Government-source records refreshed.";
            }
        } except Exception {
            notice = "Refresh failed. Existing verified records, if any, were retained.";
            notice_error = True;
        }
        refreshing = False;
    }

    feed: DisasterFeedView | None = disaster_feed;
    mobile_feed: MobileRelayFeedView | None = relay_feed;
    latest_mobile_signal: MobileRelaySignalView | None = (
        mobile_feed.signals[0]
        if mobile_feed and len(mobile_feed.signals) > 0
        else None
    );
    visible_notice: str = (
        ""
        if feed and feed.source_status in ["live", "partial"]
        else notice
    );
    return <div className="verified-ops">
        {if active_relay_alert {
            <div className="relay-alert-backdrop">
                <section
                    className="relay-alert-dialog"
                    role="alertdialog"
                    aria-modal="true"
                    aria-labelledby="relay-alert-title"
                    aria-describedby="relay-alert-description"
                >
                    <div className="relay-alert-beacon" aria-hidden="true">
                        <span></span><BellRing size={34} /><span></span>
                    </div>
                    <div className="relay-alert-kicker">
                        <span>LIVE MOBILE RELAY</span>
                        <strong>SERVER RECEIPT STORED</strong>
                    </div>
                    <h2 id="relay-alert-title">
                        {relay_status_label(active_relay_alert.status_code)}
                    </h2>
                    <p id="relay-alert-description">
                        {relay_status_instruction(active_relay_alert.status_code)}
                    </p>
                    <div className="relay-alert-facts">
                        <div>
                            <MapPin size={17} />
                            <span>LOCATION</span>
                            <strong>
                                {f"{active_relay_alert.latitude:.5f}, {active_relay_alert.longitude:.5f}"}
                            </strong>
                        </div>
                        <div>
                            <RouteIcon size={17} />
                            <span>RELAY PATH</span>
                            <strong>
                                {str(active_relay_alert.hop_count) + " hop · " + active_relay_alert.delivered_by}
                            </strong>
                        </div>
                        <div>
                            <Clock3 size={17} />
                            <span>RECEIVED</span>
                            <strong>{active_relay_alert.received_at}</strong>
                        </div>
                    </div>
                    <p className="relay-alert-boundary">
                        This is device-backed report evidence. Responder acknowledgement
                        and rescue outcome remain unknown.
                    </p>
                    <button
                        id="dismiss-relay-alert"
                        className="relay-alert-dismiss"
                        onClick={dismiss_relay_alert}
                    >
                        <X size={18} /> Dismiss alert
                    </button>
                </section>
            </div>
        }}
        <header className="verified-ops-header">
            <Link to="/" className="brand-lockup brand-lockup--ops">
                <span className="brand-mark"><Waypoints size={20} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <div className="verified-ops-title">
                <span>OPERATIONS EVIDENCE</span>
                <h1>Verified source monitor</h1>
            </div>
            <Link to="/" className="button button--outline">
                <ArrowLeft size={15} /> Overview
            </Link>
        </header>

        <main className="verified-ops-main">
            <section className="verified-boundary-banner">
                <ShieldCheck size={20} />
                <div>
                    <strong>No generated operational state</strong>
                    <p>Relay reports, receipts, responder acknowledgements, and outcomes appear only after their own evidence exists.</p>
                </div>
                <span className={"relay-connection relay-connection--error" if relay_error else "relay-connection"}>
                    <span></span>{relay_error if relay_error else "CLOUD RELAY LIVE"}
                </span>
            </section>

            {if visible_notice {
                <div className={"notice notice--error" if notice_error else "notice"}>{visible_notice}</div>
            }}

            <section className="verified-evidence-grid">
                <article className="panel verified-empty-panel">
                    <header className="panel__header">
                        <div><span className="eyebrow">RELAY REPORTS</span><h2>Device evidence</h2></div>
                        <span className="verified-signal-count">
                            <Radio size={18} />
                            {str(mobile_feed.total) if mobile_feed else "0"}
                        </span>
                    </header>
                    {if not mobile_feed or len(mobile_feed.signals) == 0 {
                        <div className="verified-empty-state">
                            <Database size={24} />
                            <strong>No received relay reports</strong>
                            <span>The cloud has not stored a device-backed packet record.</span>
                        </div>
                    } else {
                        <div className="verified-signal-list">
                            {for signal in mobile_feed.signals[:6] {
                                <article key={signal.message_id} className={"is-safe" if signal.status_code == 0 else "is-distress"}>
                                    <span className="verified-signal-pulse"></span>
                                    <div>
                                        <span>{relay_status_label(signal.status_code)}</span>
                                        <strong>{signal.message_id}</strong>
                                        <small>
                                            {f"{signal.latitude:.5f}, {signal.longitude:.5f}"}
                                        </small>
                                    </div>
                                    <div>
                                        <span>{str(signal.hop_count) + " hop"}</span>
                                        <small>{signal.received_at}</small>
                                    </div>
                                </article>
                            }}
                        </div>
                    }}
                </article>
                <article className="panel verified-empty-panel">
                    <header className="panel__header">
                        <div><span className="eyebrow">DELIVERY PROOF</span><h2>Receipts and outcomes</h2></div>
                        <Cloud size={18} />
                    </header>
                    <div className="verified-proof-list">
                        <div>
                            <span>Server receipt</span>
                            <strong className={"" if latest_mobile_signal else "is-unknown"}>
                                {"Stored" if latest_mobile_signal else "Unknown"}
                            </strong>
                        </div>
                        {if latest_mobile_signal {
                            <small className="verified-receipt-detail">
                                {latest_mobile_signal.message_id + " · " + latest_mobile_signal.received_at}
                            </small>
                        }}
                        <div><span>Responder acknowledgement</span><strong>Unknown</strong></div>
                        <div><span>Rescue outcome</span><strong>Unknown</strong></div>
                    </div>
                </article>
            </section>

            <SyntheticEvidenceMap />

            <section className="panel verified-feed-panel">
                <header className="panel__header">
                    <div><span className="eyebrow">PUBLIC HAZARD SOURCES</span><h2>USGS and NWS records</h2></div>
                    <button className="button button--outline" onClick={handle_refresh} disabled={refreshing}>
                        <RefreshCw className={"spin" if refreshing else ""} size={15} />
                        Refresh
                    </button>
                </header>
                {if not feed {
                    <div className="verified-empty-state">
                        <Cloud size={24} />
                        <strong>Source status unavailable</strong>
                        <span>No hazard records are being shown.</span>
                    </div>
                } else {
                    <div className="verified-feed-meta">
                        <span className={"verified-source-state verified-source-state--live" if feed.source_status == "live" else "verified-source-state"}>
                            {feed.source_status}
                        </span>
                        <span>{feed.refreshed_at}</span>
                        <strong>{feed.total} source records</strong>
                    </div>
                    if len(feed.events) == 0 {
                        <div className="verified-empty-state">
                            <Cloud size={24} />
                            <strong>No source records available</strong>
                            <span>SafeRelay did not substitute examples or continuity fixtures.</span>
                        </div>
                    } else {
                        <div className="verified-feed-list">
                            {for event in feed.events {
                                <article key={event.disaster_id}>
                                    <span className="verified-feed-icon">
                                        {if event.event_type == "earthquake" { <Activity size={17} />; } else { <Wind size={17} />; }}
                                    </span>
                                    <div>
                                        <span>{event.source + " · " + event.severity}</span>
                                        <strong>{event.title}</strong>
                                        <p>{event.area}</p>
                                        <small>{event.occurred_at}</small>
                                    </div>
                                    <a href={event.detail_url} target="_blank" rel="noreferrer" title="Open source record" aria-label="Open source record">
                                        <ExternalLink size={16} />
                                    </a>
                                </article>
                            }}
                        </div>
                    }
                }}
            </section>
        </main>
    </div>;
}
