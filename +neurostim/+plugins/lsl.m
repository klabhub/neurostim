classdef lsl <  neurostim.plugin
    % Class to interact with the LSL Labrecorder app that records
    % Lab Streaming Layer data streams. Neurostim adds its own stream
    % (with ID and name neurostim) to send various markers.
    %
    % Dependencies:
    %   The LSL Library :  https://github.com/labstreaminglayer/liblsl-Matlab
    %   The LSL Recorder App: https://github.com/labstreaminglayer/App-LabRecorder
    %
    % To read the .xdf output files:
    %   The XDF reader : https://github.com/xdf-modules/xdf-Matlab
    %
    % Usage:
    %   Start LSL streaming on your devices (e.g., EEG)
    %   Start the LabRecorder app 
    %   Include the lsl plugin in your neurostim experiment and tell it 
    %   the IP and port of the LabRecorder.
    %
    %   .xdf output files with all of the streams (neurostim markers plus
    %   any device streams like EEG) are saved to an xdf file that is named
    %   following the neurostim convention
    %   (year/mo/dy/subject.paradigm.starttime.xdf).
    % 
    % PROPERTIES
    % ip - IP address of the computer runnnig LabRecorder [localhost]
    % port - port used by LabRecorder RCS [22345]
    % timeout - timeout for remote commands [10] seconds.
    % root  - Root data folder where LabRecorder should save its
    % files (if different on the remote machine). [cic.dirs.output]
    % The filename is constructed on the fly to match the neurostim
    % convention.
    %
    % BK -  Sept 2026.
    properties  (Transient)
        hTcp =[];  % Handle to the tcpclient object.
        hLib = []; % Handle to the LSL Lib
        outlet = []; % The LSL outlet for markers    
    end

    methods

        function delete(o)
            % Make sure the port is released
            o.hTcp =[]; % Remove the ref deletes it.
        end

        function o = lsl(c)
            % Construct a LabRecorder plugin.
            o=o@neurostim.plugin(c,'lsl');
            o.addProperty('fake',false);
            o.addProperty('ip','localhost'); % IP address of machine running LabRecorder.
            o.addProperty('port',22345); % Default port
            o.addProperty('timeout',10); % 10 s
            o.addProperty('root',''); % Root folder on the LabRecorder

            % Properties used to log events
            o.addProperty('file',[],sticky=true);
            o.addProperty('writing',false,sticky=true);
        end

        function connect(o)
            % Open a connection to the labrecorder
            if o.fake;fprintf('Fake connecting to %s:%d',o.ip,o.port); return;end
            o.hTcp =tcpclient(o.ip,o.port,Timeout=o.timeout, ConnectTimeout=o.timeout,Tag="ns2lsl");
            assert(~isempty(o.hTcp),"Failed to connect to %s:%d",o.ip,o.port)
        end

        function disconnect(o)
            % Close the marker stream and disconnect from the labrecorder
            if o.fake;fprintf('Fake disconnecting from %s:%d',o.ip,o.port); return;end
            if ~isempty(o.outlet)
                delete(o.outlet);
            end
            send(o,"update"); % Refresh stream list to remove the neurostim streams
            flush(o.hTcp);
            o.hTcp = []; % Delete reference to tcpclient.
        end

        function beforeExperiment(o)
            if ~o.fake
                assert(exist('lsl_loadlib','file'),'LSL not found. Cannot generate markers. See https://github.com/labstreaminglayer/liblsl-Matlab')
                % Create a marker stream to add to the recorder output
                o.hLib = lsl_loadlib;
                % Create a new stream
                info = lsl_streaminfo(o.hLib, ...
                    'neurostim', ...       % stream name
                    'Markers', ...             % stream type
                    1, ...                     % number of channels
                    0, ...                     % irregular sampling rate
                    'cf_string', ...           % channel format (using JSON)
                    'neurostim');   % unique source ID
                % Setup an outlet to send markers to the LSL Stream for Neurostim
                o.outlet = lsl_outlet(info);               
            end

            connect(o); % Connect to the LabRecorder
            [folder,filename] = fileparts([o.cic.fullFile '.mat']); % Add .mat to avoid stripping starttime
            if isempty(o.root)
                o.root = strrep(o.cic.dirs.output,'/','\');
            end
            rt =strrep(folder,strrep(o.cic.dirs.output,'/','\'),o.root);

            send(o,"update"); % Refresh stream list
            send(o,"select all"); % Select all streams for saving
            % Tell labrecorder where to save
            send(o,sprintf("filename {root:%s} {template:%s.xdf}",rt,filename))
            o.file = true; % Log
        end

        function beforeTrial(o)
            if  o.cic.trial ==1
                send(o,"start")
                o.writing = true;
                start = datetime('now');
                % Make sure the recorder is tracking the marker outlet
                if ~o.fake
                    while (datetime('now')< start + seconds(10))
                        if have_consumers(o.outlet)
                            break;
                        else
                            pause(0.5);
                        end
                    end
                    assert(have_consumers(o.outlet),'LabRecorder is not trakcing the neurostim marker outlet')
                end
                marker(o,struct('start',1));
                marker(o,struct('file',o.cic.fullFile)); % Store the filename in the xdf file marker stream
            end
            marker(o,struct('trial',o.cic.trial));            
        end

        function afterExperiment(o)
            % Stop
            if o.writing
                marker(o,struct('stop',1));
                pause(2); % Pause to make sure the last events are included
                send(o,"stop"); % Stop the recorder
                o.writing = false;
                send(o,"select none");
            end
            disconnect(o);
        end
    end


    methods (Access=protected)
         function send(o, msg)
            if o.fake
                fprintf('Fake: Sending %s to %s:%d\n',msg ,o.ip,o.port)
            else
                writeline(o.hTcp, msg);
                deadline = tic;
                reply = "";
                while toc(deadline) < o.timeout
                    if o.hTcp.NumBytesAvailable >= 2
                        reply = string(char(read(o.hTcp, 2, "uint8")'));
                        break
                    end
                    pause(0.01);
                end
                assert(numel(reply)==2 && reply(1) =="O" && reply(2) == "K", ...
                    "LabRecorder did not acknowledge command %s; response was %s", msg, reply);
            end
        end


        function marker(o,value)
            arguments
                o (1,1) neurostim.plugins.lsl
                value (1,1) struct
            end
            json = jsonencode(value);

            if o.fake
                fprintf('Fake payload %s pushed to lsl\n',json);
            else
                t = lsl_local_clock(o.hLib);
                push_sample(o.outlet,{json},t);
            end
        end
    end


    %% GUI Functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            if strcmpi(parms.onOffFakeKnob,'Fake')
                o.fake=true;
            else
                o.fake =false;
            end
        end
    end

    methods (Static, Access=public)
        function logOnset(s,startTime)
            % This function sends a message to the LSL marker stream to indicate
            % that a stimulus just appeared on the screen (i.e. first frame flip)
            % I use a static function to make the notation easier for the
            % user, but by using CIC I nevertheless make use of the
            % object that is currently loaded.
            % INPUT
            % s =  stimulus
            % startTime = flipTime in clocktime (i.e. not relative to the
            % trial)

            msg= struct('event','ON','stimulus',s.name,'flip', round(startTime,1),'duration',round(s.duration,1));
            marker(s.cic.lsl,msg);
        end


        function logOffset(s,stopTime)
            % This function sends a message to the LSL marker stream to indicate
            % that a stimulus just disappeared from the screen
            % INPUT
            % s =  stimulus
            % stopTime = flipTime in clocktime (i.e. not relative to the
            % trial)
            stopTime  = stopTime + 1000/s.cic.screen.frameRate;
            msg= struct('event','OFF','stimulus',s.name,'flip', round(stopTime,1));
            marker(s.cic.lsl,msg);
        end
    end

end
