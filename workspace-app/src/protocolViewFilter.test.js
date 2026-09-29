import test from 'node:test';
import assert from 'node:assert/strict';
import {compileTagRules,readTagRules,clearTagFilters,tagFilterLabel} from './protocolViewFilter.js';
test('multiple tag rules preserve all/any, scopes, and negative membership on reopen',()=>{
 const rules=[{scope:'effective',comparison:'is',value:' selected '},{scope:'cell',comparison:'is_not',value:'artifact'}];
 for(const mode of ['all','any']){
  const predicate=compileTagRules(mode,rules);
  assert.deepEqual(predicate[mode][1],{not:{field:'annotations/cell/tags',operator:'contains',value:'artifact'}});
  assert.deepEqual(readTagRules({tag_predicate:JSON.stringify(predicate)}),{mode,rules:[{...rules[0],value:'selected'},rules[1]]});
 }
});
test('clearing tags preserves other protocol filters and shows readable multi-rule scope',()=>{
 const filters={cell_type:'RGC',tag:'old',tagged:'true',tag_predicate:JSON.stringify(compileTagRules('all',[{scope:'epoch',comparison:'is',value:'keep'}]))};
 assert.deepEqual(clearTagFilters(filters),{cell_type:'RGC'});
 assert.equal(tagFilterLabel(filters),'All of 1 tag rule');
 assert.ok(filters.tag_predicate);
 assert.throws(()=>compileTagRules('all',[{scope:'effective',comparison:'is',value:''}]));
});
