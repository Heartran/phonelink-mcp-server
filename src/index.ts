#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import {
  GetStatusInputSchema,
  GetMessagesInputSchema,
  GetCallsInputSchema,
  GetNotificationsInputSchema,
  GetPhotosInputSchema,
  InspectUiInputSchema,
  SendMessageInputSchema,
  MakeCallInputSchema,
  LaunchAppInputSchema,
} from "./schemas/tools.js";

import {
  handleGetStatus,
  handleGetMessages,
  handleGetCalls,
  handleGetNotifications,
  handleGetPhotos,
  handleInspectUi,
} from "./tools/read-tools.js";

import {
  handleSendMessage,
  handleMakeCall,
  handleLaunchApp,
} from "./tools/write-tools.js";

process.on("uncaughtExceptionMonitor", (error, origin) => {
  console.error(`Uncaught exception (${origin}):`, error);
});

process.on("unhandledRejection", (reason) => {
  console.error("Unhandled rejection:", reason);
});

// ── Server initialization ──

const server = new McpServer({
  name: "phonelink-mcp-server",
  version: "1.0.0",
});

// ═══════════════════════════════════════════════════════════════
//  READ-ONLY TOOLS
// ═══════════════════════════════════════════════════════════════

server.registerTool(
  "phonelink_get_status",
  {
    title: "Get Phone Link Status",
    description: `Get the connection status of Phone Link (MyPhone) and basic phone info.

Returns whether the phone is connected, the phone name/model, and whether the app is running.
Use this as the first tool call to verify Phone Link is available before using other tools.

Returns:
  {
    "connected": boolean,     // Whether the phone is connected
    "status": string,         // Status text from the UI
    "phone_name": string,     // Phone model/name if detected
    "app_running": boolean    // Whether Phone Link is running
  }

Error Handling:
  - If Phone Link is not running, returns connected=false with an appropriate status message.
  - Use phonelink_launch_app to start it first if needed.`,
    inputSchema: GetStatusInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  async () => handleGetStatus()
);

server.registerTool(
  "phonelink_get_messages",
  {
    title: "Get Phone Messages",
    description: `Read SMS messages from Phone Link's Messages tab.

Two modes:
1. **List conversations**: Leave conversation_name empty to get a list of all visible conversations with their last message previews.
2. **Read conversation**: Provide a contact name to open and read messages from that specific conversation.

Args:
  - conversation_name (string, optional): Contact name to open. Empty = list all conversations.
  - max_messages (number): Max messages/conversations to return (1-100, default: 20).
  - navigate_to_tab (boolean): Click the Messages tab first (default: true).

Returns (list mode):
  { "conversation_count": number, "conversations": [{ "contact": string, ... }] }

Returns (conversation mode):
  { "conversation": string, "message_count": number, "messages": [{ "text": string, ... }] }

Tips:
  - Use list mode first to discover available conversations.
  - The contact name must match what's displayed in the Phone Link UI.`,
    inputSchema: GetMessagesInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: false, // clicking tabs changes UI state
      openWorldHint: false,
    },
  },
  async (params) => handleGetMessages(params)
);

server.registerTool(
  "phonelink_get_calls",
  {
    title: "Get Call History",
    description: `Read recent call history from Phone Link's Calls tab.

Navigates to the Calls tab and scrapes the visible call list.
Each entry includes the contact/number, call type (incoming/outgoing/missed), and display text.

Args:
  - max_calls (number): Maximum call entries to return (1-100, default: 20).

Returns:
  {
    "call_count": number,
    "calls": [{
      "display_text": string,  // Full text shown for the call entry
      "call_type": "incoming" | "outgoing" | "missed" | "unknown",
      "automation_id": string
    }]
  }`,
    inputSchema: GetCallsInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    },
  },
  async (params) => handleGetCalls(params)
);

server.registerTool(
  "phonelink_get_notifications",
  {
    title: "Get Phone Notifications",
    description: `Read phone notifications from Phone Link's Notifications panel.

Navigates to the Notifications section and scrapes all visible notification entries.
Useful for checking app notifications, system alerts, and other phone notifications mirrored to PC.

Args:
  - max_notifications (number): Max notifications to return (1-100, default: 30).

Returns:
  {
    "notification_count": number,
    "notifications": [{ "text": string, "control_type": string, ... }]
  }`,
    inputSchema: GetNotificationsInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    },
  },
  async (params) => handleGetNotifications(params)
);

server.registerTool(
  "phonelink_get_photos",
  {
    title: "Get Phone Photos",
    description: `List recent photos from Phone Link's Photos tab.

Navigates to the Photos tab and scrapes the visible photo grid.
Returns metadata about each photo entry (name, bounds, type).
Note: This does NOT download photos — it lists what's visible in the UI.

Args:
  - max_photos (number): Maximum photo entries to return (1-100, default: 25).

Returns:
  {
    "photo_count": number,
    "photos": [{ "name": string, "bounds": { x, y, width, height }, ... }]
  }`,
    inputSchema: GetPhotosInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    },
  },
  async (params) => handleGetPhotos(params)
);

server.registerTool(
  "phonelink_inspect_ui",
  {
    title: "Inspect Phone Link UI Tree",
    description: `Debug tool: dumps the Phone Link UI automation tree as JSON.

Use this to discover UI element names, automation IDs, control types, and bounding rectangles.
Helpful for troubleshooting when other tools can't find expected elements.

Args:
  - max_depth (number): Maximum tree depth (1-25, default: 10). Higher = more elements but slower.
  - filter_control_type (string, optional): Only return elements of this type (e.g. "Text", "Button", "ListItem").

Returns:
  {
    "element_count": number,
    "window_name": string,
    "elements": [{ "Name": string, "ControlType": string, "AutomationId": string, ... }]
  }`,
    inputSchema: InspectUiInputSchema,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  async (params) => handleInspectUi(params)
);

// ═══════════════════════════════════════════════════════════════
//  WRITE TOOLS
// ═══════════════════════════════════════════════════════════════

server.registerTool(
  "phonelink_send_message",
  {
    title: "Send SMS Message",
    description: `Send an SMS message through Phone Link's UI.

Opens a new message, types the recipient and message text, and clicks Send.
This interacts with the Phone Link UI to send a real SMS from your phone.

Args:
  - recipient (string): Contact name or phone number.
  - message_text (string): The message to send (max 1600 chars).

Returns:
  { "sent": boolean, "recipient": string, "message": string }

⚠️ WARNING: This sends a REAL SMS. Verify recipient and message before calling.

Error Handling:
  - Returns sent=false with error message if any UI element can't be found.
  - Common issues: Phone not connected, Messages tab not loading, UI layout changes.`,
    inputSchema: SendMessageInputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async (params) => handleSendMessage(params)
);

server.registerTool(
  "phonelink_make_call",
  {
    title: "Make Phone Call",
    description: `Initiate a phone call through Phone Link's dial pad.

Opens the Calls tab, enters the phone number, and clicks the call button.
This triggers a real phone call from your connected phone.

Args:
  - phone_number (string): The number to call (include country code if needed).

Returns:
  { "initiated": boolean, "phone_number": string }

⚠️ WARNING: This initiates a REAL phone call. Verify the number before calling.`,
    inputSchema: MakeCallInputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async (params) => handleMakeCall(params)
);

server.registerTool(
  "phonelink_launch_app",
  {
    title: "Launch Phone Link",
    description: `Launches the Phone Link app if not already running.

Uses the ms-phone: protocol handler to open Phone Link.
Wait a few seconds after calling this before using other tools.

Returns:
  { "launched": boolean, "message": string }`,
    inputSchema: LaunchAppInputSchema,
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  async () => handleLaunchApp()
);

// ═══════════════════════════════════════════════════════════════
//  TRANSPORT
// ═══════════════════════════════════════════════════════════════

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("phonelink-mcp-server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
