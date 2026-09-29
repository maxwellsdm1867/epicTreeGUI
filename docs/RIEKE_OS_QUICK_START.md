# Rieke OS quick start

This guide takes you from a complete application download to your first project.
Rieke OS is a local browser application, not a hosted account or desktop installer.
New projects use a private MySQL runtime installed with the app. You do not need
Docker or a separately installed database server. A signed macOS `.app` with a
bundled Python interpreter has not yet been produced.

## 1. Get the complete source

**Availability:** the public `master` branch currently provides the MATLAB
application. Use the **`codex/rieke-native-e2e` review branch** for the complete
Rieke OS development source. It is not a signed installer or stable app release.
A valid checkout contains `rieke.py`,
`python/workspace_bootstrap.py`, `python/workspace-runtime.lock`,
`python/workspace-source.json`, `python/workspace-mysql-runtime.json`, and
`workspace-app/package-lock.json` together
with the rest of the application.

Open the [review branch](https://github.com/maxwellsdm1867/epicTreeGUI/tree/codex/rieke-native-e2e)
and use **Code → Download ZIP** (extract the whole archive), or clone explicitly:

```sh
git clone --branch codex/rieke-native-e2e https://github.com/maxwellsdm1867/epicTreeGUI.git
cd epicTreeGUI
```

Do not download individual Python files to assemble an installation.

Keep the application in a permanent folder, separate from the workspace that will
hold your projects. The package contains code and dependency specifications;
setup downloads dependencies. Bring your own Symphony H5 recordings. No lab
database or recordings are bundled.

## 2. Install prerequisites

| Requirement | Installation / purpose |
| --- | --- |
| Apple Silicon macOS | The bundled native MySQL runtime is validated here. Linux and Windows do not yet have a supported native runtime package. |
| Git | [Git downloads](https://git-scm.com/downloads); setup fetches RetinAnalysis and its submodule even when the app came from a ZIP. |
| Python 3.10+ | [Python downloads](https://www.python.org/downloads/); runs the bootstrap. Setup obtains its own pinned Python 3.11.13. |
| uv | [uv installation](https://docs.astral.sh/uv/getting-started/installation/); must be on PATH. |
| Node and npm | [Node downloads](https://nodejs.org/en/download); Node 20.19+ on 20.x, or 22.12+. |
| C++ compiler | On macOS run `xcode-select --install`; the parser's native extensions are compiled during source setup. |

Allow internet access and several GB of free disk for scientific dependencies,
including PyTorch, plus your project data. MATLAB is needed only for the exported
MATLAB browser. Setup installs a verified, private MySQL 8.4.2 server and client
inside the app's runtime directory. It does not install a system database service.

If you want an assistant to walk through setup, use the
[LLM setup instructions](LLM_SETUP.md).

## 3. Install once

In Terminal, change into the complete application checkout (the folder containing
`rieke.py`), then run each command in order. Stop and address any error before
continuing:

```sh
python3 rieke.py setup
python3 rieke.py doctor
python3 rieke.py init "$HOME/Documents/RiekeLabWorkspace"
```

`init` creates a workspace marker and a small launch script. It downloads nothing,
starts no services, and leaves existing files in that folder intact. It refuses
to overwrite an existing marker or launch script. A workspace holds multiple
projects; initialize their parent folder, not an individual project's folder.
Workspace storage must be separate from the application checkout.

## 4. Launch and create a project

```sh
cd "$HOME/Documents/RiekeLabWorkspace"
python3 rieke-workspace.py
```

Keep that terminal open and visit <http://127.0.0.1:8766>. Choose **New project**,
give it a name, then open it. Opening initializes and starts that project's
private database using the app's bundled server. Use **Add data store** to connect
recordings. Creating an empty project does not require a recording.

The launch script works from any current directory and handles spaces in paths.
You can also invoke the installed app from a workspace or any of its subfolders:

```sh
python3 /path/to/epicTreeGUI/rieke.py launch
```

For explicit selection or a different chooser port:

```sh
python3 /path/to/epicTreeGUI/rieke.py launch --workspace "$HOME/Documents/RiekeLabWorkspace" --port 8870
```

Selection order is `--workspace`, the nearest workspace marker above the current
directory, `RECORDING_WORKSPACE_ROOT`, the last root selected in the launcher, the root saved during setup, then the legacy
`RECORDING_PROJECT_DIR` parent or `~/Documents/RecordingWorkspace`. Explicit
`--workspace` requires an initialized folder. Existing unmarked installations can
continue using the environment variable or the setup configuration.

Ctrl-C stops the chooser. Opened project servers and private databases may keep
running and are reused on the next visit. This command is not an all-services
shutdown. Use **Project folder → Close project** for a clean database shutdown
before moving a native project's folder. Development launch checks dependencies
and rebuilds the browser app. Managed release launch uses its prebuilt frontend
and Python service without Node/npm or Git commands. The current source installer
is not an offline standalone desktop installer.

## 5. Reopen your workspace

Run:

```sh
cd "$HOME/Documents/RiekeLabWorkspace"
python3 rieke-workspace.py
```

Open <http://127.0.0.1:8766> and select your project. You do not need to rerun
`setup` or `init` every time. Keep the application checkout at its original path.

## Troubleshooting

| Symptom | Next step |
| --- | --- |
| `rieke.py` is missing | You have an incomplete or MATLAB-only checkout. Obtain the complete Rieke OS source; installing Python packages will not add the launcher. |
| A prerequisite command is missing | Install it, reopen Terminal so PATH updates take effect, then rerun setup. |
| Setup fails compiling vision-utils | Verify the C++ compiler is installed; keep the exact error and rerun setup after fixing the cause. |
| Doctor says `native_mysql` is not ready | Check the reported runtime error and run setup in the complete application checkout. `ready` covers the app; `project_open_ready` also checks its private MySQL binaries. Do not install a system MySQL service to bypass the check. |
| An existing project requests Docker | It is a legacy Docker-backed project. Keep its original configuration and arrange explicit migration; new native projects do not need Docker. |
| Port 8766 is occupied | Launch with `--port 8870` as shown above and open the matching URL. |
| `init` says the workspace already exists | Use its existing `rieke-workspace.py` launcher; do not delete project files to initialize again. |
| Traces cannot be read | Restore access to the project-managed H5 copy, or to the original drive for older linked imports. Exports contain source references, not bundled waveforms. |

For a diagnostic report, run `python3 rieke.py doctor --json` from the application
checkout. Review paths before sharing the report. Project diagnostics live under
`<workspace>/<project>/logs/`; do not share database credentials or raw recordings.

## Where files live

```text
Application checkout/
  rieke.py                    setup, doctor, init, launch
  .rieke-runtime/             installed Python, parser, private MySQL, configuration
  workspace-app/dist/        built browser application

RiekeLabWorkspace/
  .rieke-workspace.json       workspace identity/version marker
  rieke-workspace.py          entry point linked to the application checkout
  .rieke-os.json              last-opened project preference (created on use)
  project-name-<id>/
    project.json             project identity
    catalog.json             database reference
    storage.json             managed directory contract
    database/                service configuration and persistent MySQL files
    protocols/               saved protocol queries
    imports/                 parsed metadata and source references
    raw-uploads/             verified project-managed H5 recordings
    query-snapshots/          frozen query baselines
    exports/                 exported data/reference packages
    logs/                    import, application, error and storage logs
    cache/                   rebuildable derived indexes
    backups/                 reserved location for verified backups
```

Choose **Data stores → Import H5s** to select or drop one or more recordings. A batch imports one file at a time;
keep the app tab open until it finishes. The review opens after the batch. Uploads keep
one checksum-verified copy in `raw-uploads`; lazy traces read that project copy.
Alternatively, choose **Open H5 folder** and drop H5 files directly there. While
the project is open, files are imported after their size and modification time
settle for five seconds. Folder imports use that same file without another copy. After the app confirms a
successful import and verified copy, you may remove the original from Downloads.
Do not move or delete the managed copy inside the project. Older imports may
still link to external recordings, so keep those external files available. The
`backups` folder does not itself create backups. A running MySQL directory is not a valid
file-copy backup.

For a native project, choose **Project folder → Close project**, wait for the
clean-close confirmation, and copy or move the entire project folder. Open it
with **Open project** in an app using the same bundled MySQL runtime. The app
verifies source identities and updates project-contained file locators. It keeps
scientific UUIDs and historical audit/export evidence. External linked H5 files
are not automatically included: restore their access before opening, or use
**Prepare to share** to create a logical transfer package containing recordings.
This cold-folder workflow does not convert legacy Docker projects or guarantee
compatibility with a different MySQL version. Copied projects subsequently evolve
independently; opening them does not synchronize edits.
See [storage and migration details](../workspace-app/README.md#what-travels-with-the-repository).

If the application checkout moves, update `application` in `rieke-workspace.py`.
Do not move project folders to repair an application path. For dependency errors,
run `python3 /path/to/epicTreeGUI/rieke.py doctor`; rerun `setup` to repair the
managed runtime. If the chooser port is occupied, choose another with `--port`.

## Workspace and author selection in the app

The launcher displays the full **Workspace root**. Choose **Choose folder** and
enter an absolute path, then **Use this workspace**. A new root receives the
workspace marker and launch script. A valid existing root is reused and its
immediate project folders are discovered without replacing their manifests or
files. Select the parent workspace, not the folder containing an individual
`project.json`. New project folders remain separate children of that root.

The last root chosen in the UI is recorded locally in
`.rieke-runtime/workspace-selection.json` for a development checkout, or the stable
installation's `preferences/workspace-selection.json` for managed releases. It is used on subsequent launches
unless an explicit `--workspace`, discovered workspace marker, or environment
root takes precedence. Root selection does not relocate an existing project,
move its database, or copy its recordings.

After opening a project, the author picker offers existing profiles or creation
of a named profile. The OS username is a suggestion, not automatic consent to
attribute tags to that name. Choose an author before adding or importing tags;
browsing and exporting existing tags do not require that choice. The selected
profile UUID is remembered per project in this browser, while the profiles,
authored tags and audit history live in the project database. The profile
button in the bottom-left rail changes the active author. A different browser
must choose an author again; it cannot silently inherit another person's choice.
