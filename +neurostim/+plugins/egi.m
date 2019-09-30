classdef egi < neurostim.plugin
    % Plugin for EGI Netstation.
    % Wraps around the NetStation.m function in PTB.
    %
    % USAGE:
    % This will connect to the NetStation at the given host name, starts recording
    % before the experiment starts sends events at the start and stop of every
    % trial, and stops recording at the end of the experiment.
    % 
    % To add stimulus onset events, define the .onsetFunction property of a
    % stimulus as:
    % 
    % g.onsetFunction  =@neurostim.plugins.egi.logOnset; 
    % 
    % Before using this plugin, please run the egiAvTester.m script in the
    % tools directory to investigate the reliability of your timing (and
    % define the constant offset of stimulus onset events).
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
            if isempty(which('NetStation.m'))
                error('Cannot find the NetStation.m file. Please add it to your path( from psychtoolbox). ');                
            end
            o = o@neurostim.plugin(c,'egi');
            o.addProperty('eventCode','');  % Logs the event codes transmitted to NetStation
            o.addProperty('clockOffset',0); % Clock offset used to synchronize NetStation with cic.clocktime
            o.addProperty('eventAckTime',NaN); % Measured time to deliver and acknowledge an event 
            o.addProperty('eventAckVariability',NaN); % Measured variability in time to deliver/ack.            
            o.addProperty('syncEveryN',Inf); %  Sync the clocks every N trials (not needed when useNTPSync is true)
            o.addProperty('useNTPSync',true);% Toggle to use NTP synchronization (NetStation 3.5 and later, NetAmp 400 series: see NetStation.m)
            o.addProperty('ntpServer','10.10.10.51'); % The IP address of the NetAMP (which will serve as NTP time server).
        end 
        
        

        % Send a timestamped event
        % See NetStation.m for details.
        function event(o,code,time,duration,varargin)
            % Send a timestamped event to Netstation (and wait for
            % acknowledgment)
            % code = 4 letter code
            % time = time in milliseconds when the event occurred on the
            %           CIC clock. If left empty, it defaults to the 
            %           cic.clockTime at the time of calling this function.
            % duration = duration of the event in milliseconds.  [1]
            % The remaining parm/value pairs will be passed as key/value
            % pairs to NetStation and stored without changes. 
            % Note that trial time (TTIM) is added to the NetStation event
            % automatically and trial number (TRIA) and block
            % number (BLCK) and condition (CND) are stored in the begin trial (BTRL) event.
            % So there is no need to include those in the call to this
            % function.
            %                        
            if isempty(time)
                time = o.cic.clockTime;                 
            end
            if isempty(duration)
                duration = 1;
            end            
            % Correct the time for the known clockoffset (measured and then fixed per rig)
            % Then send.  
            [status,err] = NetStation('Event',code,(time+o.clockOffset)/1000,duration/1000,varargin{:},'TTIM',o.cic.trialTime);
            o.eventCode = code; % Log the generation of the event here.
            o.checkStatusOk(status,err);
            o.writeToFeed(['NetStation: ' code ]);
        end
        
        function beforeExperiment(o)            
            o.connect;            
            o.synchronize; % Check that we can sync reliably
            o.startRecording;
            o.event('BREC',[],[],'DESC','Begin recording','FLNM',o.cic.fullFile,'PDGM',o.cic.paradigm,'SUBJ',o.cic.subject);
        end
        
        
        function afterExperiment(o)
            o.event('EREC',[],[],'DESC','End recording');
            o.stopRecording;
            o.disconnect;
        end
        
        function beforeTrial(o)
            if mod(o.cic.trial,o.syncEveryN)==0 && ~o.useNTPSync 
                % Repeated syncs are not necessary (and time consuming!)
                % with NTP Sync, so only do this in non-NTP.
                o.synchronize; 
            end
            o.event('BTRL',[],[],'DESC','Begin trial','TRIA',o.cic.trial,'BLCK',o.cic.block,'COND',o.cic.condition);            
        end
        
        function afterTrial(o)
            % Deliver the events that were queued during the trial
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
            if o.useNTPSync
                % Synchronization using the NetAMP NTP server - highly
                % reliable and drift across time is automatically removed
                [status,err] = NetStation( 'GetNTPSynchronize', o.ntpServer );
            else                
                % Older way to sync time clocks - this needs to be repeated
                % every few trials (~40 or so when BK tested).
                [status,err] = NetStation('Synchronize',o.syncLimit);
            end
            if o.checkStatusOk(status,err)
              o.writeToFeed('Synchronized with EGI-host');
           end
        end

       % start recording
        function startRecording(o)
            [status(1),err{1}]=NetStation('StartRecording');
            [status(2),err{2}]=NetStation('FlushReadbuffer'); 
            if o.checkStatusOk(status,err)
                o.writeToFeed('Started recording on EGI-host %s:%d',o.host,o.port);
            end
        end
        
        % stop recording
        function stopRecording(o)
            [status(1),err{1}]=NetStation('FlushReadbuffer'); 
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
        
        function addToEventQueue(o,thisE)
            % Because sending event takes time we avoid doing this during
            % the time-critical periods of a trial. Each event is stored
            % here in a cell array and then all are sent to NetStation after
            % the current trial ends. This is possible because we also
            % stored the time that the event occurrred (so NetStation
            % stores it at the right location in its datastream).           
            % INPUT
            % stim  = stimulus object that generated the event. 
            % thisE = Cell array containing event information. 
            %       {code,startTime,duration,parm/value pairs}
            
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
            code = [s.name(1:min(numel(s.name),2)) 'ON']; % First 2 char of name plus 'ON'
            hEgi= s.cic.egi;            
            thisE = {code,startTime,s.duration,'FLIP',startTime,'DESC',[s.name ' onset']};
            hEgi.addToEventQueue(s,thisE);
        end
        function logOffset(s,stopTime)
            % This function sends a message to NetStation to indicate that
            % a stimulus just disappeard from the screen (i.e. first frame flip)
            % I use a static function to make the notation easier for the
            % user, but by using CIC I nevertheless make use of the egi
            % object that is currently loaded.
            % INPUT
            % s =  stimulus
            % stopTime= flipTime in clocktime (i.e. not relative to the
            % trial)                        
            code = [s.name(1:min(numel(s.name),2)) 'OF'];
            hEgi= s.cic.egi;            
            thisE = {code,stopTime,1,'FLIP',stopTime,'DESC',[s.name ' offset']};
            hEgi.addToEventQueue(s,thisE);
        end
    end
end