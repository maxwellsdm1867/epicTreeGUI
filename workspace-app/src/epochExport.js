// Scope a one-off export by immutable identity, never by an epoch's block number.
export function epochExportPredicate(predicate,epochUuid){
  if(!epochUuid)throw new Error('Choose an epoch before exporting');
  return {all:[predicate,{field:'epoch',operator:'eq',value:epochUuid}]};
}
export function epochExportOptions(epoch,format,{filters={},splits='date,cell,block',queryRevision}={}){
  if(!epoch?.epoch_uuid)throw new Error('Choose an epoch before exporting');
  if(epoch.curation?.included===false)throw new Error('Include this epoch before exporting it from this protocol');
  return {format,query_revision:queryRevision,filters:{...filters,epoch_uuid:epoch.epoch_uuid},split_order:splits,
    review_policy:'include_unreviewed',name:`${epoch.cell_label||'Recording'} · epoch ${epoch.epoch_number??epoch.epoch_uuid}`};
}
