import { z } from "zod";
export declare const GetStatusInputSchema: z.ZodObject<{}, "strict", z.ZodTypeAny, {}, {}>;
export declare const GetMessagesInputSchema: z.ZodObject<{
    conversation_name: z.ZodOptional<z.ZodString>;
    max_messages: z.ZodDefault<z.ZodNumber>;
    navigate_to_tab: z.ZodDefault<z.ZodBoolean>;
}, "strict", z.ZodTypeAny, {
    max_messages: number;
    navigate_to_tab: boolean;
    conversation_name?: string | undefined;
}, {
    conversation_name?: string | undefined;
    max_messages?: number | undefined;
    navigate_to_tab?: boolean | undefined;
}>;
export declare const GetCallsInputSchema: z.ZodObject<{
    max_calls: z.ZodDefault<z.ZodNumber>;
}, "strict", z.ZodTypeAny, {
    max_calls: number;
}, {
    max_calls?: number | undefined;
}>;
export declare const GetNotificationsInputSchema: z.ZodObject<{
    max_notifications: z.ZodDefault<z.ZodNumber>;
}, "strict", z.ZodTypeAny, {
    max_notifications: number;
}, {
    max_notifications?: number | undefined;
}>;
export declare const GetPhotosInputSchema: z.ZodObject<{
    max_photos: z.ZodDefault<z.ZodNumber>;
}, "strict", z.ZodTypeAny, {
    max_photos: number;
}, {
    max_photos?: number | undefined;
}>;
export declare const InspectUiInputSchema: z.ZodObject<{
    max_depth: z.ZodDefault<z.ZodNumber>;
    filter_control_type: z.ZodDefault<z.ZodOptional<z.ZodString>>;
}, "strict", z.ZodTypeAny, {
    max_depth: number;
    filter_control_type: string;
}, {
    max_depth?: number | undefined;
    filter_control_type?: string | undefined;
}>;
export declare const SendMessageInputSchema: z.ZodObject<{
    recipient: z.ZodString;
    message_text: z.ZodString;
}, "strict", z.ZodTypeAny, {
    recipient: string;
    message_text: string;
}, {
    recipient: string;
    message_text: string;
}>;
export declare const MakeCallInputSchema: z.ZodObject<{
    phone_number: z.ZodString;
}, "strict", z.ZodTypeAny, {
    phone_number: string;
}, {
    phone_number: string;
}>;
export declare const LaunchAppInputSchema: z.ZodObject<{}, "strict", z.ZodTypeAny, {}, {}>;
//# sourceMappingURL=tools.d.ts.map