import {useState} from 'react';

export default function ProjectClosedNotice(){
  const [path,setPath]=useState(()=>new URLSearchParams(window.location.search).get('closed_project'));
  const [copied,setCopied]=useState(false),[error,setError]=useState('');
  if(!path)return null;
  async function copy(){try{await navigator.clipboard.writeText(path);setCopied(true);}catch{setError('Select the folder path below and copy it.');}}
  function dismiss(){setPath(null);const url=new URL(window.location.href);url.searchParams.delete('closed_project');window.history.replaceState(window.history.state,'',url);}
  return <section className="project-closed-notice" role="status"><strong>Project closed</strong><p>You can now copy the entire folder. On the other computer, choose <b>Open project</b> and select that folder.</p><code>{path}</code><p>Include all project files. Older linked recordings must also be available.</p><button onClick={copy}>{copied?'Folder path copied':'Copy folder path'}</button> <button onClick={dismiss}>Dismiss</button>{error&&<p>{error}</p>}</section>;
}
