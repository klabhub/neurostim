classdef sound < neurostim.plugin
    % Generic sound plugin for PTB. Add if using sound.
    properties (Access=public)
        sampleRate@double = NaN;
    end
    properties (Access=protected)
        paHandle
    end
    
    
    methods (Access=public)
        function o=sound(c)
            o=o@neurostim.plugin(c,'sound');
            
            % Sound initialization
            InitializePsychSound(1);
            
            % Opening here instead of beforeExperiment so that the actual
            % sampleRate is available for resampling in classes that use
            % this plugin (e.g. soundFeedback)
            o.paHandle = PsychPortAudio('Open');            
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
            PsychPortAudio('Close');
        end
    end
end