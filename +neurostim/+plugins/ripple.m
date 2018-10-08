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
    %               digital input. (Base-1)
    %   drive    - Map a drive on the neurostim ccomputer to a different
    %               drive on the computer running Trellis (in case they are not saving
    %               to the same place on a network)
    %   channels   - A vector of channel numbers (e.g. 129:192 for the
    %                   first 64 channels on port B)
    %  electrodes  - For each channel, an electrode that it connects to.
    %                   e.g. (1:64). 
    %               Channels/electrodes does not change the
    %               recording/streaming but it allows analysis software
    %               (e.g. sib) to save the data in a physically meaningful
    %               sense (i.e. even if you record electrode 2 with Port C
    %               channel 4, you'd want it to show up as electrode 2 in
    %               sib).
    % %Example:
    %  t = plugins.ripple(c);  %Create the plugin and connect it to CIC
    %  t.trialBit = 3; % Signal start/stop on SMA digital output 3 (whcih is looped to input 3)
    %  t.drive = {'z:\','c:\'};  % Whatever Neurostim wants to save to z:\
    %                               we put on c:\ on the Trellis computer
    %  t.channels = 129:160 ; % For this animal we connect a single 32
    %  channel front end to Port B - those channels are 129:160.
    % t.electrodes = 1:32; % When analyzing these data we refer to the
    % first channel as electrode 1 and the last channel (160) as electrode 32.
    %
    % You can also deliver reward through Trellis - see plugins.liquid
    % 
    % BK - September 2018
    
    properties (Constant)
        SAMPLINGFREQ = 30000; %30KHz fixed
        NRDIGOUT = 4; % The individual digout channels (sma)
        availableStreams = upper({'raw','stim','hi-res','lfp','spk','spkfilt','1ksps','30ksps'});
        availablePorts ='ABCD';       
    end
    
    properties (SetAccess=protected,GetAccess=public)          
        tmr@timer; % Array of timer objects for digouts 1-5 (to handle duration of pulse)
        currentDigout = false(1,neurostim.plugins.ripple.NRDIGOUT); % Track state of digout
    end
    
    properties (Dependent)
        nipTime@double;             % Time in ms since NIP started
        status@struct;              % Current Trellis status.
        
        % Get channel numbers for all or a subset of "modalities"
        stimChannels@double;       % Stimulation channels    [1-512]
        microChannels@double;      % Electrode channels connected to Micro front end [1-512]
        nanoChannels@double;       % Electrode channels connected to Nano front end [1 -512]
        surfChannels@double;       % Surface channels [1-512]
        analogChannels@double;     % Analog channels [SMA: 10241:10244. Micro-D: 10245:10268 -Audio: 10269, 10270]
        allChannels@double;        % All channels.
               
    end
    
    methods
        function v = get.nipTime(~)
            v = 1000*xippmex('time')/neurostim.plugins.ripple.SAMPLINGFREQ;
        end
        
        
        function v= get.status(~)
            v = xippmex('trial');
            v= v.status;
        end
        
        function v= get.stimChannels(~)
            v = xippmex('elec','stim');
        end
        
        function v= get.nanoChannels(~)
            v = xippmex('elec','nano');
        end
        
        
        function v= get.microChannels(~)
            v = xippmex('elec','micro');
        end
        
        function v= get.surfChannels(~)
            v = xippmex('elec','surf');
        end
        
        function v= get.analogChannels(~)
            v = xippmex('elec','analog');
        end
        
        function v= get.allChannels(~)
            v = xippmex('elec','all');
        end
        
    end
    methods
        function o = ripple(c)
            % Construct a ripple plugin
            o = o@neurostim.plugin(c,'ripple');
            o.addProperty('trialBit',[]);
            o.addProperty('trialStart',[]);
            o.addProperty('trialStop',[]);
            o.addProperty('channel',[]);    % Specify which channel connects to which electrode.
            o.addProperty('electrode',[]);
            o.addProperty('streamSettings',{});
            o.addProperty('startSave',NaN);
            o.addProperty('stopSave',NaN);
            o.addProperty('drive',{}); % Optional - change output drive on the Ripple machine {'Z:\','C:\'} will change the Z:\ in the neurostim file to C:\ for Ripple            
    
            
            % Example (future) streamSettings={{'port','A','channel',1:64,'stream','raw'};
    %              {'port','A','channel',1:64,'stream','lfp'};
    %              {'port','SMA','channel',3,'stream','1ksps'}};

            pth = which('xippmex');
            if isempty(pth)
                error('The ripple plugin relies on xippmex, which could not be found. Please obtain it from your Trellis installation folder, and add it to the Matlab path');
            end
            
            % Create a timer object for each digout channel (to 
            for ch = 1:o.NRDIGOUT
                o.tmr(ch) = timer('tag',['ripple_digout' num2str(ch)]);
            end                                                                    
        end
        
        function digout(o,channel,value,duration)
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
                xippmex('digout',1:o.NRDIGOUT,double(newDigout));
                o.currentDigout = newDigout;
                if isfinite(duration)
                    o.tmr(channel).StartDelay = duration/1000;
                    o.tmr(channel).TimerFcn = @(~,~) digout(o,channel,~value);                                           
                    start(o.tmr(channel));
                end            
            elseif channel == 5 && isa(value,'uint16')
                % MicroD out (16 unsigned bits)
                xippmex('digout',channel,value);
            else
                % Must be an error.
                error(['Channel ' num2str(channel) ' cannot be set to ' num2str(value)]);
            end
            
        end
        
        function stream(o,varargin)
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
                    stream  = xippmex('signal',elec(1));
                else
                    stream = {p.Results.stream};
                end                
                %Activate/inactivate the streams. 
                for i=1:numel(stream)
                    xippmex('signal',elec,lower(stream{i}),double(p.Results.on));
                end
            end
        end
        
        function beforeExperiment(o)
            
            %% Iniitialize
            try
                stat = xippmex;
            catch
                stat = -1;
            end
            if stat ~= 1; error('Xippmex Did Not Initialize');  end
            
            
        
            
            %% Define recording & stim electrodes
            % Disabled for now as this only does the streaming not saving.
            % First turn everything off
%             for strm = 1:numel(o.availableStreams)
%                 for p=1:numel(o.availablePorts)                    
%                     stream(o,'port',o.availablePorts(p),'channel',1:128,'stream','','on',false);
%                 end
%             end
%             stream(o,'port','ANALOG','channel',1:32,'stream','','on',false);
%             % Then enable those that have been selected. 
%             if ~isempty(o.streamSettings)
%                 for i=1:numel(o.streamSettings)
%                     record(o,o.streamSettings{i}{:});
%                 end
%             end
            
            
            %% First make sure Trellis has stopped 
            
            if ~strcmpi(o.status,'stopped')
                warning('Trellis was still recording when this experiment started');
                xippmex('trial','stopped');
            end
            
            tic;
            while(~strcmpi(o.status,'stopped'))
                pause (1);
                if toc > 5 % 5 s timeout to stop
                    o.cic.error('Failed to stop Trellis?');
                end
            end
            
            xippmex('digout',1:o.NRDIGOUT,zeros(1,o.NRDIGOUT)); % ReSet digout
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
                xippmex('trial','recording',filename,0,0);
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
            o.startStave = o.nipTime;
            o.writeToFeed(['Trellis is now recording to ' o.cic.fullFile]);                        
        end
        function afterExperiment(o)
            % Wait for timers to finish, then close file and TCP link
            if any(strcmpi('On',{o.tmr.Running}))
                o.writeToFeed('Waiting for Trellis timers to finish...')
                wait(o.tmr); % Make sure they're all done - as they will fail after the xippmex connection is closed.
                o.writeToFeed('All Done.');
            end
                
            xippmex('trial','stopped');
            while(~strcmpi(o.status,'stopped'))
                pause (1); 
                o.cic.error('STOPEXPERIMENT','Stop recording on Trellis failed...?');
            end
            o.stopStave = o.nipTime;            
            xippmex('close'); % Close the link
            o.writeToFeed('Trellis has stopped recording.');
        end
        
        function beforeTrial(o)
            % Set trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,true);
            end
            o.trialStart = o.nipTime; % Store nip time
        end
        function afterTrial(o)
            % unset trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,false);
            end
            o.trialStop = o.nipTime; % Store niptime
        end
    end        
end