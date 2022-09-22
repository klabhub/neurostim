function djExport(targetDataRoot,varargin)
% Export files (ns.File) corresponding to one or more paradigms from the
% Root folder to a project folder.
%
% INPUT
% targetDataRoot = Path to the folder where data will be stored (e.g.
% '../data')
% 'useDayFolders' - Structure the files using year/month/day hiearchy
% 'skipExisting'  - Copy only new files.
% 'paradigm' - Cell array of paradigms to include
% 'extension' - Selection of file extensions to include (e.g. '.mat' to
% copy only .mat files). Only one extension can be handled at a time (until
% the or-restriction on tables works in datajoint).
% 'include' - Copy only files that contain this string (or multiple strings
% specified as a cellstr. {'temp','notanalyze'};
% 'exclude' - Don't copy files that contain this string (or multiple
% strings specified as a cellstr).
% 'dryrun' - If true only a log is produced, no files are copied. [True]
% 'maxNrFiles'  - Process at most this number of files. [Inf]
%
% 'ssh' - To copy files to a remote system, provide an SSH struct that is
%          genrated by ssh2_config in the matlab-ssh2 package by David
%          Friedman. It is available on github.
%
% 'fun' - The default export simply copies the raw data files, but youc an
%        also provide a function_handle to process these files. This
%        function should take the file name as its input and return a sigle
%        output. If this output is a table, you can export it as a CSV file
%           by specifying 'format', '.csv'. If this output is something
%           else (e.g. a struct), it uses the '.mat' format to save the output
%           in a .mat file. The .mat file will be named after the Neurostim
%           output file, with the addition of a 'tag'.  (e.g., 'export' to
%           distinghuish it from the main Neurostim output file.
% 'tag' - Tag used to label the exported file ['export']
% 'format' - '.CSV' is allowed for Table exports, and '.MAT'for everything
%               else.
%
% OUTPUT
% void
%
% EXAMPLE
%  Copy all .mat files to a remote cluster
%  Setup the SSH connection
% host = 'hpc.rutgers.edu';
% user = 'bart';
% keyfile = 'bart_hpc_rsa';
% ssh = ssh2_config_publickey(host,user,keyfile,' ');
%  djExport('/scratch/bart/posner/data','useDayFolders',false,'extension','.mat',...
%           'dryrun',false,'paradigm','posner','ssh',ssh)
%
% Or to run a script called  export (that returns a table ) on each file and save
% the table as a CSV in a local data folder:
%   djExport('data','useDayFolders',false,'extension','.mat',...
%           'dryrun',false,'paradigm','posner','fun',@export,'format','.CSV')
%
% Or, if you need to use datajoint queries to select a more specific subset
% of files (selecting on session_date is not built-in to this function)
% f = ns.File * ns.Experiment & 'session_date=''2015-03-30''' & 'extension=''.spk'''
% Then:
% djExport('../data','table',f,'useDayFolders',true,'exclude',{'.lfp','.cls'},'dryrun',false)
% Note that include/exclude/extension/paradigm parameters are still allowed, even when
% passing a specific table to djExport. 
%
% BK - July 2022.
% BK - Added table input, Sept 2022.
p=inputParser;
p.addRequired('targetDataRoot',@mustBeTextScalar)
p.addParameter('useDayFolders',false,@islogical);
p.addParameter('skipExisting',true,@islogical);
p.addParameter('paradigm','',@mustBeText);
p.addParameter('extension','',@mustBeText);
p.addParameter('table',[],@(x) isa(x,'dj.internal.GeneralRelvar'));
p.addParameter('include','',@mustBeText);
p.addParameter('exclude','',@mustBeText);
p.addParameter('dryrun',true,@islogical);
p.addParameter('maxNrFiles',Inf,@isnumeric);
p.addParameter('ssh','');
p.addParameter('fun',''); % Process the file by this function  and export the result (i.e. a table or some other variable)
p.addParameter('format',''); % Empty for copying, .CSV for table fun output, .MAT for other fun output
p.addParameter('tag','export');
p.parse(targetDataRoot,varargin{:});

% Define restrictions
if isempty(p.Results.paradigm)
    keepParadigm = true;
else
    keepParadigm = struct('paradigm',p.Results.paradigm);
end
if isempty(p.Results.extension)
    keepExtension = true;
else
    keepExtension = struct('extension',p.Results.extension);
end
%% Get the files from the database
if isempty(p.Results.table)
    %% Find relevant files by querying the database
    files = fetch((ns.File & keepExtension) * (ns.Experiment & keepParadigm),'*');
else
    % Fetch the table that was passed 
    files = fetch(p.Results.table & keepExtension & keepParadigm,'*');
end

srcRoot = fetch1(ns.Global & 'name=''root''' ,'value','ORDER BY id DESC LIMIT 1');
nrFiles = numel(files);

% Select on include/exclude
keepRows = true(nrFiles,1);
if ~isempty(p.Results.exclude)
    keepRows = keepRows & ~contains({files.filename}',p.Results.exclude);
end
if ~isempty(p.Results.include)
    keepRows = keepRows &  contains({files.filename}',p.Results.include);
end
nrFiles= sum(keepRows);
rows = find(keepRows);

if ~p.Results.useDayFolders
    % Check that filenames are unique
    assert(numel(unique({files(keepRows).filename}))==nrFiles,"Some of these files have the same name. Please use ''dayFolders'',true ")
end

%% Export one by one
mbytes=0;
nrFailed = 0;
nrSkipped = 0;
nrMissing =0;    
if nrFiles==0
    fprintf('No matching files. Noting to do \n');
else
    cntr =0;
    for row=rows'
        cntr =cntr+1;
        if cntr > p.Results.maxNrFiles;break;end

        dayFolder = datestr(files(row).session_date,'YYYY/mm/DD');
        [subFolder,filename,ext]= fileparts(files(row).filename);
        srcFullFile = fullfile(srcRoot,dayFolder,subFolder,[filename ext]);
        if ~exist(srcFullFile,'file')
            fprintf('%s does not exist.\n',srcFullFile)
            nrMissing = nrMissing+1;
        else
            if ~p.Results.useDayFolders
                dayFolder= '';
            end
            % Construct the name of the target file
            if isempty(p.Results.fun)
                % Copy  - keep file name
                trgFullFile = fullfile(targetDataRoot,dayFolder,subFolder,[filename ext]);
            else
                %
                % Export files get a (user specified) tag to
                % distinguish fronm raw data
                trgFullFile  = fullfile(targetDataRoot,dayFolder,subFolder,sprintf('%s_%s%s',filename,p.Results.tag,p.Results.format));
                if isempty(p.Results.ssh)
                    % Can save directly to the target
                    tmpTrgFullFile= trgFullFile;
                else
                    % Need an intermediate file before scp
                    tmpTrgFullFile = fullfile(tempdir,sprintf('%s_%s%s',filename,p.Results.tag,p.Results.format));
                end
            end

            %% Check to see if we can skip this one.
            if p.Results.skipExisting
                if isempty(p.Results.ssh)
                    % Check local system
                    skip = exist(trgFullFile,"file");
                else % Check remote system via SSH
                    [~,result] = ssh2_command(p.Results.ssh,['test -f ' strrep(trgFullFile,'\','/') ' && echo 1']);
                    skip= strcmpi(result{1},'1');
                end
                if skip
                    nrSkipped = nrSkipped +1;
                    fprintf('Skipping %s  (already exists)  \n',trgFullFile)
                    continue;
                end
            end

            %% Compute a user defined result to export
            if ~isempty(p.Results.fun)
                try
                    result  = p.Results.fun(srcFullFile);
                    success = true;
                catch me
                    success = false;
                    message = me.message;
                end
                if ~success
                    nrFailed = nrFailed+1;
                    fprintf('Falied on%s  (%s)  \n',srcFullFile,message)
                    continue;
                end
            end

            %% Create target folder
             trgFolder = fileparts(trgFullFile);                
            if p.Results. dryrun
                if ~exist(trgFolder,'dir')
                    fprintf('(DRYRUN): creating %s \n', trgFolder);
                end
            else
                if isempty(p.Results.ssh)
                    % Local file system
                    if ~exist(trgFolder,"dir")
                        [ok,msg] = mkdir(trgFolder);
                        if ~ok
                            nrFailed = nrFailed+1;
                            warning(msg);
                            continue; % next file
                        end
                    end
                else
                    % Remote file system
                    remotePath = strrep(trgFolder,'\','/');
                    ssh2_command(p.Results.ssh,['mkdir --parents ' remotePath])
                end
            end
            %% Now do the export
            d = dir(srcFullFile);  
            mbytes = mbytes +d.bytes;            % Collect size for report at end (also during DRYRUN)
            if p.Results.dryrun                
                fprintf('(DRYRUN) Exporting %s to \n \t \t %s \n',srcFullFile,trgFullFile)
            else
                fprintf('Exporting %s to \n \t \t %s \n',srcFullFile,trgFullFile)
                if isempty(p.Results.fun)
                    % Simple copy - no analysis
                    if isempty(p.Results.ssh)
                        [success,message] = copyfile(srcFullFile,trgFullFile);
                    else
                        %- will be copied below
                        success =true;
                    end
                    if ~success
                        nrFailed = nrFailed+1;
                        warning(message)
                        continue;
                    end
                    fileToDelete = '';
                else
                    switch upper(p.Results.format)
                        case '.CSV'
                            % Export as CSV
                            if isa(result,"table")
                                writetable(result,tmpTrgFullFile);
                            else
                                error('The %s function returned a %s, but only tables can be exported to csv. Change the ''format'' to .MAT?',func2str(p.Results.fun),class(result))
                            end
                        case '.MAT'
                            % Export as .mat
                            save(tmpTrgFullFile,'result');
                        otherwise
                            error('Unknown export format %s',format)
                    end
                    if isempty(p.Results.ssh)
                        fileToDelete ='';
                    else
                        % Now this temp file is the srcfile to copy to the remote
                        srcFullFile = tmpTrgFullFile;
                        fileToDelete = tmpTrgFullFile;
                    end
                end

                % For SSH only - copy the file or the temp file with the
                % results of .fun
                if ~isempty(p.Results.ssh) % Use SSH to copy remote
                    [localPath,localFilename,e] = fileparts(srcFullFile);
                    scp_put(p.Results.ssh,[localFilename e],remotePath,localPath);
                    if ~isempty(fileToDelete)
                        if contains(fileToDelete,srcRoot)
                            % Cannot happen, but just in case
                            warning('Deleting from the source??')
                        else
                            delete(fileToDelete);
                        end
                    end
                end
            end
        end
    end
end
fprintf('Total %d, Copied %d, Skipped %d, Failed %d, Missing %d files (%g MB).\n',nrFiles,min(p.Results.maxNrFiles,nrFiles)-nrFailed-nrSkipped-nrMissing,nrSkipped,nrFailed,nrMissing,round(mbytes/1e6))
end
