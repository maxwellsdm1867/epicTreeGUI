"""Installation status and offline transfer jobs shared by chooser and projects."""
from pathlib import Path
import os
import secrets
import threading
import uuid
from flask import jsonify, request


def register_app_routes(app, *, application_dir=None):
    root = Path(application_dir or Path(__file__).resolve().parents[1]).resolve()
    jobs = {}
    lock = threading.Lock()
    update_token = secrets.token_urlsafe(32)
    update_job = {'state': 'idle'}

    def update_payload(value):
        return {**value, 'update_token': update_token, 'download': dict(update_job)}

    def local_request():
        if (request.remote_addr not in {'127.0.0.1', '::1'}
                or request.host.split(':', 1)[0] not in {'127.0.0.1', 'localhost'}):
            return jsonify(error='App operations require a local connection.'), 403
        if request.method == 'POST':
            if (request.headers.get('X-Workspace-Request') != '1'
                    or request.headers.get('Origin', request.host_url.rstrip('/')) != request.host_url.rstrip('/')):
                return jsonify(error='App operations require a same-origin workspace request.'), 403

    @app.before_request
    def app_operation_boundary():
        if request.path.startswith(('/api/app/', '/api/projects/transfers/',
                                    '/api/projects/prepare-transfer', '/api/projects/restore-transfer')):
            return local_request()

    @app.get('/api/app/updates')
    def update_status():
        from workspace_updates import installation_status
        return jsonify(update_payload(installation_status(root=root)))

    @app.post('/api/app/updates/check')
    def check_updates():
        body = request.get_json(silent=True)
        if request.args or body not in ({}, {'force': True}):
            return jsonify(error='Update check accepts an empty object or force: true.'), 400
        from workspace_updates import check_for_updates
        return jsonify(update_payload(check_for_updates(root=root, force=bool(body.get('force')))))

    @app.post('/api/app/updates/stage')
    def stage_update():
        if (request.args or request.get_json(silent=True) != {}
                or not secrets.compare_digest(request.headers.get('X-Rieke-Update-Token', ''), update_token)):
            return jsonify(error='Reopen the updates panel before downloading an update.'), 403
        from workspace_updates import installation_status, stage_release
        if not installation_status(root=root).get('can_stage') or not os.environ.get('RIEKE_INSTALLATION_ROOT'):
            return jsonify(error='Verified downloads require a managed installation with a trusted release key.'), 409
        with lock:
            if update_job['state'] == 'running':
                return jsonify(error='An update download is already running.'), 409
            update_job.clear()
            update_job['state'] = 'running'
        def run():
            try:
                result = stage_release(os.environ['RIEKE_INSTALLATION_ROOT'], root=root)
                with lock:
                    update_job.update(state='complete', result=result)
            except Exception as error:
                app.logger.exception('Update staging failed')
                with lock:
                    update_job.update(state='failed', error=str(error) if isinstance(error, ValueError) else 'Update download failed. Check the launcher log; the active release was not changed.')
        threading.Thread(target=run, name='rieke-update-download', daemon=False).start()
        return jsonify(state='running'), 202

    @app.get('/api/app/updates/download')
    def update_download():
        with lock:
            return jsonify(update_job)

    def transfer(operation):
        body = request.get_json(silent=True)
        if (request.args or not isinstance(body, dict) or set(body) != {'directory', 'destination'}
                or any(not isinstance(value, str) or not value.strip() or not Path(value).expanduser().is_absolute()
                       for value in body.values())):
            return jsonify(error='Choose absolute source and destination folder paths.'), 400
        with lock:
            if any(job['state'] == 'running' for job in jobs.values()):
                return jsonify(error='A project transfer is already running. Wait for it to finish.'), 409
            # Bound local job history without losing the current operation.
            while len(jobs) >= 30:
                del jobs[next(iter(jobs))]
            identity = str(uuid.uuid4())
            jobs[identity] = {'job_id': identity, 'state': 'running'}

        def run():
            try:
                from workspace_portability import prepare_project, restore_project
                function = prepare_project if operation == 'prepare' else restore_project
                result = function(body['directory'].strip(), body['destination'].strip())
                with lock:
                    jobs[identity] = {'job_id': identity, 'state': 'complete', 'result': result}
            except Exception as error:
                app.logger.exception('Project transfer failed')
                message = str(error) if isinstance(error, (ValueError, FileNotFoundError)) else 'Project transfer failed. Check the launcher log; no success was recorded.'
                with lock:
                    jobs[identity] = {'job_id': identity, 'state': 'failed', 'error': message}
        # A normal process shutdown waits for a transfer rather than killing its writer.
        threading.Thread(target=run, name='rieke-project-transfer', daemon=False).start()
        return jsonify(job_id=identity, state='running'), 202

    @app.post('/api/projects/prepare-transfer')
    def prepare_transfer():
        return transfer('prepare')

    @app.post('/api/projects/restore-transfer')
    def restore_transfer():
        return transfer('restore')

    @app.get('/api/projects/transfers/<identity>')
    def transfer_status(identity):
        with lock:
            job = jobs.get(identity)
            if job is None:
                return jsonify(error='Transfer status is unavailable. Inspect the destination before retrying.'), 404
            return jsonify(job)
