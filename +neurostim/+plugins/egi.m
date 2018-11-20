classdef egi < neurostim.plugin
    % Plugin for EGI Netstation.
    % Wraps around the NetStation.m function in PTB.
    %
    % USAGE:
    % This will connect to the NetStation at the given IP, starts recording
    % before the experiment starts sends events at the start of every
    % trial, and stops recording at the end of the experiment.
    % 
    % Events sent to Netstation are also logged here.
    %
    % BK - Nov 2015
    % JD - Aug 2016: Major overhaul
    
    properties
        host@char = '10.10.10.42'; % '10.10.10.42' is NetStation default.
        port@double = 55513; % Default port for connection to NetStation.
        syncLimit  = 2.5; % Limits for acceptable sync (in ms).       
    end
    methods (Access=public)
        function o = egi(c)
            o = o@neurostim.plugin(c,'egi');
            o.addProperty('eventCode',''); % Used to log events
            o.addProperty('clockOffset',NaN); % Measured clock offset
            o.addProperty('clockVariability',NaN); % Measured clock variability
            o.addProperty('fineTuneClockOffset',0); % User specifiable offset to reduce AV tester offsets to 0
            o.addProperty('syncEveryN',Inf); %  Sync the clocks every N trials
            
        end 
        
        function logStimulusStart(o,stimulus)
            if ~iscell(stimulus);stimulus = {stimulus};end
            for i=1:numel(stimulus)
                addProperty(o.cic.(stimulus{i}),'startTime',-Inf,'thisIsAnUpdate',true,'postprocess',@(stim,val) logEvent(o,stim,val));
            end
        end
            
        function val = logEvent(o,stim,val)
            if val<0 || isinf(val);return;end % Don't log before trial start or when startTime is reset to -inf
            code = stim.name(1:4);            
            o.cic.egi.event(code,'valu',val); % This uses the handle to the egi plugin we know exists in the o.cic handle
        end

        % Send a timestamped event
        % See NetStation.m for details.
        function event(o,code,varargin)
            %NetStation('Event' [,code] [,starttime] [,duration] [,keycode1] [,keyvalue1] [...])
            [status,err] = NetStation('Event',code,o.cic.clockTime/1000,1/1000,varargin{:},'TTIM',o.cic.trialTime);
            o.eventCode = code; % Log the generation of the event here.
            o.checkStatusOk(status,err);
            o.writeToFeed(['NetStation: ' code ]);
        end
        
        function beforeExperiment(o)            
            o.connect;            
            o.synchronize; % Check that we can sync, and set the NetStation clock to ours.
            o.startRecording;
            o.event('BREC','DESC','Begin recording','FLNM',o.cic.fullFile,'PDGM',o.cic.paradigm,'SUBJ',o.cic.subject);
        end
        
        
        function afterExperiment(o)
            o.event('EREC','DESC','End recording');
            o.stopRecording;
            o.disconnect;
        end
        
        function beforeTrial(o)
            % Should we sync again? Or is once enough beforeExperiment?
            % O.synchronize; .
            if mod(o.cic.trial,o.syncEveryN)==0
                NetStation('RESETCLOCK',(o.cic.clockTime-o.clockOffset-o.fineTuneClockOffset),0);        
            end
            o.event('BTRL','DESC','Begin trial','TRIA',o.cic.trial,'BLCK',o.cic.block,'COND',o.cic.conditionName);            
        end
        
        function afterTrial(o)
            o.event('ETRL','DESC','End trial','TRIA',o.cic.trial,'BLCK',o.cic.block,'COND',o.cic.conditionName);            
        end
    end
    
    % Functions below are simple wrappers around the NetStation.m
    % funcionality.
    methods (Access=protected)
        % Connect to a named host
        function connect(o)
            o.writeToFeed('Trying to connect to EGI-host %s:%d',o.host,o.port);
            [status,err] = NetStation('Connect',o.host,o.port);
            if o.checkStatusOk(status,err)
                o.writeToFeed('Connected to EGI-host %s:%d',o.host,o.port);
            else
                o.writeToFeed('Failed to connect. Make sure ECI Events for TCP port %d is checked in Netstation',o.port);
            end
        end 
        
        % Disconnect
        function disconnect(o)
            [status,err] = NetStation('Disconnect');
            if o.checkStatusOk(status,err)
                o.writeToFeed('Disconnected from EGI-host %s:%d',o.host,o.port);
            end
        end
        
        % synchronize the clocks off the computer running PTB and the
        % NetStation.
        function synchronize(o,slimit)
            if exist('slimit','var') && ~isempty(slimit)
                o.syncLimit = slimit;
            end
            [status,err,value] = NetStation('Synchronize',o.syncLimit);
            o.clockOffset = value(1); %ms
            o.clockVariability = value(2);
            % Now use that mean offset 
            NetStation('RESETCLOCK',(o.cic.clockTime-o.clockOffset-o.fineTuneClockOffset),0);
            if o.checkStatusOk(status,err)
                o.writeToFeed('Synchronized with EGI-host  \Delta: %f \sigma %f', o.clockOffset,o.clockVariability);
            end
        end

       % start recording
        function startRecording(o)
            [status(1),err{1}]=NetStation('StartRecording');
            [status(2),err{2}]=NetStation('FlushReadbuffer'); % not sure what this does (JD)
            if o.checkStatusOk(status,err)
                o.writeToFeed('Started recording on EGI-host %s:%d',o.host,o.port);
            end
        end
        
        % stop recording
        function stopRecording(o)
            [status(1),err{1}]=NetStation('FlushReadbuffer'); % not sure what this does (JD)
            [status(2),err{2}]=NetStation('StopRecording');
            if o.checkStatusOk(status,err)
                o.writeToFeed('Stopped recording on EGI-host %s:%d',o.host,o.port);
            end
        end
        
       
    
        % support function to check 1 or more status reports
        function ok = checkStatusOk(o,status,err)
            if ~iscell(err), err={err}; end
            ok=true;
            for i=1:numel(status)
                if status(i)~=0
                    ok=false;
                    o.cic.error('STOPEXPERIMENT',err{i});
                end
            end
        end
        
            
    end
end