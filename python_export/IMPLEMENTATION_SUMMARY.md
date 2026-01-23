# Python to MATLAB Export - Implementation Summary

## What We Built

A complete Python-to-MATLAB export system that allows RetinAnalysis pipeline data to be exported to `.mat` files that MATLAB can easily read and process.

## Files Created

### 1. Core Export Module
**Location:** `new_retinanalysis/src/retinanalysis/utils/matlab_export.py`

**Functions:**
- `export_pipeline_to_matlab()` - Main export function
- `_format_spike_times_for_matlab()` - Converts spike times to MATLAB-friendly format
- `_format_rf_params_for_matlab()` - Converts RF parameters to MATLAB structs
- `_format_epoch_params_for_matlab()` - Converts stimulus parameters to MATLAB structs
- `print_export_summary()` - Verification utility

**Features:**
- Export to `.mat` or `.json` format
- Optional filtering by cell type, cell IDs, or epochs
- Automatic data type conversion for MATLAB compatibility
- Compression enabled by default

### 2. Example Scripts

**`example_export.py`** - Complete usage example showing:
- Full export
- Filtered exports (by cell type, epochs)
- JSON export for debugging
- Verification of exports

**`test_export_simple.py`** - Standalone test with mock data:
- Tests all export functions
- No real experimental data needed
- Verifies MAT file integrity
- Includes filtered export tests

### 3. MATLAB Verification Script

**`examples/test_data_loading.m`** - Complete MATLAB test that:
- Loads exported `.mat` file
- Verifies all data fields
- Tests accessing spike times, RF params, epoch params
- Creates example PSTH plot
- Provides next steps for GUI integration

### 4. Documentation

**`README.md`** - Comprehensive guide covering:
- Installation and dependencies
- Quick start examples
- All export options
- Complete data structure documentation
- MATLAB loading examples
- Troubleshooting tips

## Data Structure (MATLAB)

The exported `.mat` file contains:

```matlab
data =
  struct with fields:

    % Metadata
    exp_name: 'experiment_name'
    block_id: 1
    datafile_name: 'data000'
    protocol_name: 'protocolName'
    num_epochs: 50
    num_cells: 100

    % Cell info
    cell_ids: [100×1 double]
    cell_types: {100×1 cell}
    noise_ids: [100×1 double]

    % Spike data
    spike_times: [1×1 struct]
      .cell_42: [1×1 struct]
        .spike_times: {50×1 cell}  % Each cell contains spike time array
        .num_epochs: 50
      .cell_56: ...

    % RF parameters
    rf_params: [1×1 struct]
      .noise_1: [1×1 struct]
        .center_x: 100.5
        .center_y: 150.2
        .std_x: 25.3
        .std_y: 28.1
        .rotation: 45.0
      .noise_2: ...

    % Timing
    epoch_starts: [50×1 double]  % milliseconds
    epoch_ends: [50×1 double]
    frame_times: {50×1 cell}

    % Stimulus params
    epoch_params: [50×1 struct]
      (1): [1×1 struct]
        .contrast: 0.5
        .size: 200
        .temporal_freq: 4.0
      (2): ...
    param_names: {1×N cell}
```

## Usage Examples

### Python Export

```python
import retinanalysis as ra
from retinanalysis.utils.matlab_export import export_pipeline_to_matlab

# Create pipeline
pipeline = ra.create_mea_pipeline('20250115A', 'data000')

# Full export
export_pipeline_to_matlab(pipeline, 'output.mat')

# Filtered export
export_pipeline_to_matlab(
    pipeline,
    'onp_cells.mat',
    cell_types=['OnP', 'OffP']
)
```

### MATLAB Loading

```matlab
% Load data
data = load('output.mat');

% Access spike times
spikes_cell42_epoch1 = data.spike_times.cell_42.spike_times{1};

% Access RF parameters
rf_center = [data.rf_params.noise_15.center_x, ...
             data.rf_params.noise_15.center_y];

% Access stimulus parameters
contrast_epoch3 = data.epoch_params(3).contrast;
```

## Testing

### Test the Python Export

```bash
cd python_export
python test_export_simple.py
```

This will:
1. Create mock pipeline data
2. Test all export functions
3. Verify MAT file integrity
4. Create test files in `test_exports/`

### Test MATLAB Loading

```matlab
% In MATLAB, navigate to examples/ directory
cd examples
test_data_loading
```

This will:
1. Load the exported MAT file
2. Verify all fields are accessible
3. Create example plots
4. Display summary

## Next Steps

### For Python Users

1. Export your experimental data:
   ```bash
   python example_export.py
   ```

2. Customize the export (edit `example_export.py`):
   - Change experiment name and datafile
   - Add filters for specific cell types
   - Select epochs of interest

### For MATLAB Users

1. Load the exported data:
   ```matlab
   data = load('path/to/export.mat');
   ```

2. Verify with test script:
   ```matlab
   test_data_loading
   ```

3. Build the EpicTreeGUI (upcoming):
   - EpochData class to wrap the loaded data
   - TreeNode class for hierarchical organization
   - epicTreeGUI for interactive browsing

## File Organization

```
epicTreeGUI/
├── python_export/
│   ├── README.md                    # Main documentation
│   ├── IMPLEMENTATION_SUMMARY.md    # This file
│   ├── example_export.py            # Complete usage example
│   ├── test_export_simple.py        # Standalone test
│   └── matlab_exports/              # Default output directory
│
├── new_retinanalysis/
│   └── src/retinanalysis/utils/
│       └── matlab_export.py         # Core export module
│
└── examples/
    └── test_data_loading.m          # MATLAB verification script
```

## Key Design Decisions

### 1. Separate Module vs Modifying Pipeline Class

**Decision:** Created separate `matlab_export.py` module
**Rationale:**
- Keeps export logic separate from core pipeline
- Easier to maintain and test
- Can be used independently

### 2. Data Structure Format

**Decision:** Nested structs with `cell_<ID>` and `noise_<ID>` naming
**Rationale:**
- MATLAB-friendly struct access
- Easy to iterate over cells
- Clear association between IDs and data

### 3. Filtering Options

**Decision:** Support filtering by cell type, cell IDs, and epochs
**Rationale:**
- Reduces file size for large datasets
- Allows targeted analysis
- Flexible export for different use cases

### 4. Dual Format Support (MAT and JSON)

**Decision:** Support both `.mat` and `.json`
**Rationale:**
- MAT for MATLAB integration
- JSON for debugging and inspection
- JSON for potential web-based tools

## Testing Status

✅ **Completed:**
- Core export function
- Spike time formatting
- RF parameter formatting
- Epoch parameter formatting
- Filtering (cell types, IDs, epochs)
- Mock data testing
- MATLAB loading verification

⏳ **Pending:**
- Test with real experimental data
- Performance testing with large datasets
- Integration with EpicTreeGUI

## Dependencies

**Python:**
- scipy (for `.mat` file I/O)
- numpy
- pandas
- retinanalysis package

**MATLAB:**
- Base MATLAB (R2019b or later recommended)
- No additional toolboxes required

## Known Limitations

1. **Large Datasets:** Very large exports (>1000 cells, >1000 epochs) may take time
2. **Unmatched Cells:** Cells with `noise_id=0` have no RF parameters
3. **Stimulus Reconstruction:** Stimulus data itself is not exported, only parameters

## Future Enhancements

1. **Lazy Loading:** Export metadata + data pointers for huge datasets
2. **Batch Export:** Export multiple experiments at once
3. **Stimulus Data:** Include actual stimulus arrays for LN modeling
4. **Compression Options:** User-selectable compression levels
5. **Progress Bars:** For large exports

## Support

For issues or questions:
1. Check `README.md` for common solutions
2. Run `test_export_simple.py` to verify functionality
3. Check MATLAB console output from `test_data_loading.m`

## Version History

- **v1.0 (2025-01-23):** Initial implementation
  - Core export functionality
  - Filtering options
  - Documentation and tests
