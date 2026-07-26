"""Behavioral parity tests for the Jac-native SafeRelay operations graph."""

import from .store {
    AlertView,
    DrillWorkspace,
    OpsSnapshot,
    ReplaySnapshot,
    RunArchiveView,
    RunComparisonView,
    TraceRelay,
    _clear_graph,
    _clear_workspace,
    acknowledge_alert,
    advance_drill,
    apply_scenario_preset,
    archive_scenario_run,
    assign_responder,
    compare_scenario_runs,
    configure_drill,
    create_drill_handoff,
    get_disaster_feed,
    get_drill_workspace,
    get_run_replay,
    get_snapshot,
    import_scenario_preset,
    resolve_alert,
    save_scenario_preset,
    sign_drill_review,
    update_drill_handoff,
}


test "scenario generation controls alter the deterministic drill shape" {
    _clear_graph();
    _clear_workspace();
    low: OpsSnapshot = configure_drill("wildfire", 42, 10, 10, 10, 20, 1.0, False, True, False);
    low_workspace: DrillWorkspace = get_drill_workspace();
    high: OpsSnapshot = configure_drill("wildfire", 42, 100, 100, 80, 90, 1.0, False, True, False);
    high_workspace: DrillWorkspace = get_drill_workspace();
    assert len(high.alerts) > len(low.alerts);
    assert high_workspace.controls.device_count > low_workspace.controls.device_count;
    assert high_workspace.controls.gateway_count > low_workspace.controls.gateway_count;
    assert high_workspace.metrics.average_hops > low_workspace.metrics.average_hops;
}

test "all committed disaster scenarios map to distinct Jac incidents" {
    wildfire: OpsSnapshot = configure_drill("wildfire", 7, 65, 70, 30, 55, 1.0, False, True, False);
    tornado: OpsSnapshot = configure_drill("tornado", 7, 65, 70, 30, 55, 1.0, False, True, False);
    hurricane: OpsSnapshot = configure_drill("hurricane", 7, 65, 70, 30, 55, 1.0, False, True, False);
    earthquake: OpsSnapshot = configure_drill("earthquake", 7, 65, 70, 30, 55, 1.0, False, True, False);
    assert wildfire.incident_name == "Paradise Fire Complex";
    assert tornado.incident_name == "Oklahoma Tornado Outbreak";
    assert hurricane.incident_name == "Hurricane Response - Galveston";
    assert earthquake.incident_name == "San Andreas Fault Activity";
    assert len(earthquake.alerts) > len(tornado.alerts);
}

test "alert mutation and relay provenance persist in the graph" {
    _clear_graph();
    snapshot: OpsSnapshot = get_snapshot();
    snapshot = acknowledge_alert("SOS-1042");
    alert: AlertView = [item for item in snapshot.alerts if item.alert_id == "SOS-1042"][0];
    assert alert.status == "acknowledged";
    snapshot = assign_responder("SOS-1042", "ems-1");
    alert = [item for item in snapshot.alerts if item.alert_id == "SOS-1042"][0];
    assert alert.status == "responding";
    assert alert.assigned_to == "ems-1";
    result = root spawn TraceRelay(alert_id="SOS-1042");
    assert len(result.reports) == 4;
    assert result.reports[3].had_internet;
    snapshot = resolve_alert("SOS-1042", "Patient transferred in the exercise.");
    alert = [item for item in snapshot.alerts if item.alert_id == "SOS-1042"][0];
    assert alert.status == "resolved";
    assert alert.resolution_notes == "Patient transferred in the exercise.";
}

test "timeline covers originated relay gateway received assignment and resolution" {
    _clear_graph();
    _ = get_snapshot();
    _ = assign_responder("SOS-1042", "ems-1");
    _ = resolve_alert("SOS-1042", "Exercise complete.");
    workspace: DrillWorkspace = get_drill_workspace();
    event_types: list[str] = [event.event_type for event in workspace.timeline if event.alert_id == "SOS-1042"];
    assert "originated" in event_types;
    assert "relay_hop" in event_types;
    assert "gateway" in event_types;
    assert "received" in event_types;
    assert "assigned" in event_types;
    assert "resolved" in event_types;
}

test "live simulation ticks append deterministic emergency signals" {
    _clear_graph();
    initial: OpsSnapshot = configure_drill("earthquake", 19, 80, 70, 35, 75, 4.0, True, True, False);
    first: OpsSnapshot = advance_drill();
    second: OpsSnapshot = advance_drill();
    assert first.tick == 1;
    assert second.tick == 2;
    assert len(first.alerts) == len(initial.alerts) + 1;
    assert len(second.alerts) == len(first.alerts) + 1;
    assert len([alert for alert in second.alerts if alert.alert_id == "SOS-LIVE-0002"]) == 1;
}

test "scenario presets export import apply and clamp controls" {
    _clear_graph();
    _clear_workspace();
    _ = configure_drill("hurricane", 321, 100, 95, 25, 85, 4.0, False, False, True);
    saved: DrillWorkspace = save_scenario_preset("Night shift hurricane");
    assert len(saved.presets) == 1;
    exported: str = saved.presets[0].export_json;
    imported: DrillWorkspace = import_scenario_preset(exported);
    assert len(imported.presets) == 2;
    restored: OpsSnapshot = apply_scenario_preset(imported.presets[0].preset_id);
    restored_workspace: DrillWorkspace = get_drill_workspace();
    assert restored.scenario == "hurricane";
    assert restored_workspace.controls.seed == 321;
    assert restored_workspace.controls.intensity == 100;
    assert restored_workspace.controls.simulation_speed == 4.0;
    assert not restored_workspace.controls.sound_enabled;
    assert restored_workspace.controls.live_mode;
}

test "archives freeze artifacts and replay projects an as-of view" {
    _clear_graph();
    _clear_workspace();
    _ = configure_drill("wildfire", 11, 45, 55, 20, 30, 1.0, False, True, False);
    first: DrillWorkspace = archive_scenario_run("Baseline");
    first_id: str = first.runs[0].run_id;
    _ = configure_drill("earthquake", 12, 95, 90, 70, 85, 16.0, False, True, False);
    second: DrillWorkspace = archive_scenario_run("Contender");
    second_id: str = second.runs[0].run_id;
    comparison: RunComparisonView = compare_scenario_runs(first_id, second_id);
    assert len(comparison.deltas) == 6;
    assert comparison.run_a;
    assert comparison.run_b;
    run_a: RunArchiveView = comparison.run_a as RunArchiveView;
    run_b: RunArchiveView = comparison.run_b as RunArchiveView;
    assert run_b.alert_count > run_a.alert_count;
    replay_start: ReplaySnapshot = get_run_replay(second_id, 0);
    replay_middle: ReplaySnapshot = get_run_replay(second_id, 50);
    replay_end: ReplaySnapshot = get_run_replay(second_id, 100);
    assert len(replay_start.visible_alerts) == 0;
    assert len(replay_middle.visible_events) > 0;
    assert len(replay_end.visible_alerts) == second.runs[0].alert_count;
}

test "responder coverage is capacity aware and reflected in metrics" {
    _clear_graph();
    _ = configure_drill("tornado", 14, 70, 70, 35, 60, 1.0, False, True, False);
    active_ids: list[str] = [
        alert.alert_id
        for alert in get_snapshot().alerts
        if alert.status == "active"
    ][:5];
    for alert_id in active_ids { _ = assign_responder(alert_id, "ems-1"); }
    workspace: DrillWorkspace = get_drill_workspace();
    assert workspace.metrics.assigned_alert_count >= 5;
    assert workspace.metrics.assignment_coverage > 0;
    assert workspace.metrics.average_eta_minutes >= 6.0;
    assert workspace.metrics.average_eta_minutes < 10.0;
}

test "briefing archive review and handoff form one auditable workflow" {
    _clear_graph();
    _clear_workspace();
    _ = configure_drill("hurricane", 51, 85, 80, 40, 70, 1.0, False, True, False);
    workspace: DrillWorkspace = get_drill_workspace();
    assert workspace.briefing.title == "Hurricane response drill brief";
    assert len(workspace.briefing.mission_objectives) == 3;
    workspace = archive_scenario_run("Hurricane certification");
    run_id: str = workspace.runs[0].run_id;
    workspace = sign_drill_review(run_id, "Exercise Controller", "Validate gateway placement next cycle.");
    assert len(workspace.reviews) == 1;
    review_id: str = workspace.reviews[0].review_id;
    workspace = create_drill_handoff(review_id, "Night Operations", "Carry the gateway inject forward.", "2026-08-01");
    handoff_id: str = workspace.handoffs[0].handoff_id;
    workspace = update_drill_handoff(
        handoff_id,
        "sent",
        "active",
        "needs_follow_up",
        "Night Operations",
        "Bridge validation remains open.",
        "2026-08-01",
    );
    assert workspace.handoffs[0].lifecycle_state == "sent";
    assert workspace.handoffs[0].resolution == "needs_follow_up";
    assert workspace.handoffs[0].follow_up_status == "scheduled";
    assert workspace.persistence.handoff_count == 1;
}

test "disaster feed always has a continuity snapshot" {
    _clear_workspace();
    feed = get_disaster_feed();
    assert feed.total == 2;
    assert feed.earthquake_count == 1;
    assert feed.weather_count == 1;
    assert feed.severe_count == 1;
    assert feed.source_status == "fallback";
}
