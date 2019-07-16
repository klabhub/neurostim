classdef logger < handle
    % Class to handle writeToFeed commands issued by stimuli and plugins.
    % These are messages that are intended for the experimenter and are
    % written to the command line.
    % To avoid interfering witht the experiment itself, these messages can
    % be cached and written out in the intertrial interval (localCache =
    % true), and they can also be sent to a different computer by
    % specifying host name and starting a logger there. 
    % This makes it possible to run the experiment on a single
    % monitor machine (which improves timing of PTB) and still get
    % online information on the progression of the experiment.
    %
    % See remoteLogDemo for an example
    %  
    % BK March 2019.
    
    properties (Constant)
        EMPTYCACHE = struct('style',cell(1000,1),'formatSpecs',cell(1000,1),'msg',cell(1000,1),'plg',cell(1000,1),'trialTime',cell(1000,1),'trial',cell(1000,1));
    end
    
    properties (SetAccess=public, GetAccess=public)
        %% Properties of the remote server and local client
        host@char=''; % The remote server to connect to  (empty means no remote server)
        port@double =1024;
        timerPeriod@double = 2; % the remote host will check for new inputs every 2 seconds.
        
        outputBufferSize@double = 100000; % bytes
        inputBufferSize@double = 100000; % bytes
        timeout@double = 1; % seconds      
        
        
        %% Cache
        localCache@logical = false;    % Write out only after the trial ends [false]
        cache = neurostim.logger.EMPTYCACHE;  % initialize empty
        cacheCntr@double =0;
        echo@logical = true;            % Even when logging remotely, generate local echo too.
        
        useColor@logical = true;        % Use cprintf's color functionality
        
    end
    properties (SetAccess=private, GetAccess=public)
        isServer@logical = false;
        tcp; % Leave this untyped so that someone without the TCPIP toolbox can use the object locally.
    end
    
    properties (Dependent)
        hasRemote;
    end
    
    methods
        function v=get.hasRemote(o)
            v = ~isempty(o.host);
        end
    end
    
    
    methods
        function o= logger(startAsServer)
            o = o@handle;
            if nargin<1
                startAsServer =false;
            end
            if startAsServer
                o.isServer = true;
                o.port = 80;
                o.host = '0.0.0.0';
                setupServer(o);
            end
        end
        function close(o)
            if o.hasRemote
                data  =getByteStreamFromArray('CLOSE');
                binblockwrite(o.tcp,[double('#') 1 numel(data) data],'uint8');
            end
        end
        function disp(o)
            if o.isServer
                disp(['Remote Logger for ' o.tcp.RemoteHost]);
            elseif o.hasRemote
                disp(['Local logger connected to ' o.host]);
            else
                disp('Local logger');
            end
        end
        
        function feed(o,inTrial,style,thisTrial,thisTrialTime,msg,plg)
            % This function is called from plugin.writeToFeed
            if inTrial && (o.localCache || o.hasRemote)
                % Cache the info for later printing to the command line.
                % When using a remote host, feeds must be cached.
                o.cacheCntr= o.cacheCntr+1;
                o.cache(o.cacheCntr).style = style;
                o.cache(o.cacheCntr).inTrial = inTrial;                
                o.cache(o.cacheCntr).msg = msg;
                o.cache(o.cacheCntr).plg= plg;
                o.cache(o.cacheCntr).trialTime = thisTrialTime;
                o.cache(o.cacheCntr).trial = thisTrial;
            else
                % Print immediately to the local command line
                print(o,inTrial,style,thisTrial,thisTrialTime,msg,plg);
            end
        end
        
        function printCache(o)
            if (~o.isServer && o.hasRemote)
                % Send to remote logger
                data = getByteStreamFromArray(o.cache(1:o.cacheCntr));
                binblockwrite(o.tcp,[double('#') 1 numel(data) data],'uint8');
            end
            
            if o.echo
                % Also show locally
                [~,ix] = sortrows([[o.cache.trial]' [o.cache.trialTime]']);
                for i=ix'
                    print(o,o.cache(i).inTrial,o.cache(i).style,o.cache(i).trial,o.cache(i).trialTime,o.cache(i).msg,o.cache(i).plg);
                end
                o.cache =neurostim.logger.EMPTYCACHE;
                o.cacheCntr =0;
            end
        end
        
        
        function setupServer(o)
            % Start a local server to receive messages from the client.
            o.checkToolbox;
            [~,serverName] =system('hostname');
            serverName = deblank(serverName);
            o.tcp = tcpip(o.host,o.port,'NetworkRole','Server',...
                'Name',['NS@' serverName],...
                'OutputBufferSize',o.outputBufferSize,...
                'InputBufferSize',o.inputBufferSize,...
                'Terminator','LF',...
                'Timeout',o.timeout);
            o.tcp.BytesAvailableFcn = @o.incoming;
            o.tcp.BytesAvailableFcnMode = 'terminator';
            o.tcp.ReadAsyncMode=  'continuous';
            o.echo = true; % Server always echos
            runServer(o);
        end
        
        function runServer(o)
            tmr = timerfind('Name','Logger');
            if ~isempty(tmr)
                stop(tmr);
                delete(tmr);
            end
            if strcmpi(o.host,'0.0.0.0')
                hstStr = 'any host';
            else
                hstStr = o.host;
            end
            disp(['Waiting for a logger connection from ' hstStr ]);
            fopen(o.tcp); % Busy wait until the client connects
            if strcmpi(o.tcp.Status,'Open')
                disp(['Connected to ' o.tcp.RemoteHost]);
            end
            disp('Starting timer to read incoming feeds')
            tmr = timer('BusyMode','drop','ExecutionMode','FixedRate','Period',o.timerPeriod,'TimerFcn',@o.incoming,'Name','Logger');
            start(tmr);
            disp(['Timer running every '  num2str(o.timerPeriod) 's']);
        end
        
        % The timer running on the host calls this to process the incoming
        % data.
        function incoming(o,tmr,event) %#ok<INUSD>
            if o.tcp.BytesAvailable >0
                bytes = binblockread(o.tcp,'uint8'); % Retrieve bytestream encoded message
                data= getArrayFromByteStream(uint8(bytes(4:end))); % Conver to Matlab vars.
                if ischar(data)
                    switch (data)
                        case 'CLOSE'
                            fclose(o.tcp);
                            runServer(o);
                        otherwise
                            disp(data)
                    end
                elseif iscell(data)
                    % This was a call from the client sending a single print line (see o.print)
                    % This is not recommended - too much reading/writing.
                    print(o,data{:});
                elseif isstruct(data)
                    % This should be the cache that was sent from the
                    % client.
                    o.cache =data; % Store it on the host
                    printCache(o); % Print it to the command line
                else
                    disp('Received unknown data object')
                    data
                end
            end
        end
        
        
        function setupClient(o)
            % If a host has been specified, this function will try to
            % connect to it.
            if ~isempty(o.host)
                o.checkToolbox;
                [~,clientName] =system('hostname');
                clientName = deblank(clientName);
                o.tcp = tcpip(o.host,o.port,'NetworkRole','client',...
                    'name',['NS@' clientName],...
                    'OutputBufferSize',o.outputBufferSize,...
                    'InputBufferSize',o.inputBufferSize,...
                    'Terminator','LF',...
                    'Timeout',o.timeout,...
                    'ByteOrder','littleEndian');
                    answer = input(['Is the remote logger running on ' o.host ':' num2str(o.port) ' ( Use: neurostim.logger(true);) [Y/n]'],'s');
                    if isempty(answer)
                        answer = 'Y';
                    end
                    connected=false;
                    if strcmpi(answer,'Y')
                        try
                           fopen(o.tcp); % Busy wait until connected.                           
                        catch 
                            
                        end
                        if strcmpi(o.tcp.Status,'Open')
                            connected =true;
                            disp(['Connected to ' o.tcp.RemoteHost ':' num2str(o.tcp.RemotePort)]);
                        else                            
                            disp(['Failed to connect to the logger app (' o.host ':' num2str(o.port) '). Is it running? ']);
                        end
                    end
                    if ~connected
                        answer = input('Continue without remote logging? (Y/n)','s');
                        if strcmpi(answer,'N')
                           error('No remote logger');
                        else
                            o.host = ''; % No remote host
                        end
                    end                        
            end
        end
        
        
        
        function print(o,inTrial,style,thisTrial,thisTrialTime,msg,plg)
            % Prints one or more lines of information to the command line            .
            if inTrial
                phaseStr = '';
            else
                phaseStr = '(ITI)';
            end
            if ~o.useColor
                style = 'NOSTYLE';
            end
            if iscell(msg)
                % multi line message
                maxChars = max(cellfun(@numel,msg));
                neurostim.utils.cprintf(style,'TR: %d: (T: %.0f %s) %s \n',thisTrial,thisTrialTime,phaseStr,plg); 
                neurostim.utils.cprintf(style,'\t%s\n',repmat('-',[1 maxChars]));
                for i=1:numel(msg)
                    neurostim.utils.cprintf(style,'\t %s\n',msg{i}); % These are the message lines
                end
                neurostim.utils.cprintf(style,'\t%s\n',repmat('-',[1 maxChars]));
            else
                % single line
                neurostim.utils.cprintf(style,'TR: %d (T: %.0f %s): %s - %s \n',thisTrial,thisTrialTime,phaseStr,plg,msg);
            end
        end
        
        function checkToolbox(o)
            f = which('tcpip');
            if isempty(f)
                error('neurostim.messenger requires the tcpip command (part of the Instrument Control Toolbox). Please install it first to use messenger across the network.');
            end
        end
        
    end
    
    
    
end