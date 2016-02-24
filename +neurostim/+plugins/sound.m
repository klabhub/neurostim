classdef sound < neurostim.plugin
    % Generic sound plugin for PTB. Add if using sound.
    properties (Access=protected)
        paHandle
    end
    
    
    methods (Access=public)
        function o=sound(c)
            o=o@neurostim.plugin(c,'sound');
            o.listenToEvent({'BEFOREEXPERIMENT', 'AFTEREXPERIMENT'});
        end
        
        function beforeExperiment(o,c,evt)
            % Sound initialization
            InitializePsychSound(1);
            o.paHandle = PsychPortAudio('Open');
        end
        
        function afterExperiment(o,c,evt)
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
        
        
        function delete(o)
            PsychPortAudio('Close');
        end
    end
end