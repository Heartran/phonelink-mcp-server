import { runPowerShellJson } from "../services/powershell.js";
function formatOutput(data) {
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}
function errorOutput(message) {
    return {
        isError: true,
        content: [{ type: "text", text: `Error: ${message}` }],
    };
}
export async function handleSendMessage(params) {
    try {
        const result = await runPowerShellJson("send-message.ps1", {
            Recipient: params.recipient,
            MessageText: params.message_text,
        }, 45_000); // longer timeout for multi-step UI interaction
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to send message: ${err.message}`);
    }
}
export async function handleMakeCall(params) {
    try {
        const result = await runPowerShellJson("make-call.ps1", {
            PhoneNumber: params.phone_number,
        }, 30_000);
        if (result.error)
            return errorOutput(result.error);
        return formatOutput(result);
    }
    catch (err) {
        return errorOutput(`Failed to make call: ${err.message}`);
    }
}
export async function handleLaunchApp() {
    try {
        const { execFile } = await import("node:child_process");
        return new Promise((resolve) => {
            execFile("cmd.exe", ["/c", "start", "ms-phone:"], { timeout: 10_000, windowsHide: true }, (err) => {
                if (err) {
                    resolve(errorOutput(`Failed to launch Phone Link: ${err.message}`));
                }
                else {
                    resolve(formatOutput({
                        launched: true,
                        message: "Phone Link launch initiated. Wait a few seconds before using other tools.",
                    }));
                }
            });
        });
    }
    catch (err) {
        return errorOutput(`Failed to launch Phone Link: ${err.message}`);
    }
}
//# sourceMappingURL=write-tools.js.map