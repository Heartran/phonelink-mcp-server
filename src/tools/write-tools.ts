import { runPowerShellJson } from "../services/powershell.js";
import type { SendMessageResult, MakeCallResult } from "../types.js";

function formatOutput(data: unknown): { content: Array<{ type: "text"; text: string }> } {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

function errorOutput(message: string): { isError: true; content: Array<{ type: "text"; text: string }> } {
  return {
    isError: true,
    content: [{ type: "text" as const, text: `Error: ${message}` }],
  };
}

export async function handleSendMessage(params: {
  recipient: string;
  message_text: string;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<SendMessageResult>("send-message.ps1", {
      Recipient: params.recipient,
      MessageText: params.message_text,
    }, 45_000); // longer timeout for multi-step UI interaction
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to send message: ${(err as Error).message}`);
  }
}

export async function handleMakeCall(params: {
  phone_number: string;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<MakeCallResult>("make-call.ps1", {
      PhoneNumber: params.phone_number,
    }, 30_000);
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to make call: ${(err as Error).message}`);
  }
}

export async function handleLaunchApp(): Promise<ReturnType<typeof formatOutput>> {
  try {
    const { execFile } = await import("node:child_process");
    return new Promise((resolve) => {
      execFile("cmd.exe", ["/c", "start", "ms-phone:"], { timeout: 10_000, windowsHide: true }, (err) => {
        if (err) {
          resolve(errorOutput(`Failed to launch Phone Link: ${err.message}`));
        } else {
          resolve(formatOutput({
            launched: true,
            message: "Phone Link launch initiated. Wait a few seconds before using other tools.",
          }));
        }
      });
    });
  } catch (err) {
    return errorOutput(`Failed to launch Phone Link: ${(err as Error).message}`);
  }
}
