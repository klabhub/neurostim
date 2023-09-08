classdef intanrhx < neurostim.plugin    
    % The IntanRHX plugin sets up the file name on the RHX recorder, starts 
    % and stops recording, it can be used to enable/disable channels
    % for recording, and it can get/set any parameter on Intan RHD and RHS 
    % devices.
    %
    % Note 1. There is another plugin (intan.m) which does not seem
    % to match the current (2023) TCP interface of the RHX software, but it
    % presumably talks to some other Intan product. 
    %
    % Note 2. This plugin only uses the command set/get/execute interface
    % to the RHX software. The same TCP interface also provides realtime
    % access to the data (waveforms and spikes) that are being recorded.
    % This could be added by someone who wants to do realtime feedback
    % control. 
    %     
    %
    % Properties
    %   'host'   - The network name or IP address of the computer running
    %               the  INTAN RHX software.
    %   'port'   - The port on which the RHX server is listening (open the
    %               Network item in the RHX menu; the port is listed
    %               there. While you're there, press connect to allow
    %               incoming connections).
    %   secondsBetweenWrites - Minimum time between two commands written to
    %   the TCP command interface. 10 ms seems to be enough. 0 ms is not. 
    %   secondsBeforeRead - Time between sending a get command and reading
    %           the reply from RHX. 50 ms is enough, maybe shorter waits would work
    %           too. 
    %  Several settings of the Intann device are read and stored by
    %  neurostim. See the Intan RHX TCP guide for details.
    %   sampleRateHertz
    %   version
    %   headstagePresent
    % Other RHX TCP parameters are set by neurostim and can be changed:
    %   fileFormat 
    %   writeToDiskLatency
    %   newSaveFilePeriodMinutes
    % The default values (Traditional/Highest/999) work fine for BK's
    % intended use (low channel count recording, no data streaming).
    %
    % The plugin tells RHX to create a new folder for each experiment. This
    % folder will have a name that matches the neurostim file, but with a timestamp
    % attached. The main reason for a subfolder is to allow RHX to save its
    % settings.xml file in there (which could be different for each
    % experiment in a session). 
    % 
    % If your Neurostim computer saves to a different drive, you use
    %   'drive'    - Map a drive on the neurostim ccomputer to a different
    %               drive on the computer running Trellis (in case they are not saving
    %               to the same place on a network)
    %    
    %
    % NOTE
    %  The tcp client command connection is stored as a global variable (hIntanCommand)
    % This avoids issues with connecting/reconnecting for every
    % experiment. If connections fail, use clear global in Matlab and press
    % disconnect/connect in the RHX Network menu.
    % 
    % EXAMPLE
    % First go to the computer running RHX, check its network name or ip,
    % open the Network menu in RHX, note the port, and press Connect.
    %
    %  rhx = neurostim.plugins.intanrhx(c);
    %  rhx.host = 'intanpc.local'; % The name of the PC running RHX
    %  rhx.port = 5000;         % Port where RHX is listening
    %  rhx.drive = {'z:\','c:\'} % NS computer saves to Z: but Intan should
    %                               save to its c: drive
    % enable(c.intanrhx,'A',0:2,true);   % Enable viewing/recording three
    %                                       channels on Port A
    % enable(c.intanrhx,'B',0:31,true)  % Disable all of port B
    % You can also send arbitrary commands to RHX as a cell array of
    % commands. 
    % For instance, to record Digitial input channel 1 and give custom
    % names to two channels:
    % cmds = {'set DIGITAL-IN-01.enabled true',...
    %    'set A-001.CustomChannelName Auditory',...
    %    'set DIGITAL-IN-01.CustomChannelName TrialStart'};
    % intanSend(rhx,cmds);
    %
    % The syntax for these commands is defined in the Intan RHX TCP guide.
    % In principle any set or execute command can be sent. Neurostim does not 
    % do any error checking on these. You shoudl check the Errors window in
    % the RHX network menu to make sure commands are recognized (those that
    % are not are simply ignored, with an error message).
    %
    % To retrieve information about parameters in the RHX software, use the
    % intanGet command. For instance the following command will retrieve
    % the type of the board that is connected. 
    %
    % type =intanGet(rhx,'Type')
    % BK - Sept 2023.
    
   properties  (SetAccess  = protected)
       % Set by the constructor
       host (1,1) string 
       port (1,1) double 
   end
    methods (Access=public)
        
        function o = intanrhx(c,hst,prt)
            arguments
                c (1,1) neurostim.cic
                hst (1,1) string = 'localhost'
                prt (1,1) double = 5000
            end
           
            % Construct a intanrhx plugin
            o = o@neurostim.plugin(c,'intanrhx');

            o.addProperty('secondsBetweenWrites',0.01);  % Allow the RHX to handle the message for at least this many seconds, before sending the next.
            o.addProperty('secondsBeforeRead',0.05) % When sending a GET, wait at least this long before collecting the response.
            o.addProperty('timeout',2); % Timeout in seconds (waiting on a Intan response to a get).

            % Properties that are read from the RHX
            o.addProperty('sampleRateHertz',[]);
            o.addProperty('version',[]);
            o.addProperty('headstagePresent',[]);

            % Intant Properties that are set by neurostim
            o.addProperty('fileFormat','Traditional'); % "Traditional, OneFilePerSignalType, OneFilePerChannel
            o.addProperty('writeToDiskLatency','Highest'); % Highest, High, Medium,Low,Lowest
            o.addProperty('newSaveFilePeriodMinutes',999); % 
            
            o.addProperty('trialStart',NaN);
            o.addProperty('trialStop',NaN);
            o.addProperty('startSave',NaN);
            o.addProperty('stopSave',NaN);
            o.addProperty('drive',{}); % Optional - change output drive on the Intan machine {'Z:\','C:\'} will change the Z:\ in the neurostim file to C:\ 
            o.addProperty('fake',false);       
            o.addProperty('useMDaq',true); 
            
            o.host = hst;
            o.port = prt;
            
            % Try to connect. Will throw an error if it fails.            
           tp = intanGet(o,'type');
            rm = intanGet(o,'runmode');
            o.writeToFeed(sprintf('Connected to %s:%d (Type: %s, RunMode: %s)',o.host,o.port,tp,rm));
            
            if ~strcmpi(rm,'Stop')
                 warning('RHX was still recording .. stopping it now');
                 intanSet(o,'runmode','Stop');
                 pause(1);
            end     

        end
        
              
        function beforeExperiment(o)
            if o.fake; return;end
            if o.useMDaq && ~hasPlugin(o.cic,'mdaq')
                error('IntanRhx set to use mdaq, but mdaq plugin is not loaded')
            end
            
            o.sampleRateHertz   = intanGet(o,'SampleRateHertz');
            o.version           = intanGet(o,'Version');
            o.headstagePresent  = intanGet(o,'HeadstagePresent');

            intanSet(o,'FileFormat',o.fileFormat);
            intanSet(o,'writeToDiskLatency',o.writeToDiskLatency);
            intanSet(o,'newSaveFilePeriodMinutes',num2str(o.newSaveFilePeriodMinutes));

            % Setup the file name. RHX will save to a subfolder named after
            % the neurostim file, with a timestamp (_date_time ) attached.
            % This is done to keep settings.xml files for each experiment
            % with the data. 
            intanSet(o,'createNewDirectory','True');
            if isempty(o.drive)
                % Save to the "same" location as Neurostim
                pth  = fileparts(o.cic.fullFile);
            else
                % Save to a different drive , but the same folder
                pth = strrep(fileparts(o.cic.fullFile),o.drive{1},o.drive{2});
            end
            intanSet(o,'Filename.BaseFilename',o.cic.file); 
            intanSet(o,'Filename.Path',pth); 
            
            % Start recording
            intanSet(o,'runMode','record')            
        end
        function afterExperiment(o)
            if o.fake; return;end           
            intanSet(o,'runMode','stop')                      
            o.writeToFeed('Intan RHX has stopped recording.');
        end
        
        function beforeTrial(o)
            if o.fake; return;end
            % Set trial bit
            if o.useMDaq
                digitalOut(o.cic.mdaq,"trial",true);
            end
            o.trialStart = intanGet(o,'CurrentTimeSeconds'); % Store time on Intan (poor resolution due to USB)            
        end
        function afterTrial(o)
            if o.fake; return;end
            % unset trial bit
            if o.useMDaq
                digitalOut(o.cic.mdaq,"trial",false);
            end
            o.trialStop = intanGet(o,'CurrentTimeSeconds'); % Store time on Intan (poor resolution due to USB)            
        end
        
        function intanSend(o,cmnds)
            % Send an arbitrary list of commands to the Intan device.
              if ~iscell(cmnds);cmnds={cmnds};end
              nrSetCmnds =numel(cmnds);
              for i=1:nrSetCmnds
                  write(o,cmnds{i});                  
              end
        end

        function intanEnable(o,port,channels,yesno)
            % Enable or disable amplifier channels on a specific port.
            % (Use intanSend to enable/disable Analog or Digital channels)
            if nargin <4
                yesno =true;
            end
            for ch=channels
                 write(o,sprintf('set %s-%0.3d.enabled %s',port, ch, string(yesno)));               
            end
        end

        function v = intanGet(o,prm)
            % Read a parameter on the device.
            write(o,['get '  prm]);  
            pause(o.secondsBeforeRead);
            v = intanRead(o);
        end
    end
    methods (Access=protected)
        function v = hCommand(o)
            % Setup and/or return a handle to the TCP client.
            % Using a global avoids having to press disconnect/connect on
            % the RHX for every experiment.
            global  hIntanCommand
            if isempty(hIntanCommand) 
                connect =true;
            else
                try % Check that the connection is working
                    ok = strcmpi(hIntanCommand.Address,o.host);
                    if ok
                        connect =false;
                    else
                        % This cannot really happen..
                        error('Connected to a different host???  %s ~= %s',hIntanCommand.Address,o.host)
                    end
                catch
                    % Connection broken. Reestablish
                    connect = true;
                    
                end                
            end
            if connect
                clear hIntanCommand;
                global hIntanCommand
                o.writeToFeed(sprintf('Trying to connect to the Intan RHX (%s : %s)',o.host,o.port));
                hIntanCommand = tcpclient(o.host,o.port,"ConnectTimeout",30,"EnableTransferDelay",false);
                o.writeToFeed("Connected.");
            end
            v= hIntanCommand;
        end


        function intanSet(o,prm,value)
            % Set a parameter
            write(o,['set ' prm ' ' value]);
          
        end
        function intanExecute(o,cmd)
            % Execute a parameter
            write(o,['execute  '   cmd])
        end
        
        function write(o,cmd)      
            % Write the byte-coded command on the tcp link.
            % Make sure that commands are separated by enough time
            % (> .secondsBetweenWrites)
            persistent lastWrite            
            if ~isempty(lastWrite) 
                secondsSinceLastWrite = (GetSecs-lastWrite);
                if secondsSinceLastWrite < o.secondsBetweenWrites
                    pause(o.secondsBetweenWrites-secondsSinceLastWrite);
                end
            end               
            write(o.hCommand,uint8(cmd))
            lastWrite = GetSecs;            
        end

        function [v,prm] = intanRead(o)
            % Read a response from the device.
            % There is no ACK so it is difficult to know when to stop
            % reading. This code assumes that as soon as any butes are
            % available, all bytes are available. This, together with the
            % wait period (secondsBeforeRead) after a 'get' probably works.
            tic;
            h= hCommand(o);
            while h.BytesAvailable == 0
                elapsedTime = toc;
                if elapsedTime > o.timeout
                    % Clear the tcp connection to restablish
                    clear global hIntanCommand
                    error('Reading command timed out. Restart RHX?');
                end
                pause(0.01)
            end
           v = read(h);
           match = regexp(char(v),'Return: (?<parm>\w+)\s+(?<value>\w+)','names');
           if isempty(match)
               % Return the full byte string for further processing
               prm ='';
           else
               v = match.value;
               prm = match.parm;
           end
        end
    end
    
        
    %%  GUI functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            o.fake = strcmpi(parms.onOffFakeKnob,'fake');            
        end


                       
    end
        
end