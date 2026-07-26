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
    Map as MapIcon,
    MapPin,
    PackageOpen,
    Radio,
    RefreshCw,
    ShieldCheck,
    Siren,
    SlidersHorizontal,
    Smartphone,
    UploadCloud,
    Trash2,
    TriangleAlert,
    Volume2,
    Wrench,
    X
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
    clear_cached_map_region,
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
    PacketPublishState,
    clear_mesh_event_sink,
    current_location,
    emergency_haptic,
    inspect_native_readiness,
    mesh_is_running,
    native_platform,
    notify_incoming,
    open_native_settings,
    publish_packet,
    publish_packet_state,
    register_app_state_observer,
    register_network_observer,
    register_notification_observers,
    request_notification_permission,
    set_mesh_event_sink,
    set_torch,
    start_compass,
    start_mesh,
    stop_compass,
    test_distress_notification,
    unix_seconds
}
import from ..services.storage {
    AUTO_DOWNLOAD_MAPS_KEY,
    BATTERY_KEY,
    NOTIFICATIONS_KEY,
    SYNC_ATTEMPTS_KEY,
    SYNC_RECEIPTS_KEY,
    THEME_KEY,
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
    reset_onboarding,
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
    has cloud_configured: bool = False;
    has cloud_message: str = "Jac cloud relay has not been checked.";
    has background_state: str = "unknown";
    has location_ready: bool = False;
    has latitude: float = 0.0;
    has longitude: float = 0.0;
    has location_accuracy: float = 0.0;
    has location_message: str = "Location not sampled.";
    has selected_status: int = 1;
    has distress_armed: bool = False;
    has distress_sending: bool = False;
    has distress_stage: str = "idle";
    has distress_message: str = "Ready to create a device-local emergency packet.";
    has distress_packet_id: str = "";
    has distress_saved: bool = False;
    has distress_radio_accepted: bool = False;
    has distress_peer_count: int = 0;
    has distress_pulse_nonce: int = 0;
    has battery_mode: str = "Bridge";
    has theme_mode: str = "System";
    has auto_download_maps: bool = True;
    has show_notifications: bool = True;
    has alert_message: str = "";
    has alert_tone: str = "neutral";
    has alert_dismissing: bool = False;
    has alert_nonce: int = 0;
    has distress_notice_id: str = "";
    has distress_notice_timer: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has map_focus_packet_id: str = "";
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
    has heading_accuracy: float = -1.0;
    has compass_active: bool = False;
    has compass_status: str = "Compass starts automatically when selected.";
    has strobe_timer: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has strobe_phase: Ref[bool] = Ref(False);

    async def refresh_readiness {
        readiness: NativeReadiness = await inspect_native_readiness();
        platform_name = readiness.platform;
        ble_permission = readiness.ble_permission;
        notification_permission = readiness.notification_permission;
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
            show_alert(
                "Survival Guide unavailable: " + result.availability,
                "warning"
            );
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
            show_alert("Guide reply copied.", "neutral");
        } except Exception {
            show_alert("Could not copy the guide reply.", "warning");
        }
    }

    async def erase_survival_chat {
        await clear_survival_chat_history();
        survival_chat = [];
        survival_input = "";
        show_alert("Local Survival Guide history cleared.", "neutral");
    }

    def append_log(message: str) {
        activity_log = [message] + activity_log[:7];
    }

    def show_alert(message: str, tone: str) {
        if tone != "warning" and tone != "danger" { return; }
        alert_message = message;
        alert_tone = tone;
        alert_dismissing = False;
        alert_nonce += 1;
    }

    def dismiss_alert {
        if alert_dismissing { return; }
        dismiss_nonce = alert_nonce;
        alert_dismissing = True;
        setTimeout(lambda {
            if alert_nonce == dismiss_nonce {
                alert_message = "";
                alert_dismissing = False;
            }
        }, 220);
    }

    def show_distress_notice(packet_id: str) {
        if distress_notice_timer.current {
            clearTimeout(distress_notice_timer.current);
        }
        distress_notice_id = packet_id;
        notice_id = packet_id;
        distress_notice_timer.current = setTimeout(lambda {
            if distress_notice_id == notice_id {
                distress_notice_id = "";
            }
            distress_notice_timer.current = None;
        }, 8000);
    }

    def view_distress_notice(packet_id: str) {
        if distress_notice_timer.current {
            clearTimeout(distress_notice_timer.current);
            distress_notice_timer.current = None;
        }
        distress_notice_id = "";
        map_focus_packet_id = packet_id;
        active_tab = "map";
    }

    async def handle_mesh_event(event: any) {  # jac:ignore[W1037]
        kind = str(event["kind"]);
        message = str(event["message"]);
        append_log(message);
        if kind == "lifecycle" {
            lifecycle_data = event["data"] as dict[str, object];
            if lifecycle_data["isActive"] as bool {
                await ensure_mesh_active();
                await refresh_readiness();
                await sync_cloud(False);
            }
            return;
        }
        if kind == "network" {
            network_data = event["data"] as dict[str, object];
            if network_data["connected"] as bool {
                network_state = "checking";
                await sync_cloud(False);
            } else {
                network_state = "offline";
                cloud_message = "Jac cloud relay is unreachable; packets remain queued locally.";
            }
            return;
        }
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
                show_distress_notice(packet.unique_id());
                await emergency_haptic();
                if show_notifications {
                    await notify_incoming(
                        packet.user_id + packet.sequence,
                        "SafeRelay " + status_label(packet.status_code),
                        "Nearby packet " + packet.unique_id() + ". Reported, not responder-confirmed."
                    );
                }
            }

            relay = evaluate_relay(
                packet,
                now,
                "Automatic",
                battery_mode,
                len(updated)
            );
            append_log(relay.decision.upper() + ": " + relay.reason);
            if relay.should_relay() {
                await publish_packet(packet_to_bytes(packet));
            }
            await sync_cloud(False);
        } except Exception as error {
            append_log("Rejected malformed radio packet: " + str(error));
        }
    }

    async def ensure_mesh_active {
        if mesh_is_running() {
            mesh_state = "active";
            return;
        }
        busy = True;
        result = await start_mesh();
        mesh_state = result.state;
        mesh_message = result.message;
        platform_name = result.platform;
        plugin_version = result.plugin_version;
        append_log(result.message);
        busy = False;
        await refresh_readiness();
    }

    async def refresh_location {
        busy = True;
        try {
            fix = await current_location();
            location_ready = fix.ready;
            latitude = fix.latitude;
            longitude = fix.longitude;
            location_accuracy = fix.accuracy;
            location_message = fix.message;
            if not fix.ready {
                show_alert(fix.message, "warning");
            }
        } except Exception as error {
            location_ready = False;
            location_message = "Location failed: " + str(error);
            show_alert(location_message, "warning");
        } finally {
            busy = False;
        }
    }

    def choose_distress_status(status: int) {
        if distress_sending { return; }
        selected_status = status;
        distress_armed = False;
        distress_stage = "idle";
        distress_message = "Ready to create a device-local emergency packet.";
        distress_packet_id = "";
        distress_saved = False;
        distress_radio_accepted = False;
        distress_peer_count = 0;
    }

    async def send_selected_status {
        distress_pulse_nonce += 1;
        if distress_sending { return; }

        if not distress_armed {
            distress_armed = True;
            distress_stage = "armed";
            distress_message = (
                status_label(selected_status)
                + " is armed. Tap the pulsing SOS button again to send."
            );
            show_alert(
                "Distress action armed. Tap SOS again to send the radio packet.",
                "warning"
            );
            await emergency_haptic();
            if not location_ready {
                distress_sending = True;
                distress_stage = "locating";
                distress_message = "Armed. Acquiring the packet position now.";
                try {
                    fix = await current_location();
                    location_ready = fix.ready;
                    latitude = fix.latitude;
                    longitude = fix.longitude;
                    location_accuracy = fix.accuracy;
                    location_message = fix.message;
                    distress_stage = "armed" if fix.ready else "blocked";
                    distress_message = (
                        "Position acquired. Tap SOS again to save and broadcast."
                        if fix.ready
                        else "Position is required before sending. " + fix.message
                    );
                    if not fix.ready {
                        show_alert(distress_message, "danger");
                    }
                } except Exception as error {
                    location_ready = False;
                    location_message = "Location failed: " + str(error);
                    distress_stage = "blocked";
                    distress_message = (
                        "Position is required before sending. " + location_message
                    );
                    show_alert(distress_message, "danger");
                } finally {
                    distress_sending = False;
                }
            }
            return;
        }

        status_to_send = selected_status;
        distress_sending = True;
        distress_saved = False;
        distress_radio_accepted = False;
        distress_peer_count = 0;
        try {
            if not location_ready {
                distress_stage = "locating";
                distress_message = "Acquiring a current position before packet creation.";
                fix = await current_location();
                location_ready = fix.ready;
                latitude = fix.latitude;
                longitude = fix.longitude;
                location_accuracy = fix.accuracy;
                location_message = fix.message;
            }
            if not location_ready {
                distress_stage = "blocked";
                distress_message = (
                    "Packet was not created. A current position is required. "
                    + location_message
                );
                show_alert(distress_message, "danger");
                return;
            }

            distress_stage = "saving";
            distress_message = "Creating and saving the emergency packet on this device.";
            sequence = await next_sequence();
            packet = create_packet(
                user_id,
                sequence,
                latitude,
                longitude,
                status_to_send,
                unix_seconds()
            );
            distress_packet_id = packet.unique_id();
            updated = replace_packet(packets, packet);
            await save_packets(updated);
            packets = updated;
            distress_saved = True;

            distress_stage = "starting-radio";
            distress_message = "Packet saved. Checking the native Bluetooth relay.";
            if not mesh_is_running() {
                mesh_result = await start_mesh();
                mesh_state = mesh_result.state;
                mesh_message = mesh_result.message;
                platform_name = mesh_result.platform;
                plugin_version = mesh_result.plugin_version;
                append_log(mesh_result.message);
            }

            distress_stage = "broadcasting";
            distress_message = "Packet saved. Handing it to the native Bluetooth relay.";
            publish: PacketPublishState = await publish_packet_state(
                packet_to_bytes(packet)
            );
            distress_radio_accepted = publish.accepted;
            distress_peer_count = publish.connected_peers;
            distress_armed = False;
            if publish.accepted {
                distress_stage = "accepted";
                distress_message = (
                    "Saved on device and accepted by the radio with "
                    + str(publish.connected_peers)
                    + (
                        " current peer link. Peer receipt is not yet confirmed."
                        if publish.connected_peers == 1
                        else " current peer links. Peer receipt is not yet confirmed."
                    )
                );
            } else {
                distress_stage = "queued";
                distress_message = (
                    "Saved on device, but radio handoff was not accepted. "
                    + publish.message
                    + " SafeRelay will retain the packet for retry."
                );
            }
            show_alert(
                distress_message,
                "danger" if status_to_send != 0 else "success"
            );
            append_log(
                status_label(status_to_send)
                + " "
                + distress_packet_id
                + ": "
                + distress_message
            );
            await emergency_haptic();
            try {
                await sync_cloud(False);
            } except Exception as sync_error {
                append_log(
                    "Cloud sync deferred after "
                    + distress_packet_id
                    + ": "
                    + str(sync_error)
                );
            }
        } except Exception as error {
            if distress_saved {
                distress_armed = False;
                distress_stage = "queued";
                distress_message = (
                    "Packet "
                    + distress_packet_id
                    + " is saved on this device. Radio handoff failed: "
                    + str(error)
                );
            } else {
                distress_armed = True;
                distress_stage = "failed";
                distress_message = (
                    "Packet could not be saved. Tap again to retry: " + str(error)
                );
            }
            show_alert(distress_message, "danger");
            append_log(distress_message);
        } finally {
            distress_sending = False;
        }
    }

    async def choose_battery(mode: str) {
        battery_mode = mode;
        await save_setting(BATTERY_KEY, mode);
        append_log("Battery mode changed to " + mode);
    }

    async def choose_theme(mode: str) {
        theme_mode = mode;
        await save_setting(THEME_KEY, mode);
        document.documentElement.style.setProperty("color-scheme", (
            "light" if mode == "Light"
            else "dark" if mode == "Dark"
            else "light dark"
        ));  # jac:ignore[W2001]
    }

    async def toggle_auto_download_maps {
        auto_download_maps = not auto_download_maps;
        await save_setting(
            AUTO_DOWNLOAD_MAPS_KEY,
            "true" if auto_download_maps else "false"
        );
    }

    async def toggle_show_notifications {
        show_notifications = not show_notifications;
        await save_setting(
            NOTIFICATIONS_KEY,
            "true" if show_notifications else "false"
        );
        if show_notifications and notification_permission != "granted" {
            state = await request_notification_permission();
            notification_permission = state.permission;
            show_alert(
                state.message,
                "success" if state.permission == "granted" else "warning"
            );
        }
    }

    async def clear_offline_map_cache {
        cleared = await clear_cached_map_region();
        offline_tiles = 0;
        show_alert(
            "Offline map cache cleared." if cleared
            else "No offline map cache was stored.",
            "neutral"
        );
    }

    async def redo_onboarding {
        await reset_onboarding();
        onboarding_done = False;
    }

    async def finish_onboarding {
        await complete_onboarding();
        onboarding_done = True;
        notification_state = await request_notification_permission();
        notification_permission = notification_state.permission;
        show_alert(
            (
                "Device setup saved. Bluetooth relay stays active automatically."
                if notification_state.permission == "granted"
                else notification_state.message
            ),
            (
                "success"
                if notification_state.permission == "granted"
                else "warning"
            )
        );
    }

    async def send_notification_test {
        busy = True;
        result = await test_distress_notification();
        notification_permission = result.permission;
        show_alert(
            result.message,
            "success" if result.scheduled else "warning"
        );
        append_log(result.message);
        busy = False;
    }

    async def open_background_settings {
        await open_native_settings();
        show_alert(
            "Return to SafeRelay after enabling Background App Refresh.",
            "warning"
        );
    }

    async def erase_packet_history {
        await clear_packets();
        packets = [];
        show_alert("Local packet history cleared from this device.", "neutral");
    }

    async def erase_operational_ledgers {
        await clear_operational_history();
        sync_attempts = [];
        sync_receipts = [];
        show_alert("Local sync history cleared from this device.", "neutral");
    }

    async def refresh_operational_ledgers {
        sync_attempts = await load_records(SYNC_ATTEMPTS_KEY);
        sync_receipts = await load_records(SYNC_RECEIPTS_KEY);
    }

    async def check_reachability(
        queued_packets: list[SosPacket] | None = None
    ) {
        check: any = await verify_internet();  # jac:ignore[W1037]
        internet_failures = int(check["failures"]);
        cloud_configured = bool(check["configured"]);
        cloud_message = str(check["message"]);
        if bool(check["online"]) {
            network_state = "online";
            pending_packets = (
                queued_packets if queued_packets is not None else packets
            );
            if len([packet for packet in pending_packets if not packet.is_synced]) > 0 {
                await sync_cloud(False, pending_packets);
            }
            return;
        }
        network_state = "offline" if cloud_configured else "unconfigured";
        if platform_name != "web" and mesh_state != "active" {
            await ensure_mesh_active();
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
        show_alert(
            (
                str(result["cached"]) + " of " + str(result["total"])
                + " local map tiles are available offline."
            ),
            "success" if offline_tiles > 0 else "warning"
        );
        busy = False;
    }

    async def sync_cloud(
        announce: bool,
        queued_packets: list[SosPacket] | None = None
    ) {
        if sync_state == "checking" or sync_state == "uploading" { return; }
        if announce { busy = True; }
        pending_packets = (
            queued_packets if queued_packets is not None else packets
        );
        sync_state = "checking";
        reachability: any = await verify_internet();  # jac:ignore[W1037]
        online = bool(reachability["online"]);
        cloud_configured = bool(reachability["configured"]);
        cloud_message = str(reachability["message"]);
        network_state = (
            "online"
            if online
            else "offline" if cloud_configured
            else "unconfigured"
        );
        sync_state = "uploading" if online else "offline";
        result: any = await sync_relayed_packets(  # jac:ignore[W1037]
            pending_packets,
            user_id,
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
            "route": result["route"],
            "message": result["message"]
        };
        sync_attempts = [visible_attempt] + sync_attempts[:99];
        new_receipts = result["receipts"] as list[dict[str, object]];
        if len(new_receipts) > 0 {
            sync_receipts = new_receipts + sync_receipts;
        }
        synced_ids = result["syncedIds"] as list[str];
        if len(synced_ids) > 0 {
            for packet in pending_packets {
                if packet.unique_id() in synced_ids { packet.is_synced = True; }
            }
            await save_packets(pending_packets);
            packets = pending_packets[:];
        }
        if announce {
            show_alert(
                str(result["message"]),
                "success" if sync_state == "succeeded" or sync_state == "empty" else "warning"
            );
        }
        append_log("Cloud sync " + sync_state + ": " + str(result["message"]));
        if announce { busy = False; }
    }

    async def run_cloud_sync {
        await sync_cloud(True);
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
            show_alert(
                (
                    "Ultrasonic packet transmitted."
                    if bool(result["sent"]) else str(result["message"])
                ),
                "success" if bool(result["sent"]) else "warning"
            );
        } except Exception as error {
            message = "Ultrasonic transmitter unavailable: " + str(error);
            ultrasonic_log = [message] + ultrasonic_log[:5];
            show_alert(message, "warning");
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
        show_alert(
            str(result["message"]),
            "success" if ultrasonic_listening else "warning"
        );
    }

    async def activate_compass {
        tools_view = "compass";
        compass_status = "Acquiring magnetic heading...";
        result = await start_compass(
            lambda (event: any) {  # jac:ignore[W1037]
                heading = float(event["heading"]);
                heading_accuracy = float(event["accuracy"]);
                compass_status = "Live magnetic heading";
            }
        );
        compass_active = bool(result["active"]);
        compass_status = str(result["message"]);
        if not compass_active {
            show_alert(compass_status, "warning");
        }
    }

    async def select_field_tool(tool: str) {
        if tool == "compass" {
            await activate_compass();
            return;
        }
        if compass_active {
            compass_active = False;
            compass_status = "Compass starts automatically when selected.";
            await stop_compass();
        }
        tools_view = tool;
    }

    async def open_tools {
        active_tab = "tools";
        if tools_view == "compass" {
            await activate_compass();
        }
    }

    async def toggle_strobe {
        if strobe_active {
            if strobe_timer.current { clearInterval(strobe_timer.current); }
            strobe_timer.current = None;
            strobe_phase.current = False;
            strobe_active = False;
            await set_torch(False);
            show_alert("Visual beacon stopped.", "neutral");
            return;
        }
        enabled = await set_torch(True);
        if not enabled {
            show_alert(
                "Torch unavailable. Check camera permission in Settings.",
                "warning"
            );
            return;
        }
        strobe_phase.current = True;
        strobe_active = True;
        strobe_timer.current = setInterval(lambda {
            phase = not bool(strobe_phase.current);
            strobe_phase.current = phase;
            set_torch(phase);
        }, 650);
        show_alert("Visual beacon active.", "success");
    }

    async can with entry {
        user_id = await get_or_create_user_id();
        loaded_packets = await load_packets();
        packets = loaded_packets;
        onboarding_done = await load_onboarding_complete();
        battery_mode = await load_setting(BATTERY_KEY, "Bridge");
        loaded_theme = await load_setting(THEME_KEY, "System");
        theme_mode = loaded_theme;
        auto_download_maps = (
            await load_setting(AUTO_DOWNLOAD_MAPS_KEY, "true")
        ) == "true";
        show_notifications = (
            await load_setting(NOTIFICATIONS_KEY, "true")
        ) == "true";
        document.documentElement.style.setProperty("color-scheme", (
            "light" if loaded_theme == "Light"
            else "dark" if loaded_theme == "Dark"
            else "light dark"
        ));  # jac:ignore[W2001]
        await refresh_operational_ledgers();
        runtime_platform = native_platform();
        platform_name = runtime_platform;
        await refresh_readiness();
        await refresh_foundation_status();
        survival_chat = await load_survival_chat_history();
        if runtime_platform != "web" {
            await ensure_mesh_active();
        }
        await check_reachability(loaded_packets);
        register_app_state_observer();
        register_network_observer();
        await register_notification_observers();
        booting = False;
    }

    useEffect(lambda {
        set_mesh_event_sink(handle_mesh_event);
        return lambda { clear_mesh_event_sink(); };
    }, [packets, battery_mode, show_notifications, user_id]);

    useEffect(lambda {
        return lambda {
            if strobe_timer.current { clearInterval(strobe_timer.current); }
            if distress_notice_timer.current {
                clearTimeout(distress_notice_timer.current);
            }
            set_torch(False);
            stop_ultrasonic_listener();
            stop_compass();
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
        if compass_active and (
            active_tab != "tools" or tools_view != "compass"
        ) {
            compass_active = False;
            compass_status = "Compass starts automatically when selected.";
            stop_compass();
        }
    }, [active_tab, tools_view]);

    useEffect(lambda {
        window.scrollTo(0, 0);  # jac:ignore[W2001]
    }, [active_tab]);

    now = unix_seconds();
    foreign_distress = active_foreign_distress(packets, user_id, now);
    urgent_count = len(foreign_distress);
    notice_distress = [
        packet
        for packet in foreign_distress
        if packet.unique_id() == distress_notice_id
    ];
    distress_age = (
        max(0, notice_distress[0].age_seconds(now))
        if len(notice_distress) > 0 else 0
    );
    distress_age_label = (
        str(distress_age) + "s ago"
        if distress_age < 60
        else str(distress_age // 60) + "m ago"
    );
    brief: ClientOperationalReport = field_brief(
        packets,
        now,
        network_state == "online",
        False
    );
    queue = assess_cloud_queue(
        packets,
        network_state == "online",
        cloud_configured
    );
    distress_headline = (
        "Acquiring position"
        if distress_stage == "locating"
        else "Saving on device"
        if distress_stage == "saving"
        else "Starting Bluetooth relay"
        if distress_stage == "starting-radio"
        else "Broadcasting packet"
        if distress_stage == "broadcasting"
        else "Packet accepted by radio"
        if distress_stage == "accepted"
        else "Packet retained for retry"
        if distress_stage == "queued"
        else "Position unavailable"
        if distress_stage == "blocked"
        else "Send needs attention"
        if distress_stage == "failed"
        else "Distress action armed"
        if distress_armed
        else ""
    );
    distress_button_label = (
        "ACQUIRING POSITION"
        if distress_stage == "locating"
        else "SAVING ON DEVICE"
        if distress_stage == "saving"
        else "STARTING RADIO"
        if distress_stage == "starting-radio"
        else "BROADCASTING"
        if distress_stage == "broadcasting"
        else "RETRY RADIO PACKET"
        if distress_stage == "blocked" or distress_stage == "failed"
        else "CONFIRM RADIO PACKET"
        if distress_armed
        else "ARM DISTRESS ACTION"
    );
    compass_direction = (
        "N"
        if heading < 22.5 or heading >= 337.5
        else "NE"
        if heading < 67.5
        else "E"
        if heading < 112.5
        else "SE"
        if heading < 157.5
        else "S"
        if heading < 202.5
        else "SW"
        if heading < 247.5
        else "W"
        if heading < 292.5
        else "NW"
    );
    compass_rotation = 0.0 - heading;
    compass_accuracy_label = (
        "±" + f"{heading_accuracy:.0f}°"
        if heading_accuracy >= 0.0
        else "CALIBRATING"
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
                    icon={<UploadCloud size={20} />}
                    label="Cloud delivery"
                    value="Automatic when reachable"
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

    return <div className="app-shell">
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

        {if len(notice_distress) > 0 {
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
                        {status_label(notice_distress[0].status_code)}
                        {" · " + status_description(notice_distress[0].status_code)}
                    </strong>
                    <small>
                        {"Node " + str(notice_distress[0].user_id)[-6:]
                        + " · " + distress_age_label
                        + (" · 1 active report" if urgent_count == 1 else " · " + str(urgent_count) + " active reports")}
                    </small>
                </div>
                <button
                    className="distress-presence-action"
                    onClick={lambda {
                        view_distress_notice(notice_distress[0].unique_id());
                    }}
                    title="View distress reports on map"
                    aria-label="View distress reports on map"
                >
                    <MapPin size={20} />
                    <span>VIEW</span>
                </button>
            </section>
        }}

        {if alert_message {
            <div
                key={"runtime-alert-" + str(alert_nonce)}
                className={
                    "alert-strip " + alert_tone
                    + (" dismissing" if alert_dismissing else "")
                }
                role="status"
                aria-live={"assertive" if alert_tone == "danger" else "polite"}
                aria-atomic="true"
            >
                <span className="alert-strip-icon">
                    {if alert_tone == "success" {
                        <Check size={17} />
                    } elif alert_tone == "danger" {
                        <Siren size={17} />
                    } else {
                        <TriangleAlert size={17} />
                    }}
                </span>
                <span>{alert_message}</span>
                <button
                    aria-label="Dismiss alert"
                    title="Dismiss alert"
                    onClick={dismiss_alert}
                ><X size={17} /></button>
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
                        <div
                            className={"relay-power active" if mesh_state == "active" else "relay-power"}
                            title="Bluetooth relay is always enabled"
                            aria-label="Bluetooth relay is always enabled"
                        >
                            <Radio size={23} />
                        </div>
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
                            <small>{"Jac cloud" if cloud_configured else "Configure cloud"}</small>
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
                        focus_packet_id={map_focus_packet_id}
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
                    <button id="tool-guide" role="tab" aria-selected={tools_view == "guide"} className={"active" if tools_view == "guide" else ""} onClick={lambda { select_field_tool("guide"); }}>GUIDE</button>
                    <button id="tool-compass" role="tab" aria-selected={tools_view == "compass"} className={"active" if tools_view == "compass" else ""} onClick={activate_compass}>COMPASS</button>
                    <button id="tool-beacon" role="tab" aria-selected={tools_view == "strobe"} className={"active" if tools_view == "strobe" else ""} onClick={lambda { select_field_tool("strobe"); }}>BEACON</button>
                    <button id="tool-sonic" role="tab" aria-selected={tools_view == "ultrasonic"} className={"active" if tools_view == "ultrasonic" else ""} onClick={lambda { select_field_tool("ultrasonic"); }}>SONIC</button>
                </div>

                <section className="tool-band mode-panel mode-compass detail-tool compass-tool">
                    <div className="compass-readout">
                        <div className="compass-live-label">
                            <span className={"compass-live-dot active" if compass_active else "compass-live-dot"}></span>
                            <span>{"LIVE MAGNETIC BEARING" if compass_active else "MAGNETIC BEARING"}</span>
                        </div>
                        <div className="compass-bearing">
                            <strong>{f"{heading:.0f}"}</strong><span>°</span>
                        </div>
                        <div className="compass-direction">{compass_direction}</div>
                    </div>
                    <div
                        className="compass-dial large"
                        role="img"
                        aria-label={f"Compass heading {heading:.0f} degrees {compass_direction}"}
                    >
                        <div className="compass-tick-ring"></div>
                        <span className="compass-cardinal north">N</span>
                        <span className="compass-cardinal east">E</span>
                        <span className="compass-cardinal south">S</span>
                        <span className="compass-cardinal west">W</span>
                        <div className="compass-needle" style={{"transform": f"rotate({compass_rotation:.1f}deg)"}}>
                            <span className="compass-needle-north"></span>
                            <span className="compass-needle-south"></span>
                            <span className="compass-hub"></span>
                        </div>
                        <span className="compass-lubber"></span>
                    </div>
                    <div className="compass-meta" aria-live="polite">
                        <div>
                            <span>STATUS</span>
                            <strong>{compass_status}</strong>
                        </div>
                        <div>
                            <span>ACCURACY</span>
                            <strong>{compass_accuracy_label}</strong>
                        </div>
                    </div>
                </section>

                <section className="tool-band mode-panel mode-strobe detail-tool">
                    <div className="tool-heading">
                        <div className="tool-icon strobe"><Flashlight size={21} /></div>
                        <div><span>VISUAL BEACON</span><h2>{"ACTIVE" if strobe_active else "READY"}</h2></div>
                    </div>
                    <button
                        id="strobe-action"
                        className={"tool-action active large-action" if strobe_active else "tool-action large-action"}
                        onClick={toggle_strobe}
                        aria-pressed={strobe_active}
                    >
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
                            id="sonic-base-frequency"
                            type="range"
                            min="15000"
                            max="19000"
                            step="250"
                            value={str(ultrasonic_base)}
                            aria-label="Sonic base frequency"
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
                        <button id="sonic-send-action" className="tool-action" onClick={send_ultrasonic}>
                            <Volume2 size={18} /> SEND SOS
                        </button>
                        <button
                            id="sonic-listen-action"
                            className={"tool-action active" if ultrasonic_listening else "tool-action"}
                            onClick={toggle_ultrasonic_listener}
                            aria-pressed={ultrasonic_listening}
                        >
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
                        onClick={lambda { choose_distress_status(1); }}
                        disabled={distress_sending}
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
                        onClick={lambda { choose_distress_status(2); }}
                        disabled={distress_sending}
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
                        onClick={lambda { choose_distress_status(3); }}
                        disabled={distress_sending}
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
                        onClick={lambda { choose_distress_status(4); }}
                        disabled={distress_sending}
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
                    id="distress-command"
                    className={
                        "distress-command status-" + str(selected_status)
                        + (" armed" if distress_armed else "")
                        + (" working" if distress_sending else "")
                    }
                    onClick={send_selected_status}
                    disabled={distress_sending}
                    data-state={distress_stage}
                    data-message={distress_message}
                    aria-label={
                        (
                            "Send " + status_label(selected_status) + " radio packet"
                            if distress_armed
                            else "Arm " + status_label(selected_status) + " distress action"
                        )
                    }
                >
                    <span
                        key={"distress-pulse-" + str(distress_pulse_nonce)}
                        className="distress-command-pulse"
                        aria-hidden="true"
                    ></span>
                    <span className="distress-command-mark" aria-hidden="true">SOS</span>
                    <span className="distress-command-copy">
                        <small>{status_label(selected_status)}</small>
                        <strong>{distress_button_label}</strong>
                    </span>
                </button>

                {if distress_stage != "idle" or distress_armed {
                    <section
                        className={"distress-state " + distress_stage}
                        role="status"
                        aria-live="assertive"
                        aria-atomic="true"
                    >
                        <span className={
                            "active"
                            if distress_stage == "accepted"
                            else "working"
                            if distress_sending
                            else "warning"
                            if distress_stage in ["blocked", "queued", "failed"]
                            else ""
                        }></span>
                        <div>
                            <strong>{distress_headline}</strong>
                            <small>{distress_message}</small>
                            {if distress_packet_id {
                                <code>{"PACKET " + distress_packet_id}</code>
                            }}
                        </div>
                    </section>
                }}
                </div>
            }}

            {if active_tab == "settings" {
                <div key="settings-panel" className="tab-panel settings-panel">
                <div
                    id="native-settings-state"
                    className="native-settings-state"
                    data-mesh-active={"true" if mesh_state == "active" else "false"}
                    data-busy={"true" if busy else "false"}
                    data-mesh-message={mesh_message}
                    data-battery-mode={battery_mode}
                    data-theme-mode={theme_mode}
                    data-auto-download-maps={"true" if auto_download_maps else "false"}
                    data-show-notifications={"true" if show_notifications else "false"}
                    data-bluetooth-permission={ble_permission}
                    data-notification-permission={notification_permission}
                    data-background-state={background_state}
                    data-network-state={network_state}
                    data-cloud-configured={"true" if cloud_configured else "false"}
                    data-cloud-reachable={"true" if network_state == "online" else "false"}
                    data-cloud-message={cloud_message}
                    data-location-ready={"true" if location_ready else "false"}
                    data-location-message={location_message}
                    data-foundation-available={"true" if foundation_status.available else "false"}
                    data-foundation-status={foundation_status.availability}
                    data-offline-tiles={str(offline_tiles)}
                    data-queued-packets={str(queue.queued)}
                    data-sync-receipts={str(len(sync_receipts))}
                    data-packet-count={str(len(packets))}
                    data-sync-record-count={str(len(sync_attempts) + len(sync_receipts))}
                    data-platform={platform_name}
                    data-plugin-version={plugin_version}
                ></div>
                <section className="page-heading">
                    <div><h1>Settings</h1></div>
                    <SlidersHorizontal size={23} />
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>READINESS AND SYSTEMS</span>
                    </div>
                    <div className="settings-row">
                        <span className={"settings-icon safe" if mesh_state == "active" else "settings-icon"}><Radio size={19} /></span>
                        <div><strong>Bluetooth relay · always on</strong><small>{mesh_message}</small></div>
                        <span className={"status-dot ready" if mesh_state == "active" else "status-dot"}></span>
                    </div>
                    <button id="settings-mesh-start" className="settings-row settings-row-button" onClick={ensure_mesh_active} disabled={busy or mesh_state == "active"}>
                        <span className="settings-icon"><Radio size={19} /></span>
                        <div><strong>Restore Bluetooth relay</strong><small>Retry only when iOS has paused or blocked the radio</small></div>
                    </button>
                    <button id="settings-refresh" className="settings-row settings-row-button" onClick={refresh_readiness}>
                        <span className="settings-icon"><RefreshCw size={19} /></span>
                        <div><strong>Refresh device status</strong><small>Bluetooth, notifications, and background refresh</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>DELIVERY ROUTES</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon safe"><Bluetooth size={19} /></span>
                        <div><strong>Nearby Bluetooth</strong><small>Scanning, advertising, and local forwarding stay active</small></div>
                        <span className={"status-dot ready" if mesh_state == "active" else "status-dot"}></span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><UploadCloud size={19} /></span>
                        <div><strong>Jac cloud relay</strong><small>{cloud_message}</small></div>
                        <span className={"status-dot ready" if network_state == "online" else "status-dot"}></span>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>DISPLAY</span>
                    </div>
                    <div className="settings-choice">
                        <div className="settings-choice-copy"><Smartphone size={19} /><div><strong>Theme Mode</strong><small>{theme_mode}</small></div></div>
                        <div className="segmented-control glass-slider-three" role="radiogroup" aria-label="Theme mode">
                            <button id="settings-theme-system" role="radio" aria-checked={theme_mode == "System"} className={"active" if theme_mode == "System" else ""} onClick={lambda { choose_theme("System"); }}>AUTO</button>
                            <button id="settings-theme-light" role="radio" aria-checked={theme_mode == "Light"} className={"active" if theme_mode == "Light" else ""} onClick={lambda { choose_theme("Light"); }}>LIGHT</button>
                            <button id="settings-theme-dark" role="radio" aria-checked={theme_mode == "Dark"} className={"active" if theme_mode == "Dark" else ""} onClick={lambda { choose_theme("Dark"); }}>DARK</button>
                        </div>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>BATTERY MODE</span>
                    </div>
                    <div className="settings-choice">
                        <div className="settings-choice-copy"><BatteryMedium size={19} /><div><strong>Relay profile</strong><small>{battery_mode + " · iOS manages radio scheduling"}</small></div></div>
                        <div className="mode-switch four" role="radiogroup" aria-label="Battery profile">
                            <button id="settings-battery-sos" role="radio" aria-checked={battery_mode == "SOS Active"} className={"active" if battery_mode == "SOS Active" else ""} onClick={lambda { choose_battery("SOS Active"); }}>SOS</button>
                            <button id="settings-battery-bridge" role="radio" aria-checked={battery_mode == "Bridge"} className={"active" if battery_mode == "Bridge" else ""} onClick={lambda { choose_battery("Bridge"); }}>BRIDGE</button>
                            <button id="settings-battery-saver" role="radio" aria-checked={battery_mode == "Battery Saver"} className={"active" if battery_mode == "Battery Saver" else ""} onClick={lambda { choose_battery("Battery Saver"); }}>SAVER</button>
                            <button id="settings-battery-custom" role="radio" aria-checked={battery_mode == "Custom"} className={"active" if battery_mode == "Custom" else ""} onClick={lambda { choose_battery("Custom"); }}>CUSTOM</button>
                        </div>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>DATA AND STORAGE</span>
                    </div>
                    <button id="settings-download-map" className="settings-row settings-row-button" onClick={download_local_map} disabled={busy}>
                        <span className="settings-icon"><Download size={19} /></span>
                        <div><strong>Download Offline Region</strong><small>{str(offline_tiles) + " tiles cached" if offline_tiles > 0 else "Save the area around your current position"}</small></div>
                    </button>
                    <button id="settings-alert-history" className="settings-row settings-row-button" onClick={lambda { active_tab = "home"; }}>
                        <span className="settings-icon"><RefreshCw size={19} /></span>
                        <div><strong>Alert History</strong><small>{str(len(packets)) + " packet records on this device"}</small></div>
                    </button>
                    <button id="settings-clear-map-cache" className="settings-row settings-row-button destructive" onClick={clear_offline_map_cache}>
                        <span className="settings-icon"><MapIcon size={19} /></span>
                        <div><strong>Clear Map Cache</strong><small>Remove downloaded offline tiles</small></div>
                    </button>
                    <button id="settings-clear-packets" className="settings-row settings-row-button destructive" onClick={erase_packet_history}>
                        <span className="settings-icon"><Trash2 size={19} /></span>
                        <div><strong>Clear SOS History</strong><small>Remove all cached packets</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>OFFLINE SETTINGS</span>
                    </div>
                    <div className="settings-row">
                        <span className="settings-icon"><Download size={19} /></span>
                        <div><strong>Auto-download Maps</strong><small>Update the local map around your position on launch</small></div>
                        <button id="settings-auto-download" className={"settings-toggle on" if auto_download_maps else "settings-toggle"} onClick={toggle_auto_download_maps} aria-label="Toggle automatic map downloads"><span></span></button>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>BLUETOOTH</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Bluetooth size={19} /></span>
                        <div><strong>Radio compatibility</strong><small>BLE 5.x · selected by iOS and connected hardware</small></div>
                        <span className={"status-dot ready" if ble_permission == "granted" else "status-dot"}></span>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>AUTOMATION</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><UploadCloud size={19} /></span>
                        <div><strong>Cloud upload · automatic</strong><small>Every unsynced signal uploads whenever the Jac relay is reachable</small></div>
                        <span className={"status-dot ready" if network_state == "online" else "status-dot"}></span>
                    </div>
                    <div className="settings-row">
                        <span className="settings-icon"><Bell size={19} /></span>
                        <div><strong>Show notifications</strong><small>Alert when SOS signals are received</small></div>
                        <button id="settings-show-notifications" className={"settings-toggle on" if show_notifications else "settings-toggle"} onClick={toggle_show_notifications} aria-label="Toggle distress notifications"><span></span></button>
                    </div>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>CLOUD SYNC</span>
                    </div>
                    <button id="settings-sync" className="settings-row settings-row-button" onClick={run_cloud_sync} disabled={busy}>
                        <span className="settings-icon"><UploadCloud size={19} /></span>
                        <div><strong>Retry Cloud Upload</strong><small>{str(queue.queued) + " queued · " + str(len(sync_receipts)) + " receipts"}</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>LOCATION REFERENCE</span>
                    </div>
                    <button id="settings-refresh-location" className="settings-row settings-row-button" onClick={refresh_location} disabled={busy}>
                        <span className="settings-icon"><MapPin size={19} /></span>
                        <div><strong>Current Location</strong><small>{f"Ready · accuracy ±{location_accuracy:.0f} m" if location_ready else location_message}</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>DIAGNOSTICS</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Bluetooth size={19} /></span>
                        <div><strong>Mesh Radio</strong><small>{ble_permission}</small></div>
                        <span className={"status-dot ready" if ble_permission == "granted" else "status-dot"}></span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon"><Bell size={19} /></span>
                        <div><strong>Notifications</strong><small>{notification_permission}</small></div>
                        <span className={"status-dot ready" if notification_permission == "granted" else "status-dot"}></span>
                    </div>
                    <button id="settings-test-notification" className="settings-row settings-row-button" onClick={send_notification_test} disabled={busy}>
                        <span className="settings-icon"><Bell size={19} /></span>
                        <div><strong>Test distress notification</strong><small>Banner, sound, and Notification Center</small></div>
                    </button>
                    {if platform_name == "ios" and background_state == "available" {
                        <div className="settings-row settings-status-row">
                            <span className="settings-icon safe"><Activity size={19} /></span>
                            <div><strong>Background refresh</strong><small>Available</small></div>
                            <span className="status-dot ready"></span>
                        </div>
                    } elif platform_name == "ios" {
                        <button id="settings-open-ios" className="settings-row settings-row-button settings-attention" onClick={open_background_settings}>
                            <span className="settings-icon"><Activity size={19} /></span>
                            <div><strong>Background refresh required</strong><small>{background_state}</small></div>
                        </button>
                    }}
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
                    <button id="settings-clear-sync" className="settings-row settings-row-button destructive" onClick={erase_operational_ledgers}>
                        <span className="settings-icon"><Database size={19} /></span>
                        <div><strong>Clear sync history</strong><small>{str(len(sync_attempts) + len(sync_receipts)) + " local records"}</small></div>
                    </button>
                </section>

                <section className="settings-section">
                    <div className="settings-section-title">
                        <span>ABOUT</span>
                    </div>
                    <div className="settings-row settings-status-row">
                        <span className="settings-icon safe"><Check size={19} /></span>
                        <div><strong>Version</strong><small>{plugin_version}</small></div>
                    </div>
                    <button id="settings-how-it-works" className="settings-row settings-row-button" onClick={lambda { show_alert("SafeRelay keeps Bluetooth relay active, stores every packet locally, and uploads every unsynced signal whenever the Jac cloud relay is reachable.", "neutral"); }}>
                        <span className="settings-icon"><ShieldCheck size={19} /></span>
                        <div><strong>How it works</strong><small>Review local relay, cloud upload, and receipt boundaries</small></div>
                    </button>
                    <button id="settings-redo-onboarding" className="settings-row settings-row-button" onClick={redo_onboarding}>
                        <span className="settings-icon"><RefreshCw size={19} /></span>
                        <div><strong>Redo Onboarding</strong><small>Review permissions and setup again</small></div>
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
            <button id="nav-sos" title="Distress" aria-label="Distress" className={"active distress" if active_tab == "sos" else "distress"} onClick={lambda { active_tab = "sos"; }}>
                <Siren size={21} /><span>DISTRESS</span>
            </button>
            <button id="nav-tools" title="Tools" aria-label="Tools" className={"active" if active_tab == "tools" else ""} onClick={open_tools}>
                <Wrench size={20} /><span>TOOLS</span>
            </button>
            <button id="nav-settings" title="Settings" aria-label="Settings" className={"active" if active_tab == "settings" else ""} onClick={lambda { active_tab = "settings"; }}>
                <SlidersHorizontal size={20} /><span>SETTINGS</span>
            </button>
        </nav>
    </div>;
}
