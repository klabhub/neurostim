classdef trellis < neurostim.plugin
    properties (Constant)
        SAMPLINGFREQ = 30000; %30KHz
        availableStreams = upper({'raw','stim','hi-res','lfp','spk','spkfilt','1ksps','30ksps'});
        availablePorts ='ABCD';
    end
    
    properties (SetAccess=protected,GetAccess=public)
        operator@double;    % Operator (NIP/Trellis) that we're talking to currently
    end
    
    
    properties (Dependent)
        time@double;        % Time in ms since NIP started
        operators@double;   % List of Trellis IDs on the network
        status@struct;      % Current Trellis status.
        
        % Get channel numbers for all or a subset of "modalities"
        stimChannels@double;       % Stimulation channels    [1-512]
        microChannels@double;      % Micro electrode channels [1-512]
        surfChannels@double;       % Surface channels [1-512]
        analogChannels@double;     % Analog channels [SMA: 10241:10244. Micro-D: 10245:10268 -Audio: 10269, 10270]
        allChannels@double;        % All channels.
        
    end
    
    methods
        function v = get.time(~)
            v = 1000*xippmex('time')/neurostim.plugins.trellis.SAMPLINGFREQ;
        end
        
        function v = get.operators(~)
            v = xippmex('opers');
        end
        
        function v= get.status(o)
            v = xippmex('trial',o.operator);
        end
        
        function v= get.stimChannels(o)
            v = xippmex('elec','stim');
        end
        
        
        function v= get.microChannels(o)
            v = xippmex('elec','micro');
        end
        
        function v= get.surfChannels(o)
            v = xippmex('elec','surf');
        end
        
        function v= get.analogChannels(o)
            v = xippmex('elec','analog');
        end
        
        function v= get.allChannels(o)
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
    % Example (future) streamSettings={{'port','A','channel',1:64,'stream','raw'};
    %              {'port','A','channel',1:64,'stream','lfp'};
    %              {'port','SMA','channel',3,'stream','1ksps'}};

                                                
        end
        
        function digout(~,channel,value)
            % Set the digital output to the specified (TTL; 3.3V or 0V) value.
            if channel<5 && islogical(value)
                % Single SMA out
                xppmex('digout',channel,value);
            elseif channel ==5 && isa(value,'uint16')
                % MicroD out (16 unsigned bits)
                xppmex('digout',channel,value);
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
            
            
            %% Connect to Trellis/NIP
            tmp = o.operators;
            if isempty(tmp)
                error('Could not find Trellis on the network...')
            end
            if numel(tmp)>1
                error('More than on Trellis on the network??');
            end
            o.operator = tmp;
            
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
                xippmex('trial',o.operator,'stopped');
            end
            
            tic;
            while(~strcmpi(o.status,'stopped'))
                pause (1);
                if toc > 5 % 5 s timeout to stop
                    o.cic.error('Failed to stop Trellis?');
                end
            end
            
            % Now start it with the file name specified by CIC. The
            % recording will run until stopped (0) and autoincrement for file names
            % is off.
            stat = xippmex('trial',o.operator,'recording',o.cic.file,0,false);
            if ~strcmpi(stat.status,'recording')
                o.cic.error('Failed to start recording on Trellis');
            end
            
        end
        function afterExperiment(o)
            % Close the UDP link
            xippmex('close');
        end
        
        function beforeTrial(o)
            % Set trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,true);
            end
            o.trialStart = xippmex('time')/(o.SAMPLINGFREQ/1000); % Time in ms since NIP on
        end
        function afterTrial(o)
            % unset trial bit
            if ~isempty(o.trialBit)
                digout(o,o.trialBit,false);
            end
            o.trialStop = xippmex('time')/(o.SAMPLINGFREQ/1000); % Time in ms since NIP on
        end
    end
end