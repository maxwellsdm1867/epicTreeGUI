import test from 'node:test';
import assert from 'node:assert/strict';
import {releaseLink,updateNotice,updateLabel,watchAppUpdates} from './appUpdates.js';
test('only an available release creates a notification',()=>{
  for(const state of ['unavailable','unconfigured','error','up_to_date'])assert.equal(updateNotice({state,available:'1.0.0'}),null);
  assert.equal(updateNotice({state:'update_available',available:{version:'1.2.0'}}).version,'1.2.0');
});
test('release links cannot navigate to executable or untrusted destinations',()=>{
  for(const value of ['javascript:alert(1)','https://github.com.evil.test/releases','https://github.com/other/repo/releases','https://user:password@github.com/maxwellsdm1867/epicTreeGUI/releases'])assert.equal(releaseLink(value),null);
  assert.ok(releaseLink('https://github.com/maxwellsdm1867/epicTreeGUI/releases/tag/v1.0.0'));
});
test('automatically checks at startup, periodically, and on return after elapsed interval',()=>{
  let calls=0,tick,visible,time=0,cleared=false;
  const documentObject={visibilityState:'visible',addEventListener:(event,fn)=>visible=fn,removeEventListener:()=>visible=null};
  const stop=watchAppUpdates(()=>calls++,{interval:100,now:()=>time,documentObject,setTimer:fn=>{tick=fn;return 9;},clearTimer:id=>cleared=id===9});
  assert.equal(calls,1);time=100;tick();assert.equal(calls,2);
  documentObject.visibilityState='hidden';time=200;tick();assert.equal(calls,2);
  documentObject.visibilityState='visible';visible();assert.equal(calls,3);
  time=210;visible();assert.equal(calls,3);
  stop();assert.equal(cleared,true);assert.equal(visible,null);
});
test('visible status distinguishes no releases and failed checks from up to date',()=>{
  assert.equal(updateLabel({state:'up_to_date'}),'Up to date');
  assert.equal(updateLabel({state:'unavailable'}),'No release published');
  assert.equal(updateLabel({state:'error'}),'Update check unavailable');
});
