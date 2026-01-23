# EpicTreeGUI: Hierarchical Epoch Data Browser

A MATLAB GUI for browsing, organizing, and analyzing neurophysiology data exported from the RetinAnalysis Python pipeline.

## Overview

EpicTreeGUI replicates all functionality from the original epochtree system but operates on **pre-processed data exports** from the Python RetinAnalysis pipeline instead of live Java/Symphony data. The tree is NOT just visualization—it's a **powerful filtering and organization system** that dynamically reorganizes data based on different splitting criteria.

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

See `trd` file for complete technical specification (1200+ lines):
- **Week 1**: Python export (`.mat` and `.json`)
- **Weeks 2-4**: MATLAB data layer + GUI core
- **Weeks 5-8**: Analysis functions (8 major + 6 utilities)
- **Week 9**: Tree splitters (14+ functions)
- **Week 10**: Polish & documentation

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

### 2. Launch GUI in MATLAB
```matlab
gui = epicTreeGUI('my_experiment.mat');
```

### 3. Organize and Analyze
- Use dropdown to reorganize tree by different parameters
- Click tree nodes to view PSTH/raster
- Run analysis functions (RFAnalysis, LSTA, etc.)
- Flag example epochs for each condition
- Compare responses across conditions

## Structure

```
epicTreeGUI/
├── src/
│   ├── core/              # Data loading & tree structure
│   │   ├── EpochData.m
│   │   └── TreeNode.m
│   ├── gui/               # Main GUI
│   │   ├── epicTreeGUI.m
│   │   └── singleEpoch.m
│   ├── analysis/          # Analysis functions
│   │   ├── RFAnalysis.m
│   │   ├── LSTA.m
│   │   ├── SpatioTemporalModel.m
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
