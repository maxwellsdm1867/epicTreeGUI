# Cell and epoch tags

Tags are project annotations stored in DataJoint. Each annotation has an exact target UUID, a target kind (`cell` or `epoch`), a local author profile, and a revision. Changes are recorded in project activity. Profiles identify the claimed author; they are not authenticated accounts.

In the epoch browser, **Tags** lets you tag the focused epoch, its entire cell, or explicitly selected epochs. The whole-cell action applies to every epoch with that cell UUID, including epochs in other protocols and later imports. It does not use the visible cell label, date, tree position, or current predicate membership. Direct epoch tags and inherited cell tags are shown separately. Choose the author when opening a project or using the profile button at the bottom of the project rail. Tagging and tag import remain disabled until an author is explicitly selected; the OS username is only a suggestion.

Use **Cell tags**, **Epoch tags**, or **Effective tags** in Search predicate. Effective tags combine direct epoch and inherited cell annotations. Acquisition keywords and the older protocol-specific dataset tags remain separate fields. Tag chips can open an exact tag predicate.

## MATLAB and file exchange

In native EpicTreeGUI, use **Tags → Load tag JSON**, **Tag selected epochs** or **Tag cells of selected epochs**, then **Save tag JSON**. Unsaved tag edits prompt on close. The menu checks imported target UUIDs against the loaded tree before accepting them.

Use **Export tags** in the web app to download a portable tag JSON. It records the exact cell and epoch UUID registry and each tag's author. MATLAB uses the same identities:

```matlab
annotations = readWorkspaceTags('tags.json');
% Copy these UUIDs from the exported document; never substitute a row number.
annotations = workspaceTag(annotations, 'epoch', epochUuid, ...
    'reviewed-response', profileUuid, authorName);
writeWorkspaceTags(annotations, 'tags-reviewed.json');
```

Back in the web app, choose **Import tags**, select the JSON, review its additions, and import. Import is additive: matching existing authored tags are unchanged; missing tags in the input do not delete saved tags. Removing a tag is a separate explicit edit by its author. Reordering a MATLAB tree or exporting a subset does not change the identities.

The import preview validates target kind and UUID against the registered project. Unknown targets, duplicate targets, conflicting author identities, and stale previews are rejected. A cell label such as `Cell1` never identifies an import target. Tags from another project are matched only to the same exact registered acquisition UUIDs and are called out in the preview. Raw H5 files are not rewritten.

Samarjit hierarchical tag JSON is also supported for cell and epoch annotations. Author names in this legacy format are retained as imported claims. Tagged hierarchy levels that cannot be represented are rejected rather than silently discarded.

## Tags and inclusion masks

A MATLAB `.ugm` file is an inclusion mask, not a tag file. Use **Refresh metadata** to check for updated `selection.ugm` files in registered MATLAB export folders (`exports/<export_uuid>/matlab/selection.ugm` or `exports/<export_uuid>/selection.ugm`). Updated masks appear under **MATLAB selection masks** in the refresh status panel, with a changed-decision count and **Apply updated mask** action. Refresh only detects changes; applying uses the same exact UUID/export and current-revision checks as manual import. Original export masks and previously applied file versions are not offered again. Files elsewhere can still be imported through **More → Import mask file…** in protocol inspection. Inclusion decisions do not implicitly add or remove authored tags. Existing protocol-scoped curation tags stay in their original dataset scope and are not silently converted to shared annotations.

Wheeler SQLite and EpicTree MATLAB dataset exports include a frozen annotation snapshot. Later tag edits do not rewrite an earlier export.

## Automatic tags from Wheeler and other services

Use **Export log → Local export folder → Copy folder path** to link an external service to this project's single `exports/` directory. All export formats share this root, with one UUID subfolder per export and a root README explaining how results return. There is no need to point the service at acquisition data folders to return tags or selection masks.

SQLite exports now have a writable return area beside the frozen database:

```text
exports/<export_uuid>/
  recordings.sqlite
  annotation-return.json
  annotations/incoming/
  annotations/receipts/
```

Open the export folder shown under **External tags** in the app header. Wheeler reads `recordings.sqlite`, obtains exact epoch/cell UUIDs, and writes additions into `annotations/incoming`. It must not edit the SQLite snapshot. The manifest lists allowed targets, source hashes, and an example message. Existing registered SQLite exports gain the return area automatically when checked.

The included helper submits tags without needing a running app or database connection:

```sh
python3 python/workspace_external_tags.py /path/to/project/exports/EXPORT_UUID \
  --author Wheeler --target-kind epoch --uuid EPOCH_UUID \
  --tag publication:paper-2026-01
```

Repeat `--uuid` and `--tag` for multiple targets/tags. `--profile-uuid` can supply an existing stable author identity; otherwise the helper derives one deterministically from the exact author name. Author names are local attribution claims, not authenticated accounts. Use `--target-kind cell` only when all epochs of that cell, including future ones, should inherit the tag.

The receiving app scans on page open/reload, about every three seconds while visible, and when returning to the window. **External tags** shows only the last check and latest successful import. Its refresh icon checks immediately; an error appears only when attention is needed. Tags appear in the normal annotation UI and tag searches. No dataset reimport or manual tag preview is needed. Closed pages receive queued messages on reopen; no always-running daemon is installed.

Each message needs a fresh `message_uuid` and a filename matching it. Publish complete files atomically; the helper does this for you. Repeated delivery of the same message is safe, and saved receipts prevent an old message from restoring a tag removed later. Submissions only add tags; missing tags or missing folders never remove anything. Receipts and additions share one database transaction. Unsupported/foreign identities are displayed as errors without guessing a match.

This scans the original registered project export folders. If Wheeler works on a copy elsewhere, deliver or synchronize its completed JSON messages into the original export's `annotations/incoming` folder. Downloading a SQLite file alone does not create a communication channel back to the app. External actors can query current tags through the existing annotation API; an old SQLite export retains its historical snapshot.
