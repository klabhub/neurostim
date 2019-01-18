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
    % BK - Jan 2019. Overhaul, proper timing testing.
    
    properties
        host@char = '10.10.10.42'; % '10.10.10.42' is NetStation default.
        port@double = 55513; % Default port for connection to NetStation.
        syncLimit  = 2.5; % Limits for acceptable sync (in ms).       
    end
    properties (SetAccess= protected)
        eventQ = cell(10,1); % Preallocate cell for 10 events 
        nrInQ = 0;
    end
    methods (Access=public)
        function o = egi(c)
            o = o@neurostim.plugin(c,'egi');
            o.addProperty('eventCode','');  % Logggin event codes transmitted to NetStation
            o.addProperty('clockOffset',0); % Clock offset used to synchronize NetStation with cic.clocktime
            o.addProperty('eventAckTime',NaN); % Measured time to deliver and acknowledge an event 
            o.addProperty('eventAckVariability',NaN); % Measured variability in time to deliver/ack.            
            o.addProperty('syncEveryN',Inf); %  Sync the clocks every N trials                 
        end 
        
        

        % Send a timestamped event
        % See NetStation.m for details.
        function event(o,code,time,duration,varargin)
            % Send a timestamped event to Netstation (and wait for
            % acknowledgment)
            % code = 4 letter code
            % time = time in milliseconds when the event occurred
            % duration = duration of the event in milliseconds 
            % The remaining parm/value pairs will be passed as key/value
            % pairs to NetStation and stored without changes. 
            % Note that trial time (TTIM) are added to the NetStation event
            % automatically and trial number (TRIA) and block
            % number (BLCK) and condition (CND) are stored in the begin trial (BTRL) event.
            % So there is no need to include those in the call to this
            % function.
            
            
            %NetStation('Event' [,code] [,starttime] [,duration] [,keycode1] [,keyvalue1] [...])
            if isempty(time)
                time = o.cic.clockTime;                 
            end
            if isempty(duration)
                duration = 1;
            end            
            [status,err] = NetStation('Event',code,time/1000,duration/1000,varargin{:},'TTIM',o.cic.trialTime);
            o.eventCode = code; % Log the generation of the event here.
            o.checkStatusOk(status,err);
            o.writeToFeed(['NetStation: ' code ]);
        end
        
        function beforeExperiment(o)            
            o.connect;            
            o.synchronize; % Check that we can sync, and set the NetStation clock to ours.
            o.startRecording;
            o.event('BREC',[],[],'DESC','Begin recording','FLNM',o.cic.fullFile,'PDGM',o.cic.paradigm,'SUBJ',o.cic.subject);
        end
        
        
        function afterExperiment(o)
            o.event('EREC',[],[],'DESC','End recording');
            o.stopRecording;
            o.disconnect;
        end
        
        function beforeTrial(o)
            % Should we sync again? Or is once enough beforeExperiment?
            
            if mod(o.cic.trial,o.syncEveryN)==0
                o.synchronize; 
%                NetStation('RESETCLOCK',(o.cic.clockTime-o.clockOffset),0);        
            end
            o.event('BTRL',[],[],'DESC','Begin trial','TRIA',o.cic.trial,'BLCK',o.cic.block,'COND',o.cic.condition);            
        end
        
        function afterTrial(o)
            % Deliver the events that were queued
            for i=1:o.nrInQ
                o.event(o.eventQ{i}{:}); % Send the queued events to netstations                
            end
            o.nrInQ = 0; % Reset counter
            o.eventQ = cell(numel(o.eventQ),1);% Prealoc for next trials
            o.event('ETRL',[],[],'DESC','End trial');            
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
        
        % synchronize the clocks of the computer running PTB and the
        % NetStation.
        function synchronize(o,slimit)
            if exist('slimit','var') && ~isempty(slimit)
                o.syncLimit = slimit;
            end
            % This measures the time it takes to send and acknowledge an
            % event.            
            %NetStation('RESETCLOCK',(o.cic.clockTime-o.clockOffset),0);
            [status,err,value] = NetStation('Synchronize',o.syncLimit);
            o.eventAckTime = value(1); %ms  (mean over 100 sends)
            o.eventAckVariability = value(2); % Stdev over 100 sends

            
            NetStation('RESETCLOCK',(o.cic.clockTime-o.clockOffset),0);
           
            if o.checkStatusOk(status,err)
                o.writeToFeed('Synchronized with EGI-host  Delta: %f sigma %f', o.eventAckTime,o.eventAckVariability);
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
        
        function addToEventQueue(o,s,startTime)
             code = s.name(1:min(numel(s.name),4)); % Use the first four letters of the stimulus name
             thisE = {code,startTime,s.duration,'FLIP',startTime,'DESC',[s.name ' onset event']};
             if o.nrInQ+1 > numel(o.eventQ)
                 % Preallocate more space
                 chunkSize =10;
                 o.evenQ = cat(1,o.eventQ,cell(chunkSize,1));
             end
             o.eventQ{o.nrInQ+1} = thisE;  
             o.nrInQ = o.nrInQ +1;
        end
    end
    
    methods (Static)
        
        function logOnset(s,startTime)
            % This function sends a message to NetStation to indicate that
            % a stimulus just appeared on the screen (i.e. first frame flip)
            % I use a static function to make the notation easier for the
            % user, but by using CIC I nevertheless make use of the egi
            % object that is currently loaded.
            % INPUT
            % s =  stimulus
            % startTime = flipTime in clocktime (i.e. not relative to the
            % trial)            
            
            s.cic.egi.addToEventQueue(s,startTime)
        end
    end
end