function v = filename(o,root,filetype)
% Take the output of a fetch(ns.Experiment) and return the associated file
% name (including the root if specified).
% INPUT
% o = The output of a call to .Experiment
% root = The top level folder to use. Will default to the value of 'root'
% in ns.Global.
%
% OUTPUT
% v = the filename of the corresponding Neurostim output file, or a cell
% array of filenames if o was a struct array
%
if nargin < 3
    filetype = '.mat';
    if nargin <2
        root = '';
    end
end
if isempty(root)
    rt = fetchn(ns.Global & 'name=''root''' ,'value','ORDER BY id DESC LIMIT 1');
    if ~isempty(rt)
        root =rt{1};
    end
end
if isa(o,'ns.Experiment')
    o =fetch(o,'*');
elseif isstruct(o)
    o = fetch(ns.Experiment & o,'*');
end
nrExperiments = numel(o);
v= cell(1,nrExperiments);
for i=1:nrExperiments
    v{i} = fullfile(root,datestr(o(i).session_date,'YYYY/mm/dd'), ...
        [o(i).subject '.' o(i).paradigm '.' datestr(o(i).starttime,'HHMMss') filetype ]);
end
if nrExperiments ==1
    v = v{1};
end
end