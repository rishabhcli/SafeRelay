"""Explorable Mapbox incident map for the SafeRelay field client."""

import from "react" { useEffect }
import from "mapbox-gl" {
    LngLatBounds,
    Map as MapboxMap,
    Marker as MapboxMarker,
}
import from "lucide-react" {
    Crosshair,
    LocateFixed,
    LoaderCircle,
    MapPin,
    X,
    ZoomIn,
    ZoomOut,
}
import from ..domain.protocol {
    ClientSosPacket as SosPacket,
    client_status_color as status_color,
    client_status_description as status_description,
    client_status_label as status_label,
}

glob MAPBOX_ACCESS_TOKEN: str = str(__MAPBOX_ACCESS_TOKEN__);  # jac:ignore[W2001]
glob _document: any = document;  # jac:ignore[W1037, W2001]


def packet_center(packets: list[SosPacket]) -> list[float] {
    if len(packets) == 0 {
        return [0.0, 0.0];
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
    location_message: str,
    on_locate: any,  # jac:ignore[W1037]
    focus_packet_id: str = "",
) -> JsxElement {
    has container_ref: Ref[HTMLDivElement] = Ref();
    has map_ref: Ref[any] = Ref(None);  # jac:ignore[W1037]
    has marker_refs: Ref[list[any]] = Ref([]);  # jac:ignore[W1037]
    has did_auto_center: Ref[bool] = Ref(False);
    has selected_packet_id: str = "";
    has locating: bool = False;

    initial_center: list[float] = (
        [longitude, latitude] if location_ready else packet_center(packets)
    );
    has_verified_signal: bool = location_ready or len(packets) > 0;
    selected_packet_label: str = "";
    selected_packet_coordinates: str = "";
    selected_packet_description: str = "";
    selected_packet_source: str = "";
    selected_packet_meta: str = "";
    selected_packet_color: str = "#49a8ff";
    for packet in packets {
        if packet.unique_id() == selected_packet_id {
            selected_packet_label = status_label(packet.status_code);
            selected_packet_coordinates = (
                f"{packet.latitude():.5f}, {packet.longitude():.5f}"
            );
            selected_packet_description = status_description(packet.status_code);
            selected_packet_source = "LOCAL MESH REPORT";
            selected_packet_meta = (
                (str(packet.rssi) + " dBm" if packet.rssi > -127 else "RSSI unknown")
                + " / "
                + str(packet.relay_hops)
                + (" relay hop" if packet.relay_hops == 1 else " relay hops")
            );
            selected_packet_color = status_color(packet.status_code);
        }
    }

    def center_map(_event: MouseEvent) {
        map_instance: any = map_ref.current;  # jac:ignore[W1037]
        if not map_instance { return; }
        if len(packets) + (1 if location_ready else 0) > 1 {
            bounds: any = new(LngLatBounds);  # jac:ignore[W1037]
            for packet in packets {
                bounds.extend([packet.longitude(), packet.latitude()]);
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
                "center": initial_center,
                "zoom": 14.0 if has_verified_signal else 2.0,
                "duration": 500,
            });
        }
    }

    def zoom_in(_event: MouseEvent) {
        map_instance: any = map_ref.current;  # jac:ignore[W1037]
        if map_instance {
            map_instance.zoomIn({"duration": 260});
        }
    }

    def zoom_out(_event: MouseEvent) {
        map_instance: any = map_ref.current;  # jac:ignore[W1037]
        if map_instance {
            map_instance.zoomOut({"duration": 260});
        }
    }

    async def locate_user(_event: MouseEvent) {
        locating = True;
        await on_locate();
        locating = False;
        map_instance: any = map_ref.current;  # jac:ignore[W1037]
        if map_instance and location_ready {
            map_instance.easeTo({
                "center": [longitude, latitude],
                "zoom": max(15.0, float(map_instance.getZoom())),
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
                    "zoom": 13.0 if has_verified_signal else 2.0,
                    "minZoom": 2.0,
                    "maxZoom": 18.0,
                    "dragRotate": False,
                    "touchPitch": False,
                    "cooperativeGestures": False,
                },
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
            if not focus_packet_id { return; }
            map_instance: any = map_ref.current;  # jac:ignore[W1037]
            if not map_instance { return; }
            for packet in packets {
                if packet.unique_id() == focus_packet_id {
                    selected_packet_id = focus_packet_id;
                    map_instance.easeTo({
                        "center": [packet.longitude(), packet.latitude()],
                        "zoom": max(15.5, float(map_instance.getZoom())),
                        "duration": 650,
                    });
                    break;
                }
            }
        },
        [focus_packet_id, packets],
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
                marker_element.style.setProperty(
                    "--marker-color",
                    status_color(packet.status_code),
                );
                pin_element: any = _document.createElement("span");  # jac:ignore[W1037]
                pin_element.className = "field-map-marker-pin";
                marker_element.appendChild(pin_element);
                marker_element.setAttribute(
                    "aria-label",
                    status_label(packet.status_code) + " packet " + packet_id,
                );
                marker_element.setAttribute(
                    "aria-expanded",
                    "true" if packet_id == selected_packet_id else "false",
                );
                marker_element.addEventListener(
                    "click",
                    lambda (_event: any) {
                        selected_packet_id = (
                            "" if selected_packet_id == packet_id else packet_id
                        );
                    },
                );
                marker: any = new(  # jac:ignore[W1037]
                    MapboxMarker,
                    {"element": marker_element, "anchor": "bottom"},
                );
                marker.setLngLat([packet.longitude(), packet.latitude()]);
                marker.addTo(map_instance);
                next_markers.append(marker);
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
        <div className="field-map-controls" role="group" aria-label="Map controls">
            <button title="Zoom in" aria-label="Zoom in" onClick={zoom_in}>
                <ZoomIn size={20} />
            </button>
            <button title="Zoom out" aria-label="Zoom out" onClick={zoom_out}>
                <ZoomOut size={20} />
            </button>
            <button
                className={
                    "is-locating"
                    if locating
                    else ("has-location" if location_ready else "")
                }
                title={location_message if not location_ready else "Center on my location"}
                aria-label={
                    "Locating current position"
                    if locating
                    else "Locate me"
                }
                aria-pressed={location_ready}
                onClick={locate_user}
                disabled={locating}
            >
                {<LoaderCircle className="field-map-control-spinner" size={20} /> if locating else <LocateFixed size={20} />}
            </button>
            <button title="Fit active signals" aria-label="Fit active signals" onClick={center_map}>
                <Crosshair size={20} />
            </button>
        </div>
        {if selected_packet_label {
            <aside className="field-map-selection" aria-label="Emergency details" aria-live="polite">
                <div className="field-map-selection-handle"></div>
                <div className="field-map-selection-header">
                    <span
                        className="field-map-selection-icon"
                        style={{"backgroundColor": selected_packet_color}}
                    >
                        <MapPin size={17} />
                    </span>
                    <div>
                        <span className="field-map-selection-source">{selected_packet_source}</span>
                        <strong>{selected_packet_label}</strong>
                    </div>
                    <button
                        className="field-map-selection-close"
                        title="Collapse emergency details"
                        aria-label="Collapse emergency details"
                        onClick={lambda { selected_packet_id = ""; }}
                    >
                        <X size={18} />
                    </button>
                </div>
                <p>{selected_packet_description}</p>
                <div className="field-map-selection-meta">
                    <span>{selected_packet_coordinates}</span>
                    <span>{selected_packet_meta}</span>
                </div>
            </aside>
        }}
        {if not MAPBOX_ACCESS_TOKEN {
            <div className="field-map-unavailable">
                <MapPin size={20} />
                <strong>MAP TOKEN REQUIRED</strong>
            </div>
        } elif not has_verified_signal {
            <div className="field-map-empty">
                <MapPin size={18} />
                <div>
                    <strong>NO VERIFIED MAP SIGNALS</strong>
                    <span>Enable location or receive a mesh report.</span>
                </div>
            </div>
        }}
    </section>;
}
