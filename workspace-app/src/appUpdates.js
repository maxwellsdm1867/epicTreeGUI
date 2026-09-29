const releaseRoot='https://github.com/maxwellsdm1867/epicTreeGUI/releases';
export function releaseLink(value){
  if(typeof value!=='string')return null;
  try{const url=new URL(value);return url.origin==='https://github.com'&&(url.pathname==='/maxwellsdm1867/epicTreeGUI/releases'||url.pathname.startsWith('/maxwellsdm1867/epicTreeGUI/releases/tag/'))&&!url.username&&!url.password?url.href:null;}catch{return null;}
}
export function updateNotice(status){
  const version=typeof status?.available==='string'?status.available:status?.available?.version;
  return status?.state==='update_available'&&version?{version,message:`Rieke OS ${version} is available`,url:releaseLink(status.release_url)||releaseRoot}:null;
}

export function updateLabel(status,busy=false){
  if(busy&&!status)return 'Checking for updates…';
  if(updateNotice(status))return 'Update available';
  return ({up_to_date:'Up to date',unavailable:'No release published',error:'Update check unavailable'})[status?.state]||'App updates';
}

export function watchAppUpdates(check,{interval=15*60*1000,setTimer=setInterval,clearTimer=clearInterval,documentObject=globalThis.document,now=Date.now}={}){
  let lastCheck=0;
  const run=()=>{lastCheck=now();check();};
  const visible=()=>{if(documentObject?.visibilityState==='visible'&&now()-lastCheck>=interval)run();};
  run();
  const timer=setTimer(()=>{if(!documentObject||documentObject.visibilityState==='visible')run();},interval);
  documentObject?.addEventListener('visibilitychange',visible);
  return()=>{clearTimer(timer);documentObject?.removeEventListener('visibilitychange',visible);};
}
