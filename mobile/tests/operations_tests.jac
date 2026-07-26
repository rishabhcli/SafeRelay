"""Parity tests for the original operational domain behavior."""

import from domain.protocol { SosPacket }
import from domain.operations {
    adjudication_item,
    assess_cloud_queue,
    decode_shelter_target,
    deterministic_drill,
    evidence_board,
    field_brief,
    handoff_export,
    incident_report,
    reconcile_cloud,
    replay_decision,
    responder_needs,
    shelter_target,
    survival_chat_records,
    trust_score
}


def packet(
    user_id: int,
    sequence: int,
    status: int,
    timestamp: int,
    synced: bool = False
) -> SosPacket {
    return SosPacket(
        user_id=user_id,
        sequence=sequence,
        latitude_e7=377749000,
        longitude_e7=-1224194000,
        status_code=status,
        timestamp=timestamp,
        is_synced=synced
    );
}


test "replay window rejects duplicates stale sequence and invalid time" {
    now = 1778906400;
    current = packet(1, 4, 1, now - 10);
    assert replay_decision(current, None, now) == "accept";
    assert replay_decision(current, 4, now) == "duplicate";
    assert replay_decision(current, 5, now) == "stale_sequence";
    assert replay_decision(packet(1, 6, 1, now - 90000), 5, now) == "expired";
    assert replay_decision(packet(1, 6, 1, now + 600), 5, now) == "future";
}


test "shelter status packs capacity spaces and amenities" {
    encoded = shelter_target(2, 145, 37);
    decoded = decode_shelter_target(encoded);
    assert decoded["version"] == 1;
    assert decoded["capacity"] == 2;
    assert decoded["spaces"] == 145;
    assert decoded["amenities"] == 37;
}


test "incident report separates active safe stale conflict and duplicate evidence" {
    now = 1778906400;
    packets = [
        packet(1, 1, 1, now - 20),
        packet(1, 2, 0, now - 10),
        packet(2, 1, 2, now - 30),
        packet(3, 1, 4, now - 5000),
        packet(2, 1, 2, now - 30)
    ];
    summary = incident_report(packets, now);
    assert summary["active"] == 3;
    assert summary["safe"] == 1;
    assert summary["stale"] == 1;
    assert summary["conflicts"] == 1;
    assert summary["duplicates"] == 1;
    board = evidence_board(packets, now);
    assert len(board.warnings) == 3;
    assert "responder receipt" in board.unknowns[1];
}


test "responder board summarizes needs without inventing outcomes" {
    now = 1778906400;
    needs = responder_needs([
        packet(1, 1, 1, now),
        packet(2, 1, 3, now),
        packet(3, 1, 2, now),
        packet(4, 1, 4, now)
    ], now);
    assert needs["needs"][0]["count"] == 2;
    assert needs["needs"][1]["count"] == 1;
    assert needs["needs"][2]["count"] == 1;
    assert needs["proof"] == "Local packet evidence only";
}


test "field brief labels drills and preserves unknowns" {
    now = 1778906400;
    brief = field_brief([packet(1, 1, 1, now)], now, False, True);
    assert brief.title == "DRILL: Field brief";
    assert "DRILL:" in brief.facts[0];
    assert len(brief.unknowns) == 2;
}


test "cloud queue respects privacy connectivity initialization and sync state" {
    packets = [
        packet(1, 1, 1, 1),
        packet(2, 1, 2, 1, True)
    ];
    blocked = assess_cloud_queue(packets, False, "Relay Only", False);
    assert blocked.queued == 1;
    assert blocked.eligible == 0;
    assert len(blocked.blockers) == 3;
    ready = assess_cloud_queue(packets, True, "Cloud Bridge", True);
    assert ready.state == "ready";
    assert ready.eligible == 1;
}


test "trust assessment never conflates confidence with physical proof" {
    trust = trust_score(True, True, True, True, False);
    assert trust["score"] == 90;
    assert trust["level"] == "high";
    assert not trust["physicalProof"];
    assert "not proof" in trust["unknown"];
}


test "local only handoff redacts packet identity and coordinates" {
    export = handoff_export([packet(99, 7, 2, 100)], 120, "Local Only");
    row = export["reports"][0];
    assert "packetId" not in row;
    assert "latitude" not in row;
    assert export["privacyMode"] == "Local Only";
}


test "adjudication validates decisions and remains local evidence" {
    item = adjudication_item("conflict-1", "merge", "operator", "same event", 42);
    assert item["decision"] == "merge";
    assert item["localOnly"];
    try {
        adjudication_item("x", "resolved", "operator", "", 42);
        assert False;
    } except ValueError {
        assert True;
    }
}


test "drill simulation models congestion and battery constraints explicitly" {
    drill = deterministic_drill(12, True, True);
    assert drill.delivered + drill.deferred + drill.dropped == 12;
    assert drill.deferred > 0;
    assert drill.dropped > 0;
    assert "Simulation only" in drill.proof_boundary;
}


test "shelter target rejects values outside its wire allocation" {
    invalid = [
        [-1, 0, 0, 1],
        [16, 0, 0, 1],
        [0, -1, 0, 1],
        [0, 65536, 0, 1],
        [0, 0, 256, 1],
        [0, 0, 0, 16]
    ];
    for values in invalid {
        try {
            shelter_target(values[0], values[1], values[2], values[3]);
            assert False;
        } except ValueError {
            assert True;
        }
    }
}


test "incident report counts unique senders and excludes stale needs" {
    now = 1778906400;
    summary = incident_report([
        packet(7, 1, 1, now - 4000),
        packet(7, 2, 2, now - 20),
        packet(8, 1, 4, now - 10)
    ], now);
    assert summary["senderCount"] == 2;
    assert summary["packetCount"] == 3;
    assert summary["stale"] == 1;
    assert summary["active"] == 2;
    assert summary["conflicts"] == 1;
}


test "empty evidence reports absence as unknown not safety" {
    board = evidence_board([], 100);
    assert board.is_clear();
    assert len(board.unknowns) == 3;
    assert "No local packets" in board.unknowns[2];
}


test "field brief surfaces critical and stale review work" {
    now = 1778906400;
    brief = field_brief([
        packet(1, 1, 3, now),
        packet(2, 1, 2, now - 4000)
    ], now, True);
    assert len(brief.warnings) == 2;
    assert "Prioritize" in brief.warnings[1];
    assert brief.facts[2] == "Internet link is available";
}


test "empty cloud queue remains empty even when policy is blocked" {
    queue = assess_cloud_queue([], False, "Local Only", False);
    assert queue.state == "empty";
    assert queue.queued == 0;
    assert queue.eligible == 0;
    assert len(queue.blockers) == 3;
}


test "cloud reconciliation distinguishes receipts from acknowledgements" {
    packets = [
        packet(1, 1, 1, 100),
        packet(2, 1, 2, 100, True),
        packet(3, 1, 4, 100)
    ];
    reconciliation = reconcile_cloud(packets, [packets[0].unique_id()]);
    assert reconciliation.facts[0] == "2 packets have receipt evidence";
    assert reconciliation.facts[1] == "1 packets remain pending";
    assert len(reconciliation.warnings) == 1;
    assert "not responder acknowledgement" in reconciliation.unknowns[0];
}


test "relay handoff preserves coordinates outside local only mode" {
    export = handoff_export([packet(99, 7, 2, 100)], 120, "Relay Only");
    row = export["reports"][0];
    assert row["packetId"] == "99_7";
    assert row["latitude"] == 37.7749;
    assert row["longitude"] == -122.4194;
}


test "trust levels cover low medium and high without outcome claims" {
    low = trust_score(False, False, False, False, False);
    medium = trust_score(True, True, False, False, False);
    high = trust_score(True, True, True, True, False);
    assert low["level"] == "low";
    assert medium["level"] == "medium";
    assert high["level"] == "high";
    assert low["unknown"] == high["unknown"];
}


test "baseline drill delivers every packet and stays deterministic" {
    first = deterministic_drill(12);
    second = deterministic_drill(12);
    assert first.delivered == 12;
    assert first.deferred == 0;
    assert first.dropped == 0;
    assert first.relayed == second.relayed;
    assert first.events == second.events;
}


test "survival chat records discard malformed entries and bound retained history" {
    records: list[dict[str, object]] = [
        {"role": "system", "content": "ignore", "timestamp": 1},
        {"role": "user", "content": "   ", "timestamp": 2},
        {"role": "assistant", "content": "packed", "timestamp": "3"}
    ];
    for index in range(30) {
        records.append({
            "role": "user" if index % 2 == 0 else "assistant",
            "content": "message " + str(index),
            "timestamp": index + 10
        });
    }
    messages = survival_chat_records(records);
    assert len(messages) == 24;
    assert messages[0].content == "message 6";
    assert messages[-1].role == "assistant";
}


test "survival chat content is excluded from handoff exports" {
    messages = survival_chat_records([
        {"role": "user", "content": "secret survival note", "timestamp": 1}
    ]);
    export = handoff_export([packet(99, 7, 2, 100)], 120, "Relay Only");
    assert len(messages) == 1;
    assert "secret survival note" not in str(export);
}
