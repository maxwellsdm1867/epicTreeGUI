# Export Guide: DataJoint to EpicTreeGUI

This guide explains how to export data from DataJoint to the EpicTreeGUI standard format.

## Prerequisites

1. **Python Environment**:
   ```bash
   pip install datajoint h5py scipy numpy
   ```

2. **Access to DataJoint Database**:
   - Database must be running and accessible
   - You need valid credentials

3. **H5 Files**:
   - H5 data files must be accessible at paths stored in database

## Quick Start

### Interactive Mode

The easiest way to export data:

```bash
cd python_export
python export_to_epictree.py
```

You'll be prompted for:
- Username
- Experiment name (optional filter)
- Cell type (optional filter)
- Protocol name (optional filter)
- Output filename

### Programmatic Usage

```python
import sys
sys.path.append('/Users/maxwellsdm/Documents/GitHub/datajoint/next-app/api')

import datajoint as dj
from export_to_epictree import EpicTreeExporter

# Connect to database
db = dj.VirtualModule('schema.py', 'schema')

# Create exporter
exporter = EpicTreeExporter(username='your_username', db=db)

# Define query
query_obj = {
    'experiment': {'COND': {'type': 'COND', 'value': 'exp_name="20250115A"'}},
    'cell': {'COND': {'type': 'COND', 'value': 'type="OnP"'}},
}

# Export
exporter.export_query_to_mat(
    query_obj=query_obj,
    output_file='my_export.mat',
    verbose=True
)
```

## Query Examples

### Export All Data

```python
query_obj = {}  # Empty query = everything
exporter.export_query_to_mat(query_obj, 'all_data.mat')
```

### Export Specific Experiment

```python
query_obj = {
    'experiment': {'COND': {'type': 'COND', 'value': 'exp_name="20250115A"'}}
}
exporter.export_query_to_mat(query_obj, 'exp_20250115A.mat')
```

### Export Specific Cell Types

```python
query_obj = {
    'cell': {'COND': {'type': 'COND', 'value': 'type="OnP"'}}
}
exporter.export_query_to_mat(query_obj, 'onp_cells.mat')
```

### Export Specific Protocol

```python
query_obj = {
    'epoch_block': {'COND': {'type': 'COND', 'value': 'protocol_name="Contrast"'}}
}
exporter.export_query_to_mat(query_obj, 'contrast_protocol.mat')
```

### Combined Filters

```python
query_obj = {
    'experiment': {'COND': {'type': 'COND', 'value': 'exp_name="20250115A"'}},
    'cell': {'COND': {'type': 'COND', 'value': 'type="OnP"'}},
    'epoch_block': {'COND': {'type': 'COND', 'value': 'protocol_name="Contrast"'}}
}
exporter.export_query_to_mat(query_obj, 'filtered_export.mat')
```

## Advanced Query Syntax

### AND Conditions

```python
query_obj = {
    'cell': {
        'AND': [
            {'COND': {'type': 'COND', 'value': 'type="OnP"'}},
            {'COND': {'type': 'COND', 'value': 'properties->"ndf">5'}}
        ]
    }
}
```

### Using Tags

```python
query_obj = {
    'epoch': {'COND': {'type': 'TAG', 'value': 'tag="good_quality"'}}
}
```

## Excluding Hierarchy Levels

If you want to skip certain levels (e.g., Animal, Preparation):

```python
exporter.export_query_to_mat(
    query_obj=query_obj,
    output_file='export.mat',
    exclude_levels=['animal', 'preparation']
)
```

## Troubleshooting

### Database Connection Issues

```python
# Check database connection
import datajoint as dj
print(dj.conn().is_connected)
```

### H5 File Access Issues

If you get errors about H5 files not being found:

1. Check that `Experiment.data_file` paths are correct
2. Verify you have read permissions for H5 files
3. For MEA data, check `EpochBlock.data_dir` paths

### Memory Issues

For very large exports:

```python
# Export in batches by experiment
experiments = ['20250115A', '20250116A', '20250117A']

for exp in experiments:
    query_obj = {
        'experiment': {'COND': {'type': 'COND', 'value': f'exp_name="{exp}"'}}
    }
    exporter.export_query_to_mat(query_obj, f'{exp}_export.mat')
```

## Output Format

The exported `.mat` file contains:

```
data.mat:
  format_version: '1.0'
  metadata: struct
    - created_date
    - data_source
    - export_user
    - query_object
    - num_experiments
  experiments: array of structs
    - id, exp_name, is_mea, cells, etc.
```

See [DATA_FORMAT_SPECIFICATION.md](../DATA_FORMAT_SPECIFICATION.md) for complete structure.

## Loading in MATLAB/EpicTreeGUI

```matlab
% Load the exported data
[treeData, metadata] = loadEpicTreeData('my_export.mat');

% Or use the GUI
epicTreeGUI()
% File > Load Data... > select my_export.mat
```

## Performance Tips

1. **Use Filters**: Don't export everything if you only need subset
2. **Exclude Levels**: Skip hierarchy levels you don't need
3. **Batch Processing**: Export large datasets in chunks
4. **Check Query First**: Verify query returns expected number of results before exporting

## Next Steps

After exporting:
1. Load in MATLAB: `loadEpicTreeData('export.mat')`
2. Visualize in EpicTreeGUI: `epicTreeGUI()`
3. Run analysis functions (PSTH, RF analysis, etc.)

## Reference

- Export script: [export_to_epictree.py](export_to_epictree.py)
- Data format spec: [DATA_FORMAT_SPECIFICATION.md](../DATA_FORMAT_SPECIFICATION.md)
- Integration guide: [INTEGRATION_INSTRUCTIONS.md](../INTEGRATION_INSTRUCTIONS.md)
