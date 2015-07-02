classdef output < neurostim.plugin
    % Simple output subclass which can be used to save files in a specific
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
        data = struct;
        filename;
        trial = [];
        variableSize = struct;
        m;
        last = 0;
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
        function o = output(name)
            o = o@neurostim.plugin('output');
             if o.saveAfterTrial > 0
                % only listen to afterTrial event if saving after trial.
                o.listenToEvent({'AFTERTRIAL'});
            end
            o.listenToEvent({'AFTEREXPERIMENT','BEFOREEXPERIMENT'});            
%             o.listenToEvent({'BASEAFTEREXPERIMENT'});
            o.counter = o.saveAfterTrial;            
        end
        
            
        function collectData(o,c)
            if ~exist(o.filename,'file') || o.last ==1  % if the file exists or it is an afterExperiment save
                if o.last == 1
                    o.trial = 'total';  % save all
                else o.trial = 0;   % save first
                end
                
                saveVariables = {'screen','subjectNr','paradigm',...
                    'iti','trialDuration','nrStimuli','nrConditions','nrTrials',...
                    'fullFile','subject','blocks','responseKeys','trial','condition','block',...
                    'startTime','stopTime','trialStartTime','trialEndTime'};
                
                for a = 1:length(c.stimuli) % runs through and saves all stimuli to o.data
                    stimulus = c.stimuli{a};
                    o.variableSize.(stimulus) = max(size(c.(stimulus).log.parms));
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(1,:) = c.(stimulus).log.parms;
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(2,:) = c.(stimulus).log.values;
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(3,:) = num2cell(c.(stimulus).log.t);
                end
                
                for a = 1:length(saveVariables) % saves all variables to o.data
                    variable = saveVariables{a};
                    o.data.(horzcat('save',num2str(o.trial))).(variable) = c.(variable);
                end
                
                for a = 1:length(c.plugins) % saves all plugins to o.data
                    plugin = c.plugins{a};
                    if ~isempty(c.(plugin).log.parms)
                        o.variableSize.(plugin) = max(size(c.(stimulus).log.parms));
                        o.data.(horzcat('save',num2str(o.trial))).plugins.(plugin)(1,:) = c.(plugin).log.parms;
                        o.data.(horzcat('save',num2str(o.trial))).plugins.(plugin)(2,:) = c.(plugin).log.values;
                        o.data.(horzcat('save',num2str(o.trial))).plugins.(plugin)(3,:) = num2cell(c.(plugin).log.t);
                    end
                end
                
            else    %append to file, just save relevant information
                saveVariables = {'trial','condition','block','trialStartTime','trialEndTime'};
                if isempty(o.trial)
                    o.trial = 1;
                else o.trial = o.trial+1;
                end
                for a = 1:length(c.stimuli)
                    stimulus = c.stimuli{a};
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(1,:) = ...
                        c.(stimulus).log.parms((o.variableSize.(stimulus)+1):end);
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(2,:) = ...
                        c.(stimulus).log.values((o.variableSize.(stimulus)+1):end);
                    o.data.(horzcat('save',num2str(o.trial))).plugins.(stimulus)(3,:) = ...
                        num2cell(c.(stimulus).log.t((o.variableSize.(stimulus)+1):end));
                    o.variableSize.(stimulus) = max(size(c.(stimulus).log.parms));
                end
                
                for a = 1:length(saveVariables)
                    variable = saveVariables{a};
                    if strcmpi(variable,'trialStartTime') || strcmpi(variable,'trialEndTime')
                        o.data.(horzcat('save',num2str(o.trial))).(variable) = c.(variable)(end);
                    end
                    o.data.(horzcat('save',num2str(o.trial))).(variable) = c.(variable);
                end
                
                for a = 1:length(c.plugins)
                    plugin = c.plugins{a};
                    if ~isempty(c.(plugin).log.parms)
                        o.data.(horzcat('save',num2str(o.trial))).(plugin)(1,:) = ...
                            c.(plugin).log.parms((o.variableSize.(plugin)+1):end);
                        o.data.(horzcat('save',num2str(o.trial))).(plugin)(2,:) = ...
                            c.(plugin).log.values((o.variableSize.(plugin)+1):end);
                        o.data.(horzcat('save',num2str(o.trial))).(plugin)(3,:) = ...
                            num2cell(c.(plugin).log.t((o.variableSize.(plugin)+1):end));
                        o.variableSize.(plugin) = max(size(c.(plugin).log.parms));
                    end
                end
            end
           
                
        end
                
        function saveFileBase(o,c)
           % Save output to disk.
           [pathName, fname,ext] = fileparts(o.filename);  
            if isempty(o.trial)
            try
                collectData(o,c);
                saveFile(o,c,0);
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
           else
               try
                   collectData(o,c);
                   saveFile(o,c,1);
                   
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
        end
        
        function saveFile(o,c,append)
                %Function that should be overloaded in derived class for custom user output formats.
             if o.last == 1
                 [pathName, fname,ext] = fileparts(o.filename);  
                 data = o.data.(horzcat('save',num2str(o.trial)));
                 save([pathName, fname, '_total.mat'],'data','-mat');
                 
             else if append
                     data = o.data.(horzcat('save',num2str(o.trial)));
                     o.m.(horzcat('save',num2str(o.trial))) = data;
                 else
                     data = o.data.save0;
                     o.m = matfile(o.filename,'Writable',true);
                     o.m.save0 = data;
                 end
             end
            
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveAfterTrial;   % reset counter
                saveFileBase(o,c);
            else
                o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment.
            o.last = 1;
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
                    neurostim.plugins.output.createDir(o.root,today);
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
        
        function sobj = saveobj(obj)
            sobj = saveobj@super(obj);
            
            
        end
    end
    
    
end
