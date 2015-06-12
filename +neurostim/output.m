classdef output < neurostim.plugin
    % Simple output class which can be used to save files in a specific
    % format to the specified directory.
    % Variables:
    % saveDirectory - computer directory to save files to.
    % saveAfterTrial - save after every X trials. 0 indicates no saving
    % until the end of the experiment.

    events
        AFTERTRIAL;    
        AFTEREXPERIMENT;
    end
    
    properties
        counter;
        data;
        saveAfterTrial = 0;
    end
    
    properties (Dependent)
        fullFile;       % Output file name including path
    end
     
    methods (Access = public)
        function o = output
            o = o@neurostim.plugin('output');
            
            if o.saveAfterTrial > 0
                % only listen to afterTrial event if saving after trial.
                o.listenToEvent({'AFTERTRIAL'});
            end
            o.listenToEvent({'AFTEREXPERIMENT'});
            
            o.counter = o.saveAfterTrial;
            
        end
        
            
        function collectData(o,c)
            % collects all the data from log files into a cell array.
            o.data = [];
            for a = 1:length(o.cic.stimuli)
               stimulus = o.cic.stimuli{a};
               o.data.(stimulus)(1,:) = o.cic.(stimulus).log.parms;
               o.data.(stimulus)(2,:) = o.cic.(stimulus).log.values;
               o.data.(stimulus)(3,:) = num2cell(o.cic.(stimulus).log.t);
            end
        end
        
        
        function saveFileBase(o,c)
           % Save output to disk.
            [pathName, fname,ext] = fileparts(o.fullFile);
  
            try
                if ~exist(pathName,'dir')
                    mkdir(pathName);
                end
                saveFile(o,c);
            catch
                try
                    warning('There was a problem saving to disk. Attempting save to c:\temp');
                    save(['c:\temp\' fname,ext],'c', '-mat');
                    warning('There was a problem saving to disk. Attempting save to c:\temp.... success');
                catch
                    warning('There was a problem saving to disk. Halting execution to allow manual recovery');
                    keyboard;
                end
            end
        end
        
        function saveFile(o,c)
            %Function that should be overloaded in derived class for custom user output formats.
            save(o.fullFile,'c', '-mat');
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveAfterTrial;   % reset counter
                collectData(o,c);   % run data collection and file saving
                saveFileBase(o,c);
            else o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment.
            collectData(o,c);
            saveFileBase(o,c);
        end
    
    end
    
    methods
        function v = get.fullFile(o)
            v = cat(2,horzcat(o.cic.fullFile,'.nso'));
        end
    end
    
end
