import {useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {Check,CheckCircle2,Copy,Files,FolderOpen,LoaderCircle,LogOut,Package,ArrowRight,X} from 'lucide-react';
import {api} from '../api.js';
import {localProjectUrl,runProjectTransfer} from '../projectTransfer.js';
import './ProjectFolder.css';

export default function ProjectFolder({project,onClose,onFiles,initialMode='open',onTransferComplete,preferredRoot}){
  const dialog=useRef(null),requestController=useRef(null);
  const [mode,setMode]=useState(initialMode==='restore'?'restore':'prepare');
  const [openPath,setOpenPath]=useState(''),[copied,setCopied]=useState(false),[relocate,setRelocate]=useState(false),[movePath,setMovePath]=useState('');
  const [directory,setDirectory]=useState(initialMode==='restore'?'':project?.path||'');
  const [destination,setDestination]=useState('');
  const [busy,setBusy]=useState(false),[opening,setOpening]=useState(false),[closing,setClosing]=useState(false),[error,setError]=useState(''),[result,setResult]=useState(null);
  useEffect(()=>{const element=dialog.current;element.showModal();return()=>{requestController.current?.abort();element.close();};},[]);
  function chooseMode(next){
    setMode(next);setDirectory(next==='prepare'?project?.path||'':'');setDestination('');setError('');setResult(null);
  }
  async function openDirectory(path){
    setBusy(true);setOpening(true);setError('');
    try{
      await api('/projects/inspect-folder',{method:'POST',body:{directory:path}});
      if(relocate){
        const moved=await api('/projects/relocate',{method:'POST',body:{directory:path,destination:movePath.trim()}});
        path=moved.directory;setOpenPath(path);setRelocate(false);
      }
      const response=await api('/projects/open-folder',{method:'POST',body:{directory:path}});
      window.location.assign(localProjectUrl(response.url,window.location.href));
    }catch(error){setError(error.message);setBusy(false);setOpening(false);}
  }
  async function closeProject(){
    if(busy)return;
    setBusy(true);setClosing(true);setError('');
    try{
      const response=await api('/project/close',{method:'POST',body:{}});
      if(response.state!=='closed')throw new Error('The project did not confirm a clean close. Keep its folder in place.');
      const launcher=new URL(localProjectUrl(response.launcher_url,window.location.href));if(project?.path)launcher.searchParams.set('closed_project',project.path);window.location.assign(launcher.href);
    }catch(error){setError(error.message);setBusy(false);setClosing(false);}
  }
  async function submit(event){
    event.preventDefault();if(busy||!directory.trim())return;
    if(!destination.trim())return;
    setBusy(true);setError('');setResult(null);
    try{
      requestController.current=new AbortController();
      const response=await runProjectTransfer({mode,directory:directory.trim(),destination:destination.trim(),request:api,signal:requestController.current.signal});
      setResult(response);
      onTransferComplete?.({mode,...response});
    }catch(error){setError(`${error.message} If the connection was interrupted, inspect the destination before retrying.`);}
    finally{setBusy(false);}
  }
  async function copyPath(){
    try{await navigator.clipboard.writeText(project.path);setCopied(true);}catch{setError('Could not copy the path. Select the folder path below and copy it.');}
  }
  const preparing=mode==='prepare';
  return createPortal(<dialog ref={dialog} className="project-folder-dialog" aria-labelledby="project-folder-title" onCancel={event=>{event.preventDefault();if(!busy)onClose();}}>
    <header><div className="project-folder-heading"><span className="project-folder-symbol"><FolderOpen size={22}/></span><div><small>YOUR WORKSPACE</small><h2 id="project-folder-title">Project folder</h2></div></div><button autoFocus className="icon-button" aria-label="Close project folders" disabled={busy} onClick={onClose}><X size={18}/></button></header>
    {project&&<section className="project-folder-current">
      <div className="project-folder-name"><h3>{project.name||'Current project'}</h3><span className="project-folder-state"><span/>Open here</span></div>
      <div className="project-folder-path"><code>{project.path||'Project folder unavailable'}</code>{project.path&&<button type="button" className="icon-button" onClick={copyPath} aria-label={copied?'Project path copied':'Copy project path'} title={copied?'Copied':'Copy path'}>{copied?<Check size={16}/>:<Copy size={16}/>}</button>}</div>
      <div className="project-folder-actions">{onFiles&&<button disabled={busy} onClick={()=>{onClose();onFiles();}}><Files size={16}/> View files</button>}{project.database_kind==='native-mysql'&&<button className="project-folder-close" disabled={busy} onClick={closeProject}><LogOut size={16}/> Close project</button>}</div>
      <p>{project.database_kind==='native-mysql'?'To move or share this folder, close the project first, copy the folder, then open it in the receiving app. Linked recordings need to remain accessible.':'Your imports, saved work and exports live here. Recordings linked from another location stay in that location.'}</p>
    </section>}
    <form className="project-folder-open" onSubmit={event=>{event.preventDefault();if(!busy&&openPath.trim()&&(!relocate||movePath.trim()))openDirectory(openPath.trim());}}>
      <div><h3>{project?'Open another project':'Open a project'}</h3><p>Choose a project folder anywhere on this computer. Its required files are checked before opening. Opening in place is the default.</p></div>
      <label htmlFor="open-project-path">Project folder location</label>
      <div className="project-folder-input-row"><input id="open-project-path" required value={openPath} disabled={busy} onChange={event=>{setOpenPath(event.target.value);setError('');}} placeholder="/Users/you/Research/my-project"/><button type="submit" className="primary" disabled={busy||!openPath.trim()||(relocate&&!movePath.trim())}><FolderOpen size={16}/> {relocate?'Move & open project':'Open project'}</button></div>
      <details className="project-folder-organize"><summary>Optional: move to a preferred location</summary>
        <p>Only closed projects can move. Keep the folder intact; moving across disks requires closing and copying it with your file manager.</p>
        <label><input type="checkbox" checked={relocate} disabled={busy} onChange={event=>{setRelocate(event.target.checked);if(event.target.checked&&!movePath&&preferredRoot&&openPath.trim())setMovePath(`${preferredRoot.replace(/\/$/,'')}/${openPath.trim().replace(/\/$/,'').split('/').pop()}`);}}/> Move this folder before opening</label>
        {relocate&&<label>Destination project folder<input required value={movePath} disabled={busy} onChange={event=>setMovePath(event.target.value)} placeholder={preferredRoot?`${preferredRoot}/my-project`:'/absolute/path/to/preferred-projects/my-project'}/><small>The destination must not exist. The whole folder moves without changing its contents.</small></label>}
      </details>
    </form>
    <details className="project-folder-advanced" open={initialMode!=='open'||undefined}>
      <summary onClick={event=>{if(busy)event.preventDefault();}}><Package size={16}/><span>Advanced sharing<small>Include linked recordings or restore a prepared copy</small></span></summary>
      <nav className="project-folder-modes" aria-label="Advanced sharing action">{[['prepare','Prepare to share'],['restore','Open prepared copy']].map(([value,label])=><button key={value} type="button" aria-pressed={mode===value} disabled={busy} onClick={()=>chooseMode(value)}>{label}</button>)}</nav>
      <form onSubmit={submit} aria-busy={busy}>
        <label htmlFor="existing-project-folder">{preparing?'Project folder to share':'Prepared transfer folder'}</label><input id="existing-project-folder" required value={directory} disabled={busy} onChange={event=>{setDirectory(event.target.value);setResult(null);}} placeholder="/absolute/path/to/project"/>
        <p>{preparing?'Close the project before preparing it from the project chooser. This optional copy includes one project’s database and recordings. Closing a browser tab does not close the project.':'Select the prepared folder you received. Its files and database are verified before the new local project becomes available.'}</p>
        <label htmlFor="project-transfer-destination">{preparing?'New shared copy location':'New local project location'}</label><input id="project-transfer-destination" required value={destination} disabled={busy} onChange={event=>{setDestination(event.target.value);setResult(null);}} placeholder="/absolute/path/to/new-folder"/>
        <p>Choose a folder that does not yet exist. Large projects can take several minutes.</p>
        {result?<section className="project-folder-success" role="status"><strong><CheckCircle2 size={16}/>{preparing?'Verified copy is ready':'Project restored and verified'}</strong><code>{result.directory}</code><p>{preparing?'Give the entire folder to the recipient. They can choose Advanced sharing → Open prepared copy.':'Your local project is ready to open.'}</p>{!preparing&&<button type="button" className="primary" disabled={busy} onClick={()=>openDirectory(result.directory)}>Open restored project <ArrowRight size={15}/></button>}</section>:<footer><button className="primary" disabled={busy||!directory.trim()||!destination.trim()}>{preparing?'Prepare to share':'Restore project'}<ArrowRight size={15}/></button></footer>}
      </form>
    </details>
    {busy&&<p className="project-folder-progress" role="status"><LoaderCircle size={16} className="spin"/>{closing?'Closing the project and stopping its database…':opening?'Opening project…':preparing?'Copying files and verifying the database backup…':'Verifying files and restoring the project…'} Keep this window open.</p>}
    {error&&<p className="project-folder-error" role="alert">{error}</p>}
    <div className="project-folder-bottom"><span>{copied?'Project path copied':project?'Your project files stay on this computer.':'The app and your project files stay separate.'}</span><button disabled={busy} onClick={onClose}>Done</button></div>
  </dialog>,document.body);
}
