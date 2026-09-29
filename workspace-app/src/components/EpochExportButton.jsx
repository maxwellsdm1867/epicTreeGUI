import {useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {Download,X} from 'lucide-react';
import {api} from '../api.js';
import {epochExportOptions,epochExportPredicate} from '../epochExport.js';
import './ExportSelectionDialog.css';

function EpochExportDialog({epoch,protocolId,queryRevision,filters,splits,predicate,onClose,onExported}){
  const dialog=useRef(null),inFlight=useRef(false);
  const [format,setFormat]=useState('wheeler-sqlite'),[busy,setBusy]=useState(false),[error,setError]=useState(''),[result,setResult]=useState(null);
  useEffect(()=>{dialog.current.showModal();return()=>dialog.current?.close();},[]);
  async function run(){
    if(inFlight.current)return;
    inFlight.current=true;setBusy(true);setError('');setResult(null);
    try{
      let receipt;
      if(protocolId){
        receipt=await api(`/protocols/${protocolId}/exports`,{method:'POST',body:epochExportOptions(epoch,format,{filters,splits,queryRevision})});
      }else{
        const candidate=await api('/explore/revisions',{method:'POST',body:{predicate:epochExportPredicate(predicate,epoch.epoch_uuid),splits,summary_only:true,name:`${epoch.cell_label||'Recording'} · epoch ${epoch.epoch_number??epoch.epoch_uuid}`}});
        if(candidate.recipe.epoch_count!==1)throw new Error('This epoch no longer matches the search. Refresh the results before exporting.');
        receipt=await api(`/explore/revisions/${candidate.revision_uuid}/exports`,{method:'POST',body:{format,expected_recipe_sha256:candidate.recipe.full_recipe_sha256}});
      }
      if(receipt.epoch_count!==1||typeof receipt.download_url!=='string'||!receipt.download_url.startsWith('/api/exports/')||typeof receipt.dataset_uuid!=='string')throw new Error('The server did not return a complete export receipt. Check Activity & logs before retrying.');
      setResult(receipt);onExported?.(receipt);
    }catch(failure){setError(failure.message);}finally{inFlight.current=false;setBusy(false);}
  }
  return createPortal(<dialog ref={dialog} className="export-selection-dialog" aria-labelledby="epoch-export-title" onCancel={event=>{event.preventDefault();if(!busy)onClose();}}><header><h2 id="epoch-export-title"><Download size={17}/> Export epoch</h2><button className="icon-button" aria-label="Close epoch export" disabled={busy} onClick={onClose}><X size={17}/></button></header><div className="export-selection-body"><p>Export only this epoch, with its recording metadata and linked H5 source.</p><label>Format <select value={format} disabled={busy} onChange={event=>setFormat(event.target.value)}><option value="wheeler-sqlite">SQLite database</option><option value="epictree-mat">EpicTree / MATLAB</option></select></label><p><button className="primary" disabled={busy} onClick={run}>{busy?'Preparing export…':'Export epoch'}</button></p>{error&&<p role="alert">{error}</p>}{result&&<p role="status">1 epoch exported · <a href={result.download_url} download>Download {format==='epictree-mat'?'MATLAB bundle':'SQLite database'}</a></p>}</div></dialog>,document.body);
}

export default function EpochExportButton({epoch,disabled=false,...scope}){
  const [open,setOpen]=useState(false);
  const excluded=!!scope.protocolId&&epoch?.curation?.included===false;
  return <><button disabled={disabled||!epoch||excluded} title={excluded?'Include this epoch before exporting it from this protocol':'Export this epoch'} onClick={()=>setOpen(true)}><Download size={14}/> Export</button>{open&&<EpochExportDialog key={epoch.epoch_uuid} epoch={epoch} {...scope} onClose={()=>setOpen(false)}/>}</>;
}
