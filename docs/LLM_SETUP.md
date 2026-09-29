# Set up Rieke OS with an AI assistant

Use this prompt with a coding assistant that can read your downloaded application
folder and run commands on your computer. A chat-only assistant can explain the
steps, but cannot verify your local installation. No LLM account or API key is
required by Rieke OS itself.

Read the [quick start](RIEKE_OS_QUICK_START.md) first. The complete Rieke OS
development source is on the `codex/rieke-native-e2e` review branch; `master`
still contains the legacy MATLAB application. Use this exact source command:

```sh
git clone --branch codex/rieke-native-e2e https://github.com/maxwellsdm1867/epicTreeGUI.git
```

There is no signed standalone installer or stable release yet. An assistant
must not substitute a guessed package, branch or download URL.

## Copyable setup prompt

```text
Help me install and launch Rieke OS from this application folder:
<absolute path to the complete application checkout>

Store my projects in this separate workspace folder:
<absolute path to my workspace, for example ~/Documents/RiekeLabWorkspace>

Read README.md, docs/RIEKE_OS_QUICK_START.md, and workspace-app/README.md
before running commands. Confirm this checkout includes rieke.py,
python/workspace_bootstrap.py, python/workspace-runtime.lock,
python/workspace-source.json, python/workspace-mysql-runtime.json, and
workspace-app/package-lock.json. If the
package is incomplete, stop and explain which files are missing. Do not
invent a download URL, pip package, release, branch, or replacement launcher.

Check my operating system, Git, Python, uv, Node/npm and C++ compiler.
Use the documented requirements. Explain missing prerequisites and help me
install them using their official instructions. Do not claim readiness from
version checks alone. The bundled native MySQL runtime currently supports Apple
Silicon macOS. Do not install Docker, Homebrew MySQL or a system database service
for a new project. A signed standalone .app has not yet been built.

Run python3 rieke.py setup from the application root. This downloads the
pinned runtime/parser and private MySQL server/client, and builds the browser
app; allow time for it to finish.
Use the clone-local environment, not my existing research environment. Do not
upgrade pins, reset a modified parser checkout, or bypass a failed check.

Run python3 rieke.py doctor --json and distinguish app readiness from
project_open_ready, which includes the private native MySQL executable checks.
The doctor does not start a database. If any step fails, report the actual error,
fix its cause, and repeat that step. Existing Docker-backed projects retain their
configuration and require explicit migration; do not silently rewrite them.

Inspect the requested workspace before initializing it. If it already has a
valid workspace marker and launcher, reuse them. Otherwise run
python3 rieke.py init "<absolute workspace path>". Keep it outside the app
checkout. Never delete or overwrite existing projects to make setup work.

Start python3 rieke-workspace.py from the workspace folder. Show me the
local URL (default http://127.0.0.1:8766) and help me confirm the chooser
loads. Explain New project, opening its database, Add data store, and the
explicit tag-author choice. Ask me which H5 file to import before importing
any recordings. Do not seed a new empty project with another project's database
or credentials. Preserve supplied existing projects and open them as projects.

At the end, tell me what actually succeeded, what is still unverified, the
application path, workspace path, local URL, and exact commands to reopen.
Explain that Ctrl-C stops the chooser but may leave project services running.
For moving a native project, use Project folder -> Close project and wait for
the clean-close confirmation before copying its entire folder. Open the copy in
the recipient's app using the same bundled runtime. Included paths are verified
and updated on open; linked recordings must remain accessible. Prepare to share
is an optional logical transfer that can include recordings. A browser tab close
is not a database shutdown, and copied projects do not synchronize later edits.
Do not upload recordings, credentials, or database contents to an AI service.
```

Replace the angle-bracket placeholders with your paths before using the prompt.
Setup needs internet access; project data stays on your computer unless you
explicitly share it. Your assistant's own access and data handling are separate
from Rieke OS.

## What a successful setup report should say

- The complete source was found, setup completed, and doctor passed the required
  dependency checks.
- Whether the bundled native MySQL checks passed and a project was actually opened.
- Whether the chooser was observed in the browser. A running process alone is
  not evidence that the page works.
- Which workspace is in use and how to reopen it.
- Whether any recording was imported or a trace inspected; these should remain
  explicitly unverified if you have not supplied a recording.

## For assistants working with exports

A MATLAB bundle or Wheeler SQLite export is a snapshot with H5 source references.
It is not a copy of all waveform samples. Preserve epoch UUIDs, frozen membership,
source checksums, units and sample rates. Do not infer experimental conditions
from filenames or replace missing metadata with guessed values. Keep derived
analysis separate from frozen exported data. See the
[export and runtime reference](../workspace-app/README.md) for the checked reader
and MATLAB handoff details.
