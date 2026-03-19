import { runPowerShellJson } from "../services/powershell.js";
import { CHARACTER_LIMIT } from "../constants.js";
// ── Helper: format tool output ──
function formatOutput(data) {
    const json = JSON.stringify(data, null, 2);
    const text = json.length > CHARACTER_LIMIT
        ? json.slice(0, CHARACTER_LIMIT) + "\n\n... [truncated]"
        : json;
    return { content: [{ type: "text", text }] };
}
function errorOutput(message) {
    return {
        isError: true,
        content: [{ type: "text", text: `Error: ${message}` }],
    };
}
// ── Tool handlers ──
export async function handleGetStatus() {
    try {
        const result = await runPowerShellJson("get-status.ps1");
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to get status: ${err.message}`);
    }
}
export async function handleGetMessages(params) {
    try {
        const args = {
            NavigateToTab: params.navigate_to_tab === true || params.navigate_to_tab === "true",
            MaxMessages: params.max_messages,
        };
        if (params.conversation_name) {
            args.ConversationName = params.conversation_name;
        }
        const result = await runPowerShellJson("get-messages.ps1", args);
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to get messages: ${err.message}`);
    }
}
export async function handleGetCalls(params) {
    try {
        const result = await runPowerShellJson("get-calls.ps1", {
            MaxCalls: params.max_calls,
        });
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to get calls: ${err.message}`);
    }
}
export async function handleGetNotifications(params) {
    try {
        const result = await runPowerShellJson("get-notifications.ps1", {
            MaxNotifications: params.max_notifications,
        });
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to get notifications: ${err.message}`);
    }
}
export async function handleGetPhotos(params) {
    try {
        const result = await runPowerShellJson("get-photos.ps1", {
            MaxPhotos: params.max_photos,
        });
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to get photos: ${err.message}`);
    }
}
export async function handleInspectUi(params) {
    try {
        const result = await runPowerShellJson("inspect-ui.ps1", {
            MaxDepth: params.max_depth,
            FilterControlType: params.filter_control_type ?? "",
        });
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to inspect UI: ${err.message}`);
    }
}
//# sourceMappingURL=read-tools.js.map