import { useCallback, useEffect, useState } from 'react';
export async function api(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    ...options, headers: { 'Content-Type': 'application/json', 'X-Workspace-Request': '1', ...options.headers },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || data.message || `Request failed (${response.status})`);
  return data;
}
export function useResource(path, revision = 0) {
  const [state, setState] = useState({data: null, loading: true, error: null});
  const [nonce, setNonce] = useState(0);
  const reload = useCallback(() => setNonce(n => n + 1), []);
  useEffect(() => {
    if (!path) {setState({data: null, loading: false, error: null}); return;}
    const controller = new AbortController();
    setState(previous => previous.path === path ? {...previous, loading:true, error:null} : {data:null,loading:true,error:null,path});
    api(path, {signal: controller.signal}).then(data => {
      if (!controller.signal.aborted) setState({data, loading: false, error: null,path});
    }).catch(error => {if (!controller.signal.aborted) setState({data: null, loading: false, error: error.message,path});});
    return () => controller.abort();
  }, [path, revision, nonce]);
  return {...state, reload};
}
export const number = value => Number(value || 0).toLocaleString();
export const duration = seconds => seconds == null ? 'Unknown' : seconds < 60 ? `${seconds.toFixed(1)} s` : `${Math.floor(seconds / 60)}m ${Math.round(seconds % 60)}s`;
export const humanize = value => String(value || '').replace(/([a-z])([A-Z])/g, '$1 $2').replace(/^RGC\\/, '').replace(/Cur Inject/g, 'current injection');
export const time = value => value ? new Date(value).toLocaleString(undefined, {month:'short', day:'numeric', hour:'numeric', minute:'2-digit'}) : '—';

// Individual epoch controls must never inherit an unrelated bulk selection.
export function resolveCurationTargets(focused, targets = [], scope = 'selection') {
  if (!['selection', 'focused'].includes(scope)) throw new Error('Unknown curation action scope');
  if (scope === 'focused') return focused ? [focused] : [];
  return targets.length ? [...new Set(targets)] : focused ? [focused] : [];
}

// Review is an optional export filter; excluded epochs never become eligible.
export function eligibleExportCount(counts, policy) {
  const value = policy === 'include_unreviewed' ? counts.included :
    policy === 'approved_only' ? (counts.approved_exportable ?? counts.exportable) : undefined;
  return Number.isInteger(value) && value >= 0 ? value : undefined;
}
