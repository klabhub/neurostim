%% Report current status of the database
[pdm] =unique(fetchn(ns.Experiment,'paradigm'));
[ext] = unique(fetchn(ns.File,'extension'));
fprintf('The database now contains: \n Subjects:\t \t %d \n Sessions:\t\t %d \n Experiments:\t %d \n Files:\t\t\t %d \n Paradigms:\t\t %d\n ',count(ns.Subject),count(ns.Session),count(ns.Experiment),count(ns.File),numel(pdm));
fprintf(['Paradigms: ' repmat('%s / ',[1 numel(pdm)]) '\n'],pdm{:});
fprintf(['File types: ' repmat('%s / ',[1 numel(ext)]) '\n'],ext{:}); 
