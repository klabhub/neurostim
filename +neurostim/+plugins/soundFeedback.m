classdef soundFeedback < neurostim.plugins.feedback
    % Plugin to deliver auditory feedback.
    % 'path'  -  Path to search for sound files that are specified in add()
    % 'waveform'  - filename for a .wav or other file. Or an actual mono mono- (vector) or stereo (matrix) waveform 
    properties (SetAccess=public)
        path@char =''; % Set this to the folder that contains the sound files.
    end
    
    
    methods (Access=public)
        function o=soundFeedback(c,name)
            o=o@neurostim.plugins.feedback(c,name);
            o.listenToEvent({'BEFOREEXPERIMENT'});            
        end
    end
    
    methods (Access=protected)        
        function chAdd(o,varargin)
            % This is called from feedback.add only, there the standard
            % parts of the item have already been added to the class. 
            % Here we just add the sound specific arts.
            p=inputParser;  
            p.StructExpand = true; % The parent class passes as a struct
            p.addParameter('waveform',[],@(x) isnumeric(x) || ischar(x));     %Waveform data, filename (wav), or label for known (built-in) file (e.g. 'correct')
            p.parse(varargin{:});
            if ischar(p.Results.waveform)
                % Look in the sound path (unless a full path has been
                % provided)
                [pth,~,~] = fileparts(p.Results.waveform);
                if isempty(pth)
                    file = fullfile(o.path,p.Results.waveform);
                else
                    file = p.Results.waveform;
                end
                if exist(file,'file')
                    waveform = o.readFile(file);
                else
                    o.cic.error('STOPEXPERIMENT',['Sound file ' strrep(file,'\','/') ' could not be found.']);
                end
            else 
                waveform = p.Results.waveform; % Presumably the waveform itself
            end
            %Store the waveform
            o.addProperty(['item', num2str(o.nItems) 'waveform'],waveform);
        end
    end
    
    methods (Access=public)
        
        function beforeExperiment(o,c,evt)            
            %Check that the sound plugin is enabled
            snd = c.pluginsByClass('sound');            
            if isempty(snd)
                o.cic.error('STOPEXPERIMENT','No "sound" plugin detected. soundFeedback relies on it.');
            end            
            %Allocate the audio buffers
            for i=1:o.nItems
               o.addProperty(['item', num2str(i) 'buffer'],o.cic.sound.createBuffer(o.(['item' num2str(i) 'waveform'])));
            end
        end

        function waveformData = readFile(o,file)             
            %Read WAV file and return waveform data
            waveformData = audioread(file);
        end
    end
    
    methods (Access=protected)
         
        function deliver(o,item)
            o.cic.sound.play(o.(['item' num2str(item) 'buffer']));   
        end
 end
        
    
    
end