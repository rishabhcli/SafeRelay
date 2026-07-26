"""SafeRelay operator command center authored in client Jac."""

import from "@jac/runtime" { Link, jacLogout, useNavigate }
import from "react" { useEffect, useRef }
import from "lucide-react" {
    Activity,
    Archive,
    ArrowLeft,
    BarChart3,
    Bell,
    BellOff,
    Bot,
    BookOpen,
    Check,
    ChevronRight,
    CircleGauge,
    ClipboardCheck,
    Cloud,
    Clock3,
    Crosshair,
    Database,
    Download,
    FileCheck,
    GitCompare,
    HeartPulse,
    History,
    LayoutDashboard,
    List,
    LocateFixed,
    LogOut,
    Map,
    Network,
    Pause,
    Play,
    Radio,
    RefreshCw,
    Route,
    Save,
    Search,
    Send,
    Settings,
    ShieldCheck,
    Signal,
    Siren,
    SlidersHorizontal,
    Sparkles,
    Table2,
    Trash2,
    TriangleAlert,
    Upload,
    Users,
    Volume2,
    VolumeX,
    Waypoints,
    Wifi,
    WifiOff,
    Wind,
    X,
}

sv import from .store {
    ActivityView,
    AgentBriefing,
    AlertView,
    DisasterFeedView,
    DrillHandoffView,
    DrillReviewView,
    DrillWorkspace,
    OpsSnapshot,
    RelayHopView,
    ReplaySnapshot,
    ResponderView,
    RunComparisonView,
    TraceRelay,
    ZoneView,
    acknowledge_alert,
    advance_drill,
    analyze_incident,
    apply_scenario_preset,
    archive_scenario_run,
    assign_responder,
    cancel_alert,
    compare_scenario_runs,
    configure_drill,
    create_drill_handoff,
    delete_scenario_preset,
    delete_scenario_run,
    get_disaster_feed,
    get_drill_workspace,
    get_run_replay,
    get_snapshot,
    import_scenario_preset,
    refresh_disaster_feed,
    reset_drill,
    resolve_alert,
    save_scenario_preset,
    sign_drill_review,
    update_drill_handoff,
    update_drill_runtime,
}


def priority_class(priority: str) -> str {
    return f"priority priority--{priority}";
}

def status_class(status: str) -> str {
    return f"status-pill status-pill--{status}";
}


def:pub StatTile(
    label: str,
    value: str,
    detail: str,
    tone: str,
    children: JsxElement | None = None,
) -> JsxElement {
    return <article className={"stat-tile " + tone}>
        <div className="stat-tile__label">{children}<span>{label}</span></div>
        <strong>{value}</strong>
        <small>{detail}</small>
    </article>;
}


def:pub AlertMapPanel(
    alerts: list[AlertView],
    selected_id: str,
    on_select: Callable[[str], None],
) -> JsxElement {
    return <section className="panel map-panel">
        <header className="panel__header">
            <div><span className="eyebrow">INCIDENT MAP</span><h2>Mesh delivery surface</h2></div>
            <div className="map-legend">
                <span><span className="legend-dot legend-dot--critical"></span> Critical</span>
                <span><span className="legend-dot legend-dot--mesh"></span> Mesh node</span>
            </div>
        </header>
        <div className="ops-map">
            <div className="ops-map__grid"></div>
            <div className="ops-map__road ops-map__road--one"></div>
            <div className="ops-map__road ops-map__road--two"></div>
            <div className="ops-map__water"></div>
            <span className="ops-map__label ops-map__label--north">NORTH RIDGE</span>
            <span className="ops-map__label ops-map__label--east">EAST RIDGE</span>
            <span className="ops-map__label ops-map__label--canyon">CANYON</span>
            <span className="ops-map__label ops-map__label--lake">LAKE</span>
            {for alert in alerts {
                <button
                    key={alert.alert_id}
                    className={
                        f"alert-pin alert-pin--{alert.priority} is-selected"
                        if alert.alert_id == selected_id
                        else f"alert-pin alert-pin--{alert.priority}"
                    }
                    style={{"left": f"{alert.map_x}%", "top": f"{alert.map_y}%"}}
                    onClick={lambda (_e: MouseEvent) { on_select(alert.alert_id); }}
                    aria-label={f"Select {alert.alert_id}, {alert.priority} {alert.emergency_type}"}
                >
                    <span></span>
                    <small>{alert.alert_id}</small>
                </button>
            }}
            <div className="gateway gateway--alpha"><Wifi size={15} /><span>GW-A</span></div>
            <div className="gateway gateway--bravo"><Wifi size={15} /><span>GW-B</span></div>
            <div className="map-scale"><span></span> 1 KM</div>
        </div>
    </section>;
}


def:pub AlertQueue(
    alerts: list[AlertView],
    selected_id: str,
    on_select: Callable[[str], None],
) -> JsxElement {
    return <section className="panel alert-queue">
        <header className="panel__header">
            <div><span className="eyebrow">TRIAGE QUEUE</span><h2>Incoming signals</h2></div>
            <span className="queue-count">{len([a for a in alerts if a.status != "resolved"])} active</span>
        </header>
        <div className="alert-list">
            {for alert in alerts {
                <button
                    key={alert.alert_id}
                    className={"alert-row is-selected" if alert.alert_id == selected_id else "alert-row"}
                    onClick={lambda (_e: MouseEvent) { on_select(alert.alert_id); }}
                >
                    <span className={priority_class(alert.priority)}>
                        {if alert.priority == "critical" { <Siren size={14} />; }
                        else { <Radio size={14} />; }}
                    </span>
                    <span className="alert-row__main">
                        <span><strong>{alert.alert_id}</strong><em>{alert.received_at}</em></span>
                        <strong className="alert-row__type">{alert.emergency_type} · {alert.zone}</strong>
                        <small>{alert.message}</small>
                    </span>
                    <span className="alert-row__meta">
                        <span className={status_class(alert.status)}>{alert.status}</span>
                        <small>{alert.hop_count} hops</small>
                    </span>
                    <ChevronRight size={16} />
                </button>
            }}
        </div>
    </section>;
}


def:pub RelayTrace(hops: list[RelayHopView]) -> JsxElement {
    return <div className="relay-trace">
        {if len(hops) == 0 {
            <div className="empty-inline"><RefreshCw size={16} /> Loading relay path</div>;
        } else {
            for hop in hops {
                <div className="relay-hop" key={hop.device_id}>
                    <span className={"hop-icon hop-icon--gateway" if hop.had_internet else "hop-icon"}>
                        {if hop.had_internet { <Wifi size={15} />; } else { <Radio size={15} />; }}
                    </span>
                    <div>
                        <strong>{hop.device_id}</strong>
                        <small>{hop.label}</small>
                    </div>
                    <div className="hop-signal">
                        <span>{hop.rssi} dBm</span>
                        <small>{hop.battery}% battery</small>
                    </div>
                    {if hop.hop_order < len(hops) { <ChevronRight className="hop-arrow" size={15} />; }}
                </div>
            }
        }}
    </div>;
}


def:pub ZoneTable(zones: list[ZoneView]) -> JsxElement {
    return <section className="panel compact-panel">
        <header className="panel__header">
            <div><span className="eyebrow">NETWORK ZONES</span><h2>Coverage health</h2></div>
            <Network size={18} />
        </header>
        <div className="zone-table">
            {for zone in zones {
                <div className="zone-row" key={zone.name}>
                    <div><strong>{zone.name}</strong><small>{zone.gateway}</small></div>
                    <div className="health-meter"><span style={{"width": f"{zone.health}%"}}></span></div>
                    <strong className="zone-health-value">{zone.health}%</strong>
                    <span>{zone.nodes_online} nodes</span>
                    <em>{zone.alerts} alerts</em>
                </div>
            }}
        </div>
    </section>;
}


def:pub ResponderRoster(responders: list[ResponderView]) -> JsxElement {
    return <section className="panel compact-panel">
        <header className="panel__header">
            <div><span className="eyebrow">FIELD TEAMS</span><h2>Responder status</h2></div>
            <Users size={18} />
        </header>
        <div className="responder-grid">
            {for responder in responders {
                <article key={responder.responder_id}>
                    <span className={"avatar is-deployed" if responder.status == "deployed" else "avatar"}>
                        {responder.name[0]}
                    </span>
                    <div><strong>{responder.name}</strong><small>{responder.role}</small></div>
                    <span className={status_class(responder.status)}>{responder.status}</span>
                    <em>{responder.eta_minutes} min · {responder.zone}</em>
                </article>
            }}
        </div>
    </section>;
}


def:pub ActivityFeed(events: list[ActivityView]) -> JsxElement {
    return <section className="panel compact-panel activity-panel">
        <header className="panel__header">
            <div><span className="eyebrow">EVENT GRAPH</span><h2>Recent activity</h2></div>
            <Activity size={18} />
        </header>
        <div className="activity-list">
            {for event in events {
                <div className={"activity-item activity-item--" + event.event_type} key={event.event_id}>
                    <span></span>
                    <time>{event.event_time}</time>
                    <p>{event.message}</p>
                </div>
            }}
        </div>
    </section>;
}

def:pub AlertTablePanel(
    alerts: list[AlertView],
    selected_id: str,
    on_select: Callable[[str], None],
) -> JsxElement {
    return <section className="panel parity-table-panel">
        <header className="panel__header">
            <div><span className="eyebrow">SOS SIGNALS</span><h2>Operator queue</h2></div>
            <span className="queue-count">{len(alerts)} shown</span>
        </header>
        <div className="parity-table-wrap">
            <table className="parity-table">
                <thead><tr>
                    <th>Signal</th><th>Priority</th><th>Type</th><th>Location</th>
                    <th>Delivery</th><th>Status</th><th>Team</th><th></th>
                </tr></thead>
                <tbody>
                    {for alert in alerts {
                        <tr key={alert.alert_id} className={"is-selected" if alert.alert_id == selected_id else ""}>
                            <td><strong>{alert.alert_id}</strong><small>{alert.received_at}</small></td>
                            <td><span className={priority_class(alert.priority)}>{alert.priority}</span></td>
                            <td>{alert.emergency_type}</td>
                            <td>{alert.zone}</td>
                            <td><strong>{alert.hop_count} hops</strong><small>{alert.delivered_via.replace("_", " ")}</small></td>
                            <td><span className={status_class(alert.status)}>{alert.status}</span></td>
                            <td>{alert.assigned_to or "Unassigned"}</td>
                            <td><button className="icon-action icon-action--ops" title="Inspect signal" onClick={lambda (_e: MouseEvent) { on_select(alert.alert_id); }}><ChevronRight size={15} /></button></td>
                        </tr>
                    }}
                </tbody>
            </table>
        </div>
    </section>;
}

def:pub AnalyticsWorkspace(workspace: DrillWorkspace, zones: list[ZoneView]) -> JsxElement {
    metrics = workspace.metrics;
    return <div className="parity-view">
        <section className="parity-metric-grid">
            <article><span>Delivery rate</span><strong>{metrics.delivery_rate}%</strong><small>Signals received by command</small></article>
            <article><span>Mesh relay</span><strong>{metrics.mesh_relay_percentage}%</strong><small>{metrics.average_hops} average hops</small></article>
            <article><span>Gateway coverage</span><strong>{metrics.gateway_coverage_score}%</strong><small>{workspace.controls.gateway_count} internet-capable nodes</small></article>
            <article><span>Responder coverage</span><strong>{metrics.assignment_coverage}%</strong><small>{metrics.assigned_alert_count} assigned alerts</small></article>
            <article><span>Unresolved critical</span><strong>{metrics.unresolved_criticals}</strong><small>Immediate command attention</small></article>
            <article><span>Active devices</span><strong>{metrics.active_devices}</strong><small>{workspace.controls.device_count} generated devices</small></article>
        </section>
        <div className="analytics-grid">
            <section className="panel">
                <header className="panel__header"><div><span className="eyebrow">SCENARIO SCORE</span><h2>Network performance</h2></div><BarChart3 size={18} /></header>
                <div className="score-bars">
                    <div><span>Delivery reliability</span><div><span className="meter-fill" style={{"width": f"{metrics.delivery_rate}%"}}></span></div><strong>{metrics.delivery_rate}%</strong></div>
                    <div><span>Gateway coverage</span><div><span className="meter-fill" style={{"width": f"{metrics.gateway_coverage_score}%"}}></span></div><strong>{metrics.gateway_coverage_score}%</strong></div>
                    <div><span>Responder coverage</span><div><span className="meter-fill" style={{"width": f"{metrics.assignment_coverage}%"}}></span></div><strong>{metrics.assignment_coverage}%</strong></div>
                    <div><span>Resolved signals</span><div><span className="meter-fill" style={{"width": f"{round((metrics.resolved_count / metrics.alert_volume) * 100) if metrics.alert_volume else 0}%"}}></span></div><strong>{metrics.resolved_count}</strong></div>
                </div>
            </section>
            <ZoneTable zones={zones} />
        </div>
    </div>;
}

def:pub DisasterWorkspace(
    feed: DisasterFeedView | None,
    refreshing: bool,
    on_refresh: Callable[[MouseEvent], None],
) -> JsxElement {
    return <div className="parity-view">
        <section className="panel disaster-workspace">
            <header className="panel__header">
                <div><span className="eyebrow">PUBLIC HAZARD FEEDS</span><h2>Disaster intelligence</h2></div>
                <button className="button button--outline" onClick={on_refresh} disabled={refreshing}>
                    <RefreshCw className={"spin" if refreshing else ""} size={15} /> Refresh USGS / NWS
                </button>
            </header>
            {if not feed {
                <div className="empty-inline"><Cloud size={17} /> Feed not loaded</div>;
            } else {
                <div className="disaster-summary">
                    <article><strong>{feed.total}</strong><span>Total events</span></article>
                    <article><strong>{feed.earthquake_count}</strong><span>Earthquakes</span></article>
                    <article><strong>{feed.weather_count}</strong><span>Weather alerts</span></article>
                    <article><strong>{feed.severe_count}</strong><span>Severe / extreme</span></article>
                    <small className={"source-state source-state--live" if feed.source_status == "live" else "source-state"}>{feed.source_status} · {feed.refreshed_at}</small>
                </div>
                <div className="disaster-list">
                    {for event in feed.events {
                        <article key={event.disaster_id}>
                            <span className={"disaster-icon disaster-icon--quake" if event.event_type == "earthquake" else "disaster-icon"}>{if event.event_type == "earthquake" { <Activity size={17} />; } else { <Wind size={17} />; }}</span>
                            <div><span>{event.source} · {event.severity}</span><strong>{event.title}</strong><p>{event.area}</p><small>{event.occurred_at}</small></div>
                            <a href={event.detail_url} target="_blank" rel="noreferrer" title="Open source record"><ChevronRight size={16} /></a>
                        </article>
                    }}
                </div>
            }}
        </section>
    </div>;
}


def:pub CommandCenter -> JsxElement {
    has snapshot: OpsSnapshot | None = None,
        workspace: DrillWorkspace | None = None,
        active_view: str = "dashboard",
        selected_alert_id: str = "SOS-1042",
        relay_hops: list[RelayHopView] = [],
        briefing: AgentBriefing | None = None,
        disaster_feed: DisasterFeedView | None = None,
        comparison: RunComparisonView | None = None,
        replay: ReplaySnapshot | None = None,
        question: str = "What should command prioritize in the next ten minutes?",
        scenario_choice: str = "wildfire",
        responder_choice: str = "ems-1",
        search_query: str = "",
        table_page: int = 1,
        seed_choice: int = 42,
        intensity_choice: int = 65,
        density_choice: int = 70,
        gateway_choice: int = 30,
        damage_choice: int = 55,
        speed_choice: float = 1.0,
        simulation_running: bool = False,
        sound_enabled: bool = True,
        live_mode: bool = False,
        preset_name: str = "Command drill preset",
        preset_json: str = "",
        run_name: str = "After action run",
        run_a_choice: str = "",
        run_b_choice: str = "",
        replay_run_choice: str = "",
        replay_position: int = 100,
        reviewer_name: str = "Exercise Controller",
        review_notes: str = "",
        handoff_review_choice: str = "",
        receiving_operator: str = "Night Operations",
        handoff_notes: str = "",
        handoff_follow_up: str = "",
        handoff_choice: str = "",
        handoff_state: str = "sent",
        handoff_disposition: str = "active",
        handoff_resolution: str = "unresolved",
        review_filter: str = "all",
        handoff_query: str = "",
        handoff_filter: str = "all",
        resolution_notes: str = "",
        settings_open: bool = False,
        refreshing_feed: bool = False,
        busy: bool = False,
        agent_busy: bool = False,
        notice: str = "",
        notice_error: bool = False,
        load_error: str = "";

    navigate = useNavigate();
    alert_audio = useRef(None);

    async can with entry {
        try {
            initial_snapshot: OpsSnapshot = await get_snapshot();
            if not initial_snapshot or len(initial_snapshot.alerts) == 0 {
                load_error = "Your command session expired. Sign in again to restore access.";
                return;
            }
            snapshot = initial_snapshot;
            scenario_choice = initial_snapshot.scenario;
            initial_workspace: DrillWorkspace = await get_drill_workspace();
            sync_workspace(initial_workspace);
            await select_alert(selected_alert_id);
        } except Exception {
            load_error = "Your command session could not be opened. Sign in again to restore access.";
        }
    }

    async def select_alert(alert_id: str) {
        selected_alert_id = alert_id;
        relay_hops = [];
        result = root spawn TraceRelay(alert_id=alert_id);
        relay_hops = result.reports if result and result.reports else [];
    }

    def sync_workspace(next_workspace: DrillWorkspace) {
        workspace = next_workspace;
        scenario_choice = next_workspace.controls.scenario;
        seed_choice = next_workspace.controls.seed;
        intensity_choice = next_workspace.controls.intensity;
        density_choice = next_workspace.controls.device_density;
        gateway_choice = next_workspace.controls.gateway_ratio;
        damage_choice = next_workspace.controls.infrastructure_damage;
        speed_choice = next_workspace.controls.simulation_speed;
        simulation_running = next_workspace.controls.is_running;
        sound_enabled = next_workspace.controls.sound_enabled;
        live_mode = next_workspace.controls.live_mode;
        if len(next_workspace.runs) > 0 {
            if not run_a_choice { run_a_choice = next_workspace.runs[-1].run_id; }
            if not run_b_choice { run_b_choice = next_workspace.runs[0].run_id; }
            if not replay_run_choice { replay_run_choice = next_workspace.runs[0].run_id; }
        }
        if len(next_workspace.reviews) > 0 and not handoff_review_choice {
            handoff_review_choice = next_workspace.reviews[0].review_id;
        }
        if len(next_workspace.handoffs) > 0 and not handoff_choice {
            handoff_choice = next_workspace.handoffs[0].handoff_id;
        }
    }

    async def reload_workspace {
        sync_workspace(await get_drill_workspace());
    }

    async def refresh_after(next_snapshot: OpsSnapshot, message: str) {
        if not next_snapshot or len(next_snapshot.alerts) == 0 {
            load_error = "Your command session expired. Sign in again to restore access.";
            busy = False;
            return;
        }
        snapshot = next_snapshot;
        await reload_workspace();
        notice = message;
        notice_error = False;
        await select_alert(selected_alert_id);
        busy = False;
    }

    def operation_failed(message: str) {
        notice = message;
        notice_error = True;
        busy = False;
    }

    async def handle_advance(_e: MouseEvent) {
        busy = True;
        try {
            await refresh_after(await advance_drill(), "Drill advanced and graph metrics recomputed.");
            play_alert_tone();
        } except Exception {
            operation_failed("The drill could not be advanced. Retry after the graph reconnects.");
        }
    }

    async def handle_reset(_e: MouseEvent) {
        busy = True;
        selected_alert_id = "SOS-1042";
        briefing = None;
        try {
            await refresh_after(
                await configure_drill(
                    scenario_choice,
                    seed_choice,
                    intensity_choice,
                    density_choice,
                    gateway_choice,
                    damage_choice,
                    speed_choice,
                    simulation_running,
                    sound_enabled,
                    live_mode,
                ),
                f"{scenario_choice.title()} drill generated from seed {seed_choice}.",
            );
        } except Exception {
            operation_failed("The drill could not be reset.");
        }
    }

    async def handle_acknowledge(_e: MouseEvent) {
        busy = True;
        try {
            await refresh_after(await acknowledge_alert(selected_alert_id), f"{selected_alert_id} acknowledged.");
        } except Exception {
            operation_failed("The alert could not be acknowledged.");
        }
    }

    async def handle_assign(_e: MouseEvent) {
        busy = True;
        try {
            await refresh_after(
                await assign_responder(selected_alert_id, responder_choice),
                f"{responder_choice} assigned to {selected_alert_id}.",
            );
        } except Exception {
            operation_failed("Assignment failed. Confirm that the responder is available.");
        }
    }

    async def handle_resolve(_e: MouseEvent) {
        busy = True;
        try {
            await refresh_after(
                await resolve_alert(selected_alert_id, resolution_notes or "Resolved after operator review."),
                f"{selected_alert_id} resolved.",
            );
        } except Exception {
            operation_failed("The alert could not be resolved.");
        }
    }

    async def handle_cancel(_e: MouseEvent) {
        busy = True;
        try {
            await refresh_after(
                await cancel_alert(selected_alert_id, resolution_notes or "Cancelled by command."),
                f"{selected_alert_id} cancelled.",
            );
        } except Exception {
            operation_failed("The alert could not be cancelled.");
        }
    }

    async def handle_runtime_toggle(kind: str) {
        next_running: bool = not simulation_running if kind == "running" else simulation_running;
        next_sound: bool = not sound_enabled if kind == "sound" else sound_enabled;
        next_live: bool = not live_mode if kind == "live" else live_mode;
        try {
            sync_workspace(await update_drill_runtime(speed_choice, next_running, next_sound, next_live));
            notice = "Simulation runtime settings updated.";
            notice_error = False;
        } except Exception {
            operation_failed("Runtime settings could not be updated.");
        }
    }

    async def handle_speed_change(e: ChangeEvent) {
        next_speed: float = float(e.target.value);
        speed_choice = next_speed;
        try {
            sync_workspace(await update_drill_runtime(next_speed, simulation_running, sound_enabled, live_mode));
        } except Exception {
            operation_failed("Simulation speed could not be updated.");
        }
    }

    async def handle_save_preset(e: FormEvent) {
        e.preventDefault();
        busy = True;
        try {
            sync_workspace(await save_scenario_preset(preset_name));
            notice = f"Preset '{preset_name}' saved to the Jac graph.";
            notice_error = False;
        } except Exception {
            operation_failed("The preset could not be saved.");
        }
        busy = False;
    }

    async def handle_import_preset(e: FormEvent) {
        e.preventDefault();
        busy = True;
        try {
            sync_workspace(await import_scenario_preset(preset_json));
            notice = "Preset JSON imported and validated.";
            notice_error = False;
            preset_json = "";
        } except Exception {
            operation_failed("Preset JSON is invalid or unsupported.");
        }
        busy = False;
    }

    async def handle_apply_preset(preset_id: str) {
        busy = True;
        selected_alert_id = "SOS-1042";
        try {
            await refresh_after(await apply_scenario_preset(preset_id), "Preset applied to the active drill.");
        } except Exception {
            operation_failed("The preset could not be applied.");
        }
    }

    async def handle_delete_preset(preset_id: str) {
        busy = True;
        try {
            sync_workspace(await delete_scenario_preset(preset_id));
            notice = "Preset deleted.";
            notice_error = False;
        } except Exception {
            operation_failed("The preset could not be deleted.");
        }
        busy = False;
    }

    async def handle_archive_run(e: FormEvent) {
        e.preventDefault();
        busy = True;
        try {
            sync_workspace(await archive_scenario_run(run_name));
            notice = f"Run '{run_name}' frozen with its alerts and event ledger.";
            notice_error = False;
        } except Exception {
            operation_failed("The run could not be archived.");
        }
        busy = False;
    }

    async def handle_delete_run(run_id: str) {
        busy = True;
        try {
            sync_workspace(await delete_scenario_run(run_id));
            comparison = None;
            replay = None;
            notice = "Archived run deleted.";
            notice_error = False;
        } except Exception {
            operation_failed("The archived run could not be deleted.");
        }
        busy = False;
    }

    async def handle_compare(_e: MouseEvent) {
        if not run_a_choice or not run_b_choice { return; }
        busy = True;
        try {
            comparison = await compare_scenario_runs(run_a_choice, run_b_choice);
            notice = "Archived run comparison calculated.";
            notice_error = False;
        } except Exception {
            operation_failed("Select two valid archived runs.");
        }
        busy = False;
    }

    async def handle_replay_change(e: ChangeEvent) {
        replay_position = int(e.target.value);
        if not replay_run_choice { return; }
        try {
            replay = await get_run_replay(replay_run_choice, replay_position);
        } except Exception {
            operation_failed("The replay projection could not be calculated.");
        }
    }

    async def handle_load_replay(_e: MouseEvent) {
        if not replay_run_choice { return; }
        try {
            replay = await get_run_replay(replay_run_choice, replay_position);
            notice = "Frozen run replay loaded.";
            notice_error = False;
        } except Exception {
            operation_failed("The replay could not be loaded.");
        }
    }

    async def handle_sign_review(e: FormEvent) -> None {
        e.preventDefault();
        if not replay_run_choice and not run_b_choice { return; }
        busy = True;
        try {
            sync_workspace(await sign_drill_review(replay_run_choice or run_b_choice, reviewer_name, review_notes));
            notice = "After-action review scored and signed.";
            notice_error = False;
        } except Exception {
            operation_failed("The review could not be signed.");
        }
        busy = False;
    }

    async def handle_create_handoff(e: FormEvent) -> None {
        e.preventDefault();
        if not handoff_review_choice { return; }
        busy = True;
        try {
            sync_workspace(await create_drill_handoff(
                handoff_review_choice,
                receiving_operator,
                handoff_notes,
                handoff_follow_up,
            ));
            notice = "Receiving-operator handoff created.";
            notice_error = False;
        } except Exception {
            operation_failed("The handoff could not be created.");
        }
        busy = False;
    }

    async def handle_update_handoff(e: FormEvent) -> None {
        e.preventDefault();
        if not handoff_choice { return; }
        busy = True;
        try {
            sync_workspace(await update_drill_handoff(
                handoff_choice,
                handoff_state,
                handoff_disposition,
                handoff_resolution,
                receiving_operator,
                handoff_notes,
                handoff_follow_up,
            ));
            notice = "Handoff lifecycle updated.";
            notice_error = False;
        } except Exception {
            operation_failed("The handoff could not be updated.");
        }
        busy = False;
    }

    async def handle_feed_refresh(_e: MouseEvent) {
        refreshing_feed = True;
        try {
            disaster_feed = await refresh_disaster_feed();
            notice = "Public hazard feeds refreshed.";
            notice_error = False;
        } except Exception {
            notice = "Live feeds were unavailable; the continuity snapshot remains available.";
            notice_error = True;
        }
        refreshing_feed = False;
    }

    async def open_disasters(_e: MouseEvent) {
        active_view = "disasters";
        if not disaster_feed {
            try {
                disaster_feed = await get_disaster_feed();
            } except Exception {
                operation_failed("The disaster feed could not be opened.");
            }
        }
    }

    def play_alert_tone {
        if sound_enabled and alert_audio.current {
            try {
                alert_audio.current.currentTime = 0;
                alert_audio.current.play();
            } except Exception {
                notice = "Browser audio is blocked until the next operator interaction.";
                notice_error = True;
            }
        }
    }

    async def run_live_tick {
        try {
            next_snapshot: OpsSnapshot = await advance_drill();
            snapshot = next_snapshot;
            await reload_workspace();
            if selected_alert_id {
                await select_alert(selected_alert_id);
            }
            play_alert_tone();
        } except Exception {
            operation_failed("Live simulation paused after a graph update failed.");
            simulation_running = False;
        }
    }

    useEffect(
        lambda -> any {
            if simulation_running {
                interval_ms: int = 16000 if speed_choice == 0.5 else (
                    8000 if speed_choice == 1.0 else (2000 if speed_choice == 4.0 else 500)
                );
                interval = setInterval(lambda { run_live_tick(); }, interval_ms);
                return lambda { clearInterval(interval); };
            }
        },
        [simulation_running, speed_choice],
    );

    async def handle_agent(e: FormEvent) -> None {
        e.preventDefault();
        if not question.strip() { return; }
        agent_busy = True;
        try {
            briefing = await analyze_incident(question);
            notice = "";
        } except Exception {
            notice = "The operations briefing could not be generated.";
            notice_error = True;
        }
        agent_busy = False;
    }

    def handle_logout(_e: MouseEvent) {
        jacLogout();
        navigate("/login");
    }

    if load_error {
        return <div className="ops-session-error">
            <span className="brand-mark brand-mark--large"><Waypoints size={26} /></span>
            <h1>Command session unavailable</h1>
            <p>{load_error}</p>
            <button className="button button--primary" onClick={handle_logout}>
                <LogOut size={16} /> Return to sign in
            </button>
        </div>;
    }

    if not snapshot or not workspace {
        return <div className="ops-loading">
            <span className="brand-mark brand-mark--large"><Waypoints size={26} /></span>
            <div className="loading-line"><span></span></div>
            <p>Connecting to the Jac operations graph</p>
        </div>;
    }

    current: OpsSnapshot = snapshot as OpsSnapshot;
    current_workspace: DrillWorkspace = workspace as DrillWorkspace;
    selected: AlertView | None = None;
    for alert in current.alerts {
        if alert.alert_id == selected_alert_id { selected = alert; }
    }
    if not selected and len(current.alerts) > 0 {
        selected = current.alerts[0];
    }
    selected_current: AlertView = selected as AlertView;
    normalized_search: str = search_query.strip().lower();
    filtered_alerts: list[AlertView] = [
        alert
        for alert in current.alerts
        if not normalized_search
        or normalized_search in alert.alert_id.lower()
        or normalized_search in alert.emergency_type.lower()
        or normalized_search in alert.zone.lower()
        or normalized_search in alert.message.lower()
        or normalized_search in alert.assigned_to.lower()
    ];
    total_pages: int = max(1, (len(filtered_alerts) + 24) // 25);
    if table_page > total_pages { table_page = total_pages; }
    page_start: int = (table_page - 1) * 25;
    paged_alerts: list[AlertView] = filtered_alerts[page_start:page_start + 25];
    filtered_reviews: list[DrillReviewView] = [
        review
        for review in current_workspace.reviews
        if review_filter == "all" or review.status == review_filter
    ];
    normalized_handoff_query: str = handoff_query.strip().lower();
    filtered_handoffs: list[DrillHandoffView] = [
        handoff
        for handoff in current_workspace.handoffs
        if (
            handoff_filter == "all"
            or handoff.lifecycle_state == handoff_filter
            or handoff.disposition == handoff_filter
            or handoff.resolution == handoff_filter
        )
        and (
            not normalized_handoff_query
            or normalized_handoff_query in handoff.handoff_id.lower()
            or normalized_handoff_query in handoff.receiving_operator.lower()
            or normalized_handoff_query in handoff.operator_notes.lower()
        )
    ];

    return <div className="ops-shell">
        <aside className="ops-sidebar">
            <Link to="/" className="brand-lockup brand-lockup--ops">
                <span className="brand-mark"><Waypoints size={19} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <div className="mode-badge"><span></span>{current.source_mode}</div>
            <nav className="ops-nav">
                <button className={"is-active" if active_view == "dashboard" else ""} onClick={lambda (_e: MouseEvent) { active_view = "dashboard"; }}><LayoutDashboard size={17} /><span>Dashboard</span></button>
                <button className={"is-active" if active_view == "signals" else ""} onClick={lambda (_e: MouseEvent) { active_view = "signals"; }}><Table2 size={17} /><span>SOS signals</span></button>
                <button className={"is-active" if active_view == "map" else ""} onClick={lambda (_e: MouseEvent) { active_view = "map"; }}><Map size={17} /><span>Live map</span></button>
                <button className={"is-active" if active_view == "scenario" else ""} onClick={lambda (_e: MouseEvent) { active_view = "scenario"; }}><SlidersHorizontal size={17} /><span>Scenario lab</span></button>
                <button className={"is-active" if active_view == "archive" else ""} onClick={lambda (_e: MouseEvent) { active_view = "archive"; }}><Archive size={17} /><span>Archive & replay</span></button>
                <button className={"is-active" if active_view == "reviews" else ""} onClick={lambda (_e: MouseEvent) { active_view = "reviews"; }}><ClipboardCheck size={17} /><span>AAR & handoffs</span></button>
                <button className={"is-active" if active_view == "disasters" else ""} onClick={open_disasters}><TriangleAlert size={17} /><span>Disasters</span></button>
                <button className={"is-active" if active_view == "analytics" else ""} onClick={lambda (_e: MouseEvent) { active_view = "analytics"; }}><BarChart3 size={17} /><span>Analytics</span></button>
            </nav>
            <div className="sidebar-health">
                <div><Signal size={16} /><span>GRAPH RUNTIME</span><strong className="sidebar-health-state">HEALTHY</strong></div>
                <div className="health-bars"><span></span><span></span><span></span><span></span></div>
                <small>Jac server · persistent root</small>
            </div>
            <div className="sidebar-actions">
                <Link to="/" className="sidebar-back"><ArrowLeft size={15} /> Public view</Link>
                <button className="sidebar-back" onClick={handle_logout}><LogOut size={15} /> Sign out</button>
            </div>
        </aside>

        <main className="ops-main" id="overview">
            <header className="ops-header">
                <div className="incident-title">
                    <div className="incident-icon"><Siren size={21} /></div>
                    <div>
                        <span>{current.phase} · STARTED {current.started_at}</span>
                        <h1>{current.incident_name}</h1>
                        <p><LocateFixed size={13} /> {current.area}</p>
                    </div>
                </div>
                <div className="ops-header__controls">
                    <label>
                        <span>SCENARIO</span>
                        <select value={scenario_choice} onChange={lambda (e: ChangeEvent) { scenario_choice = e.target.value; }}>
                            <option value="wildfire">Wildfire</option>
                            <option value="tornado">Tornado</option>
                            <option value="hurricane">Hurricane</option>
                            <option value="earthquake">Earthquake</option>
                        </select>
                    </label>
                    <button className="icon-action icon-action--ops" onClick={lambda (_e: MouseEvent) { handle_runtime_toggle("sound"); }} title={"Mute alert sound" if sound_enabled else "Enable alert sound"}>
                        {if sound_enabled { <Volume2 size={17} />; } else { <VolumeX size={17} />; }}
                    </button>
                    <button className="icon-action icon-action--ops" onClick={lambda (_e: MouseEvent) { settings_open = not settings_open; }} title="Runtime settings">
                        <Settings size={17} />
                    </button>
                    <button className="icon-action icon-action--ops" onClick={handle_reset} title="Reset drill" disabled={busy}>
                        <RefreshCw size={17} />
                    </button>
                    <button className="button button--primary button--ops" onClick={handle_advance} title="Advance drill" disabled={busy}>
                        <Play size={15} /> Advance drill <span>T+{current.tick}</span>
                    </button>
                </div>
            </header>

            {if settings_open {
                <section className="runtime-settings">
                    <div><span className="eyebrow">SIMULATION RUNTIME</span><strong>Operator settings</strong></div>
                    <label><span>Playback speed</span><select value={str(speed_choice)} onChange={handle_speed_change}>
                        <option value="0.5">0.5x</option><option value="1.0">1x</option><option value="4.0">4x</option><option value="16.0">16x</option>
                    </select></label>
                    <button className={"toggle-control is-on" if simulation_running else "toggle-control"} onClick={lambda (_e: MouseEvent) { handle_runtime_toggle("running"); }}>
                        {if simulation_running { <Pause size={15} />; } else { <Play size={15} />; }} Live simulation
                    </button>
                    <button className={"toggle-control is-on" if live_mode else "toggle-control"} onClick={lambda (_e: MouseEvent) { handle_runtime_toggle("live"); }}>
                        <Cloud size={15} /> {"Live data mode" if live_mode else "Demo data mode"}
                    </button>
                    <button className={"toggle-control is-on" if sound_enabled else "toggle-control"} onClick={lambda (_e: MouseEvent) { handle_runtime_toggle("sound"); }}>
                        {if sound_enabled { <Bell size={15} />; } else { <BellOff size={15} />; }} Alert audio
                    </button>
                    <button className="icon-action icon-action--ops" onClick={lambda (_e: MouseEvent) { settings_open = False; }} title="Close settings"><X size={15} /></button>
                </section>;
            }}

            {if notice {
                <div className={"ops-notice ops-notice--error" if notice_error else "ops-notice"}>
                    {if notice_error { <X size={15} />; } else { <Check size={15} />; }}
                    {notice}
                    <button onClick={lambda (_e: MouseEvent) { notice = ""; }}><X size={14} /></button>
                </div>;
            }}

            <section className="stats-grid">
                <StatTile label="ACTIVE ALERTS" value={str(current.stats.active_alerts)} detail={f"{current.stats.critical_alerts} require immediate triage"} tone="tone-danger">
                    <Siren size={16} />
                </StatTile>
                <StatTile label="NETWORK HEALTH" value={f"{current.stats.network_health}%"} detail="Across four modeled zones" tone="tone-signal">
                    <Signal size={16} />
                </StatTile>
                <StatTile label="MESH DELIVERY" value={f"{current.stats.mesh_delivery_percent}%"} detail={f"{current.stats.average_hops} average hops"} tone="tone-cyan">
                    <Network size={16} />
                </StatTile>
                <StatTile label="RESPONDERS READY" value={str(current.stats.responders_available)} detail="Field resources available" tone="tone-green">
                    <Users size={16} />
                </StatTile>
            </section>

            {if active_view == "dashboard" {
                <div className="primary-grid" id="incident-map">
                    <AlertMapPanel alerts={current.alerts} selected_id={selected_alert_id} on_select={select_alert} />
                    <AlertQueue alerts={current.alerts[:12]} selected_id={selected_alert_id} on_select={select_alert} />
                </div>;
            } elif active_view == "map" {
                <div className="map-only-view"><AlertMapPanel alerts={filtered_alerts} selected_id={selected_alert_id} on_select={select_alert} /></div>;
            } elif active_view == "signals" {
                <div className="parity-view">
                    <div className="table-toolbar">
                        <label><Search size={15} /><input value={search_query} onChange={lambda (e: ChangeEvent) { search_query = e.target.value; table_page = 1; }} placeholder="Search ID, type, zone, message, or team" /></label>
                        <span>{len(filtered_alerts)} matching · page {table_page} of {total_pages}</span>
                        <div><button className="icon-action icon-action--ops" onClick={lambda (_e: MouseEvent) { table_page = max(1, table_page - 1); }} disabled={table_page == 1} title="Previous page"><ArrowLeft size={15} /></button><button className="icon-action icon-action--ops" onClick={lambda (_e: MouseEvent) { table_page = min(total_pages, table_page + 1); }} disabled={table_page == total_pages} title="Next page"><ChevronRight size={15} /></button></div>
                    </div>
                    <AlertTablePanel alerts={paged_alerts} selected_id={selected_alert_id} on_select={select_alert} />
                </div>;
            }}

            {if selected_current and active_view in ["dashboard", "signals", "map"] {
                <section className="panel selected-alert" id="relay-path">
                    <header className="selected-alert__header">
                        <div className={priority_class(selected_current.priority)}>
                            {if selected_current.priority == "critical" { <Siren size={17} />; } else { <Radio size={17} />; }}
                        </div>
                        <div>
                            <span className="eyebrow">{selected_current.priority} · {selected_current.emergency_type}</span>
                            <h2>{selected_current.alert_id} · {selected_current.caller}</h2>
                            <p>{selected_current.message}</p>
                        </div>
                        <div className="selected-alert__facts">
                            <span><LocateFixed size={14} /> {selected_current.zone}</span>
                            <span><Clock3 size={14} /> {selected_current.received_at}</span>
                            <span><HeartPulse size={14} /> {selected_current.battery}% battery</span>
                        </div>
                    </header>
                    <div className="selected-alert__body">
                        <div className="trace-wrap">
                            <div className="subhead"><span>RELAY PROVENANCE</span><strong>{selected_current.hop_count} verified hops</strong></div>
                            <RelayTrace hops={relay_hops} />
                        </div>
                        <div className="alert-actions">
                            <div className="subhead"><span>OPERATOR ACTIONS</span><strong className={status_class(selected_current.status)}>{selected_current.status}</strong></div>
                            <div className="action-controls">
                                <button className="button button--outline" onClick={handle_acknowledge} disabled={busy or selected_current.status != "active"}>
                                    <ShieldCheck size={15} /> Acknowledge
                                </button>
                                <div className="assign-control">
                                    <select value={responder_choice} onChange={lambda (e: ChangeEvent) { responder_choice = e.target.value; }}>
                                        {for responder in current.responders {
                                            <option key={responder.responder_id} value={responder.responder_id}>{responder.responder_id} · {responder.name}</option>
                                        }}
                                    </select>
                                    <button className="button button--outline" onClick={handle_assign} disabled={busy or selected_current.status == "resolved"}>
                                        <Crosshair size={15} /> Assign
                                    </button>
                                </div>
                                <button className="button button--success" onClick={handle_resolve} disabled={busy or selected_current.status == "resolved"}>
                                    <Check size={15} /> Resolve alert
                                </button>
                                <input className="resolution-input" value={resolution_notes} onChange={lambda (e: ChangeEvent) { resolution_notes = e.target.value; }} placeholder="Resolution or cancellation notes" maxLength={500} />
                                <button className="button button--danger-outline" onClick={handle_cancel} disabled={busy or selected_current.status == "resolved"}>
                                    <X size={15} /> Cancel
                                </button>
                            </div>
                        </div>
                    </div>
                </section>;
            }}

            {if active_view == "dashboard" {
                <div className="secondary-grid" id="field-teams">
                    <ZoneTable zones={current.zones} />
                    <ResponderRoster responders={current.responders} />
                    <ActivityFeed events={current.activity} />
                </div>;
            }}

            {if active_view == "dashboard" {
            <section className="agent-panel" id="agent">
                <div className="agent-panel__intro">
                    <span className="agent-icon"><Sparkles size={21} /></span>
                    <div>
                        <span className="eyebrow">JAC OPERATIONS AGENT</span>
                        <h2>Grounded incident briefing</h2>
                        <p>Recommendations are derived from the current simulated graph and returned as a typed briefing.</p>
                    </div>
                </div>
                <form onSubmit={handle_agent} className="agent-form">
                    <label htmlFor="agent-question">OPERATOR QUESTION</label>
                    <div>
                        <input
                            id="agent-question"
                            value={question}
                            onChange={lambda (e: ChangeEvent) { question = e.target.value; }}
                            placeholder="Ask about priorities, coverage, or resource placement"
                            maxLength={500}
                        />
                        <button type="submit" className="button button--agent" disabled={agent_busy}>
                            {if agent_busy { <RefreshCw className="spin" size={16} />; } else { <Send size={16} />; }}
                            Analyze
                        </button>
                    </div>
                </form>
                {if briefing {
                    <article className="briefing">
                        <header>
                            <span><Bot size={16} /> {briefing.mode}</span>
                            <small>{briefing.confidence} confidence</small>
                        </header>
                        <h3>{briefing.headline}</h3>
                        <p>{briefing.summary}</p>
                        <div className="briefing-actions">
                            {for (idx, action) in enumerate(briefing.actions) {
                                <div key={idx}><span>{idx + 1}</span><p>{action}</p></div>
                            }}
                        </div>
                        <footer><strong>WHY</strong><span>{briefing.reasoning}</span></footer>
                    </article>;
                } else {
                    <div className="agent-empty">
                        <Bot size={23} />
                        <span>Awaiting an operations question</span>
                        <small>Provider configured: Jac byLLM · Otherwise: deterministic Jac policy</small>
                    </div>;
                }}
            </section>;
            }}

            {if active_view == "scenario" {
                <div className="parity-view scenario-workspace">
                    <div className="scenario-grid">
                        <section className="panel scenario-controls">
                            <header className="panel__header"><div><span className="eyebrow">SCENARIO GENERATOR</span><h2>Drill controls</h2></div><SlidersHorizontal size={18} /></header>
                            <div className="scenario-selector">
                                {for scenario in ["wildfire", "tornado", "hurricane", "earthquake"] {
                                    <button key={scenario} className={"is-active" if scenario_choice == scenario else ""} onClick={lambda (_e: MouseEvent) { scenario_choice = scenario; }}>{scenario.title()}</button>
                                }}
                            </div>
                            <label className="seed-control"><span>Deterministic seed</span><input type="number" min="1" max="2147483646" value={str(seed_choice)} onChange={lambda (e: ChangeEvent) { seed_choice = int(e.target.value); }} /></label>
                            <div className="range-controls">
                                <label><span><strong>Incident intensity</strong><em>{intensity_choice}%</em></span><input type="range" min="0" max="100" step="5" value={str(intensity_choice)} onChange={lambda (e: ChangeEvent) { intensity_choice = int(e.target.value); }} /></label>
                                <label><span><strong>Device density</strong><em>{density_choice}%</em></span><input type="range" min="0" max="100" step="5" value={str(density_choice)} onChange={lambda (e: ChangeEvent) { density_choice = int(e.target.value); }} /></label>
                                <label><span><strong>Gateway ratio</strong><em>{gateway_choice}%</em></span><input type="range" min="0" max="100" step="5" value={str(gateway_choice)} onChange={lambda (e: ChangeEvent) { gateway_choice = int(e.target.value); }} /></label>
                                <label><span><strong>Infrastructure damage</strong><em>{damage_choice}%</em></span><input type="range" min="0" max="100" step="5" value={str(damage_choice)} onChange={lambda (e: ChangeEvent) { damage_choice = int(e.target.value); }} /></label>
                            </div>
                            <div className="scenario-run-controls">
                                <button className="button button--primary" onClick={handle_reset} disabled={busy}><Play size={15} /> Generate drill</button>
                                <button className={"button button--outline is-active" if simulation_running else "button button--outline"} onClick={lambda (_e: MouseEvent) { handle_runtime_toggle("running"); }}>{if simulation_running { <Pause size={15} />; } else { <Play size={15} />; }} {if simulation_running { "Pause"; } else { "Run live"; }}</button>
                                <select value={str(speed_choice)} onChange={handle_speed_change}><option value="0.5">0.5x</option><option value="1.0">1x</option><option value="4.0">4x</option><option value="16.0">16x</option></select>
                            </div>
                        </section>

                        <section className="panel scenario-score">
                            <header className="panel__header"><div><span className="eyebrow">LIVE RUN SHAPE</span><h2>{current.incident_name}</h2></div><CircleGauge size={18} /></header>
                            <p>{current.area} · seed {current_workspace.controls.seed}</p>
                            <div className="scenario-score-grid">
                                <article><strong>{current_workspace.metrics.alert_volume}</strong><span>Alerts</span></article>
                                <article><strong>{current_workspace.controls.device_count}</strong><span>Devices</span></article>
                                <article><strong>{current_workspace.controls.gateway_count}</strong><span>Gateways</span></article>
                                <article><strong>{current_workspace.metrics.mesh_relay_percentage}%</strong><span>Mesh relay</span></article>
                                <article><strong>{current_workspace.metrics.average_hops}</strong><span>Avg hops</span></article>
                                <article><strong>{current_workspace.metrics.unresolved_criticals}</strong><span>Critical aging</span></article>
                            </div>
                            <div className="persistence-state"><Database size={17} /><div><strong>{current_workspace.persistence.archive_mode_label}</strong><span>{current_workspace.persistence.message}</span></div><span className="persistence-dot"></span></div>
                        </section>
                    </div>

                    <div className="scenario-grid scenario-grid--brief">
                        <section className="panel drill-brief">
                            <header className="panel__header"><div><span className="eyebrow">DRILL BRIEFING</span><h2>{current_workspace.briefing.title}</h2></div><BookOpen size={18} /></header>
                            <span className="focus-pill">{current_workspace.briefing.focus} focus</span>
                            <div className="brief-columns">
                                <div><strong>Mission objectives</strong>{for item in current_workspace.briefing.mission_objectives { <p key={item}><Check size={13} /> {item}</p> }}</div>
                                <div><strong>Failure injects</strong>{for item in current_workspace.briefing.failure_injects { <p key={item}><TriangleAlert size={13} /> {item}</p> }}</div>
                                <div><strong>Evidence targets</strong>{for item in current_workspace.briefing.evidence_targets { <p key={item}><FileCheck size={13} /> {item}</p> }}</div>
                            </div>
                            <footer><Archive size={14} /> {current_workspace.briefing.archive_action}</footer>
                        </section>
                        <ResponderRoster responders={current.responders} />
                    </div>

                    <div className="scenario-grid">
                        <section className="panel preset-workspace">
                            <header className="panel__header"><div><span className="eyebrow">SCENARIO PRESETS</span><h2>Save and restore</h2></div><Save size={18} /></header>
                            <form onSubmit={handle_save_preset} className="inline-form"><input value={preset_name} onChange={lambda (e: ChangeEvent) { preset_name = e.target.value; }} placeholder="Preset name" maxLength={80} /><button className="button button--primary" type="submit" disabled={busy}><Save size={15} /> Save preset</button></form>
                            <div className="artifact-list">
                                {if len(current_workspace.presets) == 0 { <div className="empty-inline">No saved presets</div>; }
                                else { for preset in current_workspace.presets {
                                    <article key={preset.preset_id}>
                                        <div><strong>{preset.name}</strong><span>{preset.scenario} · seed {preset.seed}</span><small>{preset.intensity}% intensity · {preset.gateway_ratio}% gateway · {preset.infrastructure_damage}% damage</small></div>
                                        <div className="artifact-actions"><button className="button button--outline" onClick={lambda (_e: MouseEvent) { handle_apply_preset(preset.preset_id); }}><Play size={14} /> Apply</button><button className="icon-action icon-action--ops" title="Delete preset" onClick={lambda (_e: MouseEvent) { handle_delete_preset(preset.preset_id); }}><Trash2 size={14} /></button></div>
                                        <details><summary><Download size={13} /> Export JSON</summary><textarea readOnly value={preset.export_json}></textarea></details>
                                    </article>
                                }}}
                            </div>
                        </section>
                        <section className="panel import-workspace">
                            <header className="panel__header"><div><span className="eyebrow">PORTABLE CONFIG</span><h2>Import preset JSON</h2></div><Upload size={18} /></header>
                            <form onSubmit={handle_import_preset}><textarea value={preset_json} onChange={lambda (e: ChangeEvent) { preset_json = e.target.value; }} placeholder='{"version":1,"name":"Imported drill",...}'></textarea><button className="button button--outline" type="submit" disabled={busy or not preset_json.strip()}><Upload size={15} /> Validate and import</button></form>
                            <div className="persistence-counts"><article><strong>{current_workspace.persistence.preset_count}</strong><span>Presets</span></article><article><strong>{current_workspace.persistence.run_count}</strong><span>Runs</span></article><article><strong>{current_workspace.persistence.review_count}</strong><span>Reviews</span></article><article><strong>{current_workspace.persistence.handoff_count}</strong><span>Handoffs</span></article></div>
                        </section>
                    </div>
                </div>;
            }}

            {if active_view == "archive" {
                <div className="parity-view archive-workspace">
                    <div className="scenario-grid">
                        <section className="panel">
                            <header className="panel__header"><div><span className="eyebrow">RUN ARCHIVE</span><h2>Frozen exercise artifacts</h2></div><Archive size={18} /></header>
                            <form onSubmit={handle_archive_run} className="inline-form"><input value={run_name} onChange={lambda (e: ChangeEvent) { run_name = e.target.value; }} placeholder="Run name" maxLength={80} /><button type="submit" className="button button--primary" disabled={busy}><Archive size={15} /> Archive current run</button></form>
                            <div className="artifact-list run-list">
                                {if len(current_workspace.runs) == 0 { <div className="empty-inline">Archive the current drill to enable replay and comparison.</div>; }
                                else { for run in current_workspace.runs {
                                    <article key={run.run_id}><div><strong>{run.name}</strong><span>{run.scenario} · seed {run.seed} · {run.created_at}</span><small>{run.alert_count} alerts · {run.device_count} devices · {run.delivery_rate}% delivery · {run.assignment_coverage}% responder coverage</small></div><span className={status_class(run.review_status)}>{run.review_status}</span><button className="icon-action icon-action--ops" title="Delete run" onClick={lambda (_e: MouseEvent) { handle_delete_run(run.run_id); }}><Trash2 size={14} /></button></article>
                                }}}
                            </div>
                        </section>
                        <section className="panel comparison-panel">
                            <header className="panel__header"><div><span className="eyebrow">RUN COMPARISON</span><h2>Baseline versus contender</h2></div><GitCompare size={18} /></header>
                            <div className="comparison-controls"><select value={run_a_choice} onChange={lambda (e: ChangeEvent) { run_a_choice = e.target.value; }}>{for run in current_workspace.runs { <option key={run.run_id} value={run.run_id}>A · {run.name}</option> }}</select><select value={run_b_choice} onChange={lambda (e: ChangeEvent) { run_b_choice = e.target.value; }}>{for run in current_workspace.runs { <option key={run.run_id} value={run.run_id}>B · {run.name}</option> }}</select><button className="button button--outline" onClick={handle_compare} disabled={len(current_workspace.runs) < 2}><GitCompare size={14} /> Compare</button></div>
                            {if comparison {
                                <div className="delta-list">{for delta in comparison.deltas { <div key={delta.key}><span>{delta.label}</span><strong>{delta.value_a}</strong><ChevronRight size={13} /><strong>{delta.value_b}</strong><em className={"is-good" if (delta.delta >= 0 and delta.higher_is_better) or (delta.delta <= 0 and not delta.higher_is_better) else "is-bad"}>{delta.delta if delta.delta < 0 else f"+{delta.delta}"}</em></div> }}</div>;
                            } else { <div className="empty-inline"><GitCompare size={16} /> Select two archived runs</div>; }}
                        </section>
                    </div>

                    <section className="panel replay-panel">
                        <header className="panel__header"><div><span className="eyebrow">SCENARIO REPLAY</span><h2>As-of event projection</h2></div><History size={18} /></header>
                        <div className="replay-controls"><select value={replay_run_choice} onChange={lambda (e: ChangeEvent) { replay_run_choice = e.target.value; replay = None; }}>{for run in current_workspace.runs { <option key={run.run_id} value={run.run_id}>{run.name}</option> }}</select><button className="button button--outline" onClick={handle_load_replay} disabled={not replay_run_choice}><Play size={14} /> Load replay</button><label><span>{replay_position}%</span><input type="range" min="0" max="100" value={str(replay_position)} onChange={handle_replay_change} /></label></div>
                        {if replay {
                            <div className="replay-grid">
                                <div className="replay-summary"><strong>{replay.current_time}</strong><span>{len(replay.visible_alerts)} visible alerts</span><span>{len(replay.visible_events)} visible events</span><div className="event-density"><span className="meter-fill" style={{"width": f"{replay.position}%"}}></span></div></div>
                                <div className="replay-events">{for event in replay.visible_events[-18:] { <article key={event.event_id}><span>{event.event_type}</span><strong>{event.alert_id}</strong><p>{event.message}</p><small>{event.event_time}</small></article> }}</div>
                            </div>;
                        } else { <div className="empty-inline"><History size={16} /> Load an archived run to scrub its immutable event ledger.</div>; }}
                    </section>
                </div>;
            }}

            {if active_view == "reviews" {
                <div className="parity-view review-workspace">
                    <div className="scenario-grid">
                        <section className="panel">
                            <header className="panel__header"><div><span className="eyebrow">AFTER-ACTION REVIEW</span><h2>Score and sign evidence</h2></div><ClipboardCheck size={18} /></header>
                            <form onSubmit={handle_sign_review} className="stack-form"><label><span>Archived run</span><select value={replay_run_choice} onChange={lambda (e: ChangeEvent) { replay_run_choice = e.target.value; }}>{for run in current_workspace.runs { <option key={run.run_id} value={run.run_id}>{run.name}</option> }}</select></label><label><span>Reviewer</span><input value={reviewer_name} onChange={lambda (e: ChangeEvent) { reviewer_name = e.target.value; }} maxLength={80} /></label><label><span>Operator notes</span><textarea value={review_notes} onChange={lambda (e: ChangeEvent) { review_notes = e.target.value; }} maxLength={2000}></textarea></label><button type="submit" className="button button--primary" disabled={busy or len(current_workspace.runs) == 0}><FileCheck size={15} /> Score and sign review</button></form>
                        </section>
                        <section className="panel training-trends">
                            <header className="panel__header"><div><span className="eyebrow">TRAINING TRENDS</span><h2>Signed review history</h2></div><BarChart3 size={18} /></header>
                            <div className="trend-score"><strong>{current_workspace.reviews[0].score if len(current_workspace.reviews) > 0 else 0}</strong><span>Latest score</span><em>{f"+{current_workspace.reviews[0].score_delta}" if len(current_workspace.reviews) > 0 and current_workspace.reviews[0].score_delta >= 0 else (str(current_workspace.reviews[0].score_delta) if len(current_workspace.reviews) > 0 else "0")}</em></div>
                            <div className="review-filter"><button className={"is-active" if review_filter == "all" else ""} onClick={lambda (_e: MouseEvent) { review_filter = "all"; }}>All</button><button className={"is-active" if review_filter == "pass" else ""} onClick={lambda (_e: MouseEvent) { review_filter = "pass"; }}>Pass</button><button className={"is-active" if review_filter == "watch" else ""} onClick={lambda (_e: MouseEvent) { review_filter = "watch"; }}>Watch</button><button className={"is-active" if review_filter == "fail" else ""} onClick={lambda (_e: MouseEvent) { review_filter = "fail"; }}>Fail</button></div>
                            <div className="review-list">{if len(filtered_reviews) == 0 { <div className="empty-inline">No signed reviews</div>; } else { for review in filtered_reviews { <article key={review.review_id}><div><strong>{review.review_id}</strong><span>{review.reviewer} · {review.signed_at}</span><p>{review.notes or "No reviewer notes."}</p></div><span className={status_class(review.status)}>{review.score} · {review.status}</span><details><summary><Download size={13} /> JSON</summary><textarea readOnly value={review.export_json}></textarea></details></article> }}}</div>
                        </section>
                    </div>

                    <div className="scenario-grid">
                        <section className="panel">
                            <header className="panel__header"><div><span className="eyebrow">HANDOFF PACKET</span><h2>Create receiving-operator work</h2></div><Users size={18} /></header>
                            <form onSubmit={handle_create_handoff} className="stack-form"><label><span>Signed review</span><select value={handoff_review_choice} onChange={lambda (e: ChangeEvent) { handoff_review_choice = e.target.value; }}>{for review in current_workspace.reviews { <option key={review.review_id} value={review.review_id}>{review.review_id} · {review.status}</option> }}</select></label><label><span>Receiving operator</span><input value={receiving_operator} onChange={lambda (e: ChangeEvent) { receiving_operator = e.target.value; }} /></label><label><span>Follow-up date</span><input type="date" value={handoff_follow_up} onChange={lambda (e: ChangeEvent) { handoff_follow_up = e.target.value; }} /></label><label><span>Transfer notes</span><textarea value={handoff_notes} onChange={lambda (e: ChangeEvent) { handoff_notes = e.target.value; }}></textarea></label><button type="submit" className="button button--primary" disabled={busy or len(current_workspace.reviews) == 0}><Send size={15} /> Create handoff</button></form>
                        </section>
                        <section className="panel">
                            <header className="panel__header"><div><span className="eyebrow">HANDOFF LIFECYCLE</span><h2>Update receiving state</h2></div><Route size={18} /></header>
                            <form onSubmit={handle_update_handoff} className="stack-form"><label><span>Handoff</span><select value={handoff_choice} onChange={lambda (e: ChangeEvent) { handoff_choice = e.target.value; }}>{for handoff in current_workspace.handoffs { <option key={handoff.handoff_id} value={handoff.handoff_id}>{handoff.handoff_id} · {handoff.lifecycle_state}</option> }}</select></label><div className="form-row"><label><span>Lifecycle</span><select value={handoff_state} onChange={lambda (e: ChangeEvent) { handoff_state = e.target.value; }}><option value="draft">Draft</option><option value="sent">Sent</option><option value="acknowledged">Acknowledged</option><option value="superseded">Superseded</option></select></label><label><span>Disposition</span><select value={handoff_disposition} onChange={lambda (e: ChangeEvent) { handoff_disposition = e.target.value; }}><option value="active">Active</option><option value="archived">Archived</option><option value="deleted">Deleted</option></select></label><label><span>Resolution</span><select value={handoff_resolution} onChange={lambda (e: ChangeEvent) { handoff_resolution = e.target.value; }}><option value="unresolved">Unresolved</option><option value="accepted">Accepted</option><option value="needs_follow_up">Needs follow-up</option><option value="rejected">Rejected</option></select></label></div><button type="submit" className="button button--outline" disabled={busy or len(current_workspace.handoffs) == 0}><Save size={15} /> Save lifecycle</button></form>
                        </section>
                    </div>

                    <section className="panel handoff-queue">
                        <header className="panel__header"><div><span className="eyebrow">HANDOFF QUEUE</span><h2>Follow-up and disposition</h2></div><List size={18} /></header>
                        <div className="table-toolbar"><label><Search size={15} /><input value={handoff_query} onChange={lambda (e: ChangeEvent) { handoff_query = e.target.value; }} placeholder="Search operator, ID, or notes" /></label><select value={handoff_filter} onChange={lambda (e: ChangeEvent) { handoff_filter = e.target.value; }}><option value="all">All states</option><option value="draft">Draft</option><option value="sent">Sent</option><option value="acknowledged">Acknowledged</option><option value="archived">Archived</option><option value="deleted">Deleted</option><option value="needs_follow_up">Needs follow-up</option></select><span>{len(filtered_handoffs)} packets</span></div>
                        <div className="handoff-list">{if len(filtered_handoffs) == 0 { <div className="empty-inline">No matching handoffs</div>; } else { for handoff in filtered_handoffs { <article key={handoff.handoff_id}><div><strong>{handoff.handoff_id}</strong><span>{handoff.receiving_operator} · {handoff.updated_at}</span><p>{handoff.operator_notes or "No transfer notes."}</p></div><div><span className="handoff-state">{handoff.lifecycle_state}</span><span>{handoff.disposition}</span><em>{handoff.resolution}</em><small>{handoff.follow_up_status}{f" · {handoff.follow_up_date}" if handoff.follow_up_date else ""}</small></div><details><summary><Download size={13} /> Manifest</summary><textarea readOnly value={handoff.export_json}></textarea></details></article> }}}</div>
                    </section>
                </div>;
            }}

            {if active_view == "disasters" {
                <DisasterWorkspace feed={disaster_feed} refreshing={refreshing_feed} on_refresh={handle_feed_refresh} />;
            }}

            {if active_view == "analytics" {
                <AnalyticsWorkspace workspace={current_workspace} zones={current.zones} />;
            }}

            <audio
                ref={alert_audio}
                preload="auto"
                src="data:audio/wav;base64,UklGRoQEAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YWAEAACAobOtk3BUTV19nrKvlnNWTVt6m7GvmXZZTVl2mK+wm3pbTldzla2xnX1eTlZxkqyxoIBgT1Vuj6qxooNjUFRrjKixpIZmUlNpiaWxpYlpU1JmhqOwp4xsVVJkg6GvqI9uVlFigJ6uqZFxWFFgfZytqpR0WlFeepmsq5Z3XFJcd5arrJl6X1JbdZOprJt9YVNacpGorJ2AY1RZb46mrJ+DZlVYbYukrKCGaFZXa4iirKKIa1dWaYWgq6OLbllWZ4Odq6SNcFpWZYCbqqWQc1xWY32ZqaaSdl5WYXuWqKeUeGBWYHiUpqeWe2JXX3aRpaiYfWRYXnOPpKiagGZYXXGMoqibg2lZXG+KoKidhWtaW22Hnqeeh21cW2uFnKefinBdW2mCmqagjHJfW2iAmKWhjnRgW2Z+lqSikHdiW2V7lKOiknlkW2R5kqKjlHtlXGN3j6GjlX5nXGJ1jZ+jl4BpXWFzi56jmIJrXmBxiZyjmYRtX2Bvhpujm4ZvYF9uhJminIhyYV9sgpehnIp0Y19rgJWhnYx2ZF9pfpOgno54Zl9ofJGfnpB6Z2Bneo+enpF8aWBmeI6dn5N+amFmdoybn5SAbGJldYqan5WCbmJkc4iZnpaEcGNkcoaXnpeGcmRkcISWnZiHc2Vkb4KUnZmJdWdkboCSnJmLd2hkbX6Rm5qMeWlkbHyPmpqNe2tka3uNmpqPfWxlanmMmJqQfm5laXiKl5qRgG9maXaIlpqSgnFnaXWGlZqTg3JoaHSFlJmThXRpaHODkpmUhnVqaHKCkZiViHdraHGAj5iViXlsaHB/jpeVinptaW99jJaWi3xuaW58i5WWjH1waW56ipSWjX9xam15iJOWjoBya214h5KVj4Fza213hZGVj4N1bG12hJCVkIR2bW11g4+UkIV3bm10gY6UkYZ5b210gIyTkYd6cG1zf4uSkYh7cW1yfoqSkYl9cm5yfYmRkYp+c25yfIiQkYp/dG9xe4aPkYuAdW9xeoWOkYyBdnBxeYSNkIyCd3FxeIOMkIyDeHFxeIKLkI2EeXJxd4GKj42FenNxd4CJj42Fe3Rydn+Ijo2GfHVydn6HjY2HfXVydX2HjY2HfnZzdX2GjI2If3dzdXyFi4yIgHh0dXuEioyIgXl0dXuDioyJgXp1dXqCiYuJgnt2dXqBiIuJg3t2dnqBh4qJg3x3dnmAhoqJhH14dnl/homJhH54d3l/hYmJhH55d3l+hIiIhX96d3l+hIiIhX96eHl9g4eIhYB7eHl9goaIhYB8eXl9goaHhYF8eXp9gYWHhYF9enp9gYWGhYJ9enp8gISGhYJ+e3p8gISFhYJ+fHt8gIOFhYJ/fHt9f4OEhIJ/fXx9f4KEhIJ/fXx9f4KDhIKAfnx9f4GDg4KAfn19f4GDg4KAfn1+f4GCg4KAf35+f4CCgoKAf35+f4CBgoGAf39/f4CBgYGAgH9/f4CBgYGAgH9/gICAgICAgICAgICA"
            ></audio>

            <footer className="ops-footer">
                <span><WifiOff size={14} /> Training environment · simulated data</span>
                <span>Protected per-operator Jac graph</span>
                <span>Authenticated Jac operations</span>
            </footer>
        </main>
    </div>;
}
