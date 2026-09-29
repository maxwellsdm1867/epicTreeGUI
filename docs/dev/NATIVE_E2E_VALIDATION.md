# Native project end-to-end validation

Validated on macOS Apple Silicon, 29 September 2026.

## User journey

1. Start Rieke OS and create a project from the project chooser.
2. Import an H5 recording. Native projects retain a copy inside their folder.
3. Inspect a trace, select an author and save an epoch tag.
4. Close the project. Wait for the closed-project confirmation before copying.
5. Copy the entire project folder using the file manager.
6. Choose **Open project** and select the copied folder. Recordings, metadata,
   tags and protocols load together; no archive is needed.
7. Export selected epochs to SQLite and MATLAB.

The real browser run imported 3 cells, 1,915 epochs, 2,190 responses and 1,915
stimuli. The copied folder reopened independently beside the original with its
saved tag and waveform intact. Both export formats completed for 1,640 epochs.
Unchanged generated MATLAB scripts reconstructed 3 ordered leaves and all 1,640
UUIDs; two 6,000-sample traces at 10 kHz matched direct H5 reads exactly. Shuffled
selection masks, saved masks, all-excluded selections and invalid mappings were
checked. Original recording files were not modified.

## Automated checks

- Python workspace suite: 587 tests passed with native MySQL and native transfer
  integration enabled; no skips.
- Frontend suite: 205 tests passed; production build passed.
- MATLAB: 23 function tests plus portable-tag and native-GUI tag scripts passed.
- Private runtime provisioning: a second installation from the verified package
  cache produced working MySQL 8.4.2 server, client and dump tools.
- Release metadata validation and whitespace checks passed.

Reproduce the backend suite after setup:

```sh
RIEKE_TEST_NATIVE_MYSQL=1 RIEKE_TEST_NATIVE_TRANSFER=1 PYTHONPATH=python \
  .rieke-runtime/venv/bin/python -m unittest discover -s python/tests -p 'test_*workspace*.py'
cd workspace-app
npm test
npm run build
```

## Defects caught and fixed

The real journey caught cross-process shutdown waiting on a non-child zombie,
copied projects being hidden because their scientific UUIDs matched, stale
sender server records, unstable reopened browser origins, and obsolete default
export grouping fields. Regression coverage accompanies those fixes. The MATLAB tree now retains readable row heights and
scrolls expanded epoch lists. Copy
recovery also checks recording hashes, export dependencies and clean shutdown;
unknown-machine dirty copies are rejected.

The project chooser, folder controls and files page were visually inspected in
the real app. The files page groups recordings, imports, exports, saved work and
app storage with consistent icons. Close returns to the chooser with copying
instructions and a copyable folder path.

## Boundaries

Actual folder transfer was tested between two folders on one Mac. Cross-machine
ownership and path conditions have automated coverage, but physical transfers
to a second computer or another OS were not performed. The retained database is
DataJoint/MySQL; SQLite exports and disposable indexes are separate concerns.

The source application runs without Docker using its private runtime. A signed
standalone app installer has not been produced. Automatic release checks and
notifications are implemented; no stable signed release or trusted production
signing key has been published. Release staging/activation tests do not establish
that a public update can already be installed.

## Import and selection follow-up

The project rail's plus opens both New project and Open project. New project
accepts an absolute root folder and creates a new isolated child folder; existing
nonempty folders are never overwritten. A browser-created project under a second
root imported the same real H5 fixture and automatically opened the review dialog.
It showed +1 recording, +3 cells, +1,915 epochs, +2,190 responses and +1,915 stimuli,
separately from source totals, plus the verified managed-copy confirmation.

New imports (including path imports) always use a checksum-verified project copy.
Regression tests remove the original and read a waveform from the managed copy.
Only completed verified imports offer original-removal guidance. Old linked files
and duplicates do not receive that confirmation.

Protocol review supports independent approval, guarded Approve All, inspection,
and dismissal without approval. Analysis inclusion defaults on. Its per-row toggle
updates the existing protocol mask without deleting or hiding the recording.
Epoch selection uses row highlighting, Ctrl/Command-click and Shift-click; the
redundant selection checkbox is removed and row labels display only the number.
The browser verified exclusion with the waveform still visible. The updated
backend suite passed 593 tests with native integration enabled, and 209 frontend
tests plus production build passed.


## Exact project folders

The creation form now uses one exact project folder rather than requiring a
parent root plus managed child. The browser created and opened a native project
directly at the selected path. Explicit read-only preflight rejects missing or
inconsistent manifests, storage layout and initialized database files.

The browser also moved the populated 1,915-epoch fixture into the preferred
projects location using the optional Move & open control. In-app relocation
requires a closed native project and an unused destination on the same
filesystem; atomic exclusive rename prevents destination overwrite. Cross-volume
moves leave the source untouched and direct the user to copy/open via their file
manager. Existing root/directory API parameters remain for compatibility.


## Quiet import notifications

Routine import status now appears as a compact upper-right notification. Normal
notices expire after six seconds and attention notices after ten; hover/focus
pauses expiry. Clicking View details opens the import workbench. Existing history
is not replayed as new notifications after reload. Completion no longer opens a
modal automatically; the review dialog is available explicitly from Review import.
The browser verified a real duplicate import notification and automatic expiry,
with no persistent header bar or automatic review dialog. App update notices also
expire; their availability indicator remains in Release / Publish.

## Pinned query approval demonstration

A synthetic H5 fixture derived from the read-only test recording (fresh, disjoint
UUIDs and explicit Synthetic demo cell labels) added 3 cells and 9 epochs to the
disposable project. Automatic saved-query reruns produced three candidates:
Variable Mean Noise +3 epochs, Expanding Spots +3 epochs, and unpinned Single Spot
+3 epochs. The overall protocol-type delta was correctly zero for known names.

The browser approved Variable Mean Noise individually (1,640 to 1,643 epochs),
then Approve All updated only the remaining pinned Expanding Spots dataset (255
to 258 epochs). Single Spot remained pending. Both pinned sidebar entries stayed
in place; no file export was generated. Cards now show cells, epochs and compact
before/after bars, with affected cells and navigation inside collapsed Details.
Approve All remains visible in the review header while scrolling.

This real run caught a DataJoint lineage mismatch in the new protocol-type count.
The fix restricts by project experiment keys rather than joining unrelated integer
lineages; a real native-MySQL regression reproduces that schema distinction.
The final backend suite passed 617 tests with native integration enabled;
211 frontend tests and the production build passed. The unsuccessful test attempt
remains in demo history; it added no source records and the retry completed with
no warnings.

### Single managed H5 folder and storage totals (2026-09-29)

- Full native backend suite: 628 tests passed; frontend: 211 tests passed and production build succeeded. Datastore size tests also passed (15).
- Closed/reopened the native demo project, then copied a fresh synthetic H5 directly into `raw-uploads`. The watcher automatically imported it after settling: one recording, three cells, nine epochs, zero new protocol types. Three saved-query proposals were created without approval.
- Verified the job's retained path equals the dropped path, exactly one matching managed H5 exists, and `original_removal_safe` is false for this in-place recording. Sidebar pinned protocols displayed pending +3-cell updates.
- Browser confirmed Import H5s and Open H5 folder controls. Data stores showed 268.4 MB H5, 23.4 MB parsed metadata, 291.8 MB combined, with per-recording metadata sizes. These totals exclude MySQL, caches, exports, logs and unregistered files; unavailable sizes are marked partial.

### Automatic completion review (2026-09-29)

Successful import completion now opens the global Review imported data dialog from any workspace page. Existing history on page load does not reopen it. Verified with a fresh synthetic watched-folder import while on Data stores: dialog appeared without clicking, showing +1 recording/+3 cells/+9 epochs and two pinned protocol proposals with Approve All. Proposals remain pending for user inspection. Frontend 211 tests and production build passed.
