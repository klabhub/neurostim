% Generate Matlab code for the Neurostim NWB extensions.
% 
% Note that the yaml files are created by the Neurostim NWB Extensions 
% Jupyiter notebook script in this folder and not in Matlab; update/run that 
% first in Python then run this Matlab script.
% 
%
% BK -  June 2021


here = pwd;
nsNwbFolder = fileparts(which(mfilename('fullpath')));
cd(nsNwbFolder);

%% Clean up current files
matnwb = fileparts(which('generateExtension'));
if isempty(matnwb)
    error('The matnwb toolbox must be on the path for this to work');
end
nsFile = fullfile(matnwb,'namespaces','neurostim.mat');
targetTypeFolder = fullfile(matnwb,'+types/+neurostim');
if exist(nsFile,'file')
    delete(nsFile)
end
if exist(targetTypeFolder,'dir')
    rmdir(targetTypeFolder,'s')
end

%%  Generate new files locally 
% (the neurorstim namespace file is
% automatically saved in matnwb/namespaces and not locally).
% Call matnwb tool
generateExtension('neurostim.namespace.yaml');
% Copy resulting m code to MatNWB folder
movefile('+types/+neurostim/*',targetTypeFolder)
[status,msg] = rmdir('+types'); % Clean up locally
cd (here); % Back to where we were