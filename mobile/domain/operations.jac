"""Operational intelligence preserved from the original SafeRelay product."""

import from math { atan2, cos, degrees, radians, sin, sqrt }
glob STALE_SECONDS: int = 3600;
glob REPLAY_WINDOW_SECONDS: int = 86400;


def _status_label(code: int) -> str {
    if code == 0 { return "SAFE"; }
    if code == 1 { return "EMERGENCY"; }
    if code == 2 { return "MEDICAL"; }
    if code == 3 { return "TRAPPED"; }
    if code == 4 { return "SUPPLIES"; }
    if code == 5 { return "SHELTER"; }
    return "UNKNOWN";
}


obj:pub OperationalReport {
    has title: str,
        facts: list[str],
        unknowns: list[str];
    has warnings: list[str] = [];

    def is_clear -> bool {
        return len(self.warnings) == 0;
    }
}


obj:pub NavigationVector {
    has distance_meters: float,
        bearing_degrees: float,
        relative_degrees: float,
        source: str;
}


obj:pub CloudQueueReport {
    has state: str,
        queued: int,
        eligible: int,
        blockers: list[str],
        facts: list[str];
}


obj:pub DrillReport {
    has scenario: str,
        delivered: int,
        relayed: int,
        deferred: int,
        dropped: int,
        events: list[str],
        proof_boundary: str;
}


def:pub replay_decision(
    packet: any,  # jac:ignore[W1037]
    highest_sequence: int | None,
    now_seconds: int
) -> str {
    age = now_seconds - packet.timestamp;
    if packet.timestamp > now_seconds + 300 { return "future"; }
    if age > REPLAY_WINDOW_SECONDS { return "expired"; }
    if highest_sequence is None { return "accept"; }
    if packet.sequence == highest_sequence { return "duplicate"; }
    if packet.sequence < highest_sequence { return "stale_sequence"; }
    return "accept";
}


def:pub shelter_target(
    capacity_code: int,
    spaces: int,
    amenities_mask: int,
    version: int = 1
) -> int {
    if version < 0 or version > 15 { raise ValueError("Invalid shelter version"); }
    if capacity_code < 0 or capacity_code > 15 {
        raise ValueError("Invalid shelter capacity");
    }
    if spaces < 0 or spaces > 65535 { raise ValueError("Invalid shelter spaces"); }
    if amenities_mask < 0 or amenities_mask > 255 {
        raise ValueError("Invalid shelter amenities");
    }
    return (
        ((version & 15) << 28)
        | ((capacity_code & 15) << 24)
        | ((amenities_mask & 255) << 16)
        | (spaces & 65535)
    );
}


def:pub decode_shelter_target(value: int) -> dict[str, int] {
    return {
        "version": (value >> 28) & 15,
        "capacity": (value >> 24) & 15,
        "amenities": (value >> 16) & 255,
        "spaces": value & 65535
    };
}


def:pub incident_report(
    packets: list[any],  # jac:ignore[W1037]
    now_seconds: int
) -> dict[str, object] {
    active = 0;
    safe = 0;
    stale = 0;
    critical = 0;
    medical = 0;
    supplies = 0;
    shelters = 0;
    senders: dict[str, int] = {};
    sender_count = 0;
    conflicts = 0;
    duplicates = 0;
    ids: dict[str, int] = {};

    for packet in packets {
        packet_id = packet.unique_id();
        ids[packet_id] = ids.get(packet_id, 0) + 1;
        if ids[packet_id] > 1 { duplicates += 1; }
        sender = str(packet.user_id);
        if sender not in senders { sender_count += 1; }
        if sender in senders and senders[sender] != packet.status_code {
            conflicts += 1;
        }
        senders[sender] = packet.status_code;
        if now_seconds - packet.timestamp > STALE_SECONDS {
            stale += 1;
            continue;
        }
        if packet.status_code == 0 {
            safe += 1;
        } else {
            active += 1;
        }
        if packet.status_code == 1 or packet.status_code == 3 { critical += 1; }
        if packet.status_code == 2 { medical += 1; }
        if packet.status_code == 4 { supplies += 1; }
        if packet.status_code == 5 { shelters += 1; }
    }
    return {
        "packetCount": len(packets),
        "senderCount": sender_count,
        "active": active,
        "safe": safe,
        "stale": stale,
        "critical": critical,
        "medical": medical,
        "supplies": supplies,
        "shelters": shelters,
        "conflicts": conflicts,
        "duplicates": duplicates
    };
}


def:pub evidence_board(
    packets: list[any],  # jac:ignore[W1037]
    now_seconds: int
) -> OperationalReport {
    summary = incident_report(packets, now_seconds);
    facts = [
        str(summary["packetCount"]) + " stored packet observations",
        str(summary["senderCount"]) + " distinct sender identifiers",
        str(summary["active"]) + " current help reports",
        str(summary["safe"]) + " current safe reports"
    ];
    warnings: list[str] = [];
    unknowns = [
        "Packet absence does not prove rescue or safety.",
        "A local receipt does not prove responder receipt."
    ];
    if int(summary["stale"]) > 0 {
        warnings.append(str(summary["stale"]) + " reports are stale");
    }
    if int(summary["conflicts"]) > 0 {
        warnings.append(str(summary["conflicts"]) + " sender histories conflict");
    }
    if int(summary["duplicates"]) > 0 {
        warnings.append(str(summary["duplicates"]) + " repeated packet copies");
    }
    if len(packets) == 0 {
        unknowns.append("No local packets are available for incident assessment.");
    }
    return OperationalReport(
        title="Incident evidence",
        facts=facts,
        warnings=warnings,
        unknowns=unknowns
    );
}


def:pub responder_needs(
    packets: list[any],  # jac:ignore[W1037]
    now_seconds: int
) -> dict[str, object] {
    summary = incident_report(packets, now_seconds);
    needs: list[dict[str, object]] = [];
    needs.append({
        "category": "Immediate rescue",
        "count": summary["critical"],
        "priority": 3
    });
    needs.append({
        "category": "Medical",
        "count": summary["medical"],
        "priority": 2
    });
    needs.append({
        "category": "Supplies",
        "count": summary["supplies"],
        "priority": 1
    });
    needs.append({
        "category": "Shelter reports",
        "count": summary["shelters"],
        "priority": 1
    });
    return {
        "needs": needs,
        "unknownCount": int(summary["stale"]) + int(summary["conflicts"]),
        "proof": "Local packet evidence only"
    };
}


def:pub field_brief(
    packets: list[any],  # jac:ignore[W1037]
    now_seconds: int,
    is_online: bool,
    is_drill: bool = False
) -> OperationalReport {
    summary = incident_report(packets, now_seconds);
    prefix = "DRILL: " if is_drill else "";
    facts = [
        prefix + str(summary["active"]) + " active help reports",
        str(summary["critical"]) + " critical or trapped reports",
        "Internet link is " + ("available" if is_online else "unavailable")
    ];
    warnings: list[str] = [];
    if int(summary["stale"]) > 0 {
        warnings.append("Confirm " + str(summary["stale"]) + " stale reports");
    }
    if int(summary["conflicts"]) > 0 {
        warnings.append("Human review required for conflicting sender evidence");
    }
    if int(summary["critical"]) > 0 {
        warnings.append("Prioritize current critical and trapped reports");
    }
    return OperationalReport(
        title=prefix + "Field brief",
        facts=facts,
        warnings=warnings,
        unknowns=[
            "Responder assignment is unknown.",
            "Rescue outcome is unknown."
        ]
    );
}


def:pub assess_cloud_queue(
    packets: list[any],  # jac:ignore[W1037]
    online: bool,
    privacy_mode: str,
    initialized: bool
) -> CloudQueueReport {
    queued = 0;
    for packet in packets {
        if not packet.is_synced { queued += 1; }
    }
    blockers: list[str] = [];
    if privacy_mode != "Cloud Bridge" {
        blockers.append("Privacy mode blocks cloud upload");
    }
    if not online { blockers.append("Internet is offline"); }
    if not initialized { blockers.append("Cloud client is not initialized"); }
    eligible = queued if len(blockers) == 0 else 0;
    state = "ready" if eligible > 0 else ("empty" if queued == 0 else "blocked");
    return CloudQueueReport(
        state=state,
        queued=queued,
        eligible=eligible,
        blockers=blockers,
        facts=[
            str(queued) + " unsynced local packets",
            "Upload requires Cloud Bridge privacy mode"
        ]
    );
}


def:pub reconcile_cloud(
    packets: list[any],  # jac:ignore[W1037]
    receipt_ids: list[str]
) -> OperationalReport {
    synced = 0;
    pending = 0;
    for packet in packets {
        if packet.unique_id() in receipt_ids or packet.is_synced {
            synced += 1;
        } else {
            pending += 1;
        }
    }
    warnings: list[str] = [];
    if pending > 0 { warnings.append(str(pending) + " packets lack durable receipts"); }
    return OperationalReport(
        title="Cloud reconciliation",
        facts=[
            str(synced) + " packets have receipt evidence",
            str(pending) + " packets remain pending"
        ],
        warnings=warnings,
        unknowns=[
            "Cloud durability is not responder acknowledgement.",
            "Receipt absence does not imply packet loss."
        ]
    );
}


def:pub navigation_vector(
    from_lat: float,
    from_lon: float,
    to_lat: float,
    to_lon: float,
    heading: float = 0.0,
    source: str = "live"
) -> NavigationVector {
    lat1 = radians(from_lat);
    lat2 = radians(to_lat);
    dlat = radians(to_lat - from_lat);
    dlon = radians(to_lon - from_lon);
    a = (
        sin(dlat / 2.0) * sin(dlat / 2.0)
        + cos(lat1) * cos(lat2)
        * sin(dlon / 2.0) * sin(dlon / 2.0)
    );
    distance = 6371000.0 * 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    y = sin(dlon) * cos(lat2);
    x = (
        cos(lat1) * sin(lat2)
        - sin(lat1) * cos(lat2) * cos(dlon)
    );
    bearing = (degrees(atan2(y, x)) + 360.0) % 360.0;
    return NavigationVector(
        distance_meters=distance,
        bearing_degrees=bearing,
        relative_degrees=(bearing - heading + 360.0) % 360.0,
        source=source
    );
}


def:pub trust_score(
    signature_valid: bool,
    fresh: bool,
    replay_clear: bool,
    known_peer: bool,
    physical_proof: bool
) -> dict[str, object] {
    score = 0;
    if signature_valid { score += 30; }
    if fresh { score += 25; }
    if replay_clear { score += 20; }
    if known_peer { score += 15; }
    if physical_proof { score += 10; }
    level = "high" if score >= 80 else ("medium" if score >= 50 else "low");
    return {
        "score": score,
        "level": level,
        "physicalProof": physical_proof,
        "unknown": "Identity confidence is not proof of rescue outcome."
    };
}


def:pub handoff_export(
    packets: list[any],  # jac:ignore[W1037]
    now_seconds: int,
    privacy_mode: str
) -> dict[str, object] {
    summary = incident_report(packets, now_seconds);
    rows: list[dict[str, object]] = [];
    for packet in packets {
        row: dict[str, object] = {
            "status": _status_label(packet.status_code),
            "ageSeconds": packet.age_seconds(now_seconds)
        };
        if privacy_mode != "Local Only" {
            row["packetId"] = packet.unique_id();
            row["latitude"] = packet.latitude();
            row["longitude"] = packet.longitude();
        }
        rows.append(row);
    }
    return {
        "generatedAt": now_seconds,
        "privacyMode": privacy_mode,
        "summary": summary,
        "reports": rows,
        "boundary": "Local evidence export; responder receipt and outcome unknown."
    };
}


def:pub adjudication_item(
    issue_id: str,
    decision: str,
    reviewer: str,
    note: str,
    timestamp: int
) -> dict[str, object] {
    valid = ["keep", "merge", "dismiss", "escalate"];
    if decision not in valid { raise ValueError("Invalid adjudication decision"); }
    return {
        "issueId": issue_id,
        "decision": decision,
        "reviewer": reviewer,
        "note": note,
        "timestamp": timestamp,
        "localOnly": True
    };
}


def:pub deterministic_drill(
    packet_count: int = 12,
    low_battery: bool = False,
    congestion: bool = False
) -> DrillReport {
    delivered = 0;
    relayed = 0;
    deferred = 0;
    dropped = 0;
    events: list[str] = [];
    for index in range(packet_count) {
        if congestion and index % 5 == 4 {
            dropped += 1;
            events.append("Packet " + str(index + 1) + " dropped by congestion");
        } elif low_battery and index % 3 == 2 {
            deferred += 1;
            events.append("Packet " + str(index + 1) + " deferred for battery");
        } else {
            delivered += 1;
            if index % 2 == 1 { relayed += 1; }
        }
    }
    return DrillReport(
        scenario="City outage",
        delivered=delivered,
        relayed=relayed,
        deferred=deferred,
        dropped=dropped,
        events=events,
        proof_boundary="Simulation only; no physical radio or cloud receipt proof."
    );
}


# Jac's server linker traces concrete references when this module is loaded by a
# test worker. Keep the public operational contract rooted as a single value so
# every exported callable and report type remains importable.
glob OPERATIONAL_API: tuple = (
    OperationalReport,
    NavigationVector,
    CloudQueueReport,
    DrillReport,
    replay_decision,
    shelter_target,
    decode_shelter_target,
    incident_report,
    evidence_board,
    responder_needs,
    field_brief,
    assess_cloud_queue,
    reconcile_cloud,
    navigation_vector,
    trust_score,
    handoff_export,
    adjudication_item,
    deterministic_drill
);
