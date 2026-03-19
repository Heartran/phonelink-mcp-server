import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
/** Root directory of the project (one level up from dist/) */
export const PROJECT_ROOT = join(__dirname, "..");
/** Path to the PowerShell scripts directory */
export const SCRIPTS_DIR = join(PROJECT_ROOT, "scripts");
/** Max characters for a single tool response */
export const CHARACTER_LIMIT = 50_000;
/** Default PowerShell execution timeout (ms) */
export const PS_TIMEOUT_MS = 30_000;
/** PowerShell executable name — pwsh (PS Core) preferred, fallback to powershell */
export const PS_EXECUTABLE = process.env.PHONELINK_PS_EXECUTABLE ?? "powershell.exe";
//# sourceMappingURL=constants.js.map