"""Explorable Mapbox incident map for the SafeRelay field client."""

import from "react" { useEffect }
import from "mapbox-gl" {
    LngLatBounds,
    Map as MapboxMap,
    Marker as MapboxMarker,
    NavigationControl,
}
import from "lucide-react" { Crosshair, MapPin }
import from ..domain.protocol {
    ClientSosPacket as SosPacket,
    client_status_color as status_color,
    client_status_label as status_label,
}

glob MAPBOX_ACCESS_TOKEN: str = str(__MAPBOX_ACCESS_TOKEN__);  # jac:ignore[W2001]
glob _document: any = document;  # jac:ignore[W1037, W2001]


def packet_center(packets: list[SosPacket]) -> list[float] {
    if len(packets) == 0 {
        return [-122.4194, 37.7749];
    }
    latitude_total: float = 0.0;
    longitude_total: float = 0.0;
    for packet in packets {
        latitude_total += packet.latitude();
        longitude_total += packet.longitude();
    }
    return [
        longitude_total / float(len(packets)),
        latitude_total / float(len(packets)),
    ];
}


def:pub IncidentMap(
    packets: list[SosPacket],
    latitude: float,
    longitude: float,
    location_ready: bool,
) -> JsxElement {
    has container_ref: Ref[HTMLDivElement] = Ref();
    has map_ref: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has marker_refs: Ref[list[any]] = Ref([]);  # jac:ignore[W1037]
    has did_auto_center: Ref[bool] = Ref(False);
    has selected_packet_id: str = "";

    initial_center: list[float] = (
        [longitude, latitude] if location_ready else packet_center(packets)
    );
    demo_signals: list[dict[str, any]] = [  # jac:ignore[W1037]
        {
            "id": "demo-rescue",
            "label": "DEMO RESCUE",
            "longitude": initial_center[0] - 0.008,
            "latitude": initial_center[1] + 0.004,
            "color": "#ff4d5e",
        },
        {
            "id": "demo-medical",
            "label": "DEMO MEDICAL",
            "longitude": initial_center[0] + 0.006,
            "latitude": initial_center[1] + 0.007,
            "color": "#f2cc60",
        },
        {
            "id": "demo-supplies",
            "label": "DEMO SUPPLIES",
            "longitude": initial_center[0] + 0.009,
            "latitude": initial_center[1] - 0.004,
            "color": "#49a8ff",
        },
        {
            "id": "demo-safe",
            "label": "DEMO SAFE",
            "longitude": initial_center[0] - 0.004,
            "latitude": initial_center[1] - 0.007,
            "color": "#48c78e",
        },
    ];
    selected_packet_label: str = "";
    selected_packet_coordinates: str = "";
    for packet in packets {
        if packet.unique_id() == selected_packet_id {
            selected_packet_label = status_label(packet.status_code);
            selected_packet_coordinates = (
                f"{packet.latitude():.5f}, {packet.longitude():.5f}"
            );
        }
    }
    for demo_signal in demo_signals {
        if str(demo_signal["id"]) == selected_packet_id {
            selected_packet_label = str(demo_signal["label"]);
            selected_packet_coordinates = (
                f"{float(demo_signal['latitude']):.5f}, "
                + f"{float(demo_signal['longitude']):.5f}"
            );
        }
    }

    def center_map(_event: MouseEvent) {
        map_instance: any = map_ref.current;  # jac:ignore[W1037]
        if not map_instance { return; }
        if len(packets) + len(demo_signals) > 1 {
            bounds: any = new(LngLatBounds);  # jac:ignore[W1037]
            for packet in packets {
                bounds.extend([packet.longitude(), packet.latitude()]);
            }
            for demo_signal in demo_signals {
                bounds.extend([
                    float(demo_signal["longitude"]),
                    float(demo_signal["latitude"]),
                ]);
            }
            if location_ready {
                bounds.extend([longitude, latitude]);
            }
            map_instance.fitBounds(
                bounds,
                {"padding": 52, "maxZoom": 15.0, "duration": 500},
            );
        } else {
            map_instance.easeTo({
                "center": (
                    [longitude, latitude]
                    if location_ready
                    else packet_center(packets)
                ),
                "zoom": 14.0,
                "duration": 500,
            });
        }
    }

    useEffect(
        lambda {
            if not container_ref.current or not MAPBOX_ACCESS_TOKEN {
                return;
            }
            map_instance: any = new(  # jac:ignore[W1037]
                MapboxMap,
                {
                    "accessToken": MAPBOX_ACCESS_TOKEN,
                    "container": container_ref.current,
                    "style": "mapbox://styles/mapbox/outdoors-v12",
                    "center": initial_center,
                    "zoom": 13.0,
                    "minZoom": 2.0,
                    "maxZoom": 18.0,
                    "dragRotate": False,
                    "touchPitch": False,
                    "cooperativeGestures": False,
                },
            );
            map_instance.addControl(
                new(NavigationControl, {"showCompass": False}),
                "top-right",
            );
            map_ref.current = map_instance;
            return lambda {
                map_instance.remove();
                map_ref.current = None;
            };
        },
        [],
    );

    useEffect(
        lambda {
            map_instance: any = map_ref.current;  # jac:ignore[W1037]
            if not map_instance or not location_ready or did_auto_center.current {
                return;
            }
            did_auto_center.current = True;
            map_instance.easeTo({
                "center": [longitude, latitude],
                "zoom": 14.0,
                "duration": 500,
            });
        },
        [location_ready, latitude, longitude],
    );

    useEffect(
        lambda {
            map_instance: any = map_ref.current;  # jac:ignore[W1037]
            if not map_instance { return; }
            for old_marker in marker_refs.current {
                old_marker.remove();
            }
            next_markers: list[any] = [];  # jac:ignore[W1037]

            if location_ready {
                location_element: any = _document.createElement("div");  # jac:ignore[W1037]
                location_element.className = "field-map-location";
                location_element.setAttribute("aria-label", "Current field position");
                location_marker: any = new(  # jac:ignore[W1037]
                    MapboxMarker,
                    {"element": location_element, "anchor": "center"},
                );
                location_marker.setLngLat([longitude, latitude]);
                location_marker.addTo(map_instance);
                next_markers.append(location_marker);
            }

            for packet in packets {
                packet_id: str = packet.unique_id();
                marker_element: any = _document.createElement("button");  # jac:ignore[W1037]
                marker_element.type = "button";
                marker_element.className = (
                    "field-map-marker is-selected"
                    if packet_id == selected_packet_id
                    else "field-map-marker"
                );
                marker_element.style.backgroundColor = status_color(
                    packet.status_code
                );
                marker_element.setAttribute(
                    "aria-label",
                    status_label(packet.status_code) + " packet " + packet_id,
                );
                marker_element.addEventListener(
                    "click",
                    lambda (_event: any) { selected_packet_id = packet_id; },
                );
                marker: any = new(  # jac:ignore[W1037]
                    MapboxMarker,
                    {"element": marker_element, "anchor": "center"},
                );
                marker.setLngLat([packet.longitude(), packet.latitude()]);
                marker.addTo(map_instance);
                next_markers.append(marker);
            }

            for demo_signal in demo_signals {
                demo_id: str = str(demo_signal["id"]);
                demo_label: str = str(demo_signal["label"]);
                demo_element: any = _document.createElement("button");  # jac:ignore[W1037]
                demo_element.type = "button";
                demo_element.className = (
                    "field-map-marker is-demo is-selected"
                    if demo_id == selected_packet_id
                    else "field-map-marker is-demo"
                );
                demo_element.style.backgroundColor = str(demo_signal["color"]);
                demo_element.setAttribute("aria-label", demo_label);
                demo_element.addEventListener(
                    "click",
                    lambda (_event: any) { selected_packet_id = demo_id; },
                );
                demo_marker: any = new(  # jac:ignore[W1037]
                    MapboxMarker,
                    {"element": demo_element, "anchor": "center"},
                );
                demo_marker.setLngLat([
                    float(demo_signal["longitude"]),
                    float(demo_signal["latitude"]),
                ]);
                demo_marker.addTo(map_instance);
                next_markers.append(demo_marker);
            }
            marker_refs.current = next_markers;
            return lambda {
                for marker in next_markers {
                    marker.remove();
                }
            };
        },
        [packets, location_ready, latitude, longitude, selected_packet_id],
    );

    return <section className="field-map mode-default" aria-label="Explorable incident map">
        <div ref={container_ref} className="field-map-canvas"></div>
        <button
            className="field-map-recenter"
            title="Fit active signals"
            aria-label="Fit active signals"
            onClick={center_map}
        >
            <Crosshair size={18} />
        </button>
        {if selected_packet_label {
            <div className="field-map-selection">
                <MapPin size={16} />
                <div>
                    <strong>{selected_packet_label}</strong>
                    <span>{selected_packet_coordinates}</span>
                </div>
            </div>
        }}
        {if not MAPBOX_ACCESS_TOKEN {
            <div className="field-map-unavailable">
                <MapPin size={20} />
                <strong>MAP TOKEN REQUIRED</strong>
            </div>
        }}
    </section>;
}
