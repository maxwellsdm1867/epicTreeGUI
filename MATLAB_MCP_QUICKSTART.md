# MATLAB MCP Server - Quick Start

## ✅ Setup Complete - Global Installation

The MATLAB MCP Core Server has been installed globally and is accessible from any project.

**Location:** `~/bin/matlab-mcp-core-server`
**Added to PATH:** Yes (in ~/.zshrc)

## 🚀 One-Line Setup (Run this in your terminal)

```bash
claude mcp add --transport stdio matlab ~/bin/matlab-mcp-core-server --matlab-root=/Applications/MATLAB_R2022a.app --initialize-matlab-on-startup=true
```

**If that doesn't work,** see [MATLAB_MCP_SETUP.md](MATLAB_MCP_SETUP.md) for manual configuration.

## 📋 Quick Commands

Once configured, you can ask Claude to:

### Run MATLAB Code
```
"Run this MATLAB code: disp('Hello from MATLAB')"
```

### Execute a Script
```
"Run the MATLAB script examples/test_data_loading.m"
```

### Check Code Quality
```
"Check the code quality of examples/test_data_loading.m"
```

### List Toolboxes
```
"What MATLAB toolboxes do I have installed?"
```

## 🎯 For EpicTreeGUI Project

### Test Exported Data
```
"Run examples/test_data_loading.m to verify the Python export data"
```

### Create MATLAB Classes
```
"Create the EpochData class according to the TRD specification"
```

### Run Unit Tests
```
"Run MATLAB tests for the EpochData class"
```

## 📁 File Locations

- **Server Binary:** `~/bin/matlab-mcp-core-server` (globally accessible)
- **MATLAB:** `/Applications/MATLAB_R2022a.app`
- **Added to PATH:** `~/bin` in `~/.zshrc`
- **Test Data:** `python_export/test_exports/test_export.mat`

## ✨ What You Can Do Now

With the MATLAB MCP server configured, you can:

1. **Execute MATLAB Code Directly** - No need to manually run scripts
2. **Test Phase 2 Code** - Build and test EpochData.m and TreeNode.m
3. **Validate Exports** - Run test_data_loading.m automatically
4. **Quality Checks** - Get automatic code analysis
5. **Iterate Faster** - Build, test, debug all in conversation

## 🔄 Next Steps for Phase 2

1. ✅ Python export complete and tested
2. ➡️ **Create EpochData.m** - MATLAB data container class
3. ➡️ **Create TreeNode.m** - Hierarchical tree structure
4. ➡️ **Test with real data** - Verify with exported .mat files

---

See [MATLAB_MCP_SETUP.md](MATLAB_MCP_SETUP.md) for detailed configuration options.
