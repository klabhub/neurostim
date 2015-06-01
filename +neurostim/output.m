classdef output < neurostim.plugin
    % Simple output class which can be used to save files in a specific
    % format to the specified directory.
    % Variables:
    % saveDirectory - computer directory to save files to.
    % saveAfterTrial - save after every X trials. 0 indicates no saving
    % until the end of the experiment.

    events
        BEFOREFRAME;
        AFTERFRAME;    
        BEFORETRIAL;
        AFTERTRIAL;    
        BEFOREEXPERIMENT;
        AFTEREXPERIMENT;
    end
    
    properties
        counter;
        data;
    end
    
    methods
        function o = output
            o = o@neurostim.plugin('output');
            o.addProperty('saveDirectory','C:\MATLAB\Neurostim\');
            o.addProperty('saveAfterTrial',2);
            
            if o.saveAfterTrial > 0
                % only listen to afterTrial event if saving after trial.
                o.listenToEvent({'AFTERTRIAL'});
            end
            o.listenToEvent({'AFTEREXPERIMENT'});
            
            o.counter = o.saveAfterTrial;
            
        end
        
            
        function collectData(o,c)
            o.data = [];
            for a = 1:length(o.cic.stimuli)
               stimulus = o.cic.stimuli{a};
               o.data.(stimulus)(1,:) = o.cic.(stimulus).log.parms;
               o.data.(stimulus)(2,:) = o.cic.(stimulus).log.values;
               o.data.(stimulus)(3,:) = num2cell(o.cic.(stimulus).log.t);
            end
        end
        
        
        function saveFile(o,c)
            % Generic wrapper for file saving.
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1
                o.counter = o.saveAfterTrial;
                collectData(o,c);
                saveFile(o,c);
            else o.counter = o.counter-1;
            end
        end
        
        function afterExperiment(o,c,evt)
            collectData(o,c);
            saveFile(o,c);
        end
    
    

    end
    
end
