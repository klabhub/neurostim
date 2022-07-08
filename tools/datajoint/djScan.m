function djScan(varargin)
% This function scans filenames in (and around) the folder correspondong
% to a certain date under a given root folder and adds Neurostim experiments
% found in those folders to the datajoint database.
%
% This works because Neurostim always (?) generates files in the following
% format:
% root\YYYY\MM\dd\subject.paradigm.startTime.mat
%
% INPUT
% 'root' - Top level folder (e.g. Z:\). Folders below this root folder should
% correspond to the years. [Read from ns.Global 'root' property by default]
% date - Date to scan.  [today]
% schedule - 'y' - Scan the year in which the date falls.
%          - 'm' - Scan the month
%          - ['d'] - Scan the specified day only.
% readFileContents - Read each Neurostim file and update the database with its
%               values [false]
%           With this set to false, this creates a quick overview of files
%           in the data root folder. File content can later be added using
%           the ns.Experiment.updateWithFileContents
%
% ignore  - File extensions to ignore {'.ini','.cache'}
% safemode   = [true] -Ask confirmation before dropping tables in the
%                       database
% paradigms = Cell array of paradigms to include. Leave empty to include
% all. [{}]
% OUTPUT
% None
%
% BK - April 2022.

rt = fetchn(ns.Global & 'name=''root''' ,'value','ORDER BY id DESC LIMIT 1');
if isempty(rt)
    rt = pwd;
else
    rt =rt{1};
end
p = inputParser;
p.addParameter('root',rt);
p.addParameter('date',now);
p.addParameter('schedule','d');
p.addParameter('readFileContents',false);
p.addParameter('ignore',{'.ini','.cache'});
p.addParameter('safemode',true);
p.addParameter('paradigms',{});
p.addParameter('fileType','*.mat')
p.parse(varargin{:});

dj.config('safemode',p.Results.safemode);


switch (p.Results.schedule)
    case 'y'
        % Allow more than one folder below year
        srcFolder = fullfile(p.Results.root,datestr(p.Results.date,'yyyy'),'**',p.Results.fileType);
    case 'm'
        % Exactly one folder below month
        srcFolder = fullfile(p.Results.root,datestr(p.Results.date,'yyyy/mm'),'**',p.Results.fileType);
    case 'd'
        % Inside the day folder
        srcFolder = fullfile(p.Results.root,datestr(p.Results.date,'yyyy/mm/dd'),p.Results.fileType);
    otherwise
        error('Unknown schedule %s',p.Results.schedule)
end

fprintf('Scanning %s ...\n',srcFolder)

% Find the files matching the wildcard
files= dir(srcFolder);
pathFromRoot = strrep({files.folder},p.Results.root,'');
fullName = strcat(pathFromRoot',filesep,{files.name}');
% Prune to get files that Neurostim generates
if strcmpi(filesep','\')
    fs = '\\';
else
    fs = filesep;
end
pattern = ['(?<date>\d{4,4}' fs '\d{2,2}' fs '\d{2,2})' fs '(?<subject>\w{2,10})\.(?<paradigm>\w+)\.(?<startTime>\d{6,6})\.'];
nsDataFiles = regexp(fullName,pattern,'names');
% Prune those file that did not match
out = cellfun(@isempty,nsDataFiles);

fullName(out) =[];
nsDataFiles(out)=[];
files(out) = [];
nsDataFiles= [nsDataFiles{:}]; % Create a struct array with the relevant info

if ~isempty(p.Results.paradigms) && ~isempty(nsDataFiles)
    out = ~ismember({nsDataFiles.paradigm},p.Results.paradigms);
    if any(out)
        fprintf('Skipping %d files with non-matching paradigms\n',sum(out))
        fullName(out) =[];
        nsDataFiles(out)=[];
        files(out) = [];
    end
end
if isempty(nsDataFiles)
    fprintf('No files found in %s\n',p.Results.root);
    return;
end

fprintf('Foound %d files with matching paradigms\n',numel(files))

%% Add the new subjects (if any)
% Assuming that all non-primary keys are nullable.
uSubjects = unique({nsDataFiles.subject});
tbl  = ns.Subject;
knownSubjects = fetch(tbl,'subject');
newSubjects = setdiff(uSubjects,{knownSubjects.subject});
nullFields = tbl.nonKeyFields;
tmp = cell(1,2*numel(nullFields));
[tmp{1:2:end}] = deal(nullFields{:});
[tmp{2:2:end}] = deal([]);
newSubjects = struct(tbl.primaryKey{1},newSubjects,tmp{:});
fprintf('Adding %d new subjects \n',numel(newSubjects))
insert(ns.Subject,newSubjects)

% Loop over datafiles (which should correspond to Neurostim experiments
nrDataFiles  = numel(nsDataFiles);
for i=1:nrDataFiles
    fprintf('Processing file %d of %d (%s)\n',i,nrDataFiles,files(i).name);

    %% Find or add Session
    qry =struct('session_date', datestr(nsDataFiles(i).date,29),...  % Convert to ISO 8601
        'subject',nsDataFiles(i).subject);
    thisSession = ns.Session & qry;
    if ~thisSession.exists
        insert(ns.Session,qry);
    end

    %% Find or add Experiment
    qry.starttime = datestr(datenum(nsDataFiles(i).startTime,'HHMMSS'),'HH:MM:SS');
    qry.paradigm = nsDataFiles(i).paradigm;
    thisExperiment = ns.Experiment  & qry;
    if ~thisExperiment.exists || p.Results.readFileContents
        key = qry;
        file = fullfile(p.Results.root,fullName{i});
        key.file    = file;
        if p.Results.readFileContents
            updateWithFileContents(ns.Experiment,key);
        else
            % Just insert the file info
            insert(ns.Experiment,key);
        end
    end
    qry = rmfield(qry,'paradigm');

    %% Find or add Files  - this requires a search for all files that have the same prefix
    [~,f] =fileparts(files(i).name);
    prefix = fullfile(files(i).folder,[f '*']);
    inFolder = dir(prefix);
    prefix = [prefix filesep '*']; %#ok<AGROW> %Seach subfolders
    inSubFolder = dir(prefix);
    linkedFiles = cat(1,inFolder,inSubFolder);
    % Remove folders
    linkedFiles([linkedFiles.isdir]) =[];
    % Remove common junk files
    [~,~,ext] = fileparts({linkedFiles.name});
    out = ismember(ext,p.Results.ignore);
    linkedFiles(out) =[];
    % Add each one
    for f=1:numel(linkedFiles)
        relFolder = strrep(linkedFiles(f).folder,files(i).folder,'');
        [~,~,ext] = fileparts(linkedFiles(f).name);
        qry.filename = fullfile(relFolder,linkedFiles(f).name);
        thisFile = ns.File & qry;
        if ~thisFile.exists
            qry.extension = ext;
            insert(ns.File,qry);
            qry = rmfield(qry,"extension");
        end
    end

end
djReport;
end








