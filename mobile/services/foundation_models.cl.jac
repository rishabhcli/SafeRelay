"""iOS Apple Foundation Models bridge with browser and Android-safe fallbacks."""

import from "@capacitor/core" { Capacitor, registerPlugin }

glob FoundationModels: any = registerPlugin("SafeRelayFoundationModels");  # jac:ignore[W1037]


obj:pub FoundationModelStatus {
    has available: bool,
        availability: str,
        mode: str;
}


obj:pub FoundationModelChatResponse {
    has available: bool,
        availability: str,
        reply: str;
}


async def:pub foundation_model_status -> FoundationModelStatus {
    if not Capacitor.isNativePlatform() or Capacitor.getPlatform() != "ios" {
        return FoundationModelStatus(
            available=False,
            availability="iOS 26 device required",
            mode="unavailable"
        );
    }
    try {
        result: any = await FoundationModels.status();  # jac:ignore[W1037]
        return FoundationModelStatus(
            available=bool(result.available),
            availability=str(result.availability),
            mode=str(result.mode)
        );
    } except Exception as error {
        return FoundationModelStatus(
            available=False,
            availability="plugin unavailable: " + str(error),
            mode="unavailable"
        );
    }
}


async def:pub chat_with_survival_guide(
    messages: list[dict[str, object]],
    field_context: list[str]
) -> FoundationModelChatResponse {
    status = await foundation_model_status();
    if not status.available {
        return FoundationModelChatResponse(
            available=False,
            availability=status.availability,
            reply=""
        );
    }
    try {
        result: any = await FoundationModels.chat({  # jac:ignore[W1037]
            "messages": messages[-12:],
            "fieldContext": "\n".join(field_context)[:2500]
        });
        return FoundationModelChatResponse(
            available=bool(result.available),
            availability=str(result.availability),
            reply=str(result.reply)
        );
    } except Exception as error {
        return FoundationModelChatResponse(
            available=False,
            availability="guide unavailable: " + str(error),
            reply=""
        );
    }
}
