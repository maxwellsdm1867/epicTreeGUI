import test from 'node:test';
import assert from 'node:assert/strict';
import {epochExportOptions,epochExportPredicate} from './epochExport.js';
test('focused export uses UUID and preserves local filters, not repeated block numbers',()=>{
 const epoch={epoch_uuid:'unique',epoch_number:1,cell_label:'Cell1',curation:{included:true}};
 const filters={tag:'reviewed',cell_uuid:'cell'};
 const options=epochExportOptions(epoch,'wheeler-sqlite',{filters,splits:'cell',queryRevision:'revision'});
 assert.deepEqual(options.filters,{...filters,epoch_uuid:'unique'});
 assert.deepEqual(filters,{tag:'reviewed',cell_uuid:'cell'});
 assert.equal(options.query_revision,'revision');
 assert.equal(options.split_order,'cell');
 assert.throws(()=>epochExportOptions({...epoch,curation:{included:false}},'wheeler-sqlite'),/Include this epoch/);
});
test('focused search export intersects identity with the original predicate',()=>{
 const predicate={field:'protocol',operator:'contains',value:'Noise'};
 assert.deepEqual(epochExportPredicate(predicate,'unique'),{all:[predicate,{field:'epoch',operator:'eq',value:'unique'}]});
});
