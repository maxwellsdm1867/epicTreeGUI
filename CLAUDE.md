# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EpicTreeGUI is a pure MATLAB replacement for the legacy Rieke Lab Java-based epochtree system. It provides a hierarchical browser for neurophysiology data exported from the RetinAnalysis Python pipeline. The tree is NOT just visualization—it's a **powerful filtering and organization system** that dynamically reorganizes data based on different splitting criteria.

**Key Concept:** The tree structure is built dynamically using splitter functions. Instead of a static hierarchy, the tree reorganizes the entire dataset based on selected parameters (e.g., by cell type, stimulus parameter, date).

## Running and Testing

### Launch GUI - Two Patterns

**Pattern 1: Simple file loading (dynamic splits)**
```matlab
% GUI with dropdown menu to change split configuration
gui = epicTreeGUI('data.mat');
```

**Pattern 2: Pre-built tree (legacy pattern - RECOMMENDED)**
```matlab
% Build tree structure in code first (matches legacy epochTreeGUI)
[data, ~] = loadEpicTreeData('data.mat');
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @epicTreeTools.splitOnExperimentDate,
    'cellInfo.id'
});
gui = epicTreeGUI(tree);  % NO dropdown - tree is fixed
```

**See `USAGE_PATTERNS.md` for detailed comparison.**

### Test Scripts
```matlab
% Pattern 1 - Simple exploration
run test_launch.m

% Pattern 2 - Legacy-style (RECOMMENDED)
run test_legacy_pattern.m
run test_exact_legacy_pattern.m

% Unit tests
run tests/test_tree_navigation.m
run tests/test_gui_display_data.m
run tests/test_tree_navigation_realdata.m
```

### Running Tests with MCP MATLAB Server

**IMPORTANT:** When asked to test MATLAB code or run test files, ALWAYS use the MCP MATLAB server tools instead of regular bash commands. This ensures proper execution in the MATLAB environment.

**Use MCP tools for:**
- Running test files: `mcp__matlab__run_matlab_test_file` with absolute path
- Executing MATLAB scripts: `mcp__matlab__run_matlab_file` with absolute path
- Evaluating MATLAB code: `mcp__matlab__evaluate_matlab_code` with project path
- Static code analysis: `mcp__matlab__check_matlab_code` with script path

**Example:**
```
When user asks: "test the tool" or "run tests"
Use: mcp__matlab__run_matlab_test_file with script_path: /Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/test_tree_navigation_realdata.m
NOT: Bash with matlab -batch command
```

The MCP server connects directly to an existing MATLAB session with the GUI visible, provides comprehensive test output, and properly handles MATLAB's testing framework.

### Test Data Location
Default test data: `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`

### Quick Inspection
```matlab
% Inspect MAT file structure
inspect_mat_file.m
```

## Architecture

### Data Flow
```
Python Pipeline (RetinAnalysis)
    ↓ export_to_matlab()
.mat file with hierarchy:
  experiments → cells → epoch_groups → epoch_blocks → epochs
    ↓ loadEpicTreeData()
Flattened epoch list
    ↓ epicTreeTools.buildTree()
Dynamic tree organized by split keys
    ↓ GUI display
Interactive browser + viewer
```

### Core Components

**1. epicTreeTools class (src/tree/epicTreeTools.m)**
- Hierarchical tree structure for organizing epochs
- Supports both key path splitting (`'cellInfo.type'`) and custom splitter functions (`@epicTreeTools.splitOnCellType`)
- Navigation: `childAt(i)`, `childBySplitValue(value)`, `leafNodes()`, `parent`, `parentAt(n)`
- Controlled access: `putCustom(key, value)`, `getCustom(key)` for storing analysis results at nodes
- Critical methods: `getAllEpochs(onlySelected)`, `setSelected()`, `epochCount()`, `selectedCount()`

**2. epicTreeGUI class (epicTreeGUI.m)**
- Main GUI controller integrating tree browser and data viewer
- 40% tree panel (left) + 60% viewer panel (right)
- **Two usage modes:**
  - Simple mode: Pass file path → shows split dropdown for dynamic reorganization
  - Legacy mode: Pass pre-built tree → NO dropdown, fixed structure (RECOMMENDED)
- Selection management with checkbox system
- Menu-driven analysis functions

**3. getSelectedData function (src/getSelectedData.m)**
- **THIS IS THE CRITICAL FUNCTION** used by ALL analysis workflows
- Input: epicTreeTools node OR cell array of epochs
- Filters to only epochs with `isSelected == true`
- Returns: `[dataMatrix, selectedEpochs, sampleRate]`
- Used by RFAnalysis, LSTA, SpatioTemporalModel, CenterSurround, etc.

**4. graphicalTree system (src/tree/graphicalTree/)**
- Visual tree rendering with checkboxes, expand/collapse, highlighting
- Handles user interaction (click, keyboard navigation)
- Syncs with epicTreeTools node states

### Key Data Structures

**Epoch struct fields:**
- `cellInfo`: Cell metadata (type, label, id)
- `parameters` / `protocolSettings`: Stimulus parameters (aliased for compatibility)
- `responses`: Array with `device_name`, `data`, `spike_times`, `sample_rate`
- `stimuli`: Stimulus waveforms
- `isSelected`: Selection flag (CRITICAL for filtering)
- `expInfo`, `groupInfo`, `blockInfo`: Parent hierarchy references

**Tree organization:**
- Root node contains all epochs in `allEpochs` property
- Internal nodes group epochs by split criteria
- Leaf nodes contain `epochList` with actual epoch structs
- Each node has `splitKey` and `splitValue` identifying its organization

## Implementation Patterns

### Tree Navigation Pattern
```matlab
% Build tree with multiple split levels
tree = epicTreeTools(data);
tree.buildTree({'cellInfo.type', 'parameters.contrast'});

% Navigate DOWN
for i = 1:tree.childrenLength()
    cellTypeNode = tree.childAt(i);
    cellType = cellTypeNode.splitValue;

    for j = 1:cellTypeNode.childrenLength()
        contrastNode = cellTypeNode.childAt(j);
        contrast = contrastNode.splitValue;

        % Analyze data at this condition
        [data, epochs, fs] = getSelectedData(contrastNode, 'Amp1');
        results = analyzeData(data, fs);

        % Store results at node
        contrastNode.putCustom('results', results);
    end
end

% Query stored results later
leaves = tree.leafNodes();
for i = 1:length(leaves)
    results = leaves{i}.getCustom('results');
    if ~isempty(results)
        % Process results
    end
end
```

### Custom Splitter Pattern
```matlab
% Use built-in splitters (static methods in epicTreeTools)
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @epicTreeTools.splitOnContrast
});

% Mix key paths and function handles
tree.buildTreeWithSplitters({
    'cellInfo.type',
    @epicTreeTools.splitOnF1F2Phase
});

% Splitter function signature
function value = splitOnMyParameter(epoch)
    value = epicTreeTools.getNestedValue(epoch, 'parameters.myParam');
    % OR custom logic
    if epoch.parameters.stimulus == 'flash'
        value = 'flash';
    else
        value = 'other';
    end
end
```

### Analysis Function Pattern
```matlab
function results = myAnalysisFunction(treeNode)
    % Get selected data
    [data, epochs, fs] = getSelectedData(treeNode, 'Amp1');

    if isempty(data)
        error('No selected data');
    end

    % Perform analysis
    meanTrace = mean(data, 1);
    peakResponse = max(meanTrace);

    % Package results
    results = struct();
    results.meanTrace = meanTrace;
    results.peakResponse = peakResponse;
    results.nEpochs = length(epochs);
    results.fs = fs;

    % Optional: Store at node
    treeNode.putCustom('myAnalysis', results);
end
```

### Selection Management
```matlab
% Select specific nodes
node.setSelected(true, false);        % This node only
node.setSelected(true, true);         % This node + all descendants

% Get selected epochs
selectedEpochs = tree.getAllEpochs(true);   % Only selected
allEpochs = tree.getAllEpochs(false);       % All epochs

% Check counts
nTotal = node.epochCount();
nSelected = node.selectedCount();
```

## Critical Functions to Know

**Tree navigation:**
- `childAt(i)` - Get child by 1-based index
- `childBySplitValue(value)` - Find child matching split value
- `leafNodes()` - Get all leaf nodes recursively
- `getAllEpochs(onlySelected)` - Flatten tree to epoch list

**Data access:**
- `getSelectedData(nodeOrEpochs, streamName)` - **Use this for all analysis**
- `epicTreeTools.getNestedValue(obj, keyPath)` - Access nested struct fields
- `epicTreeTools.getResponseData(epoch, deviceName)` - Low-level response access

**Node state:**
- `putCustom(key, value)` - Store analysis results
- `getCustom(key)` - Retrieve stored data
- `hasCustom(key)` - Check if key exists
- `setSelected(flag, recursive)` - Manage selection state

## File Organization

```
epicTreeGUI/
├── epicTreeGUI.m              # Main GUI class
├── test_launch.m              # Quick launcher
├── inspect_mat_file.m         # Data inspection
├── src/
│   ├── getSelectedData.m      # CRITICAL - data extraction
│   ├── loadEpicTreeData.m     # Load .mat files
│   ├── getResponseMatrix.m    # Low-level data matrix builder
│   ├── tree/
│   │   ├── epicTreeTools.m    # Core tree class
│   │   ├── README.md          # Tree usage guide
│   │   └── graphicalTree/     # Visual tree system
│   ├── splitters/
│   │   ├── splitOnCellType.m
│   │   ├── splitOnParameter.m
│   │   └── ...                # 14+ splitter functions
│   └── utilities/
├── tests/                     # Test scripts (run with 'run tests/test_*.m')
├── old_epochtree/             # Legacy reference code (DO NOT USE - for reference only)
└── docs/                      # Documentation
    ├── trd                    # Technical specification (2100+ lines)
    ├── MISSING_TOOLS.md       # Implementation checklist
    └── ...
```

## Important Notes

### DO NOT use old_epochtree/ code directly
The `old_epochtree/` directory contains legacy Java-based code for reference only. The new system uses pure MATLAB with different patterns:
- Old: `edu.washington.rieke.Analysis.*` (Java)
- New: `epicTreeTools`, `getSelectedData` (MATLAB)

### Selection state is CRITICAL
Always filter epochs using `getAllEpochs(true)` or `getSelectedData()` to respect user selections. Direct access to `epochList` bypasses selection filtering.

### Parameter field aliases
The code handles both `parameters` and `protocolSettings` field names for backward compatibility. Use `epicTreeTools.getNestedValue()` or let the system auto-alias.

### Splitter functions are static
Built-in splitters are static methods: `@epicTreeTools.splitOnCellType`, not instance methods.

### Tree rebuilding is fast
Switching split keys rebuilds the entire tree structure (typically <1 second). The same epochs are just reorganized with different grouping.

## Common Tasks

**Add a new splitter:**
1. Add static method to `epicTreeTools.m` following pattern at line 1542+
2. Function signature: `function V = splitOnMyParam(epoch)`
3. Extract value using `epicTreeTools.getParams(epoch)` or `getNestedValue()`
4. Return scalar value (numeric, string, logical)
5. Add to GUI dropdown in `epicTreeGUI.m` line 403-410

**Add a new analysis function:**
1. Follow pattern: accept `treeNode` or epoch list
2. Use `getSelectedData(node, streamName)` to get data
3. Store results with `node.putCustom('results', results)`
4. Add menu item in `epicTreeGUI.buildMenuBar()` if GUI integration needed

**Debug tree organization:**
```matlab
tree.buildTree({'cellInfo.type'});
fprintf('Children: %d\n', tree.childrenLength());
for i = 1:tree.childrenLength()
    child = tree.childAt(i);
    fprintf('  %s: %d epochs\n', string(child.splitValue), child.epochCount());
end
```

**Test with synthetic data:**
See `tests/test_tree_navigation.m` lines 29-109 for creating test data matching the expected format.
