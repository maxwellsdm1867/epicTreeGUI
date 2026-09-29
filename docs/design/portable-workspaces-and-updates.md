# Portable workspaces and application updates

Status: original design notes, superseded in part by the Docker-free native MySQL
implementation on 2026-09-29. See [current behavior](../WORKSPACE_SHARING_AND_UPDATES.md).
New projects retain MySQL/DataJoint with a bundled private runtime. A cleanly closed
native project folder can be moved and opened directly; logical transfer packaging
is optional. SQLite remains an export/index/snapshot format. The Docker findings
and implementation sequence below describe the initial inspected state, not the
new default. A signed standalone desktop installer remains unfinished release work.

## User contract

Rieke OS is installed independently of research data. A user opens a workspace
folder and sees its projects, recordings, annotations, saved queries, and exports.
Updating the application preserves those contents. A prepared workspace can be
given to another person, who opens it with their own installation.

The app is the interface and runtime for this data. The folder is the durable
unit of ownership. Opening loads metadata and indexes; waveforms remain lazy.

## What exists

- `python/workspace_installation.py` creates `.rieke-workspace.json` and supports
  selecting an existing root. Its generated launcher embeds an absolute code path.
- `python/workspace_projects.py` discovers immediate child projects, with
  `project.json`, `catalog.json`, and stable project UUIDs. It requires storage to
  be separate from application code.
- Explicit **Open project folder** already exists; its cross-root route has unit
  tests with mocked project startup. That verifies folder selection, not transfer
  and restoration on a second machine.
- `python/workspace_storage.py` defines database, protocols, imports, raw uploads,
  query snapshots, exports, logs, cache, and backups directories.
- `python/workspace_project_database.py` provisions project-owned Docker MySQL.
  Ownership checks include the absolute project path and bind mount. Existing
  database files without their original container are rejected. Copying a folder
  to another computer therefore does not yet make it openable.
- External H5 references are supported; a copied folder may omit its recordings.
- `python/workspace_state_snapshot.py` captures selected current application
  state. It is not a complete database or recording backup.
- Runtime/parser pins and frontend/Python/MATLAB tests exist. The frontend package
  says `0.1.0`; that is not a published, coordinated application release.
- GitHub API inspection found zero Actions workflows, tags, or releases in
  [the repository](https://github.com/maxwellsdm1867/epicTreeGUI). The default branch
  is `master`; its root lacks `rieke.py` and `workspace-app`. Substantial Rieke OS
  work exists locally, including uncommitted changes.

## Storage and identity

Keep the existing workspace/project hierarchy. Treat the project manifest as the
authority for project identity and format; store that same UUID and schema version
in its database and validate their agreement on open. A database mismatch is an
error, not permission to create an empty replacement.

Separate portable state from machine state:

| Portable project state | Local installation/runtime state |
| --- | --- |
| Identity, format and schema versions | Absolute mounted folder path |
| Recordings or declared recording dependencies | Credentials and container IDs |
| Database contents and scientific provenance | Ports, PIDs and locks |
| Tags, authors, queries, masks and layouts | Installed app versions |
| Immutable exports and their recipes | Recent folders and active author choice |

Store a local registry mapping project UUID plus local instance ID to its folder.
The database does not own the machine's folder path. Keep local preferences outside
versioned app releases so updates preserve them. Resolve included file references
relative to the project root. External sources use stable identity/checksum plus
a local path mapping. Preserve historical audit paths as evidence; do not treat
them as the current locator.

A copied project keeps its scientific UUIDs. Local instance IDs distinguish copies
and avoid container collisions. Opening copies does not merge their later edits;
collaborative synchronization would be a separate feature.

## Open and share

User-facing actions: **Open workspace**, **Open project**, **Prepare to share**.

1. Inspect manifests and supported versions before making changes.
2. Resolve project-relative files and check declared external dependencies.
3. Attach an existing local runtime or restore a verified portable database into
   a newly provisioned local runtime with fresh credentials.
4. Check database/project identity, then load the catalog and saved state.
5. If recordings are missing, show what remains available and provide **Locate
   recordings**. Verify matches by identity/checksum, not filename alone.

Initially retain DataJoint/MySQL. Existing SQLite exports are subsets for other
tools; they are not substitutes for the complete project database. A future
SQLite-backed project would require a separate compatibility investigation.

**Prepare to share** writes a separate folder containing portable manifests,
project files, and a consistent logical database backup with checksums. It pauses
all project writers across database and file capture, including import workers and
external-tag ingestion, and validates a restore before reporting success. Exclude
runtime secrets, container bindings and disposable caches. Do not copy live MySQL
storage as the transfer format.

Distinguish a live working folder from a prepared transfer folder. Backup only
application databases, excluding MySQL system accounts and donor credentials.
Write a checksum inventory and completion marker last; reject incomplete packages.
Restore into staging with a recovery journal and publish the local instance only
after verification. Hash copied recordings against registered source hashes before
publication: stopping app writers cannot prevent external recording modifications.

Offer two explicit transfer choices:

- **Complete workspace:** include recordings and verify every dependency is inside
  the package. This is the “give someone the folder and open it” promise.
- **Workspace with linked recordings:** include a dependency inventory and disclose
  that the recipient needs access to those recordings.

Metadata-only browsing with missing recordings is also proposed work: current
metadata refresh checks raw-file signatures and can fail when those files are
absent. It must explicitly support unavailable traces before advertising that mode.

The recipient selects the folder from their installed app; they do not run a
sender-specific launch script. Opening an already-restored folder reuses its local
database. Import never silently overwrites an existing divergent project instance.
Supporting multiple copies requires changing discovery and opening rules as well
as container naming: current discovery omits ambiguous duplicate UUIDs and opening
a second copy of the current project is rejected. Source resolution must cover
parsed metadata references as well as raw H5 paths.

## In-app update flow

**Settings → Updates → Check for updates → Download → Restart and update.**
Show installed/available versions, release notes and any required project migration.
An update applies to the frontend, Python service, parser and dependency locks as
one tested release. It does not fetch arbitrary changes from the development branch.

A stable launcher outside release directories manages versioned installations:

1. Fetch a release manifest from the official release channel; validate its signed
   metadata and artifact hashes against a trusted updater key.
2. Stage the release separately, checking platform support, space and dependencies.
3. Coordinate all app windows, project services and active jobs. Stop new writes
   and finish or safely cancel jobs before switching. Preserve unsaved UI drafts.
4. Run a staged startup/compatibility check without changing user projects.
5. Atomically switch the active release pointer and restart through the launcher.
6. Reopen the selected workspace. Keep the prior release for recovery.

Today project services detach from the launcher and can be reused based on project
identity and health alone. Add release identity to the service handshake and track
all processes owned by the installation. Restarting only the chooser must never
connect the new frontend to an incompatible old backend. Ship the built frontend;
the current `start.mjs` rebuilds it on every launch, which is unsuitable for an
immutable release. Build/package parser dependencies instead of depending on a
mutable editable development checkout.

Offline checks, failed downloads and failed staged checks leave the active version
usable. The local update endpoint needs authenticated local authorization and
origin protection because it can install executable software.

Version application releases independently from workspace format, database schema
and export formats. Each release declares supported format/schema ranges. Before
any project migration, create and validate a complete recovery backup; migrate
only that project under an exclusive lock and journal interruption recovery.
Never let an older app write a newer unsupported schema. Rolling back code alone
is safe only when schemas remain compatible; otherwise recovery must pair the old
app with its pre-migration project snapshot and disclose any later writes at risk.
App installation and project migration are distinct transactions.

## Release pipeline and regression gates

Publish the reviewed Rieke OS source first, then establish GitHub Actions:

1. Pull requests: frontend tests/build, Python tests, and workspace-contract checks.
2. Integration: disposable real MySQL/DataJoint, import fixture recordings, edit
   tags/queries, export, restart, and confirm stable identities and state.
3. Portability: prepare a complete workspace, open under a different absolute path
   with no original container or credentials, and compare metadata, tags, queries,
   exports and waveform samples. Exercise missing/relocated linked sources and
   duplicate project copies.
4. Upgrades: run supported prior-version fixtures through migration; test future
   schema rejection, failed/interrupted migration, backup restore, active jobs,
   failed downloads, corrupted artifacts and compatible app rollback.
   Include detached services and rejection of mixed frontend/backend releases.
5. MATLAB: run supported handoff/tag/mask regressions on an appropriately licensed
   runner. A missing runner must not count as a passed compatibility check.
6. Release tag: build immutable artifacts from the tested commit, including pinned
   dependencies and version metadata. Smoke-test clean install, update and reopen
   on each advertised platform. Sign artifacts/manifest and publish a GitHub
   Release only after required gates pass.

Start with platforms actually validated. Current documentation describes exercised
Apple Silicon macOS; Linux needs equivalent validation before that promise.

## Implementation order

1. Define portable manifest, local instance registry and version compatibility
   contract; add fresh-path database restore and source relocation tests.
2. Implement **Prepare to share** and recipient **Open workspace/project** with
   real database restore verification. Start with one complete project including
   recordings and reuse the existing open-folder UI; linked-recording recovery and
   whole-workspace batch packaging can follow. This establishes the data boundary.
3. Publish the source and add CI, a coordinated app version and reproducible release
   artifacts. Verify one clean installation from those artifacts.
4. Implement the stable launcher and in-app updater; exercise one supported
   old-to-new update with an existing workspace and recovery test.

Source review/publication and CI setup can proceed in parallel with portability.
Pin the release's MySQL image by digest as well as its application dependencies.
Existing mocked startup/setup tests and bootstrap receipts do not establish the
real-data transfer, clean-install or upgrade gates above.

Success means a second machine can open a prepared folder and reproduce its saved
research state, and an app update can reopen that workspace without losing data.
