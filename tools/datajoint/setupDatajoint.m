function setupDatajoint(code,schemaName,dataRoot)
% Setup a new datajoint pipeline for a project. 
% For instance, if Alice's data are all under the root folder x:\data\
% and she wants to start a new project called 'alice_memory' with Matlab code
% for the pipelin stored in u:\projects\memory\code, she uses:
% 
%  setupDatajoint('u:\projects\memory\code','alice_memory','x:\data\')
%  And then she runs 
%  djScan('date','01-May-2022','schedule','m','readFileContents',true)
% to scan files collected in May '22 and add them to the pipeline.
% The datajoint code in the neurostim repository handles file scanning and 
% stores all Neurostim data (i.e. all neurostim parameters) in the
% database.
% To retrieve the data for a single Neurostim experiment (i.e. file), you
% use a query to define the experiment :
% For instance, this will return a struct array with the data for all
% experiments for subject #12:
% data = get(ns.Experiment & 'subject=12')
%
% Alice can now add files to the u:\projects\memory\code\+ns that define
% the analysis pipeline. 
% 
% INPUT 
% code -  The root level folder where your project's code lives. The script
%           will create a +ns package subfolder with a getSchema.m file.
% schemaName - The name of this project in your SQL database (e.g.
%                   'alice_memory')
% dataRoot - The root folder that contains all data files. The
%               folders below this are the years.
%
%  BK - April 2022


[here] =fileparts(mfilename('fullpath'));
if ~exist(code,'dir')
    mkdir(code);
end
packageName = 'ns';

%% Add the schema and utilities (dj*) 
addpath(here)
%% Create a package folder in the project to extend the schema 
mkdir(fullfile(code,['+' packageName]));

%% Create the schema on the SQL server
query(dj.conn, sprintf('CREATE SCHEMA `%s`',schemaName))

%% Create the getSchema function
gs= 'function obj = getSchema\n persistent OBJ \n if isempty(OBJ) \n     OBJ = dj.Schema(dj.conn,''%s'', ''%s'');\n end\n obj = OBJ;\n end \n';
fid = fopen(fullfile(code,['+' packageName],'getSchema.m'),"w");
fprintf(fid,gs,packageName,schemaName);
fclose(fid);

%% Setup the global table with an entry for the preferred data root.
insert(ns.Global,struct('id',0,'name','root','value',dataRoot));

%% Go to the project folder
cd(code)
fprintf('The datajoint pipeline for %s has been setup. Run djScan to add files.\n',schemaName);



end