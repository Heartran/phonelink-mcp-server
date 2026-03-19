import { z } from "zod";

// ── Read-only tool schemas ──

export const GetStatusInputSchema = z.object({}).strict().describe(
  "No parameters required. Returns Phone Link connection status."
);

export const GetMessagesInputSchema = z.object({
  conversation_name: z.string()
    .optional()
    .describe("Contact name to open a specific conversation. Leave empty to list all conversations."),
  max_messages: z.number()
    .int().min(1).max(100)
    .default(20)
    .describe("Maximum number of messages/conversations to return (default: 20)."),
  navigate_to_tab: z.boolean()
    .default(true)
    .describe("Whether to click the Messages tab first (default: true). Set false if already on the tab."),
}).strict();

export const GetCallsInputSchema = z.object({
  max_calls: z.number()
    .int().min(1).max(100)
    .default(20)
    .describe("Maximum number of call entries to return (default: 20)."),
}).strict();

export const GetNotificationsInputSchema = z.object({
  max_notifications: z.number()
    .int().min(1).max(100)
    .default(30)
    .describe("Maximum number of notifications to return (default: 30)."),
}).strict();

export const GetPhotosInputSchema = z.object({
  max_photos: z.number()
    .int().min(1).max(100)
    .default(25)
    .describe("Maximum number of photo entries to return (default: 25)."),
}).strict();

export const InspectUiInputSchema = z.object({
  max_depth: z.number()
    .int().min(1).max(25)
    .default(10)
    .describe("Maximum UI tree depth to traverse (default: 10)."),
  filter_control_type: z.string()
    .optional()
    .default("")
    .describe("Only return elements of this control type (e.g. 'Text', 'Button', 'ListItem'). Leave empty for all."),
}).strict();

// ── Write tool schemas ──

export const SendMessageInputSchema = z.object({
  recipient: z.string()
    .min(1, "Recipient is required")
    .describe("Contact name or phone number to send the SMS to."),
  message_text: z.string()
    .min(1, "Message text is required")
    .max(1600, "SMS message too long (max ~1600 chars)")
    .describe("The text message to send."),
}).strict();

export const MakeCallInputSchema = z.object({
  phone_number: z.string()
    .min(3, "Phone number is required")
    .describe("The phone number to call (with country code if needed)."),
}).strict();

export const LaunchAppInputSchema = z.object({}).strict().describe(
  "No parameters required. Launches Phone Link if not already running."
);
