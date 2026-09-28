"""Bounded chronological inspection pages for an exact source-predicate preview."""
import re
import uuid
from flask import jsonify
from workspace_tree_pages import TreePages, _chronology


def register_matching_epoch_routes(app, service, db_lock, registration_locks, read_request):
    @app.post('/api/explore/epochs')
    def matching_epochs():
        body = read_request({'predicate','splits','offset','limit','revision','anchor_uuid'}, {'predicate','splits','revision'})
        expected = body['revision']
        if not isinstance(expected,str) or not re.fullmatch('[0-9a-f]{64}',expected):
            raise ValueError('Matching epoch pages require a verified preview revision')
        limit, offset = body.get('limit',60), body.get('offset',0)
        if type(limit) is not int or not 1 <= limit <= 100 or type(offset) is not int or not 0 <= offset <= 10_000_000:
            raise ValueError('Matching epoch pages require limit 1–100 and a bounded offset')
        anchor = body.get('anchor_uuid')
        if anchor is not None:
            if not isinstance(anchor,str) or offset:
                raise ValueError('Epoch locator requires a UUID and no offset')
            anchor = str(uuid.UUID(anchor))
        with db_lock, registration_locks():
            rows, _, _, _, _, revision = TreePages(service)._scope({'predicate':body['predicate'],'splits':body['splits']})
            if expected != revision:
                return jsonify(error='Predicate results changed. Refresh the preview before inspecting or exporting.'), 409
            rows = sorted(rows,key=_chronology)
            anchor_index = None
            if anchor:
                anchor_index = next((index for index,row in enumerate(rows) if row['epoch_uuid']==anchor),None)
                if anchor_index is None:
                    raise ValueError('Epoch is outside this predicate')
                offset = anchor_index // limit * limit
            keys = ('epoch_uuid','cell_uuid','cell_label','cell_type','date','start_time','block_uuid','epoch_number','protocol_name','duration_seconds')
            return jsonify(epochs=[{key:row.get(key) for key in keys} for row in rows[offset:offset+limit]],
                           offset=offset,limit=limit,total=len(rows),has_more=offset+limit<len(rows),
                           revision=revision,anchor_index=anchor_index,anchor_uuid=anchor)
