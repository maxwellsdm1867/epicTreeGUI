---
phase: 05-datajoint-integration-export-mat-from-datajoint-query-results
plan: 02
subsystem: Flask Endpoint + UI Button + Tags Export
tags: [datajoint, flask, react, export, tags, blueprintjs]
dependency_graph:
  requires: [export_mat.py, field_mapper.py, generate_tree()]
  provides: [/results/export-mat endpoint, "Export to epicTree" button, tags in .mat export]
  affects: [DataJoint web UI, epicTreeGUI .mat format]
key_files:
  created:
    - .planning/phases/05-datajoint-integration-export-mat-from-datajoint-query-results/05-02-SUMMARY.md
  modified:
    - /Users/maxwellsdm/Documents/GitHub/datajoint/next-app/api/app.py
    - /Users/maxwellsdm/Documents/GitHub/datajoint/next-app/src/app/components/ResultsViewer.js
    - python/export_mat.py
decisions:
  - Tags extracted at every hierarchy level (experiment, cell, epoch_group, epoch_block, epoch)
  - Tags stored as [{user, tag}] arrays in .mat file (stripped of DB-internal fields)
  - Lazy import of export_mat inside Flask handler (not at startup)
  - Blob responseType for axios (binary .mat file, not JSON)
  - BlueprintJS intent="success" (green) for Export button visual distinction
metrics:
  duration_minutes: 5
  tasks_completed: 3
  files_modified: 3
  test_coverage: 33 existing tests still passing
  completed_date: 2026-02-16
---

# Phase 05 Plan 02: Flask Endpoint + UI Button + Tags in Export

**One-liner:** Wired Flask /results/export-mat endpoint, "Export to epicTree" UI button, and added DataJoint tags to every level of the .mat export.

## Summary

Completed the end-to-end DataJoint-to-epicTreeGUI export pipeline:

1. **Flask endpoint** (`/results/export-mat`): Calls `generate_tree(include_meta=True)`, passes to `export_to_mat()`, returns .mat file via `send_file()` with proper error handling for MEA data, missing queries, and import errors.

2. **UI button** ("Export to epicTree"): Green button in ResultsViewer ButtonGroup. Uses axios with `responseType: 'blob'` for binary download. Blob error parsing for error messages. Snackbar feedback for success/error.

3. **Tags in export**: Added `extract_tags()` to export_mat.py that strips DB-internal fields (tag_id, table_name, table_id, experiment_id, h5_uuid) and keeps only `{user, tag}` pairs. Tags now flow through at all 5 hierarchy levels in the .mat file.

## Tasks Completed

### Task 1: Flask /results/export-mat endpoint (already in app.py)

The endpoint was implemented in the previous session at app.py:391-433. Key features:
- Lazy import of `export_mat` inside handler
- Calls `generate_tree(query, exclude_levels, include_meta=True)`
- Returns .mat file via `send_file(as_attachment=True)`
- ValueError → 400 (MEA not supported), ImportError → 500 (module missing), generic Exception → 500

### Task 2: "Export to epicTree" button (already in ResultsViewer.js)

The button and handler were implemented in the previous session at ResultsViewer.js:99-197. Key features:
- `handleExportMat()` with `responseType: 'blob'` for binary download
- Blob-to-text parsing for error messages (since axios blob responses don't auto-parse JSON errors)
- `window.URL.createObjectURL` + programmatic link click for download
- BlueprintJS `intent="success"` (green) and `icon="export"`

### Task 3: Tags in .mat export (new this session)

Added `extract_tags()` function to export_mat.py and integrated at all 5 hierarchy levels:
- `build_experiment()` → `experiment['tags']`
- `build_cell()` → `cell['tags']`
- `build_epoch_group()` → `epoch_group['tags']`
- `build_epoch_block()` → `epoch_block['tags']`
- `build_epoch()` → `epoch['tags']`

## How Tags Work in the Export Pipeline

### Tag Source: DataJoint Tags Table

```
Tags table schema:
  tag_id (int, auto-increment)
  h5_uuid (varchar)
  experiment_id (int)
  table_name (varchar) — 'experiment', 'cell', 'epoch_group', 'epoch_block', 'epoch'
  table_id (int)
  user (varchar)
  tag (varchar)
```

### Tag Flow: Database → Tree → .mat File

```
1. User adds tags in DataJoint web UI
   → Tags table: {tag_id: 1, h5_uuid: 'abc', experiment_id: 5,
                   table_name: 'epoch', table_id: 42, user: 'alice', tag: 'good'}

2. generate_tree() fetches tags at each node (query.py line 195):
   child['tags'] = (Tags & f'table_name="{level}"' & f'table_id={id}')
                   .proj('user', 'tag').fetch(as_dict=True)
   → [{'user': 'alice', 'tag': 'good'}, {'user': 'bob', 'tag': 'review'}]

3. export_mat.py extract_tags() strips DB fields, keeps {user, tag}:
   → [{'user': 'alice', 'tag': 'good'}, {'user': 'bob', 'tag': 'review'}]

4. scipy.io.savemat writes to .mat file:
   → epoch.tags = struct array with .user and .tag fields
```

### Tag Persistence: Push/Pull/Reset

Tags have a three-tier persistence model:
- **Database (Tags table):** Working state, per-user, real-time
- **JSON files (on NAS):** Shared state, per-experiment, pushed/pulled manually
- **UI (ResultsTree):** Display only, refreshed on query

Tag operations:
- **Push:** Export your tags from DB to JSON file (overwrites your previous tags, preserves others)
- **Pull:** Import other users' tags from JSON to DB (preserves your tags)
- **Reset:** Clear all tags in DB, reimport from JSON (both your tags and others)

### Reading Tags in MATLAB

After loading the .mat file in epicTreeGUI:
```matlab
[data, ~] = loadEpicTreeData('epictree_export.mat');
tree = epicTreeTools(data, 'LoadUserMetadata', 'none');

% Access tags at any level
epochs = tree.getAllEpochs(false);
for i = 1:length(epochs)
    if isfield(epochs{i}, 'tags') && ~isempty(epochs{i}.tags)
        for j = 1:length(epochs{i}.tags)
            fprintf('Tag: %s (by %s)\n', epochs{i}.tags(j).tag, epochs{i}.tags(j).user);
        end
    end
end
```

## Verification

- All 33 existing Python tests pass (no regressions from tags addition)
- Flask endpoint already in app.py with proper error handling
- UI button already in ResultsViewer.js with blob download + error parsing
- Tags gracefully default to empty list when not present in node data
- Task 3 (human verification gate) pending: requires running DataJoint app end-to-end

## Deviations from Plan

1. **Tags added to export:** Plan didn't mention tags, but user requested documenting how tags work in the export. Added `extract_tags()` and integrated at all levels.
2. **Tasks 1 & 2 already implemented:** These were done in the previous session; this session verified they're correct and added the tags integration.

## Next Steps

- **Human verification (Task 3):** Start DataJoint app, run query, click "Export to epicTree", load in MATLAB
- **Tags as splitter:** Could add `splitOnTag` splitter to epicTreeTools for filtering epochs by DataJoint tags
- **UGM → Tags round-trip:** Read .ugm selection mask in Python, write back to DataJoint Tags table
