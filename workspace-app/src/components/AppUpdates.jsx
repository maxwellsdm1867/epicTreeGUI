import {useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {ArrowUpCircle,RefreshCw,X} from 'lucide-react';
import {api} from '../api.js';
import {updateNotice,releaseLink,updateLabel,watchAppUpdates} from '../appUpdates.js';
import './AppUpdates.css';

function UpdateDialog({status,busy,error,onCheck,onClose,onDownload,download}){
  const dialog=useRef(null);
  useEffect(()=>{dialog.current.showModal();const element=dialog.current;return()=>element.close();},[]);
  const installed=typeof status?.installed==='string'?status.installed:status?.installed?.version;
  const notice=updateNotice(status),url=releaseLink(status?.release_url);
  return createPortal(<dialog ref={dialog} className="app-update-dialog" aria-labelledby="app-update-title" onCancel={event=>{event.preventDefault();onClose();}}>
    <header><h2 id="app-update-title">Rieke OS updates</h2><button autoFocus className="icon-button" aria-label="Close updates" onClick={onClose}><X size={18}/></button></header>
    <p>Installed version: <strong>{installed||'Development checkout'}</strong></p>
    <p className="app-update-automatic">Updates are checked automatically when you open the app and every 15 minutes while it is visible.</p>
    <p role="status">{busy?'Checking for updates…':notice?.message||status?.message||'Check for a published Rieke OS release.'}</p>
    {error&&<p role="alert" className="error">{error}</p>}
    {notice&&!status?.can_stage&&<p>Automatic installation is not available for this installation. Review the release instructions before updating.</p>}
    {download?.state==='running'&&<p role="status">Downloading and verifying the update. The current app remains active.</p>}
    {download?.state==='complete'&&<div role="status"><p>{download.result?.message||'Update downloaded and verified.'}</p>{download.result?.apply_command&&<code>{download.result.apply_command}</code>}</div>}
    {download?.state==='failed'&&<p role="alert">{download.error}</p>}
    {status?.checked_at&&<small>Last checked: {new Date(status.checked_at).toLocaleString()}</small>}
    <footer>{url&&<a href={url} target="_blank" rel="noopener noreferrer">Release notes</a>}{notice&&status.can_stage&&<button disabled={busy||['running','complete'].includes(download?.state)} onClick={onDownload}>Download update</button>}<button disabled={busy} onClick={onCheck}><RefreshCw size={14} className={busy?'spin':''}/> Check for updates</button></footer>
  </dialog>,document.body);
}

export default function AppUpdates(){
  const [status,setStatus]=useState(null),[busy,setBusy]=useState(false),[error,setError]=useState(''),[open,setOpen]=useState(false),[dismissed,setDismissed]=useState(null);
  const alive=useRef(false),checking=useRef(false);
  const [download,setDownload]=useState(null);
  async function check(force=false){
    if(checking.current)return;checking.current=true;setBusy(true);setError('');
    try{const result=await api('/app/updates/check',{method:'POST',body:force?{force:true}:{}});if(alive.current){setStatus(result);if(result.download)setDownload(result.download);}}
    catch(error){if(alive.current){setError(error.message);setStatus(previous=>({...previous,state:'error',message:'Could not check for updates. The current app remains usable.'}));}}
    finally{checking.current=false;if(alive.current)setBusy(false);}
  }
  async function stage(){
    setError('');
    try{const result=await api('/app/updates/stage',{method:'POST',body:{},headers:{'X-Rieke-Update-Token':status.update_token}});if(alive.current)setDownload(result);}
    catch(error){if(alive.current)setError(error.message);}
  }
  useEffect(()=>{
    if(download?.state!=='running')return;
    let cancelled=false,timer;
    async function poll(){try{const result=await api('/app/updates/download');if(!cancelled){setError('');setDownload(result);if(result.state==='running')timer=setTimeout(poll,1500);}}catch(error){if(!cancelled){setError(`Update status unavailable: ${error.message}`);timer=setTimeout(poll,5000);}}}
    timer=setTimeout(poll,1000);return()=>{cancelled=true;clearTimeout(timer);};
  },[download?.state]);
  useEffect(()=>{alive.current=true;const stop=watchAppUpdates(()=>check());return()=>{alive.current=false;stop();};},[]);
  const notice=updateNotice(status);
  return <><button className={`app-update-button ${notice?'has-update':''}`} onClick={()=>setOpen(true)} title={notice?.message||status?.message||'App updates'} aria-label={notice?.message||updateLabel(status,busy)}><ArrowUpCircle size={16}/><span>{updateLabel(status,busy)}</span></button>
    {notice&&dismissed!==notice.version&&<div className="app-update-notice" role="status"><ArrowUpCircle size={18}/><div><strong>{notice.message}</strong><button onClick={()=>setOpen(true)}>View update</button></div><button className="icon-button" aria-label="Dismiss update notification" onClick={()=>setDismissed(notice.version)}><X size={15}/></button></div>}
    {open&&<UpdateDialog status={status} busy={busy} error={error} onCheck={()=>check(true)} onDownload={stage} download={download} onClose={()=>setOpen(false)}/>}</>;
}
