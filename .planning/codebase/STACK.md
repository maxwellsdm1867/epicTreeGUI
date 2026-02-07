# Technology Stack

**Analysis Date:** 2026-02-06

## Languages

**Primary:**
- MATLAB R2022a - Main application framework, all core logic, GUI components, tree structure, analysis functions

**Secondary:**
- Python 3.9+ - Data export pipeline, bridges RetinAnalysis dataset to MATLAB-compatible .mat format

## Runtime

**Environment:**
- MATLAB R2022a (via `/Applications/MATLAB_R2022a.app`)
- Python 3.9 (for export utilities)

**Package Manager:**
- MATLAB Built-in (no external dependency manager)
- Python: pip (requirements managed in export scripts)
- Lockfile: Not applicable for MATLAB; Python dependencies specified inline in scripts

## Frameworks

**Core:**
- Pure MATLAB (no external frameworks) - All application logic is native MATLAB
- MCP MATLAB Server - Protocol server for Claude Code integration (stdio-based communication)

**Testing:**
- MATLAB built-in testing framework - Tests run via `run tests/test_*.m` pattern
- No external test framework (xunit-style manual organization)

**Build/Dev:**
- No build system - Direct execution of .m files
- MCP JSON config at `mcp.json` - Configures MATLAB server for development

## Key Dependencies

**Critical (MATLAB Built-in):**
- `h5read` / `h5info` - HDF5 file reading (built-in MATLAB function)
  - Used in `src/loadH5ResponseData.m` for lazy loading response data
  - Enables on-demand data loading from H5 files without preloading full dataset

**Critical (Python):**
- `scipy.io.savemat` - MATLAB .mat file writer
  - Used in `python_export/export_to_epictree.py` for exporting data
  - Saves compressed MATLAB-compatible structures from Python

- `h5py` - HDF5 file reading in Python
  - Used in `python_export/export_to_epictree.py` for loading H5 files from RetinAnalysis pipeline
  - Extracts response data and metadata

- `datajoint as dj` - Database query interface
  - Used in `python_export/export_to_epictree.py` at line 25
  - Queries experiment metadata, cell information, epoch data
  - Connects to Rieke Lab's DataJoint database

- `numpy` - Numeric operations
  - Used in `python_export/export_to_epictree.py` at line 19
  - Handles numeric array conversions

- `retinanalysis` - Custom pipeline module
  - Used in `python_export/example_export.py` at line 14
  - Provides `export_pipeline_to_matlab()` function (line 15)
  - Converts RetinAnalysis pipeline output to MATLAB format

**Infrastructure (Python):**
- `json` - Structured data export (standard library)
- `datetime` - Timestamp generation (standard library)
- `typing` - Type hints (standard library)
- `os`, `sys` - System operations (standard library)

## Configuration

**Environment:**
- H5 directory (where .h5 response files live):
  - Searched in order: `/Users/maxwellsdm/Documents/epicTreeTest/h5`, `/Volumes/rieke-nas/data/h5`, `/Volumes/rieke/data/h5`
  - Configured via `epicTreeConfig('h5_dir', path)` in `src/config/epicTreeConfig.m`
  - Can be persisted to .mat file or auto-detected

- Database credentials (Python only):
  - DataJoint requires login; handled via `datajoint` configuration
  - Not version-controlled (security)

**Build:**
- No build configuration files (pure MATLAB execution)
- MCP server config: `mcp.json` - Defines MATLAB server startup with working folder and initialization

**Data Format:**
- Version: 1.0 (defined in exported .mat files)
- Backward compatible; version check in `src/loadEpicTreeData.m` line 44-56

## Platform Requirements

**Development:**
- macOS 10.14+ (tested on Darwin 23.2.0 - macOS Sonoma)
- MATLAB R2022a or later (MCP server path hardcoded to R2022a)
- Python 3.9+ (for export utilities only, not required for GUI operation)
- H5 files accessible via network path or local mount

**Production:**
- MATLAB R2022a runtime (or full MATLAB license)
- HDF5 file support (built into MATLAB)
- Network access to H5 file storage (NAS paths: `/Volumes/rieke-nas/` or `/Volumes/rieke/`)
- Test data location: `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`

## Data I/O

**Input Formats:**
- `.mat` files - Structured epoch hierarchies exported from RetinAnalysis pipeline
  - Fields: `format_version`, `metadata`, `experiments` (nested: cells, epoch_groups, epoch_blocks, epochs)
  - Loaded by `src/loadEpicTreeData.m`

- `.h5` files - Response data from RetinAnalysis
  - Path structure: `/experiment-.../responses/Amp1-...` (internal HDF5 paths)
  - Lazy loaded by `src/loadH5ResponseData.m` on demand
  - Contains compound datasets with `quantity` (float64) and `units` (string) fields

**Output Formats:**
- `.mat` - Analysis results, configurations, exported datasets
- Console logging - Test output, debug traces

**Format Compatibility:**
- Handles both MATLAB cell arrays and struct arrays (backward compatibility)
- Field aliasing: `parameters` and `protocolSettings` treated interchangeably

---

*Stack analysis: 2026-02-06*
