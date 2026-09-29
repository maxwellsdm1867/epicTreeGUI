// A transfer response must affirm verification before the UI offers its output.
export function verifiedTransferResult(result) {
  if (result?.verified !== true || typeof result.directory !== 'string' || !result.directory.trim()) {
    throw new Error('The server did not confirm a verified project folder. Check the destination before retrying.');
  }
  return result;
}

export function localProjectUrl(url, base) {
  if (typeof url !== 'string') throw new Error('The project service did not return an app URL.');
  const destination = new URL(url, base);
  if (!['http:', 'https:'].includes(destination.protocol) ||
      !['127.0.0.1', 'localhost', '[::1]'].includes(destination.hostname) ||
      destination.username || destination.password) {
    throw new Error('The project service returned an invalid local URL.');
  }
  return destination.href;
}

export async function runProjectTransfer({mode,directory,destination,request,signal,pause=ms=>new Promise(resolve=>setTimeout(resolve,ms))}) {
  if (!['prepare','restore'].includes(mode)) throw new Error('Unknown project transfer action.');
  const job=await request(mode==='prepare'?'/projects/prepare-transfer':'/projects/restore-transfer',{
    method:'POST',body:{directory,destination},signal,
  });
  if(typeof job?.job_id!=='string'||!job.job_id) throw new Error('The server did not return a transfer job.');
  while(!signal?.aborted){
    const status=await request(`/projects/transfers/${encodeURIComponent(job.job_id)}`,{signal});
    if(status.state==='complete')return verifiedTransferResult(status.result);
    if(status.state==='failed')throw new Error(status.error||'The project transfer failed.');
    if(status.state!=='running')throw new Error('The server returned an unknown transfer state.');
    await pause(1000);
  }
  throw new Error('Transfer monitoring stopped. The server operation may still be running.');
}
