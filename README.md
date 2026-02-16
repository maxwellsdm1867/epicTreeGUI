# EpicTreeGUI

A MATLAB GUI for browsing and analyzing neurophysiology epoch data.

## Overview

EpicTreeGUI provides hierarchical organization and analysis of neurophysiology epochs through dynamic tree structures. The system uses configurable splitting criteria to reorganize datasets by cell type, experimental protocol, stimulus parameters, recording date, or custom grouping functions.

*Replaces the legacy Rieke Lab Java-based epoch tree system.*

## Features

- Dynamic tree organization with 22+ built-in splitter functions
- Interactive GUI with checkbox-based epoch selection
- Programmatic API for scripted analysis workflows
- Selection state persistence (.ugm files)
- Lazy loading from H5 data files
- Compatible with RetinAnalysis Python export pipeline
- Pre-built tree pattern for reproducible analysis hierarchies

## Requirements

- MATLAB R2019b or later
- No additional toolboxes required
- Operating system: Windows, macOS, Linux

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/Rieke-Lab/epicTreeGUI.git
   cd epicTreeGUI
   ```

2. Run the installation script in MATLAB:

   ```matlab
   install
   ```

3. Verify installation:

   ```matlab
   help epicTreeTools
   ```

## Quick Start

```matlab
% Get script directory for relative path resolution
scriptDir = fileparts(mfilename('fullpath'));

% Load sample data
dataFile = fullfile(scriptDir, 'examples', 'data', 'sample_epochs.mat');
[epochs, metadata] = loadEpicTreeData(dataFile);

% Build tree structure
tree = epicTreeTools(epochs);
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,    % Level 1: Cell type
    @epicTreeTools.splitOnProtocol     % Level 2: Protocol name
});

% Navigate to leaf node and extract data
leaves = tree.leafNodes();
targetLeaf = leaves{1};
[dataMatrix, selectedEpochs, sampleRate] = getSelectedData(targetLeaf, 'Amp1');

% Compute mean response
meanTrace = mean(dataMatrix, 1);
semTrace = std(dataMatrix, [], 1) / sqrt(size(dataMatrix, 1));
timeVector = (1:length(meanTrace)) / sampleRate * 1000;

% Plot results
figure;
hold on;
fill([timeVector, fliplr(timeVector)], ...
     [meanTrace + semTrace, fliplr(meanTrace - semTrace)], ...
     [0.8 0.8 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
plot(timeVector, meanTrace, 'b', 'LineWidth', 2);
xlabel('Time (ms)');
ylabel('Response Amplitude');
title(sprintf('Mean Response (n=%d epochs)', size(dataMatrix, 1)));
```

See `examples/quickstart.m` for a complete working example using bundled sample data.

## Citation

If you use this software in academic work, please cite:

```bibtex
@software{epicTreeGUI,
  title = {EpicTreeGUI: Hierarchical Browser for Neurophysiology Epoch Data},
  author = {{The epicTreeGUI Authors}},
  year = {2025},
  url = {https://github.com/Rieke-Lab/epicTreeGUI},
  version = {1.0.0}
}
```

See [CITATION.cff](CITATION.cff) for additional citation formats.

## Documentation

- **User Guide**: `docs/UserGuide.md` - Comprehensive usage documentation
- **Examples**: `examples/` - Sample scripts demonstrating common workflows
- **Technical Specification**: `docs/trd` - Complete technical reference
- **API Reference**: `src/tree/README.md` - epicTreeTools class documentation
- **Developer Guide**: `docs/dev/CLAUDE.md` - Project architecture and patterns

## License

MIT License - see [LICENSE](LICENSE) file.
