import { execFile } from "node:child_process";
import { join } from "node:path";
import { SCRIPTS_DIR, PS_EXECUTABLE, PS_TIMEOUT_MS } from "../constants.js";

export interface PsExecResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
}

type ExecFileError = NodeJS.ErrnoException & {
  code?: number | string;
  killed?: boolean;
  signal?: NodeJS.Signals | string | null;
};

type JsonObject = Record<string, unknown>;

function formatPowerShellFailure(
  scriptName: string,
  error: ExecFileError | null,
  stderr: string
): string {
  const details: string[] = [];

  if (error?.message) {
    details.push(error.message);
  }

  if (error?.code === "ENOENT") {
    details.push(`PowerShell executable not found: ${PS_EXECUTABLE}`);
  }

  if (error?.killed || /timed out/i.test(error?.message ?? "")) {
    details.push("Execution timed out");
  }

  if (error?.signal) {
    details.push(`Signal: ${String(error.signal)}`);
  }

  const stderrText = stderr.trim();
  if (stderrText) {
    details.push(`Stderr: ${stderrText.slice(0, 2000)}`);
  }

  const suffix = details.length > 0 ? ` ${details.join(". ")}` : "";
  return `PowerShell script "${scriptName}" failed.${suffix}`;
}

function stripBom(value: string): string {
  return value.replace(/^\uFEFF/, "");
}

function extractJsonEnvelope(raw: string): string {
  const start = raw.search(/[{\[]/);
  if (start === -1) {
    return raw;
  }

  const opener = raw[start];
  const closer = opener === "{" ? "}" : "]";

  let depth = 0;
  let inString = false;
  let escaping = false;

  for (let index = start; index < raw.length; index += 1) {
    const char = raw[index];

    if (inString) {
      if (escaping) {
        escaping = false;
        continue;
      }

      if (char === "\\") {
        escaping = true;
        continue;
      }

      if (char === "\"") {
        inString = false;
      }
      continue;
    }

    if (char === "\"") {
      inString = true;
      continue;
    }

    if (char === opener) {
      depth += 1;
      continue;
    }

    if (char === closer) {
      depth -= 1;
      if (depth === 0) {
        return raw.slice(start, index + 1);
      }
    }
  }

  return raw.slice(start);
}

function escapeControlCharactersInJsonStrings(input: string): string {
  let output = "";
  let inString = false;
  let escaping = false;

  for (const char of input) {
    const codePoint = char.codePointAt(0) ?? 0;

    if (inString) {
      if (escaping) {
        output += char;
        escaping = false;
        continue;
      }

      if (char === "\\") {
        output += char;
        escaping = true;
        continue;
      }

      if (char === "\"") {
        output += char;
        inString = false;
        continue;
      }

      if (codePoint < 0x20) {
        output += `\\u${codePoint.toString(16).padStart(4, "0")}`;
        continue;
      }
    } else if (char === "\"") {
      inString = true;
    }

    output += char;
  }

  return output;
}

function removeTrailingCommas(input: string): string {
  return input.replace(/,\s*([}\]])/g, "$1");
}

function isJsonObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isHashtablePayload(value: JsonObject): value is JsonObject & { Keys: unknown[]; Values: unknown[] } {
  if (!Array.isArray(value.Keys) || !Array.isArray(value.Values) || value.Keys.length !== value.Values.length) {
    return false;
  }

  const allowedKeys = new Set([
    "Count",
    "IsFixedSize",
    "IsReadOnly",
    "IsSynchronized",
    "Keys",
    "SyncRoot",
    "Values",
  ]);

  return Object.keys(value).every((key) => allowedKeys.has(key));
}

function normalizeParsedPowerShellJson<T>(value: T): T {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeParsedPowerShellJson(item)) as T;
  }

  if (!isJsonObject(value)) {
    return value;
  }

  if (isHashtablePayload(value)) {
    const rebuilt: JsonObject = {};
    value.Keys.forEach((key, index) => {
      rebuilt[String(key)] = normalizeParsedPowerShellJson(value.Values[index]);
    });
    return rebuilt as T;
  }

  const normalizedEntries = Object.entries(value).map(([key, entryValue]) => [
    key,
    normalizeParsedPowerShellJson(entryValue),
  ]);

  return Object.fromEntries(normalizedEntries) as T;
}

/**
 * Executes a PowerShell script from the scripts directory and returns raw output.
 */
export async function runPowerShellScript(
  scriptName: string,
  args: Record<string, string | number | boolean> = {},
  timeoutMs: number = PS_TIMEOUT_MS
): Promise<PsExecResult> {
  const scriptPath = join(SCRIPTS_DIR, scriptName);

  const psArgs: string[] = [
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    scriptPath,
  ];

  for (const [key, value] of Object.entries(args)) {
    if (typeof value === "boolean") {
      psArgs.push(`-${key}:${value}`);
    } else {
      psArgs.push(`-${key}`, String(value));
    }
  }

  return new Promise<PsExecResult>((resolve, reject) => {
    const child = execFile(
      PS_EXECUTABLE,
      psArgs,
      {
        encoding: "utf8",
        timeout: timeoutMs,
        maxBuffer: 10 * 1024 * 1024,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        const execError = (error as ExecFileError | null) ?? null;
        const stdoutText = stdout?.toString() ?? "";
        const stderrText = stderr?.toString() ?? "";

        if (execError && !stdoutText.trim()) {
          reject(new Error(formatPowerShellFailure(scriptName, execError, stderrText)));
          return;
        }

        resolve({
          stdout: stdoutText,
          stderr: stderrText,
          exitCode: typeof execError?.code === "number" ? execError.code : execError ? 1 : 0,
        });
      }
    );

    const timer = setTimeout(() => {
      child.kill("SIGTERM");
    }, timeoutMs + 5_000);

    child.on("close", () => clearTimeout(timer));
  });
}

/**
 * Executes a PowerShell script and parses its JSON output.
 * Returns the parsed object or throws on failure.
 */
export async function runPowerShellJson<T>(
  scriptName: string,
  args: Record<string, string | number | boolean> = {},
  timeoutMs: number = PS_TIMEOUT_MS
): Promise<T> {
  const result = await runPowerShellScript(scriptName, args, timeoutMs);

  const raw = stripBom(result.stdout).trim();
  if (!raw) {
    throw new Error(`Script "${scriptName}" returned empty output. Stderr: ${result.stderr.trim()}`);
  }

  const extracted = stripBom(extractJsonEnvelope(raw));
  const attempts = Array.from(
    new Set([
      extracted,
      escapeControlCharactersInJsonStrings(extracted),
      removeTrailingCommas(escapeControlCharactersInJsonStrings(extracted)),
    ])
  );

  let lastError: Error | undefined;

  for (const candidate of attempts) {
    try {
      const parsed = JSON.parse(candidate) as T;
      return normalizeParsedPowerShellJson(parsed);
    } catch (error) {
      lastError = error as Error;
    }
  }

  const stderrText = result.stderr.trim();
  const stderrSuffix = stderrText ? ` Stderr: ${stderrText.slice(0, 1000)}` : "";
  throw new Error(
    `Failed to parse JSON from "${scriptName}". ${lastError?.message ?? "Unknown parsing error."}${stderrSuffix} Raw output:\n${extracted.slice(0, 1000)}`
  );
}

/**
 * Checks if PowerShell is available on the system.
 */
export async function checkPowerShellAvailability(): Promise<boolean> {
  try {
    return await new Promise((resolve) => {
      execFile(
        PS_EXECUTABLE,
        [
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); Write-Output ok",
        ],
        { encoding: "utf8", timeout: 5_000, windowsHide: true },
        (error, stdout) => {
          resolve(!error && stdout.trim() === "ok");
        }
      );
    });
  } catch {
    return false;
  }
}
