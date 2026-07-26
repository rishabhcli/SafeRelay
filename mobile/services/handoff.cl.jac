"""Responder handoff transfer surfaces backed by Capacitor native plugins."""

import from "@capacitor/core" { Capacitor }
import from "@capacitor/filesystem" { Directory, Encoding, Filesystem }
import from "@capacitor/share" { Share }
import from "@capgo/capacitor-printer" { Printer }

glob _capacitor: any = Capacitor;  # jac:ignore[W1037]
glob _filesystem: any = Filesystem;  # jac:ignore[W1037]
glob _share: any = Share;  # jac:ignore[W1037]
glob _printer: any = Printer;  # jac:ignore[W1037]
glob _navigator: any = navigator;  # jac:ignore[W1037, W2001]
glob _window: any = window;  # jac:ignore[W1037, W2001]
glob _document: any = document;  # jac:ignore[W1037, W2001]
glob _crypto: any = crypto;  # jac:ignore[W1037, W2001]


def _print_text(handoff: any) -> str {  # jac:ignore[W1037]
    summary: any = handoff["summary"];  # jac:ignore[W1037]
    lines = [
        "SAFERELAY RESPONDER HANDOFF",
        "Generated: " + str(handoff["generatedAt"]),
        "Privacy: " + str(handoff["privacyMode"]),
        "",
        "Stored packets: " + str(summary["packetCount"]),
        "Active help reports: " + str(summary["active"]),
        "Safe reports: " + str(summary["safe"]),
        "Stale reports: " + str(summary["stale"]),
        "Conflicts: " + str(summary["conflicts"]),
        "",
        str(handoff["boundary"]),
        "",
        JSON.stringify(handoff["reports"], None, 2)  # jac:ignore[W2001]
    ];
    return "\n".join(lines);
}


async def _sha256(value: str) -> str {
    encoded = new(TextEncoder).encode(value);  # jac:ignore[W2001]
    digest = await _crypto.subtle.digest("SHA-256", encoded);
    values = new(Uint8Array, digest);  # jac:ignore[W2001]
    output = "";
    for index in range(int(values.length)) {
        byte: any = values[index];  # jac:ignore[W1037]
        output += str(byte.toString(16)).zfill(2);
    }
    return output;
}


def _download(name: str, data: str, mime_type: str) {
    link = _document.createElement("a");
    link.href = (
        "data:" + mime_type + ";charset=utf-8,"
        + str(_window.encodeURIComponent(data))
    );
    link.download = name;
    link.click();
}


def _html_escape(value: str) -> str {
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    );
}


async def:pub prepare_handoff(handoff: any) -> dict[str, object] {  # jac:ignore[W1037]
    payload = JSON.stringify(handoff, None, 2);  # jac:ignore[W2001]
    print_text = _print_text(handoff);
    digest = await _sha256(payload);
    stamp = str(handoff["generatedAt"]);
    base_name = "saferelay-handoff-" + stamp;
    size = int(new(TextEncoder).encode(payload).length);  # jac:ignore[W2001]
    return {
        "baseName": base_name,
        "jsonName": base_name + ".json",
        "textName": base_name + ".txt",
        "pdfName": base_name + ".pdf",
        "payload": payload,
        "printText": print_text,
        "sha256": digest,
        "payloadBytes": size,
        "qrPayload": payload if size <= 2200 else "",
        "boundary": "Responder receipt remains unknown until separately confirmed."
    };
}


async def:pub copy_handoff(artifact: any) -> dict[str, object] {  # jac:ignore[W1037]
    try {
        await _navigator.clipboard.writeText(str(artifact["payload"]));
        return {"ok": True, "message": "Responder handoff copied."};
    } except Exception as error {
        return {"ok": False, "message": "Clipboard unavailable: " + str(error)};
    }
}


async def:pub save_handoff(artifact: any) -> dict[str, object] {  # jac:ignore[W1037]
    if not _capacitor.isNativePlatform() {
        _download(str(artifact["jsonName"]), str(artifact["payload"]), "application/json");
        _download(str(artifact["textName"]), str(artifact["printText"]), "text/plain");
        return {"ok": True, "message": "Handoff JSON and text files downloaded."};
    }
    try {
        folder = "SafeRelay/Handoffs/";
        await _filesystem["writeFile"]({
            "path": folder + str(artifact["jsonName"]),
            "data": str(artifact["payload"]),
            "directory": Directory.Documents,
            "encoding": Encoding.UTF8,
            "recursive": True
        });
        await _filesystem["writeFile"]({
            "path": folder + str(artifact["textName"]),
            "data": str(artifact["printText"]),
            "directory": Directory.Documents,
            "encoding": Encoding.UTF8,
            "recursive": True
        });
        return {
            "ok": True,
            "message": "Handoff files saved to Documents/SafeRelay/Handoffs."
        };
    } except Exception as error {
        return {"ok": False, "message": "Could not save handoff: " + str(error)};
    }
}


async def:pub share_handoff(artifact: any) -> dict[str, object] {  # jac:ignore[W1037]
    try {
        if _capacitor.isNativePlatform() {
            folder = "saferelay-handoff-share/";
            json_path = folder + str(artifact["jsonName"]);
            text_path = folder + str(artifact["textName"]);
            await _filesystem["writeFile"]({
                "path": json_path,
                "data": str(artifact["payload"]),
                "directory": Directory.Cache,
                "encoding": Encoding.UTF8,
                "recursive": True
            });
            await _filesystem["writeFile"]({
                "path": text_path,
                "data": str(artifact["printText"]),
                "directory": Directory.Cache,
                "encoding": Encoding.UTF8,
                "recursive": True
            });
            json_uri = await _filesystem["getUri"]({
                "path": json_path,
                "directory": Directory.Cache
            });
            text_uri = await _filesystem["getUri"]({
                "path": text_path,
                "directory": Directory.Cache
            });
            await _share["share"]({
                "title": "SafeRelay responder handoff",
                "text": "Local evidence handoff. SHA-256: " + str(artifact["sha256"]),
                "files": [str(json_uri["uri"]), str(text_uri["uri"])],
                "dialogTitle": "Share responder handoff"
            });
        } else {
            payload = str(artifact["payload"]);
            options = {
                "title": "SafeRelay responder handoff",
                "text": (
                    "Local evidence handoff. SHA-256: "
                    + str(artifact["sha256"]) + "\n\n" + payload
                )
            };
            if not _navigator.share {
                _download(str(artifact["jsonName"]), payload, "application/json");
                return {"ok": True, "message": "Share unavailable; handoff downloaded."};
            }
            await _navigator.share(options);
        }
        return {"ok": True, "message": "Handoff share sheet opened."};
    } except Exception as error {
        return {"ok": False, "message": "Could not share handoff: " + str(error)};
    }
}


async def:pub print_handoff(artifact: any) -> dict[str, object] {  # jac:ignore[W1037]
    try {
        html = (
            "<!doctype html><html><head><meta charset=\"utf-8\">"
            "<style>body{font:11px/1.45 monospace;margin:34px;color:#111}"
            "h1{font:700 18px sans-serif}pre{white-space:pre-wrap;overflow-wrap:anywhere}"
            "</style></head><body><h1>SafeRelay Responder Handoff</h1><pre>"
            + _html_escape(str(artifact["printText"]))
            + "\n\nSHA-256: " + _html_escape(str(artifact["sha256"]))
            + "</pre></body></html>"
        );
        await _printer["printHtml"]({
            "name": str(artifact["pdfName"]),
            "html": html
        });
        return {"ok": True, "message": "Native print dialog opened."};
    } except Exception as error {
        return {"ok": False, "message": "Could not print handoff: " + str(error)};
    }
}
