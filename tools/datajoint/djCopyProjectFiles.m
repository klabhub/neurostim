function djCopyProjectFiles(targetDataRoot,varargin)

p=inputParser;
p.addRequired('targetDataRoot',@mustBeTextScalar)
p.addParameter('useDayFolders',false,@islogical);
p.addParameter('paradigm','',@mustBeText);
p.addParameter('extension','',@mustBeText);
p.addParameter('dryrun',true,@islogical);
p.addParameter('scp','',@mustBeTextScalar);
p.parse(targetDataRoot,varargin{:});

if ~exist(targetDataRoot,'dir')
    [ok,msg] = mkdir(targetDataRoot);
    if ~ok
        error(msg);
    end
end

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

files = fetch((ns.File & keepExtension) * (ns.Experiment & keepParadigm),'*');

srcRoot = fetch1(ns.Global & 'name=''root''' ,'value','ORDER BY id DESC LIMIT 1');
nrFiles= numel(files);


if nrFiles==0
    fprintf('No matching files. Noting to do \n');
else
    failCntr = 0;
    for i=1:nrFiles
        folder = datestr(files(i).session_date,'YYYY/mm/DD');
        filename = files(i).filename;
        src = fullfile(srcRoot,folder,filename);
        if p.Results.useDayFolders
            trgFolder = fullfile(targetDataRoot,folder);
            if ~exist(trgFolder,"dir")
                [ok,msg] = mkdir(trgFolder);
                if ~ok
                    error(msg);
                end
            end
            trg = fullfile(trgFolder,filename);
        else
            trg = fullfile(targetDataRoot,filename);
        end        
        if ~exist(src,'file')
            fprintf('%s does not exist.\n',src)
            failCntr= failCntr+1;
        else
            subFolder = fileparts(trg);
            if ~exist(subFolder,"dir")
                [ok,msg] = mkdir(subFolder);
                if ~ok
                    error(msg);
                end
            end
            if p.Results.dryrun
                fprintf('(DRYRUN) Copying %s to %s\n',src,trg)
            else
                fprintf('Copying %s to %s \n',src,trg)
                if isempty(p.Results.scp)
                    [success,message] = copyfile(src,trg);
                    if ~success
                        failCntr = failCntr+1;
                        warning(message)
                    end
                else
                    % Use SSH to copy remote
                end
            end
        end
    end
    fprintf('Copied %d files. Failed %d files.\n',nrFiles-failCntr,failCntr)
end
