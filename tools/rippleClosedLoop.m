classdef rippleClosedLoop < neurostim.messenger
    % An example class to pull data from ripple, do some  analysis, and use the
    % results to change an ongoing experiment
    
    % BK - Nov 2019
    
    properties (SetAccess=public, GetAccess=public)
        channel;  %1 -A-1
        stream;   % raw lfp hi-res hifreq
        fake = true;
        
    end
    
    properties (Dependent)
        samplingRate;
        nrSamples;
    end
    
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
    
    
    
    methods
        function o = rippleClosedLoop(fun)
            o = o@neurostim.messenger(true); % Start a 'remote' type messenger
            if nargin>0
                o.remoteFunction =fun;
            else
                % Demo purposes
                o.remoteFunction = @rippleClosedLoop.debugRemoteFunction;
            end
            
        end
        
        function delete(o)
            if o.fake;return;end
            xippmex('close');
        end
        
        function start(o)
            if o.fake;return;end
            pth = which('xippmex');
            if isempty(pth)
                error('The ripple ClosedLoop tool relies on xippmex, which could not be found. Please obtain it from your Trellis installation folder, and add it to the Matlab path');
            end
            
            %% Iniitialize
            try
                stat = xippmex;
            catch
                stat = -1;
            end
            if stat ~= 1; error('Xippmex Did Not Initialize');  end
            
            if xippmex('signal', o.channel, o.stream) == 0
                xippmex('signal', o.channel, o.stream, 1); % Turn streaming on
            end
        end
        
        
        
        
    end
    methods (Static)
        function update = debugRemoteFunction(o)
            % Example data processor that just writes some summary locally
            
            status = true;
            if status
                % Collection
                if o.fake
                    signals = rand(10,1);
                    times =1:10;
                else
                    [signals,times] = xippmex('cont',o.channel,o.nrSamples,o.stream);
                end
            end
            fprintf('Read %d samples from %d channels with mean %3.2f\n',numel(times),size(signals,2),mean(signals));
            %update = struct; % Send an empty struct to the experiment. This will do nothing.
            update.patch.color = rand(1,3);
            % update.gabor.orientation = 10; % This would change the parameter orientation in plugin
            % 'gabor' to 10
        end
    end
    
    
    
end

