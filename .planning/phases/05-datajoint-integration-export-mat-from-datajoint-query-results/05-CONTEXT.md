# Phase 5: DataJoint Integration — Export .mat from DataJoint Query Results - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a Flask endpoint (`/results/export-mat`) to the SamarjitK/datajoint web app that exports query results in epicTreeGUI's standard `.mat` format (as defined in `docs/dev/DATA_FORMAT_SPECIFICATION.md`). Include a UI button in the DataJoint web interface alongside the existing JSON download. The export code lives in the epicTreeGUI repository (`python/` directory) and is imported by the Flask app. End-to-end test: DataJoint query → export → load in MATLAB → epicTreeTools tree builds correctly.

Single-cell patch clamp data only (no MEA in this phase).

</domain>

<decisions>
## Implementation Decisions

### Hierarchy mapping
- Flatten Animal and Preparation metadata into cell-level metadata (merge species, bath_solution, region, etc. into each cell's properties)
- DataJoint's 9-level hierarchy (Experiment → Animal → Preparation → Cell → EpochGroup → EpochBlock → Epoch → Response → Stimulus) maps to epicTreeGUI's 5-level format (Experiment → Cell → EpochGroup → EpochBlock → Epoch with nested responses/stimuli)
- Animal/Preparation fields become part of `cellInfo` or `cell.properties`

### Field mapping
- Strict mapping to DATA_FORMAT_SPECIFICATION fields — every field the epicTreeGUI backend expects must be populated from the correct DataJoint column or JSON blob
- Extract known fields from DataJoint's `properties` and `attributes` JSON blobs into the specific struct fields defined in the spec (e.g., `experiment.rig`, `cell.type`, `epoch_group.protocol_name`)
- Unknown/extra fields go into a catchall `properties` struct for discoverability

### Parameter handling
- Convert JSON parameter blobs to flat MATLAB structs (epoch.parameters.contrast, epoch.parameters.spotIntensity, etc.)
- Nested JSON dicts flatten to dot-separated MATLAB struct fields

### Tags
- Export DataJoint tags as custom metadata on each node — accessible via epicTreeGUI's `getCustom('tags')` / `putCustom()` system
- Tags do NOT affect isSelected state — that's managed by .ugm files

### Waveform data
- Keep h5path references for lazy loading — do NOT embed waveform data
- .mat files stay small (metadata only), H5 files remain the waveform data store
- Response struct includes `h5_path` field pointing into the H5 file
- epicTreeGUI's existing `getResponseData()` handles lazy loading from H5

### Export trigger
- New Flask endpoint `/results/export-mat` in the DataJoint web app
- New "Export to epicTree" button in the web UI, next to existing JSON download buttons
- Endpoint reuses existing `generate_tree()` / `generate_object_tree()` query traversal with `include_meta=True`
- Output: timestamped .mat file in `downloads/` directory (same pattern as JSON export)

### Code location
- Export logic lives in epicTreeGUI repo under `python/` directory
- The Flask endpoint in datajoint repo imports from this module
- scipy added as dependency for `savemat()`

### Scope constraints
- Single-cell patch clamp data only — MEA support deferred to future phase
- Do NOT modify epicTreeGUI MATLAB backend unless a blocking bug is found
- All changes must be backward compatible with existing .mat files and loadEpicTreeData()
- Goal: build around the existing system, not change it

### Testing requirements
- DataJoint app must be running and functional (Docker + Flask + Next.js)
- End-to-end test: query in DataJoint → export .mat → load in MATLAB → build tree → verify structure
- UI button must be clickable and trigger export

### Claude's Discretion
- Exact scipy.io.savemat() options (compression, oned_as, etc.)
- How to handle missing/null fields from DataJoint
- Temporary file handling during export
- Error handling and progress reporting in Flask endpoint

</decisions>

<specifics>
## Specific Ideas

- The DataJoint repo is already cloned at `/Users/maxwellsdm/Documents/GitHub/datajoint` with all dependencies installed (Poetry + Python 3.9 + Node.js + Docker available)
- DATA_FORMAT_SPECIFICATION.md already includes a Python export example — use it as the starting template
- The existing `generate_object_tree()` function in `query.py` already traverses the full hierarchy with metadata — the export can wrap this
- DataJoint's `utils.py` has field mappings (`fields` dict) showing which DataJoint columns map to which JSON keys — useful for reverse mapping

</specifics>

<deferred>
## Deferred Ideas

- MEA experiment support (SortingChunk, SortedCell, spike sorting data) — future phase
- Embedded waveform data option (self-contained .mat files) — future enhancement
- Standalone CLI export script (independent of web UI) — future convenience
- Bidirectional sync (.ugm changes back to DataJoint tags) — future integration
- Batch export of multiple queries — future workflow

</deferred>

---

*Phase: 05-datajoint-integration-export-mat-from-datajoint-query-results*
*Context gathered: 2026-02-16*
