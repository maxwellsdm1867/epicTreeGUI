# Sharing projects and receiving updates

## Automatic update notifications

Rieke OS checks the official GitHub release channel when you open the app, every
15 minutes while the page is visible, and when you return after that interval.
No button press is required. A newer release produces an **Update available**
notice in the app and an update indicator in the header. Dismissing the notice
leaves the header indicator available.

The header distinguishes **Up to date**, **No release published**, and **Update
check unavailable**. An offline check does not count as up to date. Open the
indicator for installed version, last check, release notes, and an optional manual
retry. Manual retries bypass the automatic check cache.

Managed installations with the official trusted signing key can download and
verify a release from this panel. The download prepares a separate installation;
it does not replace the running app or modify projects. After staging, follow the
displayed apply command. Activation waits for project services to close and
refuses incompatible database versions. Automatic shutdown/restart from the
browser is not implemented. Development checkouts can check for releases but
cannot install them in place.

No signed release or trusted production key has been published by this change.
Release workflows and signing setup must be configured before downloads become
available to users.

## Open, move, or share a project folder

The main project catalog and user state remain MySQL/DataJoint. New projects use
an app-private MySQL 8.4 runtime; no Docker or system MySQL installation is needed.
SQLite continues to provide exports, rebuildable search indexes and daily state
snapshots. Raw recordings remain H5 files.

For ordinary movement between installations using the supported bundled runtime:

1. In **Project folder**, choose **Close project**. The app refuses while an import
   is active, drains requests, and closes its database cleanly.
2. Copy the entire project folder to the recipient or new location.
3. In the recipient's app, choose **Open project** and
   select that folder. No archive or prepared package is required.

The folder carries `project.json`, `catalog.json`, `storage.json`, database storage
and ownership files, retained recordings, imports, saved queries, and exports.
Opening recreates local runtime addresses, verifies project identity and recording
checksums, and rebases current file locations. Scientific UUIDs are preserved.
Closing a browser tab alone does not close a project database. Copying an open
MySQL data directory is unsupported; relocated folders marked unclean are refused.

New recording imports are copied into `raw-uploads` and verified by checksum
before parsing, so lazy traces use the project copy. After a successful import
confirms that verified copy, the original outside the project can be removed;
keep the managed copy in place. Older projects may still reference external recordings;
opening a moved folder reports missing dependencies rather than silently dropping
its data. Copies develop independently; this is not a synchronization or merge
mechanism. The direct-folder path is validated on Apple Silicon macOS with the
bundled MySQL version; it is not a promise of arbitrary MySQL-version or platform
interchange.

## Optional verified transfer and legacy projects

**Prepare to share** remains available when you want a separately verified copy
with a logical database backup and all registered recordings included. It tests a
restore before reporting success. **Open prepared project** restores that optional
transfer to a new local folder with fresh native database credentials. Existing
projects are never overwritten.

Legacy Docker projects keep their original configuration and data. They are not
silently converted. Preparing a logical transfer from such a project still needs
its original database available; restoring that transfer creates a native project
that no longer needs Docker. Native-to-native transfers use the bundled server and
clients throughout.

The optional logical transfer currently requires an initialized project database.
Runtime logs, caches and existing backup directories are excluded from it.
Historical export files retain their original bytes; external readers of old
exports may need embedded recording paths relinked. Interrupted logical restores
do not resume automatically; inspect the reported destination before retrying.
Plain-folder locator rebasing keeps a recovery journal and retries on the next open.

Restart an already-running development app to load these local-service changes,
then refresh its browser. A standalone signed desktop installer remains separate
release work; this implementation makes project storage independent of Docker.
