# Codebase Structure

**Analysis Date:** 2026-02-06

## Directory Layout

```
epicTreeGUI/
├── START_HERE.m                    # Primary entry point - loads, builds tree, launches GUI
├── epicTreeGUI.m                   # Main GUI class (40% tree | 60% viewer)
├── CLAUDE.md                       # Instructions for Claude Code sessions
├── README.md                       # User documentation
├── DATA_FORMAT_SPECIFICATION.md    # Expected .mat file structure
│
├── src/
│   ├── loadEpicTreeData.m          # Load .mat files with format validation
│   ├── getSelectedData.m           # CRITICAL: Extract data for selected epochs
│   ├── getResponseMatrix.m         # Build response data matrix from epochs
│   ├── getTreeEpochs.m             # Flatten tree to epoch list
│   ├── buildTreeFromEpicData.m     # Legacy tree builder (for reference)
│   ├── displayNodeData.m           # Format node data for display
│   ├── formatEpicNodeData.m        # Epoch struct formatting utilities
│   │
│   ├── tree/
│   │   ├── epicTreeTools.m         # Core tree class (node structure, navigation)
│   │   ├── CompatibilityList.m     # Backward compatibility utilities
│   │   └── README.md               # Tree usage guide
│   │
│   ├── gui/
│   │   ├── epicGraphicalTree.m     # Main tree visualization component
│   │   ├── epicGraphicalTreeNode.m # Visual tree node (expand/collapse/checkbox)
│   │   ├── epicGraphicalTreeNodeWidget.m  # Rendered widget pool
│   │   ├── singleEpoch.m           # Epoch viewer with slider navigation
│   │   ├── graphicalTree.m         # Legacy tree widget (for reference)
│   │   ├── graphicalTreeNode.m     # Legacy node class (for reference)
│   │   └── graphicalTreeNodeWidget.m  # Legacy widget (for reference)
│   │
│   ├── splitters/
│   │   ├── splitOnCellType.m       # Group by retinal cell type
│   │   ├── splitOnParameter.m      # Generic parameter-based splitter
│   │   ├── splitOnRGCSubtype.m     # Group by RGC subtype
│   │   └── (14+ total splitters)   # Protocol, date, contrast, etc.
│   │
│   ├── analysis/
│   │   ├── getMeanResponseTrace.m  # Compute mean ± SEM response
│   │   ├── getResponseAmplitudeStats.m  # Peak, baseline, amplitude metrics
│   │   ├── getLinearFilterAndPrediction.m  # Spike-triggered average
│   │   ├── getCycleAverageResponse.m  # Cycle-averaged response
│   │   └── MeanSelectedNodes.m     # Legacy analysis function
│   │
│   ├── config/
│   │   ├── epicTreeConfig.m        # Configuration singleton (H5 directory)
│   │   └── getH5FilePath.m         # Resolve H5 file path from experiment
│   │
│   └── utilities/
│       └── (helper functions)
│
├── tests/
│   ├── test_tree_navigation.m      # Core tree navigation tests (unit)
│   ├── test_tree_navigation_realdata.m  # Navigation with real H5 data
│   ├── test_gui_display_data.m     # GUI data display tests (integration)
│   ├── test_legacy_pattern.m       # Legacy-style usage pattern tests
│   ├── test_exact_legacy_pattern.m # Strict legacy compatibility tests
│   ├── test_splitters.m            # Splitter function tests
│   ├── test_data_loading.m         # Data load validation tests
│   ├── test_h5_lazy_loading.m      # H5 lazy load functionality
│   └── test_*.m (15+ more)         # Additional test coverage
│
├── old_epochtree/                  # Legacy reference (DO NOT USE)
│   ├── LSTA.m
│   ├── RFAnalysis.m
│   ├── RFModel.m
│   └── common/                     # Legacy utilities (reference only)
│
├── python_export/                  # Python export utilities
│   ├── export_to_epictree.py       # Export from RetinAnalysis to .mat
│   ├── cell_type_names.py          # Cell type classification
│   └── test_cell_type_conversion.py
│
└── docs/
    ├── trd                         # Technical requirements doc (2100+ lines)
    ├── EPOCH_TREE_SYSTEM_COMPREHENSIVE_GUIDE.md
    └── (other specification docs)
```

## Directory Purposes

**src/ Root Files:**
- Purpose: Core functionality - loading, data extraction, tree building
- Contains: Entry point utilities, data pipeline functions
- Key files: `loadEpicTreeData.m` (input), `getSelectedData.m` (critical), `epicTreeTools.m` (model)

**src/tree/:**
- Purpose: Data model for hierarchical epoch organization
- Contains: epicTreeTools class (composite tree pattern), navigation methods, custom property storage
- Key files: `epicTreeTools.m` (450+ lines, core functionality)

**src/gui/:**
- Purpose: Visualization and user interaction
- Contains: epicGraphicalTree (visual rendering), singleEpoch (epoch viewer), node widgets
- Organization: Modern classes (epicGraphicalTree*) separate from legacy reference code (graphicalTree*)

**src/splitters/:**
- Purpose: Pluggable tree reorganization strategies
- Contains: Static method implementations for splitting epochs by different criteria
- Pattern: Each splitter extracts a value from epoch struct, groups matching epochs

**src/analysis/:**
- Purpose: Signal processing and statistical analysis on selected epochs
- Contains: Mean traces, amplitudes, filters, cycle averages
- Dependency: All use `getSelectedData()` to extract data respecting user selections

**src/config/:**
- Purpose: Runtime configuration management
- Contains: H5 directory path storage (singleton pattern)
- Critical: Must be configured before GUI launch for data loading

**tests/:**
- Purpose: Unit and integration test coverage
- Pattern: Test scripts use `run tests/test_*.m` syntax (not unittest framework)
- Organization: Grouped by functionality (navigation, display, splitters, data loading)

**old_epochtree/:**
- Purpose: Reference implementation of legacy Java-based system
- Status: DO NOT USE IN NEW CODE - for reference/learning only
- Contains: Legacy classes, analysis patterns, utilities from original epochtree system

## Key File Locations

**Entry Points:**
- `START_HERE.m`: Quickest way to launch - configures paths, loads data, builds tree, shows GUI
- `epicTreeGUI.m`: Main GUI class constructor - accepts pre-built tree object
- `tests/test_legacy_pattern.m`: Pattern matching legacy epochtree usage

**Configuration:**
- `src/config/epicTreeConfig.m`: Centralized config (H5 directory path)
- `CLAUDE.md`: Development instructions (paths, test commands, architecture patterns)
- `DATA_FORMAT_SPECIFICATION.md`: Expected .mat file structure (format_version, experiments, metadata)

**Core Logic:**
- `src/tree/epicTreeTools.m`: Main tree data structure (450+ lines)
  - `buildTreeWithSplitters()`: Organize epochs by custom criteria
  - `getAllEpochs()`: Flatten tree to selected/all epochs
  - Navigation: `childAt()`, `parent`, `childBySplitValue()`
  - Custom storage: `putCustom()`, `getCustom()` for analysis results

- `src/getSelectedData.m`: CRITICAL FUNCTION (used by all analysis)
  - Input: epicTreeTools node OR epoch array
  - Output: `[dataMatrix, selectedEpochs, sampleRate]`
  - Filtering: Only includes `isSelected == true` epochs

- `epicTreeGUI.m`: Main GUI orchestrator (350+ lines)
  - Constructor accepts pre-built epicTreeTools
  - Layout: 40% tree (left) | 60% viewer (right)
  - No dropdown menu (tree structure is fixed at launch)

**Testing:**
- `tests/test_tree_navigation.m`: Basic tree structure tests with synthetic data
- `tests/test_tree_navigation_realdata.m`: Real H5 data tests
- `tests/test_gui_display_data.m`: GUI rendering and interaction tests
- `tests/test_legacy_pattern.m`: Backward compatibility with original epochtree

**Visualization:**
- `src/gui/epicGraphicalTree.m`: Tree widget (expand/collapse, selection)
- `src/gui/singleEpoch.m`: Epoch viewer (info table, plot, slider navigation)

## Naming Conventions

**Files:**
- Classes: `epicTreeTools.m` (camelCase prefixed with 'epic')
- Functions: `loadEpicTreeData.m` (camelCase, descriptive verbs)
- Tests: `test_*.m` (test_ prefix, underscore-separated)
- Config: In `src/config/` directory with `Config` or `config` in filename

**Directories:**
- Functional grouping: `src/tree/`, `src/gui/`, `src/analysis/`, `src/splitters/`
- All lowercase, dash-separated: No dashes used, all lowercase single words

**Classes:**
- Prefixed with 'epic': `epicTreeTools`, `epicTreeGUI`, `epicGraphicalTree`
- Avoids conflicts with legacy code (`graphicalTree` for old code)

**Functions:**
- Start with verb when describing action: `load`, `get`, `build`, `format`, `display`
- Nested paths become underscores: `split_on_*` functions (camelCase in practice)

**Custom Properties** (in epicTreeTools):
- isSelected: Boolean flag for filtering in analysis
- splitKey, splitValue: Tree organization metadata
- epochList: Leaf node only - array of epoch structs
- children: Non-leaf nodes - cell array of child epicTreeTools
- allEpochs: Root node only - flat array of all epochs
- custom: Struct container for analysis results (hidden, access via putCustom/getCustom)

## Where to Add New Code

**New Feature (Tree Reorganization):**
- Create `src/splitters/splitOnMyParam.m` with signature: `function value = splitOnMyParam(epoch)`
- Add static method to epicTreeTools.m for consistency
- Use in `tree.buildTreeWithSplitters({@epicTreeTools.splitOnMyParam, ...})`
- Example pattern: Extract parameter value, group epochs with same value

**New Component/Module (Visualization):**
- Primary code: `src/gui/myComponent.m` (class or function)
- Tests: `tests/test_myComponent.m`
- Register in epicTreeGUI if GUI integration needed (line 350-400)

**New Analysis Function:**
- Primary code: `src/analysis/myAnalysis.m` (function)
- Function signature: `result = myAnalysis(epochListOrNode, streamName, varargin)`
- Use `getSelectedData()` for data extraction
- Tests: `tests/test_myAnalysis.m`
- If menu item needed: Add to `buildMenuBar()` in epicTreeGUI.m (line 320+)

**Utilities:**
- Shared helpers: `src/utilities/myHelper.m` or add to existing utility files
- Configuration: `src/config/` directory
- Keep implementation details out of src/gui/ (visualization-specific only)

## Special Directories

**old_epochtree/:**
- Purpose: Legacy reference implementation (DO NOT USE)
- Generated: No
- Committed: Yes
- Notes: Contains original Java-based epochtree code for reference. Modern implementation is in src/tree/ and src/gui/

**python_export/:**
- Purpose: Python tools for exporting data from RetinAnalysis to EpicTreeGUI format
- Generated: No (source code)
- Committed: Yes
- Uses: Converts DataJoint exports to .mat format expected by loadEpicTreeData()

**.planning/codebase/:**
- Purpose: Analysis documents for Claude Code sessions
- Generated: Yes (created by /gsd:map-codebase)
- Committed: No (excluded from git)
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

---

*Structure analysis: 2026-02-06*
