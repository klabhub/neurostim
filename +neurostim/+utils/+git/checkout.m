function [branch,branchOnDisk] = checkout(varargin)
% Checkout a named branch in a repository, and pull from the origin to make
% sure it is up to date with the origin HEAD
% INPUT (Parm/value pairs)
% branch  - name of the repository branch   ['']
% repoFolder- folder that contains the repository.  [folder containing neurostim.cic]
% verbose - set to true to get more info on the command line [false]
% force  - set to true to not ask for confirmation for branch switches [false]
% OUTPUT
% branch  = the branch after this checkout.
%
% If the branch is different from the one on disk, the user is asked to
% confirm.
% 
% If there are local changes, they are always stashed first.
% If the branch does not change from the one on disk, the user is asked
% whether the stash should be reapplied.
% If the stash was on a different branch, then the user does not get this
% option (the stash can be applied manually later).
%
% Note that this function should not be used once an experiment is started;
% if you do, you change the code on the fly and it is not 100% clear which
% versions will run... The nsGui uses this function to update the code base
% before the experiment starts.
% 
%  BK  -Feb 2020

p= inputParser;
p.addParameter('branch','',@ischar);
p.addParameter('repoFolder',fileparts(which('neurostim.cic')),@ischar);
p.addParameter('verbose',false,@islogical);
p.addParameter('force',false,@islogical);
p.parse(varargin{:});

if ~exist(p.Results.repoFolder,'dir')
    error([ p.Results.repoFolder ' does not exist; cannot checkout a git branch']);
end

if p.Results.verbose
    disp(['Starting git.checkout for ' p.Results.branch ' in '  p.Results.repoFolder]);
end
here =pwd;
cd (p.Results.repoFolder);


branchOnDisk =git('symbolic-ref --short HEAD');
if strncmpi(branchOnDisk,'fatal:',6)
    %Not a git repo.
    warning(['The ' p.Results.repoFolder ' does not contain a git repository. git checkout is ignored']);
    branch ='';
    return;
elseif ~strcmpi(branchOnDisk,p.Results.branch)
    % Mismatched branches. Ask the user what to do.
    fButton = ['Keep ' branchOnDisk ' branch'];
    kButton =['Switch to ' p.Results.branch ' branch'];
    if p.Results.force
        answer = kButton;
    else
        answer =questdlg(['Files in ' p.Results.repoFolder '  are on the  ' branchOnDisk ' branch, but you requested the ' p.Results.branch ' branch.'],'Branch Mismatch',fButton,kButton,kButton);
    end
    if strcmpi(answer,fButton)
        % Keeping branchOnDisk
        branch = branchOnDisk;         
        branchSwitched = false;
    else
         % Switching to the specified branch
        branch = p.Results.branch;
        branchSwitched = true;       
    end
else
    branchSwitched = false;
    branch = branchOnDisk;
end

    
cmdout = git('fetch --all'); %#ok<NASGU>
[hasChanges,changes] = neurostim.utils.git.hasChanges(p.Results.repoFolder);
if hasChanges
    stash = ['Auto stash : ' datestr(now,'ddmmmyy@HHMMSS')];
    cmdout = git(['stash save ' stash ]); %#ok<NASGU>
    if p.Results.verbose
        disp(cmdout);
    end
end

cmdout = git(['checkout ' branch]);%#ok<NASGU>
remoteExists = git(['ls-remote --heads origin ' branch]);
if ~isempty(remoteExists)
    cmdout = git(['pull origin ' branch]);
    if p.Results.verbose
        disp(cmdout);
    end
else
    if p.Results.verbose
        disp(['Local branch ' branch]);
    end
end
if hasChanges && ~branchSwitched
    if p.Results.force
        answer ='Yes';
    else
        answer = questdlg(['Reapply ' num2str(numel(changes)) ' local changes to the ' p.Results.repoFolder '?']);
    end
    if strcmpi(answer,'Yes')
        [msg,sts] = git('stash pop '); %#ok<ASGLU> % Reapply the last one on the stack
        if p.Results.verbose
            disp(msg);
        end
    end    
end
cd (here);
rehash; % Make sure that any changes are included in the JIT
end