# Phase 05: DataJoint Integration — Export .mat from DataJoint Query Results - Research

**Researched:** 2026-02-16
**Domain:** Python + DataJoint + scipy + Flask + MATLAB interoperability
**Confidence:** HIGH

## Summary

This phase adds a Flask endpoint to the existing DataJoint web application that exports query results to epicTreeGUI's `.mat` format using scipy.io.savemat(). The export reuses existing query infrastructure (`generate_object_tree()` with `include_meta=True`) and adds a new UI button alongside the current JSON download. The export logic will live in the epicTreeGUI repository under a new `python/` directory, imported by the Flask app.

**Primary technical challenge:** Mapping DataJoint's flat relational 9-level schema (Experiment → Animal → Preparation → Cell → EpochGroup → EpochBlock → Epoch → Response → Stimulus) to epicTreeGUI's hierarchical 5-level format while preserving all metadata and maintaining lazy loading for waveform data via H5 path references.

**Primary recommendation:** Build the export module as a pure Python library in `epicTreeGUI/python/export_mat.py` with a single entry point function that accepts the tree structure from `generate_object_tree()` and returns a filepath. This separation keeps the DataJoint Flask app thin (just endpoint wiring) and makes the export logic testable/reusable.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Hierarchy mapping:**
- Flatten Animal and Preparation metadata into cell-level metadata (merge species, bath_solution, region, etc. into each cell's properties)
- DataJoint's 9-level hierarchy maps to epicTreeGUI's 5-level format (Experiment → Cell → EpochGroup → EpochBlock → Epoch with nested responses/stimuli)
- Animal/Preparation fields become part of `cellInfo` or `cell.properties`

**Field mapping:**
- Strict mapping to DATA_FORMAT_SPECIFICATION fields — every field the epicTreeGUI backend expects must be populated from the correct DataJoint column or JSON blob
- Extract known fields from DataJoint's `properties` and `attributes` JSON blobs into specific struct fields
- Unknown/extra fields go into catchall `properties` struct for discoverability

**Parameter handling:**
- Convert JSON parameter blobs to flat MATLAB structs (epoch.parameters.contrast, etc.)
- Nested JSON dicts flatten to dot-separated MATLAB struct fields

**Tags:**
- Export DataJoint tags as custom metadata on each node
- Tags do NOT affect isSelected state (managed by .ugm files)

**Waveform data:**
- Keep h5path references for lazy loading — do NOT embed waveform data
- .mat files stay small (metadata only)
- Response struct includes `h5_path` field pointing into H5 file

**Export trigger:**
- New Flask endpoint `/results/export-mat` in DataJoint web app
- New "Export to epicTree" button in web UI next to existing JSON download
- Endpoint reuses existing `generate_tree()` / `generate_object_tree()` with `include_meta=True`
- Output: timestamped .mat file in `downloads/` directory

**Code location:**
- Export logic lives in epicTreeGUI repo under `python/` directory
- Flask endpoint in datajoint repo imports from this module
- scipy added as dependency

**Scope constraints:**
- Single-cell patch clamp data only (no MEA)
- Do NOT modify epicTreeGUI MATLAB backend unless blocking bug found
- All changes must be backward compatible
- Build around existing system, not change it

**Testing requirements:**
- DataJoint app must be running (Docker + Flask + Next.js)
- End-to-end test: query → export .mat → load in MATLAB → build tree → verify

### Claude's Discretion

- Exact scipy.io.savemat() options (compression, oned_as, etc.)
- How to handle missing/null fields from DataJoint
- Temporary file handling during export
- Error handling and progress reporting in Flask endpoint

### Deferred Ideas (OUT OF SCOPE)

- MEA experiment support (SortingChunk, SortedCell, spike sorting)
- Embedded waveform data option (self-contained .mat files)
- Standalone CLI export script (independent of web UI)
- Bidirectional sync (.ugm changes back to DataJoint tags)
- Batch export of multiple queries
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| scipy | 1.14+ | MATLAB .mat file I/O via `scipy.io.savemat()` | Official Python library for MATLAB interoperability, maintained by NumPy community |
| h5py | 3.9+ | Reading HDF5 files (for waveform paths) | Standard HDF5 interface for Python, used by scientific community |
| Flask | 2.3+ | Web API endpoint | Already in use in DataJoint app |
| NumPy | 1.24+ | Array handling for scipy | Required dependency of scipy |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| json | stdlib | Parsing DataJoint JSON blobs | Extract parameters from `properties`/`attributes` fields |
| datetime | stdlib | Timestamp handling | Format export filenames, convert time fields |
| os | stdlib | File path operations | Construct download paths |

**Installation:**
```bash
# In epicTreeGUI repository (new python/ directory)
pip install scipy>=1.14 h5py>=3.9 numpy>=1.24

# Already installed in datajoint repository
# (Flask, datajoint dependencies)
```

## Architecture Patterns

### Recommended Project Structure
```
epicTreeGUI/
├── python/                          # NEW: Python export module
│   ├── __init__.py
│   ├── export_mat.py                # Main export logic
│   ├── field_mapper.py              # DataJoint → epicTree field mapping
│   └── tests/
│       └── test_export.py
└── docs/
    └── dev/
        └── DATA_FORMAT_SPECIFICATION.md  # Contract for export

datajoint/next-app/api/
├── app.py                           # Add /results/export-mat endpoint
└── helpers/
    └── query.py                     # Already has generate_object_tree()
```

### Pattern 1: Export as Pure Function

**What:** Export logic is a pure function that accepts tree structure and returns filepath
**When to use:** For testability and separation from Flask request handling
**Example:**

```python
# epicTreeGUI/python/export_mat.py
import scipy.io
import os
from datetime import datetime

def export_to_mat(tree_data, username, download_dir, h5_file_path=None):
    """
    Export DataJoint tree structure to epicTreeGUI .mat format.

    Args:
        tree_data (list): Output from generate_object_tree(include_meta=True)
        username (str): Database username for metadata
        download_dir (str): Directory to write .mat file
        h5_file_path (str): Optional path to H5 file for lazy loading

    Returns:
        str: Path to generated .mat file

    Raises:
        ValueError: If tree_data structure is invalid
        IOError: If write fails
    """
    # Build hierarchical structure matching DATA_FORMAT_SPECIFICATION
    experiments = []

    for exp_node in tree_data:
        experiment = build_experiment_struct(exp_node, h5_file_path)
        experiments.append(experiment)

    # Create export data structure
    export_data = {
        'format_version': '1.0',
        'metadata': {
            'created_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'data_source': 'DataJoint + H5 files',
            'export_user': username
        },
        'experiments': experiments
    }

    # Write to .mat file
    filename = f"epictree_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mat"
    filepath = os.path.join(download_dir, filename)

    scipy.io.savemat(
        filepath,
        export_data,
        do_compression=True,  # Reduce file size
        oned_as='row',        # MATLAB convention for 1-D arrays
        format='5'            # MATLAB v5 format (most compatible)
    )

    return filepath
```

### Pattern 2: Hierarchy Flattening

**What:** Collapse DataJoint's 9-level hierarchy to epicTreeGUI's 5-level format
**When to use:** When mapping between schemas with different organizational structures
**Example:**

```python
def build_experiment_struct(exp_node, h5_file_path):
    """Flatten Animal/Preparation into Cell metadata."""
    exp_data = exp_node['object'][0]

    experiment = {
        'id': exp_node['id'],
        'exp_name': exp_data['exp_name'],
        'is_mea': bool(exp_data['is_mea']),
        'label': exp_node.get('label', ''),
        'cells': []
    }

    # Navigate: Experiment → Animal → Preparation → Cell
    # Flatten to: Experiment → Cell with merged metadata
    for animal_node in exp_node['children']:
        animal_data = animal_node['object'][0]

        for prep_node in animal_node['children']:
            prep_data = prep_node['object'][0]

            for cell_node in prep_node['children']:
                cell_data = cell_node['object'][0]

                # Merge Animal + Preparation into Cell properties
                cell = {
                    'id': cell_node['id'],
                    'label': cell_node.get('label', ''),
                    'type': cell_data.get('type', ''),
                    'properties': {
                        # Animal metadata
                        'species': animal_data.get('species'),
                        'age': animal_data.get('age'),
                        # Preparation metadata
                        'bath_solution': prep_data.get('bath_solution'),
                        'region': prep_data.get('region'),
                        # Cell-specific properties
                        **extract_json_fields(cell_data.get('properties', {}))
                    },
                    'epoch_groups': build_epoch_groups(cell_node['children'], h5_file_path)
                }

                experiment['cells'].append(cell)

    return experiment
```

### Pattern 3: JSON Blob Extraction

**What:** Parse DataJoint's `properties` and `attributes` JSON fields into typed struct fields
**When to use:** When extracting known fields from unstructured JSON storage
**Example:**

```python
# epicTreeGUI/python/field_mapper.py
KNOWN_FIELDS = {
    'experiment': ['rig', 'experimenter', 'institution', 'start_time'],
    'cell': ['type', 'noise_id'],
    'epoch_group': ['protocol_name', 'start_time', 'end_time'],
    'epoch_block': ['protocol_name', 'start_time', 'end_time'],
    'epoch': ['parameters', 'start_time', 'end_time']
}

def extract_json_fields(json_obj, level='epoch'):
    """
    Extract known fields from JSON blob, leave rest in properties.

    Returns:
        tuple: (known_fields_dict, unknown_fields_dict)
    """
    known = {}
    unknown = {}

    if not isinstance(json_obj, dict):
        return {}, {}

    known_field_names = KNOWN_FIELDS.get(level, [])

    for key, value in json_obj.items():
        if key in known_field_names:
            known[key] = value
        else:
            unknown[key] = value

    return known, unknown
```

### Pattern 4: H5 Path Preservation (Lazy Loading)

**What:** Store H5 dataset paths in response structs, don't embed waveform data
**When to use:** Always (per user constraint — keep .mat files small)
**Example:**

```python
def build_response_struct(response_data, h5_file_path):
    """Build response struct with H5 path for lazy loading."""
    return {
        'id': response_data['id'],
        'device_name': response_data['device_name'],
        'label': response_data.get('label', ''),

        # H5 lazy loading fields (no embedded data)
        'data': [],  # Empty — loaded on-demand via h5_path
        'h5_path': response_data['h5path'],  # Path within H5 file

        # Metadata
        'sample_rate': parse_sample_rate(response_data.get('sample_rate')),
        'sample_rate_units': response_data.get('sample_rate_units', 'Hz'),
        'units': 'mV',  # Default for patch clamp
        'spike_times': [],  # Empty for now (computed on-demand)
        'offset_ms': 0.0
    }

def parse_sample_rate(rate_str):
    """Convert DataJoint sample_rate string to numeric Hz."""
    if rate_str is None:
        return 10000  # Default

    if isinstance(rate_str, (int, float)):
        return float(rate_str)

    # Parse "10000 Hz" or "10 kHz" formats
    import re
    match = re.search(r'(\d+(?:\.\d+)?)\s*(Hz|kHz|MHz)?', str(rate_str))
    if match:
        value = float(match.group(1))
        unit = match.group(2) or 'Hz'

        if unit == 'kHz':
            value *= 1000
        elif unit == 'MHz':
            value *= 1e6

        return value

    return 10000  # Fallback default
```

### Pattern 5: Flask Endpoint Integration

**What:** Thin Flask endpoint that calls export function and returns file
**When to use:** Minimal Flask-specific code, delegate to library
**Example:**

```python
# datajoint/next-app/api/app.py
from flask import send_file
import sys
import os

# Add epicTreeGUI python module to path
EPICTREE_PYTHON_PATH = os.path.abspath("../../epicTreeGUI/python")
sys.path.insert(0, EPICTREE_PYTHON_PATH)

from export_mat import export_to_mat

@app.route('/results/export-mat', methods=['POST'])
def export_mat_file():
    """Export current query results to epicTreeGUI .mat format."""
    if not query or not username or not db:
        return jsonify({"message": "Run a query first!"}), 400

    try:
        from helpers.query import generate_object_tree

        # Reuse existing query traversal with full metadata
        tree_data = generate_object_tree(
            query,
            exclude_levels=[],  # Include all levels
            cur_level=0
        )

        if not tree_data:
            return jsonify({"message": "No data to export"}), 400

        # Get H5 file path from first experiment
        exp_id = tree_data[0]['id']
        h5_file = (db.Experiment & f'id={exp_id}').fetch1('data_file')

        # Call export function
        filepath = export_to_mat(
            tree_data=tree_data,
            username=username,
            download_dir=download_dir,
            h5_file_path=h5_file
        )

        # Return file for download
        return send_file(
            filepath,
            as_attachment=True,
            download_name=os.path.basename(filepath),
            mimetype='application/x-matlab-data'
        )

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"message": f"Export failed: {str(e)}"}), 500
```

### Anti-Patterns to Avoid

- **Embedding waveform data in .mat file:** Violates user constraint to keep h5path references only. Results in massive files.
- **Modifying epicTreeGUI MATLAB backend:** User constraint says build around existing system. Export must match DATA_FORMAT_SPECIFICATION exactly.
- **Real-time mask synchronization:** .ugm files are separate from .mat export (selection state is a different concern, handled by GUI later).
- **Nested dict structures in scipy.savemat:** Known issue with nested dicts (see Common Pitfalls). Flatten to struct fields where possible.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MATLAB file I/O | Custom binary writer | scipy.io.savemat() | Handles MATLAB v5/v7/v7.3 formats, compression, cell arrays, structs. Extensive edge case handling. |
| HDF5 reading | Low-level h5py calls scattered everywhere | Existing `get_options()` in query.py | Already tested, returns h5_file + h5_path pairs |
| JSON flattening | Recursive dict walker | Simple known-field extraction | Spec defines exact fields needed. Extract those, dump rest to `properties` |
| Field type conversion | Manual string parsing | Use DataJoint heading.attributes type info | Schema already knows field types (timestamp, numeric, json, string) |

**Key insight:** The DataJoint infrastructure already handles database querying and H5 path lookup. The export is just a **format conversion** from the existing `generate_object_tree()` output to scipy-compatible nested dicts.

## Common Pitfalls

### Pitfall 1: Nested Dict Handling in scipy.io.savemat

**What goes wrong:** scipy has known issues with deeply nested dicts like `{'b':{'c':{'d': 3}}}`. MATLAB may fail to load or access fields.

**Why it happens:** scipy.io converts Python dicts to MATLAB structs, but MATLAB's struct access syntax is different. Deeply nested structs from Python may not roundtrip correctly.

**How to avoid:**
- Flatten nested JSON blobs to dot-separated field names when possible
- For epoch parameters: `{'spotIntensity': 0.5, 'preTime': 500}` instead of `{'stimulus': {'spot': {'intensity': 0.5}}}`
- Test loading in MATLAB: `data = load('test.mat'); data.experiments{1}.cells{1}`

**Warning signs:** MATLAB error "Reference to non-existent field" when accessing nested structs

**Source:** [scipy.io.loadmat nested structures issue #2042](https://github.com/scipy/scipy/issues/2042)

### Pitfall 2: Cell Array vs Struct Array Confusion

**What goes wrong:** Python list `[{}, {}, {}]` becomes MATLAB cell array `{ struct, struct, struct }` not struct array `struct(1), struct(2), struct(3)`.

**Why it happens:** scipy.io.savemat converts Python lists to MATLAB cell arrays by default. MATLAB has two array types: cell arrays (heterogeneous) and struct arrays (homogeneous structs with same fields).

**How to avoid:**
- Use Python list for collections: `cells = [cell1_dict, cell2_dict, ...]`
- MATLAB will load as cell array: `cells{1}.id, cells{2}.id`
- epicTreeGUI's loadEpicTreeData() handles both (lines 83-87, 92-96 check `iscell()`)

**Warning signs:** MATLAB indexing requires `{}` not `()` when accessing exported arrays

### Pitfall 3: Missing/Null Field Handling

**What goes wrong:** DataJoint query returns None for optional fields, scipy chokes on Python None values.

**Why it happens:** MATLAB doesn't have Python's None. scipy.io.savemat needs explicit empty values.

**How to avoid:**
- Convert None to appropriate MATLAB empty: `[] for arrays`, `'' for strings`, `struct() for objects`
- Use helper function:
  ```python
  def sanitize_for_matlab(value):
      if value is None:
          return []  # MATLAB empty array
      if isinstance(value, dict) and not value:
          return {}  # Empty struct
      return value
  ```

**Warning signs:** scipy raises TypeError on None values during savemat()

### Pitfall 4: 1-D Array Orientation

**What goes wrong:** NumPy 1-D array `[1, 2, 3]` becomes MATLAB column vector by default, expected row vector.

**Why it happens:** MATLAB convention is row vectors for 1-D data, NumPy/Python convention is agnostic.

**How to avoid:** Set `oned_as='row'` in savemat() call (recommended in user discretion).

**Warning signs:** MATLAB dimension mismatch errors when expecting row vectors

**Source:** [scipy.io.savemat documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.io.savemat.html)

### Pitfall 5: HDF5 Compound Datatype Reading

**What goes wrong:** DataJoint stores responses in H5 with compound dtype like `{quantity: float[], time: float[]}`. Reading entire dataset loads unnecessary fields.

**Why it happens:** H5 compound types pack multiple arrays into single dataset.

**How to avoid:**
- Use `dset.fields('quantity')[:]` to read single field
- For waveform data: `f[h5_path]['data']['quantity'][:]` (only quantity, skip time)
- This is DataJoint's existing pattern (query.py line 318)

**Warning signs:** Memory usage spikes, slow reads when only need one field from compound type

**Source:** [h5py Datasets - Compound datatypes](https://docs.h5py.org/en/stable/high/dataset.html)

## Code Examples

Verified patterns from official sources and existing codebase:

### scipy.io.savemat with Compression

```python
# Source: https://docs.scipy.org/doc/scipy/reference/generated/scipy.io.savemat.html
import scipy.io

data = {
    'format_version': '1.0',
    'metadata': {'created_date': '2026-02-16'},
    'experiments': [
        {'id': 1, 'exp_name': '20250115A', 'cells': []}
    ]
}

scipy.io.savemat(
    'output.mat',
    data,
    do_compression=True,  # Enable compression
    oned_as='row',        # 1-D arrays as row vectors
    format='5',           # MATLAB v5 format
    long_field_names=False  # Short field names for compatibility
)
```

### DataJoint Query Tree Traversal (Existing Pattern)

```python
# Source: datajoint/next-app/api/helpers/query.py lines 209-253
from helpers.query import generate_object_tree, create_query

# Build query from UI query object
query = create_query(query_obj, username, db)

# Generate full tree with metadata
tree = generate_object_tree(
    query=query,
    exclude_levels=[],  # Include all levels
    cur_level=0
)

# Tree structure:
# [
#   {
#     'level': 'experiment',
#     'id': 1,
#     'is_mea': False,
#     'object': [{...full DB row...}],
#     'tags': [...],
#     'children': [
#       {
#         'level': 'animal',
#         'id': 5,
#         'object': [{...}],
#         'children': [...]
#       }
#     ]
#   }
# ]
```

### H5 Path Extraction (Existing Pattern)

```python
# Source: datajoint/next-app/api/helpers/query.py lines 260-277
def get_options(level, id, experiment_id):
    """Get H5 paths for responses/stimuli."""
    if level == 'epoch':
        h5_file, is_mea = (Experiment & f'id={experiment_id}').fetch1('data_file', 'is_mea')

        responses = []
        for item in (Response & f'parent_id={id}').fetch(as_dict=True):
            responses.append({
                'label': item['device_name'],
                'h5_path': item['h5path'],  # Path within H5 file
                'h5_file': h5_file,         # Absolute file path
                'vis_type': 'epoch-singlecell'
            })

        return {'responses': responses, 'stimuli': [...]}
```

### Flask File Download (Best Practice)

```python
# Source: https://pythonprogramming.net/flask-send-file-tutorial/
from flask import send_file
import os

@app.route('/download')
def download_file():
    filepath = '/path/to/generated/file.mat'

    return send_file(
        filepath,
        as_attachment=True,
        download_name='epictree_export.mat',
        mimetype='application/x-matlab-data'
    )
```

### MATLAB struct array handling in loadEpicTreeData

```matlab
% Source: epicTreeGUI/src/loadEpicTreeData.m lines 81-116
% Handles both cell arrays and struct arrays from scipy
for i = 1:length(treeData.experiments)
    % Handle both cell arrays and struct arrays
    if iscell(treeData.experiments)
        exp = treeData.experiments{i};
    else
        exp = treeData.experiments(i);
    end

    totalCells = totalCells + length(exp.cells);

    for j = 1:length(exp.cells)
        if iscell(exp.cells)
            cell = exp.cells{j};
        else
            cell = exp.cells(j);
        end
        % Process cell...
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Java-based epoch tree with database | Pure MATLAB tree + Python export | 2025-2026 | Simpler deployment, no Java dependency |
| Embedded waveform data in .mat | Lazy loading via H5 paths | Always (spec) | Smaller .mat files, shared H5 storage |
| Manual JSON export + custom loader | scipy.io.savemat + standard format | Current phase | MATLAB compatibility guaranteed |
| Direct H5 file parsing in MATLAB | Python export pipeline | Architecture decision | Separation of data packaging from visualization |

**Deprecated/outdated:**
- **Java-based epochTreeGUI:** Replaced by pure MATLAB implementation (epicTreeGUI)
- **Direct MATLAB H5 reading:** Replaced by Python export pipeline (cleaner separation)
- **Custom .mat file writers:** scipy.io is the standard, well-tested library

## Open Questions

1. **How to handle experiment-level H5 file path?**
   - What we know: DataJoint stores `data_file` field in Experiment table
   - What's unclear: Should .mat file include absolute path, or relative to configured H5 dir?
   - Recommendation: Store absolute path in .mat file, let epicTreeGUI config map to local H5 directory if needed (matches existing `epicTreeConfig('h5_dir')` pattern)

2. **Should empty responses (no device_name/h5path) be included?**
   - What we know: Some epochs may have no recorded responses (protocol issue, hardware failure)
   - What's unclear: Filter these out during export, or include as empty response structs?
   - Recommendation: Include empty array `responses: []` for epochs with no data. Easier to handle in MATLAB than missing field.

3. **Parameter JSON nesting depth limit?**
   - What we know: Epoch parameters stored as JSON blobs, can be arbitrarily nested
   - What's unclear: At what nesting depth does scipy.io.savemat break?
   - Recommendation: Flatten all parameter dicts to single level with dot-separated keys (e.g., `stimulus.spot.intensity` → `stimulus_spot_intensity`). Test with real DataJoint data.

4. **MEA vs patch clamp field differences?**
   - What we know: Phase scope is single-cell patch only
   - What's unclear: What fields differ between MEA and patch in current DataJoint schema?
   - Recommendation: Document MEA-specific fields in export code comments for future phase. Current export should check `is_mea` flag and error if true.

## Sources

### Primary (HIGH confidence)
- [scipy.io.savemat API documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.io.savemat.html) - Complete parameter reference
- [h5py Datasets documentation](https://docs.h5py.org/en/stable/high/dataset.html) - Compound datatype handling
- [DataJoint Fetch documentation](https://docs.datajoint.com/core/datajoint-python/latest/query/fetch/) - Query result handling
- epicTreeGUI/docs/dev/DATA_FORMAT_SPECIFICATION.md - Export target format
- epicTreeGUI/src/loadEpicTreeData.m - MATLAB loading validation
- datajoint/next-app/api/helpers/query.py - Existing tree generation

### Secondary (MEDIUM confidence)
- [Flask send_file tutorial](https://pythonprogramming.net/flask-send-file-tutorial/) - File download pattern
- [Flask file upload/download guide](https://www.geeksforgeeks.org/python/uploading-and-downloading-files-in-flask/) - Response construction
- [scipy.io nested structures issue #2042](https://github.com/scipy/scipy/issues/2042) - Known nested dict limitation

### Tertiary (LOW confidence)
- None identified - all findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - scipy.io.savemat is well-documented, stable API since 2008
- Architecture: HIGH - Existing codebase patterns are clear and tested
- Pitfalls: HIGH - Documented issues with nested dicts and cell arrays, solutions verified
- Integration: MEDIUM - Flask endpoint pattern is standard, but epicTreeGUI import path needs testing

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (30 days - stable technologies, not fast-moving)

**Key dependencies verified:**
- scipy 1.14+ available (current stable)
- h5py 3.9+ available (current stable)
- Flask 2.3+ in use (datajoint repo)
- Python 3.9+ in use (datajoint repo Poetry config)
- DataJoint existing query infrastructure functional
- epicTreeGUI DATA_FORMAT_SPECIFICATION stable

**Testing prerequisites:**
- Docker MySQL container running
- DataJoint database populated with patch clamp data
- Flask dev server running (`flask run` in api directory)
- MATLAB R2020b+ with epicTreeGUI on path
- H5 files accessible at paths in DataJoint `data_file` field
