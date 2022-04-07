function v = filename(o,root)
% Take the output of a fetch(ns.Experiment) and return the associated file
% name (including the root if specified).
% INPUT
% o = The output of a call to .Experiment
% root = The top level folder ['']
%
% OUTPUT
% v = the filename of the corresponding Neurostim output file, or a cell
% array of filenames if o was a struct array
%
if nargin <2
    rt = fetchn(ns.Global & 'name=''root''' ,'value','ORDER BY id DESC LIMIT 1');
    if isempty(rt)
        root = '';
    else
        root =rt{1};
    end    
end
nrExperiments = numel(o);
if isa(o,'ns.Experiment')
    o =fetch(o,'*');
elseif isstruct(o)
    o = fetch(ns.Experiment & o,'*');
end
v= cell(1,nrExperiments);
for i=1:nrExperiments
    v{i} = fullfile(root,datestr(o(i).session_date,'YYYY/mm/dd'), ...
        [o(i).subject '.' o(i).paradigm '.' datestr(o(i).starttime,'HHMMss') '.mat']);
end
if nrExperiments ==1
    v = v{1};
end
end