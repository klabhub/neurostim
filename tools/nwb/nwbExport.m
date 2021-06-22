function o = nwbExport(c,sessionDescription,varargin)
% Export a CIC object to a Neurodata Without Borders format.
% NOTE  Work In Progress - see multiple TODO below 
% 
% INPUT 
% Required
% c  - A cic object or a file name with a file that contains c .
% sessionDescription 
%
% Parm/value pairs (optional)
% outFile - filename to save the NWB fle to [defaults to same name as the
%           cic object, with .nwb extension]
% general - A struct with fields matching the xxx in general_xxx properties of the
%           NWBFile. 
% subject - A struct with fields matching the fields of the
%                   types.core.Subject object. If the subject_id is not set,
%                   it will be set by the value stored in the CIC object.
%
% timezone - Timezone to use for session_start_time. ['' : no time zone]
% 
% All NWBFile properties can be set as parameter/value pairs.
% 
% OUTPUT
%  o -  The NWBFile object. If no output is requested, the file is savd.
% 
% EXAMPLE:
% 
% c =neurostim.cic; 
% general.experimenter = 'BK';
% general.institution = 'Rutgers University - Newark';
% subject = struct('subject_id','003','age','P21Y','species','homo sapiens','sex','M')
% o = neurostim.utils.nwb(c,'An empty session','timezone','America/New_York','general',general)
% 
% BK - June 2021

if isempty(which('NwbFile'))
    error('The nwb function needs access to the NWB tools. Install from https://www.nwb.org/');
end
p = inputParser;
p.KeepUnmatched = true;
p.addRequired('c',@(x) (isa(x,'neurostim.cic') || ischar(x)));
p.addRequired('session_description',@ischar);
p.addParameter('outFile','',@ischar);
p.addParameter('general',struct([]),@(x) isstruct(x) || isa(x,'types.untyped.Set'));
p.addParameter('subject',struct([]),@(x) (isstruct(x) || isa(x,'types.core.Subject')));
p.addParameter('timezone','',@ischar); % '' is without timezone, or specify zone
p.parse(c,sessionDescription,varargin{:});

if ischar(c)
    load(c,'c');
end
    
% Pull values from inputParser
% general_xxxx properties
general = struct2parmValue(p.Results.general,'general_');
unmatched = struct2cell(p.Unmatched);

% Neurostim specific conventions to store in NWB file
identifier = [c.subject '_' c.paradigm '@' datestr(c.startTime,'yyyy-mm-ddTHH:MM:SS.FFF') ];
format = 'yyyy-MM-dd''T''HH:mm:ss.SSS';
if ~isempty(p.Results.timezone)
    format = [format 'ZZZZZ'];
end
session_start_time = datetime(c.startTime,'timezone',p.Results.timezone,'convertfrom','datenum','Format',format);
% All time stamps use GetSecs. 
if isnan(c.startClockTime)
    % In this data file there is no way to link timestamps this directly to c,startTime; we
    % identify startTime with the time that the first block started. (even
    % though this is later; that deos not affect relative timing within the file)
    [~,~,~,timeZero] = get(c.prms.blockCntr,'dataIsMember',1);
else
    % startClockTime is the clockTime at c.startTime; reference time stamps
    % to that.
    timeZero = c.startClockTime;
end
   


%% Create the NwbFile object
o = NwbFile(general{:},unmatched{:},'identifier',identifier,...
            'session_start_time',char(session_start_time),...
            'timestamps_reference_time',char(session_start_time),...
            'session_description',sessionDescription);

        
        
%% Add in subject details
if ~isempty(p.Results.subject)
    % Set detailed general_subject information 
    if isa(p.Results.subject,'types.core.Subject')
        subject = p.Results.subject;
    else
        pv =struct2parmValue(p.Results.subject);
        subject = types.core.Subject(pv{:});
    end
    if isempty(subject.subject_id)
        subject.subject_id = c.subject;
    end
    o.general_subject = subject;
end


%% Collect stimulus and plugin information
perTrialInfo = {};
perExperimentInfo = {};
for plg = 1:numel(c.pluginOrder)    
    thisPlg = c.pluginOrder(plg);
    fld = fieldnames(thisPlg.prms);
    for p = 1:numel(fld)
        thisFld = thisPlg.prms.(fld{p});
        changesInTrial{plg}(p) = thisFld.changesInTrial;
        if changesInTrial{plg}(p)
            % Requires its own time series.
             [thisValue,~,~,thisTime] = get(thisPlg.prms.(fld{p}),'atTrialTime',0,'matrixIfPossible',true);
             % TODO Prune outside trial
             % TODO  Create dataset to store as timeseries and add to
             % metadata
             tseries.([thisPlg.name '_' fld{p}]) = thisTime;
        else
            % Store with trial info
            thisValue = get(thisPlg.prms.(fld{p}),'atTrialTime',0,'matrixIfPossible',true);
            if iscell(thisValue)
                % TODO make string arrays? Cells fail to save.
                nr = 0;size(thisValue,1);                
            else
                % TODO:  all nan should be removed
                uValue = unique(thisValue);
                nr = numel(uValue);
            end
            thisName = [thisPlg.name '_' fld{p}];
            %Ignore prms without a single value set
            if nr==1
                % Constant for the experiment
                perExperimentInfo = cat(2,perExperimentInfo,{thisName,uValue});
            elseif nr>1
                % Changes per trial               
               perTrialInfo = cat(2,perTrialInfo,{thisName,types.hdmf_common.VectorData('data',thisValue,'description',thisName)});
            end
        end
    end
end
nrTotal = sum(cellfun(@numel,changesInTrial))
nrChanges = sum(cellfun(@sum,changesInTrial))
%TODO as untyped set this becomes a MAP in matlab. Not clear whether that
%is ideal maybe create a separate data type?  Or one dataset per plugin to
%make referencing values easier? 
pe = types.untyped.Set(perExperimentInfo{:});

% Add Neurostim specific meta data
repoV = c.repoVersion;
repoV = struct('remote','unknown','branch','unknown','changes','unknown','hash','unknown');

nsMeta = types.neurostim.NeurostimMetaData('version',repoV,'matlab',c.matlabVersion,'psychtoolbox',c.ptbVersion.version,'script',c.expScript,'file',c.fullFile,'plugins',pe);

o.general.set('neurostim',nsMeta);
        


%% Add trial info

[~,~,~,trialStart] =  get(c.prms.firstFrame);
[~,~,~,trialStop]  = get(c.prms.trialStopTime);
condition = get(c.prms.condition,'atTrialTime',0)-1; % Base zero for consistency
block =  get(c.prms.block,'atTrialTime',0)-1;
blockCntr = get(c.prms.blockCntr,'atTrialTime',0)-1; 
blockTrial = get(c.prms.blockTrial,'atTrialTime',0)-1;
nrTrials = numel(trialStart);
trialStart = (trialStart - timeZero)/1000;
trialStop = (trialStop -timeZero)/1000;
o.intervals_trials = types.core.TimeIntervals( ...
    'colnames', {'start_time', 'stop_time','condition','block','block_cntr','block_trial',perTrialInfo{1:2:end}}, ...
    'description', 'Trial data', ...
    'id', types.hdmf_common.ElementIdentifiers('data', 0:nrTrials-1), ...
    'start_time', types.hdmf_common.VectorData('data', trialStart, ...
   	'description','start time of trial'), ...
    'stop_time', types.hdmf_common.VectorData('data', trialStop, ...
   	'description','end of each trial'),...
    'condition',  types.hdmf_common.VectorData('data', condition, ...
   	'description','condition number'),...
    'block',  types.hdmf_common.VectorData('data', block, ...
   	'description','block number'),...
    'block_cntr',  types.hdmf_common.VectorData('data', blockCntr, ...
   	'description','sequential block number'),...
    'block_trial',  types.hdmf_common.VectorData('data', blockTrial, ...
   	'description','trial number in the block'),...
    perTrialInfo{:});    
    


%% Save if no output requested
if nargout==0
    %Save to file
    if isempty(p.Results.outFile)
        outFile  = [c.file '.nwb'];
    else
        outFile = p.Results.outFile;
    end
    nwbExport(o,outFile);
end
    
end

function c = struct2parmValue(s,pre)
if isempty(s);c={};return;end
% Take a struct and convert it to parm/value pairs
% with (optionally) a string prepended to each field of the struct
c = struct2cell(s);
names= fieldnames(s);
if nargin>1
    names = strcat(pre,names);
end
c= cat(2,names,c)';
end