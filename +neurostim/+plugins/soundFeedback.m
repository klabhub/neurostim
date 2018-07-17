classdef soundFeedback < neurostim.plugins.feedback
    % Plugin to deliver auditory feedback.
    % 'path'  -  Path (relative to Neurostim root directory
    % (cic.dirs.root)) to search for sound files that are specified in
    % add(). This defaults to 'sounds'.
    % 'waveform'  - filename for a .wav or other file. Or an actual mono
    % mono- (vector) or stereo (matrix) waveform. Files will be searched in
    % the 'path' directory, but full file names (includng path) can also be
    % given.
    properties (SetAccess=public)
        path@char ='sounds'; % Set this to the folder that contains the sound files. Relative to cic.root
        buffer  = []; %Vector of buffer handles created by PscyhPortAudio in plugins.sound.m
        waveform = {}; % Waveforms
    end
    
    
    methods (Access=public)
        function o=soundFeedback(c,name)
            o=o@neurostim.plugins.feedback(c,name);
            
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
                    file = fullfile(o.cic.dirs.root,o.path,p.Results.waveform);
                else
                    file = p.Results.waveform;
                end
                if exist(file,'file')
                    %Read file and return waveform data        
                    wave = audioread(file);
                    info = audioinfo(file);
                    % If the .wav sampleRate differs from the soundcard, we
                    % need to change the sampling rate.
                    if info.SampleRate ~= o.cic.sound.sampleRate                        
                        % Simple resampling
                        wave =resample(wave,linspace(0,info.Duration,info.TotalSamples),o.cic.sound.sampleRate);
                    end
                else
                    o.cic.error('STOPEXPERIMENT',['Sound file ' strrep(file,'\','/') ' could not be found.']);
                end
            else 
                wave = p.Results.waveform; % Presumably the waveform itself
            end
            %Store the waveform
            o.waveform{o.nItems} = wave;
        end
    end
    
    methods (Access=public)
        
        function beforeExperiment(o)            
            %Check that the sound plugin is enabled
            snd = pluginsByClass(o.cic,'sound');            
            if isempty(snd)
                o.cic.error('STOPEXPERIMENT','No "sound" plugin detected. soundFeedback relies on it.');
            end            
            %Allocate the audio buffers
            o.buffer = nan(1,o.nItems);
            for i=1:o.nItems
               o.buffer(i)  = createBuffer(o.cic.sound,o.waveform{i});
            end
        end
        
    end
    
    methods (Access=protected)
         
        function deliver(o,item)
            play(o.cic.sound,o.buffer(item));   
        end
 end
        
    
    
end