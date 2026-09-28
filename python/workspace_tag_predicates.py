"""Explicit protocol-scoped tag predicates; raw acquisition indexes stay immutable."""
from __future__ import annotations
import copy
import contextlib
import hashlib
import uuid
from workspace_predicates import MAX_NODES, validate, matches, predicate_catalog
from workspace_recipes import checksum
from workspace_tree import value_key, value_order, value_label

PREFIX = 'curation/'


def referenced_fields(predicate):
    """Bounded discovery only; the regular validator checks the full AST."""
    result=set();pending=[predicate];visited=0
    while pending and visited<=MAX_NODES:
        node=pending.pop();visited+=1
        if not isinstance(node,dict): continue
        key=node.get('field')
        if isinstance(key,str) and key.startswith(PREFIX): result.add(key)
        if 'not' in node: pending.append(node['not'])
        for logic in ('all','any'):
            if isinstance(node.get(logic),list): pending.extend(node[logic][:MAX_NODES+1])
    return result


@contextlib.contextmanager
def annotation_locks(service, predicate, extra_protocols=()):
    """Serialize annotation evidence with curation writes across processes.

    Include destination protocols before entering so every multi-scope operation
    acquires locks in the same order. The caller owns its SQL transaction.
    """
    definitions={field['id']:field for field in TagPredicates(service).definitions()}
    fields=referenced_fields(predicate)
    if fields-definitions.keys():
        raise ValueError('Choose tags from a protocol workspace in this project')
    protocols={definitions[field]['annotation_scope']['protocol_uuid'] for field in fields}
    for identity in extra_protocols:
        if not isinstance(identity,str): raise ValueError('Expected protocol UUID for annotation lock')
        protocols.add(str(uuid.UUID(identity)))
    if not protocols:
        yield
        return
    connection=service.dj.conn();acquired=[]
    try:
        for protocol in sorted(protocols):
            lock=hashlib.sha256((service.project['project_uuid']+protocol).encode()).hexdigest()
            if connection.query(f"SELECT GET_LOCK('{lock}', 10)").fetchone()[0]!=1:
                raise RuntimeError('Another protocol annotation update is running; retry shortly')
            acquired.append(lock)
        yield
    finally:
        for lock in reversed(acquired):
            with contextlib.suppress(Exception):
                connection.query(f"SELECT RELEASE_LOCK('{lock}')")


class TagPredicates:
    def __init__(self,service): self.service=service

    def definitions(self):
        if not getattr(self.service,'annotation_provider',None): return []
        return [dict(id=f'curation/{identity}/tags',label='Tags · '+entry['definition']['name'],
                     path=f'curation.{identity}.tags',category='Protocol tags',
                     annotation_scope={'kind':'protocol_curation','protocol_uuid':identity},
                     description='Tags recorded in this protocol workspace only; imported keywords are separate. Untagged epochs have an empty array.')
                for identity,entry in sorted(self.service.protocols.items())]

    def snapshot(self,fields):
        definitions={field['id']:field for field in self.definitions()}
        if fields-definitions.keys(): raise ValueError('Choose tags from a protocol workspace in this project')
        protocols=[];states={}
        fingerprints=self.service._fingerprints
        universe=checksum(sorted(fingerprints))
        for field in sorted(fields):
            protocol=definitions[field]['annotation_scope']['protocol_uuid']
            current=self.service.annotation_provider(protocol,dict(fingerprints))
            if not isinstance(current,dict) or current.keys()-fingerprints.keys():
                raise ValueError('Protocol tag provider returned an invalid epoch scope')
            records=[];values={}
            for identity in fingerprints:
                state=current.get(identity,{})
                tags=state.get('tags',[]);revision=state.get('revision',0)
                if (not isinstance(tags,list) or any(not isinstance(tag,str) or not tag or tag!=tag.strip() or len(tag)>255 for tag in tags)
                        or len(set(tags))!=len(tags) or type(revision) is not int or revision<0):
                    raise ValueError('Invalid saved protocol tag annotation')
                tags=sorted(tags)
                if tags: values[identity]=tags
                if revision or tags: records.append(dict(epoch_uuid=identity,revision=revision,tags=tags))
            records.sort(key=lambda row:row['epoch_uuid'])
            revision=checksum({'registered_epoch_universe':universe,'records':records})
            protocols.append(dict(protocol_uuid=protocol,field=field,revision=revision,records=records))
            states[field]=values
        return states,{'version':1,'revision':checksum([(p['protocol_uuid'],p['revision']) for p in protocols]),'protocols':protocols}

    def catalog_fields(self,ids):
        definitions=self.definitions()
        if not definitions: return []
        states,_=self.snapshot({field['id'] for field in definitions})
        fields=[]
        for definition in definitions:
            key=definition['id'];values={identity:{key:states[key].get(identity,[])} for identity in ids}
            distinct={value_key(current[key]):current[key] for current in values.values()}
            examples=[value_label(value)[:160] for value in sorted(distinct.values(),key=value_order)[:5]]
            field={**definition,'count':len(ids),'distinct_count':len(distinct),'recorded_distinct_count':len(distinct),
                   'missing_count':0,'null_count':0,'varying':len(distinct)>1,'examples':examples,
                   'grouping_role':'annotation','grouping_priority':100,'varies_within_cell':False,
                   'suggested_rank':None,'suggestion_reason':'','high_cardinality':len(distinct)>24}
            field=predicate_catalog({'fields':[field]},values)['fields'][0]
            field.update(active_types=field['types'],types=['array'],types_scope='protocol_annotations',element_types=['string'])
            fields.append(field)
        return fields

    def match(self,predicate,ids):
        fields=referenced_fields(predicate)
        if not fields:
            validated,matched=self.service._match_metadata_predicate(predicate,ids)
            return validated,matched,None
        states,evidence=self.snapshot(fields)
        registered,_=self.service._registered_tree_fields()
        definitions=[field for field in registered['fields'] if not field['id'].startswith('joint/')]+self.definitions()
        # This pass enforces the entire AST's limits/shape and tag literal types.
        # Raw metadata subtrees below retain their exact registered-type validator.
        validated=validate(predicate,{'fields':definitions},{field:{field:['']} for field in fields})
        universe=set(ids)
        def walk(node):
            if not referenced_fields(node):
                return set(self.service._match_metadata_predicate(node,ids)[1])
            if 'all' in node:
                result=set(universe)
                for child in node['all']: result.intersection_update(walk(child))
                return result
            if 'any' in node:
                result=set()
                for child in node['any']: result.update(walk(child))
                return result
            if 'not' in node: return universe-walk(node['not'])
            key=node['field']
            return {identity for identity in ids if matches(node,{key:states[key].get(identity,[])})}
        matched=walk(validated)
        return validated,[identity for identity in ids if identity in matched],copy.deepcopy(evidence)
