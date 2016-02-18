classdef egi < neurostim.plugin
    % Plugin for EGI Netstation.
    % Wraps around the NetStation.m function in PTB.
    %
    % USAGE:
    % This will connect to the NetStation at the given IP, starts recording
    % before the experiment starts sends a STRT event at the start of every
    % trial, and stops recording at the end of the experiment.
    %
    % e = egi('192.169.1.110'); % IP address of the NetStation
    % e.syncLimit = 2.5;  %Synchrontization must be better than this (ms).
    % c.add(e) ; % Add to CIC. Done.
    %
    %
    % BK - Nov 2015
    
    properties
        host@char;
        port@double = 55513; % Default port for connection to NetStation.
        syncLimit  = 2.5; % Limits for acceptable sync (in ms).
    end
    
    
    methods (Access=public)
        function o = egi(h)
            o = o@neurostim.plugin('egi');
            o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT'});
            if nargin >0
                o.host = h;
            end
        end
        
        function beforeExperiment(o,c,evt)
            o.connect;
            o.synchronize; % Check that we can sync, and set the NetStation clock to ours.
            o.startRecording;
        end
        
        function afterExperiment(o,c,evt)
            o.stopRecording;
            o.disconnect;
        end
        
        function beforeTrial(o,c,evt)
            % Should we sync again? Or is once enough beforeExperiment?
            % O.synchronize; .
            
            % Put a sync event with the current time and trial in the EGI file.
            o.event('STRT',c.clockTime,0.001,'TRIA',c.trial);
        end
        
    end
    
    
    %%
    % Functions below are simple wrappers around the NetStation.m
    % funcionality.    
    methods (Access=protected)
        
        % Connect to a named host
        function connect(o,h,p)
            if nargin>1
                o.host = h;
            end
            if nargin >2
                o.port = p;
            end
            warning(['Connecting to ' o.host])
            [status,err] = NetStation('Connect',o.host,o.port);
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            else
                warning(['Connected to  ' o.host ]);
            end
        end
        
        % Disconnect
        function disconnect(o)
            [status,err] = NetStation('Disconnect');
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            else
                warning(['Disconnected from ' o.host ]);
            end
        end
        
        % synchronize the clocks off the computer running PTB and the
        % NetStation.
        function synchronize(o,slimit)
            if nargin>1
                o.syncLimit = slimit;
            end
            [status,err] = NetStation('Synchronize',o.syncLimit);
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            else
                warning(['Synchronized with ' o.host ]);
            end
        end
        
        
        % start recording
        function startRecording(o)
            [status,err] =NetStation('StartRecording');
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            else
                warning(['Started recording on ' o.host ]);
            end
        end
        
        % stop recording
        function stopRecording(o)
            [status,err] =NetStation('StopRecording');
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            else
                warning(['Stopped recording on ' o.host ]);
            end
        end
        
        % Send an event to the NetStation (and the data file).
        % code = a unique identifier for this event
        % startTime = the time (in local time) that this event happened
        % duration = duration of the event
        % keyCode  = a four character code
        % keyValue = data associated with this code.
        % ack  = true/false to wait for acknowledgment
        % varargin = parm/value pairs to store additional data. Parms
        % should be 4 char codes.
        % See NetStation.m for details.
        function event(o,code,startTime, duration, keyCode,keyValue,ack,varargin)
            nin = nargin;
            % Set the same defaults as NetStation.m does.
            if nin<7
                ack=true;
                if nin <6
                    keyValue = 0;
                    if nin <5
                        keyCode = 'dumm';
                        if nin<4
                            duration = 0.001; %s
                            if nin<3
                                startTime = GetSecs();
                                if nin< 2
                                    code = 'EVEN';
                                end
                            end
                        end
                    end
                end
            end
            
            if ack
                [status,err] = NetStation('Event',code,startTime, duration, keyCode, keyValue, varargin{:});
            else
                % No Ack
                [status,err] = NetStation('EventNoAck',code,startTime, duration, keyCode, keyValue, varargin{:});
            end
            if status~=0
                o.cic.error('STOPEXPERIMENT',err);
            end
            
        end
        
    end
end