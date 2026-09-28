import {predicateIdentity} from '../predicateIdentity.js';
import MatchingEpochs from './MatchingEpochs.jsx';
import CandidateExportPanel from './CandidateExportPanel.jsx';
import {explorerFocusState} from '../explorerScope.js';
import {snapshotExplorerState} from '../workspaceNavigation.js';
import {datedCellLabel} from '../recordingIdentity.js';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, Check, ChevronDown, Filter, Download, GitBranch, History, LoaderCircle, RefreshCw, Save, X } from 'lucide-react';
import { api, humanize, number, time, useResource } from '../api.js';
import { Badge, Metadata, Status } from './Common.jsx';
import { Trace } from './Inspector.jsx';
import TreeBuilder from './TreeBuilder.jsx';
import PagedTree from './PagedTree.jsx';
import PaneDivider from './PaneDivider.jsx';
import {inspectorPaneSizes} from '../inspectorInteraction.js';
import EpochConnections from './EpochConnections.jsx';
import PredicateBuilder from './PredicateBuilder.jsx';
import ProtocolApplyPanel from './ProtocolApplyPanel.jsx';
import { compilePredicate, conditionCount, newGroup, predicateToDraft } from './predicateState.js';
import './MetadataExplorer.css';

const allEpochs={all:[]};
function draftOf(predicate){const node=predicateToDraft(predicate);return node.kind==='group'?node:{...newGroup(),children:[node]};}
export default function MetadataExplorer({revision=0,protocols=[],onInspect,initialPredicate=null,initialRevisionId=null,initialProtocolId=null,initialExportIntent=null,onChange,onProtocolApplied,session=null,onSession}) {
  const saved=useRef(session).current;
  const [draft,setDraft]=useState(()=>saved?.draft || draftOf(initialPredicate || allEpochs));
  const [name,setName]=useState(saved?.name ?? 'Metadata selection');
  const [filterSplits,setFilterSplits]=useState(saved?.filterSplits ?? 'date,protocol,cell');
  const [splits,setSplits]=useState(saved?.splits ?? 'date,protocol,cell');
  const [step,setStep]=useState(saved?.step || 'filter');
  const [resultsFromDraft,setResultsFromDraft]=useState(saved?.resultsFromDraft??true),[matchingNavigation,setMatchingNavigation]=useState(saved?.matchingNavigation||null),[destination,setDestination]=useState(initialExportIntent?'export':null);
  const [initialCandidateLoading,setInitialCandidateLoading]=useState(!!initialRevisionId&&!saved?.applied);
  const [initialCandidateRetry,setInitialCandidateRetry]=useState(0);
  const [applied,setApplied]=useState(saved?.applied || null),[restored,setRestored]=useState(saved?.restored || null);
  const [treeNavigation,setTreeNavigation]=useState(saved?.treeNavigation||null);
  const [path,setPath]=useState(saved?.path || []),[focused,setFocused]=useState(saved?.focused || null);
  const [generation,setGeneration]=useState(0),[historyVersion,setHistoryVersion]=useState(0),[historyOffset,setHistoryOffset]=useState(saved?.historyOffset || 0);
  const [draftPreview,setDraftPreview]=useState({data:null,loading:false,error:null,key:null});
  const [tree,setTree]=useState({data:null,loading:false,error:null});
  const [busy,setBusy]=useState(false),[busyAction,setBusyAction]=useState(null),[error,setError]=useState(''),[notice,setNotice]=useState(saved?.wasBusy?'A request was in progress when you left. Check Candidate history before saving again.':saved?'Workspace draft restored. No save or protocol update was replayed.':'');
  const draftController=useRef(null),treeController=useRef(null);
  const [pagedInfo,setPagedInfo]=useState(null),[pagedStatus,setPagedStatus]=useState({loading:false,error:null});
  const layoutRef=useRef(null),[layoutWidth,setLayoutWidth]=useState(1100);
  const [groupingWidth,setGroupingWidth]=useState(()=>{try{const value=Number(localStorage.getItem('workspace.explorer.groupingWidth'));return value>=240?value:320;}catch{return 320;}});
  const pane=inspectorPaneSizes(layoutWidth,{tree:groupingWidth},true,false);
  useEffect(()=>{const node=layoutRef.current;if(!node)return;const observer=new ResizeObserver(entries=>setLayoutWidth(entries[0].contentRect.width));observer.observe(node);return()=>observer.disconnect();},[step,focused,initialCandidateLoading]);
  useEffect(()=>setPagedInfo(null),[splits,applied?.revision_uuid,generation]);
  const catalog=useResource('/explore/predicate-fields',`${revision}:${generation}`);
  const history=useResource(`/explore/revisions?offset=${historyOffset}&limit=20`,historyVersion);
  const epoch=useResource(focused?`/epochs/${focused}`:null,`${revision}:${generation}`);
  const compiled=useMemo(()=>{
    try{return {predicate:compilePredicate(draft,catalog.data?.fields || null),error:null};}
    catch(error){return {predicate:null,error:error.message};}
  },[draft,catalog.data]);
  const draftKey=predicateIdentity({predicate:compiled.predicate,splits:filterSplits});
  const changedFilter=!!applied&&predicateIdentity(compiled.predicate)!==predicateIdentity(applied.recipe.predicate);
  const changedTree=!!applied&&splits.split(',').map(x=>x.trim()).join(',')!==applied.recipe.splits.split(',').map(x=>x.trim()).join(',');
  const currentDraftPreview=draftPreview.key===draftKey?draftPreview.data:null;
  const previewFieldCount=field=>currentDraftPreview?.catalog?.fields?.find(item=>item.id===field)?.recorded_distinct_count;
  const restoredDiff=restored&&currentDraftPreview?.baseline_diff;
  const treeDiff=tree.data?.baseline_diff;
  const changedMembership=!!treeDiff&&(treeDiff.added>0||treeDiff.removed>0||treeDiff.changed>0||treeDiff.annotation_changed===true);
  const focusState=explorerFocusState(tree.data,focused,tree);
  const focusVerified=['included','excluded'].includes(focusState);
  const focusedInScope=focusState==='included';
  const matches=epoch.data?protocols.filter(protocol=>!protocol.binding&&(protocol.acquisition_protocol===epoch.data.protocol_name ||
    protocol.query?.all?.some(condition=>condition.field==='EpochBlock.protocol_name'&&condition.operator==='eq'&&condition.value===epoch.data.protocol_name))):[];
  useEffect(()=>{onSession?.(snapshotExplorerState({draft,name,filterSplits,splits,step,resultsFromDraft,matchingNavigation,path,treeNavigation,focused,applied,restored,historyOffset,wasBusy:busy}));},[draft,name,filterSplits,splits,step,resultsFromDraft,matchingNavigation,path,treeNavigation,focused,applied,restored,historyOffset,busy,onSession]);
  useEffect(()=>{
    if(saved?.applied&&initialCandidateRetry===0){setInitialCandidateLoading(false);return;}
    if(!initialRevisionId){setInitialCandidateLoading(false);return;}
    const controller=new AbortController();setInitialCandidateLoading(true);setApplied(null);setTree({data:null,loading:false,error:null});setError('');
    api(`/explore/revisions/${initialRevisionId}?summary=1`,{signal:controller.signal}).then(result=>{
      if(controller.signal.aborted)return;
      if(!result.recipe||!result.revision_uuid)throw new Error('This candidate does not contain a saved recipe.');
      setApplied(result);setDraft(draftOf(result.recipe.predicate));setName(initialExportIntent?.name || result.recipe.name || 'Protocol candidate');
      setSplits(result.recipe.splits);setFilterSplits(result.recipe.splits);setRestored(null);setFocused(null);setPath([]);setTreeNavigation(null);setStep('results');setResultsFromDraft(false);
      setNotice(`Reviewing saved candidate ${result.revision_uuid.slice(0,8)}. The protocol working dataset stays unchanged until you apply it.`);
    }).catch(error=>{if(!controller.signal.aborted)setError(error.message);}).finally(()=>{if(!controller.signal.aborted)setInitialCandidateLoading(false);});
    return()=>controller.abort();
  },[initialRevisionId,initialCandidateRetry]);
  useEffect(()=>()=>{draftController.current?.abort();treeController.current?.abort();},[]);
  useEffect(()=>{
    if(!applied)return;
    if(!focused&&applied.preview&&splits===applied.recipe.splits&&generation===applied.previewGeneration&&revision===applied.previewRevision){setTree({data:applied.preview,loading:false,error:null});return;}
    const controller=new AbortController();treeController.current?.abort();treeController.current=controller;
    setTree(previous=>({...previous,loading:true,error:null}));
    api('/explore/preview',{method:'POST',body:{predicate:applied.recipe.predicate,splits,summary_only:true,baseline_revision_uuid:applied.revision_uuid,...(focused?{focused_uuid:focused}:{})},signal:controller.signal})
      .then(data=>{if(!controller.signal.aborted)setTree({data:{...data,_focusedUuid:focused},loading:false,error:null});})
      .catch(error=>{if(!controller.signal.aborted)setTree(previous=>({...previous,loading:false,error:error.message}));});
    return()=>controller.abort();
  },[applied,splits,revision,generation,focused]);
  useEffect(()=>{if(focusVerified&&tree.data.focused_in_scope===false)setFocused(null);},[focusVerified,tree.data]);
  const changeSplits=useCallback(fields=>{const text=fields.join(',');setSplits(text);setFilterSplits(text);setPath([]);setTreeNavigation(null);setFocused(null);},[]);
  async function previewDraft(predicate=compiled.predicate,grouping=filterSplits,baseline=restored?.revision_uuid){
    if(!predicate)return;
    const controller=new AbortController();draftController.current?.abort();draftController.current=controller;
    const key=predicateIdentity({predicate,splits:grouping});setDraftPreview({data:null,loading:true,error:null,key});
    try{const data=await api('/explore/preview',{method:'POST',body:{predicate,splits:grouping,summary_only:true,...(baseline?{baseline_revision_uuid:baseline}:{})},signal:controller.signal});if(!controller.signal.aborted)setDraftPreview({data,loading:false,error:null,key});}
    catch(error){if(!controller.signal.aborted)setDraftPreview({data:null,loading:false,error:error.message,key});}
  }
  async function saveRevision(kind,nextStep='results'){
    const predicate=kind==='filter'?compiled.predicate:applied?.recipe.predicate;
    if(!predicate||busy)return;
    setBusy(true);setBusyAction('save');setError('');setNotice('');
    try{
      const body={predicate,splits:kind==='filter'?filterSplits:splits,name:name.trim() || 'Metadata selection',summary_only:true};
      const parent=kind==='filter'?(restored?.revision_uuid || applied?.revision_uuid):applied?.revision_uuid;
      if(parent)body.parent_revision_uuid=parent;
      const result=await api('/explore/revisions',{method:'POST',body});
      if(!result.recipe||!result.revision_uuid)throw new Error('The server did not return a recorded revision. Reload history before retrying.');
      setApplied({...result,previewGeneration:generation,previewRevision:revision});if(result.preview)setTree({data:result.preview,loading:false,error:null});onChange?.();setSplits(result.recipe.splits);setFilterSplits(result.recipe.splits);setPath([]);setTreeNavigation(null);setFocused(null);setStep(nextStep);setResultsFromDraft(false);
      if(kind==='filter'){setDraft(draftOf(result.recipe.predicate));setRestored(null);}
      setHistoryVersion(value=>value+1);setHistoryOffset(0);setNotice(`Recorded revision ${result.revision_uuid.slice(0,8)}. Its query and exact epoch membership are preserved.`);return result;
    }catch(error){setError(error.message);}finally{setBusy(false);setBusyAction(null);}
  }
  async function restoreDraft(id){
    if(busy)return;setBusy(true);setBusyAction('restore');setError('');setNotice('');
    try{
      const result=await api(`/explore/revisions/${id}?summary=1`);
      setRestored(result);setDraft(draftOf(result.recipe.predicate));setFilterSplits(result.recipe.splits);setName(result.recipe.name || 'Restored selection');
      setStep('filter');setFocused(null);await previewDraft(compilePredicate(draftOf(result.recipe.predicate),catalog.data?.fields || null),result.recipe.splits,result.revision_uuid);
    }catch(error){setError(error.message);}finally{setBusy(false);setBusyAction(null);}
  }
  const resultPreview=resultsFromDraft?currentDraftPreview:tree.data;
  const resultPredicate=resultsFromDraft?compiled.predicate:applied?.recipe.predicate;
  const resultSplits=resultsFromDraft?filterSplits:splits;
  const resultLoading=resultsFromDraft?draftPreview.loading:tree.loading;
  const resultError=resultsFromDraft?draftPreview.error:tree.error;
  useEffect(()=>{if(step==='results'&&resultsFromDraft&&!currentDraftPreview&&!draftPreview.loading&&draftPreview.key!==draftKey&&compiled.predicate)previewDraft();},[step,resultsFromDraft,draftKey,currentDraftPreview,draftPreview.loading,draftPreview.key]);
  async function prepareDestination(next,fromDraft=resultsFromDraft){
    if(fromDraft||!applied||changedTree||changedMembership){const result=await saveRevision(fromDraft?'filter':'tree',next==='tree'?'tree':'results');if(!result)return;}
    if(next==='tree'){setStep('tree');setDestination(null);}else setDestination(next);
  }
  return <div className={`inspector metadata-explorer predicate-explorer ${focused?'explorer-inspecting':step==='tree'?'tree-design':''}`}>
    <header className="mx-heading"><div><div className="eyebrow">SOURCE RECORDINGS</div><h1>{focused?'Inspect selected epoch':step==='results'?'Matching epochs':step==='tree'?'Design tree':'Search predicate'}</h1></div>
      <div className="mx-header-actions">{focused?<button onClick={()=>setFocused(null)}><ArrowLeft size={15}/> Back to tree overview</button>:<>
        <button className={step==='filter'?'active':''} onClick={()=>setStep('filter')}><Filter size={14}/> 1 · Filter epochs</button>
        <button className={step==='results'?'active':''} disabled={!applied&&!currentDraftPreview} onClick={()=>{setStep('results');setFocused(null);}}>2 · Matching epochs</button>
        <button className={step==='tree'?'active':''} disabled={!applied} onClick={()=>setStep('tree')}><GitBranch size={14}/> 3 · Tree overview</button>
      </>}{step==='tree'&&applied&&!focused&&<button onClick={()=>setGeneration(value=>value+1)} disabled={tree.loading}><RefreshCw size={14}/> Refresh preview</button>}</div>
    </header>
    {error&&<div className="mx-operation-error" role="alert">{error}<button onClick={()=>setError('')} aria-label="Dismiss error"><X size={14}/></button></div>}
    {notice&&<div className="mx-recorded-notice" role="status"><Check size={14}/><span>{notice}</span><button onClick={()=>setNotice('')} aria-label="Dismiss revision notice"><X size={14}/></button></div>}
    {initialCandidateLoading?<div className="mx-candidate-loading" role="status"><LoaderCircle size={18}/> Loading saved candidate…</div>:initialRevisionId&&!applied?<div className="mx-candidate-loading"><span>The saved candidate could not be loaded.</span><button onClick={()=>setInitialCandidateRetry(value=>value+1)}>Retry</button></div>:step==='filter'&&!focused?<div className="mx-filter-layout"><div className="mx-filter-editor">
      <div className="mx-filter-heading"><div><h2>Filter source recordings</h2><p>Choose a field, a comparison and a recorded value. Combine conditions below.</p></div><Badge>{applied?'Editing draft':'Draft'}</Badge></div>
      {restored&&<div className="mx-restored"><History size={15}/><span>Restored revision {restored.revision_uuid.slice(0,8)} as a draft. The original stays unchanged.</span></div>}
      <Status {...catalog} retry={catalog.reload}>{catalog.data&&<PredicateBuilder disabled={busy} draft={draft} fields={catalog.data.fields} onChange={setDraft}/>}</Status>
      {compiled.error&&<p className="mx-validation" role="status">{compiled.error}</p>}
      <div className="mx-save-details"><label className="mx-selection-name">Selection name<input disabled={busy} value={name} onChange={event=>setName(event.target.value)} maxLength={120} placeholder="Name this recording selection"/></label><span><Save size={13}/> Saved with its query and exact epoch membership</span></div>
      <details className="mx-predicate-json"><summary>Exact predicate</summary><pre>{compiled.predicate?JSON.stringify(compiled.predicate,null,2):'Complete the conditions to produce a valid predicate.'}</pre></details>
      <div className="mx-filter-actions"><button disabled={!!compiled.error||catalog.loading||draftPreview.loading||busy} onClick={()=>previewDraft()}><SearchIcon/> Preview matches</button><button className="primary" disabled={!currentDraftPreview||draftPreview.loading||busy} onClick={()=>{setResultsFromDraft(true);setStep('results');setDestination(null);}}>View matching epochs <ArrowRight size={14}/></button><button disabled={!!compiled.error||!catalog.data||busy} onClick={()=>saveRevision('filter')}><Save size={15}/>{busy?(busyAction==='restore'?'Restoring…':'Saving…'):'Save & continue'}</button></div>
    </div><aside className="mx-filter-aside">
      <section className="mx-match-summary"><div className="eyebrow"><Filter size={13}/> MATCHING DATA</div><strong>{draftPreview.loading?'…':currentDraftPreview?number(currentDraftPreview.matched_count):'—'}</strong><span>{currentDraftPreview?`of ${number(currentDraftPreview.total_source)} active source epochs match`:'Preview to count matching active epochs'}</span>{currentDraftPreview&&<><progress className="mx-match-meter" value={currentDraftPreview.matched_count} max={Math.max(1,currentDraftPreview.total_source)} aria-label="Fraction of query-included epochs matching"/><div className="mx-match-facts"><div><strong>{number(previewFieldCount('cell'))}</strong><span>{previewFieldCount('cell')===1?'cell':'cells'}</span></div><div><strong>{number(previewFieldCount('date'))}</strong><span>{previewFieldCount('date')===1?'date':'dates'}</span></div><div><strong>{number(previewFieldCount('protocol'))}</strong><span>{previewFieldCount('protocol')===1?'protocol ID':'protocol IDs'}</span></div></div></>}{currentDraftPreview?.total_catalog>currentDraftPreview?.total_source&&<p>{number(currentDraftPreview.total_catalog-currentDraftPreview.total_source)} catalog epochs are excluded from new queries.</p>}
        <p>{conditionCount(draft)===0?'No field conditions; group logic applies.':`${conditionCount(draft)} ${conditionCount(draft)===1?'condition':'conditions'}.`} {applied?'Editing this draft leaves the saved selection unchanged.':'Preview, then inspect matching epochs.'}</p>
        {draftPreview.data&&!currentDraftPreview&&<p>Draft edited since the last preview.</p>}
        {draftPreview.error&&<p className="mx-validation" role="alert">{draftPreview.error}</p>}
        {restoredDiff&&<div className="mx-revision-diff"><span>Compared with saved membership</span><strong>+{restoredDiff.added} added · −{restoredDiff.removed} removed</strong><span>{restoredDiff.changed} metadata revisions changed{restoredDiff.annotation_changed?' · Saved tags changed':''}</span></div>}
      </section>
      <section className="mx-revision-history"><div><h3><History size={15}/> Candidate history</h3><button onClick={history.reload} aria-label="Refresh filter history"><RefreshCw size={13}/></button></div><Status {...history} retry={history.reload}>
        {history.data?.revisions?.length?history.data.revisions.map(item=><div className="mx-history-row" key={item.revision_uuid}><strong>{item.name || 'Recording selection'}</strong><span>{time(item.created_at)} · {number(item.matched_count)} / {number(item.total_source)} epochs</span><small>{item.revision_uuid.slice(0,8)}{item.parent_revision_uuid?` ← ${item.parent_revision_uuid.slice(0,8)}`:''}</small><button disabled={busy} onClick={()=>restoreDraft(item.revision_uuid)}>Restore as draft</button></div>):<p className="mx-history-empty">Saved selections and tree arrangements appear here.</p>}
      </Status><div className="mx-history-pages"><button disabled={!historyOffset} onClick={()=>setHistoryOffset(Math.max(0,historyOffset-20))}><ArrowLeft size={13}/></button><span>Revisions {history.data?.revisions?.length?historyOffset+1:0}–{historyOffset+(history.data?.revisions?.length || 0)}</span><button disabled={!history.data?.has_more} onClick={()=>setHistoryOffset(historyOffset+20)}><ArrowRight size={13}/></button></div></section>
    </aside></div>:step==='results'?<div className="mx-results-workflow">
      <div className="mx-results-actions"><strong>{applied&&!resultsFromDraft?'Saved selection':'Predicate preview'}</strong><input aria-label="Selection name for results" value={name} onChange={event=>setName(event.target.value)} placeholder="Name this selection (optional)"/><button disabled={busy||resultLoading||!!resultError||!resultPreview} onClick={()=>saveRevision(resultsFromDraft?'filter':'tree')}>{busy?'Saving selection…':'Save selection'}</button><button disabled={busy||resultLoading||!!resultError||!resultPreview} onClick={()=>prepareDestination('tree')}><GitBranch size={14}/> Edit tree</button><button disabled={busy||resultLoading||!!resultError||!resultPreview} onClick={()=>prepareDestination('protocol')}>Use in protocol</button><button className="primary" disabled={busy||resultLoading||!!resultError||!resultPreview?.matched_count} onClick={()=>prepareDestination('export')}><Download size={14}/> Export selection</button></div>
      {destination&&applied&&!resultsFromDraft&&<div className="mx-result-destination"><button className="mx-close-destination" onClick={()=>setDestination(null)}><X size={14}/> Close {destination==='export'?'export':'protocol'} controls</button>{destination==='export'?<CandidateExportPanel candidate={applied} defaultName={name} defaultFormat={initialExportIntent?.format} disabled={busy||resultLoading||!!resultError||changedTree||changedMembership} onExported={()=>onChange?.()}/>:<ProtocolApplyPanel initialProtocolId={initialProtocolId} candidate={applied} protocols={protocols} disabled={busy||resultLoading||!!resultError||changedTree||changedMembership} onApplied={onProtocolApplied}/>}</div>}
      {resultError&&<div className="mx-operation-error" role="alert">{resultError}<button onClick={()=>resultsFromDraft?previewDraft():setGeneration(value=>value+1)}>Refresh results</button></div>}
      {!resultLoading&&!resultError&&resultPreview&&resultPredicate?<MatchingEpochs key={resultPreview.tree_revision} predicate={resultPredicate} splits={resultSplits} preview={resultPreview} session={matchingNavigation} onSession={setMatchingNavigation} onRefresh={()=>resultsFromDraft?previewDraft():setGeneration(value=>value+1)}/>:<Status loading={resultLoading} error={resultError}/>}
    </div>:<>
      <div className="mx-applied-scope"><Filter size={14}/><strong>{tree.data?`${tree.data===applied?.preview?'Recorded selection':'Preview'}: ${number(tree.data.matched_count)} / ${number(tree.data.total_source)} source epochs`:'Evaluating applied filter…'}</strong><span>Saved revision {applied?.revision_uuid.slice(0,8)} · {number(applied?.recipe.epoch_count ?? applied?.recipe.epochs?.length)} epochs recorded</span>
        {changedFilter&&<Badge>Unapplied filter edits</Badge>}{changedTree||changedMembership?<><Badge kind="warning">{changedMembership?'Current preview differs from saved revision':'Tree changes are a draft'}</Badge><button disabled={busy||tree.loading||!!tree.error} onClick={()=>saveRevision('tree')}><Save size={14}/> {changedMembership?'Save current revision':'Save tree revision'}</button></>:<Badge kind="success">Filter & tree recorded</Badge>}
        {treeDiff&&(treeDiff.added||treeDiff.removed||treeDiff.changed)?<span className="mx-current-diff">Current data: +{treeDiff.added} / −{treeDiff.removed} / {treeDiff.changed} changed</span>:null}
      </div>
      {!focused&&applied&&<div className="mx-results-actions"><strong>Tree layout</strong><button onClick={()=>{setResultsFromDraft(false);setStep('results');}}>View matching epochs</button><button className="primary" disabled={busy||tree.loading||!!tree.error} onClick={()=>{setResultsFromDraft(false);setStep('results');prepareDestination('export',false);}}>Export selection</button></div>}
      {!focused&&applied&&<ProtocolApplyPanel initialProtocolId={initialProtocolId} candidate={applied} protocols={protocols} disabled={busy||tree.loading||pagedStatus.loading||!!tree.error||!!pagedStatus.error||changedTree||changedMembership} onApplied={onProtocolApplied}/>}
      <div ref={layoutRef} className="inspection-layout mx-layout resizable-layout" style={{gridTemplateColumns:pane.columns}}><aside className="inspection-tree">
        {tree.data?<TreeBuilder catalogData={tree.data.catalog} value={splits.split(',').filter(Boolean)} onChange={changeSplits} preview={pagedInfo&&pagedInfo.split_order?.join(',')===splits?{...tree.data.tree,...pagedInfo,count:tree.data.matched_count}:tree.data.tree} loading={tree.loading||pagedStatus.loading} error={tree.error||pagedStatus.error}/>:<Status {...tree} retry={()=>setGeneration(value=>value+1)}/>}
      </aside><PaneDivider label="Resize tree editor pane" value={pane.tree} min={240} max={Math.max(240,pane.treeMax)} onChange={setGroupingWidth} onCommit={value=>{try{localStorage.setItem('workspace.explorer.groupingWidth',String(value));}catch{}}}/>{!focused?<Status {...tree} retry={()=>setGeneration(value=>value+1)}>{tree.data&&applied&&<PagedTree predicate={applied.recipe.predicate} splits={splits} revision={`${revision}:${generation}`} design initialNavigation={treeNavigation} onNavigationChange={setTreeNavigation} expectedRevision={tree.data.tree_revision} onRefreshPreview={()=>setGeneration(value=>value+1)} onMetadata={setPagedInfo} onStatus={setPagedStatus} onSelectEpoch={setFocused}/>}</Status>:<div className="inspection-detail"><Status {...epoch} data={focusedInScope&&epoch.data?.epoch_uuid===focused?epoch.data:null} loading={!epoch.error&&!tree.error&&focusState!=='invalid'&&(epoch.loading||focusState==='pending')} error={epoch.error||tree.error||(focusState==='invalid'?'The server did not confirm membership for this epoch. Refresh the preview before inspecting it.':null)} retry={()=>{epoch.reload();setGeneration(value=>value+1);}}>{epoch.data?.epoch_uuid===focused&&focusedInScope&&<>
        <div className="epoch-heading"><div><div className="eyebrow">APPLIED FILTER · READ-ONLY EPOCH</div><h2>{datedCellLabel(epoch.data)}</h2><p>Epoch {epoch.data.epoch_number ?? '—'} within block · {epoch.data.start_time?.split(' ')[1]?.slice(0,8)}</p></div></div>
        <Trace key={epoch.data.epoch_uuid} epoch={epoch.data}/><EpochConnections epoch={epoch.data} contextLabel="Acquisition protocol" protocolName={humanize(epoch.data.protocol_name?.split('.').at(-1)) || 'Not recorded'}/>
        <section className="mx-handoff"><div><strong>Open a different workspace</strong><p>{matches.length?'A predefined workspace has its own saved query. Switching below does not carry this explorer filter, and its inspection/export scope may be broader.':'No predefined workspace matches this recording. The applied explorer scope remains read-only.'}</p></div>
          {matches.map(protocol=><button key={protocol.protocol_uuid} onClick={()=>onInspect?.(protocol.protocol_uuid,epoch.data)}>Switch scope: {humanize(protocol.name)}<ArrowRight size={14}/></button>)}
        </section>
        <Metadata title="Protocol settings · recorded fields" data={epoch.data.parameters}/><Metadata title="Epoch metadata" data={{epoch_uuid:epoch.data.epoch_uuid,source_recording:epoch.data.source_filename,acquisition_protocol:epoch.data.protocol_name,raw_group_label:epoch.data.group_label,...epoch.data.properties,...epoch.data.attributes}}/>
        {['cell','group','block'].map(level=><details className="ancestry-metadata" key={level}><summary>{level[0].toUpperCase()+level.slice(1)} source metadata</summary><Metadata title={`Full ${level} record`} data={epoch.data.metadata?.[level] || {status:'Not recorded'}}/></details>)}
      </>}</Status></div>}</div>
    </>}
  </div>;
}
function SearchIcon(){return <Filter size={15}/>;}
