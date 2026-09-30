"""Folder navigation stays local, read-only, shallow and explicitly paged."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from flask import Flask

import workspace_folder_browser as browser


class FolderBrowserTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        for name in ('Beta', 'alpha', 'Zulu', '.hidden'):
            (self.root / name).mkdir()
        (self.root / 'recording.h5').write_bytes(b'file contents must never be served')
        (self.root / 'alias').symlink_to(self.root / 'alpha', target_is_directory=True)
        (self.root / 'broken alias').symlink_to(self.root / 'absent', target_is_directory=True)
        (self.root / 'alpha/nested').mkdir()
        self.app = Flask(__name__)
        browser.register_folder_browser_routes(self.app)
        self.client = self.app.test_client()
        self.headers = {'X-Workspace-Request': '1'}

    def test_sorted_direct_folders_only_and_no_file_reads(self):
        with patch.object(Path, 'open', side_effect=AssertionError('Do not read files')):
            result = browser.list_folder(self.root)
        self.assertEqual(result['directory'], str(self.root))
        self.assertEqual(result['parent'], str(self.root.parent))
        self.assertEqual([folder['name'] for folder in result['folders']], ['alpha', 'Beta', 'Zulu'])
        self.assertEqual([folder['path'] for folder in result['folders']],
                         [str(self.root / name) for name in ('alpha', 'Beta', 'Zulu')])
        self.assertEqual(result['total'], 3)
        self.assertFalse(result['has_more'])
        self.assertFalse(result['truncated'])

    def test_nonexistent_destination_uses_nearest_parent_without_creating_it(self):
        target = self.root / 'alpha/new project/data'
        before = set(self.root.rglob('*'))
        result = browser.list_folder(target)
        self.assertEqual(result['directory'], str(self.root / 'alpha'))
        self.assertEqual([folder['name'] for folder in result['folders']], ['nested'])
        self.assertEqual(before, set(self.root.rglob('*')))
        self.assertFalse(target.exists())

    def test_home_locations_and_root_parent(self):
        for name in ('Documents', 'Desktop'):
            (self.root / name).mkdir()
        with patch.object(Path, 'home', return_value=self.root):
            result = browser.list_folder()
        self.assertEqual(result['directory'], str(self.root))
        locations = {entry['name']: entry['path'] for entry in result['locations']}
        self.assertEqual(locations['Home'], str(self.root))
        self.assertEqual(locations['Documents'], str(self.root / 'Documents'))
        self.assertEqual(locations['Desktop'], str(self.root / 'Desktop'))
        self.assertIsNone(browser.list_folder('/')['parent'])

    def test_parent_aliases_are_resolved_to_normal_absolute_paths(self):
        alias = self.root / 'directory alias'
        alias.symlink_to(self.root / 'alpha', target_is_directory=True)
        result = browser.list_folder(alias / 'nested/future project')
        self.assertEqual(result['directory'], str(self.root / 'alpha/nested'))
        self.assertNotIn('directory alias', result['directory'])

    def test_pagination_is_explicit_and_bounded(self):
        first = browser.list_folder(self.root, limit=2)
        self.assertEqual([entry['name'] for entry in first['folders']], ['alpha', 'Beta'])
        self.assertTrue(first['has_more'])
        self.assertEqual(first['next_offset'], 2)
        last = browser.list_folder(self.root, offset=2, limit=2)
        self.assertEqual([entry['name'] for entry in last['folders']], ['Zulu'])
        self.assertFalse(last['has_more'])
        self.assertIsNone(last['next_offset'])
        self.assertEqual(browser.list_folder(self.root, offset=10)['folders'], [])
        for kwargs in ({'offset': -1}, {'offset': True}, {'limit': 0}, {'limit': 201}, {'limit': True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                browser.list_folder(self.root, **kwargs)

    def test_scan_cap_is_reported_without_silent_truncation(self):
        with patch.object(browser, 'MAX_ENTRIES', 1):
            result = browser.list_folder(self.root)
        self.assertTrue(result['truncated'])
        self.assertLessEqual(result['total'], 1)
        self.assertFalse(result['empty'])

    def test_empty_counts_all_entries_including_files_and_hidden_names(self):
        selected = self.root / 'empty folder'
        selected.mkdir()
        self.assertTrue(browser.list_folder(selected)['empty'])
        for name in ('recording.h5', '.hidden file'):
            with self.subTest(name=name):
                file = selected / name
                file.write_bytes(b'only entry')
                result = browser.list_folder(selected)
                self.assertEqual(result['folders'], [])
                self.assertFalse(result['empty'])
                file.unlink()

    def test_inaccessible_children_are_omitted_and_selected_folder_reports_error(self):
        actual_access = os.access
        with patch.object(browser.os, 'access', side_effect=lambda path, mode: (
                False if Path(path) == self.root / 'Beta' else actual_access(path, mode))):
            result = browser.list_folder(self.root)
        self.assertEqual([entry['name'] for entry in result['folders']], ['alpha', 'Zulu'])
        with patch.object(browser.os, 'access', return_value=False):
            with self.assertRaisesRegex(ValueError, 'Access denied'):
                browser.list_folder(self.root)
        with patch.object(browser.os, 'scandir', side_effect=PermissionError('private details')):
            with self.assertRaisesRegex(ValueError, '^Access denied'):
                browser.list_folder(self.root)

    def test_relative_empty_nonstring_and_file_paths_are_rejected(self):
        for value in ('relative/folder', '', [], self.root / 'recording.h5'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                browser.list_folder(value)

    def test_route_accepts_deliberate_local_requests_and_rejects_invalid_queries(self):
        response = self.client.get('/api/folders', query_string={'directory': str(self.root), 'limit': 2},
                                   headers={**self.headers, 'Origin': 'http://localhost'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()['next_offset'], 2)
        for query in ({'file': str(self.root / 'recording.h5')}, {'directory': ''},
                      {'directory': 'relative'}, {'offset': '-1'}, {'offset': '1.5'},
                      {'offset': '\u0661'}, {'limit': '201'}, {'offset': '1' * 20}):
            with self.subTest(query=query):
                result = self.client.get('/api/folders', query_string=query, headers=self.headers)
                self.assertEqual(result.status_code, 400)
        response = self.client.get('/api/folders?directory=/&directory=/tmp', headers=self.headers)
        self.assertEqual(response.status_code, 400)

    def test_privacy_boundary_rejects_untrusted_get_before_filesystem_access(self):
        requests = ({'headers': {}},
                    {'headers': {**self.headers, 'Origin': 'https://other.example'}},
                    {'headers': self.headers, 'base_url': 'http://localhost.evil.example'},
                    {'headers': self.headers, 'environ_overrides': {'REMOTE_ADDR': '192.0.2.1'}})
        with patch.object(browser, 'list_folder', side_effect=AssertionError('No filesystem access')):
            for kwargs in requests:
                with self.subTest(kwargs=kwargs):
                    self.assertEqual(self.client.get('/api/folders', **kwargs).status_code, 403)


if __name__ == '__main__':
    unittest.main()
