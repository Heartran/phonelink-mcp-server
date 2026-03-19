// ── Phone Link MCP Server Types ──

export interface PhoneLinkStatus {
  connected: boolean;
  status: string;
  phone_name: string;
  app_running?: boolean;
  ui_texts?: UiTextEntry[];
  error?: string;
}

export interface UiTextEntry {
  text: string;
  type: string;
  automation: string;
}

export interface ConversationEntry {
  contact: string;
  control_type: string;
  automation_id: string;
}

export interface MessageEntry {
  text: string;
  control_type: string;
  automation_id: string;
  class_name: string;
}

export interface MessagesResult {
  conversation?: string;
  message_count?: number;
  messages?: MessageEntry[];
  conversation_count?: number;
  conversations?: ConversationEntry[];
  error?: string;
}

export interface CallEntry {
  display_text: string;
  call_type: "incoming" | "outgoing" | "missed" | "unknown";
  automation_id: string;
}

export interface CallsResult {
  call_count: number;
  calls: CallEntry[];
  error?: string;
}

export interface NotificationEntry {
  text: string;
  control_type: string;
  automation_id: string;
  class_name: string;
}

export interface NotificationsResult {
  notification_count: number;
  notifications: NotificationEntry[];
  error?: string;
}

export interface PhotoEntry {
  name: string;
  control_type: string;
  automation_id: string;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}

export interface PhotosResult {
  photo_count: number;
  photos: PhotoEntry[];
  error?: string;
}

export interface SendMessageResult {
  sent: boolean;
  recipient?: string;
  message?: string;
  error?: string;
}

export interface MakeCallResult {
  initiated: boolean;
  phone_number?: string;
  error?: string;
}

export interface UiElementInfo {
  Name: string;
  ControlType: string;
  AutomationId: string;
  ClassName: string;
  IsEnabled: boolean;
  Value: string;
  BoundingRect: {
    X: number;
    Y: number;
    Width: number;
    Height: number;
  };
}

export interface InspectUiResult {
  element_count: number;
  window_name?: string;
  elements: UiElementInfo[];
  error?: string;
}
