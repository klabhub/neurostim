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
        STREAMS = {'raw','lfp','hi-res','hifreq','spk'};
    end
    properties (SetAccess=public, GetAccess=public)
        fakeRipple = true;
        dataProcessor; % Function to analyze streams
        streaming = containers.Map; % Map of stream names to channels
    end
    
    properties (Dependent)
        samplingRate;
        nrSamples;
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
        function v =get.samplingRate(o)
            % Hz, sampling frequency of signal
            switch upper(o.stream)
                case 'RAW'
                    v  = 30e3;
                case 'LFP'
                    v  = 1e3;
                case 'HI-RES'
                    v = 2e3;
                case 'HIFREQ'
                    v = 7.5e3;
                otherwise
                    error('%s is an invalid stream type.\n', o.stream);
            end
        end
        function v=get.nrSamples(o)
            v = 1000;
        end
        
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
         %   stopRemote(o.messenger);
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
            p.addParameter('timerPeriod',10,@isnumeric);
            p.addParameter('echo',false,@islogical);
            p.parse(varargin{:});
            
            o.dataProcessor = p.Results.processor;
            
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
          
            
            %% Setup a remote neurostim messenger
            o.messenger = neurostim.messenger;
            o.messenger.remoteFunction = @o.updateRipple; % This function will be called every update on the remote
            o.messenger.timerPeriod = p.Results.timerPeriod;
            o.messenger.echo = p.Results.echo;
            o.messenger.setupRemote; % Setup and Start running
            
            
            
        end
        
        
        function cmnd = updateRipple(o,msgr)
           
            % Collect requested streams from Ripple
           
                thisStreams = o.streaming.keys;
                for i= 1:numel(thisStreams)
                    channels = o.streaming(thisStreams{i});
                    nrChannels = numel(channels);
                    if o.fakeRipple
                        data.(thisStreams{i}).signals = randn(o.nrSamples,nrChannels);
                        data.(thisStreams{i}).times =   0:o.nrSamples;
                    else                        
                        [data.(thisStreams{i}).signals,data.(thisStreams{i}).times] = xippmex('cont',channels,o.nrSamples,thisStreams{i});            
                    end
                end                          
                % Send these to the user-specified function to handle
                % streams. This should return a struct with
                % .plugin.parameter fields
                cmnd = o.dataProcessor(data);
                % update.gabor.orientation = 10; % This would change the parameter orientation in plugin
                % 'gabor' to 10
           
        end
        
    end
    
    methods (Static)
        function cmd = debugDataProcessor(data) 
            % An example data processor
            if isfield(data,'lfp')
                if mod(round(sum(data.lfp.signals(:))),2)
                    color = [1 0 0];
                else
                    color = [0 1 0];
                end
            end
            cmd.command= 'SETSTICKY';  % Must specify that this is an SETSTICKY command by adding a .command field with the value SETSTICKY (sticky means it will persist across trials/conditions)
            cmd.reddot.color = color; % Assign a new color to the patch plugin (this works with demos/rippleDemo)
        end
        
    end
    
end

