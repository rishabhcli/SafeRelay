"""Capacitor-native radio and device capability bindings."""

import from "@capacitor/core" { Capacitor, registerPlugin }
import from "@capacitor/app" { App }
import from "@capacitor/geolocation" { Geolocation }
import from "@capacitor/haptics" { Haptics, ImpactStyle }
import from "@capacitor/local-notifications" { LocalNotifications }
import from "@capacitor/network" { Network }
import from "@capawesome/capacitor-torch" { Torch }
import from "@capgo/capacitor-bluetooth-low-energy" { BluetoothLowEnergy }

glob BackgroundRelay: any = registerPlugin("SafeRelayBackground");  # jac:ignore[W1037]
glob SERVICE_UUID: str = "12345678-1234-1234-1234-123456789ABC";
glob PACKET_CHARACTERISTIC_UUID: str = "12345678-1234-1234-1234-123456789ABD";

glob _event_sink: any = None;  # jac:ignore[W1037]
glob _mesh_running: bool = False;
glob _mesh_starting: bool = False;
glob _listeners_ready: bool = False;
glob _current_packet_bytes: list[int] = [];
glob _connecting_ids: list[str] = [];
glob _connected_ids: list[str] = [];
glob _retry_after: dict[str, int] = {};


obj:pub MeshStartState {
    has state: str,
        message: str,
        native: bool,
        platform: str;
    has plugin_version: str = "unavailable";
}


obj:pub NativeReadiness {
    has native: bool,
        platform: str,
        ble_permission: str,
        bluetooth_state: str,
        notification_permission: str,
        network_state: str,
        plugin_version: str,
        message: str;
}


obj:pub LocationFix {
    has ready: bool,
        latitude: float,
        longitude: float,
        accuracy: float,
        message: str;
}


def:pub unix_seconds -> int {
    return int(Math.floor(Date.now() / 1000));  # jac:ignore[W2001]
}


def:pub is_native -> bool {
    return bool(Capacitor.isNativePlatform());
}


def:pub native_platform -> str {
    return str(Capacitor.getPlatform());
}


def:pub mesh_is_running -> bool {
    return _mesh_running;
}


async def:pub resume_saved_mesh -> MeshStartState | None {
    if not is_native() or native_platform() != "android" {
        return None;
    }
    try {
        status = await BackgroundRelay.status();
        if status.enabled {
            return await start_mesh();
        }
    } except Exception {}
    return None;
}


def:pub set_mesh_event_sink(sink: any) {  # jac:ignore[W1037]
    _event_sink = sink;
}


def:pub clear_mesh_event_sink {
    _event_sink = None;
}


def _emit(kind: str, message: str, data: object | None = None) {
    if not _event_sink { return; }
    callback = _event_sink;
    callback.call(None, {
        "kind": kind,
        "message": message,
        "data": data if data is not None else {}
    });
}


def _emit_packet(bytes: list[int], rssi: int, source: str) {
    _emit(
        "packet",
        "Received an SafeRelay packet over " + source,
        {"bytes": bytes, "rssi": rssi, "source": source}
    );
}


async def _wait(milliseconds: int) {
    await new(Promise, lambda (resolve: any, reject: any) {
        setTimeout(lambda { resolve.call(None, None); }, milliseconds);
    });
}


async def:pub inspect_native_readiness -> NativeReadiness {
    platform = native_platform();
    if not is_native() {
        return NativeReadiness(
            native=False,
            platform=platform,
            ble_permission="unavailable",
            bluetooth_state="unavailable",
            notification_permission="unavailable",
            network_state="browser preview",
            plugin_version="unavailable",
            message="Native BLE is available only in the generated iOS or Android shell."
        );
    }

    ble_permission = "prompt";
    bluetooth_state = "unknown";
    notification_permission = "prompt";
    network_state = "unknown";
    plugin_version = "unknown";
    try {
        permissions = await BluetoothLowEnergy.checkPermissions();
        ble_permission = str(permissions.bluetooth);
    } except Exception {}
    try {
        version = await BluetoothLowEnergy.getPluginVersion();
        plugin_version = str(version.version);
    } except Exception {}
    try {
        notification_status = await LocalNotifications.checkPermissions();
        notification_permission = str(notification_status.display);
    } except Exception {}
    try {
        network = await Network.getStatus();
        network_state = (
            str(network.connectionType) if network.connected else "offline"
        );
    } except Exception {}

    return NativeReadiness(
        native=True,
        platform=platform,
        ble_permission=ble_permission,
        bluetooth_state=bluetooth_state,
        notification_permission=notification_permission,
        network_state=network_state,
        plugin_version=plugin_version,
        message="Native shell detected. Radio access still depends on OS permission and hardware state."
    );
}


async def _handle_discovered(event: any) {  # jac:ignore[W1037]
    device = event.device;
    device_id = str(device.deviceId);
    if device_id in _connecting_ids or device_id in _connected_ids { return; }
    if device_id in _retry_after and int(Date.now()) < _retry_after[device_id] {
        return;
    }
    _connecting_ids = _connecting_ids + [device_id];
    _emit("peer", "Discovered nearby SafeRelay peer", {"deviceId": device_id});

    try {
        await BluetoothLowEnergy.connect({
            "deviceId": device_id,
            "autoConnect": True
        });
        await BluetoothLowEnergy.discoverServices({"deviceId": device_id});
        await BluetoothLowEnergy.startCharacteristicNotifications({
            "deviceId": device_id,
            "service": SERVICE_UUID,
            "characteristic": PACKET_CHARACTERISTIC_UUID
        });
        result = await BluetoothLowEnergy.readCharacteristic({
            "deviceId": device_id,
            "service": SERVICE_UUID,
            "characteristic": PACKET_CHARACTERISTIC_UUID
        });
        if result.value and len(result.value) >= 21 {
            _emit_packet(result.value as list[int], int(device.rssi or -100), "GATT read");
        }
        if len(_current_packet_bytes) >= 21 {
            await BluetoothLowEnergy.writeCharacteristic({
                "deviceId": device_id,
                "service": SERVICE_UUID,
                "characteristic": PACKET_CHARACTERISTIC_UUID,
                "value": _current_packet_bytes,
                "type": "withoutResponse"
            });
        }
        _connected_ids = _connected_ids + [device_id];
        _retry_after[device_id] = 0;
        _emit("peer", "Connected to nearby SafeRelay peer", {"deviceId": device_id});
    } except Exception as error {
        _retry_after[device_id] = int(Date.now()) + 5000;
        _emit("warning", "Peer connection did not complete: " + str(error));
        try { await BluetoothLowEnergy.disconnect({"deviceId": device_id}); }
        except Exception {}
    } finally {
        _connecting_ids = [
            item for item in _connecting_ids if item != device_id
        ];
    }
}


def _register_listener_callbacks {
    if _listeners_ready { return; }

    BluetoothLowEnergy.addListener(
        "deviceScanned",
        lambda (event: any) { _handle_discovered(event); }
    );
    BluetoothLowEnergy.addListener(
        "deviceDisconnected",
        lambda (event: any) {
            _connected_ids = [
                item for item in _connected_ids
                if item != str(event.deviceId)
            ];
            _emit("peer", "A mesh peer disconnected", {
                "deviceId": str(event.deviceId)
            });
        }
    );
    BluetoothLowEnergy.addListener(
        "characteristicChanged",
        lambda (event: any) {
            if str(event.characteristic).upper() == PACKET_CHARACTERISTIC_UUID {
                _emit_packet(
                    event.value as list[int],
                    -100,
                    "GATT notification"
                );
            }
        }
    );
    BluetoothLowEnergy.addListener(
        "gattCharacteristicWriteRequest",
        lambda (event: any) {
            if str(event.characteristic).upper() == PACKET_CHARACTERISTIC_UUID {
                _emit_packet(
                    event.value as list[int],
                    -100,
                    "peer write"
                );
            }
        }
    );
    BluetoothLowEnergy.addListener(
        "centralConnected",
        lambda (event: any) {
            _emit("peer", "A central subscribed to this relay", {
                "deviceId": str(event.deviceId)
            });
        }
    );
    BluetoothLowEnergy.addListener(
        "centralDisconnected",
        lambda (event: any) {
            _emit("peer", "A central left this relay", {
                "deviceId": str(event.deviceId)
            });
        }
    );
    _listeners_ready = True;
}


async def:pub start_mesh -> MeshStartState {
    platform = native_platform();
    if not is_native() {
        return MeshStartState(
            state="unavailable",
            message="Web preview cannot access native BLE. Build the Capacitor shell on a physical device.",
            native=False,
            platform=platform
        );
    }
    if _mesh_running {
        return MeshStartState(
            state="active",
            message="Mesh relay is already active.",
            native=True,
            platform=platform
        );
    }
    if _mesh_starting {
        return MeshStartState(
            state="starting",
            message="Mesh relay startup is already in progress.",
            native=True,
            platform=platform
        );
    }

    _mesh_starting = True;
    try {
        permission = await BluetoothLowEnergy.requestPermissions();
        if str(permission.bluetooth) != "granted" {
            return MeshStartState(
                state="blocked",
                message="Bluetooth permission was not granted by the operating system.",
                native=True,
                platform=platform
            );
        }

        await BluetoothLowEnergy.initialize({
            "mode": "central",
            "showPowerAlert": True
        });
        _register_listener_callbacks();

        # The plugin owns separate native central and peripheral managers.
        # Initializing both retains both managers and enables phone-to-phone GATT relay.
        await BluetoothLowEnergy.initialize({
            "mode": "peripheral",
            "showPowerAlert": True
        });
        try {
            await BluetoothLowEnergy.removeGattService({
                "service": SERVICE_UUID
            });
        } except Exception {}
        await BluetoothLowEnergy.addGattService({
            "service": SERVICE_UUID,
            "characteristics": [{
                "uuid": PACKET_CHARACTERISTIC_UUID,
                "properties": {
                    "broadcast": True,
                    "read": True,
                    "writeWithoutResponse": True,
                    "write": True,
                    "notify": True,
                    "indicate": True,
                    "authenticatedSignedWrites": False,
                    "extendedProperties": False
                }
            }]
        });
        # A non-nil cached value, including empty data, is incompatible with
        # this writable/notifiable characteristic and makes CoreBluetooth abort.
        # The plugin resolves addGattService before CoreBluetooth reports that
        # the service is published. Avoid advertising an incomplete GATT table.
        await _wait(750);
        await BluetoothLowEnergy.startAdvertising({
            "name": "SafeRelay",
            "services": [SERVICE_UUID],
            "includeName": True,
            "includeTxPowerLevel": False
        });
        await BluetoothLowEnergy.startScan({
            "services": [SERVICE_UUID],
            "timeout": 0,
            "allowDuplicates": True
        });

        if platform == "android" {
            await BackgroundRelay.start({
                "title": "SafeRelay relay active",
                "body": "Listening for nearby emergency packets."
            });
        }
        try { await LocalNotifications.requestPermissions(); }
        except Exception {}

        _mesh_running = True;
        version = await BluetoothLowEnergy.getPluginVersion();
        _emit("state", "Central scan and peripheral relay are active");
        return MeshStartState(
            state="active",
            message="Central scan, GATT peripheral, and background relay are active.",
            native=True,
            platform=platform,
            plugin_version=str(version.version)
        );
    } except Exception as error {
        _mesh_running = False;
        _emit("error", "Mesh startup failed: " + str(error));
        return MeshStartState(
            state="error",
            message="Native mesh startup failed: " + str(error),
            native=True,
            platform=platform
        );
    } finally {
        _mesh_starting = False;
    }
}


async def:pub stop_mesh -> MeshStartState {
    platform = native_platform();
    if not is_native() {
        return MeshStartState(
            state="unavailable",
            message="No native radio is active in web preview.",
            native=False,
            platform=platform
        );
    }

    try { await BluetoothLowEnergy.stopScan(); }
    except Exception {}
    try { await BluetoothLowEnergy.stopAdvertising(); }
    except Exception {}
    if platform == "android" {
        try { await BackgroundRelay.stop(); }
        except Exception {}
    }
    for device_id in _connected_ids {
        try { await BluetoothLowEnergy.disconnect({"deviceId": device_id}); }
        except Exception {}
    }
    try { await BluetoothLowEnergy.removeAllListeners(); }
    except Exception {}
    _connected_ids = [];
    _connecting_ids = [];
    _listeners_ready = False;
    _mesh_running = False;
    _emit("state", "Mesh relay stopped");
    return MeshStartState(
        state="idle",
        message="Mesh relay is stopped.",
        native=True,
        platform=platform
    );
}


async def:pub publish_packet(bytes: list[int]) -> bool {
    _current_packet_bytes = bytes;
    if not is_native() or not _mesh_running { return False; }

    try {
        await BluetoothLowEnergy.setGattCharacteristicValue({
            "service": SERVICE_UUID,
            "characteristic": PACKET_CHARACTERISTIC_UUID,
            "value": bytes
        });
        await BluetoothLowEnergy.notifyGattCharacteristicChanged({
            "service": SERVICE_UUID,
            "characteristic": PACKET_CHARACTERISTIC_UUID,
            "value": bytes
        });
        for device_id in _connected_ids {
            try {
                await BluetoothLowEnergy.writeCharacteristic({
                    "deviceId": device_id,
                    "service": SERVICE_UUID,
                    "characteristic": PACKET_CHARACTERISTIC_UUID,
                    "value": bytes,
                    "type": "withoutResponse"
                });
            } except Exception {}
        }
        return True;
    } except Exception as error {
        _emit("warning", "Packet queued locally; native publish failed: " + str(error));
        return False;
    }
}


async def:pub current_location -> LocationFix {
    if not is_native() {
        if not navigator.geolocation {  # jac:ignore[W2001]
            return LocationFix(
                ready=False,
                latitude=0.0,
                longitude=0.0,
                accuracy=0.0,
                message="This browser does not expose geolocation."
            );
        }
        try {
            browser_fix = (await new(Promise, lambda (resolve: any, reject: any) {
                navigator.geolocation.getCurrentPosition(  # jac:ignore[E1030, W2001]
                    lambda (position: any) {  # jac:ignore[W1037]
                        resolve.call(None, {
                            "latitude": position.coords.latitude,
                            "longitude": position.coords.longitude,
                            "accuracy": position.coords.accuracy
                        });
                    },
                    lambda (error: any) { reject.call(None, error); },  # jac:ignore[W1037]
                    {
                        "enableHighAccuracy": True,
                        "timeout": 12000,
                        "maximumAge": 15000
                    }
                );
            })) as dict[str, float];  # jac:ignore[W2001]
            return LocationFix(
                ready=True,
                latitude=browser_fix["latitude"],
                longitude=browser_fix["longitude"],
                accuracy=browser_fix["accuracy"],
                message="Current browser position"
            );
        } except Exception as error {
            return LocationFix(
                ready=False,
                latitude=0.0,
                longitude=0.0,
                accuracy=0.0,
                message="Browser location unavailable: " + str(error)
            );
        }
    }

    try {
        await Geolocation.requestPermissions();
        position = await Geolocation.getCurrentPosition({
            "enableHighAccuracy": True,
            "timeout": 12000,
            "maximumAge": 15000
        });
        return LocationFix(
            ready=True,
            latitude=float(position.coords.latitude),
            longitude=float(position.coords.longitude),
            accuracy=float(position.coords.accuracy),
            message="Current device position"
        );
    } except Exception as error {
        return LocationFix(
            ready=False,
            latitude=0.0,
            longitude=0.0,
            accuracy=0.0,
            message="Location unavailable: " + str(error)
        );
    }
}


async def:pub notify_incoming(
    packet_id: int,
    title: str,
    body: str
) {
    if not is_native() { return; }
    try {
        await LocalNotifications.schedule({
            "notifications": [{
                "id": packet_id % 2147483647,
                "title": title,
                "body": body,
                "smallIcon": "ic_stat_safe_relay"
            }]
        });
    } except Exception {}
}


async def:pub emergency_haptic {
    if not is_native() { return; }
    try { await Haptics.impact({"style": ImpactStyle.Heavy}); }
    except Exception {}
}


async def:pub set_torch(enabled: bool) -> bool {
    if not is_native() { return False; }
    try {
        if enabled { await Torch.enable(); }
        else { await Torch.disable(); }
        return True;
    } except Exception as error {
        _emit("warning", "Torch control unavailable: " + str(error));
        return False;
    }
}


async def:pub open_native_settings {
    if not is_native() { return; }
    try { await BluetoothLowEnergy.openAppSettings(); }
    except Exception {}
}


def:pub register_app_state_observer {
    if not is_native() { return; }
    App.addListener("appStateChange", lambda (event: any) {
        _emit(
            "lifecycle",
            "App entered foreground" if event.isActive else "App entered background",
            {"isActive": bool(event.isActive)}
        );
    });
}
