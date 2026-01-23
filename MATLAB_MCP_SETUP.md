# MATLAB MCP Server Setup Guide

## Overview

The MATLAB MCP (Model Context Protocol) Server enables direct MATLAB interaction from Claude Code, allowing you to:
- Execute MATLAB code directly
- Run MATLAB scripts and tests
- Check code quality
- Access MATLAB toolboxes

## Installation Status

✅ **Installed:** `~/bin/matlab-mcp-core-server` (8.3 MB, Apple Silicon)
✅ **Executable:** Permissions set
✅ **PATH:** Added to ~/.zshrc for global access
✅ **MATLAB Verified:** R2022a accessible at `/Applications/MATLAB_R2022a.app`

## Configuration

### Option 1: Add to Claude Code (Recommended)

If you're using Claude Code CLI, run this command in your terminal:

```bash
claude mcp add --transport stdio matlab \
  /Users/maxwellsdm/Downloads/matlab-mcp-core-server \
  --initial-working-folder=/Users/maxwellsdm/Documents/GitHub/epicTreeGUI
```

To verify the server was added:
```bash
claude mcp list
```

To remove it later:
```bash
claude mcp remove matlab
```

### Option 2: Manual Configuration

If the CLI command doesn't work, you can manually configure the MCP server.

**For Claude Desktop:**

Edit your Claude Desktop configuration file:
- Location: `~/Library/Application Support/Claude/claude_desktop_config.json`

Add this configuration:
```json
{
  "mcpServers": {
    "matlab": {
      "command": "/Users/maxwellsdm/bin/matlab-mcp-core-server",
      "args": [
        "--matlab-root=/Applications/MATLAB_R2022a.app",
        "--initialize-matlab-on-startup=true"
      ]
    }
  }
}
```

After saving, quit and restart Claude Desktop (File > Exit).

**For VS Code with GitHub Copilot:**

Create or edit `.vscode/mcp.json` in your project:
```json
{
  "servers": {
    "matlab": {
      "type": "stdio",
      "command": "/Users/maxwellsdm/bin/matlab-mcp-core-server",
      "args": [
        "--matlab-root=/Applications/MATLAB_R2022a.app",
        "--initialize-matlab-on-startup=true"
      ]
    }
  }
}
```

## Available Tools

Once configured, you'll have access to these MATLAB tools:

### 1. `detect_matlab_toolboxes`
Lists all installed MATLAB toolboxes with version info.

### 2. `check_matlab_code`
Static code analysis for MATLAB scripts (style, errors, performance).
- Input: `script_path` (absolute path to `.m` file)

### 3. `evaluate_matlab_code`
Execute MATLAB code and return output.
- Inputs:
  - `code`: MATLAB code string
  - `project_path`: Working directory

### 4. `run_matlab_file`
Execute a MATLAB script file.
- Input: `script_path` (absolute path to `.m` file)

### 5. `run_matlab_test_file`
Run MATLAB unit tests and return results.
- Input: `script_path` (absolute path to test `.m` file)

## Testing the Setup

### Test 1: Check MATLAB Installation

Run in terminal:
```bash
/Applications/MATLAB_R2022a.app/bin/matlab -batch "disp('MATLAB OK'); ver"
```

Expected: Should display MATLAB version and toolboxes.

### Test 2: Test MCP Server Manually

Run the server in test mode:
```bash
~/Downloads/matlab-mcp-core-server --help
```

### Test 3: Verify from Claude

Once configured, ask Claude to:
1. "List my MATLAB toolboxes"
2. "Run this MATLAB code: disp('Hello from MATLAB')"
3. "Check the code quality of test_data_loading.m"

## Configuration Arguments

You can customize the server with these optional arguments:

| Argument | Description | Example |
|----------|-------------|---------|
| `--matlab-root` | Path to specific MATLAB installation | `--matlab-root=/Applications/MATLAB_R2022a.app` |
| `--initialize-matlab-on-startup` | Start MATLAB immediately | `--initialize-matlab-on-startup=true` |
| `--initial-working-folder` | MATLAB startup directory | `--initial-working-folder=/path/to/project` |
| `--disable-telemetry` | Disable anonymous data collection | `--disable-telemetry=true` |

## Your Configuration

**Recommended settings (global, works for all projects):**

```bash
claude mcp add --transport stdio matlab \
  ~/bin/matlab-mcp-core-server \
  --matlab-root=/Applications/MATLAB_R2022a.app \
  --initialize-matlab-on-startup=true
```

## Troubleshooting

### MATLAB Not Found
If MATLAB can't be found, add it to PATH or use `--matlab-root`:
```bash
export PATH="/Applications/MATLAB_R2022a.app/bin:$PATH"
```

### Permission Denied
Ensure the server binary is executable:
```bash
chmod +x ~/Downloads/matlab-mcp-core-server
```

### Server Not Responding
Check that MATLAB license is valid:
```bash
/Applications/MATLAB_R2022a.app/bin/matlab -batch "license"
```

## Resources Available

The MCP server provides these coding resources:

1. **MATLAB Coding Guidelines** (`guidelines://coding`)
   - Best practices for MATLAB code
   - Naming conventions and formatting

2. **Plain Text Live Code Guidelines** (`guidelines://plain-text-live-code`)
   - For MATLAB R2025a+ live scripts
   - Version control friendly format

## Next Steps

1. Configure the MCP server using Option 1 or 2 above
2. Restart Claude Desktop/VS Code
3. Test by asking Claude to run MATLAB code
4. Use for Phase 2: Building MATLAB Data Layer
   - Test EpochData.m class
   - Test TreeNode.m class
   - Run MATLAB unit tests

## Security Notes

- Always review tool calls before execution
- Keep human in the loop for important actions
- Server is for Personal Automation Server use only

---

**Repository:** https://github.com/matlab/matlab-mcp-core-server
**Documentation:** See README.md in matlab-mcp-core-server/
**Setup Date:** 2025-01-23
