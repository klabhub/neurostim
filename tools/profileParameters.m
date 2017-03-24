% Profile parameters set/get

profile clear
profile on

cd ../demos
c= adaptiveDemo
cd ../tools


stats= profile('info');
prms = ~cellfun(@isempty,strfind({stats.FunctionTable.FileName},'parameter.m'));
data = stats.FunctionTable(prms);

musPerCall= 1000*[data.TotalTime]./[data.NumCalls];
T = table;
T.musPerCall =musPerCall';
T.totalTime = [data.TotalTime]';
T.nrCalls = [data.NumCalls]';
T.Properties.RowNames={data.FunctionName}';
T.Properties.VariableUnits = {'\mus','ms','#'};
T.Properties.VariableDescriptions = {'\mu s per call','Time (ms)','#Calls'};
T = sortrows(T,{'musPerCall','totalTime'});

T