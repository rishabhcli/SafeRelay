"""SafeRelay mobile operator shell."""

import from "react" { useEffect }
import from "qrcode.react" { QRCodeSVG }
import from "lucide-react" {
    Activity,
    BatteryMedium,
    Bell,
    Bluetooth,
    Check,
    ChevronRight,
    CircleCheck,
    Cloud,
    CloudOff,
    Compass,
    Copy,
    Database,
    Download,
    Flashlight,
    Gauge,
    HeartPulse,
    Headphones,
    MessageCircle,
    Send,
    Sparkles,
    ListChecks,
    LocateFixed,
    LockKeyhole,
    Map as MapIcon,
    MapPin,
    PackageOpen,
    Play,
    Printer,
    QrCode,
    Radio,
    RefreshCw,
    ShieldCheck,
    Share2,
    Siren,
    SlidersHorizontal,
    Smartphone,
    Square,
    UploadCloud,
    Trash2,
    TriangleAlert,
    UserRound,
    Volume2,
    WifiOff,
    Wrench
}
import from ..domain.protocol {
    ClientSosPacket as SosPacket,
    client_contains_packet as contains_packet,
    client_create_packet as create_packet,
    client_evaluate_relay as evaluate_relay,
    client_packet_from_bytes as packet_from_bytes,
    client_packet_to_bytes as packet_to_bytes,
    client_readiness_score as readiness_score,
    client_replace_packet as replace_packet,
    client_status_color as status_color,
    client_status_description as status_description,
    client_status_label as status_label
}
import from ..domain.operations {
    ClientDrillReport,
    ClientOperationalReport,
    client_assess_cloud_queue as assess_cloud_queue,
    client_deterministic_drill as deterministic_drill,
    client_evidence_board as evidence_board,
    client_field_brief as field_brief,
    client_handoff_export as handoff_export,
    client_incident_report as incident_report,
    client_reconcile_cloud as reconcile_cloud,
    client_responder_needs as responder_needs,
    client_trust_score as trust_score
}
import from ..services.field {
    cache_map_region,
    fetch_disaster_events,
    start_ultrasonic_listener,
    stop_ultrasonic_listener,
    sync_relayed_packets,
    transmit_ultrasonic,
    verify_internet
}
import from ..services.foundation_models {
    FoundationModelChatResponse,
    FoundationModelStatus,
    chat_with_survival_guide,
    foundation_model_status,
}
import from ..services.handoff {
    copy_handoff,
    prepare_handoff,
    print_handoff,
    save_handoff,
    share_handoff
}
import from ..services.mesh {
    NativeReadiness,
    clear_mesh_event_sink,
    current_location,
    emergency_haptic,
    inspect_native_readiness,
    mesh_is_running,
    native_platform,
    notify_incoming,
    publish_packet,
    register_app_state_observer,
    resume_saved_mesh,
    set_mesh_event_sink,
    set_torch,
    start_mesh,
    stop_mesh,
    unix_seconds
}
import from ..services.storage {
    ADJUDICATIONS_KEY,
    BATTERY_KEY,
    PRIVACY_KEY,
    SYNC_ATTEMPTS_KEY,
    SYNC_RECEIPTS_KEY,
    append_record,
    clear_packets,
    clear_operational_history,
    clear_survival_chat_history,
    complete_onboarding,
    get_or_create_user_id,
    load_records,
    load_survival_chat_history,
    load_onboarding_complete,
    load_packets,
    load_setting,
    next_sequence,
    save_packets,
    save_survival_chat_history,
    save_setting
}
import from ..domain.operations {
    ClientSurvivalChatMessage
}
import from .IncidentMap { IncidentMap }

glob _window: any = window;  # jac:ignore[W1037, W2001]


def:pub Metric(label: str, value: str, detail: str) -> JsxElement {
    return <div className="metric">
        <span>{label}</span>
        <strong>{value}</strong>
        <small>{detail}</small>
    </div>;
}


def:pub FactRow(
    icon: any,  # jac:ignore[W1037]
    label: str,
    value: str,
    tone: str = "neutral"
) -> JsxElement {
    return <div className="fact-row">
        <span className={"fact-icon " + tone}>{icon}</span>
        <span>{label}</span>
        <strong>{value}</strong>
    </div>;
}


def:pub PacketRow(packet: SosPacket, now: int) -> JsxElement {
    age = max(0, packet.age_seconds(now));
    age_label = str(age) + "s ago" if age < 60 else str(age // 60) + "m ago";
    return <article className="packet-row">
        <span
            className="packet-severity"
            style={{"backgroundColor": status_color(packet.status_code)}}
        ></span>
        <div className="packet-main">
            <div className="packet-heading">
                <strong>{status_label(packet.status_code)}</strong>
                <span>{"ID " + str(packet.user_id)[-6:]}</span>
            </div>
            <p>{status_description(packet.status_code)}</p>
            <div className="packet-meta">
                <span>{age_label}</span>
                <span>{str(packet.rssi) + " dBm" if packet.rssi > -127 else "RSSI unknown"}</span>
                <span>{"seq " + str(packet.sequence)}</span>
            </div>
        </div>
        <ChevronRight size={18} />
    </article>;
}


def:pub AppShell -> JsxElement {
    has booting: bool = True;
    has onboarding_done: bool = False;
    has active_tab: str = "command";
    has tools_view: str = "guide";
    has systems_view: str = "radio";
    has user_id: int = 0;
    has packets: list[SosPacket] = [];
    has mesh_state: str = "idle";
    has mesh_message: str = "Mesh relay has not been started.";
    has plugin_version: str = "unavailable";
    has platform_name: str = "web";
    has ble_permission: str = "unavailable";
    has notification_permission: str = "unavailable";
    has network_state: str = "unknown";
    has location_ready: bool = False;
    has latitude: float = 0.0;
    has longitude: float = 0.0;
    has location_accuracy: float = 0.0;
    has location_message: str = "Location not sampled.";
    has selected_status: int = 1;
    has distress_armed: bool = False;
    has privacy_mode: str = "Relay Only";
    has battery_mode: str = "Bridge";
    has alert_message: str = "";
    has alert_tone: str = "neutral";
    has busy: bool = False;
    has activity_log: list[str] = [];
    has disaster_events: list[dict[str, object]] = [];
    has disaster_source: str = "not loaded";
    has sync_attempts: list[dict[str, object]] = [];
    has sync_receipts: list[dict[str, object]] = [];
    has adjudications: list[dict[str, object]] = [];
    has handoff_artifact: any = None;  # jac:ignore[W1037]
    has handoff_qr_open: bool = False;
    has sync_state: str = "idle";
    has internet_failures: int = 0;
    has offline_tiles: int = 0;
    has drill_low_battery: bool = False;
    has drill_congestion: bool = False;
    has ultrasonic_listening: bool = False;
    has ultrasonic_frequency: float = 0.0;
    has ultrasonic_energy: float = 0.0;
    has ultrasonic_base: float = 17000.0;
    has ultrasonic_log: list[str] = [];
    has foundation_status: FoundationModelStatus = FoundationModelStatus(
        available=False,
        availability="not checked",
        mode="unavailable"
    );
    has survival_chat: list[ClientSurvivalChatMessage] = [];
    has survival_input: str = "";
    has survival_sending: bool = False;
    has strobe_active: bool = False;
    has heading: float = 0.0;
    has compass_status: str = "Tap enable to start the live heading.";
    has strobe_timer: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has strobe_phase: Ref[bool] = Ref(False);

    async def refresh_readiness {
        readiness: NativeReadiness = await inspect_native_readiness();
        platform_name = readiness.platform;
        ble_permission = readiness.ble_permission;
        notification_permission = readiness.notification_permission;
        network_state = readiness.network_state;
        plugin_version = readiness.plugin_version;
        if readiness.native {
            mesh_message = readiness.message;
        }
    }

    async def refresh_foundation_status {
        foundation_status = await foundation_model_status();
    }

    async def send_survival_message(field_context: list[str]) {
        message = survival_input.strip();
        if not message or survival_sending { return; }
        user_message = ClientSurvivalChatMessage(
            role="user",
            content=message[:1200],
            timestamp=unix_seconds()
        );
        next_history = (survival_chat + [user_message])[-24:];
        survival_chat = next_history;
        survival_input = "";
        survival_sending = True;
        result: FoundationModelChatResponse = await chat_with_survival_guide(
            [
                {
                    "role": item.role,
                    "content": item.content,
                    "timestamp": item.timestamp
                }
                for item in next_history[-12:]
            ],
            field_context
        );
        foundation_status = FoundationModelStatus(
            available=result.available,
            availability=result.availability,
            mode="on-device" if result.available else "unavailable"
        );
        if result.reply {
            survival_chat = (next_history + [ClientSurvivalChatMessage(
                role="assistant",
                content=result.reply,
                timestamp=unix_seconds()
            )])[-24:];
            await save_survival_chat_history(survival_chat);
            append_log("Generated a local survival-guide reply.");
        } else {
            survival_chat = survival_chat[:-1];
            alert_message = "Survival Guide unavailable: " + result.availability;
            alert_tone = "warning";
        }
        survival_sending = False;
    }

    async def copy_survival_message(content: str) {
        try {
            clipboard: any = _window.navigator.clipboard;  # jac:ignore[W1037]
            if not clipboard {
                raise RuntimeError("Clipboard unavailable");
            }
            await clipboard.writeText(content);
            alert_message = "Guide reply copied.";
            alert_tone = "neutral";
        } except Exception {
            alert_message = "Could not copy the guide reply.";
            alert_tone = "warning";
        }
    }

    async def erase_survival_chat {
        await clear_survival_chat_history();
        survival_chat = [];
        survival_input = "";
        alert_message = "Local Survival Guide history cleared.";
        alert_tone = "neutral";
    }

    def append_log(message: str) {
        activity_log = [message] + activity_log[:7];
    }

    async def handle_mesh_event(event: any) {  # jac:ignore[W1037]
        kind = str(event["kind"]);
        message = str(event["message"]);
        append_log(message);
        if kind != "packet" { return; }

        data = event["data"] as dict[str, object];
        try {
            packet = packet_from_bytes(
                data["bytes"] as list[int],
                data["rssi"] as int
            );
            now = unix_seconds();
            if packet.is_expired(now) or contains_packet(packets, packet.unique_id()) {
                return;
            }
            if packet.target_id != 0 and packet.target_id != user_id { return; }

            updated = replace_packet(packets, packet);
            packets = updated;
            await save_packets(updated);

            if packet.user_id != user_id and packet.status_code != 0 {
                alert_message = status_label(packet.status_code) + ": " + status_description(packet.status_code);
                alert_tone = "danger";
                await emergency_haptic();
                await notify_incoming(
                    packet.user_id + packet.sequence,
                    "SafeRelay " + status_label(packet.status_code),
                    "Nearby packet " + packet.unique_id() + ". Reported, not responder-confirmed."
                );
            }

            relay = evaluate_relay(
                packet,
                now,
                privacy_mode,
                battery_mode,
                len(updated)
            );
            append_log(relay.decision.upper() + ": " + relay.reason);
            if relay.should_relay() {
                await publish_packet(packet_to_bytes(packet));
            }
        } except Exception as error {
            append_log("Rejected malformed radio packet: " + str(error));
        }
    }

    async def toggle_mesh {
        busy = True;
        result = (
            await stop_mesh()
            if mesh_is_running()
            else await start_mesh()
        );
        mesh_state = result.state;
        mesh_message = result.message;
        platform_name = result.platform;
        plugin_version = result.plugin_version;
        alert_message = result.message;
        alert_tone = "success" if result.state == "active" else "warning";
        append_log(result.message);
        busy = False;
        await refresh_readiness();
    }

    async def refresh_location {
        busy = True;
        fix = await current_location();
        location_ready = fix.ready;
        latitude = fix.latitude;
        longitude = fix.longitude;
        location_accuracy = fix.accuracy;
        location_message = fix.message;
        if not fix.ready {
            alert_message = fix.message;
            alert_tone = "warning";
        }
        busy = False;
    }

    async def send_selected_status {
        if not distress_armed {
            distress_armed = True;
            alert_message = "Distress action armed. Confirm to create the radio packet.";
            alert_tone = "warning";
            await emergency_haptic();
            return;
        }

        busy = True;
        if not location_ready {
            fix = await current_location();
            location_ready = fix.ready;
            latitude = fix.latitude;
            longitude = fix.longitude;
            location_accuracy = fix.accuracy;
            location_message = fix.message;
        }
        if not location_ready {
            alert_message = "Packet not created. A current position is required.";
            alert_tone = "danger";
            distress_armed = False;
            busy = False;
            return;
        }

        sequence = await next_sequence();
        packet = create_packet(
            user_id,
            sequence,
            latitude,
            longitude,
            selected_status,
            unix_seconds()
        );
        updated = replace_packet(packets, packet);
        packets = updated;
        await save_packets(updated);
        radio_sent = await publish_packet(packet_to_bytes(packet));
        distress_armed = False;
        busy = False;
        alert_tone = "danger" if selected_status != 0 else "success";
        alert_message = (
            status_label(selected_status) + " packet is live on the local radio."
            if radio_sent
            else status_label(selected_status) + " packet is queued locally; native radio delivery is not confirmed."
        );
        append_log(alert_message);
        await emergency_haptic();
    }

    async def choose_privacy(mode: str) {
        privacy_mode = mode;
        await save_setting(PRIVACY_KEY, mode);
        append_log("Privacy mode changed to " + mode);
    }

    async def choose_battery(mode: str) {
        battery_mode = mode;
        await save_setting(BATTERY_KEY, mode);
        append_log("Battery mode changed to " + mode);
    }

    async def finish_onboarding {
        await complete_onboarding();
        onboarding_done = True;
        alert_message = "Device setup saved. Start the mesh when you are ready.";
        alert_tone = "success";
    }

    async def erase_packet_history {
        await clear_packets();
        packets = [];
        alert_message = "Local packet history cleared from this device.";
        alert_tone = "neutral";
    }

    async def erase_operational_ledgers {
        await clear_operational_history();
        sync_attempts = [];
        sync_receipts = [];
        adjudications = [];
        alert_message = "Local sync, receipt, and adjudication evidence cleared.";
        alert_tone = "neutral";
    }

    async def refresh_operational_ledgers {
        sync_attempts = await load_records(SYNC_ATTEMPTS_KEY);
        sync_receipts = await load_records(SYNC_RECEIPTS_KEY);
        adjudications = await load_records(ADJUDICATIONS_KEY);
    }

    async def check_reachability {
        check: any = await verify_internet();  # jac:ignore[W1037]
        internet_failures = int(check["failures"]);
        if bool(check["online"]) {
            network_state = "online";
            return;
        }
        if internet_failures >= 3 {
            network_state = "offline";
            append_log("Three internet probes failed; offline relay policy is active.");
            if platform_name != "web" and mesh_state != "active" {
                result = await start_mesh();
                mesh_state = result.state;
                mesh_message = result.message;
                append_log("Automatic mesh start: " + result.message);
            }
        }
    }

    async def refresh_disasters {
        busy = True;
        result: any = await fetch_disaster_events(True);  # jac:ignore[W1037]
        loaded_events = result["events"] as list[dict[str, object]];
        loaded_source = str(result["source"]);
        disaster_events = loaded_events;
        disaster_source = loaded_source;
        alert_message = (
            str(len(loaded_events)) + " disaster notices loaded from " + loaded_source + " data."
        );
        alert_tone = "success" if len(loaded_events) > 0 else "warning";
        busy = False;
    }

    async def download_local_map {
        if not location_ready {
            await refresh_location();
        }
        if not location_ready { return; }
        busy = True;
        result: any = await cache_map_region(latitude, longitude, 13);  # jac:ignore[W1037]
        offline_tiles = int(result["cached"]);
        alert_message = (
            str(result["cached"]) + " of " + str(result["total"])
            + " local map tiles are available offline."
        );
        alert_tone = "success" if offline_tiles > 0 else "warning";
        busy = False;
    }

    async def run_cloud_sync {
        busy = True;
        sync_state = "checking";
        reachability: any = await verify_internet();  # jac:ignore[W1037]
        online = bool(reachability["online"]);
        network_state = "online" if online else network_state;
        result: any = await sync_relayed_packets(  # jac:ignore[W1037]
            packets,
            user_id,
            privacy_mode,
            online,
            platform_name
        );
        sync_state = str(result["status"]);
        visible_attempt: dict[str, object] = {
            "attemptId": result["attemptId"],
            "timestamp": result["timestamp"],
            "status": result["status"],
            "pending": result["pending"],
            "synced": result["synced"],
            "failed": result["failed"],
            "duplicates": result["duplicates"],
            "privacyMode": result["privacyMode"],
            "message": result["message"]
        };
        sync_attempts = [visible_attempt] + sync_attempts[:99];
        new_receipts = result["receipts"] as list[dict[str, object]];
        if len(new_receipts) > 0 {
            sync_receipts = new_receipts + sync_receipts;
        }
        synced_ids = result["syncedIds"] as list[str];
        if len(synced_ids) > 0 {
            for packet in packets {
                if packet.unique_id() in synced_ids { packet.is_synced = True; }
            }
            await save_packets(packets);
            packets = packets[:];
        }
        alert_message = str(result["message"]);
        alert_tone = "success" if sync_state == "succeeded" else "warning";
        append_log("Cloud sync " + sync_state + ": " + str(result["message"]));
        busy = False;
    }

    async def record_adjudication(issue_id: str, decision: str) {
        item = {
            "issueId": issue_id,
            "decision": decision,
            "reviewer": "local operator",
            "note": "Recorded from the Jac field console.",
            "timestamp": unix_seconds(),
            "localOnly": True
        };
        await append_record(ADJUDICATIONS_KEY, item);
        adjudications = [item] + adjudications;
        alert_message = "Local adjudication recorded: " + decision + ".";
        alert_tone = "success";
    }

    async def run_handoff_action(
        action: str,
        current_handoff: dict[str, object]
    ) {
        busy = True;
        artifact: any = await prepare_handoff(current_handoff);  # jac:ignore[W1037]
        handoff_artifact = artifact;
        if action == "qr" {
            if str(artifact["qrPayload"]) {
                handoff_qr_open = not handoff_qr_open;
                alert_message = "Offline handoff QR prepared.";
                alert_tone = "success";
            } else {
                handoff_qr_open = False;
                alert_message = "This handoff exceeds the offline QR limit. Use file, share, or print transfer.";
                alert_tone = "warning";
            }
            busy = False;
            return;
        }
        result: any = (  # jac:ignore[W1037]
            await copy_handoff(artifact) if action == "copy"
            else (
                await save_handoff(artifact) if action == "save"
                else (
                    await share_handoff(artifact) if action == "share"
                    else await print_handoff(artifact)
                )
            )
        );
        alert_message = str(result["message"]);
        alert_tone = "success" if bool(result["ok"]) else "warning";
        append_log(str(result["message"]));
        busy = False;
    }

    async def send_ultrasonic {
        try {
            result: any = await transmit_ultrasonic(  # jac:ignore[W1037]
                "SOS:" + str(user_id)[-3:],
                ultrasonic_base
            );
            ultrasonic_log = [
                ("TX " + str(result["message"])) if bool(result["sent"]) else str(result["message"])
            ] + ultrasonic_log[:5];
            alert_message = (
                "Ultrasonic packet transmitted."
                if bool(result["sent"]) else str(result["message"])
            );
            alert_tone = "success" if bool(result["sent"]) else "warning";
        } except Exception as error {
            message = "Ultrasonic transmitter unavailable: " + str(error);
            ultrasonic_log = [message] + ultrasonic_log[:5];
            alert_message = message;
            alert_tone = "warning";
        }
    }

    async def toggle_ultrasonic_listener {
        if ultrasonic_listening {
            result: any = await stop_ultrasonic_listener();  # jac:ignore[W1037]
            ultrasonic_listening = False;
            ultrasonic_frequency = 0.0;
            ultrasonic_energy = 0.0;
            append_log(str(result["message"]));
            return;
        }
        result: any = await start_ultrasonic_listener(  # jac:ignore[W1037]
            lambda (event: any) {  # jac:ignore[W1037]
                ultrasonic_frequency = float(event["frequency"]);
                ultrasonic_energy = float(event["energy"]);
            }
        );
        ultrasonic_listening = bool(result["listening"]);
        alert_message = str(result["message"]);
        alert_tone = "success" if ultrasonic_listening else "warning";
    }

    async def enable_compass {
        tools_view = "compass";
        try {
            orientation_event: any = _window.DeviceOrientationEvent;  # jac:ignore[W1037]
            if orientation_event and orientation_event.requestPermission {
                result = await orientation_event.requestPermission();
                if str(result) != "granted" {
                    compass_status = "Motion access was not granted.";
                    alert_message = compass_status;
                    alert_tone = "warning";
                    return;
                }
            }
            compass_status = "Live magnetic heading active.";
            alert_message = compass_status;
            alert_tone = "success";
        } except Exception as error {
            compass_status = "Compass unavailable: " + str(error);
            alert_message = compass_status;
            alert_tone = "warning";
        }
    }

    async def toggle_strobe {
        if strobe_active {
            if strobe_timer.current { clearInterval(strobe_timer.current); }
            strobe_timer.current = None;
            strobe_phase.current = False;
            strobe_active = False;
            await set_torch(False);
            alert_message = "Visual beacon stopped.";
            alert_tone = "neutral";
            return;
        }
        enabled = await set_torch(True);
        if not enabled {
            alert_message = "Torch unavailable. Check camera permission in Settings.";
            alert_tone = "warning";
            return;
        }
        strobe_phase.current = True;
        strobe_active = True;
        strobe_timer.current = setInterval(lambda {
            phase = not bool(strobe_phase.current);
            strobe_phase.current = phase;
            set_torch(phase);
        }, 650);
        alert_message = "Visual beacon active.";
        alert_tone = "success";
    }

    async can with entry {
        user_id = await get_or_create_user_id();
        packets = await load_packets();
        onboarding_done = await load_onboarding_complete();
        privacy_mode = await load_setting(PRIVACY_KEY, "Relay Only");
        battery_mode = await load_setting(BATTERY_KEY, "Bridge");
        await refresh_operational_ledgers();
        platform_name = native_platform();
        await refresh_readiness();
        await refresh_foundation_status();
        survival_chat = await load_survival_chat_history();
        resumed = await resume_saved_mesh();
        if resumed is not None {
            mesh_state = resumed.state;
            mesh_message = resumed.message;
            plugin_version = resumed.plugin_version;
            append_log("Recovered enabled mesh state after app restart.");
        }
        await check_reachability();
        register_app_state_observer();
        booting = False;
    }

    useEffect(lambda {
        set_mesh_event_sink(handle_mesh_event);
        return lambda { clear_mesh_event_sink(); };
    }, [packets, privacy_mode, battery_mode, user_id]);

    useEffect(lambda {
        orientation_handler = lambda (event: any) {  # jac:ignore[W1037]
            if event.webkitCompassHeading is not None {
                heading = float(event.webkitCompassHeading);
            } elif event.alpha is not None {
                heading = float(event.alpha);
            }
        };
        window.addEventListener("deviceorientation", orientation_handler);  # jac:ignore[W2001]
        return lambda {
            window.removeEventListener("deviceorientation", orientation_handler);  # jac:ignore[W2001]
        };
    }, []);

    useEffect(lambda {
        return lambda {
            if strobe_timer.current { clearInterval(strobe_timer.current); }
            set_torch(False);
            stop_ultrasonic_listener();
        };
    }, []);

    useEffect(lambda {
        reachability_timer = setInterval(lambda { check_reachability(); }, 60000);
        disaster_timer = setInterval(lambda { fetch_disaster_events(); }, 1200000);
        return lambda {
            clearInterval(reachability_timer);
            clearInterval(disaster_timer);
        };
    }, [mesh_state, platform_name]);

    now = unix_seconds();
    readiness = readiness_score(
        ble_permission == "granted",
        location_ready,
        notification_permission == "granted",
        mesh_state == "active"
    );
    urgent_count = len([
        packet for packet in packets
        if packet.status_code != 0 and not packet.is_expired(now)
    ]);
    incident: dict[str, object] = incident_report(packets, now);
    evidence: ClientOperationalReport = evidence_board(packets, now);
    brief: ClientOperationalReport = field_brief(
        packets,
        now,
        network_state != "offline",
        False
    );
    needs: dict[str, object] = responder_needs(packets, now);
    need_rows = needs["needs"] as list[dict[str, object]];
    queue = assess_cloud_queue(
        packets,
        network_state != "offline",
        privacy_mode,
        True
    );
    receipt_ids: list[str] = [
        str(item["packetId"]) for item in sync_receipts
        if bool(item["serverReceipted"])
    ];
    reconciliation: ClientOperationalReport = reconcile_cloud(
        packets,
        receipt_ids
    );
    handoff: dict[str, object] = handoff_export(packets, now, privacy_mode);
    handoff_rows = handoff["reports"] as list[dict[str, object]];
    trust: dict[str, object] = trust_score(
        True,
        True,
        True,
        len(packets) > 0,
        False
    );
    drill: ClientDrillReport = deterministic_drill(
        12,
        drill_low_battery,
        drill_congestion
    );
    if booting {
        return <main className="loading-screen">
            <div className="brand-logo large"></div>
            <span>SAFERELAY</span>
            <div className="loading-line"></div>
        </main>;
    }

    if not onboarding_done {
        return <main className="onboarding">
            <header className="onboarding-brand">
                <div className="brand-logo large"></div>
                <div>
                    <span>SAFERELAY</span>
                    <h1>FIELD NODE SETUP</h1>
                </div>
            </header>
            <section className="onboarding-checks">
                <FactRow
                    icon={<Bluetooth size={20} />}
                    label="Bluetooth relay"
                    value="Requested when mesh starts"
                />
                <FactRow
                    icon={<MapPin size={20} />}
                    label="Position"
                    value="Attached only to created packets"
                />
                <FactRow
                    icon={<Bell size={20} />}
                    label="Local alerts"
                    value="Nearby reports on this device"
                />
                <FactRow
                    icon={<LockKeyhole size={20} />}
                    label="Default privacy"
                    value="Relay Only"
                    tone="safe"
                />
            </section>
            <div className="proof-boundary">
                <ShieldCheck size={20} />
                <p>Packets are local reports. Delivery, responder receipt, and rescue outcome remain unconfirmed.</p>
            </div>
            <button className="primary-command" onClick={finish_onboarding}>
                <Check size={19} />
                COMPLETE DEVICE SETUP
            </button>
        </main>;
    }

    return <div className={"app-shell strobe-active" if strobe_active else "app-shell"}>
        <header className="app-header">
            <div className="brand-lockup">
                <div className="brand-logo"></div>
                <div>
                    <strong>SAFERELAY</strong>
                    <span>{"NODE " + str(user_id)[-6:]}</span>
                </div>
            </div>
            <div className={"radio-indicator " + mesh_state}>
                <span></span>
                {mesh_state.upper()}
            </div>
        </header>

        {if alert_message {
            <div key="runtime-alert" className={"alert-strip " + alert_tone}>
                <TriangleAlert size={17} />
                <span>{alert_message}</span>
                <button
                    aria-label="Dismiss alert"
                    title="Dismiss alert"
                    onClick={lambda { alert_message = ""; }}
                >×</button>
            </div>
        }}

        <main className="app-content">
            {if active_tab == "command" {
                <div key="command-panel" className="tab-panel">
                <section className="page-heading">
                    <div>
                        <h1>Command</h1>
                    </div>
                    <button
                        className="icon-button"
                        title="Refresh readiness"
                        aria-label="Refresh readiness"
                        onClick={refresh_readiness}
                    ><RefreshCw size={19} /></button>
                </section>

                <section className="readiness-band">
                    <div className="readiness-score">
                        <strong>{readiness}</strong>
                        <span>/100</span>
                    </div>
                    <div>
                        <span>FIELD READINESS</span>
                        <h2>{"Ready to relay" if readiness >= 70 else "Setup incomplete"}</h2>
                    </div>
                    <button
                        className={"mesh-toggle stop" if mesh_state == "active" else "mesh-toggle"}
                        onClick={toggle_mesh}
                        disabled={busy}
                    >
                        {<Square size={17} /> if mesh_state == "active" else <Play size={17} />}
                        {"STOP MESH" if mesh_state == "active" else "START MESH"}
                    </button>
                </section>

                <section className="metric-grid">
                    <Metric label="ACTIVE REPORTS" value={str(urgent_count)} detail="unexpired local evidence" />
                    <Metric label="RADIO QUEUE" value={str(len(packets))} detail="stored on this device" />
                    <Metric label="PRIVACY" value={privacy_mode} detail="current forwarding policy" />
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div>
                            <span>RECENT EVIDENCE</span>
                            <h2>Nearby reports</h2>
                        </div>
                        <Radio size={21} />
                    </div>
                    <div className="packet-list">
                        {if len(packets) == 0 {
                            <div key="empty-packets" className="empty-state">
                                <Radio size={28} />
                                <strong>No reports yet</strong>
                            </div>
                        }}
                        {for packet in packets[:6] {
                            <PacketRow key={packet.unique_id()} packet={packet} now={now} />
                        }}
                    </div>
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>INCIDENT SUMMARY</span><h2>Evidence board</h2></div>
                        <ListChecks size={21} />
                    </div>
                    <div className="metric-grid compact-metrics">
                        <Metric label="ACTIVE" value={str(incident["active"])} detail="current help reports" />
                        <Metric label="STALE" value={str(incident["stale"])} detail="needs confirmation" />
                        <Metric label="CONFLICTS" value={str(incident["conflicts"])} detail="human review" />
                    </div>
                    {for fact in evidence.facts {
                        <div key={fact} className="evidence-line"><Check size={16} /><span>{fact}</span></div>
                    }}
                    {for warning in evidence.warnings {
                        <div key={warning} className="evidence-line warning"><TriangleAlert size={16} /><span>{warning}</span></div>
                    }}
                    {for unknown in evidence.unknowns {
                        <div key={unknown} className="evidence-line unknown"><ShieldCheck size={16} /><span>{unknown}</span></div>
                    }}
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>RESPONDER NEEDS</span><h2>Priority board</h2></div>
                        <HeartPulse size={21} />
                    </div>
                    {for item in need_rows {
                        <div key={str(item["category"])} className="need-row">
                            <span>{str(item["category"])}</span>
                            <strong>{str(item["count"])}</strong>
                            <small>{"P" + str(item["priority"])}</small>
                        </div>
                    }}
                    <div className="brief-box">
                        <strong>{brief.title}</strong>
                        {for fact in brief.facts { <p key={fact}>{fact}</p> }}
                        {for warning in brief.warnings { <p key={warning} className="warning-copy">{warning}</p> }}
                    </div>
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>RESPONDER HANDOFF</span><h2>Privacy-aware export</h2></div>
                        <UploadCloud size={21} />
                    </div>
                    <FactRow icon={<Database size={18} />} label="Rows ready" value={str(len(handoff_rows))} />
                    <FactRow icon={<LockKeyhole size={18} />} label="Privacy mode" value={privacy_mode} />
                    <FactRow icon={<ShieldCheck size={18} />} label="Outcome proof" value="Unknown" tone="warning" />
                    <div className="handoff-actions">
                        <button title="Copy JSON" aria-label="Copy responder handoff JSON" onClick={lambda { run_handoff_action("copy", handoff); }} disabled={busy}><Copy size={17} /></button>
                        <button title="Save files" aria-label="Save responder handoff files" onClick={lambda { run_handoff_action("save", handoff); }} disabled={busy}><Download size={17} /></button>
                        <button title="Share files" aria-label="Share responder handoff files" onClick={lambda { run_handoff_action("share", handoff); }} disabled={busy}><Share2 size={17} /></button>
                        <button title="Print PDF" aria-label="Print responder handoff PDF" onClick={lambda { run_handoff_action("print", handoff); }} disabled={busy}><Printer size={17} /></button>
                        <button title="Show offline QR" aria-label="Show responder handoff QR" onClick={lambda { run_handoff_action("qr", handoff); }} disabled={busy}><QrCode size={17} /></button>
                    </div>
                    {if handoff_qr_open and handoff_artifact is not None and str(handoff_artifact["qrPayload"]) {
                        <div key="handoff-qr" className="handoff-qr">
                            <QRCodeSVG
                                value={str(handoff_artifact["qrPayload"])}
                                size={220}
                                level="M"
                                bgColor="#ffffff"
                                fgColor="#080d12"
                            />
                            <strong>OFFLINE HANDOFF QR</strong>
                            <small>{"SHA-256 " + str(handoff_artifact["sha256"])}</small>
                            <p>Scanning transfers local evidence only. It does not prove responder receipt.</p>
                        </div>
                    }}
                    <button className="secondary-command" onClick={lambda { record_adjudication("incident-" + str(now), "keep"); }}>
                        <Check size={17} /> RECORD LOCAL REVIEW
                    </button>
                    <small className="boundary-copy">{str(handoff["boundary"])}</small>
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>DETERMINISTIC SCENARIO</span><h2>{drill.scenario}</h2></div>
                        <Gauge size={21} />
                    </div>
                    <div className="setting-row-inline">
                        <label><input type="checkbox" checked={drill_low_battery} onChange={lambda (event: ChangeEvent) { drill_low_battery = event.target.checked; }} /> LOW BATTERY</label>
                        <label><input type="checkbox" checked={drill_congestion} onChange={lambda (event: ChangeEvent) { drill_congestion = event.target.checked; }} /> CONGESTION</label>
                    </div>
                    <div className="metric-grid compact-metrics">
                        <Metric label="DELIVERED" value={str(drill.delivered)} detail="simulated packets" />
                        <Metric label="DEFERRED" value={str(drill.deferred)} detail="battery policy" />
                        <Metric label="DROPPED" value={str(drill.dropped)} detail="congestion" />
                    </div>
                    <div className="drill-events">
                        {for item in drill.events[:8] {
                            <div key={item} className="log-line"><span>SIM</span><p>{item}</p></div>
                        }}
                    </div>
                    <div className="proof-boundary compact">
                        <ShieldCheck size={18} /><p>{drill.proof_boundary}</p>
                    </div>
                </section>
                </div>
            }}

            {if active_tab == "map" {
                <div key="map-panel" className="tab-panel map-tab-panel">
                    <IncidentMap
                        packets={packets}
                        latitude={latitude}
                        longitude={longitude}
                        location_ready={location_ready}
                    />
                </div>
            }}

            {if active_tab == "tools" {
                <div key="tools-panel" className={"tab-panel tools-" + tools_view}>
                <section className="page-heading">
                    <div><h1>Field Tools</h1></div>
                    <Wrench size={22} />
                </section>

                <div className="mode-switch four field-tools-switch" role="tablist" aria-label="Field tool">
                    <button id="tool-guide" className={"active" if tools_view == "guide" else ""} onClick={lambda { tools_view = "guide"; }}>GUIDE</button>
                    <button id="tool-compass" className={"active" if tools_view == "compass" else ""} onClick={enable_compass}>COMPASS</button>
                    <button id="tool-beacon" className={"active" if tools_view == "strobe" else ""} onClick={lambda { tools_view = "strobe"; }}>BEACON</button>
                    <button id="tool-sonic" className={"active" if tools_view == "ultrasonic" else ""} onClick={lambda { tools_view = "ultrasonic"; }}>SONIC</button>
                </div>

                <section className="tool-band mode-panel mode-compass detail-tool">
                    <div className="tool-heading">
                        <div className="tool-icon compass"><Compass size={21} /></div>
                        <div><span>LIVE HEADING</span><h2>{f"{heading:.0f}°"}</h2></div>
                    </div>
                    <div className="compass-dial large">
                        <div style={{"transform": f"rotate({heading:.1f}deg)"}}></div>
                        <span>N</span>
                    </div>
                    <p className="tool-status">{compass_status}</p>
                    <button className="tool-action" onClick={enable_compass}>
                        <Compass size={18} /> ENABLE COMPASS
                    </button>
                </section>

                <section className="tool-band mode-panel mode-strobe detail-tool">
                    <div className="tool-heading">
                        <div className="tool-icon strobe"><Flashlight size={21} /></div>
                        <div><span>VISUAL BEACON</span><h2>{"ACTIVE" if strobe_active else "READY"}</h2></div>
                    </div>
                    <button className={"tool-action active large-action" if strobe_active else "tool-action large-action"} onClick={toggle_strobe}>
                        <Flashlight size={22} />
                        {"STOP STROBE" if strobe_active else "START STROBE"}
                    </button>
                </section>

                <section className="tool-band mode-panel mode-ultrasonic detail-tool">
                    <div className="tool-heading">
                        <div className="tool-icon morse"><Volume2 size={21} /></div>
                        <div><span>17–20 KHZ FSK</span><h2>Ultrasonic modem</h2></div>
                    </div>
                    <label className="field-label">
                        BASE FREQUENCY
                        <input
                            type="range"
                            min="15000"
                            max="19000"
                            step="250"
                            value={str(ultrasonic_base)}
                            onChange={lambda (event: ChangeEvent) { ultrasonic_base = float(event.target.value); }}
                        />
                        <output>{f"{ultrasonic_base / 1000.0:.2f} kHz"}</output>
                    </label>
                    <div className="spectrum-meter">
                        <div style={{"width": f"{max(2.0, ultrasonic_energy * 100.0):.1f}%"}}></div>
                    </div>
                    <div className="tool-readout">
                        <strong>{f"{ultrasonic_frequency / 1000.0:.2f} kHz" if ultrasonic_listening else "MIC IDLE"}</strong>
                        <span>{f"energy {ultrasonic_energy * 100.0:.0f}%" if ultrasonic_listening else "Spectrum listener stopped"}</span>
                    </div>
                    <div className="tool-actions-row">
                        <button className="tool-action" onClick={send_ultrasonic}>
                            <Volume2 size={18} /> SEND SOS
                        </button>
                        <button className={"tool-action active" if ultrasonic_listening else "tool-action"} onClick={toggle_ultrasonic_listener}>
                            <Headphones size={18} /> {"STOP RX" if ultrasonic_listening else "LISTEN"}
                        </button>
                    </div>
                    {for item in ultrasonic_log {
                        <div key={item} className="log-line"><span>FSK</span><p>{item}</p></div>
                    }}
                </section>

                <section className="tool-band mode-panel mode-guide survival-guide">
                    <div className="survival-chat-toolbar">
                        <div className="survival-guide-status">
                            <Sparkles size={17} />
                            <div><strong>Survival Guide</strong><small>{foundation_status.availability}</small></div>
                        </div>
                        <button className="icon-button survival-clear" title="Clear chat" aria-label="Clear chat history" onClick={erase_survival_chat} disabled={survival_sending or len(survival_chat) == 0}>
                            <Trash2 size={18} />
                        </button>
                    </div>
                    <div className="survival-transcript" aria-live="polite">
                        {if len(survival_chat) == 0 {
                            <div key="guide-empty" className="survival-empty">
                                <MessageCircle size={30} />
                                <h2>How can I help?</h2>
                            </div>
                        }}
                        {for (index, item) in enumerate(survival_chat) {
                            <article key={str(item.timestamp) + "-" + str(index)} className={"survival-message " + item.role}>
                                <p>{item.content}</p>
                                {if item.role == "assistant" {
                                    <div className="survival-message-actions">
                                        <button title="Copy reply" aria-label="Copy guide reply" onClick={lambda { copy_survival_message(item.content); }}>
                                            <Copy size={17} />
                                        </button>
                                    </div>
                                }}
                            </article>
                        }}
                        {if survival_sending {
                            <div key="guide-thinking" className="survival-thinking" aria-label="Guide is responding">
                                <span></span><span></span><span></span>
                            </div>
                        }}
                    </div>
                    <div className="survival-composer">
                        <textarea
                            value={survival_input}
                            maxLength={1200}
                            rows={1}
                            aria-label="Message Survival Guide"
                            placeholder="Message Survival Guide"
                            onChange={lambda (event: ChangeEvent) { survival_input = event.target.value; }}
                        ></textarea>
                        <button className="survival-send" title="Send message" aria-label="Send message" onClick={lambda { send_survival_message(evidence.facts + evidence.warnings + evidence.unknowns); }} disabled={survival_sending or not survival_input.strip()}>
                            <Send size={19} />
                        </button>
                    </div>
                </section>
                </div>
            }}

            {if active_tab == "sos" {
                <div key="distress-panel" className="tab-panel">
                <section className="page-heading distress-heading">
                    <div><h1>Distress</h1></div>
                    <Siren size={24} />
                </section>

                <section className="location-lock">
                    <div className={"lock-indicator ready" if location_ready else "lock-indicator"}>
                        <MapPin size={20} />
                    </div>
                    <div>
                        <span>PACKET POSITION</span>
                        <strong>{f"{latitude:.5f}, {longitude:.5f}" if location_ready else "Not acquired"}</strong>
                        <small>{f"accuracy ±{location_accuracy:.0f} m" if location_ready else location_message}</small>
                    </div>
                    <button className="icon-button" onClick={refresh_location} title="Acquire location" aria-label="Acquire location">
                        <RefreshCw size={18} />
                    </button>
                </section>

                <section
                    className={"status-selector status-" + str(selected_status)}
                    role="radiogroup"
                    aria-label="Emergency type"
                    aria-orientation="horizontal"
                >
                    <button
                        className={"critical selected" if selected_status == 1 else "critical"}
                        role="radio"
                        aria-checked={selected_status == 1}
                        aria-label="Rescue, immediate danger"
                        onClick={lambda { selected_status = 1; distress_armed = False; }}
                    >
                        <span className="status-icon"><Siren size={21} /></span>
                        <strong>RESCUE</strong>
                    </button>
                    <button
                        className={"medical selected" if selected_status == 2 else "medical"}
                        role="radio"
                        aria-checked={selected_status == 2}
                        aria-label="Medical, urgent care"
                        onClick={lambda { selected_status = 2; distress_armed = False; }}
                    >
                        <span className="status-icon"><HeartPulse size={21} /></span>
                        <strong>MEDICAL</strong>
                    </button>
                    <button
                        className={"trapped selected" if selected_status == 3 else "trapped"}
                        role="radio"
                        aria-checked={selected_status == 3}
                        aria-label="Trapped, pinned or blocked"
                        onClick={lambda { selected_status = 3; distress_armed = False; }}
                    >
                        <span className="status-icon"><TriangleAlert size={21} /></span>
                        <strong>TRAPPED</strong>
                    </button>
                    <button
                        className={"supplies selected" if selected_status == 4 else "supplies"}
                        role="radio"
                        aria-checked={selected_status == 4}
                        aria-label="Supplies, water or food"
                        onClick={lambda { selected_status = 4; distress_armed = False; }}
                    >
                        <span className="status-icon"><PackageOpen size={21} /></span>
                        <strong>SUPPLIES</strong>
                    </button>
                </section>

                <button
                    className={"distress-command armed" if distress_armed else "distress-command"}
                    onClick={send_selected_status}
                    disabled={busy}
                >
                    <span className="distress-command-icon"><Siren size={30} /></span>
                    <span className="distress-command-copy">
                        <small>{status_label(selected_status)}</small>
                        <strong>{"CONFIRM RADIO PACKET" if distress_armed else "ARM DISTRESS ACTION"}</strong>
                    </span>
                </button>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>PACKET EVIDENCE</span><h2>Broadcast lifecycle</h2></div>
                        <Activity size={21} />
                    </div>
                    <div className="lifecycle-track">
                        <div className={"complete" if len(packets) > 0 else ""}><span>1</span><strong>Stored</strong><small>durable local record</small></div>
                        <div className={"complete" if mesh_state == "active" else ""}><span>2</span><strong>Radio live</strong><small>local bearer active</small></div>
                        <div className={"complete" if len(sync_receipts) > 0 else ""}><span>3</span><strong>Cloud receipt</strong><small>durable server evidence</small></div>
                        <div><span>4</span><strong>Responder</strong><small>not confirmed</small></div>
                    </div>
                    <FactRow icon={<Radio size={18} />} label="Local packets" value={str(len(packets))} />
                    <FactRow icon={<Cloud size={18} />} label="Server receipts" value={str(len(sync_receipts))} tone={"safe" if len(sync_receipts) > 0 else "warning"} />
                    <FactRow icon={<UserRound size={18} />} label="Responder acknowledgement" value="Unknown" tone="warning" />
                    <FactRow icon={<CircleCheck size={18} />} label="Rescue outcome" value="Unknown" tone="warning" />
                    <div className="proof-boundary compact">
                        <ShieldCheck size={18} /><p>Each state is evidence-scoped. A later state is never inferred from an earlier one.</p>
                    </div>
                </section>

                <section className="section-band">
                    <div className="section-title">
                        <div><span>LOCAL LEDGER</span><h2>Packet history</h2></div>
                        <Database size={21} />
                    </div>
                    {if len(packets) == 0 {
                        <div key="empty-history" className="empty-state">
                            <Database size={26} /><strong>No packet history</strong><span>Created and relayed packets appear here.</span>
                        </div>
                    }}
                    {for packet in packets {
                        <PacketRow key={"history-" + packet.unique_id()} packet={packet} now={now} />
                    }}
                </section>
                </div>
            }}

            {if active_tab == "systems" {
                <div key="systems-panel" className={"tab-panel systems-" + systems_view}>
                <section className="page-heading">
                    <div><h1>Systems</h1></div>
                    <SlidersHorizontal size={23} />
                </section>

                <div className="mode-switch four" role="tablist" aria-label="Systems view">
                    <button className={"active" if systems_view == "radio" else ""} onClick={lambda { systems_view = "radio"; }}>RADIO</button>
                    <button className={"active" if systems_view == "sync" else ""} onClick={lambda { systems_view = "sync"; }}>SYNC</button>
                    <button className={"active" if systems_view == "proof" else ""} onClick={lambda { systems_view = "proof"; }}>PROOF</button>
                    <button className={"active" if systems_view == "storage" else ""} onClick={lambda { systems_view = "storage"; }}>STORAGE</button>
                </div>

                <section className="section-band mode-default">
                    <div className="section-title">
                        <div><h2>Device</h2></div>
                        <Smartphone size={21} />
                    </div>
                    <FactRow icon={<Bluetooth size={18} />} label="BLE permission" value={ble_permission} tone={"safe" if ble_permission == "granted" else "warning"} />
                    <FactRow icon={<Bell size={18} />} label="Notifications" value={notification_permission} tone={"safe" if notification_permission == "granted" else "warning"} />
                    <FactRow icon={<Sparkles size={18} />} label="On-device AI" value={foundation_status.availability} tone={"safe" if foundation_status.available else "warning"} />
                    <FactRow icon={<Activity size={18} />} label="Mesh" value={mesh_state} tone={"safe" if mesh_state == "active" else "warning"} />
                </section>

                <section className="setting-band mode-default">
                    <div className="setting-copy">
                        <LockKeyhole size={20} />
                        <div><span>PRIVACY BRIDGE</span><strong>{privacy_mode}</strong></div>
                    </div>
                    <div className="segmented-control">
                        <button className={"active" if privacy_mode == "Local Only" else ""} onClick={lambda { choose_privacy("Local Only"); }}>LOCAL</button>
                        <button className={"active" if privacy_mode == "Relay Only" else ""} onClick={lambda { choose_privacy("Relay Only"); }}>RELAY</button>
                        <button className={"active" if privacy_mode == "Cloud Bridge" else ""} onClick={lambda { choose_privacy("Cloud Bridge"); }}>CLOUD</button>
                    </div>
                </section>

                <section className="setting-band mode-default">
                    <div className="setting-copy">
                        <BatteryMedium size={20} />
                        <div><span>BATTERY PROFILE</span><strong>{battery_mode}</strong></div>
                    </div>
                    <div className="segmented-control">
                        <button className={"active" if battery_mode == "SOS Active" else ""} onClick={lambda { choose_battery("SOS Active"); }}>SOS</button>
                        <button className={"active" if battery_mode == "Bridge" else ""} onClick={lambda { choose_battery("Bridge"); }}>BRIDGE</button>
                        <button className={"active" if battery_mode == "Battery Saver" else ""} onClick={lambda { choose_battery("Battery Saver"); }}>SAVER</button>
                    </div>
                </section>

                <section className="section-band mode-panel mode-sync">
                    <div className="section-title">
                        <div><span>PRIVACY-GATED BRIDGE</span><h2>Cloud sync</h2></div>
                        <Cloud size={21} />
                    </div>
                    <div className="metric-grid compact-metrics">
                        <Metric label="QUEUED" value={str(queue.queued)} detail="unsynced packets" />
                        <Metric label="ELIGIBLE" value={str(queue.eligible)} detail="policy allows" />
                        <Metric label="RECEIPTS" value={str(len(sync_receipts))} detail="local evidence" />
                    </div>
                    {for blocker in queue.blockers {
                        <div key={blocker} className="evidence-line warning"><LockKeyhole size={16} /><span>{blocker}</span></div>
                    }}
                    <button className="secondary-command" onClick={run_cloud_sync} disabled={busy}>
                        <UploadCloud size={17} /> {"SYNCING…" if busy and sync_state == "checking" else "SYNC RELAYED PACKETS"}
                    </button>
                    <small className="boundary-copy">Originated distress packets remain local; cloud upload is limited to packets this device relayed, matching the original safety rule.</small>
                </section>

                <section className="section-band mode-panel mode-sync">
                    <div className="section-title">
                        <div><span>ATTEMPT LEDGER</span><h2>Recent sync evidence</h2></div>
                        <Database size={21} />
                    </div>
                    {if len(sync_attempts) == 0 {
                        <p key="empty-sync-ledger" className="muted-copy">No cloud sync attempt has been recorded.</p>
                    }}
                    {for item in sync_attempts[:12] {
                        <div key={str(item["attemptId"])} className="ledger-row">
                            <span className={"ledger-state " + str(item["status"])}></span>
                            <div><strong>{str(item["status"]).upper()}</strong><p>{str(item["message"])}</p></div>
                            <small>{str(item["pending"]) + " queued"}</small>
                        </div>
                    }}
                </section>

                <section className="section-band mode-panel mode-proof">
                    <div className="section-title">
                        <div><span>CONFORMANCE</span><h2>Verification state</h2></div>
                        <ShieldCheck size={21} />
                    </div>
                    <FactRow icon={<Check size={18} />} label="Jac client source" value="Build verified" tone="safe" />
                    <FactRow icon={<Bluetooth size={18} />} label="Native BLE plugin" value={plugin_version} tone={"safe" if plugin_version != "unavailable" else "warning"} />
                    <FactRow icon={<Gauge size={18} />} label="Trust score" value={str(trust["score"]) + "/100"} />
                    <FactRow icon={<ShieldCheck size={18} />} label="Physical proof" value={"Captured" if bool(trust["physicalProof"]) else "Not captured"} tone="warning" />
                    {for fact in reconciliation.facts {
                        <div key={fact} className="evidence-line"><Check size={16} /><span>{fact}</span></div>
                    }}
                    {for warning in reconciliation.warnings {
                        <div key={warning} className="evidence-line warning"><TriangleAlert size={16} /><span>{warning}</span></div>
                    }}
                    <div className="proof-boundary compact">
                        <ShieldCheck size={18} /><p>{str(trust["unknown"])}</p>
                    </div>
                </section>

                <section className="section-band mode-panel mode-storage">
                    <div className="section-title">
                        <div><span>DEVICE-LOCAL DATA</span><h2>Retention</h2></div>
                        <Database size={21} />
                    </div>
                    <FactRow icon={<Radio size={18} />} label="Packet records" value={str(len(packets))} />
                    <FactRow icon={<Cloud size={18} />} label="Sync attempts" value={str(len(sync_attempts))} />
                    <FactRow icon={<Check size={18} />} label="Receipts" value={str(len(sync_receipts))} />
                    <FactRow icon={<ListChecks size={18} />} label="Adjudications" value={str(len(adjudications))} />
                    <button className="destructive-command" onClick={erase_packet_history}>
                        <Trash2 size={18} /> CLEAR PACKET HISTORY
                    </button>
                    <button className="destructive-command subdued" onClick={erase_operational_ledgers}>
                        <Trash2 size={18} /> CLEAR OPERATIONAL LEDGERS
                    </button>
                </section>
                </div>
            }}
        </main>

        <nav className="bottom-nav" aria-label="Primary">
            <button id="nav-command" title="Command" aria-label="Command" className={"active" if active_tab == "command" else ""} onClick={lambda { active_tab = "command"; }}>
                <Radio size={20} /><span>COMMAND</span>
            </button>
            <button id="nav-map" title="Map" aria-label="Map" className={"active" if active_tab == "map" else ""} onClick={lambda { active_tab = "map"; }}>
                <MapIcon size={20} /><span>MAP</span>
            </button>
            <button id="nav-tools" title="Tools" aria-label="Tools" className={"active" if active_tab == "tools" else ""} onClick={lambda { active_tab = "tools"; }}>
                <Wrench size={20} /><span>TOOLS</span>
            </button>
            <button id="nav-sos" title="Distress" aria-label="Distress" className={"active distress" if active_tab == "sos" else "distress"} onClick={lambda { active_tab = "sos"; }}>
                <Siren size={21} /><span>DISTRESS</span>
            </button>
            <button id="nav-systems" title="Systems" aria-label="Systems" className={"active" if active_tab == "systems" else ""} onClick={lambda { active_tab = "systems"; }}>
                <SlidersHorizontal size={20} /><span>SYSTEMS</span>
            </button>
        </nav>
    </div>;
}
