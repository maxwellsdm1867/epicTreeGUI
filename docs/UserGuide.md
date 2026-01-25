# EpicTreeGUI User Guide

A pure MATLAB GUI for browsing and analyzing epoch data.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Loading Data](#loading-data)
3. [Building Trees](#building-trees)
4. [Tree Navigation](#tree-navigation)
5. [Selection & Controlled Access](#selection--controlled-access)
6. [Data Retrieval](#data-retrieval)
7. [Analysis Functions](#analysis-functions)
8. [GUI Usage](#gui-usage)
9. [Common Workflows](#common-workflows)

---

## Getting Started

### Installation

1. Clone or download the epicTreeGUI repository
2. Add the src folder to your MATLAB path:

```matlab
addpath(genpath('/path/to/epicTreeGUI/src'));
```

### Requirements

- MATLAB R2020a or later
- No external toolboxes required (pure MATLAB)

### Quick Start

```matlab
% Configure H5 directory (if using H5 lazy loading)
epicTreeConfig('h5_dir', '/path/to/h5/files');

% Launch GUI
gui = epicTreeGUI('/path/to/data.mat');
```

---

## Loading Data

### Data Format

EpicTreeGUI works with `.mat` files conforming to the standard data format. See [DATA_FORMAT_SPECIFICATION.md](../DATA_FORMAT_SPECIFICATION.md) for details.

Basic structure:
```matlab
data.format_version = '1.0';
data.experiments{1}.cells{1}.epoch_groups{1}.epoch_blocks{1}.epochs{1}
```

### Loading with epicTreeTools

```matlab
% Load data file
data = load('experiment.mat');

% Create tree
tree = epicTreeTools(data);

% Check total epochs
allEpochs = tree.getAllEpochs(false);
fprintf('Loaded %d epochs\n', length(allEpochs));
```

### H5 Lazy Loading

For large datasets, response data can be lazy-loaded from H5 files:

```matlab
% Set H5 directory once per session
epicTreeConfig('h5_dir', '/Users/data/h5');

% Get H5 file path for an experiment
h5_file = getH5FilePath('2025-12-02_F');

% Data is loaded from H5 when needed
[data, epochs, fs] = getSelectedData(node, 'Amp1', h5_file);
```

---

## Building Trees

Trees organize epochs hierarchically by splitting on different parameters.

### Basic Tree Building

```matlab
% Create tree from data
tree = epicTreeTools(data);

% Build by cell type
tree.buildTree({'cellInfo.type'});

% Build by cell type, then protocol
tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name'});

% Build by cell type, protocol, then contrast
tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name', 'parameters.contrast'});
```

### Available Split Keys

**String key paths** (dot notation):
- `cellInfo.type` - Cell type (OnP, OffP, etc.)
- `cellInfo.label` - Cell label/ID
- `blockInfo.protocol_name` - Protocol name
- `parameters.contrast` - Stimulus contrast
- `parameters.preTime` - Pre-stimulus time
- `parameters.stimTime` - Stimulus time
- Any parameter: `parameters.<paramName>`

**Function handles** (for complex splitting):
```matlab
tree.buildTreeWithSplitters({
    'cellInfo.type',
    @epicTreeTools.splitOnExperimentDate,
    @epicTreeTools.splitOnProtocol,
    'parameters.contrast'
});
```

### Built-in Splitter Functions

| Function | Description |
|----------|-------------|
| `splitOnCellType` | Groups by cell type |
| `splitOnCellLabel` | Groups by cell label |
| `splitOnProtocol` | Groups by protocol name |
| `splitOnExperimentDate` | Groups by experiment date |
| `splitOnContrast` | Groups by contrast value |
| `splitOnKeywords` | Groups by epoch keywords |

---

## Tree Navigation

### Navigate Down (to children)

```matlab
% Get number of children
n = node.childrenLength();

% Get child by index (1-based)
child = node.childAt(1);

% Loop over all children
for i = 1:node.childrenLength()
    child = node.childAt(i);
    fprintf('Child %d: %s\n', i, string(child.splitValue));
end

% Find child by split value
onpNode = tree.childBySplitValue('OnP');
contrastNode = parentNode.childBySplitValue(0.5);

% Get all leaf nodes
leaves = tree.leafNodes();
```

### Navigate Up (to parents)

```matlab
% Get direct parent
parent = node.parent;

% Get ancestor N levels up
grandparent = node.parentAt(2);

% Get root node
root = node.getRoot();

% Get depth (root = 0)
d = node.depth();

% Get path from root
path = node.pathFromRoot();  % Cell array of nodes

% Get human-readable path string
pathStr = node.pathString();  % "Root > OnP > 0.5"
pathStr = node.pathString('/');  % "Root/OnP/0.5"
```

### Check Node Properties

```matlab
% Is this a leaf node?
if node.isLeaf
    epochs = node.epochList;  % Direct access to epochs
end

% Count epochs under this node
n = node.epochCount();

% Get split value
value = node.splitValue;  % e.g., 'OnP' or 0.5
```

---

## Selection & Controlled Access

### Selection State

Each epoch has an `isSelected` flag for filtering:

```matlab
% Get all epochs (selected + unselected)
allEpochs = node.getAllEpochs(false);

% Get only selected epochs
selectedEpochs = node.getAllEpochs(true);

% Count selected
nSelected = node.selectedCount();

% Set selection on a node (and optionally children)
node.setSelected(true, true);   % Select all recursively
node.setSelected(false, false); % Deselect this node only

% Mark individual epochs
node.epochList{1}.isSelected = false;
```

### Controlled Access (putCustom/getCustom)

Store and retrieve custom data on nodes without directly modifying properties:

```matlab
% Store analysis results
results = struct();
results.mean = 42.5;
results.std = 3.2;
results.n = 10;
node.putCustom('results', results);

% Check if key exists
if node.hasCustom('results')
    % Retrieve results
    r = node.getCustom('results');
    fprintf('Mean: %.2f (n=%d)\n', r.mean, r.n);
end

% Remove custom data
node.removeCustom('results');

% List all custom keys
keys = node.customKeys();
```

---

## Data Retrieval

### getSelectedData (Primary Function)

The most important function for analysis - gets response data filtered by selection:

```matlab
% Basic usage
[dataMatrix, epochs, sampleRate] = getSelectedData(node, 'Amp1');

% With H5 lazy loading
[dataMatrix, epochs, sampleRate] = getSelectedData(node, 'Amp1', h5_file);

% Returns:
%   dataMatrix - [nEpochs x nSamples] response data
%   epochs     - Cell array of epoch structs
%   sampleRate - Sample rate in Hz
```

### getResponseMatrix

Lower-level function - gets all epochs without selection filtering:

```matlab
% Get response matrix from epoch list
[respMatrix, fs] = getResponseMatrix(epochs, 'Amp1');
[respMatrix, fs] = getResponseMatrix(epochs, 'Amp1', h5_file);  % With H5
```

### getTreeEpochs

Convenience wrapper for getAllEpochs:

```matlab
epochs = getTreeEpochs(node);           % All epochs
epochs = getTreeEpochs(node, true);     % Selected only
```

---

## Analysis Functions

### getMeanResponseTrace

Compute mean response with SEM:

```matlab
% Get data first
[data, ~, fs] = getSelectedData(node, 'Amp1', h5_file);

% Compute mean trace
result = getMeanResponseTrace(data, fs);

% Result contains:
%   result.mean       - Mean trace
%   result.stdev      - Standard deviation
%   result.SEM        - Standard error of mean
%   result.n          - Number of epochs
%   result.timeVector - Time in seconds
```

### getResponseAmplitudeStats

Compute peak and integrated response:

```matlab
result = getResponseAmplitudeStats(data, fs, 'PreTime', 500, 'StimTime', 1000);

% Result contains:
%   result.peakAmplitude
%   result.integratedResponse
%   result.timeToMeak
```

### getCycleAverageResponse

For periodic stimuli:

```matlab
result = getCycleAverageResponse(data, fs, cyclePeriodMs);

% Result contains:
%   result.cycleAverage
%   result.F1amplitude
%   result.F2amplitude
```

### MeanSelectedNodes

Compare multiple conditions:

```matlab
% Get nodes for different conditions
nodes = {};
for i = 1:parentNode.childrenLength()
    nodes{end+1} = parentNode.childAt(i);
end

% Plot comparison
results = MeanSelectedNodes(nodes, 'Amp1', 'h5_file', h5_file);

% Result contains:
%   results.meanResponse - [nNodes x nSamples]
%   results.respAmp      - Integrated response per node
%   results.splitValue   - Split value for each node
```

---

## GUI Usage

### Launching the GUI

```matlab
% Basic launch
gui = epicTreeGUI('data.mat');

% Without individual epochs in tree
gui = epicTreeGUI('data.mat', 'noEpochs');
```

### GUI Layout

```
+------------------+------------------------+
|   Tree Browser   |     Data Viewer        |
|     (40%)        |        (60%)           |
|                  |                        |
| [Split Dropdown] |  [Info Table]          |
|                  |                        |
| + Root           |  [Response Plot]       |
|   + OnP          |                        |
|     + Protocol1  |                        |
|       - 0.3      |                        |
|       - 0.5      |                        |
|                  |                        |
| [Buttons]        |                        |
+------------------+------------------------+
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ↑ / ↓ | Navigate up/down in tree |
| ← | Collapse selected node |
| → | Expand selected node |
| F or Space | Toggle selection checkbox |

### Menu Options

**File Menu:**
- Load Data... - Open a new data file
- Export Selection... - Save selected epochs to .mat
- Close - Close the GUI

**Analysis Menu:**
- Mean Response Trace - Plot mean ± SEM
- Response Amplitude - (Coming soon)

---

## Common Workflows

### Workflow 1: Analyze Contrast Response

```matlab
% Load and build tree
data = load('experiment.mat');
tree = epicTreeTools(data);
tree.buildTree({'cellInfo.type', 'parameters.contrast'});

% Configure H5
epicTreeConfig('h5_dir', '/path/to/h5');
h5_file = getH5FilePath('experiment_name');

% Navigate to OnP cell type
onpNode = tree.childBySplitValue('OnP');

% Analyze each contrast
for i = 1:onpNode.childrenLength()
    contrastNode = onpNode.childAt(i);
    contrast = contrastNode.splitValue;

    % Get data
    [data, ~, fs] = getSelectedData(contrastNode, 'Amp1', h5_file);

    % Compute mean
    result = getMeanResponseTrace(data, fs);

    % Store results
    contrastNode.putCustom('results', result);

    fprintf('Contrast %.2f: mean=%.2f, n=%d\n', ...
        contrast, mean(result.mean), result.n);
end
```

### Workflow 2: Compare Cell Types

```matlab
% Build tree by cell type
tree = epicTreeTools(data);
tree.buildTree({'cellInfo.type'});

% Collect all cell type nodes
cellNodes = {};
for i = 1:tree.childrenLength()
    cellNodes{end+1} = tree.childAt(i);
end

% Compare using MeanSelectedNodes
results = MeanSelectedNodes(cellNodes, 'Amp1', ...
    'h5_file', h5_file, ...
    'ShowAnalysis', true);
```

### Workflow 3: Batch Analysis with Results Storage

```matlab
% Build deep tree
tree = epicTreeTools(data);
tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name', 'parameters.contrast'});

% Analyze all leaf nodes
leaves = tree.leafNodes();
for i = 1:length(leaves)
    leaf = leaves{i};

    % Get data
    [data, ~, fs] = getSelectedData(leaf, 'Amp1', h5_file);

    if isempty(data)
        continue;
    end

    % Compute statistics
    result = struct();
    result.mean = mean(data, 1);
    result.peak = max(mean(data, 1));
    result.n = size(data, 1);
    result.path = leaf.pathString();

    % Store at leaf
    leaf.putCustom('results', result);
end

% Query results later
for i = 1:length(leaves)
    r = leaves{i}.getCustom('results');
    if ~isempty(r)
        fprintf('%s: peak=%.2f (n=%d)\n', r.path, r.peak, r.n);
    end
end
```

---

## Troubleshooting

### "No epochs found"

- Check data format matches DATA_FORMAT_SPECIFICATION.md
- Verify epochs are nested correctly: `experiments → cells → epoch_groups → epoch_blocks → epochs`

### "H5 file not found"

- Ensure `epicTreeConfig('h5_dir', path)` is set correctly
- Check H5 file naming matches experiment name

### "Response stream not found"

- Check available streams: `getStreamNames(epochs, 'responses')`
- Common streams: 'Amp1', 'Amp2'

### Selection not working

- Epochs need `isSelected` field (defaults to true)
- Check: `epochs{1}.isSelected`

---

## API Reference

See inline documentation for each function:

```matlab
help epicTreeTools
help getSelectedData
help MeanSelectedNodes
```

---

*Last updated: January 2026*
