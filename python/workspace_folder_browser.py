"""Read-only, paged local directory navigation for the browser app."""
from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlsplit

PAGE_LIMIT = 200
MAX_ENTRIES = 20_000


def _directory(path):
    if path is None:
        path = Path.home()
    if not isinstance(path, (str, Path)) or not str(path).strip():
        raise ValueError('Choose an absolute folder path.')
    candidate = Path(str(path).strip()).expanduser()
    if not candidate.is_absolute():
        raise ValueError('Choose an absolute folder path.')
    try:
        # Resolving supports normal macOS aliases such as /var and /tmp.
        candidate = candidate.resolve()
        while not candidate.exists():
            parent = candidate.parent
            if parent == candidate:
                raise ValueError('The folder does not exist.')
            candidate = parent
        if not candidate.is_dir():
            raise ValueError('Choose a folder, not a file.')
        if not os.access(candidate, os.R_OK | os.X_OK):
            raise ValueError('Access denied for this folder.')
        return candidate
    except PermissionError as error:
        raise ValueError('Access denied for this folder.') from error
    except (OSError, RuntimeError) as error:
        raise ValueError('This folder cannot be accessed. Choose another location.') from error


def _locations():
    home = Path.home()
    locations, seen = [], set()
    for name, path in (('Home', home), ('Documents', home / 'Documents'),
                       ('Desktop', home / 'Desktop'), ('Volumes', Path('/Volumes')),
                       ('Computer', Path('/'))):
        try:
            if not path.is_dir() or not os.access(path, os.R_OK | os.X_OK):
                continue
            path = str(path.resolve())
        except (OSError, RuntimeError):
            continue
        if path not in seen:
            locations.append({'name': name, 'path': path})
            seen.add(path)
    return locations


def list_folder(path=None, *, offset=0, limit=PAGE_LIMIT):
    """List immediate accessible folders, never files or a recursive tree.

    A destination that has not been created opens its nearest existing parent.
    Page size and the number of inspected directory entries are both bounded.
    """
    if type(offset) is not int or offset < 0 or type(limit) is not int or not 1 <= limit <= PAGE_LIMIT:
        raise ValueError('Use a nonnegative offset and a folder page size from 1 to 200.')
    root = _directory(path)
    folders, truncated, empty = [], False, True
    try:
        with os.scandir(root) as entries:
            for index, entry in enumerate(entries):
                empty = False  # Files, hidden names and aliases also occupy the folder.
                if index >= MAX_ENTRIES:
                    truncated = True
                    break
                if entry.name.startswith('.'):
                    continue
                try:
                    if entry.is_symlink() or not entry.is_dir(follow_symlinks=False):
                        continue
                    child = root / entry.name
                    if not os.access(child, os.R_OK | os.X_OK):
                        continue
                    folders.append({'name': entry.name, 'path': str(child)})
                except OSError:
                    continue  # An inaccessible or disappearing child is not selectable.
    except OSError as error:
        raise ValueError('Access denied for this folder. Choose another location.') from error
    folders.sort(key=lambda folder: (folder['name'].casefold(), folder['name']))
    has_more = offset + limit < len(folders)
    return {'directory': str(root), 'parent': None if root == root.parent else str(root.parent),
            'folders': folders[offset:offset + limit], 'locations': _locations(),
            'offset': offset, 'limit': limit, 'total': len(folders), 'has_more': has_more,
            'next_offset': offset + limit if has_more else None, 'truncated': truncated,
            'empty': empty and not truncated}


def register_folder_browser_routes(app):
    """Require a deliberate same-origin loopback request even though this is GET."""
    from flask import jsonify, request

    @app.get('/api/folders')
    def folder_browser():
        if (request.remote_addr not in {'127.0.0.1', '::1'}
                or urlsplit(request.host_url).hostname not in {'localhost', '127.0.0.1', '::1'}
                or request.headers.get('X-Workspace-Request') != '1'
                or request.headers.get('Origin', request.host_url.rstrip('/')) != request.host_url.rstrip('/')):
            return jsonify(error='Folder browsing requires a same-origin local app request.'), 403
        if (set(request.args) - {'directory', 'offset', 'limit'}
                or any(len(request.args.getlist(key)) != 1 for key in request.args)):
            return jsonify(error='Folder browsing accepts one directory, offset and limit only.'), 400
        numbers = {}
        for key, default in (('offset', 0), ('limit', PAGE_LIMIT)):
            value = request.args.get(key, str(default))
            if not value.isascii() or not value.isdecimal() or len(value) > 9:
                return jsonify(error='Folder offset and page size must be integers.'), 400
            numbers[key] = int(value)
        try:
            return jsonify(list_folder(request.args.get('directory'), **numbers))
        except ValueError as error:
            return jsonify(error=str(error)), 400
