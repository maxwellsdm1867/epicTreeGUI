import {useEffect,useState} from 'react';
import {Activity,ArrowRight,FolderOpen,LoaderCircle,Plus,Folder,MapPin,ShieldCheck,X} from 'lucide-react';
import {api} from '../api.js';
import {projectColor} from './ProjectNavigator.jsx';
import './ProjectOnboarding.css';

export default function ProjectOnboarding({registry,onSelect,onCreated,onCancel,onWorkspaceChanged,onOpenProject,createOnly=false,loading=false,error=null}){
  const [creating,setCreating]=useState(createOnly),[name,setName]=useState(''),[directory,setDirectory]=useState(''),[busy,setBusy]=useState(false),[failure,setFailure]=useState(''),[created,setCreated]=useState(null);
  const [selectedRegistry,setSelectedRegistry]=useState(null),[rootEditing,setRootEditing]=useState(false),[rootPath,setRootPath]=useState(registry?.managed_root||''),[rootMessage,setRootMessage]=useState('');
  const currentRegistry=selectedRegistry||registry;
  const projects=currentRegistry?.projects||[];
  const recent=projects.filter(item=>item.uuid===currentRegistry?.last_project_uuid),last=recent.length===1?recent[0]:null;
  const needsRoot=registry?.launcher&&!currentRegistry?.workspace_initialized&&!projects.length;
  useEffect(()=>{if(needsRoot)setRootEditing(true);},[needsRoot]);
  useEffect(()=>{if(selectedRegistry&&registry?.managed_root===selectedRegistry.managed_root&&registry?.workspace_initialized===selectedRegistry.workspace_initialized)setSelectedRegistry(null);},[registry,selectedRegistry]);
  async function chooseRoot(event){
    event.preventDefault();if(busy||!rootPath.trim())return;setBusy(true);setFailure('');setRootMessage('');
    try{const result=await api('/workspace',{method:'POST',body:{directory:rootPath.trim()}});setSelectedRegistry(result);setRootPath(result.managed_root);setRootEditing(false);setCreating(false);setCreated(null);setRootMessage(`${result.projects.length} existing project${result.projects.length===1?'':'s'} found. This workspace is ready.`);onWorkspaceChanged?.();}
    catch(error){setFailure(error.message);}finally{setBusy(false);}
  }
  async function create(event){
    event.preventDefault();if(busy||!name.trim()||!directory.trim())return;
    setBusy(true);setFailure('');
    try{const result=await api('/projects',{method:'POST',body:{name:name.trim(),...(directory.trim()?{project_directory:directory.trim()}:{})}});if(!result.project?.uuid)throw new Error('The server did not return a project identity. Refresh the project list before retrying.');setCreated(result.project);await onCreated?.(result.project);}
    catch(error){setFailure(error.message);}finally{setBusy(false);}
  }
  return <section className={`project-onboarding ${createOnly?'creation-only':''}`} aria-label="Project setup">
    <header><span className="onboarding-mark"><Activity size={23}/></span><div><small>RIEKE OS</small><h1>{creating?'Create a project':'Your projects'}</h1></div>{onCancel&&<button className="icon-button" onClick={onCancel} disabled={busy} aria-label="Close project setup"><X size={19}/></button>}</header>
    <p>{creating?'Start with an empty project. Add recordings whenever you are ready.':'Open a project folder to pick up where you left off. Your recordings, saved work and exports stay with your project.'}</p>
    {(error||failure)&&<div className="onboarding-error" role="alert">{failure||error}</div>}
    {!creating&&!created&&<div className="onboarding-main-actions">{onOpenProject&&<button className="primary" disabled={loading||busy} onClick={onOpenProject}><FolderOpen size={17}/> Open project</button>}<button disabled={loading||busy} onClick={()=>setCreating(true)}><Plus size={17}/> New project</button></div>}
    {!creating&&<div className="onboarding-root"><MapPin size={17}/><div><small>PREFERRED PROJECTS LOCATION</small><strong>{currentRegistry?.managed_root||'Loading workspace location…'}</strong><span>An optional place to organize projects. You can create or open a project anywhere.</span></div>{registry?.launcher&&<button disabled={busy||loading} onClick={()=>{setRootPath(currentRegistry?.managed_root||'');setRootEditing(value=>!value);}}>{rootEditing?'Cancel':'Change'}</button>}</div>}
    {!creating&&rootEditing&&<form className="onboarding-root-form" onSubmit={chooseRoot}><label>Workspace root directory<input autoFocus value={rootPath} disabled={busy} onChange={event=>setRootPath(event.target.value)} placeholder="/absolute/path/to/research-workspace"/></label><p>Use an existing workspace or a new folder. Existing project files are preserved; new projects get their own subfolders.</p><button className="primary" disabled={busy||!rootPath.trim()}>{busy?'Checking workspace…':'Use this workspace'}</button></form>}
    {rootMessage&&<p role="status">{rootMessage}</p>}
    {created?<div className="onboarding-created" role="status"><strong>{created.name} was created.</strong><span>{created.path}</span><p role={loading?'status':undefined}>{loading?<><LoaderCircle size={15} className="spin"/> Preparing the project database and opening the workspace…</>:'No H5 file is required. Open the project to add recordings when ready.'}</p><div className="onboarding-actions"><button disabled={loading} className="primary" onClick={()=>onSelect?.(created)}>Open project <ArrowRight size={15}/></button>{!createOnly&&<button disabled={loading} onClick={()=>{setCreated(null);setCreating(false);setFailure('');}}>Back to projects</button>}</div></div>:creating?<form onSubmit={create}>
      <label>Project name<input autoFocus required maxLength={120} value={name} disabled={busy} onChange={event=>setName(event.target.value)} placeholder="e.g. Spike response study"/></label>
      <label>Project folder <small>Use this folder as the project root</small><input value={directory} disabled={busy} onChange={event=>setDirectory(event.target.value)} placeholder="/absolute/path/to/my-project"/></label>
      <div className="onboarding-location"><FolderOpen size={16}/><span><strong>{directory.trim()||'Choose a new or empty folder anywhere on this computer.'}</strong><small>Project files are stored directly here. To use an existing project, choose Open project instead.</small></span></div>
      <footer>{!createOnly&&<button type="button" disabled={busy} onClick={()=>setCreating(false)}>Back to projects</button>}<button type="submit" className="primary" disabled={busy||!name.trim()||!directory.trim()}>{busy?<><LoaderCircle size={15} className="spin"/> Creating project…</>:<>Create & open project <ArrowRight size={15}/></>}</button></footer>
    </form>:<>
      <div className="onboarding-list-heading"><h2>Projects in this location</h2><span>{projects.length} project{projects.length===1?'':'s'}</span></div>
      {loading&&<p role="status"><LoaderCircle size={15} className="spin"/> Opening project and preparing its database…</p>}
      <div className="onboarding-project-list">{projects.map(project=><button key={project.path||project.uuid} disabled={loading||!project.available} onClick={()=>onSelect?.(project)}><span className="onboarding-project-icon" style={projectColor(project.uuid)}><Folder size={21}/></span><span className="onboarding-project-info"><strong>{project.name}{project.path===last?.path&&<em>Recent</em>}</strong><small>{project.path}</small>{!project.available&&<small className="onboarding-unavailable">{project.unavailable_reason||'This project needs attention before opening.'}</small>}</span><span className="onboarding-project-open">{project.available?'Open':'Unavailable'}<ArrowRight size={15}/></span></button>)}</div>
      <p className="onboarding-profile-note"><ShieldCheck size={14}/> Moving a project? Close it first, copy its folder, then open the copy here.</p>{!projects.length&&<div className="onboarding-empty"><FolderOpen size={28}/><strong>No projects yet</strong><span>Create a new project or open an existing folder. Add recordings whenever you are ready.</span></div>}
    </>}
  </section>;
}
