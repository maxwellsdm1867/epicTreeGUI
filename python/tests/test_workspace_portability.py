"""Transfer validation plus opt-in real bundled-native MySQL round-trip.

RIEKE_TEST_NATIVE_TRANSFER=1 python -m unittest tests.test_workspace_portability
The integration test creates/removes only its own disposable project databases.
"""
import fcntl
import json
import os
import shutil
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch
import uuid

import workspace_portability as transfer
from workspace_projects import create_project, _project_record


class PackageValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.package = self.root / 'package'
        self.package.mkdir()
        self.identity = str(uuid.uuid4())
        transfer._write(self.package / 'project.json', {'format': 'recording-project', 'version': 1,
            'project_uuid': self.identity, 'name': 'Portable study', 'catalog_ref': 'catalog.json'})
        (self.package / 'database.sql').write_text('-- fixture logical database\n')
        self.seal()

    def seal(self, **changes):
        value = {'format': transfer.FORMAT, 'version': 1, 'mode': 'complete',
            'database_format': 'mysql8-logical-v1', 'project_uuid': self.identity,
            'sources': [], 'files': transfer._files(self.package)}
        value.update(changes)
        transfer._write(self.package / transfer.MANIFEST, value)
        return value

    def test_tampering_and_unlisted_files_fail_before_runtime_or_destination(self):
        for change in ('modify', 'add'):
            with self.subTest(change=change):
                self.seal()
                if change == 'modify':
                    (self.package / 'database.sql').write_text('changed')
                else:
                    (self.package / 'surprise').write_text('unlisted')
                with patch('workspace_project_database.ensure_project_database') as start:
                    with self.assertRaisesRegex(ValueError, 'checksum|inventory'):
                        transfer.restore_project(self.package, self.root / 'restored')
                    start.assert_not_called()
                self.assertFalse((self.root / 'restored').exists())

    def test_incomplete_future_and_unsafe_packages_rejected(self):
        for changes in ({'version': 2}, {'version': True}, {'mode': 'linked'},
                        {'database_format': 'future'}, {'project_uuid': str(uuid.uuid4())}):
            with self.subTest(changes=changes):
                self.seal(**changes)
                with self.assertRaises(ValueError):
                    transfer.inspect_package(self.package)
        value = self.seal()
        value['files']['../outside'] = {'sha256': 'a' * 64, 'size': 1}
        transfer._write(self.package / transfer.MANIFEST, value)
        with self.assertRaisesRegex(ValueError, 'relative path'):
            transfer.inspect_package(self.package)
        (self.package / transfer.MANIFEST).unlink()
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            transfer.inspect_package(self.package)

    def test_symbolic_links_and_runtime_configuration_are_not_transferable(self):
        self.seal()
        (self.package / 'link').symlink_to(self.package / 'database.sql')
        with self.assertRaisesRegex(ValueError, 'symbolic'):
            transfer.inspect_package(self.package)
        (self.package / 'link').unlink()
        transfer._write(self.package / 'catalog.json', {'password': 'must not transfer'})
        self.seal()
        with self.assertRaisesRegex(ValueError, 'runtime files'):
            transfer.inspect_package(self.package)

    def test_existing_destination_is_never_overwritten(self):
        destination = self.root / 'existing'
        destination.mkdir()
        (destination / 'keep').write_bytes(b'untouched')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            transfer.restore_project(self.package, destination)
        self.assertEqual((destination / 'keep').read_bytes(), b'untouched')

    def test_active_app_refused_before_database_access(self):
        project = create_project(self.root / 'workspace', 'Locked')
        root = Path(project['path'])
        with (root / '.app-state-session.lock').open('a') as active:
            fcntl.flock(active, fcntl.LOCK_SH | fcntl.LOCK_NB)
            with patch('workspace_project_database.ensure_project_database') as start:
                with self.assertRaisesRegex(ValueError, 'Close all project sessions'):
                    transfer.prepare_project(root, self.root / 'outgoing')
                start.assert_not_called()
        self.assertFalse((self.root / 'outgoing').exists())

    def test_failed_backup_releases_database_lock_and_publishes_nothing(self):
        project = create_project(self.root / 'workspace', 'Backup failure')
        root = Path(project['path'])
        original = (root / 'project.json').read_bytes()
        connection = MagicMock()
        with patch('workspace_project_database.ensure_project_database'), \
             patch.object(transfer, '_connection', return_value=connection), \
             patch.object(transfer, '_sources', return_value=[]), \
             patch.object(transfer, '_dump', side_effect=ValueError('dump failed')):
            with self.assertRaisesRegex(ValueError, 'dump failed'):
                transfer.prepare_project(root, self.root / 'outgoing')
        connection.close.assert_called_once()
        self.assertFalse((self.root / 'outgoing').exists())
        self.assertFalse(list(self.root.glob('.rieke-transfer-*')))
        self.assertEqual((root / 'project.json').read_bytes(), original)

    def test_failed_sql_restore_removes_only_its_new_runtime_and_folder(self):
        before = transfer._files(self.package)
        destination = self.root / 'failed-restore'
        with patch('workspace_project_database.ensure_project_database'), \
             patch.object(transfer, '_import', side_effect=ValueError('SQL failed')), \
             patch.object(transfer, '_remove_runtime') as cleanup:
            with self.assertRaisesRegex(ValueError, 'SQL failed'):
                transfer.restore_project(self.package, destination)
        cleanup.assert_called_once()
        self.assertEqual(cleanup.call_args.args[0], destination)
        self.assertFalse(destination.exists())
        self.assertEqual(transfer._files(self.package), before)

    def test_interrupted_restore_cannot_be_discovered_or_started(self):
        project = create_project(self.root / 'workspace', 'Partial')
        root = Path(project['path'])
        (root / transfer.PENDING).write_text('{}')
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            _project_record(root)
        with patch('workspace_project_database._run') as docker:
            from workspace_project_database import ensure_project_database
            with self.assertRaisesRegex(ValueError, 'incomplete'):
                ensure_project_database(root)
            docker.assert_not_called()


class DirectFolderRelocationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.root, self.old = self.base / 'received', self.base / 'donor'
        self.root.mkdir()
        self.identity = str(uuid.uuid4())
        transfer._write(self.root / 'project.json', {'project_uuid': self.identity})
        self.recording = self.root / 'raw-uploads/fixture.h5'
        self.recording.parent.mkdir()
        self.recording.write_bytes(b'fixture waveform bytes')
        self.metadata = self.root / 'imports/fixture/metadata.catalog.json'
        transfer._write(self.metadata, {'fixture': 'metadata'})
        self.sha = transfer._hash(self.recording)
        self.manifest = {'source_sha256': self.sha, 'metadata_sha256': transfer._hash(self.metadata),
            'source_path': str(self.old / self.recording.relative_to(self.root)),
            'metadata_path': str(self.old / self.metadata.relative_to(self.root))}
        self.local = self.metadata.parent / 'import-manifest.json'
        transfer._write(self.local, self.manifest)
        self.connection = MagicMock()
        self.cursor = self.connection.cursor.return_value.__enter__.return_value
        self.cursor.fetchall.return_value = [(self.identity, str(self.old))]

    def relocate(self):
        with patch.object(transfer, '_sources', return_value=[{'source_sha256': self.sha, 'manifest': self.manifest}]), \
             patch.object(transfer, '_artifact_relocations', return_value=[]):
            return transfer.rebase_project_paths(self.root, self.connection)

    def test_copied_folder_rebases_current_refs_without_changing_recordings_or_history(self):
        before_recording, before_metadata = self.recording.read_bytes(), self.metadata.read_bytes()
        result = self.relocate()
        self.assertTrue(result['relocated'])
        self.assertEqual(transfer._json(self.local)['source_path'], str(self.recording))
        self.assertEqual(transfer._json(self.local)['metadata_path'], str(self.metadata))
        self.assertEqual((self.recording.read_bytes(), self.metadata.read_bytes()), (before_recording, before_metadata))
        queries = [call.args[0] for call in self.cursor.execute.call_args_list]
        self.assertFalse(any('event' in query or 'export' in query for query in queries))
        self.connection.commit.assert_called_once()
        self.assertFalse((self.root / '.project-path-rebase.pending').exists())

    def test_missing_external_recording_and_hash_mismatch_fail_before_writes(self):
        before = self.local.read_bytes()
        self.manifest['source_path'] = str(self.base / 'unavailable-external.h5')
        with self.assertRaisesRegex(ValueError, 'missing files'):
            self.relocate()
        self.assertEqual(self.local.read_bytes(), before)
        self.connection.begin.assert_not_called()
        self.manifest['source_path'] = str(self.old / self.recording.relative_to(self.root))
        self.recording.write_bytes(b'wrong file')
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            self.relocate()
        self.connection.begin.assert_not_called()

    def test_interrupted_relocation_can_retry_after_local_manifest_changed(self):
        self.connection.commit.side_effect = OSError('connection interrupted')
        with self.assertRaisesRegex(OSError, 'interrupted'):
            self.relocate()
        self.assertTrue((self.root / '.project-path-rebase.pending').is_file())
        self.assertEqual(transfer._json(self.local)['source_path'], str(self.recording))
        self.connection.rollback.assert_called_once()
        # Covers an uncertain commit: SQL may already name the new directory.
        self.cursor.fetchall.return_value = [(self.identity, str(self.root))]
        self.manifest = transfer._json(self.local)
        self.connection.commit.side_effect = None
        self.assertTrue(self.relocate()['relocated'])
        self.assertFalse((self.root / '.project-path-rebase.pending').exists())


class ExportRelocationTests(unittest.TestCase):
    def test_only_verified_managed_artifact_locators_are_rebased(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            artifact = root / 'exports/dataset/recordings.json'
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes(b'{"immutable":"export"}')
            before = artifact.read_bytes()
            identity, dataset = str(uuid.uuid4()), str(uuid.uuid4())
            previous = Path('/old/project')
            connection = MagicMock()
            cursor = connection.cursor.return_value.__enter__.return_value
            cursor.fetchall.return_value = [(identity, dataset, str(previous / 'exports/dataset/recordings.json'), transfer._hash(artifact))]
            changes = transfer._artifact_relocations(connection, identity, root, previous)
            self.assertEqual(changes, [(str(artifact), dataset, identity)])
            self.assertEqual(artifact.read_bytes(), before)
            transfer._update_artifact_locations(cursor, changes)
            self.assertEqual(cursor.execute.call_args.args, (
                'UPDATE recording_workspace.dataset_revision SET artifact_path=%s WHERE dataset_uuid=%s AND project_uuid=%s',
                (str(artifact), dataset, identity)))
            artifact.write_bytes(b'wrong export')
            with self.assertRaisesRegex(ValueError, 'export checksum mismatch'):
                transfer._artifact_relocations(connection, identity, root, previous)
            artifact.unlink()
            with self.assertRaisesRegex(ValueError, 'missing a saved export'):
                transfer._artifact_relocations(connection, identity, root, previous)

    def test_foreign_project_and_external_artifact_refs_are_rejected(self):
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        identity, dataset = str(uuid.uuid4()), str(uuid.uuid4())
        for project, path in [(str(uuid.uuid4()), '/old/project/exports/file'), (identity, '/outside/file')]:
            cursor.fetchall.return_value = [(project, dataset, path, 'a' * 64)]
            with self.assertRaises(ValueError):
                transfer._artifact_relocations(connection, identity, Path('/received'), Path('/old/project'))


class NativeTransferCommandTests(unittest.TestCase):
    def test_native_catalog_never_carries_donor_runtime_or_credentials(self):
        identity, instance = str(uuid.uuid4()), str(uuid.uuid4())
        catalog = transfer._catalog(identity, instance)
        self.assertEqual(catalog['managed_database']['kind'], 'native-mysql')
        self.assertEqual(catalog['managed_database']['instance_uuid'], instance)
        self.assertEqual(catalog['connection']['credential_provider']['kind'], 'native-project')
        self.assertNotIn('container', json.dumps(catalog))
        self.assertNotIn('password', json.dumps(catalog))

    def test_native_dump_and_restore_use_bundled_clients_without_docker(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            transfer._write(root / 'catalog.json', transfer._catalog(str(uuid.uuid4()), str(uuid.uuid4())))
            native = types.SimpleNamespace(
                connection_parameters=lambda _: {'host': '127.0.0.1', 'port': 45678,
                                                  'user': 'root', 'password': 'private-root-secret'},
                native_binary=lambda name: Path('/private/runtime/bin') / name)
            calls = []
            def run(arguments, **options):
                calls.append((arguments, options))
                if arguments[0].endswith('/mysqldump'):
                    options['stdout'].write(b'-- logical fixture')
                return types.SimpleNamespace(returncode=0)
            connection = MagicMock()
            with patch.dict('sys.modules', workspace_native_mysql=native), \
                 patch.object(transfer, '_connection', return_value=connection), \
                 patch.object(transfer.subprocess, 'run', side_effect=run):
                dump = root / 'database.sql'
                transfer._dump(root, dump)
                transfer._import(root, dump)
            dump_args, dump_options = calls[0]
            self.assertEqual(dump_args[0], '/private/runtime/bin/mysqldump')
            self.assertEqual(dump_args[1], '--no-defaults')
            self.assertIn('--single-transaction', dump_args)
            self.assertEqual(dump_args[-3:], ['--databases', 'schema', 'recording_workspace'])
            self.assertEqual(dump_options['env']['MYSQL_PWD'], 'private-root-secret')
            import_args, import_options = calls[1]
            self.assertEqual(import_args[0], '/private/runtime/bin/mysql')
            self.assertEqual(import_args[1], '--no-defaults')
            self.assertIn('--user=rieke_transfer_restore', import_args)
            self.assertIn('--binary-mode', import_args)
            self.assertIn('--local-infile=0', import_args)
            self.assertNotEqual(import_options['env']['MYSQL_PWD'], 'private-root-secret')
            for arguments, options in calls:
                self.assertNotIn('docker', arguments)
                self.assertNotIn(options['env']['MYSQL_PWD'], ' '.join(arguments))
            sql = [call.args[0] for call in connection.cursor.return_value.__enter__.return_value.execute.call_args_list]
            self.assertTrue(any('DROP USER' in query for query in sql))
            self.assertFalse(any('GRANT ALL PRIVILEGES ON *.*' in query for query in sql))
            connection.close.assert_called_once()


@unittest.skipUnless(os.environ.get('RIEKE_TEST_NATIVE_TRANSFER') == '1', 'opt-in disposable native MySQL integration')
class NativeRoundTripTests(unittest.TestCase):
    def save_export(self, connection, root, identity):
        # Match the production DatasetRevision fields; the locator is mutable,
        # while recipe and exported bytes are frozen scientific evidence.
        dataset = str(uuid.uuid4())
        artifact = root / 'exports' / dataset / 'recordings.json'
        artifact.parent.mkdir()
        artifact.write_bytes(b'{"immutable":"scientific export"}')
        recipe = {'export_uuid': dataset, 'original_directory': str(root), 'fixture': 'frozen recipe'}
        with connection.cursor() as cursor:
            cursor.execute('CREATE TABLE recording_workspace.dataset_revision (project_uuid varchar(36), dataset_uuid varchar(36), protocol_uuid varchar(36), created_at datetime, actor varchar(255), recipe json, artifact_path varchar(2048), artifact_sha256 char(64), epoch_count int unsigned, PRIMARY KEY(project_uuid,dataset_uuid))')
            cursor.execute('INSERT INTO recording_workspace.dataset_revision VALUES (%s,%s,%s,NOW(),%s,%s,%s,%s,%s)',
                           (identity, dataset, str(uuid.uuid4()), 'fixture', json.dumps(recipe), str(artifact), transfer._hash(artifact), 1))
        return dataset, recipe, artifact.read_bytes()

    def assert_export(self, connection, root, saved):
        dataset, recipe, content = saved
        with connection.cursor() as cursor:
            cursor.execute('SELECT artifact_path, artifact_sha256, recipe FROM recording_workspace.dataset_revision WHERE dataset_uuid=%s', (dataset,))
            location, checksum, stored_recipe = cursor.fetchone()
        path = Path(location)
        # These are the same location + hash constraints used by the download API.
        self.assertTrue(path.is_relative_to(root / 'exports'))
        self.assertEqual(path.read_bytes(), content)
        self.assertEqual(transfer._hash(path), checksum)
        self.assertEqual(json.loads(stored_recipe), recipe)

    def test_plain_closed_project_folder_opens_after_copy_without_a_package(self):
        from workspace_project_database import ensure_project_database
        with tempfile.TemporaryDirectory(prefix='rieke-direct-copy-test-') as temporary:
            base = Path(temporary).resolve()
            project = create_project(base / 'workspace', 'Direct copy fixture')
            root, identity = Path(project['path']), project['uuid']
            catalog = transfer._catalog(identity, str(uuid.uuid4()))
            transfer._write(root / 'catalog.json', catalog)
            transfer._write(root / 'database/service.json', catalog['managed_database'])
            runtimes = [root]
            try:
                ensure_project_database(root)
                recording = root / 'raw-uploads/fixture.h5'
                recording.write_bytes(b'unchanged managed recording')
                metadata = root / 'imports/fixture/metadata.catalog.json'
                transfer._write(metadata, {'fixture': 'metadata'})
                manifest = {'source_sha256': transfer._hash(recording), 'metadata_sha256': transfer._hash(metadata),
                            'source_path': str(recording), 'metadata_path': str(metadata)}
                transfer._write(metadata.parent / 'import-manifest.json', manifest)
                connection = transfer._connection(root)
                try:
                    with connection.cursor() as cursor:
                        cursor.execute('CREATE DATABASE recording_workspace')
                        cursor.execute('CREATE TABLE recording_workspace.project (project_uuid varchar(36) PRIMARY KEY, directory varchar(1024))')
                        cursor.execute('INSERT INTO recording_workspace.project VALUES (%s,%s)', (identity, str(root)))
                        cursor.execute('CREATE TABLE recording_workspace.source (source_sha256 char(64) PRIMARY KEY, project_uuid varchar(36), manifest json)')
                        cursor.execute('INSERT INTO recording_workspace.source VALUES (%s,%s,%s)', (manifest['source_sha256'], identity, json.dumps(manifest)))
                    saved_export = self.save_export(connection, root, identity)
                finally:
                    connection.close()
                transfer._remove_runtime(root)
                copied = base / 'received-project'
                shutil.copytree(root, copied)
                self.assertFalse((copied / transfer.MANIFEST).exists())
                runtimes.append(copied)
                ensure_project_database(copied)
                self.assertTrue(transfer.rebase_project_paths(copied)['relocated'])
                connection = transfer._connection(copied)
                try:
                    self.assert_export(connection, copied, saved_export)
                    saved = transfer._sources(connection, identity)[0]['manifest']
                    self.assertEqual(saved['source_path'], str(copied / 'raw-uploads/fixture.h5'))
                    self.assertEqual(Path(saved['source_path']).read_bytes(), b'unchanged managed recording')
                    self.assertEqual(saved['metadata_path'], str(copied / 'imports/fixture/metadata.catalog.json'))
                finally:
                    connection.close()
                self.assertFalse(transfer.rebase_project_paths(copied)['relocated'])
                # Donor remains separately openable, with its original locators.
                ensure_project_database(root)
                connection = transfer._connection(root)
                try:
                    self.assert_export(connection, root, saved_export)
                    self.assertEqual(transfer._sources(connection, identity)[0]['manifest']['source_path'], str(recording))
                finally:
                    connection.close()
            finally:
                for runtime in runtimes:
                    transfer._remove_runtime(runtime)

    def test_complete_project_survives_fresh_path_and_fresh_runtime(self):
        import h5py
        import numpy as np
        from workspace_project_database import ensure_project_database
        with tempfile.TemporaryDirectory(prefix='rieke-transfer-test-') as temporary:
            base = Path(temporary).resolve()
            project = create_project(base / 'workspace', 'Transfer fixture')
            root, identity = Path(project['path']), project['uuid']
            catalog = transfer._catalog(identity, str(uuid.uuid4()))
            transfer._write(root / 'catalog.json', catalog)
            transfer._write(root / 'database/service.json', catalog['managed_database'])
            runtimes = [root]
            try:
                ensure_project_database(root)
                recording = base / 'external.h5'
                with h5py.File(recording, 'w') as handle:
                    handle.create_dataset('waveform', data=np.array([0.25, -2.0, 3.5]))
                sha = transfer._hash(recording)
                imported = root / 'imports' / sha
                imported.mkdir()
                metadata = imported / 'metadata.catalog.json'
                transfer._write(metadata, {'experiment_uuid': str(uuid.uuid4()), 'fixture': 'metadata'})
                manifest = {'source_sha256': sha, 'source_path': str(recording),
                    'source_size': recording.stat().st_size, 'metadata_path': str(metadata),
                    'metadata_sha256': transfer._hash(metadata)}
                transfer._write(imported / 'import-manifest.json', manifest)
                (root / 'exports' / 'immutable.txt').write_text('frozen export')
                (root / 'protocols' / 'saved.json').write_text('{"saved":"query"}')
                connection = transfer._connection(root)
                try:
                    with connection.cursor() as cursor:
                        cursor.execute('CREATE DATABASE `schema`')
                        cursor.execute('CREATE DATABASE recording_workspace')
                        cursor.execute('CREATE TABLE recording_workspace.project (project_uuid varchar(36) PRIMARY KEY, name varchar(255), directory varchar(1024))')
                        cursor.execute('INSERT INTO recording_workspace.project VALUES (%s,%s,%s)', (identity, 'Transfer fixture', str(root)))
                        cursor.execute('CREATE TABLE recording_workspace.source (source_sha256 char(64) PRIMARY KEY, project_uuid varchar(36), manifest json)')
                        cursor.execute('INSERT INTO recording_workspace.source VALUES (%s,%s,%s)', (sha, identity, json.dumps(manifest)))
                        cursor.execute('CREATE TABLE recording_workspace.saved_state (kind varchar(64), payload json)')
                        for kind, payload in [('annotation', {'text': 'keep me'}), ('query-history', {'version': 1}), ('query-history', {'version': 2})]:
                            cursor.execute('INSERT INTO recording_workspace.saved_state VALUES (%s,%s)', (kind, json.dumps(payload)))
                        cursor.execute('CREATE TABLE `schema`.fixture_epoch (epoch_uuid varchar(36) PRIMARY KEY, source_sha256 char(64))')
                        epoch = str(uuid.uuid4())
                        cursor.execute('INSERT INTO `schema`.fixture_epoch VALUES (%s,%s)', (epoch, sha))
                    saved_export = self.save_export(connection, root, identity)
                finally:
                    connection.close()
                result = transfer.prepare_project(root, base / 'shared-folder')
                self.assertTrue(result['verified'])
                package = Path(result['directory'])
                self.assertFalse((package / 'catalog.json').exists())
                self.assertFalse((package / 'database').exists())
                # Hashes establish integrity, not trust: even correctly resealed
                # packages cannot use SQL to create users or alter MySQL itself.
                malicious = base / 'malicious-package'
                shutil.copytree(package, malicious)
                with (malicious / 'database.sql').open('a') as dump:
                    dump.write("\nCREATE USER 'must_not_exist'@'localhost' IDENTIFIED BY 'bad';\n")
                altered = transfer._json(malicious / transfer.MANIFEST)
                altered['files'] = transfer._files(malicious)
                transfer._write(malicious / transfer.MANIFEST, altered)
                with self.assertRaisesRegex(ValueError, 'database restore failed'):
                    transfer.restore_project(malicious, base / 'rejected-restore')
                self.assertFalse((base / 'rejected-restore').exists())
                # Destroy the donor runtime and external recording before opening.
                transfer._remove_runtime(runtimes.pop())
                recording.unlink()
                results = []
                for index in range(2):
                    restored = transfer.restore_project(package, base / f'new-machine-{index}')
                    results.append(restored)
                    target = Path(restored['directory'])
                    new_catalog = transfer._json(target / 'catalog.json')
                    self.assertEqual(new_catalog['managed_database']['kind'], 'native-mysql')
                    runtimes.append(target)
                    self.assertEqual(restored['project_uuid'], identity)
                    self.assertTrue(restored['verified'])
                    self.assertFalse((target / transfer.PENDING).exists())
                    self.assertEqual((target / 'exports' / 'immutable.txt').read_text(), 'frozen export')
                    ensure_project_database(target)  # Reopening reuses the restored runtime.
                    connection = transfer._connection(target)
                    try:
                        self.assert_export(connection, target, saved_export)
                        source = transfer._sources(connection, identity)[0]['manifest']
                        self.assertTrue(Path(source['source_path']).is_relative_to(target))
                        self.assertTrue(Path(source['metadata_path']).is_relative_to(target))
                        with h5py.File(source['source_path']) as handle:
                            np.testing.assert_array_equal(handle['waveform'][:], [0.25, -2.0, 3.5])
                        with connection.cursor() as cursor:
                            cursor.execute('SELECT COUNT(*) FROM recording_workspace.saved_state')
                            self.assertEqual(cursor.fetchone()[0], 3)
                            cursor.execute('SELECT epoch_uuid FROM `schema`.fixture_epoch')
                            self.assertEqual(cursor.fetchone()[0], epoch)
                            cursor.execute('SELECT directory FROM recording_workspace.project')
                            self.assertEqual(cursor.fetchone()[0], str(target))
                    finally:
                        connection.close()
                self.assertNotEqual(results[0]['instance_uuid'], results[1]['instance_uuid'])
                self.assertNotEqual((runtimes[0] / 'database/native-credentials.json').read_bytes(),
                                    (runtimes[1] / 'database/native-credentials.json').read_bytes())
                self.assertNotEqual(runtimes[0], runtimes[1])
            finally:
                for runtime in runtimes:
                    transfer._remove_runtime(runtime)


if __name__ == '__main__':
    unittest.main()
