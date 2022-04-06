function djCopyProjectFiles(name,varargin)

p=inputParser;
p.addRequired('name',@mustBeTextScalar)
p.addParameter('nested',false,@islogical);
p.addParameter('root',pwd,@mustBeTextScalar);
p.addParameter('paradigm','',@mustBeText);
p.addParameter('extension','',@mustBeText);
p.addParameter('dryrun',true,@islogical);
p.parse(name,varargin{:});

if ~exist(p.Results.root,'dir')
    error('The root folder (%s) oes not exist ',p.Results.root);
end

[ok,msg] = mkdir(fullfile(p.Results.root,name));
if ~ok
    error(msg);
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

files = (ns.File & keepExtension) * (ns.Experiment & keepParadigm)

if p.Results.dryrun

else

end

