import {useEffect,useMemo,useState} from 'react';
import {ChevronDown,ChevronRight,Check,X,Tag} from 'lucide-react';
import {humanize} from '../api.js';
import {epochSkimGroups} from '../epochSkimGroups.js';

export default function EpochSkimList({epochs,offset,focused,onFocus,targets=[],setTargets,disabled,showProtocol=false,selectable=true}){
  const groups=useMemo(()=>epochSkimGroups(epochs,offset),[epochs,offset]);
  const [collapsed,setCollapsed]=useState(new Set());
  useEffect(()=>{const group=groups.find(g=>g.epochs.some(item=>item.epoch.epoch_uuid===focused));if(group)setCollapsed(old=>{if(!old.has(group.key))return old;const next=new Set(old);next.delete(group.key);return next;});},[focused,groups]);
  return <div className="epoch-skim-list">{groups.map(group=><section key={group.key} className="epoch-skim-cell">
    <button className="epoch-skim-heading" aria-expanded={!collapsed.has(group.key)} onClick={()=>setCollapsed(old=>{const next=new Set(old);if(next.has(group.key))next.delete(group.key);else next.add(group.key);return next;})}>
      {collapsed.has(group.key)?<ChevronRight size={13}/>:<ChevronDown size={13}/>}<span>{group.date}</span><strong>{group.label}</strong>
    </button>
    {!collapsed.has(group.key)&&group.epochs.map(({epoch:e,position})=><div key={e.epoch_uuid} className={`epoch-row epoch-skim-row ${focused===e.epoch_uuid?'active':''}`}>
      {selectable&&<input type="checkbox" disabled={disabled} aria-label={`Select ${group.date} ${group.label} epoch ${position} for bulk action`} checked={targets.includes(e.epoch_uuid)} onChange={event=>setTargets(old=>event.target.checked?[...old,e.epoch_uuid]:old.filter(uuid=>uuid!==e.epoch_uuid))}/>}
      <button disabled={disabled} aria-current={focused===e.epoch_uuid?'true':undefined} onClick={()=>onFocus(e.epoch_uuid)} aria-label={`Inspect ${group.date} ${group.label} epoch ${position}`} title={`Epoch UUID: ${e.epoch_uuid}\nEpoch ${e.epoch_number ?? 'unknown'} within block`}>
        <span className="skim-position">{showProtocol?(e.epoch_number??position):position}</span><time>{e.start_time?.split(/[T ]/)[1]?.slice(0,8)||'Time not recorded'}</time>
        {showProtocol&&<span className="skim-protocol" title={e.protocol_name}>{humanize(e.protocol_name?.split('.').at(-1))}</span>}
        {selectable&&<span className={`skim-inclusion ${e.curation?.included===false?'excluded':''}`} title={e.curation?.included===false?'Excluded from export':'Included in export'}>{e.curation?.included===false?<X size={12}/>:<Check size={12}/>}</span>}
        {!!e.curation?.tags?.length&&<span className="skim-tag-count" title={e.curation.tags.join(', ')}><Tag size={11}/>{e.curation.tags.length}</span>}
      </button>
    </div>)}
  </section>)}</div>;
}
