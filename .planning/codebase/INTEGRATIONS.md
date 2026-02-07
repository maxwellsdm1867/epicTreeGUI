# External Integrations

**Analysis Date:** 2026-02-06

## APIs & External Services

**Rieke Lab DataJoint Database:**
- Service: DataJoint ORM for neurophysiology metadata
- What it's used for: Query experiment metadata, cell information, epoch parameters
- SDK/Client: `datajoint` Python package (used in export pipeline only, not in MATLAB GUI)
- Auth: Via DataJoint configuration (username/password, not in this repo)
- Location: Used in `python_export/export_to_epictree.py` lines 25-29
- Queries: `create_query()`, `generate_tree()`, `get_options()`, `fill_tables()` from `helpers.query`

**RetinAnalysis Pipeline:**
- Service: Custom Python library for neurophysiology data processing
- What it's used for: Export epoch data, stimulus parameters, response spike times to MATLAB format
- SDK/Client: `retinanalysis` Python module
- Import path: `/Users/maxwellsdm/Documents/GitHub/new_retinanalysis/` (referenced in MATLAB export)
- Location: Used in `python_export/example_export.py` line 14
- Function: `retinanalysis.utils.matlab_export.export_pipeline_to_matlab()`

**MCP MATLAB Server:**
- Service: Model Context Protocol (stdio) server for Claude Code integration
- What it's used for: Allow Claude AI to execute MATLAB code and tests
- Config: `mcp.json` with server command `/Users/maxwellsdm/bin/matlab-mcp-core-server`
- Args: `--matlab-root=/Applications/MATLAB_R2022a.app`, `--initial-working-folder=<repo>`, `--initialize-matlab-on-startup=true`
- Protocol: stdio (stdin/stdout communication)

## Data Storage

**Databases:**
- **Primary:** HDF5 files (.h5) - Read-only
  - What: Response data (electrophysiology traces, spike times, stimulus waveforms)
  - Client: MATLAB built-in `h5read()`, Python `h5py` library
  - Location: `/Volumes/rieke-nas/data/h5/` or local mounts (path aliases in `src/loadH5ResponseData.m` lines 56-60)
  - Connection: Network NAS or local filesystem

**Metadata Storage:**
- **Primary:** MATLAB .mat files (.mat)
  - What: Hierarchical epoch structures, cell type classifications, experiment metadata
  - Format: Version 1.0 (backward compatible)
  - Client: MATLAB `load()`, `save()`, scipy `savemat()`
  - Compression: Yes (scipy saves with `do_compression=True` in `python_export/export_to_epictree.py` line 124)

**File Storage:**
- Local/NAS filesystem (no cloud storage)
  - Development: `/Users/maxwellsdm/Documents/epicTreeTest/`
  - Production: `/Volumes/rieke-nas/` (Rieke Lab network storage)

**Caching:**
- In-memory tree structure (MATLAB) - `epicTreeTools` class caches entire epoch hierarchy once loaded
- Lazy loading of actual response data - H5 data only loaded when epoch is clicked
- No persistent cache between sessions

## Authentication & Identity

**Auth Provider:**
- Custom DataJoint authentication (Python export layer only)
- No auth in MATLAB GUI - assumes pre-exported .mat file provided
- Username for exports: Retrieved via `getenv('USER')` or override in `src/config/epicTreeConfig.m` line 109

**Implementation Approach:**
- MATLAB GUI accepts pre-built data structures (no remote queries)
- Python export scripts handle DataJoint auth (credentials via DataJoint config, not in repo)
- User identity tracked in metadata: `metadata.export_user` in exported .mat files

## Monitoring & Observability

**Error Tracking:**
- None (no external service)
- Custom error handling: try/catch blocks in MATLAB
- Examples: `src/loadEpicTreeData.m` lines 37-41, `src/loadH5ResponseData.m` lines 90-154

**Logs:**
- Console output (fprintf) only
  - Test results printed to command window
  - Export progress printed during `python_export/export_to_epictree.py` execution
  - Debug traces in `debug_*.m` scripts

**Debugging:**
- Manual inspection via script-based helpers:
  - `inspect_mat_file.m` - Structure inspection
  - `debug_splitter_values.m` - Inspect tree split organization
  - `debug_tree_structure.m` - Verify tree node creation

## CI/CD & Deployment

**Hosting:**
- Local MATLAB application
- H5 data served from NAS (Rieke Lab infrastructure)
- No cloud hosting, no API server

**CI Pipeline:**
- None (no automated CI configured)
- Manual testing via test scripts in `tests/` directory
- MCP MATLAB server used for Claude-driven testing

**Deployment:**
- Distribution: Git repository + data files
- Setup: Clone repo, configure H5 directory path, run `START_HERE.m`
- No package manager, no installation script

## Environment Configuration

**Required env vars:**
- `USER` - System username (fallback to 'guest' in `src/config/epicTreeConfig.m` line 111)
- `HOME` - Home directory (for path expansion in config at line 123)
- No custom env vars required for GUI operation
- Python scripts may require: `DATAJOINT_CONFIG` or DataJoint login credentials

**Secrets location:**
- `.env` file: Not used (not in repo)
- Credentials: Via DataJoint system configuration (macOS Keychain or `~/.datajoint/config.json`)
- H5 paths: Stored in MATLAB persistent config or passed as function arguments
- No hardcoded secrets in codebase (paths are configuration, not secrets)

**Configuration Persistence:**
- `epicTreeConfig()` function - Persistent MATLAB variables (session-scoped)
- Can save/load config via: `epicTreeConfig('save', filepath)` or `epicTreeConfig('load', filepath)`

## Webhooks & Callbacks

**Incoming:**
- None (GUI is event-driven, not webhook-driven)
- User interaction: Mouse clicks, keyboard navigation, checkbox toggles
- Callbacks internal to MATLAB app

**Outgoing:**
- None (no external notifications)

**Data Exchange:**
- One-way: RetinAnalysis → Python export → .mat file → MATLAB GUI
- No reverse communication to DataJoint or external services
- Analysis results stored locally in .mat files or in-memory tree nodes

## File Format Details

**MAT File Structure** (exported format version 1.0):
```matlab
struct with fields:
  format_version = '1.0'
  metadata = struct(
    created_date,
    data_source,
    source_database,
    export_user,
    query_object,
    num_experiments
  )
  experiments = cell array of structs:
    id, exp_name, label, is_mea, start_time, experimenter, rig
    cells = cell array:
      cellInfo struct (type, label, id, etc.)
      epoch_groups = cell array:
        groupInfo struct
        epoch_blocks = cell array:
          blockInfo struct
          epochs = cell array:
            cellInfo, parameters, responses, stimuli, isSelected
            responses array with: device_name, h5_path, h5_file, data
```

**H5 Response Data Structure:**
- Path pattern: `/experiment-.../responses/Amp1-...`
- Compound dataset fields: `quantity` (float64), `units` (string)
- Read via: `h5read(h5_file, path)` in `src/loadH5ResponseData.m`

---

*Integration audit: 2026-02-06*
