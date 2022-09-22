classdef djFileDatabase <handle
    % A class to create and interact with a file-system based database
    % by exporting the rows of all MySql Datajoint tables to a local folder.

    properties
        root char = '../data/';
        schema;
        pk2File;  % Map from table names to tables that store PK and corresponding file.
    end

    methods (Access=public)
        function o = djFileDatabase(varargin)
            o.pk2File = containers.Map('KeyType','char','ValueType','any');
        end

        function scan(o,varargin)
            p=inputParser;
            p.addParameter('target','../data/dbase',@ischar); % Folder where files will be created
            p.parse(varargin{:});

            % Get the full, absolute path to the target
            target = dir(fullfile(p.Results.target,'.')).folder;

            % Folders below target represent exported tables
            tableFolders = dir(fullfile(target,'*'));
            tableFolders(strcmpi({tableFolders.name},'.') |strcmpi({tableFolders.name},'..') | ~[tableFolders.isdir] )=[];
            tableNames = {tableFolders.name};

            allFiles = dir(fullfile(target,'**','*.mat'));
            filenames = extractBefore(strcat({allFiles.folder},filesep,{allFiles.name}),'.mat');            
            nrTables= numel(tableNames);
            for i=1:nrTables
                rows = extractAfter(filenames,[tableNames{i} filesep])';
                out = cellfun(@isempty,rows);
                rows(out)=[];
                nrRows = numel(rows);
                % Because PK are the same for each row in the table, we can
                % extract PK values from the first.
                firstFile = regexp(rows{1},filesep,'split');
                firstPKeyVal = regexp(firstFile ,'(?<key>\w*)-(?<value>.*)','names');
                firstPKeyVal = [firstPKeyVal{:}];
                allPKeys= {firstPKeyVal.key};
                nrPKeys = numel(allPKeys);
                vals = cell(nrRows,nrPKeys+1);
                % Extract the PK from the file names/rows
                % (key-value/key-value/key-value.mat)
                for k=1:nrPKeys-1
                      vals(:,k) = extractBetween(rows,[allPKeys{k} '-'],filesep);
                end
                % The last one does not have the filesep at the end
                vals(:,nrPKeys) = extractAfter(rows,[allPKeys{end} '-']);
                vals(:,end) = filenames(~out);
                % Conver to table 
                T = cell2table(vals,'VariableNames',cat(2,allPKeys,{'filename'}));       
                % Store in the map linking table names to PK and filenames
                o.pk2File(tableNames{i}) = T;
            end
        end

        function exportFromSql(o,varargin)
            % Connect to the current schema, and export tables
            p=inputParser;
            p.addParameter('tables',{},@iscell); % A cell array of table names to export
            p.addParameter('folder',pwd,@ischar); % Root where packages with Schemas live
            p.addParameter('target','../data/dbase',@ischar); % Folder where files will be created
            p.addParameter('maxRows',inf,@isnumeric); % Fetch at most this number of rows at a time
            p.parse(varargin{:});
            
            % Find the schemas in the folder
            schemas = dir(fullfile(p.Results.folder,'+*/getSchema.m'));
            if isempty(schemas)
                error('No schemas found in %s',p.Results.folder)
            end

            % Export each schema
            for s=1:numel(schemas)
                package = extractAfter(schemas(s).folder,'+');
                thisSchema = eval([package '.getSchema;']);
                % Determine which tables can be sexported
                tableMap =thisSchema.tableNames; % The Matlab class names referring to the tables in SQL
                if isempty(p.Results.tables)
                    tableNames=  tableMap.keys;
                else
                    notInSql = ~isKey(tableMap,p.Results.tables);
                    if any(notInSql)
                        fprintf('No such tables in database %s : %s\n', thisSchema.dbname,strjoin(p.Results.tables(notInSql),' & '))
                        tableNames= intersect(p.Results.tables,tableMap.keys);
                    else
                        tableNames = p.Results.tables;
                    end
                end
                % Export the tables one by one
                offset =0;
                for t=1:numel(tableNames)
                    tbl = eval(tableNames{t});
                    fprintf('Exporting %d rows in table %s \n',tbl.count,tableNames{t});
                    startTransaction(thisSchema.conn)
                    if isfinite(p.Results.maxRows)
                        while true 
                            keys = fetch(tbl,'*',sprintf('LIMIT %d OFFSET %d',p.Results.maxRows,offset));
                            offset = offset+ p.Results.maxRows;
                            if isempty(keys)
                                break
                            else
                                saveToFile(o,p.Results.target,tbl,keys)
                            end
                        end
                    else
                        % Get all at once
                        keys = fetch(tbl);
                        saveToFile(o,p.Results.target,tbl,keys);
                    end           
                    cancelTransaction(thisSchema.conn);
                end
            end
        end

    end
    methods (Access=protected)
        function saveToFile(o,target, tbl, keys)
            tblName = tbl.className;
            primaryKeys= tbl.primaryKey;            
            for k=1:numel(keys)
                key = keys(k);
                fname = fullfile(target,tblName);
                for i=1:numel(primaryKeys)
                    thisVal = key.(primaryKeys{i});
                    if isnumeric(thisVal)
                        thisVal = num2str(thisVal);
                    end
                    thisFolder = [primaryKeys{i} '-' thisVal];
                    fname = fullfile(fname,thisFolder);
                end                
                fprintf('Saving to %s\n',[fname '.mat'])
                thisFolder  =fileparts(fname);
                if ~exist(thisFolder,'dir')
                   [ok,msg] =  mkdir(thisFolder);
                   if ~ok
                       fprintf(2,'Failed to created %s (%s). Skipping.. \n',thisFolder,msg)
                   end
                end
                save(fname,'key','-v7.3')
            end
        end
    end
end