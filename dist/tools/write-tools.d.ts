declare function formatOutput(data: unknown): {
    content: Array<{
        type: "text";
        text: string;
    }>;
};
export declare function handleSendMessage(params: {
    recipient: string;
    message_text: string;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleMakeCall(params: {
    phone_number: string;
}): Promise<ReturnType<typeof formatOutput>>;
export declare function handleLaunchApp(): Promise<ReturnType<typeof formatOutput>>;
export {};
//# sourceMappingURL=write-tools.d.ts.map