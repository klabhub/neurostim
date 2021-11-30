classdef rippleClosedLoop  < handle
    % An example class to pull data from ripple, do some  analysis, and use the
    % results to change an ongoing experiment.
    % On the experiment side, run demos/rippleDemo
    % On a different computer, run
    % c=rippleClosedLoop;
    % start(c,'TimerPeriod',0.5);
    % This will set the color of the patch in the experiment every 0.5s.
    % To add your own code to run during the update, create a function that
    % takes two input arguments (signals and times) and one output (
    % a struct with a field .command that has the value 'SETSTICKY' and each
    % other field is the name of a plugin whose property you wish to update
    % (see debugDataProcessor for an example).
    % c=rippleClosedLoop;
    % c.start('processor',@myFunction,'timerPeriod',10);
    %
    % BK - Nov 2019
    
    %% PROPERTIES
    properties (Constant)
        STREAMS = {'raw','lfp','hi-res','hifreq'};
        bufferSize = 5;% xippmex maintains a 5 seconds circular buffer
        samplingRate = containers.Map( {'raw','lfp','hi-res','hifreq'},[30e3 1e3 2e3 7.5e3])
    end
    properties (SetAccess=public, GetAccess=public)
        fakeRipple = false;
        dataProcessor = @(x)(struct('command','NOP')); % Function to analyze streams
        streaming = containers.Map; % Map of stream names to channels
        nipTimeStamp; % Time stamp based on 30kHz clock ticks
    end
    
    properties (Dependent)
       
        stimChannels;
        spikeChannels;
        analogChannels;
        allChannels;
    end
    properties (SetAccess=protected,GetAccess=public)
        messenger; % A neurostim.messenger        
    end
    
    %% Get/set
    methods
        
        function v=get.stimChannels(o)
            v = xippmex('elec','stim');
        end
        
        function v=get.spikeChannels(o)
            v = union(xippmex('elec','micro'),xippmex('elec','nano'));
        end
        
        function v=get.analogChannels(o)
            v = xippmex('elec','analog');
        end
        function v=get.allChannels(o)
            v = xippmex('elec','all');
        end
    end
    
    %% Methods
    methods
        function o = rippleClosedLoop(fake)
            if nargin<1
                fake =false;
            end
            o.fakeRipple = fake;
            
            % Connnect.
            if ~o.fakeRipple
                pth = which('xippmex');
                if isempty(pth)
                    error('The ripple ClosedLoop tool relies on xippmex, which could not be found. Please obtain it from your Trellis installation folder, and add it to the Matlab path');
                end
                % Iniitialize
                try
                    stat = xippmex;
                catch
                    stat = -1;
                end
                if stat ~= 1; error('Xippmex Did Not Initialize');  end
                
                % Disable all streaming first, but looping is slow and
                % sometimes crashes... For now we'll depend on the user to
                % disable all streams on startup.                
            end
        end
        
        function delete(o)
            o.deleteRippleTimer;
            if isa(o.messenger,'neurostim.messenger')
                stopRemote(o.messenger);
            end
            if ~o.fakeRipple
                xippmex('close'); % Close xippmex connection
            end
        end
        
        function stream(o,channel,stream,enable)
            % Specify a list of channels, a stream ('lfp','spike','raw')
            % and true/false to add or remove them from the streaming
            % collection
            if nargin<4
                enable =true;
            end
            missing = setdiff(channel,o.allChannels);
            if ~isempty(missing)
                error(['These channels do not exist and cannot be streamed:' num2str(missing)]);
            end
            if isKey(o.streaming,stream)
                streamingChannels = o.streaming(stream);
            else
                streamingChannels = ones(1,0);
            end
            if enable
                streamingChannels = union(streamingChannels,channel);
            else
                streamingChannels = setdiff(streamingChannels,channel);
            end
            o.streaming(stream) = streamingChannels;
        end
        
        
        function start(o,varargin)
            % Start the app
            
            p=inputParser;
            p.addParameter('processor', @rippleClosedLoop.debugDataProcessor,@(x)(ischar(x) || isa(x,'function_handle')));
            p.addParameter('nsUpdatePeriod',10); % Updates are sent to neurostim every x second. Set this to 0 to just collect data here and not send to Neurostim
            p.addParameter('rippleUpdatePeriod',3,@(x) (x<o.bufferSize))  % Data is collected every x seconds.
            p.addParameter('echo',false,@islogical);
            p.parse(varargin{:});
            
           
            %% Start Streaming
            thisStreams = o.streaming.keys;
            for i= 1:numel(thisStreams)
                channels = o.streaming(thisStreams{i});
                if ~ismember(thisStreams{i},{'stim','spk'})
                    % One per front end to speed things up
                    channels = unique(ceil(channels/32))*32;
                end
                if ~o.fakeRipple
                    xippmex('signal',channels,thisStreams{i},ones(size(channels)));
                end
            end
            
            %% Start a timer to collect data from Ripple
            o.dataProcessor = p.Results.processor;
            o.nipTimeStamp = double(xippmex('time')); % Collect from this time point onward
            tmr = timer('BusyMode','drop','ExecutionMode','FixedRate','Period',p.Results.rippleUpdatePeriod,'TimerFcn',@o.updateRipple,'Name','rippleClosedLoop');
            start(tmr);
            disp(['Data analysis timer running every '  num2str(p.Results.rippleUpdatePeriod) 's. <a href="matlab:rippleClosedLoop.deleteRippleTimer">Stop running.</a>']);
        
            %% Setup a remote neurostim messenger
            if p.Results.nsUpdatePeriod >0
                o.messenger = neurostim.messenger;            
                o.messenger.timerPeriod = p.Results.nsUpdatePeriod;
                o.messenger.echo = p.Results.echo;
                o.messenger.setupRemote; % Setup and Start running
            end
            
            
        end
        
        
        function cmnd = updateRipple(o,tmr,evt) %#ok<INUSD>
            % Collect requested streams from Ripple and send to the data
            % processor
            thisStreams = o.streaming.keys;
            for i= 1:numel(thisStreams)
                channels = o.streaming(thisStreams{i});
                nrChannels = numel(channels);
                data.(thisStreams{i}).channels =   channels;
                sf = o.samplingRate(thisStreams{i});
                dt = (double(xippmex('time'))-o.nipTimeStamp)/30000; % time in s since last
                
                missed = (dt-o.bufferSize);
                if missed > 0
                    warning(['Lost ' num2str(1000*missed) ' miliseconds of samples']);
                    dt = o.bufferSize;
                    from  = []; % Just take the last 5s
                else                    
                    from = o.nipTimeStamp+1;
               end
                    
                if o.fakeRipple   
                    nrSamples= dt*sf;
                    data.(thisStreams{i}).signals = randn(nrSamples,nrChannels);
                    data.(thisStreams{i}).times =   0:nrSamples;
                else                    
                    [signals,timeStamp] = xippmex('cont',channels,1000*dt,thisStreams{i},from);
                    nrSamples = size(signals,2);
                    o.nipTimeStamp =double(timeStamp)+(nrSamples/sf)*30000-1;
                    data.(thisStreams{i}).signals =signals';
                    
                end
            end
            % Send these to the user-specified function to handle
            % data streams, this function should return a cmnd that is sent
            % to Neurostim via the messenger.            
            cmnd = o.dataProcessor(data);                 
        end
        
    end
    
    methods (Static)
        function cmd = debugDataProcessor(data)
            % An example data processor
            % data will have fields corresponding to the streams
            % data.lfp.signals  [nrSamples nrChannels]
            % data.lfp.time
            fprintf('Received LFP signals: [%d %d]\n',size(data.lfp.signals)); 
            %% Process the data
            if isfield(data,'lfp')
                if mod(round(sum(data.lfp.signals(:))),2)
                    color = [1 0 0];
                else
                    color = [0 1 0];
                end
            end
            %% Setup a command to send to Neurostim
            cmd.command= 'SETSTICKY';  % Must specify that this is an SETSTICKY command by adding a .command field with the value SETSTICKY (sticky means it will persist across trials/conditions)
            cmd.patch.color = color; % Assign a new color to the patch plugin (this works with demos/rippleDemo)
        end        
        
        function deleteRippleTimer
            tmr = timerfind('Name','rippleClosedLoop');
            if ~isempty(tmr)
            stop(tmr);
            delete(tmr);
            end
            disp('Stopped the rippleClosedLoop timer');
        end
    end
    
    
    
end

