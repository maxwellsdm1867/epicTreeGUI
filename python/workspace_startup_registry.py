"""Small durable launcher preference; no database credentials or source payloads."""
from pathlib import Path
import json
import uuid
import fcntl
from recording_workspace import write_json


def read_registry(root):
    path = Path(root) / '.rieke-os.json'
    if path.is_symlink():
        raise ValueError('Startup registry cannot be a symbolic link')
    if not path.exists():
        return {'format':'rieke-os-startup','version':1,'last_project_uuid':None}
    if path.stat().st_size > 64 * 1024:
        raise ValueError('Startup registry is unexpectedly large')
    value = json.loads(path.read_text())
    if not isinstance(value,dict) or value.get('format') != 'rieke-os-startup' or value.get('version') != 1:
        raise ValueError('Startup registry is invalid; preserve it and repair its configuration')
    if value.get('last_project_uuid') is not None:
        uuid.UUID(value['last_project_uuid'])
    return value


def _update_registry(root, changes):
    root = Path(root)
    lock_path = root / '.rieke-os.lock'
    if lock_path.is_symlink():
        raise ValueError('Startup registry lock cannot be a symbolic link')
    with lock_path.open('a') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        value = {**read_registry(root), **changes}
        if len(json.dumps(value).encode()) > 64 * 1024:
            raise ValueError('Startup registry is unexpectedly large')
        write_json(root / '.rieke-os.json', value)


def remember_project(root, identity):
    _update_registry(root, {'last_project_uuid': str(uuid.UUID(identity))})


def remember_project_order(root, paths):
    _update_registry(root, {'project_order': paths})


def ordered_projects(projects, saved):
    # A folder identifies an independent native copy even when UUIDs match.
    paths = saved.get('project_order')
    ranks = {path: index for index, path in enumerate(paths)} if isinstance(paths, list) and all(isinstance(path, str) for path in paths) else {}
    return sorted(projects, key=lambda item: (ranks.get(item['path'], len(ranks)),
        item['name'].casefold(), item['name'], item['path']))
