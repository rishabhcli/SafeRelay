"""Evidence-scoped SafeRelay operations surface with no generated live state."""

import from "@jac/runtime" { Link, jacLogout, useNavigate }
import from "react" { useEffect }
import from "mapbox-gl" {
    Map as MapboxMap,
    Marker as MapboxMarker,
    NavigationControl,
}
import from "lucide-react" {
    Activity,
    Cloud,
    Database,
    ExternalLink,
    LogOut,
    Map as MapIcon,
    Radio,
    RefreshCw,
    ShieldCheck,
    Waypoints,
    Wind,
}

sv import from .store {
    DisasterFeedView,
    get_disaster_feed,
    refresh_disaster_feed,
}

glob MAPBOX_ACCESS_TOKEN: str = str(__MAPBOX_ACCESS_TOKEN__);  # jac:ignore[W2001]
glob _document: any = document;  # jac:ignore[W1037, W2001]


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

    navigate = useNavigate();

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
                disaster_feed = await get_disaster_feed();
            } except Exception {}
            if disaster_feed and disaster_feed.source_status in ["live", "partial"] {
                notice = "";
                notice_error = False;
            } elif disaster_feed and disaster_feed.source_status == "cached" {
                notice = "Public sources are unavailable. Previously verified records are shown as cached.";
                notice_error = False;
            } else {
                notice = "Public sources could not be reached. No replacement data was generated.";
                notice_error = True;
            }
        }
        refreshing = False;
    }

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

    def handle_logout(_event: MouseEvent) {
        jacLogout();
        navigate("/login");
    }

    feed: DisasterFeedView | None = disaster_feed;
    visible_notice: str = (
        ""
        if feed and feed.source_status in ["live", "partial"]
        else notice
    );
    return <div className="verified-ops">
        <header className="verified-ops-header">
            <Link to="/" className="brand-lockup brand-lockup--ops">
                <span className="brand-mark"><Waypoints size={20} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <div className="verified-ops-title">
                <span>OPERATIONS EVIDENCE</span>
                <h1>Verified source monitor</h1>
            </div>
            <button className="button button--outline" onClick={handle_logout}>
                <LogOut size={15} /> Sign out
            </button>
        </header>

        <main className="verified-ops-main">
            <section className="verified-boundary-banner">
                <ShieldCheck size={20} />
                <div>
                    <strong>No generated operational state</strong>
                    <p>Relay reports, receipts, responder acknowledgements, and outcomes appear only after their own evidence exists.</p>
                </div>
            </section>

            {if visible_notice {
                <div className={"notice notice--error" if notice_error else "notice"}>{visible_notice}</div>
            }}

            <section className="verified-evidence-grid">
                <article className="panel verified-empty-panel">
                    <header className="panel__header">
                        <div><span className="eyebrow">RELAY REPORTS</span><h2>Device evidence</h2></div>
                        <Radio size={18} />
                    </header>
                    <div className="verified-empty-state">
                        <Database size={24} />
                        <strong>No verified relay reports</strong>
                        <span>The web console has not received a device-backed packet record.</span>
                    </div>
                </article>
                <article className="panel verified-empty-panel">
                    <header className="panel__header">
                        <div><span className="eyebrow">DELIVERY PROOF</span><h2>Receipts and outcomes</h2></div>
                        <Cloud size={18} />
                    </header>
                    <div className="verified-proof-list">
                        <div><span>Server receipt</span><strong>Unknown</strong></div>
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
