import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from workspace_projects import create_project
from workspace_project_validation import validate_project_folder


class ProjectValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.record = create_project(Path(self.temp.name) / 'projects', 'Validation')
        self.root = Path(self.record['path'])

    def initialized(self):
        descriptor = json.loads((self.root / 'database/service.json').read_text())
        identity = {key: descriptor[key] for key in ('version', 'project_uuid', 'instance_uuid')}
        (self.root / 'database/native-owner.json').write_text(json.dumps({**identity, 'mysql_series': '8.4', 'clean_shutdown': True}))
        (self.root / 'database/native-credentials.json').write_text(json.dumps({**identity, 'password': 'fixture-only' * 4}))
        data = self.root / 'database/mysql'
        data.mkdir()
        for name in ('mysql.ibd', 'ibdata1'):
            (data / name).write_bytes(b'disposable presence fixture')

    def test_new_project_validation_does_not_create_or_modify_files(self):
        before = {str(p): (p.read_bytes(), p.stat().st_mode) for p in self.root.rglob('*') if p.is_file()}
        with patch('workspace_native_mysql.ensure_native_database', side_effect=AssertionError('No server')):
            result = validate_project_folder(self.root)
        after = {str(p): (p.read_bytes(), p.stat().st_mode) for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        self.assertEqual(result['database_status'], 'not_initialized')
        self.assertEqual(result['project']['uuid'], self.record['uuid'])

    def test_initialized_project_never_returns_credentials_or_chmods(self):
        self.initialized()
        credentials = self.root / 'database/native-credentials.json'
        credentials.chmod(0o644)
        result = validate_project_folder(self.root)
        self.assertEqual(result['database_status'], 'initialized')
        self.assertNotIn('fixture-only', json.dumps(result))
        self.assertEqual(credentials.stat().st_mode & 0o777, 0o644)

    def test_missing_data_is_not_treated_as_new_project(self):
        self.initialized()
        for p in (self.root / 'database/mysql').iterdir():
            p.unlink()
        with self.assertRaisesRegex(ValueError, 'previously initialized'):
            validate_project_folder(self.root)

    def test_missing_core_file_is_rejected(self):
        self.initialized()
        (self.root / 'database/mysql/mysql.ibd').unlink()
        with self.assertRaisesRegex(ValueError, 'mysql.ibd'):
            validate_project_folder(self.root)

    def test_missing_owner_preserves_incomplete_database(self):
        self.initialized()
        (self.root / 'database/native-owner.json').unlink()
        with self.assertRaisesRegex(ValueError, 'ownership is missing'):
            validate_project_folder(self.root)

    def test_missing_layout_or_service_or_managed_folder_is_descriptive(self):
        for relative in ('storage.json', 'database/service.json', 'imports'):
            with self.subTest(relative=relative):
                path = self.root / relative
                saved = path.with_name(path.name + '.saved')
                path.rename(saved)
                try:
                    with self.assertRaisesRegex(ValueError, relative):
                        validate_project_folder(self.root)
                finally:
                    saved.rename(path)

    def test_legacy_project_does_not_require_native_layout(self):
        catalog = json.loads((self.root / 'catalog.json').read_text())
        catalog.pop('managed_database')
        catalog['connection']['credential_provider'] = {'kind': 'docker-container-env', 'container': 'legacy'}
        (self.root / 'catalog.json').write_text(json.dumps(catalog))
        (self.root / 'storage.json').unlink()
        self.assertEqual(validate_project_folder(self.root)['database_status'], 'legacy_external')

    def test_manifest_identity_mismatch_and_project_symlink_are_rejected(self):
        link = self.root.parent / 'linked'
        link.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symbolic link'):
            validate_project_folder(link)
        catalog = json.loads((self.root / 'catalog.json').read_text())
        catalog['project_uuid'] = '11111111-1111-4111-8111-111111111111'
        (self.root / 'catalog.json').write_text(json.dumps(catalog))
        with self.assertRaisesRegex(ValueError, 'UUIDs do not match'):
            validate_project_folder(self.root)


if __name__ == '__main__':
    unittest.main()
