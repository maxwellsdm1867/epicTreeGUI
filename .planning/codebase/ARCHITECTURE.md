# Architecture

**Analysis Date:** 2026-02-06

## Pattern Overview

**Overall:** Hierarchical Data Browser with Dynamic Tree Reorganization

**Key Characteristics:**
- Model-View separation with `epicTreeTools` (data model) and `epicGraphicalTree` (visualization)
- Dynamic tree restructuring based on pluggable splitter functions
- Lazy-loading pattern for response data via H5 files
- Pre-built tree pattern (no runtime reorganization in GUI)
- Selection-aware data extraction through centralized `getSelectedData()` function

## Layers

**Data Model Layer:**
- Purpose: Organize and manage epoch hierarchy
- Location: `src/tree/epicTreeTools.m`
- Contains: Tree node structure, hierarchical organization, custom property storage
- Depends on: None (pure MATLAB)
- Used by: epicTreeGUI, analysis functions, splitter functions

**Data Loading Layer:**
- Purpose: Load and flatten epoch data from various sources
- Location: `src/loadEpicTreeData.m`, `src/getResponseMatrix.m`, `src/loadH5ResponseData.m`
- Contains: File I/O, format validation, data extraction, H5 lazy loading
- Depends on: epicTreeTools
- Used by: START_HERE.m, test scripts, GUI initialization

**Splitting/Organization Layer:**
- Purpose: Dynamically split epochs into tree nodes using custom criteria
- Location: `src/splitters/` (splitOnCellType.m, splitOnParameter.m, splitOnProtocol.m, etc.)
- Contains: Splitter functions (14+ implementations)
- Depends on: epicTreeTools
- Used by: `buildTreeWithSplitters()` in epicTreeTools

**Visualization Layer:**
- Purpose: Render tree structure with expand/collapse, selection, keyboard navigation
- Location: `src/gui/epicGraphicalTree.m`, `src/gui/epicGraphicalTreeNode.m`, `src/gui/epicGraphicalTreeNodeWidget.m`
- Contains: Graphics objects, interaction handlers, visual state management
- Depends on: epicTreeTools (links to userData property)
- Used by: epicTreeGUI

**GUI Controller Layer:**
- Purpose: Orchestrate all UI components and manage user interactions
- Location: `epicTreeGUI.m`
- Contains: Figure management, panel layout, event handlers, menu definitions
- Depends on: epicTreeTools, epicGraphicalTree, getSelectedData, analysis functions
- Used by: End user (main entry point)

**Analysis Layer:**
- Purpose: Extract and process selected epoch data
- Location: `src/analysis/getMeanResponseTrace.m`, `src/analysis/getResponseAmplitudeStats.m`, `src/analysis/getLinearFilterAndPrediction.m`
- Contains: Signal processing, statistics, filtering operations
- Depends on: getSelectedData
- Used by: GUI menu callbacks, scripted analysis workflows

## Data Flow

**Initialization Flow:**

1. User calls `loadEpicTreeData('data.mat')`
   - Validates format_version field
   - Extracts experiments array and metadata
   - Returns hierarchical structure with epoch metadata (NO response data)

2. User creates `epicTreeTools(data)`
   - Constructor extracts flat epoch list via `extractAllEpochs()`
   - All epochs stored in `allEpochs` property at root node
   - Initial state: single leaf node containing all epochs

3. User calls `tree.buildTreeWithSplitters({@epicTreeTools.splitOnCellType, ...})`
   - Each splitter function receives epoch array
   - Splitter extracts split key (e.g., cell type) from each epoch
   - Organizes epochs into groups with same split value
   - Creates child nodes recursively for next splitter in chain
   - Final level contains leaf nodes with `epochList` property

4. User creates `epicTreeGUI(tree)`
   - GUI caches `tree.allEpochs` (metadata-only epoch list)
   - Creates epicGraphicalTree in left panel
   - Renders tree structure with expand/collapse buttons
   - Each graphicalTreeNode has `userData` link to corresponding epicTreeTools node

**Selection and Data Retrieval Flow:**

1. User checks checkbox on tree node or clicks epoch
   - epicGraphicalTree callback updates node's `isChecked` property
   - Triggers `nodeBecameCheckedFcn` callback in epicTreeGUI
   - epicTreeGUI calls `setSelected(flag, recursive)` on corresponding epicTreeTools node

2. User clicks leaf node or protocol node
   - GUI calls `singleEpoch(treeNode, panel)` or analysis function
   - Analysis function receives treeNode and calls `getSelectedData(treeNode, 'Amp1')`
   - getSelectedData flow:
     a. Calls `treeNode.getAllEpochs(false)` → gets all epochs under node
     b. Filters by `epoch.isSelected == true` field
     c. Returns only selected epoch structs

3. Response data is loaded on-demand
   - If H5 file configured, `getResponseMatrix()` lazy-loads from disk
   - Data extracted only for selected epochs (memory efficient)
   - Returns `[dataMatrix, selectedEpochs, sampleRate]`

4. Analysis functions process selected data
   - `getMeanResponseTrace()` computes mean ± SEM
   - Results can be stored back at node: `treeNode.putCustom('results', data)`
   - Later retrieval: `treeNode.getCustom('results')`

**State Management:**

**Tree Node State** (epicTreeTools):
- `isSelected` (custom property) - Selection state for filtering in analysis
- `custom` struct - Arbitrary analysis results storage via putCustom/getCustom
- `epochList` - Actual epoch struct array at leaf nodes
- `children` - Child nodes at internal levels

**Graphics Node State** (epicGraphicalTree):
- `isExpanded` - Whether tree node is visually expanded
- `isChecked` - Whether node's checkbox is ticked
- `userData` - Link to corresponding epicTreeTools node (synchronization point)

**Epoch Struct Fields** (critical for filtering):
- `cellInfo` - Cell metadata (type, label, id)
- `parameters` / `protocolSettings` - Stimulus parameters (aliased for compatibility)
- `responses` - Array of response structures with device_name, data, spike_times, sample_rate
- `isSelected` - CRITICAL: Used by getSelectedData() to filter epochs
- `expInfo`, `groupInfo`, `blockInfo` - Parent hierarchy references (preserved from import)

## Key Abstractions

**epicTreeTools Node:**
- Purpose: Represents a level in the organizational hierarchy
- Examples: `src/tree/epicTreeTools.m` (class), tree instances created in START_HERE.m
- Pattern: Composite pattern - nodes have children or epochList, uniform interface via `childAt()`, `getAllEpochs()`

**Splitter Function:**
- Purpose: Maps from raw epochs to split values (grouping key)
- Examples: `@epicTreeTools.splitOnCellType`, `@epicTreeTools.splitOnProtocol` (static methods in epicTreeTools.m)
- Pattern: Strategy pattern - pluggable organizational schemes via function handles or key paths

**Graphical Tree Synchronization:**
- Purpose: Keep visual tree (epicGraphicalTree) in sync with data tree (epicTreeTools)
- Example: Each epicGraphicalTreeNode has `userData` pointing to epicTreeTools node
- Pattern: Observer with property linking - checkbox changes trigger callbacks that update epicTreeTools.isSelected

## Entry Points

**Script Entry** (`START_HERE.m`):
- Location: `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/START_HERE.m`
- Triggers: Loads config, data, builds tree, launches GUI
- Responsibilities: Complete initialization from file to interactive GUI

**GUI Entry** (`epicTreeGUI` Constructor):
- Location: `epicTreeGUI.m` line 51-90
- Triggers: Accepts pre-built epicTreeTools object
- Responsibilities: Create figure, panels, graphicalTree, initialize UI state

**Test Entry** (Test scripts):
- Location: `tests/test_*.m` (20 test scripts)
- Triggers: Various unit and integration tests
- Responsibilities: Validate tree navigation, splitters, GUI display, H5 loading

## Error Handling

**Strategy:** Silent degradation with warnings + graceful empty-state UI

**Patterns:**
- File loading: `try-catch` with informative error messages (loadEpicTreeData.m line 37-41)
- Missing fields: Backward compatibility checks (e.g., `isSelected` field defaults to true if missing in getSelectedData.m line 70-76)
- Empty data: Check for empty array and return early with warning (epicTreeTools.m line 147-150)
- H5 lazy loading: Fallback behavior if H5 file not found or H5 section missing
- Tree building: Validates node has data before recursing (buildTreeRecursive checks isempty)

## Cross-Cutting Concerns

**Logging:** Console output via `fprintf()` in entry points (START_HERE.m, loadEpicTreeData.m)
- No logging framework used - direct MATLAB console
- Critical messages marked with ✓ checkmark (START_HERE.m)
- Data summaries printed during load (line 72-73)

**Validation:** Format version checking in loadEpicTreeData.m (line 44-56)
- Validates required fields: format_version, experiments
- Warns on version mismatch
- Continues gracefully with warning rather than error

**Authentication:** None - single-user MATLAB scripts

**Data Compatibility:** Nested field aliasing for backward compatibility
- Parameters field can be accessed via either `parameters` or `protocolSettings`
- getNestedValue() handles both paths in epicTreeTools static methods
- Maintains compatibility with DataJoint and RetinAnalysis exports

**Configuration:** Centralized via `epicTreeConfig.m` (src/config/epicTreeConfig.m)
- Stores H5 directory path (required for lazy loading)
- Singleton pattern: `config = epicTreeConfig()` reads, `epicTreeConfig('key', value)` writes
- Loaded in GUI initialization (epicTreeGUI.m line 92-100)

---

*Architecture analysis: 2026-02-06*
