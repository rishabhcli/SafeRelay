"""SafeRelay full-stack entry point."""

import from saferelay.store {
    ActivityView,
    AgentBriefing,
    AlertView,
    ComparisonDeltaView,
    DisasterEventView,
    DisasterFeedView,
    DrillBriefingView,
    DrillHandoffView,
    DrillReviewView,
    DrillWorkspace,
    OpsSnapshot,
    PersistenceView,
    RelayHopView,
    ReplaySnapshot,
    ResponderView,
    RunArchiveView,
    RunComparisonView,
    ScenarioControlsView,
    ScenarioMetricsView,
    ScenarioPresetView,
    TimelineEventView,
    TraceRelay as _TraceRelayImpl,
    ZoneView,
    acknowledge_alert as _acknowledge_alert,
    advance_drill as _advance_drill,
    analyze_incident as _analyze_incident,
    apply_scenario_preset as _apply_scenario_preset,
    archive_scenario_run as _archive_scenario_run,
    assign_responder as _assign_responder,
    cancel_alert as _cancel_alert,
    compare_scenario_runs as _compare_scenario_runs,
    configure_drill as _configure_drill,
    create_drill_handoff as _create_drill_handoff,
    delete_scenario_preset as _delete_scenario_preset,
    delete_scenario_run as _delete_scenario_run,
    get_disaster_feed as _get_disaster_feed,
    get_drill_workspace as _get_drill_workspace,
    get_run_replay as _get_run_replay,
    get_snapshot as _get_snapshot,
    import_scenario_preset as _import_scenario_preset,
    refresh_disaster_feed as _refresh_disaster_feed,
    reset_drill as _reset_drill,
    resolve_alert as _resolve_alert,
    save_scenario_preset as _save_scenario_preset,
    sign_drill_review as _sign_drill_review,
    update_drill_handoff as _update_drill_handoff,
    update_drill_runtime as _update_drill_runtime,
}


def:priv get_snapshot -> OpsSnapshot {
    return _get_snapshot();
}

def:priv reset_drill(scenario: str) -> OpsSnapshot {
    return _reset_drill(scenario);
}

def:priv configure_drill(
    scenario: str,
    seed: int,
    intensity: int,
    device_density: int,
    gateway_ratio: int,
    infrastructure_damage: int,
    simulation_speed: float,
    is_running: bool,
    sound_enabled: bool,
    live_mode: bool,
) -> OpsSnapshot {
    return _configure_drill(
        scenario,
        seed,
        intensity,
        device_density,
        gateway_ratio,
        infrastructure_damage,
        simulation_speed,
        is_running,
        sound_enabled,
        live_mode,
    );
}

def:priv get_drill_workspace -> DrillWorkspace {
    return _get_drill_workspace();
}

def:priv update_drill_runtime(
    simulation_speed: float,
    is_running: bool,
    sound_enabled: bool,
    live_mode: bool,
) -> DrillWorkspace {
    return _update_drill_runtime(simulation_speed, is_running, sound_enabled, live_mode);
}

def:priv acknowledge_alert(alert_id: str) -> OpsSnapshot {
    return _acknowledge_alert(alert_id);
}

def:priv assign_responder(alert_id: str, responder_id: str) -> OpsSnapshot {
    return _assign_responder(alert_id, responder_id);
}

def:priv resolve_alert(
    alert_id: str,
    resolution_notes: str = "Resolved after operator review.",
) -> OpsSnapshot {
    return _resolve_alert(alert_id, resolution_notes);
}

def:priv cancel_alert(
    alert_id: str,
    cancellation_notes: str = "Cancelled by command.",
) -> OpsSnapshot {
    return _cancel_alert(alert_id, cancellation_notes);
}

def:priv advance_drill -> OpsSnapshot {
    return _advance_drill();
}

def:priv analyze_incident(question: str) -> AgentBriefing {
    return _analyze_incident(question);
}

def:priv save_scenario_preset(name: str) -> DrillWorkspace {
    return _save_scenario_preset(name);
}

def:priv delete_scenario_preset(preset_id: str) -> DrillWorkspace {
    return _delete_scenario_preset(preset_id);
}

def:priv apply_scenario_preset(preset_id: str) -> OpsSnapshot {
    return _apply_scenario_preset(preset_id);
}

def:priv import_scenario_preset(payload_json: str) -> DrillWorkspace {
    return _import_scenario_preset(payload_json);
}

def:priv archive_scenario_run(name: str) -> DrillWorkspace {
    return _archive_scenario_run(name);
}

def:priv delete_scenario_run(run_id: str) -> DrillWorkspace {
    return _delete_scenario_run(run_id);
}

def:priv compare_scenario_runs(
    run_a_id: str,
    run_b_id: str,
) -> RunComparisonView {
    return _compare_scenario_runs(run_a_id, run_b_id);
}

def:priv get_run_replay(run_id: str, position: int) -> ReplaySnapshot {
    return _get_run_replay(run_id, position);
}

def:priv sign_drill_review(
    run_id: str,
    reviewer: str,
    notes: str,
) -> DrillWorkspace {
    return _sign_drill_review(run_id, reviewer, notes);
}

def:priv create_drill_handoff(
    review_id: str,
    receiving_operator: str,
    notes: str,
    follow_up_date: str = "",
) -> DrillWorkspace {
    return _create_drill_handoff(review_id, receiving_operator, notes, follow_up_date);
}

def:priv update_drill_handoff(
    handoff_id: str,
    lifecycle_state: str,
    disposition: str,
    resolution: str,
    receiving_operator: str,
    notes: str,
    follow_up_date: str,
) -> DrillWorkspace {
    return _update_drill_handoff(
        handoff_id,
        lifecycle_state,
        disposition,
        resolution,
        receiving_operator,
        notes,
        follow_up_date,
    );
}

def:priv get_disaster_feed -> DisasterFeedView {
    return _get_disaster_feed();
}

def:priv refresh_disaster_feed -> DisasterFeedView {
    return _refresh_disaster_feed();
}

walker:priv TraceRelay {
    has alert_id: str,
        reports: list[RelayHopView] = [];

    can delegate with Root entry {
        nested = here spawn _TraceRelayImpl(alert_id=self.alert_id);
        for hop in nested.reports { report hop; }
    }
}


cl {
    import ".styles.global.css";
    import from .saferelay.AppShell { SafeRelayApp }

    def:pub app -> JsxElement {
        return <SafeRelayApp />;
    }
}
