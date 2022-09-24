function pk = stripToPrimary(tbl,key)
% Based on a key struct that may have additional fields, strip all fields that are
% not part of this tables primary key. 
% INPUT
% tbl  - Relvar table
% key - Struct with (a subset of) primary keys as values (plus any  additional)
% fields).
% OUTPUT
% pk - Struct with only keys that are primary key values.
%
pk  = tbl.primaryKey;
[~,haveKeys] =intersect(pk,fieldnames(key));
pk = pk(haveKeys);
vals =cellfun(@(pv) (key.(pv)),pk,'uni',false);
pk = cell2struct(vals',pk);
            