import {SourceEligibilityNotice} from './Common.jsx';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ChevronDown, ChevronRight, GitBranch, Check, X, Tag, ArrowLeft, ArrowRight, Activity, Eye, Info, PanelRightClose, PanelRightOpen, Upload, Download, FileJson } from 'lucide-react';
import { api, useResource, number, humanize, resolveCurationTargets } from '../api.js';
import { Status, Metadata, Badge, Empty } from './Common.jsx';
import EpochConnections from './EpochConnections.jsx';
import TreeBuilder from './TreeBuilder.jsx';
import TreePreview from './TreePreview.jsx';
import './InspectorPolish.css';
import './MatlabMaskImport.css';
import MetadataPanel from './MetadataPanel.jsx';
import EpochSkimList from './EpochSkimList.jsx';
import EpochTags from './EpochTags.jsx';
import './Inspector.css';

import {inspectionSearches,indexInspectionTree,focusAfterTreeSelection,curationMatchesCellFocus} from '../inspectionScope.js';
import {branchLabel,branchTooltip,componentLabel,componentValue,epochLeafLabel,readableField} from '../treeBranchPresentation.js';
import {datedCellLabel} from '../recordingIdentity.js';
import {restoredEpochFocus} from '../workspaceNavigation.js';
import {boundedTreePage,inspectionTreeFocus} from '../boundedTree.js';
import Trace from './TraceViewer.jsx';
import PaneDivider from './PaneDivider.jsx';
import PagedTree from './PagedTree.jsx';
import {inspectorPaneSizes,epochArrowDirection,nextEpochAction,resourceForPath} from '../inspectorInteraction.js';
export {Trace};

function TreePageControls({page,onPage,kind}){
  if(page.total<=60&&!page.pinnedOutside)return null;
  return <div className="tree-page-controls"><div><button disabled={!page.hasPrevious} onClick={()=>onPage(page.offset-60)} aria-label={`Previous ${kind}`}><ArrowLeft size={12}/></button><span>{page.total?page.offset+1:0}–{page.end} of {number(page.total)} {kind}</span><button disabled={!page.hasNext} onClick={()=>onPage(page.offset+60)} aria-label={`Next ${kind}`}><ArrowRight size={12}/></button></div>{page.pinnedOutside&&<small>Focused item also shown below this page.</small>}</div>;
}
export function Branch({node,onFocus,selected,depth=0,cellBranches=null,parentField=null,treeFocus}) {
  const selectedBranch=treeFocus?.branches.has(node) || false;
  const [open,setOpen] = useState(selectedBranch);
  const [offset,setOffset] = useState(0);
  const inFocusedCell=cellBranches?.has(node) || false;
  useEffect(()=>{if(selectedBranch)setOpen(true);},[selectedBranch]);
  const children = node.children || [];
  // Legacy UUID-only leaves are converted only for the visible page.
  const leafValues=node.epochs || node.epoch_uuids || [];
  const pin=children.length?treeFocus?.childOf.get(node):selectedBranch?(node.epochs?treeFocus?.epoch:selected):null;
  const page=boundedTreePage(children.length?children:leafValues,offset,60,pin);
  return <div className={`tree-branch ${inFocusedCell?'cell-focus-branch':''}`}>
    <button className="branch-label" onClick={()=>setOpen(!open)} aria-expanded={open} title={branchTooltip(node,parentField)}>
      {open?<ChevronDown size={13}/>:<ChevronRight size={13}/>}
      <span className={node.components?.length?'branch-combination':''}>{node.components?.length?node.components.map(part=><span className="branch-component" key={part.field}><small title={part.field}>{componentLabel(part)}</small><span>{componentValue(part)}</span></span>):branchLabel(node,parentField)}</span>
      <small>{node.count ?? node.epoch_count ?? leafValues.length}</small>
    </button>
    {open && <div className="branch-children">
      {children.length>0&&node.field_label&&<div className="branch-field-label" title={node.field}>{readableField(node.field_label,node.field)}</div>}
      <TreePageControls page={page} onPage={setOffset} kind={children.length?'groups':'epochs'}/>
      {children.length?page.items.map(n=><Branch key={n.key ?? JSON.stringify([n.missing===true,n.value])} node={n} onFocus={onFocus} selected={selected} depth={depth+1} cellBranches={cellBranches} parentField={node.field} treeFocus={treeFocus}/>):page.items.map(item=>{
        const e=typeof item==='string'?{epoch_uuid:item}:item;
        return <button className={`epoch-leaf ${selected===e.epoch_uuid?'selected':''}`} key={e.epoch_uuid} onClick={()=>onFocus(e.epoch_uuid)} title={`${e.start_time || ''} · ${e.epoch_uuid}`}>
          <Activity size={12}/><span>{e.cell_label&&<small>{datedCellLabel(e)} · </small>}{epochLeafLabel(e)}</span>
        </button>;
      })}
    </div>}
  </div>;
}
function InspectionTree({tree,onFocus,selected,cellBranches,treeFocus}){
  const [offset,setOffset]=useState(0);
  const nodes=tree.children?.length?tree.children:tree.tree?.children?.length?tree.tree.children:tree.groups?.length?tree.groups:(tree.epochs||tree.epoch_uuids?[tree]:[]);
  const pin=nodes.length===1&&nodes[0]===tree?tree:treeFocus?.childOf.get(tree);
  const page=boundedTreePage(nodes,offset,60,pin);
  return <><TreePageControls page={page} onPage={setOffset} kind="top-level groups"/>{page.items.map(node=><Branch key={node.key ?? JSON.stringify([node.missing===true,node.value])} node={node} onFocus={onFocus} selected={selected} cellBranches={cellBranches} parentField={tree.field} treeFocus={treeFocus}/>)}</>;
}

function recordedValue(value) {
  if (value === undefined || value === null) return 'Not recorded';
  if (value === '[]' || (Array.isArray(value) && value.length === 0)) return '[] (empty recorded field)';
  return typeof value === 'object' ? JSON.stringify(value) : String(value);
}
function ScientificContext({epoch}) {
  const additions = epoch.metadata?.group?.properties?.externalSolutionAdditions;
  const historyProtocol=/VariableHistoryNoiseCurInject/.test(epoch.protocol_name || '');
  const controlFlag=Object.hasOwn(epoch.parameters || {},'isControl')?epoch.parameters.isControl:epoch.parameters?.controlMode;
  const historyControl=historyProtocol&&[1,true].includes(controlFlag);
  const historyPairs=historyProtocol?['history1','history2','target'].filter(key=>Array.isArray(epoch.parameters?.[key])&&epoch.parameters[key].length===2):[];
  const conditions = [
    ['currentMean','Current mean',''],
    ['currentSD','Current SD',''],
    ['frequencyCutoff','Frequency cutoff',''],
    ['stimTime','Stimulus duration',''],
  ].filter(([key])=>epoch.parameters?.[key] !== undefined && epoch.parameters[key] !== null);
  return <section className="scientific-context" aria-label="Recording and condition context">
    <div className="context-inline"><strong>{humanize(epoch.cell_type) || 'Type not recorded'}</strong><span>{epoch.source_filename || 'Source not recorded'}</span></div>
    <div className="context-inline"><span>Group label: <strong>{recordedValue(epoch.group_label)}</strong></span><span>External additions: <strong>{recordedValue(additions)}</strong></span></div>
    {historyControl&&<p className="history-control-note">Control epoch · target only; history settings were recorded but not delivered.</p>}
    {historyPairs.length>0&&<div className="history-pair-facts">{historyPairs.map(key=><div key={key}><span>{key==='target'?'Target':key==='history1'?'History 1':'History 2'}{historyControl&&key!=='target'?' · configured only':''}</span><strong>{recordedValue(epoch.parameters[key][0])} / {recordedValue(epoch.parameters[key][1])}</strong><small>Recorded mean / SD</small></div>)}</div>}
    {conditions.length>0&&<div className="condition-facts">{conditions.map(([key,label,units])=><div key={key}>
      <span>{label}</span><strong>{recordedValue(epoch.parameters[key])}{units && ` ${units}`}</strong>
    </div>)}</div>}
    <details className="context-timing"><summary>Block {epoch.block_start_time?.split(' ')[1] || 'time not recorded'} · acquisition details</summary><div className="context-facts">
      <div><span>Epoch block started</span><strong>{recordedValue(epoch.block_start_time)}</strong></div>
      <div><span>Epoch block ended</span><strong>{recordedValue(epoch.block_end_time)}</strong></div>
      <div className="context-protocol"><span>Acquisition protocol · source value</span><strong>{recordedValue(epoch.protocol_name)}</strong></div>
    </div><p className="source-note">Group labels and solution fields are separate source records. Empty fields do not establish control or wash.</p></details>
  </section>;
}

export default function Inspector({protocol,initialEpochUuid=null,cellScope,filters,revision,onChange,onBack,onImport,onStores,onExport,splitRecipe=['date','cell','block'],onSplitChange,initialNavigation=null,onSessionChange,onQC}) {
  const id=protocol.definition.protocol_uuid;
  const requestedCellFocus=filters?.cell_uuid&&filters.cell_uuid!==cellScope?null:(cellScope || null);
  const [focusCell,setFocusCell]=useState(initialNavigation&&Object.hasOwn(initialNavigation,'focusCell')?initialNavigation.focusCell:requestedCellFocus);
  const [offset,setOffset]=useState(initialNavigation?.offset || 0), [focused,setFocused]=useState(()=>restoredEpochFocus(initialNavigation,initialEpochUuid)), [targets,setTargets]=useState([]);
  const [tagFocus,setTagFocus]=useState(0);
  const [tag,setTag]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('');
  const [operationMessage,setOperationMessage]=useState(''),[maskMessage,setMaskMessage]=useState('');
  const maskInput=useRef(null),matlabMaskInput=useRef(null);
  const [matlabMaskFile,setMatlabMaskFile]=useState(null),[matlabDataset,setMatlabDataset]=useState(''),[matchingExports,setMatchingExports]=useState([]);
  const [pendingNavigation,setPendingNavigation]=useState(null);
  const externalSplitKey=splitRecipe.join(',');
  const previousExternalSplit=useRef(externalSplitKey);
  const [splits,setSplits]=useState(externalSplitKey);
  const [masksOpen,setMasksOpen]=useState(false);
  const [metadataOpen,setMetadataOpen]=useState(()=>{try{const saved=localStorage.getItem('workspace.inspector.metadata');return saved===null?window.innerWidth>=1350:saved==='true';}catch{return true;}});
  function toggleMetadata(next){setMetadataOpen(next);try{localStorage.setItem('workspace.inspector.metadata',String(next));}catch{}}
  const matlabExports=useResource(masksOpen?`/exports?protocol_uuid=${id}`:null,revision);
  useEffect(()=>{setMatlabMaskFile(null);setMatlabDataset('');setMatchingExports([]);},[id]);
  const matchingMatlabExports=[...new Map([...(matlabExports.data?.exports || []).filter(item=>item.format==='epictree-mat'&&item.protocol_uuid===id&&item.status==='completed'),...matchingExports].map(item=>[item.dataset_uuid,item])).values()];
  const [designMode,setDesignMode]=useState(initialNavigation?.designMode || false),[designPath,setDesignPath]=useState(initialNavigation?.designPath || []);
  const [designNavigation,setDesignNavigation]=useState(initialNavigation?.designNavigation||null);
  const changeSplits=useCallback(fields=>{setSplits(fields.join(','));setDesignPath([]);setDesignNavigation(null);},[]);
  const [treeOpen,setTreeOpen]=useState(initialNavigation?.treeOpen ?? true),[treeMode,setTreeMode]=useState(initialNavigation?.treeMode ?? false);
  const {protocol:protocolSearch,navigation:search}=inspectionSearches(filters,focusCell);
  const rowsPath=`/protocols/${id}/epochs?${search}&${pendingNavigation?.anchorUuid?`anchor_uuid=${encodeURIComponent(pendingNavigation.anchorUuid)}`:`offset=${offset}`}&limit=60`;
  const loadedRows=useResource(rowsPath,revision);
  const rows=resourceForPath(loadedRows,rowsPath);
  const [treePage,setTreePage]=useState(null);
  const [treeStatus,setTreeStatus]=useState({loading:true,error:null});
  const tree={data:treePage,...treeStatus};
  const receiveTree=useCallback(data=>setTreePage(data),[]);
  useEffect(()=>setTreePage(null),[id,protocolSearch,splits,revision]);
  const layoutRef=useRef(null),[layoutWidth,setLayoutWidth]=useState(1100);
  const [paneWidths,setPaneWidths]=useState(()=>{try{return JSON.parse(localStorage.getItem('workspace.inspector.paneWidths')||'{}');}catch{return {};}});
  const paneSizes=inspectorPaneSizes(layoutWidth,paneWidths||{},treeOpen,!designMode&&metadataOpen);
  const changePane=(key,value)=>setPaneWidths(old=>({...old,[key]:value}));
  const savePane=(key,value)=>{setPaneWidths(old=>{const next={...old,[key]:value};try{localStorage.setItem('workspace.inspector.paneWidths',JSON.stringify(next));}catch{}return next;});};
  useEffect(()=>{const element=layoutRef.current;if(!element)return;const observer=new ResizeObserver(entries=>setLayoutWidth(entries[0].contentRect.width));observer.observe(element);return()=>observer.disconnect();},[]);
  const epoch=useResource(focused?`/epochs/${focused}?protocol_uuid=${id}`:null,revision);
  const focusedEpoch=epoch.data?.epoch_uuid===focused?epoch.data:null;
  const metadataCatalog=useResource(metadataOpen&&!designMode?`/protocols/${id}/tree-fields?${protocolSearch}`:null,revision);
  const scopeIdentity=JSON.stringify([id,requestedCellFocus,protocolSearch,initialEpochUuid]);
  const previousScope=useRef(scopeIdentity);
  useEffect(()=>{if(previousScope.current===scopeIdentity)return;previousScope.current=scopeIdentity;setFocusCell(requestedCellFocus);setOffset(0);setFocused(initialEpochUuid);setTargets([]);setPendingNavigation(null);setDesignNavigation(null);},[scopeIdentity,id,requestedCellFocus,protocolSearch,initialEpochUuid]);
  useEffect(()=>{onSessionChange?.({focused,focusCell,offset,treeOpen,treeMode,designMode,designPath,designNavigation});},[focused,focusCell,offset,treeOpen,treeMode,designMode,designPath,designNavigation,onSessionChange]);

  function clearCellFocus(){setFocusCell(null);setOffset(0);setTargets([]);setPendingNavigation(null);}
  function focusTreeEpoch(uuid,epochInfo){
    if(busy)return;
    if(focusCell&&epochInfo?.cell_uuid!==focusCell)clearCellFocus();
    setFocused(uuid);setPendingNavigation({anchorUuid:uuid,direction:0});
  }
  useEffect(()=>{if(!focused&&!pendingNavigation&&!rows.loading&&rows.data?.epochs?.length)setFocused(rows.data.epochs[0].epoch_uuid);},[rows.data,rows.loading,focused,pendingNavigation]);
  useEffect(()=>{
    if(!pendingNavigation)return;
    if(rows.error){setError(rows.error);setPendingNavigation(null);return;}
    if(rows.loading||!rows.data)return;
    const page=rows.data.epochs;
    if(pendingNavigation.anchorUuid){
      const locatedOffset=rows.data.offset;setOffset(locatedOffset);
      if(pendingNavigation.direction){const next=nextEpochAction({epochs:page,offset:locatedOffset,total:rows.data.total,focused:pendingNavigation.anchorUuid,direction:pendingNavigation.direction});if(next.kind==='focus')setFocused(next.epoch_uuid);if(next.kind==='page'){setOffset(next.offset);setPendingNavigation(next);return;}}
    }else{if(rows.data.offset!==pendingNavigation.offset)return;if(page.length)setFocused(page[pendingNavigation.edge==='last'?page.length-1:0].epoch_uuid);}
    setPendingNavigation(null);
  },[pendingNavigation,rows.data,rows.loading,rows.error]);
  // Persist grouping only after the server has successfully built that tree.
  useEffect(()=>{if(previousExternalSplit.current===externalSplitKey&&tree.data&&!tree.loading&&!tree.error&&tree.data.split_order?.join(',')===splits)onSplitChange?.(tree.data.split_order);},[tree.data,tree.loading,tree.error,splits,onSplitChange,externalSplitKey]);
  useEffect(()=>{if(previousExternalSplit.current!==externalSplitKey){previousExternalSplit.current=externalSplitKey;setSplits(externalSplitKey);setDesignPath([]);setDesignNavigation(null);}},[externalSplitKey]);
  async function curate(changes, scope='selection') {
    if(busy)return;
    const uuids=resolveCurationTargets(focused,targets,scope);
    if(!uuids.length)return;
    setBusy(true);setError('');setOperationMessage('Saving curation changes…');
    try {
      const states=await Promise.all(uuids.map(uuid=>api(`/epochs/${uuid}?protocol_uuid=${id}`)));
      if(!curationMatchesCellFocus(states,focusCell))throw new Error('Cell focus changed. Clear the selection and select epochs in the current cell before saving.');
      const expected_revisions=Object.fromEntries(states.map(e=>[e.epoch_uuid,e.curation?.revision||0]));
      await api(`/protocols/${id}/curation`,{method:'POST',body:{epoch_uuids:uuids,changes,expected_revisions,query_revision:protocol.query_revision}});
      setTag('');onChange();
    }catch(e){setError(e.message);}finally{setBusy(false);}
  }
  async function saveMask() {
    if(busy)return;
    setBusy(true);setError('');setMaskMessage('');setOperationMessage('Saving protocol selection mask…');
    try {
      const mask=await api(`/protocols/${id}/masks/export`);
      const blob=new Blob([JSON.stringify(mask,null,2)+'\n'],{type:'application/json'});
      const url=URL.createObjectURL(blob);
      const link=document.createElement('a');link.href=url;link.download=`recording-mask-${id.slice(0,8)}.json`;
      document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
      setMaskMessage('Selection mask saved for this protocol query. The JSON contains epoch identities and inclusion decisions.');
    }catch(e){setError(e.message);}finally{setBusy(false);}
  }
  async function importMask(event) {
    const file=event.target.files?.[0];event.target.value='';
    if(!file||busy)return;
    setBusy(true);setError('');setMaskMessage('');setOperationMessage('Validating and importing protocol selection mask…');
    try {
      if(file.size>5*1024*1024)throw new Error('Selection mask is larger than the 5 MB limit. Choose a Recording Selection Mask JSON file.');
      let mask;
      try{mask=JSON.parse(await file.text());}catch{throw new Error('The selected file is not valid JSON. Choose a Recording Selection Mask v1 file.');}
      if(mask?.format!=='recording-selection-mask'||mask.version!==1)throw new Error('This button accepts Recording Selection Mask v1 JSON. Use Import MATLAB UGM below for .ugm masks.');
      if(mask.protocol_uuid!==id)throw new Error('This mask belongs to a different protocol. Open that protocol before importing it.');
      const result=await api(`/protocols/${id}/masks/import`,{method:'POST',body:{mask,query_revision:protocol.query_revision}});
      setMaskMessage(result.message || `Imported ${file.name}. Inclusion decisions were restored for the mask’s epochs; review approvals were not changed.`);
      onChange();
    }catch(e){setError(e.message);}finally{setBusy(false);}
  }
  async function importMatlabMask(){
    if(!matlabMaskFile||busy)return;
    setBusy(true);setError('');setMaskMessage('');setOperationMessage('Validating MATLAB mask against a completed export…');
    try{
      if(matlabMaskFile.size>32*1024*1024)throw new Error('MATLAB masks are limited to 32 MiB.');
      if(!matlabMaskFile.size)throw new Error('The selected mask file is empty.');
      if(!matlabMaskFile.name.toLowerCase().endsWith('.ugm'))throw new Error('Choose an EpicTree .ugm selection mask. This importer does not accept recording .mat files.');
      const body=new FormData();body.append('file',matlabMaskFile);body.append('query_revision',protocol.query_revision);
      if(matlabDataset)body.append('dataset_uuid',matlabDataset);
      const response=await fetch(`/api/protocols/${id}/masks/import-matlab`,{method:'POST',headers:{'X-Workspace-Request':'1'},body});
      const result=await response.json().catch(()=>({}));
      if(!response.ok){if(Array.isArray(result.matching_exports))setMatchingExports(result.matching_exports);throw new Error(result.error || result.message || `Mask import failed (${response.status})`);}
      if(!Number.isInteger(result.imported_count)||result.imported_count<1||!Number.isInteger(result.included_count)||result.included_count<0||result.included_count>result.imported_count||typeof result.dataset_uuid!=='string'||typeof result.query_revision!=='string'){onChange();throw new Error('The server did not return a complete import receipt. Check Activity & logs before retrying.');}
      setMaskMessage(result.message || `Imported ${number(result.imported_count)} MATLAB mask decisions from the matched export. Other epochs, tags and review states were unchanged.`);
      setMatlabMaskFile(null);setMatchingExports([]);onChange();
    }catch(error){setError(error.message);}finally{setBusy(false);}
  }
  const focusedPageIndex=rows.data?.epochs?.findIndex(e=>e.epoch_uuid===focused) ?? -1;
  function moveEpoch(direction) {
    if(busy||pendingNavigation||rows.loading)return;
    const next=nextEpochAction({epochs:rows.data?.epochs,offset:rows.data?.offset??offset,total:rows.data?.total,focused,direction});
    if(next.kind==='focus')setFocused(next.epoch_uuid);
    else if(next.kind==='page'){setPendingNavigation(next);setOffset(next.offset);}
    else if(next.kind==='locate')setPendingNavigation({anchorUuid:next.epoch_uuid,direction});
  }
  function epochKeys(event){if(designMode)return;const direction=epochArrowDirection(event);if(!direction)return;event.preventDefault();if(event.currentTarget.hasAttribute('tabindex'))event.currentTarget.focus({preventScroll:true});moveEpoch(direction);}
  const epochListRef=useRef(null);
  useEffect(()=>{epochListRef.current?.querySelector('.epoch-row.active')?.scrollIntoView({block:'nearest'});},[focused,rows.data]);
  const actionScope=targets.length?`${targets.length} selected`:'focused epoch';
  const tagEntry=focusedEpoch&&<EpochTags value={tag} onValue={setTag} onAdd={value=>curate({tags_add:[value]})} onRemove={value=>curate({tags_remove:[value]},'focused')} selectedTags={focusedEpoch.curation?.tags||[]} busy={busy} scope={actionScope} revision={revision} focusRequest={tagFocus}/>;
  const outsidePage=targets.filter(uuid=>!rows.data?.epochs?.some(e=>e.epoch_uuid===uuid)).length;
  return <div className={`inspector ${designMode?'tree-design':'epoch-inspector-mode'}`} tabIndex={0} onKeyDown={epochKeys} aria-label={designMode?'Tree overview workspace':'Epoch inspection workspace. Up and down arrows navigate matching epochs.'}>
    <div className="inspector-toolbar">
      <button className="protocol-overview-link" onClick={onBack}><ArrowLeft size={15}/> Protocol overview</button>
      <nav className="inspection-view-switch" aria-label="Tree and epoch views">
        <button className={designMode?'active':''} aria-pressed={designMode} onClick={()=>{setDesignMode(true);setTreeOpen(true);setTreeMode(true);}} title="Return to your shared tree, keeping its branch and page">{designMode?<GitBranch size={15}/>:<ArrowLeft size={15}/>} {designMode?'Tree overview':'Back to tree overview'}</button>
        <button className={!designMode?'active':''} aria-pressed={!designMode} onClick={()=>{setDesignMode(false);setTreeMode(false);}}><Activity size={15}/> Epoch inspection</button>
      </nav>
      <button onClick={()=>setTreeOpen(!treeOpen)}><GitBranch size={15}/>{treeOpen?'Hide':'Show'} {designMode?'tree editor':'tree'}</button>
      {!designMode&&<button onClick={()=>{toggleMetadata(true);setTagFocus(value=>value+1);}}><Tag size={15}/> Tag epoch</button>}
      {!designMode&&<button onClick={()=>toggleMetadata(!metadataOpen)} aria-expanded={metadataOpen} aria-controls="epoch-metadata-sidebar">{metadataOpen?<PanelRightClose size={15}/>:<PanelRightOpen size={15}/>} {metadataOpen?'Hide':'Show'} metadata</button>}<span className="spacer"/>{!designMode&&onImport&&<button disabled={busy} onClick={onImport}><Upload size={15}/> Add data store</button>}{!designMode&&onExport&&<button className="primary" disabled={busy} onClick={onExport} title="Open export controls for all matching cells in this protocol query"><Download size={15}/> Export protocol</button>}<span>{designMode||treeMode?`${tree.data?number(tree.data.count):'Loading…'} in shared tree`:`${rows.data?number(rows.data.total):'Loading…'} navigation epochs`}</span><Badge kind="info">{protocol.binding?"Working dataset":"Saved source query"}</Badge>
    </div>
    {focusCell&&<div className="inspection-cell-focus"><span title={focusCell}><strong>Cell focus:</strong> {datedCellLabel(protocol.cells?.find(cell=>cell.cell_uuid===focusCell) || focusedEpoch || {},true)} · {rows.data&&!rows.loading?number(rows.data.total):'…'} epochs for navigation</span><span>Shared tree keeps all protocol matches.</span><button disabled={busy} onClick={clearCellFocus}><X size={13}/> Clear cell focus</button></div>}
    <SourceEligibilityNotice eligibility={protocol.source_eligibility} onStores={onStores}/>
    {!designMode&&<><div className={`inspection-scope ${targets.length?'bulk-active':'focused-scope'}`} role="status" aria-live="polite">
      {targets.length?<><strong>Bulk actions affect {targets.length} selected epochs</strong>
        <span>{outsidePage?`${outsidePage} outside this page. `:''}Changing the focused trace does not change this selection.</span>
        <button disabled={busy} onClick={()=>setTargets([])}><X size={14}/> Clear selection</button>
      </>:<><strong><Eye size={13}/> Focused epoch</strong><span className="scope-help" title="Checkboxes select bulk-action targets; selecting them does not include or approve epochs."><Info size={13}/> Selection help</span></>}
      <button className="scope-mask-toggle" aria-expanded={masksOpen} onClick={()=>setMasksOpen(open=>!open)}><FileJson size={14}/> Selection masks <ChevronDown size={12}/></button>
    </div>
    {masksOpen&&<div className="inspection-mask-tools">
      <span><FileJson size={15}/> Protocol selection mask <small>All epochs in the full protocol query · includes other cells and filtered-out epochs · JSON v1 · whole protocol scope</small></span>
      <button disabled={busy} onClick={saveMask} title="Download all inclusion decisions for this protocol query as JSON"><Download size={14}/> Save JSON mask</button>
      <input ref={maskInput} type="file" accept=".json,application/json" hidden onChange={importMask}/>
      <button disabled={busy} onClick={()=>maskInput.current?.click()} title="Restore inclusion for the entire protocol query, regardless of the visible cell, filters or checkboxes"><Upload size={14}/> Import JSON mask</button>
      <details className="matlab-mask-import"><summary><Upload size={14}/> Import MATLAB UGM</summary><p>Use a UUID-based EpicTree UGM v1.1 mask from a completed MATLAB export. Only that export’s epochs are updated; tags, review and other epochs are preserved.</p>
        <div className="matlab-mask-fields"><label>Match completed MATLAB export<select aria-label="MATLAB mask export match" disabled={busy} value={matlabDataset} onChange={event=>setMatlabDataset(event.target.value)}><option value="">Automatically match exact epoch UUIDs</option>{matchingMatlabExports.map(item=><option key={item.dataset_uuid} value={item.dataset_uuid}>{item.name || item.dataset_uuid}{Number.isFinite(item.epoch_count)?` · ${number(item.epoch_count)} epochs`:''} · {item.dataset_uuid.slice(0,8)}</option>)}</select></label><input ref={matlabMaskInput} type="file" accept=".ugm" hidden onChange={event=>{setMatlabMaskFile(event.target.files?.[0] || null);setMatchingExports([]);event.target.value='';}}/><button disabled={busy} onClick={()=>matlabMaskInput.current?.click()}><Upload size={14}/> Choose UGM file</button><span className="matlab-mask-filename">{matlabMaskFile?.name || 'No file selected'}</span><button className="primary" disabled={busy||!matlabMaskFile||!protocol.query_revision} onClick={importMatlabMask}>Apply MATLAB mask</button></div>
        {matlabExports.error&&<p className="matlab-mask-history-error">Export history could not load. Automatic exact-UUID matching is still checked by the server. <button onClick={matlabExports.reload}>Retry history</button></p>}{matchingExports.length>0&&<p className="matlab-mask-history-error">Choose the completed export that produced this mask, then apply again.</p>}
      </details>
    </div>}
    </>}{!designMode&&maskMessage&&<div className="mask-result" role="status"><Check size={15}/><span>{maskMessage}</span><button className="icon-button" onClick={()=>setMaskMessage('')} aria-label="Dismiss mask result"><X size={14}/></button></div>}
    {error&&<div className="inspector-operation-error" role="alert">{error}<button className="icon-button" onClick={()=>setError('')} aria-label="Dismiss operation error"><X size={14}/></button></div>}
    <div ref={layoutRef} style={{gridTemplateColumns:paneSizes.columns,'--metadata-width':`${paneSizes.metadata}px`}} className={`inspection-layout resizable-layout ${treeOpen?'':'without-tree'} ${!designMode&&metadataOpen?'metadata-open':''} ${paneSizes.overlay?'metadata-overlay':''}`}>
      {treeOpen&&<aside className="inspection-tree">
        {!designMode&&<div className="tree-heading"><h3>{treeMode?'Shared protocol tree':focusCell?'Focused cell':'Epochs by cell'}</h3><div className="segmented">
          <button className={!treeMode?'active':''} onClick={()=>setTreeMode(false)}>Epochs</button>
          <button className={treeMode?'active':''} onClick={()=>{setTreeMode(true);changePane('tree',Math.max(420,paneSizes.tree));}}>Split tree</button>
        </div></div>}
        {designMode?<TreeBuilder protocolId={id} queryString={protocolSearch} revision={revision}
            value={splits.split(',').filter(Boolean)} onChange={changeSplits}
            preview={tree.data} loading={tree.loading} error={tree.error}/>:treeMode?<>
          <div className="inspection-tree-edit"><span>{splits?`${splits.split(',').length} splits`:'Flat epoch list'}</span><button onClick={()=>setDesignMode(true)}><GitBranch size={13}/> Edit tree</button></div>
          <PagedTree protocolId={id} filters={filters} splits={splits} revision={revision} selected={focused} initialNavigation={designNavigation} onNavigationChange={setDesignNavigation} onSelectEpoch={focusTreeEpoch} onMetadata={receiveTree} onStatus={setTreeStatus}/>
        </>:<>
          <div className="selection-controls"><button disabled={busy||rows.loading} onClick={()=>setTargets(rows.data?.epochs?.map(e=>e.epoch_uuid)||[])}>Select this page</button><button disabled={busy||!targets.length} onClick={()=>setTargets([])}>Clear {targets.length || ''}</button></div>
          <div ref={epochListRef} className="tree-scroll" tabIndex={0} aria-label="Chronological matching epochs. Up and down arrows select epochs."><Status {...rows}><EpochSkimList epochs={rows.data?.epochs||[]} offset={offset} focused={focused} onFocus={setFocused} targets={targets} setTargets={setTargets} disabled={busy||rows.loading}/></Status></div>
          <div className="pagination"><button disabled={!offset} onClick={()=>setOffset(Math.max(0,offset-60))} aria-label="Previous epoch page"><ArrowLeft size={14}/></button><span>{rows.data?.total?offset+1:0}–{Math.min(offset+60,rows.data?.total||0)}</span><button disabled={offset+60>=(rows.data?.total||0)} onClick={()=>setOffset(offset+60)} aria-label="Next epoch page"><ArrowRight size={14}/></button></div>
          {!metadataOpen&&tagEntry}
        </>}
      </aside>}
      {treeOpen&&<PaneDivider label={designMode?'Resize tree editor pane':'Resize epoch tree pane'} value={paneSizes.tree} min={180} max={paneSizes.treeMax} onChange={value=>changePane('tree',value)} onCommit={value=>savePane('tree',value)}/>}
      {designMode?<PagedTree protocolId={id} filters={filters} splits={splits} revision={revision} design selected={focused} initialNavigation={designNavigation} onNavigationChange={setDesignNavigation} onMetadata={receiveTree} onStatus={setTreeStatus} onSelectEpoch={(uuid,info)=>{focusTreeEpoch(uuid,info);setTreeMode(true);changePane('tree',Math.max(420,paneSizes.tree));setDesignMode(false);}}/>:<div className="inspection-detail"><Status {...epoch} data={focusedEpoch} loading={!epoch.error&&(epoch.loading||(!!focused&&!focusedEpoch))} retry={epoch.reload}>{focusedEpoch?<>
        <div className="epoch-heading"><div>
          <h2>{datedCellLabel(focusedEpoch)}</h2>
          <p>Epoch {focusedEpoch.epoch_number ?? '—'} within block · {focusedEpoch.start_time?.split(/[T ]/)[1]?.slice(0,8) || 'Time not recorded'}</p>
        </div><div className="epoch-heading-badges">{onQC&&<button disabled={busy} onClick={()=>onQC(focusedEpoch.cell_uuid)} title="Open quality-control recordings linked to this cell">Cell QC</button>}<Badge kind={focusedEpoch.curation?.included===false?'neutral':'info'}>{focusedEpoch.curation?.included===false?'Excluded':'Included'}</Badge><Badge>{focusedEpoch.exports?.length?`${focusedEpoch.exports.length} saved exports`:'No saved export'}</Badge></div></div>
        <div className="epoch-navigation" tabIndex={0} aria-label="Epoch navigation. Up and down arrows move chronologically."><button disabled={!!pendingNavigation||rows.loading||busy||(offset===0&&focusedPageIndex===0)} onClick={()=>moveEpoch(-1)}><ArrowLeft size={14}/> Previous epoch</button><span>{pendingNavigation?'Loading next metadata page…':focusedPageIndex<0?'Focused epoch is outside the loaded page':`Epoch ${offset+focusedPageIndex+1} of ${rows.data.total} matching epochs`}</span><button disabled={!!pendingNavigation||rows.loading||busy||(focusedPageIndex>=0&&offset+focusedPageIndex+1>=(rows.data?.total||0))} onClick={()=>moveEpoch(1)}>Next epoch <ArrowRight size={14}/></button></div>
        <Trace key={focusedEpoch.epoch_uuid} epoch={focusedEpoch}/>
        <div className="curation-bar">
          <button disabled={busy} onClick={()=>curate({included:true})}><Check size={14}/> Include {actionScope}</button>
          <button disabled={busy} onClick={()=>curate({included:false})}><X size={14}/> Exclude {actionScope}</button>
          {!metadataOpen&&(!treeOpen||treeMode)&&tagEntry}
        </div>
        {busy&&<p className="curation-progress" role="status">{operationMessage}</p>}
        <div className="tags"><span>Focused epoch tags:</span>
          {(focusedEpoch.curation?.tags||[]).map(t=><button key={t} disabled={busy} aria-label={`Remove tag ${t} from focused epoch only`} title="Remove from focused epoch only" onClick={()=>curate({tags_remove:[t]},'focused')}>{t}<X size={13}/></button>)}
          {!focusedEpoch.curation?.tags?.length&&<span>No tags</span>}
          {focusedEpoch.curation?.included===false&&<Badge kind="warning">Focused epoch excluded from export</Badge>}
        </div>
        <details className="optional-review"><summary>Optional review marker · {focusedEpoch.curation?.review_state==='approved'?'Reviewed':'Not marked'}</summary>
          <p>Use this marker if it helps your workflow. Included epochs can be exported without it; “reviewed only” is an optional export filter.</p>
          <button disabled={busy} onClick={()=>curate({review_state:!targets.length&&focusedEpoch.curation?.review_state==='approved'?'unreviewed':'approved'})}><Eye size={14}/>
            {targets.length?`Mark ${actionScope} reviewed`:focusedEpoch.curation?.review_state==='approved'?'Clear focused epoch review marker':'Mark focused epoch reviewed'}
          </button>
        </details>
      </>:<Empty title="Choose an epoch">Select an epoch from the tree to inspect its response and metadata.</Empty>}</Status></div>}
      {!designMode&&metadataOpen&&<><PaneDivider label="Resize metadata pane" value={paneSizes.metadata} min={240} max={paneSizes.metadataMax} reverse className={paneSizes.overlay?'metadata-overlay-divider':''} style={paneSizes.overlay?{right:paneSizes.metadata}:undefined} onChange={value=>changePane('metadata',value)} onCommit={value=>savePane('metadata',value)}/><MetadataPanel tags={tagEntry} epoch={focusedEpoch} catalog={metadataCatalog} onClose={()=>toggleMetadata(false)} context={focusedEpoch&&<ScientificContext epoch={focusedEpoch}/>} connections={focusedEpoch&&<EpochConnections epoch={focusedEpoch} protocolName={humanize(protocol.definition?.name)}/>}/></>}
    </div>
  </div>;
}
