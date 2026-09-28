import {spawn, spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {homedir} from 'node:os';
import {dirname, resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const appDir=dirname(fileURLToPath(import.meta.url));
const repository=resolve(appDir,'..');
const retinanalysis=process.env.RETINANALYSIS_DIR||join(homedir(),'Documents/GitHub/retinanalysis');
const managedRoot=process.env.RECORDING_WORKSPACE_ROOT||(process.env.RECORDING_PROJECT_DIR?dirname(resolve(process.env.RECORDING_PROJECT_DIR)):join(homedir(),'Documents/RecordingWorkspace'));
const python=process.env.RECORDING_PYTHON||join(retinanalysis,'.venv/bin/python');
try{
  if(!existsSync(python))throw new Error('Set RECORDING_PYTHON to a Python environment with Flask and the RetinAnalysis dependencies.');
  const built=spawnSync('npm',['run','build'],{cwd:appDir,stdio:'inherit'});
  if(built.error||built.status!==0)throw new Error('The app build did not finish. Fix the reported build error before starting.');
  console.log(`\nRieke OS: http://127.0.0.1:8766\nProjects: ${managedRoot}\nChoose a project or create an empty one. Databases start only when opened.\n`);
  const server=spawn(python,[join(repository,'python/workspace_launcher.py'),'--managed-root',managedRoot,'--retinanalysis',retinanalysis],{cwd:repository,stdio:'inherit'});
  for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>server.kill(signal));
  server.on('exit',code=>process.exit(code??0));
  server.on('error',error=>{console.error(error.message);process.exit(1);});
}catch(error){console.error(error.message);process.exit(1);}
