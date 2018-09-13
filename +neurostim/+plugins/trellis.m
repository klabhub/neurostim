classdef trellis < neurostim.plugin
    properties (Constant)
        SAMPLINGFREQ = 30000; %30KHz
        NRDIGOUT = 4; % The individual digout channels (sma)
        availableStreams = upper({'raw','stim','hi-res','lfp','spk','spkfilt','1ksps','30ksps'});
        availablePorts ='ABCD';
       
    end
    
    properties (SetAccess=protected,GetAccess=public) 
        experimentStartTime=0;       
        tmr@timer; % Array of timer objects for digouts 1-5 (to handle duration of pulse)
        currentDigout = false(1,neurostim.plugins.trellis.NRDIGOUT); % Track state of digout
    end
    
    properties (Dependent)
        time@double;        % Time in ms since NIP started
        status@struct;      % Current Trellis status.
        
        % Get channel numbers for all or a subset of "modalities"
        stimChannels@double;       % Stimulation channels    [1-512]
        microChannels@double;      % Electrode channels connected to Micro front end [1-512]
        nanoChannels@double;       % Electrode channels connected to Nano front end [1 -512]
        surfChannels@double;       % Surface channels [1-512]
        analogChannels@double;     % Analog channels [SMA: 10241:10244. Micro-D: 10245:10268 -Audio: 10269, 10270]
        allChannels@double;        % All channels.
        
    end
    
    methods
        function v = get.time(~)
            v = 1000*xippmex('time')/neurostim.plugins.trellis.SAMPLINGFREQ;
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
        function o = trellis(c)
            % Construct a trellis plugin
            o = o@neurostim.plugin(c,'trellis');
            o.addProperty('trialBit',[]);
            o.addProperty('trialStart',[]);
            o.addProperty('trialStop',[]);
            o.addProperty('streamSettings',{});
            o.addProperty('reconTime',NaN);
            o.addProperty('drive',{}); % Optional - change output drive on the Trellis machine {'Z:\','C:\'} will change the Z:\ in the neurostim file to C:\ for Trellis
            
    % Example (future) streamSettings={{'port','A','channel',1:64,'stream','raw'};
    %              {'port','A','channel',1:64,'stream','lfp'};
    %              {'port','SMA','channel',3,'stream','1ksps'}};

            pth = which('xippmex');
            if isempty(pth)
                error('The trellis plugin relies on xippmex, which could not be found. Please obtain it from your Trellis installation folder, and add it to the Matlab path');
            end
            
            % Create a timer object for each digout channel
            for ch = 1:o.NRDIGOUT
                o.tmr(ch) = timer('tag',['trellis_digout' num2str(ch)]);
            end                                                                    
        end
        
        function digout(o,channel,value,duration)
            % Set the digital output to the specified (TTL; 3.3V or 0V) value.
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
            
            
            %% First make sure Trellis has stopped and then
            
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
            o.currentDigout = false(1,o.NRDIGOUT);
            
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
            o.writeToFeed(['Trellis is now recording to ' o.cic.fullFile])
            o.reconTime = xippmex('time')/(o.SAMPLINGFREQ/1000);
            
        end
        function afterExperiment(o)
            
            if any(strcmpi('On',{o.tmr.Running}))
                o.writeToFeed('Waiting for Trellis timers to finish...')
                wait(o.tmr); % Make sure they're all done - as they will fail after the xippmex connection is closed.
                o.writeToFeed('All Done.');
            end
            % Close the UDP link
            stat= xippmex('trial','stopped');
            if ~strcmpi(stat.status,'stopped')
                o.cic.error('STOPEXPERIMENT','Stop recording on Trellis failed...?');
            end
            xippmex('close');
            o.writeToFeed('Trellis has stopped recording.')
        end
        
        function beforeTrial(o)
            % Set trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,true);
            end
            o.trialStart = xippmex('time')/(o.SAMPLINGFREQ/1000); % Time in ms on the ripple clock
        end
        function afterTrial(o)
            % unset trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,false);
            end
            o.trialStop = xippmex('time')/(o.SAMPLINGFREQ/1000); % Time in ms on the ripple clock
        end
    end
end