function version =versionTracker(varargin)
% Git Tracking Interface
% For best reproducibility one would always want to be able to restore the
% exact code base used to run each experiment. This can be achieved by
% storing the git hash id (which uniquely identifies the source code of an
% entire repository) in the experiment output data. 
% 
% In addition, it can be desirable to make sure that experiments always run
% the most up-to-date version of the code repository. 
% 
% This function helps to achieve both of these goals. It is called from
% cic.run at the start of an experiment if c.gitTracker.on ==ttrue.
% The cic.gitTracker struct is used to chose between various options:
% EXAMPLE:
% You want to log the version of the neurostim toolbox that is used, but 
% do not care about local changes 
% Use:  c.gitTracker.commit = false, 
% A more prudent strategy is to commit local changes:
% Use:  c.gitTracker.commit = true,
% This will ask the user for a commit message, which you can autogenerate
% with c.gitTracker.silent=true.
%
% The function returns a struct that includes information on the remote
% repository, as well as the hash id such that the complete code state can
% be reproduced later. The cic.run function stores this in the repoVersion
% property.
%
% INPUT
% 'commit' = Set to false to allow local modifications
% (and store current hash that does not include those local
% modifications).
% 'silent' = toggle to indicate whether commits of local changes
% are done silently, or require a commit message. [false]
% 'folder' = The folder of the repository whose version should be
% tracked [if empty or absent it defaults to the folder that contains neurostim.cic].
%
% OUTPUT
% versioon  = Struct with .remote .branch, .changes, and .hash
% 
% NOTE
% You can also use this to track another repository (for
% instance, one that contains your experiments; just provide
% the folder that contains your repository as the 'folder', and 
% store the output of this function in a cic property (e.g. 'repoVersion').
%
% BK  - Apr 2016,2020

p = inputParser;
p.addParameter('commit',true,@islogical);
p.addParameter('silent',false,@islogical);
p.addParameter('folder','',@ischar);
p.addParameter('on',false,@islogical);
p.StructExpand = true;
p.parse(varargin{:});

if ~p.Results.on
    version = struct('remote','not tracked','branch','not tracked','changes',{},'hash','not tracked');
    return; % Noting to do
end

if isempty(which('git'))
    error('The neurostim.utils.git functions  depend on a wrapper for git that you can get from github.com/manur/MATLAB-git');
end


if isempty(p.Results.folder)
    folder = fileparts(which('neurostim.cic'));
else
    folder = p.Results.folder;
end
fprintf('Updating/checking the %s git repository. Please wait.\n',folder);
here = pwd;
cd(folder);
version.remote = git('remote get-url origin');
version.branch = git('rev-parse --abbrev-ref HEAD');
[hasChanges,changes] = neurostim.utils.git.hasChanges(folder);
if p.Results.commit && hasChanges
    % Commit all changes to the current branch
    fprintf('%d files have changed in %s - branch %s.\n',numel(changes),version.remote,version.branch);
    changes =[changes{:}];
    for i=1:numel(changes)
        fprintf('Local changes in %s \n',changes{i});
    end
    if p.Results.silent
        msg = ['Silent commit  before experiment ' datestr(now,'yyyy/mm/dd HH:MM:SS')];
    else
        msg = input('Code has changed. Please provide a commit message: ','s');
    end
    cmdout = git('add :/'); %#ok<NASGU> % Add all changes.
    [txt,status]=  git(['commit -m "' msg '"']);
    if status >0
        disp(txt);
        error('git file commit failed.');
    end
    fprintf('Committed changes to git.\n');
end

%% Read the commit id
txt = git('show -s');
hash = regexp(txt,'commit (?<id>[\w]+)\n','names');
version.hash = hash.id;
version.changes = changes;
cd(here);
fprintf('Git version tracking complete and stored.');
end