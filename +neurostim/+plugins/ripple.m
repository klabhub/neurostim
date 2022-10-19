classdef ripple < neurostim.plugin
    % Plugin to interact with Ripple hardwar: the NIP, and Trellis.
    % Mostly this starts/stops saving to file and it marks the beginning
    % and end of trials using a TTL.
    %
    % Note that this plugin does not specify what should be streamed and/or
    % saved by Trellis. This should be done in the Trellis interface for
    % now.
    %
    % Properties
    %   trialBit - which SMA output bit to set to signal the start/stop of a trial
    %               To log this bit, you need to loop it (with a wire) to the
    %               digital input, or turn on UDP loopback in Trellis. (Base-1)
    %   drive    - Map a drive on the neurostim ccomputer to a different
    %               drive on the computer running Trellis (in case they are not saving
    %               to the same place on a network)
    %  onsetBit  - Which SMA output bit to set to signal stimulus onset using the logOnset function.
    %
    % %Example:
    %  t = plugins.ripple(c);  %Create the plugin and connect it to CIC
    %  t.trialBit = 3; % Signal start/stop on SMA digital output 3 (whcih is looped to input 3)
    %  t.drive = {'z:\','c:\'};  % Whatever Neurostim wants to save to z:\
    %                               we put on c:\ on the Trellis computer
    % Indicate that the first connector port B (channels 192+) is connected to the first FMA
    % in the brain and teh second connector to the second array in the
    % brain.
    %  t.connect('B',1,'arrayNumber',1,'flipped',false,'arrayType','fma')
    % t.connect('B',2,'arrayNumber',2,'flipped',false,'arrayType','fma')
    %  And if g is a handle to the critical stimulus in an experiment you
    %  can use
    %  g.onsetFunction= @neurostim.plugins.ripple.logOnset;
    % To set the t.onsetBit to high for 10 ms each time the g stimulus turns
    % on.
    %
    % You can also deliver reward through Trellis - see plugins.liquid
    %
    % BK - September 2018
    
    properties (Constant)
        SAMPLINGFREQ = 30000; %30KHz fixed
        NRDIGOUT = 4; % The individual digout channels (sma)
        availableStreams = upper({'raw','stim','hi-res','lfp','spk','spkfilt','1ksps','30ksps'});
        availablePorts ='ABCD';
        % Array types are used by the ripple.connect function to store what
        % kind of harward in/on the head a front end is connected to. This
        % is mainly used in the analysis.
        % XXX-1 means connected to the first array of type xxx (where first
        % identifies a specific piece of hardware in/on the head). For
        % arrayTypes without the -x suffix, the array number is assumed to
        % be 1.
        arrayTypes = ["OFF","FMA-1","FMA-2","EEG","3D-1","3D-2","3D-3","3D-4"];        
    end
    
    
    properties (SetAccess=protected,GetAccess=public)
        tmr=timer; % Array of timer objects for digouts 1-5 (to handle duration of pulse)
        currentDigout = false(1,neurostim.plugins.ripple.NRDIGOUT); % Track state of digout
        connectors = containers.Map;
    end
    
    properties (Dependent)
        nipTime;             % Time in ms since NIP started
        status;              % Current Trellis status.
        
        % Get channel numbers for all or a subset of "modalities"
        stimChannels;       % Stimulation channels    [1-512]
        microChannels;      % Electrode channels connected to Micro front end [1-512]
        nanoChannels;       % Electrode channels connected to Nano front end [1 -512]
        surfChannels;       % Surface channels [1-512]
        analogChannels;     % Analog channels [SMA: 10241:10244. Micro-D: 10245:10268 -Audio: 10269, 10270]
        allChannels;        % All channels.
        
    end
        
    
    methods
        function v = get.nipTime(o)
            v = 1000*tryXippmex(o,'time')/neurostim.plugins.ripple.SAMPLINGFREQ;
        end
        
        
        function v= get.status(o)
            v = tryXippmex(o,'trial');
            if isstruct(v)
                v = v.status;
            else
                % Probably called before any trial
                v = 'stopped';
            end            
        end
        
        function v= get.stimChannels(o)
            v = tryXippmex(o,'elec','stim');
        end
        
        function v= get.nanoChannels(o)
            v = tryXippmex(o,'elec','nano');
        end
        
        
        function v= get.microChannels(o)
            v = tryXippmex(o,'elec','micro');
        end
        
        function v= get.surfChannels(o)
            v = tryXippmex(o,'elec','surf');
        end
        
        function v= get.analogChannels(o)
            v = tryXippmex(o,'elec','analog');
        end
        
        function v= get.allChannels(o)
            v = tryXippmex(o,'elec','all');
        end
        
    end
    methods
        function logConnection(o,port,connector,varargin)
            % Currently only used for bookkeeping, not to actually start
            % streaming/saving.(That would require the stream function
            % below).
            p =inputParser;
            p.addRequired('port',@ischar);
            p.addRequired('connector',@isnumeric);
            p.addParameter('flip',false,@islogical);% Was the connector flipped?
            p.addParameter('arrayNr',[],@isnumeric); % Which array did this connector attach to (array is a number in the brain).
            p.addParameter('channels',1:32,@isnumeric); % Which of the 32 cahnnels recorded data.
            p.addParameter('electrodes',1:32,@isnumeric); % What do we call these wires in/on the head in the analysis?
            p.addParameter('arrayType','fma',@(x) ischar(x) || isstring(x)); % Used in data analysis
            p.addParameter('streams',{},@iscell); % Streams to enable
            p.parse(port,connector,varargin{:});
            name = [port num2str(connector)];
            results = p.Results;
            o.connectors(name)=results;
            
            
        end
        function o = ripple(c)
            % Construct a ripple plugin
            o = o@neurostim.plugin(c,'ripple');
            o.addProperty('trialBit',[]);
            o.addProperty('onsetBit',[]);
            o.addProperty('trialStart',[]);
            o.addProperty('trialStop',[]);
            o.addProperty('startSave',NaN);
            o.addProperty('stopSave',NaN);
            o.addProperty('drive',{}); % Optional - change output drive on the Ripple machine {'Z:\','C:\'} will change the Z:\ in the neurostim file to C:\ for Ripple
            o.addProperty('fake',false);
            
            
            
            pth = which('xippmex');
            if isempty(pth)
                error('The ripple plugin relies on xippmex, which could not be found. Please obtain it from your Trellis installation folder, and add it to the Matlab path');
            end
            
            % Create a timer object for each digout channel
            for ch = 1:o.NRDIGOUT
                o.tmr(ch) = timer('tag',['ripple_digout' num2str(ch)]);
            end
            % This has to be done before any other commands are sent.
            try
                xippmex;  %Initialize if possible
            catch
            end
            % But if we later want to continue in fake mode, failure should
            % not result in an error. So we let it try once only and
            % continue regardless.
        end
        
        function digout(o,channel,value,duration)
            if o.fake; return;end
            % Set the digital output to the specified (TTL; 3.3V or 0V) value.
            % Either specify a boolean for a single SMA port or an uint16
            % for the MicroD port.
            % The optional duration input only applies to the single SMA
            % ports, which will be set to the specified value for that
            % duration and then toggled back to ~value.
            if nargin <4
                duration =inf;
            end
            if channel<=o.NRDIGOUT && islogical(value)
                % Single SMA out
                newDigout = o.currentDigout;
                newDigout(channel) = value;
                tryXippmex(o,'digout',1:o.NRDIGOUT,double(newDigout));
                o.currentDigout = newDigout;
                if isfinite(duration)
                    o.tmr(channel).StartDelay = duration/1000;
                    o.tmr(channel).TimerFcn = @(~,~) digout(o,channel,~value);
                    start(o.tmr(channel));
                end
            elseif channel == 5 && isa(value,'uint16')
                % MicroD out (16 unsigned bits)
                tryXippmex(o,'digout',channel,double(value));
            else
                % Must be an error.
                error(['Channel ' num2str(channel) ' cannot be set to ' num2str(value)]);
            end
            
        end
        
        function stream(o,varargin)
            if o.fake; return;end
            % Function to activate/inactivate certain streams.
            % Ther is no way to chose data saving for these streams, and
            % there seem to be some bugs (e.g. turning 1ksps for SMA on
            % also affects B1??). Limited usefulness so skip for now (And
            % just define stream/save in the Trellis interface).
            p = inputParser;
            p.addParameter('port','',@(x) (ischar(x) && ismember(upper(x),{'ANALOG','SMA','MICROD','LINELEVEL','A','B','C','D'})));
            p.addParameter('channel',[],@(x) (isnumeric(x) && all(x>=1 & x <=128)));
            p.addParameter('stream','',@(x) (ischar(x) && (isempty(x) || ismember(upper(x),o.availableStreams))));
            p.addParameter('on',true,@islogical);
            p.parse(varargin{:});
            switch upper(p.Results.port)
                case {'SMA','ANALOG'}
                    portOffset = 10240;
                case 'MICROD'
                    portOffset = 10244;
                case 'LINELEVEL'
                    portOffset  = 10268;
                case {'A','B','C','D'}
                    portOffset = 128*(find(upper(p.Results.port)=='ABCD')-1);
            end
            % Select the electrodes that have a front end connected.
            elec= intersect(p.Results.channel+portOffset,o.allChannels);
            if any(elec)
                if isempty(p.Results.stream)
                    % ''  means all streams defined for the first electrode
                    % in the set.
                    stream  = tryXippmex(o,'signal',elec(1));
                else
                    stream = {p.Results.stream};
                end
                %Activate/inactivate the streams.
                for i=1:numel(stream)
                    tryXippmex(o,'signal',elec,lower(stream{i}),double(p.Results.on));
                end
            end
        end
        
        function beforeExperiment(o)
            if o.fake; return;end
            
           
            % Now the connection has to be active.
            stat = tryXippmex(o);
            if stat~=1; error('Failed to connect to Trellis');end
            
            
            %% First make sure Trellis has stopped
            
            if ~strcmpi(o.status,'stopped')
                warning('Trellis was still recording when this experiment started');
                tryXippmex(o,'trial','stopped');
            end
            
            tic;
            while(~strcmpi(o.status,'stopped'))
                pause (1);
                if toc > 5 % 5 s timeout to stop
                    o.cic.error('STOPEXPERIMENT','Failed to stop Trellis');
                end
            end
            
            tryXippmex(o,'digout',1:o.NRDIGOUT,zeros(1,o.NRDIGOUT)); % ReSet digout
            o.currentDigout = false(1,o.NRDIGOUT); % Local storage.
            
            % Now start it with the file name specified by CIC. The
            % recording will run until stopped (0) and autoincrement for file names
            % is off.
            o.writeToFeed('Starting Trellis recording...')
            if isempty(o.drive)
                % Save to the "same" location as Neurostim
                filename = o.cic.fullFile;
            else
                % Save to a different drive , but the same directory
                filename = strrep(o.cic.fullFile,o.drive{1},o.drive{2});
            end
            
            try
                tryXippmex(o,'trial','recording',filename,0,0);
            catch
                o.cic.error('STOPEXPERIMENT',['Failed to start recording on Trellis. Probably the path to the file does not exist on the Trellis machine: ' o.cic.fullPath]);
                return; % No stat if error
            end
            tic;
            while(~strcmpi(o.status,'recording'))
                pause (1);
                if toc > 5 % 5 s timeout to stop
                    o.cic.error('STOPEXPERIMENT','Failed to start recording on Trellis. Is ''remote control''  enabled in the Trellis GUI?');
                end
            end
            o.startSave = o.nipTime;
            o.writeToFeed(['Trellis is now recording to ' o.cic.fullFile]);
        end
        function afterExperiment(o)
            if o.fake; return;end
            % Wait for timers to finish, then close file and TCP link
            if any(strcmpi('On',{o.tmr.Running}))
                o.writeToFeed('Waiting for Trellis timers to finish...')
                wait(o.tmr); % Make sure they're all done - as they will fail after the xippmex connection is closed.
                o.writeToFeed('All Done.');
            end
            
            tryXippmex(o,'trial','stopped');
            while(~strcmpi(o.status,'stopped'))
                pause (1);
                o.cic.error('STOPEXPERIMENT','Stop recording on Trellis failed...?');
            end
            o.stopSave = o.nipTime;
            tryXippmex(o,'close'); % Close the link
            o.writeToFeed('Trellis has stopped recording.');
        end
        
        function beforeTrial(o)
            if o.fake; return;end
            % Set trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,true);
            end
            o.trialStart = o.nipTime; % Store nip time
        end
        function afterTrial(o)
            if o.fake; return;end
            % unset trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,false);
            end
            o.trialStop = o.nipTime; % Store niptime
        end
        
        function varargout = tryXippmex(o,varargin)
            % Wrapper around xippmex to retry calls to Trellis
            if o.cic.loadedFromFile
                % Deal with ripple objects loaded from file.
                switch (varargin{1})
                    case 'status'
                        varargout{1} = 'stopped';
                    otherwise 
                        varargout{1} = NaN;
                end
                return;
            end
            nrTries=0;
            MAXNRTRIES = 10;
            v  = cell(1,nargout);
            nargs = numel(varargin);
            while nrTries <MAXNRTRIES
                try
                    if nargs>0
                        command = varargin{1};
                        [v{:}] = xippmex(varargin{:});
                    else
                        command = '()';
                        [v{:}] = xippmex;
                    end
                    break;
                catch me
                    o.writeToFeed(['Trellis is not responding to  ' command ' (' me.message ')'])
                    nrTries= nrTries+1;
                    pause(0.5);
                end
            end
            if nrTries == MAXNRTRIES
                fprintf(2,'This was sent to xippmex (and failed):')
                varargin{:} %#ok<NOPRT>
                rethrow(me)
            end
            varargout = v;
        end
    end
    
    methods (Static)
        function logOnset(s,startTime)
            % This function sets the digout on the NIP as a way to encode
            % that a stimulus just appeared on the screen (i.e. first frame flip)
            % I use a static function to make the notation easier for the
            % user, but by using CIC I nevertheless make use of the ripple
            % object that is currently loaded.
            % INPUT
            % s =  stimulus
            % startTime = flipTime in clocktime (i.e. not relative to the
            % trial)
            r = s.cic.ripple;
            if ~isempty(r.onsetBit)
                DURATION = 10; % 10 ms is enough
                r.digout(r.onsetBit,true,DURATION);
            end
        end
        
        
    end
    
    %%  GUI functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = ripple  plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            o.fake = strcmpi(parms.onOffFakeKnob,'fake');
            neurostim.plugins.ripple.checkStreamSettings(parms.checkRipple,[],true,o);
        end
        
        
        
    end
    
    
    methods (Static)
        function checkStreamSettings(hButton,~,live,o)
            hasObject  =nargin>3;
            if nargin <3
                live = true;
            end
            
            oldPointer = hButton.Parent.Parent.Parent.Pointer;
            hButton.Parent.Parent.Parent.Pointer='watch';
            drawnow
            
            if live
                % Contact Ripple to check
                channels = xippmex('elec','all');
                feChannels= repmat((1:32)',[1 4*4])+(0:15)*32;
                hasFe = reshape(any(ismember(feChannels,channels)),[4 4]);
            else
                hasFe = true(4,4);
            end
            
            onStyle = uistyle('BackgroundColor','green');
            notConnectedStyle = uistyle('BackgroundColor','#EDB120');
            offStyle = uistyle('BackgroundColor','red');
            for prtNr=1:numel(neurostim.plugins.ripple.availablePorts)
                port = neurostim.plugins.ripple.availablePorts(prtNr);
                hTable = findobj(hButton.Parent.Children,'Tag',['Port' port]);
                T = hTable.Data;
                setpref('ripple',['port_' num2str(prtNr)],T);           
                removeStyle(hTable);
                for feNr = 1:4
                    chanThisFe = (prtNr-1)*128+(feNr-1)*32+ (1:32);
                    firstChanThisFe = chanThisFe(1);
                    if hasFe(feNr,prtNr)
                        if live
                            streamsThisFe = xippmex('signal',firstChanThisFe);
                        end
                        isOn = T.Type(feNr) ~=categorical("OFF");
                        elms = strsplit(string(T.Type(feNr)),'-');
                        if numel(elms)>1
                            thisArrayNr = str2double(elms{2});
                        else
                            thisArrayNr = NaN;
                        end
                        thisType = string(elms{1});
                        
                        if isOn
                            addStyle(hTable,onStyle,'row',feNr);
                            if live
                                switch (upper(thisType))
                                    case "FMA"
                                        % FMA recordings- turn on raw and lfp
                                        streamsOn = {'raw','lfp'};
                                    case "EEG"
                                        % EEG, turn on hi-res only.
                                        streamsOn = {'hi-res'};
                                end
                            end
                        else
                            addStyle(hTable,offStyle,'row',feNr);
                            streamsOn = {};
                        end
                        if live
                            streamsOff = setxor(streamsOn,streamsThisFe);
                            for i=1:numel(streamsOff)
                                if ismember(streamsOff{i},{'spk','stim'})
                                    % Should depend on Table.Chan... xippmex('signal',chanThisFe,streamsOff{i},0);
                                else
                                    xippmex('signal',firstChanThisFe,streamsOff{i},0);
                                    %NOT FUNCTIONAL   xippmex('signal-save',firstChanThisFe,streamsOff{i},0);
                                end
                            end
                            for i=1:numel(streamsOn)
                                if ismember(streamsOn{i},{'spk','stim'})
                                    % Should depend on Table.Chan... xippmex('signal',chanThisFe,streamsOff{i},0);
                                else
                                    xippmex('signal',firstChanThisFe,streamsOn{i},1);
                                  %NOT FUNCTIONAL  xippmex('signal-save',firstChanThisFe,streamsOn{i},1);
                                end
                            end
                            if hasObject
                                try
                                    channelListAsString=strjoin(["[",T.Chan(feNr), "]"]);
                                    chan = eval(channelListAsString);
                                    elecListAsString=strjoin(["[",T.Elec(feNr), "]"]);
                                    elec= eval(elecListAsString);
                                    assert(numel(chan)==numel(elec));
                                catch me
                                    % Restore
                                    hButton.Parent.Parent.Parent.Pointer=oldPointer;
                                    error('Incorrect channel/electrode specs for %s%d',port,feNr);
                                end
                                logConnection(o,port,feNr,...
                                    'channels',chan,'electrodes',elec,'arrayType',thisType,...
                                    'streams',streamsOn,'arrayNr',thisArrayNr);
                            end
                        end
                    else
                        streamsThisFe = {};
                        addStyle(hTable,notConnectedStyle,'row',feNr);
                        if live
                            % Nothing to do here - not connected.
                            if hasObject
                                logConnection(o,port,feNr,...
                                    'channels',[],'electrodes',[],'arrayType',"OFF",...
                                    'streams',{},'arrayNr',[]);
                            end
                        end
                    end
                end
            end
            
            % Restore
            hButton.Parent.Parent.Parent.Pointer=oldPointer;
            
        end
        
        
        function guiLayout(pnl)
            % Add plugin specific elements
            pnl.Position = [pnl.Position([1 2 3] ) 150];
            % One table per port to setup the Connector
            arrayType =  categorical("OFF",neurostim.plugins.ripple.arrayTypes);
            defaultT = table(repmat(arrayType,[4 1]),repmat("1:32",[4 1]),repmat("1:32",[4 1]),'VariableNames',{'Type','Chan','Elec'});        
            for prt=1:numel(neurostim.plugins.ripple.availablePorts)                
                T = getpref('ripple',['port_' num2str(prt)],defaultT);
                hTable = uitable(pnl,"Data",T,"Tag",['Port' neurostim.plugins.ripple.availablePorts(prt)]);
                hTable.ColumnSortable = false;
                hTable.ColumnEditable = [true true true];
                hTable.ColumnWidth =repmat({40},[1 3]);
                hTable.Position = [110+126*(prt-1) 5 132 119];
                hTable.Tooltip  = ['Port-' neurostim.plugins.ripple.availablePorts(prt)];
            end
            
            uibutton(pnl,"ButtonPushedFcn",@neurostim.plugins.ripple.checkStreamSettings, ...
                "Text","Check",...
                "Tooltip","Press to check if the current settings are valid.",...
                "Position",[10 75 70 20],"Tag","checkRipple");
            
            
        end
        
    end
end