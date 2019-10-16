classdef sound < neurostim.plugin
    % Generic sound plugin for PTB. Add if using sound.
    properties (Access=public)
        sampleRate@double = NaN;
    end
    properties (SetAccess=protected,GetAccess=public)
        paHandle
    end
    
    
    methods (Access=public)
        function o=sound(c,latencyClass)
            if nargin <2
                latencyClass = c.hardware.sound.latencyClass; % Latency is a priority
%   From PsychPortAudio('Open?'): Allows to select how aggressive PsychPortAudio should be about
% minimizing sound latency and getting good deterministic timing, i.e. how to
% trade off latency vs. system load and playing nicely with other sound
% applications on the system. Level 0 means: Don't care about latency, this mode
% works always and with all settings, plays nicely with other sound applications.
% Level 1 (the default) means: Try to get the lowest latency that is possible
% under the constraint of reliable playback, freedom of choice for all parameters
% and interoperability with other applications. Level 2 means: Take full control
% over the audio device, even if this causes other sound applications to fail or
% shutdown. Level 3 means: As level 2, but request the most aggressive settings
% for the given device. Level 4: Same as 3, but fail if device can't meet the
% strictest requirements.
%                 
            end
            o=o@neurostim.plugin(c,'sound');
            o.addProperty('latencyClass',latencyClass);
            
            % Sound initialization
            clear PsychPortAudio;   %Class seems to be not properly cleared sometimes, when Neurostim doesn't close gracefully.
            InitializePsychSound(latencyClass);
            
            % Opening here instead of beforeExperiment so that the actual
            % sampleRate is available for resampling in classes that use
            % this plugin (e.g. soundFeedback)
            
            o.paHandle = PsychPortAudio('Open',c.hardware.sound.device, [], latencyClass);
            status = PsychPortAudio('GetStatus', o.paHandle);
            o.sampleRate = status.SampleRate;
            
             %Play a dummy sound (first sound wasn't playing)
            bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,[0; 0]);
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            PsychPortAudio('Start',o.paHandle);
            
        end
        
        
%         function beforeExperiment(o)
%                    
%         end
%         
        function afterExperiment(o)
            PsychPortAudio('Close', o.paHandle);
        end
        
        function bufferHandle = createBuffer(o,waveform)
            
            %If a vector (mono), force to be a row
            if isvector(waveform)
                waveform = waveform(:)';
                waveform = [waveform; waveform];
            end
            
            %If neither mono, nor stereo
            if ~any(size(waveform)==2)
                error('Waveform data must be either a vector (mono) or two-column matrix (stereo)');
            end
            
            %Ensure 2 x N matrix
            if size(waveform,2)==2
                waveform = waveform';
            end
            
            bufferHandle = PsychPortAudio('CreateBuffer',o.paHandle,waveform);
        end
        
        function play(o,bufferHandle)
            PsychPortAudio('FillBuffer', o.paHandle,bufferHandle);
            
            % play sound immediately.
            PsychPortAudio('Start',o.paHandle);
        end
        
        
        function delete(o) %#ok<INUSD>
            clear PsychPortAudio;
        end
    end
end