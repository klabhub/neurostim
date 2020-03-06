function [yesno,changes] = hasChanges(repoFolder) 
% Check whether a git repository has local, uncomitted changes.
% % repoFolder = Folder that contains the repository. 
% OUTPUT
% yesno - logical whether there are changes.
% changes = files that have changes
% .

if ~exist(repoFolder,'dir')
    error([ repoFolder ' does not exist; could not detect git changes']);
end
here =pwd;
cd (repoFolder);
[txt] = git('status --porcelain');
changes = regexp([txt 10],'[ \t]*[\w!?]{1,2}[ \t]+(?<mods>[\w\d /\\\.\+]+)[ \t]*\n','tokens');
nrMods= numel(changes);
yesno = nrMods>0;
cd(here);
end


