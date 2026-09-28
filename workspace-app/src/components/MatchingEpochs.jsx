import {useEffect,useRef,useState} from 'react';
import {ArrowLeft,ArrowRight,PanelRightOpen} from 'lucide-react';
import {api,useResource,number,humanize} from '../api.js';
import {epochArrowDirection,nextEpochAction,inspectorPaneSizes} from '../inspectorInteraction.js';
import {datedCellLabel} from '../recordingIdentity.js';
import {Trace} from './Inspector.jsx';
import EpochSkimList from './EpochSkimList.jsx';
import MetadataPanel from './MetadataPanel.jsx';
import EpochConnections from './EpochConnections.jsx';
import PaneDivider from './PaneDivider.jsx';
import {Status} from './Common.jsx';
import './MatchingEpochs.css';

export default function MatchingEpochs({predicate,splits,preview,onRefresh,session,onSession}){
  const saved=useRef(session?.revision===preview.tree_revision?session:null).current;
  const [offset,setOffset]=useState(saved?.offset||0),[focused,setFocused]=useState(saved?.focused||null),[edge,setEdge]=useState(null);
  const [page,setPage]=useState({data:null,loading:true,error:null}),[reload,setReload]=useState(0),[metadataOpen,setMetadataOpen]=useState(true);
  const [width,setWidth]=useState(1200),[sizes,setSizes]=useState({tree:360,metadata:330});
  const layout=useRef(null),list=useRef(null),callbacks=useRef({onSession});callbacks.current={onSession};
  const pane=inspectorPaneSizes(width,sizes,true,metadataOpen);
  const key=JSON.stringify({predicate,splits,revision:preview.tree_revision,offset,reload});
  useEffect(()=>{const observer=new ResizeObserver(entries=>setWidth(entries[0].contentRect.width));if(layout.current)observer.observe(layout.current);return()=>observer.disconnect();},[]);
  useEffect(()=>{
    const controller=new AbortController();setPage({data:null,loading:true,error:null});
    const body=JSON.parse(key);delete body.reload;body.limit=60;
    api('/explore/epochs',{method:'POST',body,signal:controller.signal}).then(data=>{if(!controller.signal.aborted)setPage({data,loading:false,error:null,key});}).catch(error=>{if(!controller.signal.aborted)setPage({data:null,loading:false,error:error.message});});
    return()=>controller.abort();
  },[key]);
  useEffect(()=>{if(!page.data||page.loading||page.key!==key)return;const rows=page.data.epochs;if(edge||!rows.some(row=>row.epoch_uuid===focused)){setFocused(rows[edge==='last'?rows.length-1:0]?.epoch_uuid||null);setEdge(null);}},[page.data,page.loading,page.key,key,edge,focused]);
  useEffect(()=>{callbacks.current.onSession?.({revision:preview.tree_revision,offset,focused});},[preview.tree_revision,offset,focused]);
  useEffect(()=>{list.current?.querySelector('.epoch-row.active')?.scrollIntoView({block:'nearest'});},[focused,page.data]);
  const currentPage=page.key===key&&!page.loading&&!page.error;
  const inPage=currentPage&&page.data?.epochs.some(row=>row.epoch_uuid===focused)&&!page.error;
  const epoch=useResource(inPage?`/epochs/${focused}`:null,preview.tree_revision),detail=inPage&&epoch.data?.epoch_uuid===focused?epoch.data:null;
  const index=page.data?.epochs.findIndex(row=>row.epoch_uuid===focused)??-1;
  function move(direction){if(!currentPage)return;const next=nextEpochAction({epochs:page.data?.epochs,offset,total:page.data?.total,focused,direction});if(next.kind==='focus')setFocused(next.epoch_uuid);if(next.kind==='page'){setEdge(next.edge);setOffset(next.offset);}}
  return <section className="inspector epoch-inspector-mode matching-epochs" tabIndex={0} aria-label="Matching epoch inspection" onKeyDown={event=>{const direction=epochArrowDirection(event);if(direction){event.preventDefault();move(direction);}}}>
    <div className="matching-scope"><strong>{number(preview.matched_count)} matching epochs</strong><span>{number(preview.catalog?.fields?.find(field=>field.id==='cell')?.recorded_distinct_count)} cells · {number(preview.catalog?.fields?.find(field=>field.id==='date')?.recorded_distinct_count)} dates</span>{!metadataOpen&&<button onClick={()=>setMetadataOpen(true)}><PanelRightOpen size={14}/> Show metadata</button>}</div>
    {page.error&&<div className="mx-operation-error" role="alert">{page.error}<button onClick={onRefresh}>Refresh predicate results</button></div>}
    <div ref={layout} className={`inspection-layout resizable-layout ${metadataOpen?'metadata-open':''} ${pane.overlay?'metadata-overlay':''}`} style={{gridTemplateColumns:pane.columns,'--metadata-width':`${pane.metadata}px`}}>
      <aside className="inspection-tree"><div className="matching-list-heading"><strong>Date · cell · epochs</strong><span>Time / acquisition protocol</span></div><div className="tree-scroll" ref={list}><Status {...page} data={currentPage?page.data:null} loading={!currentPage&&!page.error} retry={()=>setReload(value=>value+1)}><EpochSkimList epochs={page.data?.epochs||[]} offset={offset} focused={focused} onFocus={setFocused} disabled={!currentPage} selectable={false} showProtocol/></Status></div><div className="pagination"><button aria-label="Previous matching epoch page" disabled={!currentPage||offset===0} onClick={()=>{setEdge('first');setOffset(Math.max(0,offset-60));}}><ArrowLeft size={14}/></button><span>{page.data?.total?offset+1:0}–{Math.min(offset+60,page.data?.total||0)} / {number(page.data?.total)}</span><button aria-label="Next matching epoch page" disabled={!currentPage||!page.data?.has_more} onClick={()=>{setEdge('first');setOffset(offset+60);}}><ArrowRight size={14}/></button></div></aside>
      <PaneDivider label="Resize matching epoch list" value={pane.tree} min={180} max={pane.treeMax} onChange={tree=>setSizes(old=>({...old,tree}))}/>
      <div className="inspection-detail"><Status {...epoch} data={detail} retry={epoch.reload}>{detail?<><div className="epoch-heading"><div><h2>{datedCellLabel(detail)}</h2><p>{humanize(detail.protocol_name?.split('.').at(-1))} · Epoch {detail.epoch_number} within block</p></div></div><div className="epoch-navigation"><button disabled={offset+index<=0||page.loading} onClick={()=>move(-1)}><ArrowLeft size={14}/> Previous epoch</button><span>Epoch {offset+index+1} of {number(page.data?.total)}</span><button disabled={page.loading||offset+index+1>=page.data?.total} onClick={()=>move(1)}>Next epoch<ArrowRight size={14}/></button></div><Trace key={focused} epoch={detail}/></>:<p>Select a matching epoch to inspect its trace.</p>}</Status></div>
      {metadataOpen&&<><PaneDivider label="Resize matching metadata" value={pane.metadata} min={240} max={pane.metadataMax} reverse className={pane.overlay?'metadata-overlay-divider':''} style={pane.overlay?{right:pane.metadata}:undefined} onChange={metadata=>setSizes(old=>({...old,metadata}))}/><MetadataPanel epoch={detail} catalog={{data:preview.catalog}} onClose={()=>setMetadataOpen(false)} connections={detail&&<EpochConnections epoch={detail} protocolName={humanize(detail.protocol_name)} contextLabel="Acquisition protocol"/>}/></>}
    </div>
  </section>;
}
