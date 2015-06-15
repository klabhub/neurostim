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
        root='c:\temp\';
        mode@char   = 'DAYFOLDERS';
        saveAfterTrial = 0;        
    end
    
    properties (GetAccess=public, SetAccess=protected);
        counter;
        data;
        filename;
    end
    
    
    properties (Dependent)
        fullFile;       % Output file name including path
        path;
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
                
        function saveFileBase(o,c)
           % Save output to disk.
            [pathName, fname,ext] = fileparts(o.filename);  
            try
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
            save(o.filename,'c', '-mat');
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveAfterTrial;   % reset counter
                collectData(o,c);   % run data collection and file saving
                saveFileBase(o,c);
            else
                o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment.
            collectData(o,c);
            saveFileBase(o,c);
            disp(['Saved to ' o.filename]);
        end
        
        function beforeExperiment(o,c,evt)
            % Always set at the start of the experiment so that we can 
            % check that we can save.
            o.setFile;
        end  
    end
        
      
        
     methods (Access = protected)   
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
