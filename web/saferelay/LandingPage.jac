"""Public SafeRelay product surface."""

import from "@jac/runtime" { Link }
import from "lucide-react" {
    Activity,
    ArrowRight,
    Bluetooth,
    Check,
    ChevronRight,
    CircleGauge,
    CloudLightning,
    Flame,
    LocateFixed,
    Map as MapIcon,
    Network,
    Radio,
    RotateCcw,
    Route,
    Satellite,
    Send,
    ShieldCheck,
    Signal,
    Smartphone,
    Waypoints,
}


def:pub RelayPlayground -> JsxElement {
    has phase: int = 0,
        scenario: str = "wildfire";

    def advance(_e: MouseEvent) {
        phase = 0 if phase >= 3 else phase + 1;
    }

    def choose_scenario(next_scenario: str) {
        scenario = next_scenario;
        phase = 0;
    }

    scenario_label: str = "Wildfire ridge" if scenario == "wildfire" else (
        "Quake corridor" if scenario == "earthquake" else "Storm coast"
    );
    action_label: str = "Inspect map artifact" if phase == 0 else (
        "Next map artifact" if phase < 3 else "Reset map layer"
    );
    artifact_status: str = "Origin marker selected" if phase == 0 else (
        "Nearby-phone marker selected" if phase == 1 else (
            "Field-relay marker selected" if phase == 2 else "Gateway marker selected"
        )
    );
    pip_line: str = "Map layer only. No live evidence.";

    return <section id="map-artifacts" className="relay-hero">
        <div className="relay-hero__copy">
            <div className="relay-kicker">
                <span className="relay-kicker__light"></span>
                SYNTHETIC MAP LAYER · NOT REPORTS
            </div>
            <h1><span>Safe</span>Relay</h1>
            <p>
                Explore hypothetical marker placement on a disaster map.
                Operational reports remain empty until real evidence arrives.
            </p>
            <div className="relay-hero__actions">
                <button type="button" className="relay-launch" onClick={advance}>
                    {<RotateCcw size={17} /> if phase >= 3 else <Send size={17} />}
                    {action_label}
                </button>
                <Link to="/ops" className="relay-text-link">
                    Open evidence monitor <ArrowRight size={16} />
                </Link>
            </div>
            <div className="relay-hero__proof">
                <span><Check size={13} /> BLE mesh</span>
                <span><Check size={13} /> Signed path</span>
                <span><Check size={13} /> Jac graph</span>
            </div>
        </div>

        <div
            className={"relay-stage relay-stage--" + scenario}
            aria-label={"Synthetic map artifact layer: " + scenario_label}
        >
            <div className="relay-stage__topline">
                <div>
                    <span>MAP ARTIFACTS / 001</span>
                    <strong>{scenario_label}</strong>
                </div>
                <div className="relay-scenarios" role="tablist" aria-label="Synthetic scenario">
                    <button
                        type="button"
                        role="tab"
                        aria-selected={scenario == "wildfire"}
                        className={"is-active" if scenario == "wildfire" else ""}
                        onClick={lambda (_e: MouseEvent) { choose_scenario("wildfire"); }}
                    ><Flame size={14} /> Fire</button>
                    <button
                        type="button"
                        role="tab"
                        aria-selected={scenario == "earthquake"}
                        className={"is-active" if scenario == "earthquake" else ""}
                        onClick={lambda (_e: MouseEvent) { choose_scenario("earthquake"); }}
                    ><Activity size={14} /> Quake</button>
                    <button
                        type="button"
                        role="tab"
                        aria-selected={scenario == "storm"}
                        className={"is-active" if scenario == "storm" else ""}
                        onClick={lambda (_e: MouseEvent) { choose_scenario("storm"); }}
                    ><CloudLightning size={14} /> Storm</button>
                </div>
            </div>

            <div className="relay-outage">
                <MapIcon size={19} />
                <span>MAP-ONLY SYNTHETIC LAYER</span>
            </div>

            <div className={"relay-route relay-route--one is-reached" if phase >= 1 else "relay-route relay-route--one"}></div>
            <div className={"relay-route relay-route--two is-reached" if phase >= 2 else "relay-route relay-route--two"}></div>
            <div className={"relay-route relay-route--three is-reached" if phase >= 3 else "relay-route relay-route--three"}></div>

            <div className="relay-node relay-node--origin is-reached">
                <span className="relay-node__icon"><Smartphone size={18} /></span>
                <strong>ARTIFACT 01</strong>
                <small>not a report</small>
            </div>
            <div className={"relay-node relay-node--one is-reached" if phase >= 1 else "relay-node relay-node--one"}>
                <span className="relay-node__icon"><Bluetooth size={18} /></span>
                <strong>ARTIFACT 02</strong>
                <small>not a report</small>
            </div>
            <div className={"relay-node relay-node--two is-reached" if phase >= 2 else "relay-node relay-node--two"}>
                <span className="relay-node__icon"><Radio size={18} /></span>
                <strong>ARTIFACT 03</strong>
                <small>not a report</small>
            </div>
            <div className={"relay-node relay-node--gateway is-reached" if phase >= 3 else "relay-node relay-node--gateway"}>
                <span className="relay-node__icon"><Satellite size={18} /></span>
                <strong>ARTIFACT 04</strong>
                <small>not a report</small>
            </div>

            <div className={"pip-runner pip-runner--" + str(phase)}>
                <span className="pip-message">{pip_line}</span>
                <span
                    className="pip-art"
                    role="img"
                    aria-label="Pip, SafeRelay's pixel-art rescue pigeon mascot"
                ></span>
            </div>

            <div className={"relay-delivery-burst is-visible" if phase >= 3 else "relay-delivery-burst"} aria-hidden="true">
                <span></span><span></span><span></span><span></span><span></span><span></span>
            </div>

            <div className="relay-stage__hud" aria-live="polite">
                <span>MAP SELECTION</span>
                <strong>{artifact_status}</strong>
                <div className="relay-progress" aria-label={str(phase + 1) + " of 4 map artifacts selected"}>
                    {for idx in range(4) {
                        <span key={idx} className={"is-complete" if idx <= phase else ""}></span>
                    }}
                </div>
            </div>
        </div>
    </section>;
}


def:pub LandingPage -> JsxElement {
    return <div className="relay-landing">
        <header className="relay-nav">
            <Link to="/" className="relay-brand">
                <span className="relay-brand__mark"><Waypoints size={19} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <nav aria-label="Public navigation">
                <a href="#map-artifacts">Map artifacts</a>
                <a href="#network">How it works</a>
                <a href="#readiness">Evidence</a>
            </nav>
            <Link to="/ops" className="relay-command-link">
                Command <ArrowRight size={15} />
            </Link>
        </header>

        <main>
            <RelayPlayground />

            <section className="relay-source-strip" aria-label="Evidence boundaries">
                <div><span>PUBLIC HAZARDS</span><strong>USGS + NWS</strong></div>
                <div><span>RELAY REPORTS</span><strong>UNKNOWN UNTIL RECEIVED</strong></div>
                <div><span>OPERATIONS</span><strong>PER-OPERATOR GRAPH</strong></div>
                <div className="relay-source-strip__marquee" aria-hidden="true">
                    <span>MESSAGE MOVES · PATH STAYS · MESSAGE MOVES · PATH STAYS ·</span>
                </div>
            </section>

            <section id="network" className="relay-system">
                <div className="relay-section-heading">
                    <span className="relay-section-number">01 / THE RELAY</span>
                    <h2>Your phone becomes a way through.</h2>
                    <p>
                        SafeRelay treats every nearby device as a possible bridge.
                        The packet moves; its provenance travels with it.
                    </p>
                </div>
                <div className="relay-flow">
                    <article>
                        <span>01</span>
                        <Smartphone size={25} />
                        <h3>Seal</h3>
                        <p>The origin phone signs and prioritizes the emergency packet.</p>
                    </article>
                    <ChevronRight className="relay-flow__arrow" size={20} />
                    <article>
                        <span>02</span>
                        <Bluetooth size={25} />
                        <h3>Carry</h3>
                        <p>Nearby phones pass it across the disconnected area over BLE.</p>
                    </article>
                    <ChevronRight className="relay-flow__arrow" size={20} />
                    <article>
                        <span>03</span>
                        <Route size={25} />
                        <h3>Remember</h3>
                        <p>Every handoff becomes part of a queryable relay path.</p>
                    </article>
                    <ChevronRight className="relay-flow__arrow" size={20} />
                    <article>
                        <span>04</span>
                        <ShieldCheck size={25} />
                        <h3>Surface</h3>
                        <p>The first uplink brings the message and its route to command.</p>
                    </article>
                </div>
            </section>

            <section id="readiness" className="relay-truth">
                <div className="relay-truth__visual">
                    <div className="relay-orbit" aria-hidden="true">
                        <span className="relay-orbit__ring relay-orbit__ring--one"></span>
                        <span className="relay-orbit__ring relay-orbit__ring--two"></span>
                        <span className="relay-orbit__sweep"></span>
                        <span className="relay-orbit__point relay-orbit__point--one"></span>
                        <span className="relay-orbit__point relay-orbit__point--two"></span>
                        <Network size={42} />
                    </div>
                    <div className="relay-truth__stamp">
                        <span>EVIDENCE POLICY</span>
                        <strong>REAL</strong>
                        <small>OR EXPLICITLY UNKNOWN</small>
                    </div>
                </div>
                <div className="relay-truth__copy">
                    <span className="relay-section-number">02 / THE GRAPH</span>
                    <h2>Built to know what it does not know.</h2>
                    <p>
                        The public map layer is synthetic. The operations workspace is not:
                        source records keep their provenance and missing evidence stays missing.
                    </p>
                    <div className="relay-capabilities">
                        <div><CircleGauge size={19} /><span><strong>Persistent state</strong> Verified public-source hazard records.</span></div>
                        <div><LocateFixed size={19} /><span><strong>Relay provenance</strong> Unknown until observed packet evidence exists.</span></div>
                        <div><Activity size={19} /><span><strong>Source-bound feeds</strong> USGS and NWS records keep their origin.</span></div>
                        <div><Signal size={19} /><span><strong>Honest empty states</strong> No generated reports, receipts, or outcomes.</span></div>
                    </div>
                    <Link to="/ops" className="relay-light-button">
                        Inspect the evidence <ArrowRight size={17} />
                    </Link>
                </div>
            </section>
        </main>

        <footer className="relay-footer">
            <div className="relay-brand relay-brand--footer">
                <span className="relay-brand__mark"><Waypoints size={19} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </div>
            <p>Synthetic map layer. Not an emergency service.</p>
            <span>Built end to end in Jac.</span>
        </footer>
    </div>;
}
