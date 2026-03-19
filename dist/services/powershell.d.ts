export interface PsExecResult {
    stdout: string;
    stderr: string;
    exitCode: number | null;
}
/**
 * Executes a PowerShell script from the scripts directory and returns raw output.
 */
export declare function runPowerShellScript(scriptName: string, args?: Record<string, string | number | boolean>, timeoutMs?: number): Promise<PsExecResult>;
/**
 * Executes a PowerShell script and parses its JSON output.
 * Returns the parsed object or throws on failure.
 */
export declare function runPowerShellJson<T>(scriptName: string, args?: Record<string, string | number | boolean>, timeoutMs?: number): Promise<T>;
/**
 * Checks if PowerShell is available on the system.
 */
export declare function checkPowerShellAvailability(): Promise<boolean>;
//# sourceMappingURL=powershell.d.ts.map