# phonelink-mcp-server

MCP server that reads and interacts with the **Phone Link** (MyPhone) Windows app via UI Automation.  
Since Microsoft doesn't offer public APIs for Phone Link, this server scrapes the UI using PowerShell + .NET's `System.Windows.Automation`.

## Features

| Tool | Type | Description |
|------|------|-------------|
| `phonelink_get_status` | Read | Connection status + phone info |
| `phonelink_get_messages` | Read | List conversations or read a specific chat |
| `phonelink_get_calls` | Read | Call history (incoming/outgoing/missed) |
| `phonelink_get_notifications` | Read | Phone notifications |
| `phonelink_get_photos` | Read | Photo gallery metadata |
| `phonelink_inspect_ui` | Read | Debug: dump full UI automation tree |
| `phonelink_send_message` | Write | Send an SMS via the Phone Link UI |
| `phonelink_make_call` | Write | Initiate a phone call |
| `phonelink_launch_app` | Write | Launch Phone Link if not running |

## Requirements

- **Windows 10/11** with Phone Link installed and configured
- **Node.js** >= 18
- **PowerShell** (Windows PowerShell 5.1+ or PowerShell Core 7+)
- Phone connected and paired in Phone Link

## Setup

```bash
cd phonelink-mcp-server
npm install
npm run build
```

## Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "phonelink": {
      "command": "node",
      "args": ["C:/path/to/phonelink-mcp-server/dist/index.js"],
      "env": {
        "PHONELINK_PS_EXECUTABLE": "powershell.exe"
      }
    }
  }
}
```

> **Note**: Use `pwsh.exe` instead of `powershell.exe` if you have PowerShell Core installed (recommended for better performance).

## How It Works

```
Claude ←→ MCP (stdio) ←→ Node.js Server ←→ PowerShell Scripts ←→ UIAutomation ←→ Phone Link UI
```

1. Claude calls an MCP tool (e.g., `phonelink_get_messages`)
2. The Node.js server executes the corresponding PowerShell script
3. The PowerShell script uses .NET's `System.Windows.Automation` to:
   - Find the Phone Link window
   - Navigate to the correct tab
   - Traverse the UI element tree
   - Extract text, names, and metadata
4. Results are returned as JSON through the MCP protocol

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PHONELINK_PS_EXECUTABLE` | `powershell.exe` | PowerShell executable path |

## Troubleshooting

### "Phone Link window not found"
- Make sure Phone Link is running (use `phonelink_launch_app` first)
- Check that Phone Link's window title matches expected names. Use `phonelink_inspect_ui` to debug.
- The server searches for: "Phone Link", "Collegamento al telefono", "Il tuo telefono", "Your Phone"

### UI elements not found
- Phone Link updates may change the UI structure. Use `phonelink_inspect_ui` to see current elements.
- Try increasing `max_depth` in inspect_ui to find deeper elements.
- The PowerShell scripts include multi-language support (EN, IT, DE, ES) but your locale might use different strings.

### Slow responses
- UI Automation traversal can be slow, especially with high `max_depth`.
- Keep `max_depth` at 10-12 for most operations.
- The first call after launching Phone Link may be slower while the UI loads.

### Permission issues
- PowerShell must run with sufficient privileges to use UIAutomation.
- If running as a service, ensure the service account has access to the desktop session.

## Limitations

- **UI-dependent**: Changes to Phone Link's UI can break scraping. Use `inspect_ui` to adapt.
- **Single language per session**: Element names depend on the Windows display language.
- **No photo download**: The photos tool lists metadata but cannot export actual image files.
- **Sequential only**: Only one tool should run at a time (concurrent UI automation will conflict).
- **Foreground required**: Phone Link window must be visible (not minimized) for some operations.

## Development

```bash
npm run dev          # Watch mode
npm run build        # Build once
npm start            # Run server
```

## License

MIT
