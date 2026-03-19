import { runPowerShellJson } from "../services/powershell.js";
import { CHARACTER_LIMIT } from "../constants.js";
import type {
  PhoneLinkStatus,
  MessagesResult,
  CallsResult,
  NotificationsResult,
  PhotosResult,
  InspectUiResult,
} from "../types.js";

// ── Helper: format tool output ──

function formatOutput(data: unknown): { content: Array<{ type: "text"; text: string }> } {
  const json = JSON.stringify(data, null, 2);
  const text = json.length > CHARACTER_LIMIT
    ? json.slice(0, CHARACTER_LIMIT) + "\n\n... [truncated]"
    : json;
  return { content: [{ type: "text" as const, text }] };
}

function errorOutput(message: string): { isError: true; content: Array<{ type: "text"; text: string }> } {
  return {
    isError: true,
    content: [{ type: "text" as const, text: `Error: ${message}` }],
  };
}

// ── Tool handlers ──

export async function handleGetStatus(): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<PhoneLinkStatus>("get-status.ps1");
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to get status: ${(err as Error).message}`);
  }
}

export async function handleGetMessages(params: {
  conversation_name?: string;
  max_messages: number;
  navigate_to_tab: boolean;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const args: Record<string, string | number | boolean> = {
      NavigateToTab: params.navigate_to_tab === true || (params.navigate_to_tab as unknown) === "true",
      MaxMessages: params.max_messages,
    };
    if (params.conversation_name) {
      args.ConversationName = params.conversation_name;
    }
    const result = await runPowerShellJson<MessagesResult>("get-messages.ps1", args);
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to get messages: ${(err as Error).message}`);
  }
}

export async function handleGetCalls(params: {
  max_calls: number;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<CallsResult>("get-calls.ps1", {
      MaxCalls: params.max_calls,
    });
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to get calls: ${(err as Error).message}`);
  }
}

export async function handleGetNotifications(params: {
  max_notifications: number;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<NotificationsResult>("get-notifications.ps1", {
      MaxNotifications: params.max_notifications,
    });
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to get notifications: ${(err as Error).message}`);
  }
}

export async function handleGetPhotos(params: {
  max_photos: number;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<PhotosResult>("get-photos.ps1", {
      MaxPhotos: params.max_photos,
    });
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to get photos: ${(err as Error).message}`);
  }
}

export async function handleInspectUi(params: {
  max_depth: number;
  filter_control_type?: string;
}): Promise<ReturnType<typeof formatOutput>> {
  try {
    const result = await runPowerShellJson<InspectUiResult>("inspect-ui.ps1", {
      MaxDepth: params.max_depth,
      FilterControlType: params.filter_control_type ?? "",
    });
    if (result.error) return errorOutput(result.error);
    return formatOutput(result);
  } catch (err) {
    return errorOutput(`Failed to inspect UI: ${(err as Error).message}`);
  }
}
