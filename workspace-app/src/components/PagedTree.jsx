import {lazy,Suspense,useCallback,useRef,useState,useEffect} from 'react';
const ColumnTree=lazy(()=>import('./ColumnTree.jsx'));
import {api} from '../api.js';
import {treePageRequest} from '../pagedTreeRequest.js';
import {mergeEpochSelection,toggleEpochSelection} from '../epochSelection.js';
import HierarchyTree from './HierarchyTree.jsx';
import './PagedTree.css';

// Both presentations share exact scope and bounded server pages.
export default function PagedTree(props){
  const [preferredView,setView]=useState(props.initialNavigation?.treeView||'tree');
  // A compact inspection sidebar must never restore a saved column layout.
  const view=props.presentation||preferredView;
  const remembered=useRef({hierarchyNavigation:props.initialNavigation?.hierarchyNavigation||null,columnNavigation:props.initialNavigation?.columnNavigation||props.initialNavigation||null});
  const callbacks=useRef(props);callbacks.current=props;
  const remember=useCallback(navigation=>{remembered.current[view==='tree'?'hierarchyNavigation':'columnNavigation']=navigation;callbacks.current.onNavigationChange?.({...remembered.current,treeView:view});},[view]);
  function changeView(next){setView(next);callbacks.current.onNavigationChange?.({...remembered.current,treeView:next});}
  const anchor=useRef(null),selectionRequest=useRef(null);
  const [selectionError,setSelectionError]=useState('');
  useEffect(()=>()=>selectionRequest.current?.abort(),[]);
  async function selectCell(item,field,revision){
    if(field?.field!=='cell'||!props.onSelectCell)return;
    const request=new AbortController();selectionRequest.current?.abort();selectionRequest.current=request;
    setSelectionError('');anchor.current=null;
    try{
      let page=await api('/tree-pages',{method:'POST',signal:request.signal,body:treePageRequest(props,{path:item.path,currentRevision:revision})});
      while(page.kind!=='epochs'&&page.branches?.length){
        page=await api('/tree-pages',{method:'POST',signal:request.signal,body:treePageRequest(props,{path:page.branches[0].path,currentRevision:page.revision})});
      }
      if(!request.signal.aborted&&page.epochs?.[0])props.onSelectCell(item.value,page.epochs[0]);
    }catch(error){if(error.name!=='AbortError')setSelectionError(error.message);}
  }
  async function selectEpoch(uuid,item,event,page,index){
    selectionRequest.current?.abort();setSelectionError('');
    props.onSelectEpoch?.(uuid,item);
    if(!props.setSelectedEpochs||!event)return;
    const target={uuid,index:page.offset+index,path:page.path,revision:page.revision};
    try{
      if(event.shiftKey&&anchor.current){
        if(JSON.stringify(anchor.current.path)!==JSON.stringify(page.path)||anchor.current.revision!==page.revision)throw new Error('Select a range within one tree branch, or use Command/Ctrl-click across branches.');
        const lo=Math.min(anchor.current.index,target.index),hi=Math.max(anchor.current.index,target.index);
        if(hi-lo+1>1000)throw new Error('Select at most 1,000 epochs.');
        const request=new AbortController();selectionRequest.current=request;const ids=[];
        for(let offset=Math.floor(lo/60)*60;offset<=hi;offset+=60){
          const part=offset===page.offset?page:await api('/tree-pages',{method:'POST',signal:request.signal,body:treePageRequest(props,{path:page.path,offset,currentRevision:page.revision})});
          if(part.revision!==page.revision||part.kind!=='epochs')throw new Error('Tree changed. Select the range again.');
          for(let n=Math.max(lo,offset);n<=Math.min(hi,offset+59);n++){
            const row=part.epochs[n-offset];if(!row)throw new Error('Could not load the complete range.');
            ids.push(row.epoch_uuid);
          }
        }
        if(!request.signal.aborted)props.setSelectedEpochs(mergeEpochSelection(props.selectedEpochs||[],ids));
      }else{
        anchor.current=target;
        props.setSelectedEpochs(event.metaKey||event.ctrlKey?toggleEpochSelection(props.selectedEpochs||[],uuid):[]);
      }
    }catch(error){if(error.name!=='AbortError')setSelectionError(error.message);}
  }
  const selectionProps={onSelectEpoch:selectEpoch,onSelectBranch:selectCell};
  return <div className="tree-view-workspace">{selectionError&&<p role="alert">{selectionError}</p>}{!props.presentation&&<div className="tree-view-switch" role="group" aria-label="Tree presentation"><button aria-pressed={view==='tree'} className={view==='tree'?'active':''} onClick={()=>changeView('tree')}>Expandable tree</button><button aria-pressed={view==='columns'} className={view==='columns'?'active':''} onClick={()=>changeView('columns')}>Columns</button></div>}{view==='tree'?<HierarchyTree {...props} {...selectionProps} initialNavigation={remembered.current.hierarchyNavigation} onNavigationChange={remember}/>:<Suspense fallback={<div className="pt-page-heading" role="status">Loading column view…</div>}><ColumnTree {...props} {...selectionProps} initialNavigation={remembered.current.columnNavigation} onNavigationChange={remember}/></Suspense>}</div>;
}
