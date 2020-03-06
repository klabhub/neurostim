function branch = checkout(branch,repoFolder)
% Checkout a named branch in a repository, and pull from the origin to make
% sure it is up to date with the origin HEAD
% INPUT
% branch  - name of the repository branch
% repoFolder- folder that contains the repository.
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
if ~exist(repoFolder,'dir')
    error([ repoFolder ' does not exist; cannot checkout a git branch']);
end
here =pwd;
cd (repoFolder);


branchOnDisk =git('symbolic-ref --short HEAD');
if strncmpi(branchOnDisk,'fatal:',6)
    %Not a git repo.
    warning(['The ' repoFolder ' does not contain a git repository. git checkout is ignored']);
    branch ='';
    return;
elseif ~strcmpi(branchOnDisk,branch)
    % Mismatched branches. Ask the user what to do.
    fButton = ['Keep ' branchOnDisk ' branch'];
    kButton =['Keep ' branch ' branch'];
    answer =questdlg(['Files in ' repoFolder '  are on the  ' branchOnDisk ' branch, but you requested the ' branch ' branch.'],'Branch Mismatch',fButton,kButton,kButton);
    if strcmpi(answer,fButton)
        branch = branchOnDisk;         
        branchSwitched = false;
    else
        branchSwitched = true;
        % Switching to the specified branch
    end
else
    branchSwitched = false;
end

cmdout = git('fetch --all'); %#ok<NASGU>
[hasChanges,changes] = neurostim.utils.git.hasChanges(repoFolder);
if hasChanges
    stash = ['Auto stash : ' datestr(now,'ddmmmyy@HHMMSS')];
    cmdout = git(['stash save ' stash ]); %#ok<NASGU>
end

cmdout = git(['checkout ' branch]);%#ok<NASGU>
cmdout = git(['pull origin ' branch]);%#ok<NASGU>
if hasChanges && ~branchSwitched
    answer = questdlg(['Reapply ' num2str(numel(changes)) ' local changes to the ' repoFolder '?']);
    if strcmpi(answer,'Yes')
        [msg,sts] = git('stash pop '); %#ok<ASGLU> % Reapply the last one on the stack
    end
end
cd (here);
end