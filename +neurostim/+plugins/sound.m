classdef sound < neurostim.plugins.feedback
    %Plugin to deliver auditory feedback.
    %Specify either a filename to a wav file, or pass in a mono- (vector) or stereo (matrix) waveform to be played.
    
    properties

    end
    
    properties (Access=private)
        paHandle;
    end
    
    methods (Access=public)
        function o=sound(name)
            o=o@neurostim.plugins.feedback(name);
            o.listenToEvent({'BEFOREEXPERIMENT', 'AFTEREXPERIMENT'});
        end
        
        function chAdd(o,varargin)

            %First add standard parts of the new item in parent class
            
            p=inputParser;                             
            p.addParameter('waveform',[],@(x) isnumeric(x) || ischar(x));     %Waveform data, filename (wav), or label for known (built-in) file (e.g. 'correct')
            p.parse(varargin{:}{:});
            p = p.Results;
            
            if ischar(p.waveform)
                
                %If it's a label to a known file
                if any(strcmpi(p.waveform,{'CORRECT','INCORRECT'}))
                    p.waveform = ['nsSounds\sounds\' p.waveform '.wav'];
                end
                
                %Now its a wave file. Load it.
                if exist(p.waveform,'file')
                    p.waveform = o.readFile(p.waveform);
                else
                    error(['Sound file ' toPlay ' could not be found.']);
                end
            end

            %Store the waveform
            o.item(o.nItems).waveform = p.waveform;
        end
        
        function beforeExperiment(o,c,evt)
            
            % Sound initialization
            InitializePsychSound(1);
            o.paHandle = PsychPortAudio('Open');
            
            %Allocate the audio buffers
            for i=1:o.nItems
               o.item(i).buffer = o.bufferSound(o.item(i).waveform); 
            end
        end

        function waveformData = readFile(o,file)
             
            %Read WAV file and return waveform data
            waveformData = audioread(file);
        end
        
        function buffered = bufferSound(o,waveform)
            
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
            
            %All good. Create the buffer
            buffered = PsychPortAudio('CreateBuffer',o.paHandle,waveform);
        end
            
        function afterExperiment(o,c,evt)
            PsychPortAudio('Close', o.paHandle);
        end
        
        function delete(o)
            PsychPortAudio('Close');
        end
    end
    
    methods (Access=protected)
         
        function deliver(o,item)
            PsychPortAudio('FillBuffer', o.paHandle,item.buffer);
            
            % play sound immediately.
            PsychPortAudio('Start',o.paHandle);
        end
 end
        
    
    
end