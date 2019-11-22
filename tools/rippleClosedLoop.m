classdef rippleClosedLoop  <handle
    % An example class to pull data from ripple, do some  analysis, and use the
    % results to change an ongoing experiment.
    % On the experiment side, run demos/rippleDemo
    % On a different computer, run
    % c=rippleClosedLoop;
    % start(c,'TimerPeriod',0.5);
    % This will update the color of the patch in the experiment every 0.5s.
    % To add your own code to run during the update, create a function that
    % takes two input arguments (signals and times) and one output (
    % a struct with a field .command that has the value 'UPDATE' and each
    % other field is the name of a plugin whose property you wish to update
    % (see debugDataProcessor for an example).
    % c=rippleClosedLoop;
    % c.start('processor',@myFunction,'timerPeriod',10); 
    %
    % BK - Nov 2019
    
    %% PROPERTIES
    properties (SetAccess=public, GetAccess=public)
        channel;  %1 -A-1
        stream;   % raw lfp hi-res hifreq
        fakeRipple = true;
        dataProcessor; % Function to analyze streams
    end
    
    properties (Dependent)
        samplingRate;
        nrSamples;
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
    end
    
    %% Methods
    methods
        function o = rippleClosedLoop
            % Nothing to do.
        end
        
        function delete(o)
            stopRemote(o.messenger);
            if ~o.fakeRipple
                xippmex('close'); % Close xippmex connection
            end
        end
        
        function start(o,varargin)
            % Start the app
            
            p=inputParser;
            p.addParameter('processor', @rippleClosedLoop.debugDataProcessor,@(x)(ischar(x) || isa(x,'function_handle')));
            p.addParameter('timerPeriod',10,@isnumeric);
            p.addParameter('echo',false,@islogical); 
            p.parse(varargin{:});
            
            o.dataProcessor = p.Results.processor;
            
            
            
            %% Setup the ripple connection
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
                % Start streaming
                if xippmex('signal', o.channel, o.stream) == 0
                    xippmex('signal', o.channel, o.stream, 1); % Turn streaming on
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
            status = true;
            if status
                % Collect requested streams from Ripple
                if o.fakeRipple
                    signals = rand(10,1);
                    times =1:10;
                else
                    [signals,times] = xippmex('cont',o.channel,o.nrSamples,o.stream);
                end
                
                % Send these to the user-specified function to handle
                % streams. This should return a struct with
                % .plugin.parameter fields
                cmnd = o.dataProcessor(signals,times);
                % update.gabor.orientation = 10; % This would change the parameter orientation in plugin
                % 'gabor' to 10
            else
                fprintf('Ripple status : %d', status);
            end
        end
        
    end
    
    methods (Static)
        function cmd = debugDataProcessor(signals,times) %#ok<INUSD>
            % An example data processor
            fprintf('Received %d signals with mean %3.2f\n', numel(signals), mean(signals));
            cmd.command= 'UPDATE';  % Must specify that this is an update command by adding a .command field with the value UPDATE
            cmd.patch.color = rand(1,3); % Assign a random color to the patch plugin (this works with demos/rippleDemo)
        end
        
    end
    
end

