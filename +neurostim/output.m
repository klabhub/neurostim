classdef output < neurostim.plugin
    % Simple output class which can be used to save files in a specific
    % format to the specified directory.
    % Variables:
    % root  - root of the directory tree to save files to.
    % saveAfterTrial - save after every X trials. 0 indicates no saving
    % until the end of the experiment.
    % mode = 'root' to simply save in the root directory 
    %        'dayfolders' - create folders in the yyyy/mm/dd format and
    %        save files in the deepest level.
    %
    
    properties (GetAccess=public, SetAccess=public)
        root=pwd;
        mode@char   = 'DAYFOLDERS';
        saveAfterTrial = 0;        
    end
    
    properties (GetAccess=public, SetAccess=protected);
        counter;
        data;
        filename;
    end
    
    
    methods
        function set.root(o,v)
            if ~exist(v,'dir')
                error('The root output directory does not exist. Please create it first');
            end
            o.root = v;
        end
    end
    
    methods (Access = public)
        function o = output
            o = o@neurostim.plugin('output');
            if o.saveAfterTrial > 0
                % only listen to afterTrial event if saving after trial.
                o.listenToEvent({'AFTERTRIAL'});
            end
            o.listenToEvent({'AFTEREXPERIMENT','BEFOREEXPERIMENT'});            
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
        
        
        function saveFile(o,c)
            % Generic wrapper for file saving.
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveAfterTrial;   % reset counter
                collectData(o,c);   % run data collection and file saving
                saveFile(o,c);
            else o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment.
            collectData(o,c);
            saveFile(o,c);
        end
        
        
        function beforeExperiment(o,c,evt)
            % Always set at the start of the experiment so that we can 
            % check that we can save.
            o.setFile;
        end
        
        
        function f = setFile(o)
            % Set the file name based on the mode and the current time.
            
            switch (o.mode)
                case 'DAYFOLDERS'
                    % Create a year/month/day structure and create a file
                    % named after the current time.
                    % e.g. root/2015/06/13/150523.mat for an experiment
                    % that started at 3:05 PM on June 13th, 2015.
                    today = fullfile(datestr(now,'yyyy'),datestr(now,'mm'),datestr(now,'dd'));
                    neurostim.output.createDir(o.root,today);
                    f = fullfile(o.root,today,o.timeName);
                case 'ROOT'
                    % Create a timed file in the root directory
                    neurostim.output.createDir(o.root);
                    f = fullfile(o.root,o.timeName);
            end
            if exist(f,'file')
                error(['This file ' f ' already exists?']);
            else
                o.filename =f;
                %Sometimes may even want to create an (empty) file
            end
        end                
    end
    
    
    methods (Access= protected)
        
    end
    
    
    methods (Static)
        
        function createDir(root,d)
            % Recursively create the requested directory
            here =pwd;
            cd (root);
            dirs = strsplit(d,filesep);
            for i=1:numel(dirs)
                if ~exist(dirs{i},'dir')
                    [ok, msg]= mkdir(dirs{i});
                else 
                    ok = true;
                end
                if (ok)
                    cd (dirs{i});
                else
                    error(msg);
                end                
            end
            cd(here);
        end
        
        function f= timeName()
            % Create a file named after the current time (quasi-unique)
            f= [datestr(now,'HHMMSS') '.mat'];
        end
    end
    
    
end
