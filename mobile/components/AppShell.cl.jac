"""SafeRelay mobile operator shell."""

import from "react" { useEffect }
import from "lucide-react" {
    Activity,
    BatteryMedium,
    Bell,
    Bluetooth,
    Check,
    ChevronDown,
    Compass,
    Copy,
    Database,
    Download,
    Flashlight,
    HeartPulse,
    Headphones,
    MessageCircle,
    Send,
    Sparkles,
    LockKeyhole,
    Map as MapIcon,
    MapPin,
    PackageOpen,
    Play,
    Radio,
    RefreshCw,
    ShieldCheck,
    Siren,
    SlidersHorizontal,
    Smartphone,
    Square,
    UploadCloud,
    Trash2,
    TriangleAlert,
    Volume2,
    Wrench
}
import from ..domain.protocol {
    ClientSosPacket as SosPacket,
    client_active_foreign_distress as active_foreign_distress,
    client_contains_packet as contains_packet,
    client_create_packet as create_packet,
    client_evaluate_relay as evaluate_relay,
    client_packet_from_bytes as packet_from_bytes,
    client_packet_to_bytes as packet_to_bytes,
    client_replace_packet as replace_packet,
    client_status_color as status_color,
    client_status_description as status_description,
    client_status_label as status_label
}
import from ..domain.operations {
    ClientOperationalReport,
    ClientSurvivalChatMessage,
    client_assess_cloud_queue as assess_cloud_queue,
    client_field_brief as field_brief
}
import from ..services.field {
    cache_map_region,
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
    register_notification_observers,
    request_notification_permission,
    resume_saved_mesh,
    set_mesh_event_sink,
    set_torch,
    start_mesh,
    stop_mesh,
    test_distress_notification,
    unix_seconds
}
import from ..services.storage {
    BATTERY_KEY,
    PRIVACY_KEY,
    SYNC_ATTEMPTS_KEY,
    SYNC_RECEIPTS_KEY,
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
import from .IncidentMap { IncidentMap }

glob _window: any = window;  # jac:ignore[W1037, W2001]


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
    has expanded: bool = False;
    age = max(0, packet.age_seconds(now));
    age_label = str(age) + "s ago" if age < 60 else str(age // 60) + "m ago";
    detail_id = "packet-details-" + packet.unique_id();
    return <article className={"packet-row expanded" if expanded else "packet-row"}>
        <button
            className="packet-row-trigger"
            aria-expanded={expanded}
            aria-controls={detail_id}
            onClick={lambda { expanded = not expanded; }}
        >
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
            <ChevronDown className="packet-disclosure" size={18} />
        </button>
        {if expanded {
            <div id={detail_id} className="packet-expanded">
                <div>
                    <span>POSITION</span>
                    <strong>{f"{packet.latitude():.5f}, {packet.longitude():.5f}"}</strong>
                </div>
                <div>
                    <span>RELAY PATH</span>
                    <strong>{str(packet.relay_hops) + (" hop" if packet.relay_hops == 1 else " hops")}</strong>
                </div>
                <p>Local packet evidence. Responder receipt and rescue outcome remain unknown.</p>
            </div>
        }}
    </article>;
}


def:pub AppShell -> JsxElement {
    has booting: bool = True;
    has onboarding_done: bool = False;
    has active_tab: str = "home";
    has tools_view: str = "guide";
    has user_id: int = 0;
    has packets: list[SosPacket] = [];
    has mesh_state: str = "idle";
    has mesh_message: str = "Mesh relay has not been started.";
    has plugin_version: str = "unavailable";
    has platform_name: str = "web";
    has ble_permission: str = "unavailable";
    has notification_permission: str = "unavailable";
    has network_state: str = "unknown";
    has background_state: str = "unknown";
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
    has sync_attempts: list[dict[str, object]] = [];
    has sync_receipts: list[dict[str, object]] = [];
    has sync_state: str = "idle";
    has internet_failures: int = 0;
    has offline_tiles: int = 0;
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
        background_state = readiness.background_state;
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
        if kind == "notificationAction" {
            active_tab = "map";
            return;
        }
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
        notification_state = await request_notification_permission();
        notification_permission = notification_state.permission;
        alert_message = (
            "Device setup saved. Start the mesh when you are ready."
            if notification_state.permission == "granted"
            else notification_state.message
        );
        alert_tone = (
            "success"
            if notification_state.permission == "granted"
            else "warning"
        );
    }

    async def send_notification_test {
        busy = True;
        result = await test_distress_notification();
        notification_permission = result.permission;
        alert_message = result.message;
        alert_tone = "success" if result.scheduled else "warning";
        append_log(result.message);
        busy = False;
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
        alert_message = "Local sync history cleared from this device.";
        alert_tone = "neutral";
    }

    async def refresh_operational_ledgers {
        sync_attempts = await load_records(SYNC_ATTEMPTS_KEY);
        sync_receipts = await load_records(SYNC_RECEIPTS_KEY);
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
        await register_notification_observers();
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
        return lambda {
            clearInterval(reachability_timer);
        };
    }, [mesh_state, platform_name]);

    useEffect(lambda {
        transcript: any = document.querySelector(".survival-transcript");  # jac:ignore[W1037]
        if transcript {
            transcript.scrollTop = transcript.scrollHeight;
        }
    }, [survival_chat, survival_sending, tools_view]);

    useEffect(lambda {
        window.scrollTo(0, 0);  # jac:ignore[W2001]
    }, [active_tab]);

    now = unix_seconds();
    foreign_distress = active_foreign_distress(packets, user_id, now);
    urgent_count = len(foreign_distress);
    distress_age = (
        max(0, foreign_distress[0].age_seconds(now))
        if urgent_count > 0 else 0
    );
    distress_age_label = (
        str(distress_age) + "s ago"
        if distress_age < 60
        else str(distress_age // 60) + "m ago"
    );
    brief: ClientOperationalReport = field_brief(
        packets,
        now,
        network_state != "offline",
        False
    );
    queue = assess_cloud_queue(
        packets,
        network_state != "offline",
        privacy_mode,
        True
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

        {if urgent_count > 0 {
            <section
                className="distress-presence"
                role="alert"
                aria-live="assertive"
                aria-atomic="true"
            >
                <span className="distress-presence-icon">
                    <Siren size={25} />
                </span>
                <div className="distress-presence-copy">
                    <span>SOMEONE ELSE NEEDS HELP</span>
                    <strong>
                        {status_label(foreign_distress[0].status_code)}
                        {" · " + status_description(foreign_distress[0].status_code)}
                    </strong>
                    <small>
                        {"Node " + str(foreign_distress[0].user_id)[-6:]
                        + " · " + distress_age_label
                        + (" · 1 active report" if urgent_count == 1 else " · " + str(urgent_count) + " active reports")}
                    </small>
                </div>
                <button
                    className="distress-presence-action"
                    onClick={lambda { active_tab = "map"; }}
                    title="View distress reports on map"
                    aria-label="View distress reports on map"
                >
                    <MapPin size={20} />
                    <span>VIEW</span>
                </button>
            </section>
        }}

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
            {if active_tab == "home" {
                <div key="home-panel" className="tab-panel home-panel">
                    <section className="home-heading">
                        <div>
                            <span>FIELD RELAY</span>
                            <h1>{"Mesh is active" if mesh_state == "active" else "Stay reachable"}</h1>
                            <p>{mesh_message}</p>
                        </div>
                        <button
                            className={"relay-power active" if mesh_state == "active" else "relay-power"}
                            title={"Stop mesh relay" if mesh_state == "active" else "Start mesh relay"}
                            aria-label={"Stop mesh relay" if mesh_state == "active" else "Start mesh relay"}
                            onClick={toggle_mesh}
                            disabled={busy}
                        >
                            {<Square size={23} /> if mesh_state == "active" else <Play size={23} />}
                        </button>
                    </section>

                    <section className="home-status" aria-label="Field status">
                        <button onClick={lambda { active_tab = "map"; }}>
                            <span>NEARBY</span>
                            <strong>{str(urgent_count)}</strong>
                            <small>{"active report" if urgent_count == 1 else "active reports"}</small>
                        </button>
                        <button onClick={refresh_location}>
                            <span>POSITION</span>
                            <strong>{"READY" if location_ready else "OFF"}</strong>
                            <small>{f"±{location_accuracy:.0f} m" if location_ready else "tap to acquire"}</small>
                        </button>
                        <button onClick={lambda { active_tab = "settings"; }}>
                            <span>NETWORK</span>
                            <strong>{network_state.upper()}</strong>
                            <small>{privacy_mode}</small>
                        </button>
                    </section>

                    <section className="home-reports">
                        <div className="section-title compact">
                            <div><span>LOCAL RADIO</span><h2>Nearby reports</h2></div>
                            <Radio size={20} />
                        </div>
                        {if len(packets) == 0 {
                            <div key="empty-packets" className="home-empty">
                                <Radio size={25} />
                                <div><strong>No nearby reports</strong><span>Listening continues while the mesh is active.</span></div>
                            </div>
                        } else {
                            <div className="packet-list">
                                {for packet in packets[:3] {
                                    <PacketRow key={packet.unique_id()} packet={packet} now={now} />
                                }}
                            </div>
                        }}
                    </section>

                    <section className="home-shortcuts" aria-label="Quick actions">
                        <button onClick={lambda { active_tab = "map"; }}>
                            <MapIcon size={21} />
                            <span><strong>Open map</strong><small>Reports and your position</small></span>
                        </button>
                        <button onClick={lambda { active_tab = "tools"; }}>
                            <Wrench size={21} />
                            <span><strong>Field tools</strong><small>Guide, compass, beacon</small></span>
                        </button>
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
                        location_message={location_message}
                        on_locate={refresh_location}
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
                    <button id="tool-guide" role="tab" aria-selected={tools_view == "guide"} className={"active" if tools_view == "guide" else ""} onClick={lambda { tools_view = "guide"; }}>GUIDE</button>
                    <button id="tool-compass" role="tab" aria-selected={tools_view == "compass"} className={"active" if tools_view == "compass" else ""} onClick={enable_compass}>COMPASS</button>
                    <button id="tool-beacon" role="tab" aria-selected={tools_view == "strobe"} className={"active" if tools_view == "strobe" else ""} onClick={lambda { tools_view = "strobe"; }}>BEACON</button>
                    <button id="tool-sonic" role="tab" aria-selected={tools_view == "ultrasonic"} className={"active" if tools_view == "ultrasonic" else ""} onClick={lambda { tools_view = "ultrasonic"; }}>SONIC</button>
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
                        <button className="survival-send" title="Send message" aria-label="Send message" onClick={lambda { send_survival_message(brief.facts + brief.warnings + brief.unknowns); }} disabled={survival_sending or not survival_input.strip()}>
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

                <section
                    className={"status-selector sos-type-switch status-" + str(selected_status)}
                    role="radiogroup"
                    aria-label="Emergency type"
                    aria-orientation="horizontal"
                >
                    <button
                        id="sos-rescue"
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
                        id="sos-medical"
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
                        id="sos-trapped"
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
                        id="sos-supplies"
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

                <section className="distress-state">
                    <span className={"active" if mesh_state == "active" else ""}></span>
                    <div>
                        <strong>{"Radio ready" if mesh_state == "active" else "Radio is off"}</strong>
                        <small>{"The packet will be stored locally and broadcast over the mesh." if mesh_state == "active" else "Start the mesh from Home before sending when possible."}</small>
                    </div>
                </section>
                </div>
            }}

            {if active_tab == "settings" {
                <div key="settings-panel" className="tab-panel settings-panel">
                <section className="page-heading">
                    <div><h1>Settings</h1></div>
                    <SlidersHorizontal size={23} />
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>CONNECTIVITY</span>
                    </div>
                    <div className="settings-row">
                        <span className={"settings-icon safe" if mesh_state == "active" else "settings-icon"}><Radio size={19} /></span>
                        <div><strong>Mesh relay</strong><small>{mesh_message}</small></div>
                        <button className={"settings-toggle on" if mesh_state == "active" else "settings-toggle"} onClick={toggle_mesh} disabled={busy} aria-label={"Stop mesh relay" if mesh_state == "active" else "Start mesh relay"}><span></span></button>
                    </div>
                    <button className="settings-row settings-row-button" onClick={refresh_readiness}>
                        <span className="settings-icon"><RefreshCw size={19} /></span>
                        <div><strong>Refresh device status</strong><small>Bluetooth, notifications, and background refresh</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>RELAY PREFERENCES</span>
                    </div>
                    <div className="settings-choice">
                        <div className="settings-choice-copy"><LockKeyhole size={19} /><div><strong>Privacy bridge</strong><small>{privacy_mode}</small></div></div>
                        <div className="segmented-control glass-slider-three" role="radiogroup" aria-label="Privacy bridge">
                            <button role="radio" aria-checked={privacy_mode == "Local Only"} className={"active" if privacy_mode == "Local Only" else ""} onClick={lambda { choose_privacy("Local Only"); }}>LOCAL</button>
                            <button role="radio" aria-checked={privacy_mode == "Relay Only"} className={"active" if privacy_mode == "Relay Only" else ""} onClick={lambda { choose_privacy("Relay Only"); }}>RELAY</button>
                            <button role="radio" aria-checked={privacy_mode == "Cloud Bridge"} className={"active" if privacy_mode == "Cloud Bridge" else ""} onClick={lambda { choose_privacy("Cloud Bridge"); }}>CLOUD</button>
                        </div>
                    </div>
                    <div className="settings-choice">
                        <div className="settings-choice-copy"><BatteryMedium size={19} /><div><strong>Battery profile</strong><small>{battery_mode}</small></div></div>
                        <div className="segmented-control glass-slider-three" role="radiogroup" aria-label="Battery profile">
                            <button role="radio" aria-checked={battery_mode == "SOS Active"} className={"active" if battery_mode == "SOS Active" else ""} onClick={lambda { choose_battery("SOS Active"); }}>SOS</button>
                            <button role="radio" aria-checked={battery_mode == "Bridge"} className={"active" if battery_mode == "Bridge" else ""} onClick={lambda { choose_battery("Bridge"); }}>BRIDGE</button>
                            <button role="radio" aria-checked={battery_mode == "Battery Saver"} className={"active" if battery_mode == "Battery Saver" else ""} onClick={lambda { choose_battery("Battery Saver"); }}>SAVER</button>
                        </div>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>OFFLINE DATA</span>
                    </div>
                    <button className="settings-row settings-row-button" onClick={download_local_map} disabled={busy}>
                        <span className="settings-icon"><Download size={19} /></span>
                        <div><strong>Offline map</strong><small>{str(offline_tiles) + " tiles cached" if offline_tiles > 0 else "Download around your current position"}</small></div>
                    </button>
                    <button className="settings-row settings-row-button" onClick={run_cloud_sync} disabled={busy}>
                        <span className="settings-icon"><UploadCloud size={19} /></span>
                        <div><strong>Sync relayed packets</strong><small>{str(queue.queued) + " queued · " + str(len(sync_receipts)) + " receipts"}</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>DEVICE</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Bluetooth size={19} /></span>
                        <div><strong>Bluetooth</strong><small>{ble_permission}</small></div>
                        <span className={"status-dot ready" if ble_permission == "granted" else "status-dot"}></span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Bell size={19} /></span>
                        <div><strong>Notifications</strong><small>{notification_permission}</small></div>
                        <span className={"status-dot ready" if notification_permission == "granted" else "status-dot"}></span>
                    </div>
                    <button className="settings-row settings-row-button" onClick={send_notification_test} disabled={busy}>
                        <span className="settings-icon"><Bell size={19} /></span>
                        <div><strong>Test distress notification</strong><small>Banner, sound, and Notification Center</small></div>
                    </button>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Activity size={19} /></span>
                        <div><strong>Background refresh</strong><small>{background_state}</small></div>
                        <span className={"status-dot ready" if background_state == "available" else "status-dot"}></span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Sparkles size={19} /></span>
                        <div><strong>On-device guide</strong><small>{foundation_status.availability}</small></div>
                        <span className={"status-dot ready" if foundation_status.available else "status-dot"}></span>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>STORAGE</span>
                    </div>
                    <button className="settings-row settings-row-button destructive" onClick={erase_packet_history}>
                        <span className="settings-icon"><Trash2 size={19} /></span>
                        <div><strong>Clear packet history</strong><small>{str(len(packets)) + " records on this device"}</small></div>
                    </button>
                    <button className="settings-row settings-row-button destructive" onClick={erase_operational_ledgers}>
                        <span className="settings-icon"><Database size={19} /></span>
                        <div><strong>Clear sync history</strong><small>{str(len(sync_attempts) + len(sync_receipts)) + " local records"}</small></div>
                    </button>
                </section>

                <section className="settings-about">
                    <Smartphone size={18} />
                    <span>{"SafeRelay · " + platform_name + " · " + plugin_version}</span>
                </section>
                </div>
            }}
        </main>

        <nav className="bottom-nav" aria-label="Primary">
            <button id="nav-home" title="Home" aria-label="Home" className={"active" if active_tab == "home" else ""} onClick={lambda { active_tab = "home"; }}>
                <Radio size={20} /><span>HOME</span>
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
            <button id="nav-settings" title="Settings" aria-label="Settings" className={"active" if active_tab == "settings" else ""} onClick={lambda { active_tab = "settings"; }}>
                <SlidersHorizontal size={20} /><span>SETTINGS</span>
            </button>
        </nav>
    </div>;
}
