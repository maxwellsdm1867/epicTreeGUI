# Rieke OS · EpicTreeGUI

Rieke OS is a local workspace for browsing Symphony recordings, inspecting epochs,
organizing metadata queries, tagging data, and exporting selections to MATLAB or
SQLite. It runs in your browser with a local Python service and a separate database
for each project. This repository also contains **EpicTreeGUI**, the MATLAB epoch
browser used to work with exported recordings.

> **Download status:** the public `master` branch currently contains the MATLAB
> application. Use the **`codex/rieke-native-e2e` review branch** for the complete
> Rieke OS development source and launcher. Downloading `master` alone does not
> provide that installer. There is no signed standalone desktop installer or
> stable Rieke OS release yet.

## Start here

| What you need | Where to go |
| --- | --- |
| Download and set up Rieke OS | [Quick start](docs/RIEKE_OS_QUICK_START.md) |
| Ask an AI assistant to help install it | [LLM setup instructions](docs/LLM_SETUP.md) |
| Use the existing MATLAB browser | [MATLAB installation](#matlab-installation) |
| Understand runtime and project storage | [Installation details](workspace-app/README.md) |
| Work with shared tags and MATLAB tag exchange | [Tagging guide](docs/TAGGING.md) |

## Download the application

Open the [Rieke OS review branch](https://github.com/maxwellsdm1867/epicTreeGUI/tree/codex/rieke-native-e2e)
and choose **Code → Download ZIP**, then extract the entire archive, or clone that
branch explicitly:

```sh
git clone --branch codex/rieke-native-e2e https://github.com/maxwellsdm1867/epicTreeGUI.git
cd epicTreeGUI
```

This downloads the Rieke OS development source. **Check for `rieke.py` before
attempting setup.** If it is absent, verify that you selected the review branch
instead of the MATLAB-only `master` branch. Do not
copy only the launcher into an older checkout.

The source package does not include installed dependencies, recordings, project
databases, or MATLAB. Rieke OS setup downloads its pinned Python runtime,
RetinAnalysis parser, frontend dependencies and private MySQL server/client.
New projects use this app-owned MySQL runtime; Docker and a separate MySQL
installation are unnecessary. Allow internet access and several GB of
free space, plus storage for your recordings.

## Rieke OS: install once, launch whenever needed

The bundled native database is currently supported on Apple Silicon macOS.
Source setup requires Git, Python 3.10+, uv, Node/npm (20.19+ on Node 20, or
22.12+), and a C++ compiler. Linux does not yet have a validated bundled database.
MATLAB is optional unless you want to use the MATLAB browser. A signed macOS
`.app` bundling the interpreter and all dependencies has not been built yet.
See the [quick start](docs/RIEKE_OS_QUICK_START.md) for prerequisite links.

From a **complete Rieke OS checkout**:

```sh
python3 rieke.py setup
python3 rieke.py doctor
python3 rieke.py init "$HOME/Documents/RiekeLabWorkspace"
cd "$HOME/Documents/RiekeLabWorkspace"
python3 rieke-workspace.py
```

Open [Rieke OS locally](http://127.0.0.1:8766), confirm the workspace folder,
choose **New project**, and open it. Use **Add data store** to import your Symphony
H5 recordings. Select a tag author before adding or importing tags.

To reopen later, run the last two commands again. Keep the
terminal open while using the app. Ctrl-C stops the chooser; project servers and
databases may keep running. The application checkout and workspace folder must
remain separate. Keep original H5 files available for lazy trace access, including
when using exported MATLAB or SQLite packages.

To hand over a native project, use **Project folder → Close project**, wait for
the clean-close confirmation, then copy or move its entire folder. The recipient
uses **Open project** in their own app with the same bundled MySQL runtime.
Project-contained paths are checked and updated on open. Linked recordings must
still be accessible; **Prepare to share** can create a separate logical transfer
package with recordings included. Closing a browser tab alone is not a clean
database shutdown. Existing Docker-backed projects are preserved and require an
explicit migration; opening them does not silently convert their database.
See [workspace sharing and updates](docs/WORKSPACE_SHARING_AND_UPDATES.md).

---

# EpicTreeGUI MATLAB browser

The following documentation covers the MATLAB application independently of the
Rieke OS installation above.

## Overview

EpicTreeGUI provides hierarchical organization and analysis of neurophysiology epochs through dynamic tree structures. The system uses configurable splitting criteria to reorganize datasets by cell type, experimental protocol, stimulus parameters, recording date, or custom grouping functions.

*Replaces the legacy Rieke Lab Java-based epoch tree system.*

## Features

- Dynamic tree organization with 22+ built-in splitter functions
- Interactive GUI with checkbox-based epoch selection
- Programmatic API for scripted analysis workflows
- Stimulus waveform reconstruction from generator parameters (11 Symphony generators ported)
- Selection state persistence (.ugm files) with UUID-based matching
- DataJoint round-trip: export selections back as epoch tags via h5_uuid
- Lazy loading from H5 data files
- Compatible with RetinAnalysis Python export pipeline and DataJoint Flask web app
- Pre-built tree pattern for reproducible analysis hierarchies

## MATLAB requirements

- MATLAB R2019b or later
- No additional toolboxes required
- Operating system: Windows, macOS, Linux

## MATLAB installation

1. Clone this repository:

   ```bash
   git clone https://github.com/maxwellsdm1867/epicTreeGUI.git
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

## MATLAB quick start

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

## Data Framework

### Three-File Architecture

epicTreeGUI uses three file types to keep raw data, user selections, and analysis separate:

```
experiment_2025-12-02.mat          Raw epoch data (never modified by GUI)
experiment_2025-12-02_*.ugm        User selection masks (timestamped versions)
workspace.mat                      Active MATLAB session (transient)
```

- **`.mat` file**: Exported from the RetinAnalysis Python pipeline or DataJoint. Contains the full epoch hierarchy (experiments, cells, epoch groups, blocks, epochs) with stimulus parameters, response data references, and metadata.
- **`.ugm` file**: User-Generated Metadata. Stores which epochs are selected/deselected. Saved separately so raw data stays pristine. Multiple versions can coexist (timestamped). The latest is auto-loaded by default.
- **Workspace**: During a MATLAB session, `epoch.isSelected` flags are the source of truth. Masks are built only on save, applied only on load.

### Epoch Identity: h5_uuid

Every epoch has a stable identifier (`h5_uuid`) derived from its H5 source file. This UUID:

- Survives database repopulation (unlike auto-increment IDs)
- Enables reliable matching between .ugm masks and epoch data
- Links MATLAB selections back to DataJoint records

When loading a .ugm file, epochs are matched **by h5_uuid** (not by position). This means:

- Reordering epochs between exports won't corrupt your selections
- Adding/removing epochs keeps existing selections intact
- Database repopulation doesn't break saved masks

### Selection State Persistence

```matlab
% Save current selection (builds mask + UUIDs one-time)
filepath = epicTreeTools.generateUGMFilename(tree.sourceFile);
tree.saveUserMetadata(filepath);

% Load selection (matches by h5_uuid, applies mask one-time)
tree.loadUserMetadata(filepath);

% Auto-load latest .ugm on construction (default behavior)
tree = epicTreeTools(data);                              % Auto-loads if .ugm exists
tree = epicTreeTools(data, 'LoadUserMetadata', 'none');  % Start fresh
tree = epicTreeTools(data, 'LoadUserMetadata', 'latest');% Error if no .ugm
```

The GUI close handler detects if selections changed and prompts to save.

### Configuring the UGM Directory

By default, `.ugm` files are saved next to the `.mat` file. Set `ugm_dir` to use a shared directory (useful when DataJoint or other tools need to find them):

```matlab
% Point all .ugm files to a shared directory
epicTreeConfig('ugm_dir', '/Volumes/rieke-nas/analysis/ugm');

% Now save/load automatically uses that directory
tree.saveUserMetadata(epicTreeTools.generateUGMFilename(tree.sourceFile));
% Saves to: /Volumes/rieke-nas/analysis/ugm/experiment_2026-02-16_10-00-00.ugm

% findLatestUGM checks ugm_dir first, then falls back to .mat directory
ugm = epicTreeTools.findLatestUGM('/local/path/experiment.mat');
% Finds .ugm in ugm_dir even though .mat is elsewhere
```

### Legacy DataJoint Mask Round-Trip

The following describes the older DataJoint application. In Rieke OS, `.ugm` imports change inclusion only; authored tags use the separate UUID-based [tag JSON workflow](docs/TAGGING.md).

Selection masks can be **manually** pushed back to DataJoint as epoch tags. The DataJoint web app never auto-loads `.ugm` files — import only happens when the user explicitly clicks "Import Mask" and selects a file.

```
DataJoint ──export──> .mat ──MATLAB──> .ugm ──import──> DataJoint Tags
```

1. **Export**: DataJoint web app exports query results as `.mat` with `h5_uuid` on every epoch
2. **Analyze in MATLAB**: Load `.mat`, build tree, select/deselect epochs, save `.ugm`
3. **Import mask**: Upload `.ugm` via the DataJoint web app "Import Mask" button
4. **Result**: Deselected epochs get tagged as `"excluded"` in the DataJoint Tags table, keyed by `h5_uuid`

The import is idempotent — re-importing the same `.ugm` produces identical tags.

**Python module** (`python/import_ugm.py`): Reads `.ugm` files via `h5py` and returns excluded/selected UUID lists:

```python
from import_ugm import read_ugm

ugm_data = read_ugm('/path/to/file.ugm')
# ugm_data['excluded_uuids']  -> list of h5_uuids for deselected epochs
# ugm_data['selected_uuids']  -> list of h5_uuids for selected epochs
```

> **Note**: `.ugm` files are saved in MATLAB's HDF5 format (`-v7.3`). Use `h5py` to read them in Python, not `scipy.io.loadmat`.

See `docs/SELECTION_STATE_ARCHITECTURE.md` for the full technical specification.

## Stimulus Waveform Reconstruction

Symphony stores stimuli parametrically — only the generator class name and parameters are saved, not the actual waveform. EpicTreeGUI includes pure MATLAB ports of 11 Symphony stimulus generators that reconstruct waveforms on demand.

**Supported generators:**

| Generator | stimulusID | Use Case |
|-----------|-----------|----------|
| Pulse | `symphonyui.builtin.stimuli.PulseGenerator` | Step stimuli |
| Sine | `symphonyui.builtin.stimuli.SineGenerator` | Sinusoidal modulation |
| Square | `symphonyui.builtin.stimuli.SquareGenerator` | Square wave modulation |
| Ramp | `symphonyui.builtin.stimuli.RampGenerator` | Linear ramps |
| Direct Current | `symphonyui.builtin.stimuli.DirectCurrentGenerator` | Constant holding current |
| Pulse Train | `symphonyui.builtin.stimuli.PulseTrainGenerator` | Repeated pulses |
| Repeating Pulse | `symphonyui.builtin.stimuli.RepeatingPulseGenerator` | Single-repeat pulse |
| Sum | `symphonyui.builtin.stimuli.SumGenerator` | Composite (sums sub-generators) |
| Gaussian Noise | `edu.washington.riekelab.stimuli.GaussianNoiseGenerator` | Filtered Gaussian noise |
| Gaussian Noise V2 | `edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2` | Corrected noise filter |
| Binary Noise | `edu.washington.riekelab.stimuli.BinaryNoiseGenerator` | Binary random segments |

**How it works:** When `epoch.stimuli{i}.data` is empty but `stimulus_id` and `stimulus_parameters` are present, `getStimulusByName()` auto-reconstructs the waveform transparently. Callers don't need to know whether data was pre-computed or reconstructed.

```matlab
% Get stimulus waveform (auto-reconstructs if needed)
stim = epicTreeTools.getStimulusByName(epoch, 'UV LED');
plot(stim.data);  % Reconstructed from parameters

% Get stimulus matrix for multiple epochs
[stimMatrix, sr] = epicTreeTools.getStimulusMatrix(epochs, 'UV LED');
```

**Note:** Stage-based spatial stimuli (moving bars, gratings, spots) don't have generator classes — their `stimulus_id` is empty and stimulus shape is defined by protocol parameters instead.

## DataJoint Web App Integration

EpicTreeGUI integrates with a DataJoint-based Flask/Next.js web application for data management.

### Architecture

```
┌─────────────────────────────────────────────────┐
│  DataJoint Web App                               │
│  Flask backend (Python) + Next.js frontend       │
│  MySQL 5.7 in Docker                             │
├─────────────────────────────────────────────────┤
│  Endpoints:                                      │
│  - /pop/add-data    Ingest H5 + JSON metadata    │
│  - /results/export-mat  Export to epicTreeGUI     │
│  - /results/import-ugm  Import selection masks    │
└──────────────┬──────────────────────────────────┘
               │ .mat file
               ▼
┌─────────────────────────────────────────────────┐
│  epicTreeGUI (MATLAB)                            │
│  Load → Build tree → Analyze → Save .ugm         │
└──────────────────────────────────────────────────┘
```

### Data Pipeline

1. **H5 files** contain raw experiment data (Symphony format)
2. **JSON metadata** parsed from H5 by RetinAnalysis Python pipeline
3. **DataJoint MySQL** stores structured metadata (experiments, cells, epochs, stimuli, responses)
4. **Flask export** packages DataJoint query results into epicTreeGUI `.mat` format
5. **MATLAB** loads `.mat`, reconstructs stimulus waveforms from `stimulus_id` + parameters, analyzes data

### Stimulus Metadata Flow

```
H5 file (stimulusID attribute)
  → JSON metadata (stimulusID, sampleRate, sampleRateUnits, durationSeconds, units)
    → DataJoint Stimulus table (stimulus_id, sample_rate, etc.)
      → Python export (stimulus_id + stimulus_parameters in .mat)
        → MATLAB auto-reconstruction (epicStimulusGenerators)
```

The DataJoint `Stimulus` table stores the generator class name (`stimulus_id`) and metadata. The actual waveform is never stored — it's reconstructed in MATLAB from these parameters.

See `docs/UserGuide.md` for detailed setup and usage instructions.

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
- **Data Format**: `docs/dev/DATA_FORMAT_SPECIFICATION.md` - Standard .mat format specification
- **Stimulus Plan**: `docs/dev/STIMULUS_AND_GAPS_PLAN.md` - Stimulus reconstruction design and status
- **Selection State**: `docs/SELECTION_STATE_ARCHITECTURE.md` - .ugm file format and selection persistence
- **Examples**: `examples/` - Sample scripts demonstrating common workflows
- **Technical Specification**: `docs/trd` - Complete technical reference
- **API Reference**: `src/tree/README.md` - epicTreeTools class documentation

## License

MIT License - see [LICENSE](LICENSE) file.
