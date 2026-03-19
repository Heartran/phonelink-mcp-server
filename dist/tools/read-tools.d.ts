declare function formatOutput(data: unknown): {
    content: Array<{
        type: "text";
        text: string;
    }>;
};
export declare function handleGetStatus(): Promise<ReturnType<typeof formatOutput>>;
export declare function handleGetMessages(params: {
    conversation_name?: string;
    max_messages: number;
    navigate_to_tab: boolean;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleGetCalls(params: {
    max_calls: number;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleGetNotifications(params: {
    max_notifications: number;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleGetPhotos(params: {
    max_photos: number;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleInspectUi(params: {
    max_depth: number;
    filter_control_type?: string;
}): Promise<ReturnType<typeof formatOutput>>;
export {};
//# sourceMappingURL=read-tools.d.ts.map