function pk = primaryKey(tbl,key)
% Based on a key struct that may have additional fields, create a key that
% represents only the primary key values.
% INPUT
% tbl  - Relvar table
% key - Struct with the primary keys as values (plus any additional
% fields).
% OUTPUT
% pk - Struct with only the primary key values.
%

vals =cellfun(@(pv) (key.(pv)),tbl.primaryKey,'uni',false);
pk = cell2struct(vals',tbl.primaryKey);
            