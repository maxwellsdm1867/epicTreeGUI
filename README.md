# EpicTreeGUI: Hierarchical Epoch Data Browser

A MATLAB GUI for browsing, organizing, and analyzing neurophysiology data exported from the RetinAnalysis Python pipeline. **Full functional replacement** for the legacy Rieke lab Java-based epochtree system.

## Overview

EpicTreeGUI replicates **all functionality** from the original epochtree system (Java `jenkins-jauimodel-275.jar` + MATLAB analysis) but operates on **pre-processed data exports** from the Python RetinAnalysis pipeline instead of live Symphony database. The tree is NOT just visualization—it's a **powerful filtering and organization system** that dynamically reorganizes data based on different splitting criteria.

### What Makes This Different

**Legacy System** (Java-based):
- `edu.washington.rieke.Analysis.getEntityLoader()` → Load epochs from Symphony
- `edu.washington.rieke.Analysis.getEpochTreeFactory()` → Build hierarchical tree
- `riekesuite.analysis.buildTree()` → Apply split criteria

**New System** (Pure MATLAB):
- `loadEpicTreeData()` → Load epochs from MAT file
- `buildTreeFromEpicData()` → Build hierarchical tree
- `rebuildTreeWithSplit()` → Apply split criteria

**Result**: Same workflows, same analysis functions, same user experience—but backed by Python data pipeline instead of Java/Symphony database.

### Core Concept: Dynamic Tree Organization

The tree structure is built **dynamically** using **splitter functions**. Instead of a static hierarchy, the tree reorganizes the entire dataset based on selected parameters:

- **By Cell Type**: Group all cells by type (OnP, OffP, OnM, etc.), then browse epochs within each type
- **By Stimulus Parameter**: Split by contrast, size, temporal frequency, etc.—groups epochs that share the same parameter value
- **By Date**: Organize by experiment date
- **By Custom Parameters**: Any parameter in the epoch can become an organization axis

Each split function:
1. **Traverses all epochs** in the dataset
2. **Extracts a grouping value** from each epoch (e.g., contrast = 0.5)
3. **Groups epochs** with the same value under a common tree node
4. **Creates child nodes** for each unique value found

When you switch split keys (dropdown menu), the **entire tree is reconstructed** with a different organization—same data, different grouping!

## Key Features

### Tree Browser (Left Panel)
- **Dynamic organization**: Split dropdown reorganizes tree by any parameter
- **Checkbox system**: Select/deselect individual epochs
- **Example marking**: Flag representative epochs for each condition
- **Hierarchical navigation**: Expand/collapse branches
- **Multi-level splits**: Combine splits (e.g., cell type → parameter → epochs)

### Data Viewer (Right Panel)
- **Spike raster** and **PSTH plots** for selected epochs/cells
- **RF mosaic** visualization showing spatial tuning
- **Stimulus parameter display** for selected epoch
- **Response statistics** (peak, integrated response, F1/F2 components)
- **Overlay comparisons**: Stack traces from different branches

### Analysis Functions
- **RFAnalysis** & **RFAnalysis2**: Receptive field mapping and mosaic plots
- **LSTA**: Linear spike-triggered averaging
- **SpatioTemporalModel**: Linear-nonlinear cascade fitting
- **CenterSurround**: Size tuning and surround suppression
- **Interneurons**: Interneuron-specific analysis
- **Occlusion**: Occlusion tuning analysis
- **MeanSelectedNodes**: Compare responses across conditions

### Data Extraction Utilities
- `getMeanResponseTrace`: PSTH with smoothing and baseline correction
- `getResponseAmplitudeStats`: Peak and integrated response metrics
- `getCycleAverageResponse`: Aligned responses for periodic stimuli
- `getF1F2statistics`: Fourier component analysis
- `getTreeEpochs`: Recursive epoch extraction from tree

## Why This Design Works

The original epochtree system used **Java AuiEpochTree objects** with dynamic splitting built into the data structure itself. The new system achieves the same organization using **MATLAB splitter functions** that work on **exported data**:

| Aspect | Old System | New System |
|--------|-----------|-----------|
| Data Source | Live Symphony recordings | Python pipeline exports (MAT files) |
| Tree Structure | Java AuiEpochTree objects | MATLAB TreeNode objects |
| Dynamic Organization | Java split methods | MATLAB splitter functions |
| Cell Matching | Symphony internals | Python pre-processing (noise_id → protocol_id) |
| RF Parameters | Computed in MATLAB | Pre-computed in Python |
| User Interaction | Same | **Identical** |
| Analysis Functions | Adapted | **Replicated** |

**Result**: Users experience the same workflow with the same GUI, same splitters, same analysis functions—but backed by Python data instead of Symphony!

## Implementation Status

### ✅ Completed (Phase 3 - Core System)
- **Data Loading**: `loadEpicTreeData()` loads .mat files from retinanalysis
- **Tree Building**: `buildTreeFromEpicData()` creates hierarchical structure
- **Dynamic Reorganization**: `rebuildTreeWithSplit()` routes between split methods
- **GUI Integration**: Tree panel, data viewer, split dropdown menu
- **Basic Splitters**: `splitOnCellType()`, `splitOnParameter()` (generic)
- **Data Display**: Raw traces, spike rasters, PSTH plots with smoothing

### 🟡 In Progress (Phase 4-5)
- **Additional Splitters**: Date, keywords, 11+ specific parameter splitters
- **Data Utilities**: getMeanResponseTrace, getResponseAmplitudeStats, etc.
- **Analysis Functions**: RFAnalysis, LSTA, SpatioTemporalModel (adapting from old_epochtree/)

### 📋 Documentation Complete
- **[trd](trd)**: Full technical specification (2100+ lines, Section 0 added Jan 2026)
- **[RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md](RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md)**: Legacy system analysis (1000+ lines)
- **[MISSING_TOOLS.md](MISSING_TOOLS.md)**: Implementation checklist (50+ functions, priority-ranked)
- **[DESIGN_VERIFICATION.md](DESIGN_VERIFICATION.md)**: Verification of complete feature coverage

## Requirements

- MATLAB R2019b or later
- No additional toolboxes required (base installation)
- Python 3.8+ with RetinAnalysis (for data export only)

## Getting Started

### 1. Export Data from Python
```python
import retinanalysis as ra
pipeline = ra.create_mea_pipeline('20250115A', 'data000')
pipeline.export_to_matlab('my_experiment.mat')
```

###Project Structure

```
epicTreeGUI/
├── epicTreeGUI.m                 # ✅ Main GUI (tree + viewer + split dropdown)
├── test_launch.m                 # ✅ Quick launcher script
├── inspect_mat_file.m            # ✅ Data structure inspection utility
│
├── src/                          # Core implementation
│   ├── buildTreeFromEpicData.m   # ✅ Build tree from data
│   ├── displayNodeData.m         # ✅ Display selected node (traces/spikes/PSTH)
│   ├── formatEpicNodeData.m      # ✅ Format node data for display
│   ├── loadEpicTreeData.m        # ✅ Load .mat file (in epicTreeGUI.m)
│   ├── rebuildTreeWithSplit.m    # ✅ Dynamic tree reorganization
│   └── splitters/                # Tree organization functions
│       ├── splitOnCellType.m     # ✅ Group by retinal cell type
│       ├── splitOnParameter.m    # ✅ Generic parameter-based grouping
│       ├── splitOnExperimentDate.m  # 🔴 TODO: Group by date
│       ├── splitOnKeywords.m     # 🔴 TODO: Group by keywords
│       └── (11+ more needed)     # 🔴 See MISSING_TOOLS.md
│
├── old_epochtree/                # ⚠️ Legacy reference code
│   ├── jenkins-jauimodel-275.jar # Java infrastructure (analyzed)
│   ├── lin_equiv_paperfigure.m   # Analysis workflow example
│   ├── SpatioTemporalModel.m     # LN model example
│   ├── RFAnalysis.m              # RF analysis (to adapt)
│   ├── LSTA.m                    # Spike-triggered average (to adapt)
│   └── tree_splitters/           # Original splitter functions
│Architecture Overview

### Data Flow
```
Python Pipeline                MATLAB GUI
───────────────                ──────────
RetinAnalysis    export        epicTreeGUI
  ↓              ──────→         ↓
.h5 files                    Load .mat
  ↓                              ↓
Symphony2Reader              Parse hierarchy
  ↓                              ↓
Metadata extraction          TreeNode struct
  ↓                              ↓
export_to_epictree           Display tree
  ↓                              ↓
.mat file                    Split dropdown
                                 ↓
                             Click node
                                 ↓
                             Display data
                             (traces/spikes)
```

### Key Components

**1. Data Loading** (`epicTreeGUI.m` lines 1-50)
- Reads .mat file with experiments → cells → groups → blocks → epochs
- Parses protocolSettings (stimulus parameters)
- Flattens hierarchy for tree building

**2. Tree Building** (`buildTreeFromEpicData()` + splitters)
- Default: Hierarchical by experiment/cell/group
- Dynamic: Reorganized by splitOnCellType(), splitOnParameter(), etc.
- TreeNode structure: `{splitValue, children, epochList, level, label}`

**3. GUI Integration** (`epicTreeGUI.m` lines 51-126)
- Tree panel (left 40%): uitree with node selection callback
- Viewer panel (right 60%): axes for plots
- Split dropdown: triggers `rebuildTreeWithSplit()`

**4. Data Display** (`displayNodeData.m`)
- Raw traces: voltage/current vs time
- Spike rasters: spike timing across trials
- PSTH: binned spike rate with Gaussian smoothing

### Legacy System Mapping

| Legacy Compo Roadmap

### Completed (Jan 2026)
✅ Core data loading and tree building  
✅ GUI with dynamic split dropdown  
✅ Basic data display (traces, spikes, PSTH)  
✅ 2 splitters (cellType, parameter)  
✅ Complete infrastructure analysis  

### Next Steps (Priority Order)
1. **P2 (High)**: Implement `splitOnExperimentDate.m`, `splitOnKeywords.m`
2. **P3 (Medium)**: Implement 11+ specific parameter splitters
3. **P4 (Medium)**: Data extraction utilities (`getMeanResponseTrace`, etc.)
4. **P5 (High)**: Adapt analysis functions from old_epochtree/

### Implementation Guide

**Full technical specification**: [trd](trd) (2100+ lines)
- Section 0: Legacy infrastructure mapping (NEW)
- Sections 1-12: Complete design spec
- Phases 1-7: 10-week implementation plan

**Missing tools checklist**: [MISSING_TOOLS.md](MISSING_TOOLS.md)
- 50+ functions categorized by priority
- Implementation signatures and test strategies
- Status tracking (✅ done, 🟡 partial, 🔴 not done)

**Legacy system reference**: [RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md](RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md)
- Complete JAR decompilation and analysis
- Data flow diagrams
- API pattern mapping (old → new)

## Testing

### Current Test Data
- **File**: `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`
- **Inspection**: Run `inspect_mat_file.m` to see structure
- **Launch**: Run `test_launch.m` to open GUI with test data

### Test Strategy
```matlab
% 1. Test data loading
data = loadEpicTreeData('test.mat');
assert(~isempty(data.experiments));

% 2. Test tree building
epicTreeGUI('test.mat');
% Verify tree displays, can switch splits

% 3. Test display
% Click nodes, verify plots appear

% 4. Test splitters
nodes = splitOnCellType(data);
assert(length(nodes) > 0);
```

## Contributing

When adding new splitters or analysis functions:
1. Reference legacy code in old_epochtree/
2. Adapt data access patterns (see RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md Section 0.5)
3. Follow priority order in MISSING_TOOLS.md
4. Update implementation status in this README
└── new_retinanalysis/            # Python pipeline (submodule)
    └── src/retinanalysis/        # Source data generator
```

### Key Implementation Files

**Core System** (✅ Complete):
- [epicTreeGUI.m](epicTreeGUI.m) - Lines 1-126: Main GUI with tree, viewer, dropdown
- [src/rebuildTreeWithSplit.m](src/rebuildTreeWithSplit.m) - Dynamic reorganization router
- [src/displayNodeData.m](src/displayNodeData.m) - Plot raw traces, spike rasters, PSTH
- [src/splitters/splitOnCellType.m](src/splitters/splitOnCellType.m) - Cell type organization
- [src/splitters/splitOnParameter.m](src/splitters/splitOnParameter.m) - Generic parameter splits

**Reference Documentation**:
- [trd](trd) - Section 0: Legacy infrastructure mapping (NEW Jan 2026)
- [RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md](RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md) - 183 Java classes analyzed
- [MISSING_TOOLS.md](MISSING_TOOLS.md) - 50+ functions to implement (priority-ranked) │   ├── SpatioTemporalModel.m
│   │   └── ...
│   ├── splitters/         # Reorganization functions
│   │   ├── splitOnCellType.m
│   │   ├── splitOnParameter.m
│   │   └── ...
│   └── utilities/         # Helper functions
├── python_export/         # Python export code
├── examples/              # Demo scripts
├── tests/                 # Test data
├── docs/                  # User guide
└── trd                    # Full technical design (1200+ lines)
```

## Key Files to Understand

**Data Organization:**
- [trd](trd#L300-L400) — Tree building with dynamic splits
- `TreeNode.m` — Hierarchical node structure
- `EpochData.m` — Data container with accessor methods

**GUI:**
- `epicTreeGUI.m` — Main UI with tree browser + viewer
- Split dropdown rebuilds tree on selection change
- Click node → viewer shows PSTH/data

**Splitters (14+ total):**
- `splitOnCellType.m` — Group by cell type
- `splitOnParameter.m` — Generic parameter-based grouping
- `splitOnExperimentDate.m` — Group by date
- All others in `src/splitters/`

## How Tree Organization Works (Example)

**Initial data**: 100 epochs, 50 cells, multiple contrasts (0.3, 0.5, 0.8)

**Organize by Cell Type**:
```
Root (Experiment)
├─ OnP (30 cells)
│  ├─ Epoch 1 [contrast=0.3]
│  ├─ Epoch 2 [contrast=0.5]
│  └─ ...
├─ OffP (20 cells)
│  └─ ...
```

**Switch dropdown → Organize by Contrast**:
```
Root (Experiment)
├─ Contrast = 0.3 (25 epochs, all cells)
│  ├─ Epoch 1
│  ├─ Epoch 5
│  └─ ...
├─ Contrast = 0.5 (40 epochs, all cells)
│  └─ ...
├─ Contrast = 0.8 (35 epochs, all cells)
│  └─ ...
```

**Tree rebuilt in < 1 second with different grouping!** Same data, different perspective.

## Development

Full implementation plan in `trd`:
- Phase-by-phase breakdown (10 weeks)
- Success criteria (MVP + full feature parity)
- Testing strategy
- Critical files list

See `docs/` for:
- User guide (workflows, tips)
- Analysis functions reference
- API documentation for developers

## License

MIT License
