"""Complete, offline project transfer using logical MySQL backups.

A prepared package is immutable interchange, not a live project. Restore always
creates a new folder/runtime; it never adopts or overwrites an existing database.
Run with the managed Python environment. Close project sessions before preparing.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import subprocess
import tempfile
import uuid

FORMAT = 'rieke-project-transfer'
MANIFEST = 'transfer.json'
PENDING = '.portable-restore.pending'
DIRECTORIES = ('imports', 'protocols', 'query-snapshots', 'exports', 'raw-uploads')
DATABASES = ('schema', 'recording_workspace')


def _json(path):
    with Path(path).open(encoding='utf-8') as handle:
        return json.load(handle)


def _write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, sort_keys=True, allow_nan=False)
        handle.write('\n')


def _hash(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def _inside(root, relative):
    if not isinstance(relative, str) or not relative or '\\' in relative:
        raise ValueError('Transfer file reference is invalid')
    value = PurePosixPath(relative)
    if value.is_absolute() or '..' in value.parts or str(value) != relative:
        raise ValueError('Transfer file reference must be a normalized relative path')
    path = root
    for part in value.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Transfer files cannot be symbolic links')
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Transfer file reference leaves the package')
    return path


def _destination(value, source):
    path = Path(value).expanduser()
    if not path.is_absolute() or path.is_symlink():
        raise ValueError('Choose an absolute, new destination folder')
    path = path.resolve()
    if path.exists():
        raise ValueError('Destination already exists; nothing was overwritten')
    if path.is_relative_to(source) or source.is_relative_to(path):
        raise ValueError('Transfer destination must be separate from the source folder')
    if not path.parent.is_dir():
        raise ValueError('Destination parent folder must already exist')
    return path


def _files(root, *, skip_marker=True):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('Transfer files cannot be symbolic links')
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError('Transfer contains a nonregular file')
        relative = path.relative_to(root).as_posix()
        if skip_marker and relative == MANIFEST:
            continue
        result[relative] = {'sha256': _hash(path), 'size': path.stat().st_size}
    return result


@contextmanager
def _offline(root):
    path = root / '.app-state-session.lock'
    if path.is_symlink():
        raise ValueError('Project session lock cannot be a symbolic link')
    with path.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Close all project sessions and stop import tools before preparing a transfer; use the launcher to prepare it offline') from None
        yield


def _connection(project_dir):
    """Connect to the project's declared runtime; never infer a donor's backend."""
    import pymysql
    catalog = _json(Path(project_dir) / 'catalog.json')
    provider = catalog['connection']['credential_provider']
    if provider['kind'] == 'native-project':
        from workspace_native_mysql import connection_parameters
        return pymysql.connect(**connection_parameters(project_dir), autocommit=True,
                               connect_timeout=10, read_timeout=600, write_timeout=600)
    if provider['kind'] != 'docker-container-env':
        raise ValueError('Project transfer requires an explicitly configured local MySQL runtime')
    container = provider['container']
    from workspace_project_database import _run
    result = _run(['inspect', container])
    if result.returncode:
        raise ValueError('Transfer database is unavailable')
    info = json.loads(result.stdout)[0]
    bindings = info.get('NetworkSettings', {}).get('Ports', {}).get('3306/tcp') or []
    if len(bindings) != 1 or bindings[0].get('HostIp') != '127.0.0.1':
        raise ValueError('Transfer requires a private localhost database')
    environment = dict(item.split('=', 1) for item in info['Config']['Env'] if '=' in item)
    return pymysql.connect(host='127.0.0.1', port=int(bindings[0]['HostPort']), user='root',
        password=environment['MYSQL_ROOT_PASSWORD'], autocommit=True,
        connect_timeout=10, read_timeout=600, write_timeout=600)


def _sources(connection, identity):
    with connection.cursor() as cursor:
        cursor.execute('SELECT project_uuid FROM recording_workspace.project')
        identities = {row[0] for row in cursor.fetchall()}
        if identities != {identity}:
            raise ValueError('Database must contain exactly the declared project identity')
        cursor.execute('SELECT source_sha256, project_uuid, manifest FROM recording_workspace.source')
        sources = []
        for sha, project_uuid, manifest in cursor.fetchall():
            manifest = json.loads(manifest) if isinstance(manifest, (str, bytes)) else manifest
            if project_uuid != identity or manifest.get('source_sha256') != sha or not re.fullmatch(r'[0-9a-f]{64}', sha):
                raise ValueError('Database source identity disagrees with project')
            sources.append({'source_sha256': sha, 'manifest': manifest})
        return sorted(sources, key=lambda source: source['source_sha256'])


def _dump(project_dir, path):
    provider = _json(Path(project_dir) / 'catalog.json')['connection']['credential_provider']
    if provider['kind'] == 'native-project':
        from workspace_native_mysql import connection_parameters, native_binary
        settings = connection_parameters(project_dir)
        arguments = [str(native_binary('mysqldump')), '--no-defaults', '--protocol=TCP',
            '--host=127.0.0.1', '--port=' + str(settings['port']), '--user=' + settings['user'],
            '--single-transaction', '--skip-lock-tables', '--no-tablespaces',
            '--set-gtid-purged=OFF', '--hex-blob', '--skip-comments',
            '--databases', *DATABASES]
        with path.open('wb') as handle:
            result = subprocess.run(arguments, stdout=handle, stderr=subprocess.PIPE, timeout=600,
                                    env={**os.environ, 'MYSQL_PWD': settings['password']})
        if result.returncode or not path.stat().st_size:
            raise ValueError('Logical database backup failed; no transfer was published')
        return
    if provider['kind'] != 'docker-container-env':
        raise ValueError('Unsupported project database runtime')
    container = provider['container']
    # Legacy donors remain in their explicitly configured Docker runtime.
    # Password remains inside Docker's environment, never an argv or artifact.
    command = 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --skip-lock-tables --no-tablespaces --set-gtid-purged=OFF --hex-blob --skip-comments --databases schema recording_workspace'
    with path.open('wb') as handle:
        result = subprocess.run(['docker', 'exec', container, 'sh', '-c', command], stdout=handle,
                                stderr=subprocess.PIPE, timeout=600)
    if result.returncode or not path.stat().st_size:
        raise ValueError('Logical database backup failed; no transfer was published')


def _import(project_dir, path):
    # Treat received SQL as data from another user: it gets no system-schema,
    # account, FILE, SUPER, or GRANT privileges, and client commands are disabled.
    account = 'rieke_transfer_restore'
    password = secrets.token_urlsafe(36)
    provider = _json(Path(project_dir) / 'catalog.json')['connection']['credential_provider']
    account_host = '127.0.0.1' if provider['kind'] == 'native-project' else 'localhost'
    connection = _connection(project_dir)
    try:
        with connection.cursor() as cursor:
            cursor.execute("CREATE USER %s@%s IDENTIFIED BY %s", (account, account_host, password))
            for database in DATABASES:
                cursor.execute(f'CREATE DATABASE IF NOT EXISTS `{database}`')
                cursor.execute(f"GRANT ALL PRIVILEGES ON `{database}`.* TO %s@%s", (account, account_host))
        provider = _json(Path(project_dir) / 'catalog.json')['connection']['credential_provider']
        if provider['kind'] == 'native-project':
            from workspace_native_mysql import connection_parameters, native_binary
            settings = connection_parameters(project_dir)
            arguments = [str(native_binary('mysql')), '--no-defaults', '--protocol=TCP',
                '--host=127.0.0.1', '--port=' + str(settings['port']), '--user=' + account,
                '--binary-mode', '--local-infile=0']
        elif provider['kind'] == 'docker-container-env':
            arguments = ['docker', 'exec', '-i', '--env', 'MYSQL_PWD', provider['container'],
                         'mysql', '-u' + account, '--binary-mode', '--local-infile=0']
        else:
            raise ValueError('Unsupported project database runtime')
        with path.open('rb') as handle:
            result = subprocess.run(arguments, stdin=handle,
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=600,
                env={**os.environ, 'MYSQL_PWD': password})
        if result.returncode:
            raise ValueError('Logical database restore failed; source package is preserved')
    finally:
        try:
            with connection.cursor() as cursor:
                cursor.execute("DROP USER IF EXISTS %s@%s", (account, account_host))
        finally:
            connection.close()


def _catalog(identity, instance):
    """A received logical backup always becomes a private native MySQL project."""
    from workspace_native_mysql import native_catalog
    return native_catalog(identity, instance)


def inspect_package(package_dir):
    """Validate complete inventory before starting MySQL or writing any files."""
    raw = Path(package_dir).expanduser()
    if raw.is_symlink() or not raw.is_dir():
        raise ValueError('Choose a regular prepared project folder')
    root = raw.resolve()
    marker = _inside(root, MANIFEST)
    if not marker.is_file() or marker.stat().st_size > 16 * 1024 * 1024:
        raise ValueError('Prepared project is incomplete or its transfer manifest is invalid')
    value = _json(marker)
    if not isinstance(value, dict) or value.get('format') != FORMAT or type(value.get('version')) is not int or value['version'] != 1:
        raise ValueError('Unsupported prepared project format')
    if value.get('database_format') != 'mysql8-logical-v1' or value.get('mode') != 'complete':
        raise ValueError('Unsupported prepared project database format or transfer mode')
    files = value.get('files')
    if not isinstance(files, dict) or not {'project.json', 'database.sql'} <= files.keys():
        raise ValueError('Prepared project is missing required files')
    for relative, expected in files.items():
        _inside(root, relative)
        if not isinstance(expected, dict) or set(expected) != {'size', 'sha256'} or type(expected['size']) is not int or expected['size'] < 0 or not isinstance(expected['sha256'], str) or not re.fullmatch('[0-9a-f]{64}', expected['sha256']):
            raise ValueError('Prepared project file checksum record is invalid')
        if relative not in {'project.json', 'database.sql'} and relative.split('/')[0] not in DIRECTORIES:
            raise ValueError('Prepared project contains unsupported runtime files')
    if _files(root) != files:
        raise ValueError('Prepared project checksum or file inventory mismatch')
    from workspace_projects import _identity
    project = _json(root / 'project.json')
    if project.get('format') != 'recording-project' or type(project.get('version')) is not int or project['version'] != 1 or _identity(project.get('project_uuid')) != _identity(value.get('project_uuid')):
        raise ValueError('Prepared project identity or format is invalid')
    if not isinstance(project.get('name'), str) or not project['name'].strip() or project.get('catalog_ref', 'catalog.json') != 'catalog.json':
        raise ValueError('Prepared project manifest is invalid')
    sources = value.get('sources')
    if not isinstance(sources, list):
        raise ValueError('Prepared project source inventory is invalid')
    seen = set()
    for source in sources:
        if not isinstance(source, dict) or set(source) != {'source_sha256', 'recording_ref', 'metadata_ref', 'metadata_sha256'}:
            raise ValueError('Prepared project source record is invalid')
        sha = source['source_sha256']
        if not isinstance(sha, str) or not re.fullmatch('[0-9a-f]{64}', sha) or sha in seen:
            raise ValueError('Prepared project source identities are invalid or duplicated')
        seen.add(sha)
        for key in ('recording_ref', 'metadata_ref'):
            _inside(root, source[key])
        if not source['recording_ref'].startswith('raw-uploads/') or not source['metadata_ref'].startswith('imports/'):
            raise ValueError('Prepared source references use unsupported directories')
        if files.get(source['recording_ref'], {}).get('sha256') != sha or files.get(source['metadata_ref'], {}).get('sha256') != source['metadata_sha256']:
            raise ValueError('Prepared project source checksums disagree')
    return value


def _remove_runtime(project_dir):
    provider = _json(Path(project_dir) / 'catalog.json')['connection']['credential_provider']
    if provider['kind'] == 'native-project':
        from workspace_native_mysql import stop_native_database
        stop_native_database(project_dir)
        return
    if provider['kind'] != 'docker-container-env':
        raise ValueError('Unsupported project database runtime')
    container = provider['container']
    result = subprocess.run(['docker', 'rm', '-f', container], stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE, timeout=60)
    if result.returncode:
        raise ValueError('Could not remove temporary transfer database; preserve its folder for recovery')


def _artifact_relocations(connection, identity, root, previous=None):
    """Verify current exported-artifact locators without rewriting frozen exports."""
    root = Path(root)
    with connection.cursor() as cursor:
        try:
            cursor.execute('SELECT project_uuid, dataset_uuid, artifact_path, artifact_sha256 FROM recording_workspace.dataset_revision')
            records = cursor.fetchall()
        except Exception as error:
            if getattr(error, 'args', [None])[0] == 1146:
                return []  # Projects with no exports may not have this table yet.
            raise
        if not records:
            return []
        if previous is None:
            cursor.execute('SELECT project_uuid, directory FROM recording_workspace.project')
            projects = cursor.fetchall()
            if len(projects) != 1 or projects[0][0] != identity:
                raise ValueError('Export database does not match the project identity')
            previous = Path(projects[0][1])
    previous = Path(previous)
    if not previous.is_absolute():
        raise ValueError('Recorded project folder is not an absolute path')
    changes = []
    for project_uuid, dataset_uuid, location, checksum in records:
        if project_uuid != identity or not isinstance(location, str) or not Path(location).is_absolute():
            raise ValueError('Export artifact identity or locator is invalid')
        path = Path(location)
        if path.is_relative_to(previous / 'exports'):
            path = _inside(root, path.relative_to(previous).as_posix())
        elif path.is_relative_to(root / 'exports'):
            path = _inside(root, path.relative_to(root).as_posix())
        else:
            raise ValueError('Export artifact must live in this project exports folder')
        if not path.is_file():
            raise ValueError('Project relocation is missing a saved export artifact: ' + str(path))
        if not isinstance(checksum, str) or not re.fullmatch('[0-9a-f]{64}', checksum) or _hash(path) != checksum:
            raise ValueError('Project relocation export checksum mismatch: ' + str(path))
        changes.append((str(path), dataset_uuid, identity))
    return changes


def _update_artifact_locations(cursor, changes):
    for values in changes:
        cursor.execute('UPDATE recording_workspace.dataset_revision SET artifact_path=%s WHERE dataset_uuid=%s AND project_uuid=%s', values)


def restore_project(package_dir, destination):
    """Restore into a new local instance, publishing it only after verification."""
    package = Path(package_dir).expanduser().resolve()
    manifest = inspect_package(package_dir)
    target = _destination(destination, package)
    instance = str(uuid.uuid4())
    identity = manifest['project_uuid']
    catalog = _catalog(identity, instance)
    # Reserve destination exclusively. The marker hides all partial restorations.
    target.mkdir(mode=0o700)
    _write(target / PENDING, {'version': 1, 'runtime': 'native-mysql', 'instance_uuid': instance, 'project_uuid': identity})
    runtime_attempted = False
    try:
        for relative in manifest['files']:
            if relative == 'database.sql':
                continue
            output = _inside(target, relative)
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(_inside(package, relative), output)
            if _hash(output) != manifest['files'][relative]['sha256']:
                raise ValueError('Prepared project changed during restore')
        _write(target / 'catalog.json', catalog)
        _write(target / 'database/service.json', catalog['managed_database'])
        from workspace_storage import initialize_layout
        initialize_layout(target, identity, Path(__file__).resolve().parents[1])
        # Seal our own dump copy so a package change cannot alter SQL mid-import.
        dump = target / 'database' / 'transfer.sql'
        shutil.copyfile(package / 'database.sql', dump)
        if _hash(dump) != manifest['files']['database.sql']['sha256']:
            raise ValueError('Prepared database changed during restore')
        from workspace_project_database import ensure_project_database
        runtime_attempted = True
        ensure_project_database(target, _restoring=True)
        _import(target, dump)
        connection = _connection(target)
        try:
            sources = _sources(connection, identity)
            artifacts = _artifact_relocations(connection, identity, target)
            mappings = {source['source_sha256']: source for source in manifest['sources']}
            if set(mappings) != {source['source_sha256'] for source in sources}:
                raise ValueError('Restored database sources disagree with the transfer inventory')
            with connection.cursor() as cursor:
                for source in sources:
                    record = source['manifest']
                    mapping = mappings[source['source_sha256']]
                    if record.get('metadata_sha256') != mapping['metadata_sha256']:
                        raise ValueError('Restored metadata checksum disagrees with database')
                    record['source_path'] = str(target / mapping['recording_ref'])
                    record['metadata_path'] = str(target / mapping['metadata_ref'])
                    cursor.execute('UPDATE recording_workspace.source SET manifest=%s WHERE source_sha256=%s AND project_uuid=%s',
                                   (json.dumps(record), source['source_sha256'], identity))
                    # Current import pointers move; historical event payloads stay intact.
                    local_manifest = (target / mapping['metadata_ref']).parent / 'import-manifest.json'
                    if local_manifest.is_file():
                        current = _json(local_manifest)
                        if current.get('source_sha256') != source['source_sha256']:
                            raise ValueError('Imported source file identity disagrees with database')
                        current.update(source_path=record['source_path'], metadata_path=record['metadata_path'])
                        _write(local_manifest, current)
                _update_artifact_locations(cursor, artifacts)
                cursor.execute('UPDATE recording_workspace.project SET directory=%s WHERE project_uuid=%s', (str(target), identity))
                cursor.execute('SHOW DATABASES')
                if {row[0] for row in cursor.fetchall()} - set(DATABASES) - {'mysql', 'information_schema', 'performance_schema', 'sys'}:
                    raise ValueError('Restored backup contains unexpected databases')
        finally:
            connection.close()
        dump.unlink()
        _write(target / 'database/transfer-receipt.json', {'format': FORMAT, 'version': 1,
            'project_uuid': identity, 'instance_uuid': instance, 'verified': True,
            'package_manifest_sha256': _hash(package / MANIFEST)})
        (target / PENDING).unlink()
        return {'project_uuid': identity, 'instance_uuid': instance, 'directory': str(target),
                'files': len(manifest['files']), 'source_count': len(manifest['sources']), 'verified': True}
    except BaseException:
        if runtime_attempted:
            _remove_runtime(target)
        shutil.rmtree(target)
        raise


def prepare_project(project_dir, destination):
    """Capture a complete offline package and prove its logical backup restores."""
    from workspace_projects import _project_record
    from workspace_project_database import ensure_project_database
    raw = Path(project_dir).expanduser()
    if raw.is_symlink() or not raw.is_dir():
        raise ValueError('Choose an existing regular project folder')
    root = raw.resolve()
    record = _project_record(root)
    target = _destination(destination, root)
    identity = record['uuid']
    with _offline(root):
        ensure_project_database(root)
        connection = _connection(root)
        staging = Path(tempfile.mkdtemp(prefix='.rieke-transfer-', dir=target.parent))
        try:
            with connection.cursor() as cursor:
                cursor.execute('SET SESSION lock_wait_timeout=15')
                cursor.execute('FLUSH TABLES WITH READ LOCK')
            sources = _sources(connection, identity)
            source_project = _json(root / 'project.json')
            # Only portable identity/display fields enter the transfer manifest.
            project = {key: source_project[key] for key in ('format', 'version', 'project_uuid', 'name', 'display_name', 'created_at') if key in source_project}
            project['name'] = source_project.get('name') or record['name']
            project['catalog_ref'] = 'catalog.json'
            _write(staging / 'project.json', project)
            before = {}
            for directory in DIRECTORIES:
                source_dir = root / directory
                if source_dir.exists():
                    if source_dir.is_symlink():
                        raise ValueError('Managed transfer directories cannot be symbolic links')
                    before[directory] = _files(source_dir, skip_marker=False)
                    shutil.copytree(source_dir, staging / directory)
            inventory = []
            for source in sources:
                manifest = source['manifest']
                metadata = Path(manifest['metadata_path']).resolve(strict=True)
                if not metadata.is_relative_to(root / 'imports'):
                    raise ValueError('Source metadata must live in project imports')
                reference = metadata.relative_to(root).as_posix()
                if _hash(_inside(staging, reference)) != manifest['metadata_sha256']:
                    raise ValueError('Source metadata checksum changed')
                recording = Path(manifest['source_path']).resolve()
                recording_ref = (recording.relative_to(root).as_posix() if recording.is_relative_to(root / 'raw-uploads')
                                 else 'raw-uploads/' + source['source_sha256'] + '.h5')
                output = _inside(staging, recording_ref)
                output.parent.mkdir(exist_ok=True)
                if not output.exists():
                    try:
                        shutil.copyfile(recording, output)
                    except FileNotFoundError:
                        raise ValueError('A registered recording is missing; locate it before preparing a complete transfer') from None
                if _hash(output) != source['source_sha256']:
                    raise ValueError('Recording checksum changed or a recording is missing')
                inventory.append({'source_sha256': source['source_sha256'], 'recording_ref': recording_ref,
                                  'metadata_ref': reference, 'metadata_sha256': manifest['metadata_sha256']})
            _dump(root, staging / 'database.sql')
            for directory, prior in before.items():
                staged_files = _files(staging / directory, skip_marker=False)
                if _files(root / directory, skip_marker=False) != prior or any(staged_files.get(key) != value for key, value in prior.items()):
                    raise ValueError('Project files changed while preparing transfer; stop all writers and retry')
            with connection.cursor() as cursor:
                cursor.execute('UNLOCK TABLES')
            connection.close()
            connection = None
            _write(staging / MANIFEST, {'format': FORMAT, 'version': 1, 'mode': 'complete',
                'database_format': 'mysql8-logical-v1', 'project_uuid': identity,
                'sources': inventory, 'files': _files(staging)})
            # Real restore verification, including identities and current source locators.
            verify_parent = Path(tempfile.mkdtemp(prefix='.rieke-verify-', dir=target.parent))
            verified = restore_project(staging, str(verify_parent / 'project'))
            _remove_runtime(Path(verified['directory']))
            shutil.rmtree(verify_parent)
            # Claim the final path exclusively before replacing our own empty
            # reservation with the fully verified package.
            try:
                target.mkdir(mode=0o700)
            except FileExistsError:
                raise ValueError('Destination appeared during preparation; nothing was overwritten') from None
            staging.rename(target)
            return {'project_uuid': identity, 'directory': str(target),
                    'files': len(_json(target / MANIFEST)['files']), 'source_count': len(inventory), 'verified': True}
        finally:
            if connection is not None:
                connection.close()  # Releases the database-wide read lock on every failure.
            if staging.exists():
                shutil.rmtree(staging)


def _replace_json(path, value):
    """Replace current local metadata atomically during retryable relocation."""
    path = Path(path)
    if path.is_symlink():
        raise ValueError('Current project manifests cannot be symbolic links')
    temporary = path.with_name('.' + path.name + '.' + uuid.uuid4().hex)
    try:
        _write(temporary, value)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def rebase_project_paths(project_dir, connection=None):
    """Reopen a cold-copied native project at its new location without packaging.

    Run before starting app writers. Only current project/source locators change;
    historical event payloads and immutable exports keep their original evidence.
    All dependencies are verified before writing. A small journal makes interrupted
    local-file/SQL updates idempotently recoverable on the next open.
    """
    root = Path(project_dir).expanduser().resolve()
    identity = _json(root / 'project.json')['project_uuid']
    journal = root / '.project-path-rebase.pending'
    if journal.is_symlink():
        raise ValueError('Project relocation journal cannot be a symbolic link')
    owned_connection = connection is None
    connection = connection or _connection(root)
    try:
        with connection.cursor() as cursor:
            try:
                cursor.execute('SELECT project_uuid, directory FROM recording_workspace.project')
                projects = cursor.fetchall()
            except Exception as error:
                if getattr(error, 'args', [None])[0] in (1049, 1146):
                    return {'relocated': False, 'source_count': 0, 'directory': str(root)}
                raise
        if not projects:
            return {'relocated': False, 'source_count': 0, 'directory': str(root)}
        if len(projects) != 1 or projects[0][0] != identity:
            raise ValueError('Database must contain exactly the declared project identity before relocation')
        previous = Path(projects[0][1])
        if not previous.is_absolute():
            raise ValueError('Recorded project folder is not an absolute path')
        if journal.exists():
            recovery = _json(journal)
            if recovery.get('project_uuid') != identity or recovery.get('directory') != str(root):
                raise ValueError('An interrupted project relocation needs recovery at its recorded destination')
            previous = Path(recovery['previous_directory'])
            if not previous.is_absolute():
                raise ValueError('Project relocation journal is invalid')
        elif previous == root:
            return {'relocated': False, 'source_count': 0, 'directory': str(root)}

        def relocate(value, *, metadata=False):
            if not isinstance(value, str) or not Path(value).is_absolute():
                raise ValueError('A recorded source locator is not an absolute path')
            path = Path(value)
            if path.is_relative_to(previous):
                path = _inside(root, path.relative_to(previous).as_posix())
            elif path.is_relative_to(root):
                path = _inside(root, path.relative_to(root).as_posix())
            elif metadata:
                raise ValueError('Source metadata must live in the project imports folder')
            if metadata and not path.is_relative_to(root / 'imports'):
                raise ValueError('Source metadata must live in the project imports folder')
            return path

        sources = _sources(connection, identity)
        changes = []
        missing = []
        for source in sources:
            record = dict(source['manifest'])
            recording = relocate(record['source_path'])
            metadata = relocate(record['metadata_path'], metadata=True)
            for path, expected in ((recording, source['source_sha256']),
                                   (metadata, record['metadata_sha256'])):
                if not path.is_file():
                    missing.append(str(path))
                elif _hash(path) != expected:
                    raise ValueError('Project relocation checksum mismatch: ' + str(path))
            record.update(source_path=str(recording), metadata_path=str(metadata))
            local = metadata.parent / 'import-manifest.json'
            local_record = None
            if local.exists():
                if local.is_symlink():
                    raise ValueError('Current import manifests cannot be symbolic links')
                local_record = _json(local)
                if local_record.get('source_sha256') != source['source_sha256']:
                    raise ValueError('Imported source file identity disagrees with database')
                local_record.update(source_path=str(recording), metadata_path=str(metadata))
            changes.append((source['source_sha256'], record, local, local_record))
        if missing:
            raise ValueError('This project depends on missing files. Copy managed recordings with the project, '
                             'or restore access to linked recordings before opening: ' + '; '.join(missing[:8]))
        artifacts = _artifact_relocations(connection, identity, root, previous)
        _replace_json(journal, {'version': 1, 'project_uuid': identity,
                               'previous_directory': str(previous), 'directory': str(root)})
        connection.begin()
        try:
            with connection.cursor() as cursor:
                for sha, record, local, local_record in changes:
                    if local_record is not None:
                        _replace_json(local, local_record)
                    cursor.execute('UPDATE recording_workspace.source SET manifest=%s WHERE source_sha256=%s AND project_uuid=%s',
                                   (json.dumps(record), sha, identity))
                _update_artifact_locations(cursor, artifacts)
                cursor.execute('UPDATE recording_workspace.project SET directory=%s WHERE project_uuid=%s', (str(root), identity))
            connection.commit()
        except BaseException:
            connection.rollback()
            raise
        journal.unlink()
        return {'relocated': True, 'source_count': len(sources), 'directory': str(root)}
    finally:
        if owned_connection:
            connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare', 'inspect', 'restore'))
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', nargs='?', type=Path)
    args = parser.parse_args()
    if args.operation == 'inspect':
        result = inspect_package(args.source)
    else:
        if args.destination is None:
            parser.error('prepare and restore require a new destination folder')
        result = (prepare_project if args.operation == 'prepare' else restore_project)(args.source, args.destination)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
