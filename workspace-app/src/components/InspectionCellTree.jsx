import {useEffect,useMemo,useRef,useState} from 'react';
import EpochInclusionToggle from './EpochInclusionToggle.jsx';
import {api,humanize,number} from '../api.js';
import {epochPageRequest} from '../epochBrowserSource.js';
import {epochSelectionRange,toggleEpochSelection,mergeEpochSelection} from '../epochSelection.js';
import {inspectionDates} from '../inspectionCellTree.js';
import {datedCellLabel} from '../recordingIdentity.js';
import {Status} from './Common.jsx';
import './InspectionCellTree.css';
import {useEpochBrowserPage} from '../useEpochBrowserPage.js';

function CellEpochs({cell,source,revision,focused,onFocus,targets,onSelect,disabled,onToggleInclusion,inclusionForEpoch}){
  const [offset,setOffset]=useState(0);
  const page=useEpochBrowserPage(source,{cellUuid:cell.cell_uuid,offset},revision);
  return <Status {...page} retry={page.reload}>
    {(page.data?.epochs||[]).map((record,index)=>{const epoch=inclusionForEpoch?inclusionForEpoch(record):record;return <div key={epoch.epoch_uuid} className={`epoch-row cell-tree-epoch ${focused===epoch.epoch_uuid?'active':''} ${targets.includes(epoch.epoch_uuid)?'bulk-selected':''} ${epoch.curation?.included===false?'analysis-excluded':''}`}>
      <button disabled={disabled||page.loading} aria-current={focused===epoch.epoch_uuid?'true':undefined} aria-pressed={targets.includes(epoch.epoch_uuid)||(!targets.length&&focused===epoch.epoch_uuid)} onMouseDown={event=>{if(event.shiftKey)event.preventDefault();}} onClick={event=>onSelect(event,{cellUuid:cell.cell_uuid,index:offset+index,uuid:epoch.epoch_uuid},epoch,page.data)} aria-label={`Inspect ${datedCellLabel(cell,true)} epoch ${offset+index+1}`}>
        <strong>{offset+index+1}</strong>
        <time>{epoch.start_time?.split(/[T ]/)[1]?.slice(0,8)||'—'}</time>
        <span className="epoch-short-protocol" title={humanize(epoch.protocol_name?.split('.').at(-1))}>{humanize(epoch.protocol_name?.split('.').at(-1))||'—'}</span>


      </button>
      {onToggleInclusion&&<EpochInclusionToggle epoch={epoch} label={`${datedCellLabel(cell,true)} epoch ${offset+index+1}`} disabled={disabled||page.loading} onToggle={onToggleInclusion}/>}
    </div>;})}
    {page.data&&<div className="pagination"><button aria-label={`Previous epochs for ${datedCellLabel(cell,true)}`} disabled={disabled||page.loading||!offset} onClick={()=>setOffset(Math.max(0,offset-60))}>Previous</button><span>{page.data.total?offset+1:0}–{Math.min(offset+60,page.data.total)} of {number(page.data.total)}</span><button aria-label={`Next epochs for ${datedCellLabel(cell,true)}`} disabled={disabled||page.loading||offset+60>=page.data.total} onClick={()=>setOffset(offset+60)}>Next</button></div>}
  </Status>;
}
function CellBranch({cell,dateOpen,onSelectCell,selectedCell,collapseRequest,...props}){
  const [open,setOpen]=useState(false);
  useEffect(()=>setOpen(false),[collapseRequest]);
  return <details className="cell-tree-cell" open={open} onToggle={event=>setOpen(event.currentTarget.open)}>
    <summary className={selectedCell===cell.cell_uuid?'selected-cell':''} onClick={()=>onSelectCell(cell)}><strong>{cell.label||cell.cell_label||'Unlabeled cell'}</strong></summary>
    {dateOpen&&open&&<CellEpochs cell={cell} {...props}/>}
  </details>;
}
function DateBranch({group,collapseRequest,...props}){
  const [open,setOpen]=useState(false);
  useEffect(()=>setOpen(false),[collapseRequest]);
  return <details className="cell-tree-date" open={open} onToggle={event=>setOpen(event.currentTarget.open)}>
    <summary><strong>{group.date}</strong></summary>
    {group.cells.map(cell=><CellBranch collapseRequest={collapseRequest} key={cell.cell_uuid} cell={cell} dateOpen={open} {...props}/>)}
  </details>;
}
export default function InspectionCellTree({cells,targets,setTargets,disabled,onFocus,onSelectCell,...props}){
  const dates=useMemo(()=>inspectionDates(cells),[cells]);
  const ordered=dates.flatMap(group=>group.cells),anchor=useRef(null),request=useRef(null),selected=useRef(targets);selected.current=targets;
  const [selecting,setSelecting]=useState(false),[error,setError]=useState('');
  const scope=JSON.stringify(props.source);
  useEffect(()=>{anchor.current=null;request.current?.abort();setSelecting(false);return()=>request.current?.abort();},[scope]);

  async function selectCell(cell){
    if(disabled||selecting)return;
    anchor.current=null;setError('');setSelecting(true);
    const controller=new AbortController();request.current=controller;
    try{
      const {path,options}=epochPageRequest(props.source,{cellUuid:cell.cell_uuid,offset:0});
      const page=await api(path,{...options,signal:controller.signal});
      if(!controller.signal.aborted&&page.epochs?.[0])onSelectCell?.(cell,page.epochs[0]);
    }catch(error){if(error.name!=='AbortError')setError(error.message);}
    finally{setSelecting(false);}
  }
  async function select(event,target,epoch,page){
    if(disabled||selecting)return;
    const shift=event.shiftKey,multiple=event.metaKey||event.ctrlKey;
    setError('');
    onFocus(target.uuid,epoch);
    if(!multiple&&!shift)setTargets([]);
    try{
      if(shift&&anchor.current){
        const controller=new AbortController();request.current=controller;setSelecting(true);
        const before=JSON.stringify(targets);
        const ids=await epochSelectionRange({cells:ordered,anchor:anchor.current,target,loadPage:async(cellUuid,offset)=>{
          if(cellUuid===target.cellUuid&&offset===page.offset)return page;
          const {path,options}=epochPageRequest(props.source,{cellUuid,offset});return api(path,{...options,signal:controller.signal});
        }});
        if(controller.signal.aborted)return;
        if(JSON.stringify(selected.current)!==before)throw new Error('Selection changed while loading. Select the range again.');
        setTargets(mergeEpochSelection(selected.current,ids));
      }else{
        anchor.current=target;
        if(multiple||shift)setTargets(toggleEpochSelection(targets,target.uuid));
      }
    }catch(error){if(error.name!=='AbortError')setError(error.message);}
    finally{setSelecting(false);}
  }
  return <div className="inspection-cell-tree" aria-label="All matching dates, cells and epochs" title="⌘/Ctrl-click to select epochs; Shift-click for a range">{error&&<p role="alert">{error}</p>}{selecting&&<p role="status">Selecting epoch range…</p>}{!dates.length&&<p role="status">No epochs match the current filters.</p>}{dates.map(group=><DateBranch key={group.date} group={group} {...props} targets={targets} onFocus={onFocus} onSelectCell={selectCell} onSelect={select} disabled={disabled||selecting}/>)}</div>;
}
