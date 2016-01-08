classdef soundFeedback < neurostim.plugins.feedback
    %Plugin to deliver auditory feedback.
    %Specify either a filename to a wav file, or pass in a mono- (vector) or stereo (matrix) waveform to be played.
    
    properties

    end
    
    methods (Access=public)
        function o=soundFeedback(name)
            o=o@neurostim.plugins.feedback(name);
            o.listenToEvent({'BEFOREEXPERIMENT'});
        end
    end
    
    methods (Access=protected)
        
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
            o.(['item', num2str(o.nItems)]).waveform = p.waveform;
        end
    end
    
    methods (Access=public)
        
        function beforeExperiment(o,c,evt)
            
            %Check that the sound plugin is enabled
            snd = c.pluginsByClass('sound');
            
            if isempty(snd)
                error('No "sound" plugin detected. soundFeedback relies on it.');
            end
            
            %Allocate the audio buffers
            for i=1:o.nItems
               o.(['item' num2str(i)]).buffer = o.cic.sound.createBuffer(o.(['item' num2str(i)]).waveform);
            end
        end

        function waveformData = readFile(o,file)
             
            %Read WAV file and return waveform data
            waveformData = audioread(file);
        end
    end
    
    methods (Access=protected)
         
        function deliver(o,item)
            o.cic.sound.play(item.buffer);
        end
 end
        
    
    
end