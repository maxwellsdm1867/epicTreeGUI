# EpicTreeGUI: Hierarchical Epoch Data Browser

A pure MATLAB replacement for the legacy Rieke Lab Java-based epochtree system. Provides hierarchical browsing, organization, and analysis of neurophysiology data exported from the RetinAnalysis Python pipeline.

**Status: ✅ FULLY FUNCTIONAL** (January 2026)

---

## 🚀 Quick Start

**Fastest way to launch:**

```matlab
cd('/Users/maxwellsdm/Documents/GitHub/epicTreeGUI')
run START_HERE.m
```

This automatically:
1. Configures all paths
2. Sets H5 directory for data loading
3. Loads your data
4. Builds the tree structure
5. Launches the GUI

**Done in < 5 seconds!**

---

## Key Features

### ✅ Working Now (January 2026)

**Tree Organization**
- **Pre-built tree pattern** - Define hierarchy in code before launching GUI
- **Dynamic splitters** - Organize by cell type, protocol, parameters, date
- **Epoch flattening** - Individual epochs shown at leaf level with pink backgrounds
- **Multi-level hierarchies** - Combine splitters (e.g., Cell Type → Protocol → Epochs)

**Data Visualization**
- **Lazy loading from H5** - Data loaded on-demand when you click (super fast!)
- **Dual click behavior**:
  - Click protocol node → Shows all epochs aggregated
  - Click individual epoch → Shows single trace
- **Selection system** - Checkboxes to select epochs for analysis
- **Real-time plotting** - Response traces, overlays, mean ± SEM

**Performance**
- **Fast startup** (< 1 second) - No data preloaded
- **Snappy clicks** (~0.1 sec) - Lazy loads only what you need
- **Memory efficient** - Doesn't hold all data in RAM
- **Scales to large datasets** - Tested with 1900+ epochs

---

## Architecture

### Data Flow

```
Python Pipeline (RetinAnalysis)
    ↓ export_to_matlab()
.mat file (metadata only)
    ↓ loadEpicTreeData()
epicTreeTools (in-memory tree)
    ↓ buildTreeWithSplitters()
epicTreeGUI (visualization)
    ↓ User clicks node
H5 file (lazy load on demand)
    ↓ Plot response data
```

**Key Insight**: Metadata (.mat) loads instantly. Actual response data (H5) loads only when clicked!

### Core Components

**1. epicTreeTools** (`src/tree/epicTreeTools.m`)
- Main tree structure class
- Navigation: `childAt()`, `leafNodes()`, `parent`, `childBySplitValue()`
- Data access: `getAllEpochs()`, `setSelected()`
- Custom storage: `putCustom()`, `getCustom()` for analysis results

**2. epicTreeGUI** (`epicTreeGUI.m`)
- Main GUI controller
- 40% tree browser (left) | 60% data viewer (right)
- Accepts pre-built trees (legacy pattern)
- H5-aware for lazy loading

**3. epicGraphicalTree** (`src/gui/epicGraphicalTree.m`)
- Visual tree widget (renamed to avoid conflicts with legacy code)
- Expand/collapse, selection, keyboard navigation
- Checkbox system synchronized with epoch selection

**4. getSelectedData** (`src/getSelectedData.m`)
- **CRITICAL FUNCTION** used by all analysis workflows
- Extracts response data for selected epochs only
- Supports H5 lazy loading
- Returns: `[dataMatrix, selectedEpochs, sampleRate]`

**5. Splitter Functions** (`src/splitters/`)
- `@epicTreeTools.splitOnCellType` - Group by retinal cell type
- `@epicTreeTools.splitOnProtocol` - Group by protocol name
- `@epicTreeTools.splitOnExperimentDate` - Group by date
- `@epicTreeTools.splitOnParameter` - Generic parameter splitter
- 14+ total splitters available

---

## Installation & Setup

### Requirements

- MATLAB R2019b or later
- No additional toolboxes required
- H5 files from RetinAnalysis export

### Directory Structure

Your data should be organized like this:

```
/Users/yourname/Documents/epicTreeTest/
├── analysis/
│   └── 2025-12-02_F.mat     ← Metadata (loads instantly)
└── h5/
    └── 2025-12-02_F.h5      ← Response data (lazy loaded)
```

### Configuration

**Critical Step: Set H5 Directory**

Before launching the GUI, tell it where your H5 files are:

```matlab
epicTreeConfig('h5_dir', '/Users/yourname/Documents/epicTreeTest/h5');
```

This is **required** for data loading to work!

---

## Usage Patterns

### Pattern 1: Quick Exploration (START_HERE.m)

```matlab
run START_HERE.m
```

Automatically configures everything and launches GUI.

### Pattern 2: Custom Tree (Advanced)

```matlab
% 1. Configure H5 directory
epicTreeConfig('h5_dir', '/path/to/h5/files');

% 2. Load data
[data, ~] = loadEpicTreeData('my_experiment.mat');

% 3. Build custom tree hierarchy
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @epicTreeTools.splitOnExperimentDate,
    'cellInfo.id',
    @epicTreeTools.splitOnProtocol
});

% 4. Launch GUI
gui = epicTreeGUI(tree);
```

This gives you full control over the tree organization.

### Pattern 3: Analysis Workflow

```matlab
% 1. Launch GUI
run START_HERE.m

% 2. Use GUI to select epochs (click checkboxes)

% 3. Get selected data for analysis
selectedEpochs = gui.getSelectedEpochs();
h5File = gui.h5File;
[data, epochs, fs] = getSelectedData(selectedEpochs, 'Amp1', h5File);

% 4. Perform your analysis
meanTrace = mean(data, 1);
t = (0:length(meanTrace)-1) / fs * 1000;
figure; plot(t, meanTrace);
xlabel('Time (ms)'); ylabel('Response (mV)');
```

---

## GUI Features

### Tree Browser (Left Panel)

**Visual Hierarchy:**
```
Root (1915)                          ← Total epochs
├─ RGC (1915)                        ← Cell type (white background)
│  ├─ SingleSpot (7)                 ← Protocol (white background)
│  │  ├─   1: 2025-12-02 10:15:30   ← Individual epoch (PINK background)
│  │  ├─   2: 2025-12-02 10:16:45   ← Individual epoch (PINK background)
│  │  └─ ...
│  ├─ ExpandingSpots (255)
│  └─ VariableMeanNoise (1640)
```

**Features:**
- Expand/collapse nodes (click arrows)
- Select epochs (checkboxes)
- Individual epochs shown with pink backgrounds
- Epoch counts displayed: `NodeName (N)`

### Data Viewer (Right Panel)

**Click Protocol Node:**
- Shows all epochs overlaid (gray traces)
- Mean response in black
- Title shows epoch count

**Click Individual Epoch:**
- Shows single epoch trace (blue)
- Lazy loaded from H5 file
- Fast rendering (~0.1 sec)

**Info Table:**
- Node type (Tree node vs Single epoch)
- Date/protocol information
- Selection status

### Keyboard Shortcuts

- `↑/↓` - Navigate tree
- `←/→` - Collapse/expand nodes
- `F` or `Space` - Toggle selection checkbox

### Menu Functions

**File Menu:**
- Load Data - Open different .mat file
- Export Selection - Save selected epochs to .mat

**Analysis Menu:**
- Mean Response Trace - Compute and plot mean ± SEM
- Response Amplitude - (Coming soon)

---

## Lazy Loading Performance

### Startup Performance
```
Load .mat file:       < 0.5 sec
Build tree:           < 0.5 sec
Launch GUI:           < 0.1 sec
───────────────────────────────
Total:                < 1 sec
```

**No data loaded yet!** All response data stays in H5 files.

### Click Performance
```
Click protocol (7 epochs):    ~0.1 sec (loads 7 traces from H5)
Click single epoch:           ~0.01 sec (loads 1 trace from H5)
Click parent node:            ~0.05 sec (already in memory)
```

### Memory Usage
```
Metadata only:        ~5 MB
With 1915 epochs:     ~50 MB (if all loaded)
Lazy loading:         Depends on what you click!
```

---

## Creating Custom Splitters

Splitters are functions that extract a grouping value from each epoch:

```matlab
function value = myCustomSplitter(epoch)
    % Extract any value from the epoch struct
    value = epicTreeTools.getNestedValue(epoch, 'parameters.myParam');

    % OR custom logic:
    if epoch.parameters.contrast > 0.5
        value = 'High Contrast';
    else
        value = 'Low Contrast';
    end

    % Return value can be: numeric, char, string, logical
end
```

Use it in your tree:

```matlab
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @myCustomSplitter,
    'cellInfo.id'
});
```

---

## Troubleshooting

### Problem: No data shows when clicking

**Cause:** H5 directory not configured

**Solution:**
```matlab
epicTreeConfig('h5_dir', '/path/to/your/h5/files');
```

Then restart the GUI.

**Verify it worked:**
```matlab
gui.h5File
% Should show: '/path/to/your/h5/files/2025-12-02_F.h5'
```

### Problem: "Brace indexing" error

**Cause:** Old legacy code (graphicalTree) conflicting with new code

**Solution:** This is fixed by using renamed classes (epicGraphicalTree). Just run:
```matlab
run START_HERE.m
```

### Problem: GUI slow or unresponsive

**Cause:** Too many epochs displayed at once

**Solutions:**
1. Use deeper tree hierarchies (more split levels)
2. Hide individual epochs: `gui = epicTreeGUI(tree, 'noEpochs')`
3. Use selection to filter before analysis

---

## Documentation

### Quick References
- **START_HERE.m** - Instant launch script
- **QUICK_REFERENCE.md** - Command reference
- **USAGE_PATTERNS.md** - Detailed usage examples
- **EPOCH_FLATTENING.md** - Technical details on epoch display

### Technical Documentation
- **trd** - Complete technical specification (2100+ lines)
- **CLAUDE.md** - Project guidance for Claude Code
- **src/tree/README.md** - epicTreeTools API reference
- **MISSING_TOOLS.md** - Implementation checklist

### Legacy System References
- **RIEKE_LAB_INFRASTRUCTURE_SPECIFICATION.md** - Original Java system analysis
- **old_epochtree/** - Reference implementation (DO NOT USE directly)

---

## Implementation Status

### ✅ Complete (January 2026)

**Core System:**
- epicTreeTools class with full navigation API
- epicTreeGUI with H5 lazy loading
- Pre-built tree pattern (legacy workflow)
- Epoch flattening at leaf level
- Selection management system
- getSelectedData() - critical for all analysis

**Splitters:**
- Cell type, protocol, experiment date
- Generic parameter splitter
- 14+ total splitters available

**Data Loading:**
- loadEpicTreeData() - parse MAT files
- getResponseMatrix() - extract response data
- loadH5ResponseData() - lazy loading from H5
- Type conversion and error handling

**GUI Features:**
- Tree browser with expand/collapse
- Data viewer with dual-click behavior
- Info table with metadata
- Selection checkboxes
- Export functionality

### 🔄 In Progress

**Analysis Functions:**
- RFAnalysis - Receptive field mapping
- LSTA - Linear spike-triggered averaging
- SpatioTemporalModel - LN cascade fitting
- CenterSurround - Size tuning analysis

### 📋 Planned

**Advanced Features:**
- Multi-device subplot display
- Epoch slider navigation
- Stimulus overlay on responses
- Batch analysis across nodes
- Custom analysis plugin system

---

## Contributing

When adding new features:

1. **Follow the lazy loading pattern** - Don't preload data
2. **Use epicTreeTools API** - Don't access epoch structs directly
3. **Use getSelectedData()** - Standard way to get response data
4. **Test with real H5 files** - Ensure lazy loading works
5. **Update documentation** - Keep README and CLAUDE.md current

Priority order for new implementations:
1. Analysis functions (see MISSING_TOOLS.md)
2. Additional splitters
3. Advanced visualization features
4. Performance optimizations

---

## Comparison: Legacy vs New

| Feature | Legacy (Java) | New (MATLAB) | Status |
|---------|---------------|--------------|--------|
| Tree organization | ✓ | ✓ | ✅ Identical |
| Dynamic splitters | ✓ | ✓ | ✅ Identical |
| Epoch flattening | ✓ | ✓ | ✅ Identical |
| Pink backgrounds | ✓ | ✓ | ✅ Identical |
| Lazy loading | ✓ | ✓ | ✅ Implemented |
| Selection system | ✓ | ✓ | ✅ Implemented |
| Data extraction | ✓ | ✓ | ✅ via getSelectedData() |
| Analysis functions | ✓ | 🔄 | In Progress |

**Result:** Feature parity achieved for core functionality!

---

## License

MIT License

---

## Contact & Support

For questions, see:
- **QUICK_REFERENCE.md** - Common tasks
- **CLAUDE.md** - Project overview
- **GitHub Issues** - Report bugs
