# Python to MATLAB Export Tool

This directory contains tools for exporting RetinAnalysis pipeline data to MATLAB-readable formats.

## Quick Start

### 1. Install Dependencies

Make sure you have the retinanalysis package and scipy installed:

```bash
pip install scipy
```

### 2. Basic Usage

```python
import retinanalysis as ra
from retinanalysis.utils.matlab_export import export_pipeline_to_matlab

# Create pipeline
pipeline = ra.create_mea_pipeline('20250115A', 'data000')

# Export to MATLAB
export_pipeline_to_matlab(pipeline, 'output.mat', format='mat')
```

### 3. Run Example Script

```bash
python example_export.py
```

(You'll need to edit `example_export.py` to use your actual experiment name and datafile)

## Export Options

### Full Export

```python
export_pipeline_to_matlab(pipeline, 'full_export.mat')
```

### Filter by Cell Type

```python
export_pipeline_to_matlab(
    pipeline,
    'onp_offp_only.mat',
    cell_types=['OnP', 'OffP']
)
```

### Filter by Specific Cells

```python
export_pipeline_to_matlab(
    pipeline,
    'specific_cells.mat',
    cell_ids=[42, 56, 78]
)
```

### Filter by Epochs

```python
export_pipeline_to_matlab(
    pipeline,
    'first_10_epochs.mat',
    epoch_indices=list(range(10))
)
```

### Export to JSON (for debugging)

```python
export_pipeline_to_matlab(
    pipeline,
    'debug.json',
    format='json'
)
```

## Exported Data Structure

The exported `.mat` file contains the following fields:

### Metadata
- `exp_name` - Experiment name
- `block_id` - Block ID
- `datafile_name` - Protocol datafile name
- `protocol_name` - Protocol name
- `num_epochs` - Number of epochs
- `num_cells` - Number of cells

### Cell Information
- `cell_ids` - Array of cell IDs [n_cells x 1]
- `cell_types` - Cell array of cell type strings {n_cells x 1}
- `noise_ids` - Array of matched noise IDs [n_cells x 1]

### Spike Data
- `spike_times` - Struct with fields `cell_<ID>`
  - Each `cell_<ID>` contains:
    - `spike_times` - Cell array {n_epochs x 1} of spike time arrays
    - `num_epochs` - Number of epochs

### RF Parameters
- `rf_params` - Struct with fields `noise_<ID>`
  - Each `noise_<ID>` contains:
    - `center_x` - RF center X coordinate
    - `center_y` - RF center Y coordinate
    - `std_x` - RF standard deviation X
    - `std_y` - RF standard deviation Y
    - `rotation` - RF rotation angle

### Timing
- `epoch_starts` - Epoch start times [n_epochs x 1] (ms)
- `epoch_ends` - Epoch end times [n_epochs x 1] (ms)
- `frame_times` - Cell array {n_epochs x 1} of frame time arrays (ms)

### Stimulus Parameters
- `epoch_params` - Struct array [n_epochs x 1] with parameter fields
- `param_names` - Cell array of parameter names

## Loading in MATLAB

```matlab
% Load the exported data
data = load('output.mat');

% Inspect structure
disp(fieldnames(data))

% Access spike times for cell 42, epoch 1
spike_times = data.spike_times.cell_42.spike_times{1};

% Access RF parameters for noise cell 15
rf_center_x = data.rf_params.noise_15.center_x;

% Access stimulus parameters for epoch 3
contrast = data.epoch_params(3).contrast;

% Get frame times for epoch 5
frame_times = data.frame_times{5};
```

## Verifying Export

Use the included verification function:

```python
from retinanalysis.utils.matlab_export import print_export_summary

print_export_summary('output.mat')
```

This will print a summary of what's in the exported file.

## File Organization

```
python_export/
├── README.md              # This file
├── example_export.py      # Example usage script
└── matlab_exports/        # Default output directory (created by example)
```

The actual export function is located in:
```
new_retinanalysis/src/retinanalysis/utils/matlab_export.py
```

## Next Steps

After exporting your data:

1. Load the `.mat` file in MATLAB
2. Use the EpicTreeGUI MATLAB application to browse and analyze the data
3. See `../src/` directory for the MATLAB GUI implementation

## Troubleshooting

### scipy.io.savemat errors

If you get errors about data types, the export function automatically converts numpy types to Python native types. If you still have issues:

1. Check that all spike times are valid arrays
2. Ensure epoch parameters don't contain unsupported data types
3. Try exporting to JSON first to inspect the data structure

### Missing RF parameters

If `rf_params` is empty, check that:
1. The analysis chunk was created correctly
2. Cell matching was successful (check `noise_ids`)
3. RF analysis was run on the noise chunk

### Large file sizes

If files are too large:
1. Filter by cell types or specific cells
2. Export only a subset of epochs
3. Use `do_compression=True` (automatically enabled)
