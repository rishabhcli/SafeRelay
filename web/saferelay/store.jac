"""Persistent emergency operations graph and typed Jac API."""

import json;
import os;
import requests;


node Incident {
    has scenario: str,
        name: str,
        area: str,
        started_at: str,
        phase: str = "ACTIVE RESPONSE",
        tick: int = 0,
        seed: int = 42,
        intensity: int = 65,
        device_density: int = 70,
        gateway_ratio: int = 30,
        infrastructure_damage: int = 55,
        simulation_speed: float = 1.0,
        is_running: bool = False,
        sound_enabled: bool = True,
        live_mode: bool = False,
        device_count: int = 0,
        gateway_count: int = 0;
}

node Alert {
    has alert_id: str,
        caller: str,
        emergency_type: str,
        priority: str,
        status: str,
        message: str,
        zone: str,
        map_x: int,
        map_y: int,
        battery: int,
        hop_count: int,
        originator: str,
        received_at: str,
        assigned_to: str = "",
        originated_at: str = "",
        acknowledged_at: str = "",
        resolved_at: str = "",
        resolution_notes: str = "",
        delivered_via: str = "mesh_relay",
        delivered_by: str = "";
}

node RelayHop {
    has hop_order: int,
        device_id: str,
        label: str,
        rssi: int,
        battery: int,
        had_internet: bool = False;
}

node Responder {
    has responder_id: str,
        name: str,
        role: str,
        zone: str,
        status: str,
        eta_minutes: int,
        capacity: int = 4;
}

node ActivityEvent {
    has event_id: str,
        event_time: str,
        event_type: str,
        message: str;
}

node ScenarioPreset {
    has preset_id: str,
        name: str,
        scenario: str,
        seed: int,
        intensity: int,
        device_density: int,
        gateway_ratio: int,
        infrastructure_damage: int,
        simulation_speed: float,
        sound_enabled: bool,
        live_mode: bool,
        created_at: str,
        assignment_data: str = "{}";
}

node RunArchive {
    has run_id: str,
        name: str,
        scenario: str,
        seed: int,
        intensity: int,
        device_density: int,
        gateway_ratio: int,
        infrastructure_damage: int,
        created_at: str,
        alert_count: int,
        device_count: int,
        gateway_count: int,
        delivery_rate: int,
        average_hops: float,
        assignment_coverage: int,
        unresolved_criticals: int,
        review_score: int = -1,
        review_status: str = "unreviewed";
}

node ArchivedAlert {
    has alert_id: str,
        emergency_type: str,
        priority: str,
        status: str,
        message: str,
        zone: str,
        hop_count: int,
        assigned_to: str,
        originated_at: str,
        received_at: str,
        acknowledged_at: str,
        resolved_at: str;
}

node ArchivedEvent {
    has event_id: str,
        alert_id: str,
        event_time: str,
        event_type: str,
        message: str,
        sequence: int;
}

node DrillReview {
    has review_id: str,
        run_id: str,
        reviewer: str,
        notes: str,
        score: int,
        status: str,
        signed_at: str;
}

node DrillHandoff {
    has handoff_id: str,
        review_id: str,
        run_id: str,
        receiving_operator: str,
        operator_notes: str,
        updated_at: str,
        lifecycle_state: str = "draft",
        disposition: str = "active",
        resolution: str = "unresolved",
        follow_up_date: str = "";
}

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

edge IncidentAlert: Incident --> Alert {}
edge IncidentResponder: Incident --> Responder {}
edge IncidentActivity: Incident --> ActivityEvent {}
edge RelayedThrough: Alert --> RelayHop {}
edge RootPreset: Root --> ScenarioPreset {}
edge RootRun: Root --> RunArchive {}
edge RunAlert: RunArchive --> ArchivedAlert {}
edge RunEvent: RunArchive --> ArchivedEvent {}
edge RootReview: Root --> DrillReview {}
edge RootHandoff: Root --> DrillHandoff {}
edge RootDisasterCache: Root --> DisasterCache {}
edge DisasterCacheEvent: DisasterCache --> DisasterEvent {}


obj OpsStats {
    has active_alerts: int = 0,
        critical_alerts: int = 0,
        responders_available: int = 0,
        mesh_delivery_percent: int = 0,
        average_hops: float = 0.0,
        network_health: int = 0;
}

obj AlertView {
    has alert_id: str,
        caller: str,
        emergency_type: str,
        priority: str,
        status: str,
        message: str,
        zone: str,
        map_x: int,
        map_y: int,
        battery: int,
        hop_count: int,
        originator: str,
        received_at: str,
        assigned_to: str,
        originated_at: str,
        acknowledged_at: str,
        resolved_at: str,
        resolution_notes: str,
        delivered_via: str,
        delivered_by: str;
}

obj RelayHopView {
    has hop_order: int,
        device_id: str,
        label: str,
        rssi: int,
        battery: int,
        had_internet: bool;
}

obj ResponderView {
    has responder_id: str,
        name: str,
        role: str,
        zone: str,
        status: str,
        eta_minutes: int,
        capacity: int;
}

obj ActivityView {
    has event_id: str,
        event_time: str,
        event_type: str,
        message: str;
}

obj ZoneView {
    has name: str,
        health: int,
        nodes_online: int,
        alerts: int,
        gateway: str;
}

obj OpsSnapshot {
    has incident_name: str,
        scenario: str,
        area: str,
        started_at: str,
        phase: str,
        tick: int,
        source_mode: str,
        stats: OpsStats,
        alerts: list[AlertView],
        responders: list[ResponderView],
        activity: list[ActivityView],
        zones: list[ZoneView];
}

obj ScenarioControlsView {
    has scenario: str,
        seed: int,
        intensity: int,
        device_density: int,
        gateway_ratio: int,
        infrastructure_damage: int,
        simulation_speed: float,
        is_running: bool,
        sound_enabled: bool,
        live_mode: bool,
        device_count: int,
        gateway_count: int;
}

obj ScenarioMetricsView {
    has alert_volume: int,
        active_devices: int,
        gateway_coverage_score: int,
        delivery_rate: int,
        mesh_relay_percentage: int,
        average_hops: float,
        unresolved_criticals: int,
        acknowledged_count: int,
        resolved_count: int,
        assigned_alert_count: int,
        assignment_coverage: int,
        average_eta_minutes: float;
}

obj ScenarioPresetView {
    has preset_id: str,
        name: str,
        scenario: str,
        seed: int,
        intensity: int,
        device_density: int,
        gateway_ratio: int,
        infrastructure_damage: int,
        simulation_speed: float,
        sound_enabled: bool,
        live_mode: bool,
        created_at: str,
        export_json: str;
}

obj TimelineEventView {
    has event_id: str,
        alert_id: str,
        event_time: str,
        event_type: str,
        message: str,
        sequence: int;
}

obj RunArchiveView {
    has run_id: str,
        name: str,
        scenario: str,
        seed: int,
        created_at: str,
        alert_count: int,
        device_count: int,
        gateway_count: int,
        delivery_rate: int,
        average_hops: float,
        assignment_coverage: int,
        unresolved_criticals: int,
        review_score: int,
        review_status: str;
}

obj ComparisonDeltaView {
    has key: str,
        label: str,
        value_a: float,
        value_b: float,
        delta: float,
        higher_is_better: bool;
}

obj RunComparisonView {
    has run_a: RunArchiveView | None,
        run_b: RunArchiveView | None,
        deltas: list[ComparisonDeltaView];
}

obj DrillBriefingView {
    has title: str,
        focus: str,
        mission_objectives: list[str],
        failure_injects: list[str],
        evidence_targets: list[str],
        archive_action: str;
}

obj DrillReviewView {
    has review_id: str,
        run_id: str,
        reviewer: str,
        notes: str,
        score: int,
        status: str,
        signed_at: str,
        score_delta: int,
        export_json: str;
}

obj DrillHandoffView {
    has handoff_id: str,
        review_id: str,
        run_id: str,
        receiving_operator: str,
        operator_notes: str,
        lifecycle_state: str,
        disposition: str,
        resolution: str,
        follow_up_date: str,
        updated_at: str,
        follow_up_status: str,
        export_json: str;
}

obj PersistenceView {
    has status: str,
        archive_mode_label: str,
        message: str,
        preset_count: int,
        run_count: int,
        review_count: int,
        handoff_count: int;
}

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

obj DrillWorkspace {
    has controls: ScenarioControlsView,
        metrics: ScenarioMetricsView,
        presets: list[ScenarioPresetView],
        runs: list[RunArchiveView],
        timeline: list[TimelineEventView],
        briefing: DrillBriefingView,
        reviews: list[DrillReviewView],
        handoffs: list[DrillHandoffView],
        persistence: PersistenceView;
}

obj ReplaySnapshot {
    has run_id: str,
        position: int,
        visible_alerts: list[AlertView],
        visible_events: list[TimelineEventView],
        current_time: str;
}

obj AgentBriefing {
    has headline: str,
        summary: str,
        actions: list[str],
        confidence: str,
        reasoning: str,
        mode: str;
}

sem AgentBriefing.headline = "A concise incident-operations headline.";
sem AgentBriefing.summary = "A grounded summary using only the supplied simulated incident context.";
sem AgentBriefing.actions = "Three prioritized, concrete operator actions.";
sem AgentBriefing.confidence = "One of high, medium, or low.";
sem AgentBriefing.reasoning = "A short explanation citing the incident signals that drove the recommendation.";
sem AgentBriefing.mode = "Set to Jac byLLM.";

def _agent_brief(
    incident_context: str,
    operator_question: str,
) -> AgentBriefing by llm(
    system_prompt="You are the SafeRelay operations analyst for a clearly labeled disaster drill. Never invent live conditions, official guidance, people, or resources. Use only the supplied simulation context. Keep recommendations advisory, specific, and easy to audit."
);
sem _agent_brief = "Produce a structured advisory operations briefing for the simulated incident.";
sem _agent_brief.incident_context = "Current typed SafeRelay drill snapshot rendered as concise facts.";
sem _agent_brief.operator_question = "The operator's requested analysis or decision.";


def _current_incident -> Incident | None {
    incidents: list[Incident] = [root -->[?:Incident]];
    return incidents[0] if incidents else None;
}

def _add_activity(
    incident: Incident,
    event_id: str,
    event_time: str,
    event_type: str,
    message: str,
) -> ActivityEvent {
    event: ActivityEvent = ActivityEvent(
        event_id=event_id,
        event_time=event_time,
        event_type=event_type,
        message=message,
    );
    incident +>:IncidentActivity():+> event;
    return event;
}

def _add_alert(
    incident: Incident,
    alert_id: str,
    caller: str,
    emergency_type: str,
    priority: str,
    status: str,
    message: str,
    zone: str,
    map_x: int,
    map_y: int,
    battery: int,
    hop_count: int,
    originator: str,
    received_at: str,
    assigned_to: str = "",
    originated_at: str = "",
    acknowledged_at: str = "",
    resolved_at: str = "",
    resolution_notes: str = "",
    delivered_via: str = "mesh_relay",
    delivered_by: str = "",
) -> Alert {
    alert: Alert = Alert(
        alert_id=alert_id,
        caller=caller,
        emergency_type=emergency_type,
        priority=priority,
        status=status,
        message=message,
        zone=zone,
        map_x=map_x,
        map_y=map_y,
        battery=battery,
        hop_count=hop_count,
        originator=originator,
        received_at=received_at,
        assigned_to=assigned_to,
        originated_at=originated_at or received_at,
        acknowledged_at=acknowledged_at,
        resolved_at=resolved_at,
        resolution_notes=resolution_notes,
        delivered_via=delivered_via,
        delivered_by=delivered_by,
    );
    incident +>:IncidentAlert():+> alert;
    return alert;
}

def _add_hop(
    alert: Alert,
    hop_order: int,
    device_id: str,
    label: str,
    rssi: int,
    battery: int,
    had_internet: bool = False,
) -> RelayHop {
    hop: RelayHop = RelayHop(
        hop_order=hop_order,
        device_id=device_id,
        label=label,
        rssi=rssi,
        battery=battery,
        had_internet=had_internet,
    );
    alert +>:RelayedThrough():+> hop;
    return hop;
}

def _add_responder(
    incident: Incident,
    responder_id: str,
    name: str,
    role: str,
    zone: str,
    status: str,
    eta_minutes: int,
    capacity: int = 4,
) -> Responder {
    responder: Responder = Responder(
        responder_id=responder_id,
        name=name,
        role=role,
        zone=zone,
        status=status,
        eta_minutes=eta_minutes,
        capacity=capacity,
    );
    incident +>:IncidentResponder():+> responder;
    return responder;
}

def _clamp_percent(value: int) -> int {
    return min(100, max(0, value));
}

def _seed_value(seed: int, index: int) -> int {
    return ((max(1, seed) * 16807) + ((index + 1) * 48271)) % 2147483647;
}

def _scenario_base_counts(scenario: str) -> tuple[int, int] {
    if scenario == "tornado" { return (21, 75); }
    if scenario == "hurricane" { return (37, 125); }
    if scenario == "earthquake" { return (42, 150); }
    return (30, 100);
}

def _seed_incident(
    scenario: str,
    seed: int = 42,
    intensity: int = 65,
    device_density: int = 70,
    gateway_ratio: int = 30,
    infrastructure_damage: int = 55,
    simulation_speed: float = 1.0,
    is_running: bool = False,
    sound_enabled: bool = True,
    live_mode: bool = False,
) -> Incident {
    incident_name: str = "Paradise Fire Complex";
    area: str = "Butte County, California";
    started_at: str = "14:32 PDT";
    if scenario == "tornado" {
        incident_name = "Oklahoma Tornado Outbreak";
        area = "Oklahoma City Metro";
        started_at = "16:42 CDT";
    } elif scenario == "hurricane" {
        incident_name = "Hurricane Response - Galveston";
        area = "Galveston County, Texas";
        started_at = "05:12 CDT";
    } elif scenario == "earthquake" {
        incident_name = "San Andreas Fault Activity";
        area = "Greater Los Angeles, California";
        started_at = "09:17 PDT";
    }

    normalized_intensity: int = _clamp_percent(intensity);
    normalized_density: int = _clamp_percent(device_density);
    normalized_gateway: int = _clamp_percent(gateway_ratio);
    normalized_damage: int = _clamp_percent(infrastructure_damage);
    base_counts: tuple[int, int] = _scenario_base_counts(scenario);
    device_count: int = max(8, round(base_counts[1] * (0.55 + (normalized_density / 100.0) * 1.05)));
    gateway_count: int = max(1, round(device_count * max(2, normalized_gateway) / 100.0));

    incident: Incident = root ++> Incident(
        scenario=scenario,
        name=incident_name,
        area=area,
        started_at=started_at,
        seed=max(1, seed),
        intensity=normalized_intensity,
        device_density=normalized_density,
        gateway_ratio=normalized_gateway,
        infrastructure_damage=normalized_damage,
        simulation_speed=simulation_speed if simulation_speed in [0.5, 1.0, 4.0, 16.0] else 1.0,
        is_running=is_running,
        sound_enabled=sound_enabled,
        live_mode=live_mode,
        device_count=device_count,
        gateway_count=gateway_count,
    );

    _add_responder(incident, "fire-1", "Fire Strike 1", "Fire suppression", "East Ridge", "deployed", 8, 4);
    _add_responder(incident, "ems-1", "EMS Medic 1", "Emergency medical", "North Ridge", "available", 6, 5);
    _add_responder(incident, "sar-1", "Search Rescue 1", "Search and rescue", "Canyon", "available", 12, 6);
    _add_responder(incident, "police-1", "Security Detail 1", "Public safety", "West Flat", "available", 10, 4);
    _add_responder(incident, "logistics-1", "Logistics Relay 1", "Logistics and gateway", "Lake", "deployed", 15, 8);

    alert_a: Alert = _add_alert(
        incident, "SOS-1042", "Evelyn R.", "MEDICAL", "critical", "active",
        "Severe breathing difficulty; two people sheltering in place.",
        "North Ridge", 24, 31, 38, 4, "AM-7C21", "14:37", "",
        "14:36", "", "", "", "mesh_relay", "GW-ALPHA",
    );
    _add_hop(alert_a, 1, "AM-7C21", "Origin phone", -61, 38);
    _add_hop(alert_a, 2, "AM-1F09", "Neighbor relay", -68, 72);
    _add_hop(alert_a, 3, "AM-42BE", "Trail relay", -73, 51);
    _add_hop(alert_a, 4, "GW-ALPHA", "Mobile gateway", -57, 84, True);

    alert_b: Alert = _add_alert(
        incident, "SOS-1039", "Noah K.", "FIRE", "critical", "acknowledged",
        "Visible embers crossing the road near a blocked evacuation lane.",
        "East Ridge", 69, 24, 61, 3, "AM-9A32", "14:35", "fire-1",
        "14:33", "14:36", "", "", "mesh_relay", "GW-BRAVO",
    );
    _add_hop(alert_b, 1, "AM-9A32", "Origin phone", -58, 61);
    _add_hop(alert_b, 2, "AM-B410", "Vehicle relay", -65, 47);
    _add_hop(alert_b, 3, "GW-BRAVO", "Shelter gateway", -49, 92, True);

    alert_c: Alert = _add_alert(
        incident, "SOS-1036", "Sam T.", "ACCESS", "high", "active",
        "Fallen tree blocks the canyon route; pedestrian passage only.",
        "Canyon", 49, 61, 44, 5, "AM-3D77", "14:33", "",
        "14:30", "", "", "", "mesh_relay", "GW-BRAVO",
    );
    _add_hop(alert_c, 1, "AM-3D77", "Origin phone", -64, 44);
    _add_hop(alert_c, 2, "AM-923A", "Hiker relay", -76, 35);
    _add_hop(alert_c, 3, "AM-C812", "Ranger relay", -70, 68);
    _add_hop(alert_c, 4, "AM-09FE", "Roadside relay", -79, 29);
    _add_hop(alert_c, 5, "GW-BRAVO", "Shelter gateway", -52, 92, True);

    alert_d: Alert = _add_alert(
        incident, "SOS-1031", "Amina P.", "SUPPLIES", "medium", "responding",
        "Shelter generator fuel estimated below two hours.",
        "Lake", 76, 71, 79, 2, "AM-441C", "14:28", "logistics-1",
        "14:27", "14:30", "", "", "mesh_relay", "GW-DELTA",
    );
    _add_hop(alert_d, 1, "AM-441C", "Shelter phone", -55, 79);
    _add_hop(alert_d, 2, "GW-DELTA", "Command gateway", -46, 96, True);

    alert_e: Alert = _add_alert(
        incident, "SOS-1028", "Diego M.", "CHECK-IN", "low", "active",
        "Family of four is safe at the marked community assembly point.",
        "West Flat", 18, 74, 83, 2, "AM-88F2", "14:24", "",
        "14:23", "", "", "", "mesh_relay", "GW-ALPHA",
    );
    _add_hop(alert_e, 1, "AM-88F2", "Origin phone", -59, 83);
    _add_hop(alert_e, 2, "GW-ALPHA", "Mobile gateway", -50, 84, True);

    alert_f: Alert = _add_alert(
        incident, "SOS-1024", "Unknown device", "MEDICAL", "high", "resolved",
        "Minor laceration treated by volunteer medic.",
        "North Ridge", 35, 43, 26, 3, "AM-014D", "14:18", "ems-1",
        "14:15", "14:20", "14:42", "Minor laceration treated by volunteer medic.",
        "mesh_relay", "GW-ALPHA",
    );
    _add_hop(alert_f, 1, "AM-014D", "Origin phone", -67, 26);
    _add_hop(alert_f, 2, "AM-1F09", "Neighbor relay", -72, 72);
    _add_hop(alert_f, 3, "GW-ALPHA", "Mobile gateway", -51, 84, True);

    target_alerts: int = max(
        6,
        round(base_counts[0] * (0.55 + (normalized_intensity / 100.0) * 1.15)),
    );
    primary_type: str = "FIRE" if scenario == "wildfire" else "NATURAL DISASTER";
    generated_types: list[str] = [
        primary_type,
        primary_type,
        primary_type,
        "MEDICAL",
        "MEDICAL",
        "ACCESS",
        "SECURITY",
        "SUPPLIES",
    ];
    generated_messages: list[str] = [
        "Trapped residents report an obstructed evacuation route.",
        "Medical support requested where cellular service is unavailable.",
        "Infrastructure damage has isolated a neighborhood access point.",
        "Mesh relay reports rising water, debris, or fire exposure nearby.",
        "Shelter requests a welfare check and additional supplies.",
        "Responder vehicle cannot reach the reported location directly.",
    ];
    generated_zones: list[str] = ["North Ridge", "East Ridge", "Canyon", "Lake", "West Flat"];
    for idx in range(max(0, target_alerts - 6)) {
        value: int = _seed_value(seed, idx);
        priority: str = "critical" if value % 100 < max(10, normalized_intensity // 3) else (
            "high" if value % 100 < 62 else ("medium" if value % 100 < 88 else "low")
        );
        status_index: int = (value // 97) % 10;
        status: str = "active";
        acknowledged_at: str = "";
        if status_index in [5, 6] {
            status = "acknowledged";
            acknowledged_at = f"T-{(idx % 90) + 2:03d}";
        } elif status_index in [7, 8] {
            status = "responding";
            acknowledged_at = f"T-{(idx % 90) + 2:03d}";
        } elif status_index == 9 {
            status = "resolved";
            acknowledged_at = f"T-{(idx % 90) + 2:03d}";
        }
        direct_threshold: int = max(8, 44 - (normalized_damage * 32 // 100));
        is_direct: bool = (value // 13) % 100 < direct_threshold;
        max_hops: int = 3 + ((normalized_damage * 4 + 50) // 100);
        generated_hops: int = 0 if is_direct else 1 + ((value // 101) % max_hops);
        generated_id: str = f"SOS-{2000 + idx}";
        generated_alert: Alert = _add_alert(
            incident,
            generated_id,
            f"Mesh device {idx + 1}",
            generated_types[idx % len(generated_types)],
            priority,
            status,
            generated_messages[(value // 17) % len(generated_messages)],
            generated_zones[(value // 23) % len(generated_zones)],
            8 + ((value // 29) % 84),
            10 + ((value // 31) % 78),
            12 + ((value // 37) % 87),
            generated_hops,
            f"AM-{(value % 65535):04X}",
            f"T-{(idx % 180) + 1:03d}",
            "",
            f"T-{(idx % 180) + 2:03d}",
            acknowledged_at,
            f"T-{(idx % 90) + 1:03d}" if status_index == 9 else "",
            "Exercise controller confirmed the modeled response outcome." if status_index == 9 else "",
            "direct" if is_direct else "mesh_relay",
            "" if is_direct else f"GW-{1 + (idx % max(1, gateway_count))}",
        );
        for hop_idx in range(generated_hops) {
            final_hop: bool = hop_idx == generated_hops - 1;
            _add_hop(
                generated_alert,
                hop_idx + 1,
                f"GW-{1 + (idx % max(1, gateway_count))}" if final_hop else f"AM-{idx:03d}-{hop_idx:02d}",
                "Internet gateway" if final_hop else "Phone relay",
                -45 - ((value + hop_idx * 7) % 42),
                20 + ((value + hop_idx * 13) % 80),
                final_hop,
            );
        }
    }

    _add_activity(incident, "EV-01", "14:37", "critical", "Medical SOS escaped the outage through four BLE hops.");
    _add_activity(incident, "EV-02", "14:35", "dispatch", "R-04 acknowledged ember crossing report in East Ridge.");
    _add_activity(incident, "EV-03", "14:33", "mesh", "Gateway Bravo accepted a five-hop canyon packet.");
    _add_activity(incident, "EV-04", "14:30", "system", "North Ridge delivery reliability recovered to 86%.");
    return incident;
}

def _clear_graph {
    for incident in [root -->[?:Incident]] {
        for alert in [incident ->:IncidentAlert:->[?:Alert]] {
            for hop in [alert ->:RelayedThrough:->[?:RelayHop]] {
                alert del ->:RelayedThrough:-> hop;
                del hop;
            }
            incident del ->:IncidentAlert:-> alert;
            del alert;
        }
        for responder in [incident ->:IncidentResponder:->[?:Responder]] {
            incident del ->:IncidentResponder:-> responder;
            del responder;
        }
        for event in [incident ->:IncidentActivity:->[?:ActivityEvent]] {
            incident del ->:IncidentActivity:-> event;
            del event;
        }
        root del --> incident;
        del incident;
    }
}

def _priority_rank(priority: str) -> int {
    if priority == "critical" { return 0; }
    if priority == "high" { return 1; }
    if priority == "medium" { return 2; }
    return 3;
}

def _snapshot(incident: Incident) -> OpsSnapshot {
    alerts: list[AlertView] = [];
    active_count: int = 0;
    critical_count: int = 0;
    total_hops: int = 0;
    mesh_count: int = 0;
    alert_nodes: list[Alert] = [incident ->:IncidentAlert:->[?:Alert]];
    alert_nodes = sorted(alert_nodes, key=lambda (item: Alert) { (_priority_rank(item.priority), item.received_at); });
    for alert in alert_nodes {
        if alert.status != "resolved" { active_count += 1; }
        if alert.priority == "critical" and alert.status != "resolved" { critical_count += 1; }
        total_hops += alert.hop_count;
        if alert.hop_count > 1 { mesh_count += 1; }
        alerts.append(AlertView(
            alert_id=alert.alert_id,
            caller=alert.caller,
            emergency_type=alert.emergency_type,
            priority=alert.priority,
            status=alert.status,
            message=alert.message,
            zone=alert.zone,
            map_x=alert.map_x,
            map_y=alert.map_y,
            battery=alert.battery,
            hop_count=alert.hop_count,
            originator=alert.originator,
            received_at=alert.received_at,
            assigned_to=alert.assigned_to,
            originated_at=alert.originated_at,
            acknowledged_at=alert.acknowledged_at,
            resolved_at=alert.resolved_at,
            resolution_notes=alert.resolution_notes,
            delivered_via=alert.delivered_via,
            delivered_by=alert.delivered_by,
        ));
    }

    responders: list[ResponderView] = [];
    responder_available: int = 0;
    for responder in [incident ->:IncidentResponder:->[?:Responder]] {
        if responder.status == "available" { responder_available += 1; }
        responders.append(ResponderView(
            responder_id=responder.responder_id,
            name=responder.name,
            role=responder.role,
            zone=responder.zone,
            status=responder.status,
            eta_minutes=responder.eta_minutes,
            capacity=responder.capacity,
        ));
    }

    activity: list[ActivityView] = [];
    for event in reversed([incident ->:IncidentActivity:->[?:ActivityEvent]]) {
        activity.append(ActivityView(
            event_id=event.event_id,
            event_time=event.event_time,
            event_type=event.event_type,
            message=event.message,
        ));
    }

    zone_names: list[str] = ["North Ridge", "East Ridge", "Canyon", "Lake"];
    zones: list[ZoneView] = [];
    damage_penalty: int = round(incident.infrastructure_damage * 0.22);
    zone_health: list[int] = [
        max(40, 98 - damage_penalty),
        max(36, 91 - damage_penalty),
        max(30, 84 - damage_penalty),
        max(45, 100 - damage_penalty),
    ];
    zone_node_base: int = max(4, incident.device_count // 4);
    zone_nodes: list[int] = [
        zone_node_base,
        max(3, zone_node_base - 4),
        max(3, zone_node_base - 8),
        zone_node_base + 6,
    ];
    zone_gateways: list[str] = ["GW-ALPHA", "GW-BRAVO", "GW-BRAVO", "GW-DELTA"];
    for idx in range(len(zone_names)) {
        zone_alerts: int = len([a for a in alert_nodes if a.zone == zone_names[idx] and a.status != "resolved"]);
        zones.append(ZoneView(
            name=zone_names[idx],
            health=max(45, zone_health[idx] - incident.tick * (2 if idx == 2 else 0)),
            nodes_online=zone_nodes[idx],
            alerts=zone_alerts,
            gateway=zone_gateways[idx],
        ));
    }

    alert_total: int = len(alert_nodes);
    stats: OpsStats = OpsStats(
        active_alerts=active_count,
        critical_alerts=critical_count,
        responders_available=responder_available,
        mesh_delivery_percent=round((mesh_count / alert_total) * 100) if alert_total else 0,
        average_hops=round(total_hops / alert_total, 1) if alert_total else 0.0,
        network_health=max(35, 96 - (incident.infrastructure_damage * 34 // 100) - incident.tick),
    );
    return OpsSnapshot(
        incident_name=incident.name,
        scenario=incident.scenario,
        area=incident.area,
        started_at=incident.started_at,
        phase=incident.phase,
        tick=incident.tick,
        source_mode="SIMULATED DRILL",
        stats=stats,
        alerts=alerts,
        responders=responders,
        activity=activity[:8],
        zones=zones,
    );
}

def _find_alert(incident: Incident, alert_id: str) -> Alert | None {
    for alert in [incident ->:IncidentAlert:->[?:Alert]] {
        if alert.alert_id == alert_id { return alert; }
    }
    return None;
}

def _find_responder(incident: Incident, responder_id: str) -> Responder | None {
    for responder in [incident ->:IncidentResponder:->[?:Responder]] {
        if responder.responder_id == responder_id { return responder; }
    }
    return None;
}

def _require_identifier(value: str, label: str) -> str {
    cleaned: str = value.strip();
    if not cleaned or len(cleaned) > 32 {
        raise ValueError(f"{label} must be between 1 and 32 characters.");
    }
    return cleaned;
}

def _fallback_briefing(snapshot: OpsSnapshot, question: str) -> AgentBriefing {
    top_alert: AlertView | None = snapshot.alerts[0] if snapshot.alerts else None;
    headline: str = "Stabilize the critical queue and protect the canyon relay corridor";
    summary: str = (
        f"{snapshot.incident_name} has {snapshot.stats.active_alerts} active alerts, "
        f"{snapshot.stats.critical_alerts} critical, with mesh delivery at "
        f"{snapshot.stats.mesh_delivery_percent}%. "
        f"The weakest modeled zone is Canyon at {snapshot.zones[2].health}% health."
    );
    actions: list[str] = [
        "Assign the nearest medical responder to SOS-1042 and confirm the destination route.",
        "Stage a second gateway near Canyon before its modeled network health drops further.",
        "Recheck all active alerts with device battery below 45% within the next drill tick.",
    ];
    if top_alert {
        actions[0] = f"Prioritize {top_alert.alert_id}: {top_alert.message}";
    }
    return AgentBriefing(
        headline=headline,
        summary=summary,
        actions=actions,
        confidence="high",
        reasoning=f"Deterministic Jac policy evaluated priority, assignment, battery, zone health, and relay depth. Operator question: {question}",
        mode="Deterministic Jac fallback",
    );
}

def _context_for(snapshot: OpsSnapshot) -> str {
    alert_lines: list[str] = [
        f"{alert.alert_id}: {alert.priority}, {alert.status}, {alert.zone}, battery {alert.battery}%, hops {alert.hop_count}, assigned {alert.assigned_to or 'none'}"
        for alert in snapshot.alerts
    ];
    zone_lines: list[str] = [
        f"{zone.name}: health {zone.health}%, nodes {zone.nodes_online}, active alerts {zone.alerts}, gateway {zone.gateway}"
        for zone in snapshot.zones
    ];
    return (
        f"SIMULATED DRILL ONLY. Incident: {snapshot.incident_name}. "
        f"Area: {snapshot.area}. Phase: {snapshot.phase}. "
        f"Stats: {snapshot.stats.active_alerts} active, {snapshot.stats.critical_alerts} critical, "
        f"{snapshot.stats.responders_available} responders available, "
        f"{snapshot.stats.mesh_delivery_percent}% mesh delivery. "
        f"Alerts: {' | '.join(alert_lines)}. Zones: {' | '.join(zone_lines)}."
    );
}


def _scenario_metrics(incident: Incident) -> ScenarioMetricsView {
    alerts: list[Alert] = [incident ->:IncidentAlert:->[?:Alert]];
    total: int = len(alerts);
    mesh_count: int = len([alert for alert in alerts if alert.delivered_via == "mesh_relay"]);
    total_hops: int = sum([alert.hop_count for alert in alerts]);
    unresolved: list[Alert] = [alert for alert in alerts if alert.status != "resolved"];
    assigned: list[Alert] = [alert for alert in unresolved if alert.assigned_to];
    assigned_etas: list[int] = [];
    for alert in assigned {
        responder: Responder | None = _find_responder(incident, alert.assigned_to);
        if responder { assigned_etas.append(responder.eta_minutes); }
    }
    active_probability: float = max(0.48, 0.94 - (incident.infrastructure_damage / 100.0) * 0.42);
    active_devices: int = round(incident.device_count * active_probability);
    return ScenarioMetricsView(
        alert_volume=total,
        active_devices=active_devices,
        gateway_coverage_score=round((incident.gateway_count / incident.device_count) * 100) if incident.device_count else 0,
        delivery_rate=100 if total else 0,
        mesh_relay_percentage=round((mesh_count / total) * 100) if total else 0,
        average_hops=round(total_hops / total, 1) if total else 0.0,
        unresolved_criticals=len([alert for alert in unresolved if alert.priority == "critical"]),
        acknowledged_count=len([alert for alert in alerts if alert.status in ["acknowledged", "responding"]]),
        resolved_count=len([alert for alert in alerts if alert.status == "resolved"]),
        assigned_alert_count=len(assigned),
        assignment_coverage=round((len(assigned) / len(unresolved)) * 100) if unresolved else 100,
        average_eta_minutes=round(sum(assigned_etas) / len(assigned_etas), 1) if assigned_etas else 0.0,
    );
}

def _controls_view(incident: Incident) -> ScenarioControlsView {
    return ScenarioControlsView(
        scenario=incident.scenario,
        seed=incident.seed,
        intensity=incident.intensity,
        device_density=incident.device_density,
        gateway_ratio=incident.gateway_ratio,
        infrastructure_damage=incident.infrastructure_damage,
        simulation_speed=incident.simulation_speed,
        is_running=incident.is_running,
        sound_enabled=incident.sound_enabled,
        live_mode=incident.live_mode,
        device_count=incident.device_count,
        gateway_count=incident.gateway_count,
    );
}

def _assignment_data(incident: Incident) -> str {
    assignments: dict[str, list[str]] = {};
    for responder in [incident ->:IncidentResponder:->[?:Responder]] {
        assigned_ids: list[str] = [
            alert.alert_id
            for alert in [incident ->:IncidentAlert:->[?:Alert]]
            if alert.assigned_to == responder.responder_id
        ];
        if assigned_ids { assignments[responder.responder_id] = assigned_ids; }
    }
    return json.dumps(assignments, sort_keys=True);
}

def _current_timeline(incident: Incident) -> list[TimelineEventView] {
    events: list[TimelineEventView] = [];
    sequence: int = 0;
    for alert in sorted(
        [incident ->:IncidentAlert:->[?:Alert]],
        key=lambda (item: Alert) { item.alert_id; },
    ) {
        sequence += 1;
        events.append(TimelineEventView(
            event_id=f"TL-{alert.alert_id}-ORIGIN",
            alert_id=alert.alert_id,
            event_time=alert.originated_at or alert.received_at,
            event_type="originated",
            message=f"{alert.alert_id} originated from {alert.originator}.",
            sequence=sequence,
        ));
        for hop in sorted(
            [alert ->:RelayedThrough:->[?:RelayHop]],
            key=lambda (item: RelayHop) { item.hop_order; },
        ) {
            sequence += 1;
            events.append(TimelineEventView(
                event_id=f"TL-{alert.alert_id}-HOP-{hop.hop_order}",
                alert_id=alert.alert_id,
                event_time=alert.received_at,
                event_type="gateway" if hop.had_internet else "relay_hop",
                message=f"{alert.alert_id} reached {hop.device_id} via {hop.label}.",
                sequence=sequence,
            ));
        }
        sequence += 1;
        events.append(TimelineEventView(
            event_id=f"TL-{alert.alert_id}-RECEIVED",
            alert_id=alert.alert_id,
            event_time=alert.received_at,
            event_type="received",
            message=f"{alert.alert_id} arrived at command via {alert.delivered_via.replace('_', ' ')}.",
            sequence=sequence,
        ));
        if alert.assigned_to {
            sequence += 1;
            events.append(TimelineEventView(
                event_id=f"TL-{alert.alert_id}-ASSIGNED",
                alert_id=alert.alert_id,
                event_time=alert.acknowledged_at or alert.received_at,
                event_type="assigned",
                message=f"{alert.assigned_to} assigned to {alert.alert_id}.",
                sequence=sequence,
            ));
        } elif alert.acknowledged_at {
            sequence += 1;
            events.append(TimelineEventView(
                event_id=f"TL-{alert.alert_id}-ACK",
                alert_id=alert.alert_id,
                event_time=alert.acknowledged_at,
                event_type="acknowledged",
                message=f"{alert.alert_id} acknowledged by command.",
                sequence=sequence,
            ));
        }
        if alert.resolved_at {
            sequence += 1;
            events.append(TimelineEventView(
                event_id=f"TL-{alert.alert_id}-RESOLVED",
                alert_id=alert.alert_id,
                event_time=alert.resolved_at,
                event_type="resolved",
                message=f"{alert.alert_id} resolved. {alert.resolution_notes}",
                sequence=sequence,
            ));
        }
    }
    return events;
}

def _briefing_for(incident: Incident) -> DrillBriefingView {
    metrics: ScenarioMetricsView = _scenario_metrics(incident);
    focus: str = "mesh";
    if metrics.assignment_coverage < 50 { focus = "responder"; }
    elif metrics.gateway_coverage_score < 30 { focus = "gateway"; }
    objectives: list[str] = [
        f"Deliver every critical {incident.scenario} signal into command with auditable relay provenance.",
        f"Raise responder assignment coverage above {max(75, metrics.assignment_coverage)}%.",
        f"Keep gateway coverage observable while infrastructure damage is modeled at {incident.infrastructure_damage}%.",
    ];
    injects: list[str] = [
        "Remove a gateway from the highest-volume zone and validate rerouting.",
        "Introduce a critical medical alert with a low-battery origin device.",
        "Delay one receiving team acknowledgment and exercise the handoff queue.",
    ];
    evidence: list[str] = [
        "Ordered relay timeline with a final internet-capable gateway.",
        "Responder assignment event and updated coverage calculation.",
        "Frozen run archive, signed review, and receiving-operator handoff.",
    ];
    return DrillBriefingView(
        title=f"{incident.scenario.title()} response drill brief",
        focus=focus,
        mission_objectives=objectives,
        failure_injects=injects,
        evidence_targets=evidence,
        archive_action="Save to the authenticated Jac graph and export the preset JSON.",
    );
}

def _preset_export(preset: ScenarioPreset) -> str {
    return json.dumps({
        "version": 1,
        "name": preset.name,
        "scenario": preset.scenario,
        "seed": preset.seed,
        "generationOptions": {
            "intensity": preset.intensity,
            "deviceDensity": preset.device_density,
            "gatewayRatio": preset.gateway_ratio,
            "infrastructureDamage": preset.infrastructure_damage,
        },
        "simulationSpeed": preset.simulation_speed,
        "soundEnabled": preset.sound_enabled,
        "liveMode": preset.live_mode,
        "responderAssignments": json.loads(preset.assignment_data or "{}"),
    }, sort_keys=True);
}

def _preset_view(preset: ScenarioPreset) -> ScenarioPresetView {
    return ScenarioPresetView(
        preset_id=preset.preset_id,
        name=preset.name,
        scenario=preset.scenario,
        seed=preset.seed,
        intensity=preset.intensity,
        device_density=preset.device_density,
        gateway_ratio=preset.gateway_ratio,
        infrastructure_damage=preset.infrastructure_damage,
        simulation_speed=preset.simulation_speed,
        sound_enabled=preset.sound_enabled,
        live_mode=preset.live_mode,
        created_at=preset.created_at,
        export_json=_preset_export(preset),
    );
}

def _run_view(run: RunArchive) -> RunArchiveView {
    return RunArchiveView(
        run_id=run.run_id,
        name=run.name,
        scenario=run.scenario,
        seed=run.seed,
        created_at=run.created_at,
        alert_count=run.alert_count,
        device_count=run.device_count,
        gateway_count=run.gateway_count,
        delivery_rate=run.delivery_rate,
        average_hops=run.average_hops,
        assignment_coverage=run.assignment_coverage,
        unresolved_criticals=run.unresolved_criticals,
        review_score=run.review_score,
        review_status=run.review_status,
    );
}

def _review_views -> list[DrillReviewView] {
    reviews: list[DrillReview] = [root -->[?:DrillReview]];
    reviews = sorted(reviews, key=lambda (item: DrillReview) { item.signed_at; }, reverse=True);
    views: list[DrillReviewView] = [];
    previous_score: int = 0;
    for idx in range(len(reviews)) {
        current: DrillReview = reviews[idx];
        if idx + 1 < len(reviews) { previous_score = reviews[idx + 1].score; }
        else { previous_score = current.score; }
        views.append(DrillReviewView(
            review_id=current.review_id,
            run_id=current.run_id,
            reviewer=current.reviewer,
            notes=current.notes,
            score=current.score,
            status=current.status,
            signed_at=current.signed_at,
            score_delta=current.score - previous_score,
            export_json=json.dumps({
                "version": 1,
                "reviewId": current.review_id,
                "runId": current.run_id,
                "reviewer": current.reviewer,
                "notes": current.notes,
                "score": current.score,
                "status": current.status,
                "signedAt": current.signed_at,
            }, sort_keys=True),
        ));
    }
    return views;
}

def _handoff_follow_up_status(handoff: DrillHandoff) -> str {
    if handoff.resolution != "needs_follow_up" { return "none"; }
    if not handoff.follow_up_date { return "unscheduled"; }
    return "scheduled";
}

def _handoff_views -> list[DrillHandoffView] {
    handoffs: list[DrillHandoff] = [root -->[?:DrillHandoff]];
    handoffs = sorted(handoffs, key=lambda (item: DrillHandoff) { item.updated_at; }, reverse=True);
    return [
        DrillHandoffView(
            handoff_id=item.handoff_id,
            review_id=item.review_id,
            run_id=item.run_id,
            receiving_operator=item.receiving_operator,
            operator_notes=item.operator_notes,
            lifecycle_state=item.lifecycle_state,
            disposition=item.disposition,
            resolution=item.resolution,
            follow_up_date=item.follow_up_date,
            updated_at=item.updated_at,
            follow_up_status=_handoff_follow_up_status(item),
            export_json=json.dumps({
                "version": 1,
                "handoffId": item.handoff_id,
                "reviewId": item.review_id,
                "runId": item.run_id,
                "receivingOperator": item.receiving_operator,
                "operatorNotes": item.operator_notes,
                "lifecycleState": item.lifecycle_state,
                "disposition": item.disposition,
                "resolution": item.resolution,
                "followUpDate": item.follow_up_date,
                "updatedAt": item.updated_at,
            }, sort_keys=True),
        )
        for item in handoffs
    ];
}

def _workspace(incident: Incident) -> DrillWorkspace {
    presets: list[ScenarioPresetView] = [
        _preset_view(item)
        for item in sorted(
            [root -->[?:ScenarioPreset]],
            key=lambda (preset: ScenarioPreset) { preset.created_at; },
            reverse=True,
        )
    ];
    runs: list[RunArchiveView] = [
        _run_view(item)
        for item in sorted(
            [root -->[?:RunArchive]],
            key=lambda (run: RunArchive) { run.created_at; },
            reverse=True,
        )
    ];
    reviews: list[DrillReviewView] = _review_views();
    handoffs: list[DrillHandoffView] = _handoff_views();
    return DrillWorkspace(
        controls=_controls_view(incident),
        metrics=_scenario_metrics(incident),
        presets=presets,
        runs=runs,
        timeline=_current_timeline(incident),
        briefing=_briefing_for(incident),
        reviews=reviews,
        handoffs=handoffs,
        persistence=PersistenceView(
            status="ready",
            archive_mode_label="Jac graph synchronized",
            message="Presets, run artifacts, reviews, and handoffs are durable in this operator's authenticated root graph.",
            preset_count=len(presets),
            run_count=len(runs),
            review_count=len(reviews),
            handoff_count=len(handoffs),
        ),
    );
}

def _find_preset(preset_id: str) -> ScenarioPreset | None {
    for preset in [root -->[?:ScenarioPreset]] {
        if preset.preset_id == preset_id { return preset; }
    }
    return None;
}

def _find_run(run_id: str) -> RunArchive | None {
    for run in [root -->[?:RunArchive]] {
        if run.run_id == run_id { return run; }
    }
    return None;
}

def _find_review(review_id: str) -> DrillReview | None {
    for review in [root -->[?:DrillReview]] {
        if review.review_id == review_id { return review; }
    }
    return None;
}

def _find_handoff(handoff_id: str) -> DrillHandoff | None {
    for handoff in [root -->[?:DrillHandoff]] {
        if handoff.handoff_id == handoff_id { return handoff; }
    }
    return None;
}

def _apply_assignments(incident: Incident, assignment_data: str) {
    assignments: dict[str, list[str]] = {};
    try {
        assignments = json.loads(assignment_data or "{}");
    } except Exception {
        assignments = {};
    }
    for responder in [incident ->:IncidentResponder:->[?:Responder]] {
        responder.status = "available";
    }
    for responder_id in assignments {
        responder: Responder | None = _find_responder(incident, responder_id);
        if not responder { continue; }
        for (assignment_index, alert_id) in enumerate(assignments[responder_id]) {
            alert: Alert | None = _find_alert(incident, str(alert_id));
            if alert and alert.status != "resolved" and assignment_index < responder.capacity {
                alert.assigned_to = responder.responder_id;
                alert.status = "responding";
                alert.acknowledged_at = alert.acknowledged_at or alert.received_at;
                responder.status = "deployed";
            }
        }
    }
}

def _archive_alert(run: RunArchive, alert: Alert) {
    archived: ArchivedAlert = ArchivedAlert(
        alert_id=alert.alert_id,
        emergency_type=alert.emergency_type,
        priority=alert.priority,
        status=alert.status,
        message=alert.message,
        zone=alert.zone,
        hop_count=alert.hop_count,
        assigned_to=alert.assigned_to,
        originated_at=alert.originated_at,
        received_at=alert.received_at,
        acknowledged_at=alert.acknowledged_at,
        resolved_at=alert.resolved_at,
    );
    run +>:RunAlert():+> archived;
}

def _clear_workspace {
    for run in [root -->[?:RunArchive]] {
        for item in [run ->:RunAlert:->[?:ArchivedAlert]] {
            run del ->:RunAlert:-> item;
            del item;
        }
        for item in [run ->:RunEvent:->[?:ArchivedEvent]] {
            run del ->:RunEvent:-> item;
            del item;
        }
        root del --> run;
        del run;
    }
    for preset in [root -->[?:ScenarioPreset]] {
        root del --> preset;
        del preset;
    }
    for review in [root -->[?:DrillReview]] {
        root del --> review;
        del review;
    }
    for handoff in [root -->[?:DrillHandoff]] {
        root del --> handoff;
        del handoff;
    }
    for cache in [root -->[?:DisasterCache]] {
        for event in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
            cache del ->:DisasterCacheEvent:-> event;
            del event;
        }
        root del --> cache;
        del cache;
    }
}


def:protect get_snapshot -> OpsSnapshot {
    incident: Incident | None = _current_incident();
    if not incident {
        incident = _seed_incident("wildfire");
        commit();
    }
    return _snapshot(incident);
}

def:protect reset_drill(scenario: str) -> OpsSnapshot {
    chosen: str = scenario.strip().lower();
    if chosen not in ["wildfire", "tornado", "hurricane", "earthquake"] {
        raise ValueError("Unsupported drill scenario.");
    }
    _clear_graph();
    incident: Incident = _seed_incident(chosen);
    commit();
    return _snapshot(incident);
}

def:protect configure_drill(
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
    chosen: str = scenario.strip().lower();
    if chosen not in ["wildfire", "tornado", "hurricane", "earthquake"] {
        raise ValueError("Unsupported drill scenario.");
    }
    if seed < 1 or seed > 2147483646 {
        raise ValueError("Seed must be between 1 and 2147483646.");
    }
    if simulation_speed not in [0.5, 1.0, 4.0, 16.0] {
        raise ValueError("Simulation speed must be 0.5, 1, 4, or 16.");
    }
    _clear_graph();
    incident: Incident = _seed_incident(
        chosen,
        seed,
        _clamp_percent(intensity),
        _clamp_percent(device_density),
        _clamp_percent(gateway_ratio),
        _clamp_percent(infrastructure_damage),
        simulation_speed,
        is_running,
        sound_enabled,
        live_mode,
    );
    commit();
    return _snapshot(incident);
}

def:protect get_drill_workspace -> DrillWorkspace {
    incident: Incident | None = _current_incident();
    if not incident {
        incident = _seed_incident("wildfire");
        commit();
    }
    return _workspace(incident);
}

def:protect update_drill_runtime(
    simulation_speed: float,
    is_running: bool,
    sound_enabled: bool,
    live_mode: bool,
) -> DrillWorkspace {
    if simulation_speed not in [0.5, 1.0, 4.0, 16.0] {
        raise ValueError("Simulation speed must be 0.5, 1, 4, or 16.");
    }
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    incident.simulation_speed = simulation_speed;
    incident.is_running = is_running;
    incident.sound_enabled = sound_enabled;
    incident.live_mode = live_mode;
    commit();
    return _workspace(incident);
}

def:protect acknowledge_alert(alert_id: str) -> OpsSnapshot {
    alert_key: str = _require_identifier(alert_id, "Alert ID");
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    alert: Alert | None = _find_alert(incident, alert_key);
    if not alert { raise ValueError("Alert was not found."); }
    if alert.status == "resolved" {
        raise ValueError("Resolved alerts cannot be acknowledged.");
    }
    if alert and alert.status == "active" {
        alert.status = "acknowledged";
        alert.acknowledged_at = f"T+{incident.tick + 1:02d}";
        _add_activity(
            incident,
            f"EV-ACK-{incident.tick}-{alert.alert_id}",
            f"T+{incident.tick + 1:02d}",
            "dispatch",
            f"{alert.alert_id} acknowledged by command.",
        );
    }
    commit();
    return _snapshot(incident);
}

def:protect assign_responder(alert_id: str, responder_id: str) -> OpsSnapshot {
    alert_key: str = _require_identifier(alert_id, "Alert ID");
    responder_key: str = _require_identifier(responder_id, "Responder ID");
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    alert: Alert | None = _find_alert(incident, alert_key);
    selected: Responder | None = _find_responder(incident, responder_key);
    if not alert { raise ValueError("Alert was not found."); }
    if not selected { raise ValueError("Responder was not found."); }
    selected_alert: Alert = alert as Alert;
    selected_responder: Responder = selected as Responder;
    if selected_alert.status == "resolved" {
        raise ValueError("Resolved alerts cannot receive assignments.");
    }
    if selected_alert.assigned_to == selected_responder.responder_id {
        return _snapshot(incident);
    }
    responder_load: int = len([
        item
        for item in [incident ->:IncidentAlert:->[?:Alert]]
        if item.assigned_to == selected_responder.responder_id and item.status != "resolved"
    ]);
    if responder_load >= selected_responder.capacity {
        raise ValueError("Responder team is at capacity.");
    }
    if selected_alert.assigned_to {
        previous: Responder | None = _find_responder(incident, selected_alert.assigned_to);
        if previous {
            previous_load: int = len([
                item
                for item in [incident ->:IncidentAlert:->[?:Alert]]
                if item.assigned_to == previous.responder_id
                and item.alert_id != selected_alert.alert_id
                and item.status != "resolved"
            ]);
            previous.status = "deployed" if previous_load else "available";
        }
    }
    selected_alert.assigned_to = selected_responder.responder_id;
    selected_alert.status = "responding";
    selected_alert.acknowledged_at = selected_alert.acknowledged_at or f"T+{incident.tick + 1:02d}";
    selected_responder.status = "deployed";
    _add_activity(
        incident,
        f"EV-ASG-{incident.tick}-{selected_alert.alert_id}-{selected_responder.responder_id}",
        f"T+{incident.tick + 1:02d}",
        "dispatch",
        f"{selected_responder.name} assigned to {selected_alert.alert_id} in {selected_alert.zone}.",
    );
    commit();
    return _snapshot(incident);
}

def:protect resolve_alert(alert_id: str, resolution_notes: str = "Resolved after operator review.") -> OpsSnapshot {
    alert_key: str = _require_identifier(alert_id, "Alert ID");
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    alert: Alert | None = _find_alert(incident, alert_key);
    if not alert { raise ValueError("Alert was not found."); }
    selected_alert: Alert = alert as Alert;
    if selected_alert.status == "resolved" {
        return _snapshot(incident);
    }
    selected_alert.status = "resolved";
    selected_alert.resolved_at = f"T+{incident.tick + 1:02d}";
    selected_alert.resolution_notes = resolution_notes.strip()[:500] or "Resolved after operator review.";
    if selected_alert.assigned_to {
        assigned: Responder | None = _find_responder(incident, selected_alert.assigned_to);
        if assigned {
            remaining_load: int = len([
                item
                for item in [incident ->:IncidentAlert:->[?:Alert]]
                if item.assigned_to == assigned.responder_id
                and item.alert_id != selected_alert.alert_id
                and item.status != "resolved"
            ]);
            assigned.status = "deployed" if remaining_load else "available";
        }
    }
    _add_activity(
        incident,
        f"EV-RES-{incident.tick}-{selected_alert.alert_id}",
        f"T+{incident.tick + 1:02d}",
        "system",
        f"{selected_alert.alert_id} marked resolved after operator review.",
    );
    commit();
    return _snapshot(incident);
}

def:protect cancel_alert(alert_id: str, cancellation_notes: str = "Cancelled by command.") -> OpsSnapshot {
    alert_key: str = _require_identifier(alert_id, "Alert ID");
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    alert: Alert | None = _find_alert(incident, alert_key);
    if not alert { raise ValueError("Alert was not found."); }
    selected: Alert = alert as Alert;
    if selected.status == "resolved" { return _snapshot(incident); }
    selected.status = "resolved";
    selected.resolved_at = f"T+{incident.tick + 1:02d}";
    selected.resolution_notes = cancellation_notes.strip()[:500] or "Cancelled by command.";
    if selected.assigned_to {
        assigned: Responder | None = _find_responder(incident, selected.assigned_to);
        if assigned { assigned.status = "available"; }
    }
    _add_activity(
        incident,
        f"EV-CANCEL-{incident.tick}-{selected.alert_id}",
        f"T+{incident.tick + 1:02d}",
        "system",
        f"{selected.alert_id} cancelled by command.",
    );
    commit();
    return _snapshot(incident);
}

def:protect advance_drill -> OpsSnapshot {
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    incident.tick += 1;
    if incident.tick == 1 {
        new_alert: Alert = _add_alert(
            incident, "SOS-1047", "Leila G.", "MEDICAL", "high", "active",
            "Mobility assistance requested at the lower trail assembly point.",
            "Canyon", 57, 68, 33, 4, "AM-77C8", "T+01", "",
            "T+00", "", "", "", "mesh_relay", "GW-BRAVO",
        );
        _add_hop(new_alert, 1, "AM-77C8", "Origin phone", -66, 33);
        _add_hop(new_alert, 2, "AM-C812", "Ranger relay", -72, 68);
        _add_hop(new_alert, 3, "AM-09FE", "Roadside relay", -78, 29);
        _add_hop(new_alert, 4, "GW-BRAVO", "Shelter gateway", -54, 92, True);
        _add_activity(incident, "EV-TICK-1", "T+01", "critical", "New high-priority mobility assistance request reached Gateway Bravo.");
    } else {
        value: int = _seed_value(incident.seed, incident.tick + 300);
        live_priority: str = "critical" if value % 100 < max(12, incident.intensity // 3) else (
            "high" if value % 100 < 68 else "medium"
        );
        live_type: str = (
            "FIRE" if incident.scenario == "wildfire" and incident.tick % 3 == 0
            else ("MEDICAL" if incident.tick % 2 == 0 else "NATURAL DISASTER")
        );
        live_hops: int = 1 + ((value // 101) % (3 + max(1, incident.infrastructure_damage // 25)));
        live_alert: Alert = _add_alert(
            incident,
            f"SOS-LIVE-{incident.tick:04d}",
            f"Live mesh origin {incident.tick}",
            live_type,
            live_priority,
            "active",
            "New simulated emergency signal entered the live exercise stream.",
            ["North Ridge", "East Ridge", "Canyon", "Lake", "West Flat"][value % 5],
            8 + ((value // 29) % 84),
            10 + ((value // 31) % 78),
            18 + ((value // 37) % 80),
            live_hops,
            f"AM-LIVE-{incident.tick:04d}",
            f"T+{incident.tick:02d}",
            "",
            f"T+{incident.tick:02d}",
            "",
            "",
            "",
            "mesh_relay",
            f"GW-{1 + (incident.tick % max(1, incident.gateway_count))}",
        );
        for hop_idx in range(live_hops) {
            final_hop: bool = hop_idx == live_hops - 1;
            _add_hop(
                live_alert,
                hop_idx + 1,
                f"GW-{1 + (incident.tick % max(1, incident.gateway_count))}" if final_hop else f"AM-L-{incident.tick:02d}-{hop_idx:02d}",
                "Internet gateway" if final_hop else "Live phone relay",
                -48 - ((value + hop_idx * 5) % 38),
                25 + ((value + hop_idx * 11) % 75),
                final_hop,
            );
        }
        _add_activity(
            incident,
            f"EV-TICK-{incident.tick}",
            f"T+{incident.tick:02d}",
            "mesh",
            f"Drill advanced to tick {incident.tick}; {live_alert.alert_id} joined the mesh stream.",
        );
    }
    commit();
    return _snapshot(incident);
}

def:protect analyze_incident(question: str) -> AgentBriefing {
    operator_question: str = question.strip();
    if not operator_question {
        raise ValueError("An operator question is required.");
    }
    if len(operator_question) > 500 {
        raise ValueError("Operator questions are limited to 500 characters.");
    }
    snapshot: OpsSnapshot = get_snapshot();
    live_agent_enabled: bool = (os.getenv("SAFERELAY_LIVE_AGENT") or "").lower() == "true";
    has_provider: bool = live_agent_enabled and bool(
        os.getenv("OPENAI_API_KEY")
        or os.getenv("ANTHROPIC_API_KEY")
        or os.getenv("GOOGLE_API_KEY")
        or (os.getenv("BYLLM_DEFAULT_MODEL") or "").startswith("ollama/")
        or (os.getenv("BYLLM_DEFAULT_MODEL") or "").startswith("local:")
    );
    if has_provider {
        try {
            result: AgentBriefing = _agent_brief(_context_for(snapshot), operator_question);
            result.mode = "Jac byLLM";
            return result;
        } except Exception {
            return _fallback_briefing(snapshot, operator_question);
        }
    }
    return _fallback_briefing(snapshot, operator_question);
}

def:protect save_scenario_preset(name: str) -> DrillWorkspace {
    cleaned_name: str = name.strip();
    if not cleaned_name or len(cleaned_name) > 80 {
        raise ValueError("Preset name must be between 1 and 80 characters.");
    }
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    preset_number: int = len([root -->[?:ScenarioPreset]]) + 1;
    root ++> ScenarioPreset(
        preset_id=f"PRESET-{preset_number:04d}-{incident.seed}",
        name=cleaned_name,
        scenario=incident.scenario,
        seed=incident.seed,
        intensity=incident.intensity,
        device_density=incident.device_density,
        gateway_ratio=incident.gateway_ratio,
        infrastructure_damage=incident.infrastructure_damage,
        simulation_speed=incident.simulation_speed,
        sound_enabled=incident.sound_enabled,
        live_mode=incident.live_mode,
        created_at=f"T+{incident.tick:03d} / preset {preset_number}",
        assignment_data=_assignment_data(incident),
    );
    commit();
    return _workspace(incident);
}

def:protect delete_scenario_preset(preset_id: str) -> DrillWorkspace {
    preset: ScenarioPreset | None = _find_preset(_require_identifier(preset_id, "Preset ID"));
    if not preset { raise ValueError("Preset was not found."); }
    root del --> preset;
    del preset;
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def:protect apply_scenario_preset(preset_id: str) -> OpsSnapshot {
    preset: ScenarioPreset | None = _find_preset(_require_identifier(preset_id, "Preset ID"));
    if not preset { raise ValueError("Preset was not found."); }
    selected: ScenarioPreset = preset as ScenarioPreset;
    _clear_graph();
    incident: Incident = _seed_incident(
        selected.scenario,
        selected.seed,
        selected.intensity,
        selected.device_density,
        selected.gateway_ratio,
        selected.infrastructure_damage,
        selected.simulation_speed,
        False,
        selected.sound_enabled,
        selected.live_mode,
    );
    _apply_assignments(incident, selected.assignment_data);
    commit();
    return _snapshot(incident);
}

def:protect import_scenario_preset(payload_json: str) -> DrillWorkspace {
    if len(payload_json) > 20000 {
        raise ValueError("Preset JSON is too large.");
    }
    payload: dict[str, object] = {};
    try {
        payload = dict(json.loads(payload_json));
    } except Exception {
        raise ValueError("Preset JSON could not be parsed.");
    }
    options: dict[str, object] = dict(payload.get("generationOptions") or {});
    scenario: str = str(payload.get("scenario") or "").strip().lower();
    if scenario not in ["wildfire", "tornado", "hurricane", "earthquake"] {
        raise ValueError("Imported preset has an unsupported scenario.");
    }
    name: str = str(payload.get("name") or "Imported preset").strip()[:80];
    preset_number: int = len([root -->[?:ScenarioPreset]]) + 1;
    root ++> ScenarioPreset(
        preset_id=f"PRESET-{preset_number:04d}-{int(payload.get('seed') or 42)}",
        name=name or "Imported preset",
        scenario=scenario,
        seed=max(1, min(2147483646, int(payload.get("seed") or 42))),
        intensity=_clamp_percent(int(options.get("intensity") or 65)),
        device_density=_clamp_percent(int(options.get("deviceDensity") or 70)),
        gateway_ratio=_clamp_percent(int(options.get("gatewayRatio") or 30)),
        infrastructure_damage=_clamp_percent(int(options.get("infrastructureDamage") or 55)),
        simulation_speed=float(str(payload.get("simulationSpeed") or 1.0)),
        sound_enabled=bool(payload.get("soundEnabled", True)),
        live_mode=bool(payload.get("liveMode", False)),
        created_at=f"Imported / preset {preset_number}",
        assignment_data=json.dumps(payload.get("responderAssignments") or {}, sort_keys=True),
    );
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def:protect archive_scenario_run(name: str) -> DrillWorkspace {
    cleaned_name: str = name.strip();
    if not cleaned_name or len(cleaned_name) > 80 {
        raise ValueError("Run name must be between 1 and 80 characters.");
    }
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    metrics: ScenarioMetricsView = _scenario_metrics(incident);
    run_number: int = len([root -->[?:RunArchive]]) + 1;
    run: RunArchive = root ++> RunArchive(
        run_id=f"RUN-{run_number:04d}-{incident.seed}",
        name=cleaned_name,
        scenario=incident.scenario,
        seed=incident.seed,
        intensity=incident.intensity,
        device_density=incident.device_density,
        gateway_ratio=incident.gateway_ratio,
        infrastructure_damage=incident.infrastructure_damage,
        created_at=f"T+{incident.tick:03d} / run {run_number}",
        alert_count=metrics.alert_volume,
        device_count=incident.device_count,
        gateway_count=incident.gateway_count,
        delivery_rate=metrics.delivery_rate,
        average_hops=metrics.average_hops,
        assignment_coverage=metrics.assignment_coverage,
        unresolved_criticals=metrics.unresolved_criticals,
    );
    for alert in [incident ->:IncidentAlert:->[?:Alert]] { _archive_alert(run, alert); }
    for event in _current_timeline(incident) {
        archived_event: ArchivedEvent = ArchivedEvent(
            event_id=event.event_id,
            alert_id=event.alert_id,
            event_time=event.event_time,
            event_type=event.event_type,
            message=event.message,
            sequence=event.sequence,
        );
        run +>:RunEvent():+> archived_event;
    }
    commit();
    return _workspace(incident);
}

def:protect delete_scenario_run(run_id: str) -> DrillWorkspace {
    run: RunArchive | None = _find_run(_require_identifier(run_id, "Run ID"));
    if not run { raise ValueError("Run was not found."); }
    selected: RunArchive = run as RunArchive;
    for item in [selected ->:RunAlert:->[?:ArchivedAlert]] {
        selected del ->:RunAlert:-> item;
        del item;
    }
    for item in [selected ->:RunEvent:->[?:ArchivedEvent]] {
        selected del ->:RunEvent:-> item;
        del item;
    }
    for review in [root -->[?:DrillReview]] {
        if review.run_id == selected.run_id {
            root del --> review;
            del review;
        }
    }
    root del --> selected;
    del selected;
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def:protect compare_scenario_runs(run_a_id: str, run_b_id: str) -> RunComparisonView {
    run_a: RunArchive | None = _find_run(_require_identifier(run_a_id, "Run A"));
    run_b: RunArchive | None = _find_run(_require_identifier(run_b_id, "Run B"));
    if not run_a or not run_b { raise ValueError("Both archived runs are required."); }
    a: RunArchive = run_a as RunArchive;
    b: RunArchive = run_b as RunArchive;
    gateway_a: float = round((a.gateway_count / a.device_count) * 100, 1) if a.device_count else 0.0;
    gateway_b: float = round((b.gateway_count / b.device_count) * 100, 1) if b.device_count else 0.0;
    deltas: list[ComparisonDeltaView] = [
        ComparisonDeltaView(key="alertVolume", label="Alert volume", value_a=a.alert_count, value_b=b.alert_count, delta=b.alert_count - a.alert_count, higher_is_better=False),
        ComparisonDeltaView(key="deliveryRate", label="Delivery rate", value_a=a.delivery_rate, value_b=b.delivery_rate, delta=b.delivery_rate - a.delivery_rate, higher_is_better=True),
        ComparisonDeltaView(key="averageHops", label="Average hops", value_a=a.average_hops, value_b=b.average_hops, delta=round(b.average_hops - a.average_hops, 1), higher_is_better=False),
        ComparisonDeltaView(key="gatewayCoverageScore", label="Gateway coverage", value_a=gateway_a, value_b=gateway_b, delta=round(gateway_b - gateway_a, 1), higher_is_better=True),
        ComparisonDeltaView(key="assignedResponderCoverage", label="Responder coverage", value_a=a.assignment_coverage, value_b=b.assignment_coverage, delta=b.assignment_coverage - a.assignment_coverage, higher_is_better=True),
        ComparisonDeltaView(key="unresolvedCriticals", label="Unresolved criticals", value_a=a.unresolved_criticals, value_b=b.unresolved_criticals, delta=b.unresolved_criticals - a.unresolved_criticals, higher_is_better=False),
    ];
    return RunComparisonView(run_a=_run_view(a), run_b=_run_view(b), deltas=deltas);
}

def:protect get_run_replay(run_id: str, position: int) -> ReplaySnapshot {
    run: RunArchive | None = _find_run(_require_identifier(run_id, "Run ID"));
    if not run { raise ValueError("Run was not found."); }
    selected: RunArchive = run as RunArchive;
    normalized_position: int = min(100, max(0, position));
    all_events: list[ArchivedEvent] = sorted(
        [selected ->:RunEvent:->[?:ArchivedEvent]],
        key=lambda (item: ArchivedEvent) { item.sequence; },
    );
    visible_count: int = round(len(all_events) * (normalized_position / 100.0));
    visible_nodes: list[ArchivedEvent] = all_events[:visible_count];
    visible_events: list[TimelineEventView] = [
        TimelineEventView(
            event_id=item.event_id,
            alert_id=item.alert_id,
            event_time=item.event_time,
            event_type=item.event_type,
            message=item.message,
            sequence=item.sequence,
        )
        for item in visible_nodes
    ];
    visible_alerts: list[AlertView] = [];
    archived_alerts: list[ArchivedAlert] = [selected ->:RunAlert:->[?:ArchivedAlert]];
    for idx in range(len(archived_alerts)) {
        item: ArchivedAlert = archived_alerts[idx];
        alert_events: list[ArchivedEvent] = [event for event in visible_nodes if event.alert_id == item.alert_id];
        if not alert_events { continue; }
        event_types: list[str] = [event.event_type for event in alert_events];
        replay_status: str = "active";
        if "resolved" in event_types { replay_status = "resolved"; }
        elif "assigned" in event_types { replay_status = "responding"; }
        elif "acknowledged" in event_types { replay_status = "acknowledged"; }
        visible_alerts.append(AlertView(
            alert_id=item.alert_id,
            caller="Archived origin",
            emergency_type=item.emergency_type,
            priority=item.priority,
            status=replay_status,
            message=item.message,
            zone=item.zone,
            map_x=10 + ((idx * 17) % 80),
            map_y=12 + ((idx * 23) % 76),
            battery=0,
            hop_count=len([event for event in alert_events if event.event_type in ["relay_hop", "gateway"]]),
            originator="Archived device",
            received_at=item.received_at,
            assigned_to=item.assigned_to if "assigned" in event_types else "",
            originated_at=item.originated_at,
            acknowledged_at=item.acknowledged_at if replay_status in ["acknowledged", "responding", "resolved"] else "",
            resolved_at=item.resolved_at if replay_status == "resolved" else "",
            resolution_notes="",
            delivered_via="mesh_relay" if item.hop_count else "direct",
            delivered_by="Archived gateway" if item.hop_count else "",
        ));
    }
    return ReplaySnapshot(
        run_id=selected.run_id,
        position=normalized_position,
        visible_alerts=visible_alerts,
        visible_events=visible_events,
        current_time=visible_events[-1].event_time if visible_events else "Before first event",
    );
}

def:protect sign_drill_review(
    run_id: str,
    reviewer: str,
    notes: str,
) -> DrillWorkspace {
    run: RunArchive | None = _find_run(_require_identifier(run_id, "Run ID"));
    if not run { raise ValueError("Run was not found."); }
    reviewer_name: str = reviewer.strip();
    if not reviewer_name or len(reviewer_name) > 80 {
        raise ValueError("Reviewer must be between 1 and 80 characters.");
    }
    if len(notes) > 2000 { raise ValueError("Review notes are limited to 2000 characters."); }
    selected: RunArchive = run as RunArchive;
    gateway_score: int = round((selected.gateway_count / selected.device_count) * 100) if selected.device_count else 0;
    score: int = max(0, min(
        100,
        round(
            selected.delivery_rate * 0.35
            + selected.assignment_coverage * 0.35
            + gateway_score * 0.3
            - selected.unresolved_criticals * 3
        ),
    ));
    status: str = "pass" if score >= 80 else ("watch" if score >= 60 else "fail");
    review_number: int = len([root -->[?:DrillReview]]) + 1;
    root ++> DrillReview(
        review_id=f"REVIEW-{review_number:04d}-{selected.seed}",
        run_id=selected.run_id,
        reviewer=reviewer_name,
        notes=notes.strip(),
        score=score,
        status=status,
        signed_at=f"{selected.created_at} / review {review_number}",
    );
    selected.review_score = score;
    selected.review_status = status;
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def:protect create_drill_handoff(
    review_id: str,
    receiving_operator: str,
    notes: str,
    follow_up_date: str = "",
) -> DrillWorkspace {
    review: DrillReview | None = _find_review(_require_identifier(review_id, "Review ID"));
    if not review { raise ValueError("Review was not found."); }
    receiver: str = receiving_operator.strip();
    if not receiver or len(receiver) > 80 {
        raise ValueError("Receiving operator must be between 1 and 80 characters.");
    }
    handoff_number: int = len([root -->[?:DrillHandoff]]) + 1;
    root ++> DrillHandoff(
        handoff_id=f"HANDOFF-{handoff_number:04d}",
        review_id=review.review_id,
        run_id=review.run_id,
        receiving_operator=receiver,
        operator_notes=notes.strip()[:2000],
        lifecycle_state="draft",
        disposition="active",
        resolution="unresolved",
        follow_up_date=follow_up_date.strip()[:32],
        updated_at=f"{review.signed_at} / handoff {handoff_number}",
    );
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def:protect update_drill_handoff(
    handoff_id: str,
    lifecycle_state: str,
    disposition: str,
    resolution: str,
    receiving_operator: str,
    notes: str,
    follow_up_date: str,
) -> DrillWorkspace {
    handoff: DrillHandoff | None = _find_handoff(_require_identifier(handoff_id, "Handoff ID"));
    if not handoff { raise ValueError("Handoff was not found."); }
    if lifecycle_state not in ["draft", "sent", "acknowledged", "superseded"] {
        raise ValueError("Unsupported handoff lifecycle state.");
    }
    if disposition not in ["active", "archived", "deleted"] {
        raise ValueError("Unsupported handoff disposition.");
    }
    if resolution not in ["unresolved", "accepted", "needs_follow_up", "rejected"] {
        raise ValueError("Unsupported handoff resolution.");
    }
    selected: DrillHandoff = handoff as DrillHandoff;
    selected.lifecycle_state = "acknowledged" if resolution == "accepted" else lifecycle_state;
    selected.disposition = disposition;
    selected.resolution = resolution;
    selected.receiving_operator = receiving_operator.strip()[:80] or selected.receiving_operator;
    selected.operator_notes = notes.strip()[:2000];
    selected.follow_up_date = follow_up_date.strip()[:32];
    selected.updated_at = f"{selected.updated_at} / updated";
    incident: Incident | None = _current_incident();
    if not incident { incident = _seed_incident("wildfire"); }
    commit();
    return _workspace(incident);
}

def _seed_disaster_cache -> DisasterCache {
    cache: DisasterCache = root ++> DisasterCache(
        refreshed_at="Built-in continuity snapshot",
        source_status="fallback",
    );
    fallback_events: list[dict] = [
        {
            "id": "USGS-DEMO-1",
            "source": "USGS",
            "type": "earthquake",
            "severity": "moderate",
            "title": "M 4.2 earthquake monitoring example",
            "area": "United States",
            "occurred": "Continuity snapshot",
            "url": "https://earthquake.usgs.gov/",
        },
        {
            "id": "NWS-DEMO-1",
            "source": "NWS",
            "type": "weather",
            "severity": "severe",
            "title": "Severe weather monitoring example",
            "area": "United States",
            "occurred": "Continuity snapshot",
            "url": "https://www.weather.gov/alerts",
        },
    ];
    for item in fallback_events {
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
    return cache;
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

def:protect get_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root -->[?:DisasterCache]];
    cache: DisasterCache;
    if not caches {
        cache = _seed_disaster_cache();
        commit();
    } else {
        cache = caches[0];
    }
    return _disaster_feed(cache);
}

def:protect refresh_disaster_feed -> DisasterFeedView {
    caches: list[DisasterCache] = [root -->[?:DisasterCache]];
    cache: DisasterCache = caches[0] if caches else _seed_disaster_cache();
    for event in [cache ->:DisasterCacheEvent:->[?:DisasterEvent]] {
        cache del ->:DisasterCacheEvent:-> event;
        del event;
    }
    loaded: int = 0;
    try {
        earthquake_response = requests.get(
            "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson",
            timeout=6,
            headers={"User-Agent": "SafeRelay/1.0"},
        );
        earthquake_response.raise_for_status();
        for raw_feature in (earthquake_response.json().get("features") or [])[:20] {
            feature: dict[str, object] = dict(raw_feature);
            properties: dict[str, object] = dict(feature.get("properties") or {});
            magnitude: float = float(str(properties.get("mag") or 0));
            severity: str = "major" if magnitude >= 6 else ("severe" if magnitude >= 5 else "moderate");
            event: DisasterEvent = DisasterEvent(
                disaster_id=str(feature.get("id") or f"USGS-{loaded}"),
                source="USGS",
                event_type="earthquake",
                severity=severity,
                title=str(properties.get("title") or "USGS earthquake"),
                area=str(properties.get("place") or "Location pending"),
                occurred_at=str(properties.get("time") or ""),
                detail_url=str(properties.get("url") or "https://earthquake.usgs.gov/"),
            );
            cache +>:DisasterCacheEvent():+> event;
            loaded += 1;
        }
    } except Exception {
        cache.source_status = "partial";
    }
    try {
        weather_response = requests.get(
            "https://api.weather.gov/alerts/active?severity=Severe,Extreme",
            timeout=6,
            headers={"User-Agent": "SafeRelay/1.0 operations@saferelay.local"},
        );
        weather_response.raise_for_status();
        for raw_feature in (weather_response.json().get("features") or [])[:20] {
            feature: dict[str, object] = dict(raw_feature);
            properties: dict[str, object] = dict(feature.get("properties") or {});
            event: DisasterEvent = DisasterEvent(
                disaster_id=str(feature.get("id") or f"NWS-{loaded}"),
                source="NWS",
                event_type="weather",
                severity=str(properties.get("severity") or "unknown").lower(),
                title=str(properties.get("headline") or properties.get("event") or "NWS alert"),
                area=str(properties.get("areaDesc") or "Area pending"),
                occurred_at=str(properties.get("effective") or ""),
                detail_url=str(properties.get("@id") or "https://www.weather.gov/alerts"),
            );
            cache +>:DisasterCacheEvent():+> event;
            loaded += 1;
        }
    } except Exception {
        cache.source_status = "partial";
    }
    if loaded == 0 {
        root del --> cache;
        del cache;
        cache = _seed_disaster_cache();
    } else {
        cache.refreshed_at = "Latest USGS/NWS server refresh";
        cache.source_status = "live";
    }
    commit();
    return _disaster_feed(cache);
}


walker:protect TraceRelay {
    has alert_id: str,
        reports: list[RelayHopView] = [];

    can locate with Root entry {
        for incident in [here -->[?:Incident]] {
            for alert in [incident ->:IncidentAlert:->[?:Alert]] {
                if alert.alert_id == self.alert_id { visit alert; }
            }
        }
    }

    can traverse with Alert entry {
        visit [here ->:RelayedThrough:->[?:RelayHop]];
    }

    can collect with RelayHop entry {
        report RelayHopView(
            hop_order=here.hop_order,
            device_id=here.device_id,
            label=here.label,
            rssi=here.rssi,
            battery=here.battery,
            had_internet=here.had_internet,
        );
    }
}
