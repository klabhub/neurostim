% Profile parameters set/get

profile clear
profile on

cd ../demos
c= adaptiveDemo
cd ../tools

%%
stats= profile('info');
prms = ~cellfun(@isempty,strfind({stats.FunctionTable.FileName},'parameter.m'));
allData = stats.FunctionTable(prms);
funcs= {'getValue','getFunctionValue','setValue'};
for i=1:numel(funcs)
prms = ~cellfun(@isempty,strfind({allData.FunctionName},funcs{i}));

data = allData(prms);
msPerCall= 1000*[data.TotalTime]./[data.NumCalls]; %s->ms
T = table;
T.msPerCall =msPerCall';
T.totalTime = [data.TotalTime]';
T.nrCalls = [data.NumCalls]';
T.Properties.RowNames={data.FunctionName}';
T.Properties.VariableUnits = {'ms','ms','#'};
T.Properties.VariableDescriptions = {'ms per call','Time (ms)','#Calls'};
T = sortrows(T,{'msPerCall','totalTime'});

T
end

%%
profile report