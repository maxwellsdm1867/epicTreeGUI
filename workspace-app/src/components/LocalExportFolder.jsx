import {useState} from 'react';
import {FolderOpen,Copy} from 'lucide-react';

export default function LocalExportFolder({path}){
  const [message,setMessage]=useState('');
  if(!path)return null;
  async function copy(){try{await navigator.clipboard.writeText(path);setMessage('Folder path copied.');}catch{setMessage('Select and copy the folder path below.');}}
  return <section className="section local-export-folder"><h2><FolderOpen size={18}/> Local export folder</h2>
    <p>Point Wheeler, MATLAB, or another service here once. All this project’s exports stay together.</p>
    <div><code>{path}</code><button onClick={copy}><Copy size={14}/> Copy folder path</button></div>
    <small>Tags return through each export’s annotations folder. Refresh metadata checks updated selection masks here.</small>
    {message&&<p role="status">{message}</p>}
  </section>;
}
