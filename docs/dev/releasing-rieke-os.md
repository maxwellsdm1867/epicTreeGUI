# Rieke OS release operations

The updater is a foundation for signed application releases, not `git pull`.
Development checkouts can check the official GitHub release channel but cannot
install into themselves. A missing GitHub release is reported as unavailable.

## Implemented contracts

- `rieke-release.json`, frontend package version and npm lockfile version agree.
- `python/workspace_updates.py` checks the official stable channel, caches checks
  for 15 minutes, and preserves the running app on offline/server failures.
- A managed installation has a stable `manager.py`, installed public signing key,
  independent `preferences/`, and immutable-per-version `releases/<version>/`.
- The signed manifest uses RSA PKCS#1 v1.5 with SHA-256 over the exact bytes of the
  base64-decoded `payload`; the envelope contains `algorithm`, `payload` and
  `signature`. The trusted key is installed out of band, never accepted from the
  release download. The manifest binds version, Git commit, platform, artifact
  URL, byte length, SHA-256 and database compatibility generation.
- Staging verifies signatures/hashes and archive paths before executing setup.
  It builds a separate locked runtime at its final release path, probes startup,
  and publishes a ready receipt. It never opens projects or starts databases.
  A failed stage leaves the active pointer untouched and preserves diagnostics.
- Staging uses a separate lock and can run while the app is open. Activation
  requires exclusive lifetime locks; managed chooser and detached project
  processes hold shared locks. Activation refuses incompatible database
  generations. App updates never perform implicit project migrations.
- Managed launch uses built frontend assets. Source/development launch still
  builds the frontend. Managed launch directly uses its Python service and needs
  no Node/npm, Git or Docker command. The previous version remains available for recovery.
- MySQL 8.4.2 server, client and dump tool are app-private. The Apple Silicon
  dependency closure and micromamba linker are SHA-256-pinned in
  `python/workspace-mysql-runtime.json`. Setup verifies package archives, links
  them offline into `.rieke-runtime/mysql`, repairs macOS ad-hoc signatures after
  prefix relocation and probes all three executables before recording readiness.
  No database, system service, PATH installation or Homebrew package is created.
- Release bundles include the verified native package archives, so native MySQL
  setup is offline at the destination and does not require user-installed MySQL.
  Archives retain upstream license/recipe metadata. Do not strip this metadata
  when distributing the bundled GPL MySQL and third-party dependencies.

The current artifact is a signed application source bundle, built UI and native
MySQL package archives. It is not yet a macOS `.app` or a fully bundled offline
Python runtime. Building/staging the Python and frontend portions still requires
Git, uv, Node/npm, a C++ compiler and access to pinned dependencies. Once prepared,
managed launch needs no frontend build tools, external MySQL or Docker. Packaging
the Python interpreter/dependencies and stable launcher into a signed/notarized
desktop bundle remains a distinct release-engineering step.

## Establish release trust

A maintainer must create an RSA release signing key in their chosen secret
management system and commit only its public PEM as `release-signing-public.pem`.
No private key or generated trust anchor is included by this change. Protect the
`release-signing` GitHub environment and set its `RELEASE_SIGNING_PRIVATE_KEY`
secret. Review ownership and rotation procedures before distributing the key.

Publish the current reviewed application source first. The source and parser
commit must be fetchable by a clean machine. The current dirty development tree
is intentionally rejected by the release packager.

## Candidate pipeline

PR CI runs frontend tests/build, Python workspace tests and coordinated-version
validation. A separate Apple Silicon job prepares the private native runtime,
checks full project readiness and runs real database lifecycle and transfer tests
without requiring a signing key or release tag. The manually dispatched
`workspace-release-candidate.yml` checks out
the requested reviewed version tag, exercises setup and tests on Apple Silicon,
including real native MySQL lifecycle and native project transfer/copy tests,
builds a signed artifact and uploads it as a GitHub Actions artifact. It does not
publish a public GitHub Release.

Before promoting the candidate to a stable GitHub Release, require recorded
passing evidence for real MySQL/DataJoint import/edit/export/restart, complete
workspace transfer to a different path and machine, previous-to-current update
and recovery, active-worker shutdown, and licensed MATLAB handoff regressions.
Mocked/unit-only tests do not satisfy those gates. A missing runner is not a pass.
Only upload the exact signed artifact and `rieke-release-manifest.json` under its
matching `v<version>` GitHub Release tag. Linux is not an advertised artifact yet.

## Managed installation and applying an update

After distributing the trusted public key with a reviewed application, initialize
an empty installation folder:

```sh
python3 python/workspace_updates.py --installation /path/to/RiekeOS init
python3 /path/to/RiekeOS/manager.py --installation /path/to/RiekeOS stage
python3 /path/to/RiekeOS/manager.py --installation /path/to/RiekeOS activate
python3 /path/to/RiekeOS/manager.py --installation /path/to/RiekeOS launch
```

The managed app can stage a signed update while running. Its result includes the
exact apply command. Close all chooser and project-service processes, then run:

```sh
python3 /path/to/RiekeOS/manager.py --installation /path/to/RiekeOS activate-and-launch
```

This waits at most five minutes for processes to release their locks, switches
the active release atomically, and launches it. It never force-kills workers.
Closing a browser tab alone does not stop a project service.

Fully automatic **Restart and update** still needs a coordinated request drain,
unsaved-draft preservation and shutdown acknowledgement from every project
service. The UI must not present this as implemented. Incompatible database
updates likewise stay disabled until verified backup/migration/recovery exists.
Key rotation and automatic recovery from post-activation startup failure are
also not implemented; the previous release is retained, not silently restored.
