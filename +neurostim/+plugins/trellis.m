classdef trellis < plugin
    properties (Constant)
        SAMPLINGFREQ = 30000; %30KHz
        availableStreams = {'raw','stim','hi-res','lfp','spk','spkfilt'}
    end
    
    properties (SetAccess=public)
        trialBit@double = []; % DigOut used to signal trial start to the NIP
        
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
            v = 1000*xippmex('time')/trellis.SAMPLINGFREQ;
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
            o = o@plugin(c,'trellis');
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
        
        function record(o,chan,strm)
            % Specify what (strm) to record from which channels
            % chan is a vector with channels
            % stream a cell array of streams to enable.
            if ischar(strm);strm = {strm};end;
            notOk = setdiff(strm,trellis.availableStreams);
            if any(notOk)
                error(['Unknown stream: ' notOk{:}]);
            end
            
            e= o.allChannels;
            notOk = setdiff(e,chan);
            if any(notOk)
                error(['These electrodes are not available : ' num2str(notOk)]);
            end
            args = cell(1,2*numel(strm));
            args(1:2:end) = deal(strm{:});
            args(2:2:end) = true;   % Enable all specified streams
            xippmex('signal',chan,args{:});
        end
        
        
%         function events(o,src,evt)
%             switch evt.EventName
%                 case 'BEFOREEXPERIMENT'
%                     
%                     ok = true;
%                     % Connect to Trellis/NIP
%                     tmp = o.operators;
%                     if isempty(tmp)
%                         error('Could not find Trellis on the network...')
%                     end
%                     if numel(tmp)>1
%                         error('More than on Trellis on the network??');
%                     end
%                     o.operator = tmp;
%                     
%                     % First make sure Trellis has stopped
%                     stat = o.status;
%                     if ~strcmpi(stat.status,'stopped')
%                         warning('Trellis was still recording when this experiment started');
%                         stat = xippmex('trial',o.operator,'stopped');
%                     end
%                     if ~strcmpi(stat.status,'stopped')
%                         error('Failed to stop Trellis?');
%                     end
%                     
%                     % Now start it with the file name specified by CIC. The
%                     % recording will run until stopped (Inf) and autoincrement is
%                     % off.
%                     stat = xippmex('trial',o.operator,'recording',o.cic.file,Inf,false);
%                     
%                     if ~strcmpi(stat.status,'recording')
%                         error('Failed to start recording on Trellis');
%                     end
%                 case 'AFTEREXPERIMENT'
%                     % Close the UDP link
%                     xippmex('close');
%                 case 'BEFORETRIAL'
%                     % Set trial bit
%                     if ~isempty(o.trialBit)
%                         digout(o,o.trialBit,true);
%                     end
%                 case 'AFTERTRIAL'
%                     % unset trial bit
%                     if ~isempty(o.trialBit)
%                         digout(o,o.trialBit,false);
%                     end
%             end
%         end
        
    end
end