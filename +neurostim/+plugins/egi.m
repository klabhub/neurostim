classdef egi < neurostim.plugin
    % Plugin for EGI Netstation.
    % Wraps around the NetStation.m function in PTB.
    %
    % USAGE:
    % This will connect to the NetStation at the given IP, starts recording
    % before the experiment starts sends a STRT event at the start of every
    % trial, and stops recording at the end of the experiment.
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
            o.addProperty('eventCode',''); % Used to log events here.            
            o.listenToEvent({'BEFOREEXPERIMENT','BEFORETRIAL','AFTERTRIAL','AFTEREXPERIMENT'});
        end 
        function beforeExperiment(o,c,evt)            
            o.connect;            
            o.synchronize; % Check that we can sync, and set the NetStation clock to ours.
            o.startRecording;
            o.event('BREC','DESC','Begin recording','FLNM',c.fullFile,'PDGM',c.paradigm,'SUBJ',c.subject);
        end
        function afterExperiment(o,c,evt)
            o.event('EREC','DESC','End recording');
            o.stopRecording;
            o.disconnect;
        end
        function beforeTrial(o,c,evt)
            % Should we sync again? Or is once enough beforeExperiment?
            % O.synchronize; .
            o.event('BTRL','DESC','Begin trial','TRIA',c.trial,'BLCK',c.block,'COND',c.conditionName);            
        end
        function afterTrial(o,c,evt)
            o.event('ETRL','DESC','End trial','TRIA',c.trial,'BLCK',c.block,'COND',c.conditionName);            
        end
    end
    
    % Functions below are simple wrappers around the NetStation.m
    % funcionality.
    methods (Access=protected)
        % Connect to a named host
        function connect(o)
            disp(['Trying to connect to EGI-host ' o.host ':' num2str(o.port)]);
            [status,err] = NetStation('Connect',o.host,o.port);
            if o.checkStatusOk(status,err)
                disp(['Connected to EGI-host ' o.host ':' num2str(o.port) ]);
            else
                disp(['Failed to connect. Make sure ECI Events for TCP port ' num2str(o.port) ' is checked in Netstation']);
            end
        end 
        
        % Disconnect
        function disconnect(o)
            [status,err] = NetStation('Disconnect');
            if o.checkStatusOk(status,err)
                disp(['Disconnected from EGI-host ' o.host ':' num2str(o.port) ]);
            end
        end
        
        % synchronize the clocks off the computer running PTB and the
        % NetStation.
        function synchronize(o,slimit)
            if exist('slimit','var') && ~isempty(slimit)
                o.syncLimit = slimit;
            end
            [status,err] = NetStation('Synchronize',o.syncLimit);
            if o.checkStatusOk(status,err)
                disp(['Synchronized with EGI-host ' o.host ':' num2str(o.port) ]);
            end
        end

        % start recording
        function startRecording(o)
            [status(1),err{1}]=NetStation('StartRecording');
            [status(2),err{2}]=NetStation('FlushReadbuffer'); % not sure what this does (JD)
            if o.checkStatusOk(status,err)
                disp(['Started recording on EGI-host ' o.host ':' num2str(o.port) ]);
            end
        end
        
        % stop recording
        function stopRecording(o)
            [status(1),err{1}]=NetStation('FlushReadbuffer'); % not sure what this does (JD)
            [status(2),err{2}]=NetStation('StopRecording');
            if o.checkStatusOk(status,err)
                disp(['Stopped recording on EGI-host ' o.host ':' num2str(o.port) ]);
            end
        end
        
        % Send a timestamped event
        % See NetStation.m for details.
        function event(o,code,varargin)
            %NetStation('Event' [,code] [,starttime] [,duration] [,keycode1] [,keyvalue1] [...])
            [status,err] = NetStation('Event',code,GetSecs,1/1000,varargin{:},'CTIM',o.cic.clockTime);
            o.eventCode = code; % Log the generation of the event here.
            o.checkStatusOk(status,err);
%             if ~o.cic.guiOn
%                 o.cic.writeToFeed(['NetStation: ' code ]);
%             end
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