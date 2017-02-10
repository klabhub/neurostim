classdef output < neurostim.plugin
    % Simple output subclass - saves files to a set directory.
    % Adjustable Variables:
    %   root  - root of the directory tree to save files to.
    %   saveFrequency - save after every X trials. 0 indicates no saving
    %       until the end of the experiment.
    %   mode = 'root' to simply save in the root directory 
    %          'dayfolders' - create folders in the yyyy/mm/dd format and
    %             save files in the deepest level.
    %
    
    properties (GetAccess=public, SetAccess=public)
        mode@char   = 'DAYFOLDERS';
        saveFrequency = 2;
        ext@char='.mat';
    end
    
    properties (GetAccess=public, SetAccess=protected);
        counter = Inf;   
        filename@char;
    end
        
    
    methods (Access = public)
        function o = output(c)
            o = o@neurostim.plugin(c,'output');
            o.listenToEvent({'AFTERTRIAL','AFTEREXPERIMENT','BEFOREEXPERIMENT'});            
        end
    end
    
    methods (Access=private)
        
        function save(o,c,trialNr)                         
            if nargin <3 
                % Final
                currentFile = o.filename;
                dumpClean = true;
            else                
                % Interim dumps
                [p,filename,~]=fileparts(o.filename);
                currentFile = fullfile(p,[filename '_' num2str(trialNr) o.ext]);
                dumpClean = false;
            end
            
            try
                save(currentFile,'c','-mat');           
            catch
                try
                    warning('There was a problem saving to disk. Attempting save to c:\temp');
                    [~, fname,xt] = fileparts(o.filename);
                    save(['c:\temp\' fname,xt],'c', '-mat');
                    warning('Save to c:\temp.... success');
                catch
                    warning('There was a problem saving to disk. Failed. Halting execution to allow manual recovery');
                    sca;
                    keyboard;
                end
            end
            
            % Remove intermediate dumps
            if dumpClean
                [p,f,~]=fileparts(o.filename);
                dumpFiles = fullfile(p,[f  '_*'  o.ext]);
                delete(dumpFiles);
            end
            
        end
        
    end
    
    methods (Access=public)
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveFrequency;   % reset counter
                save(o,c,c.trial);
            else
                o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment. 
            for a = 1:numel(c.pluginOrder)
                o = c.(c.pluginOrder{a});
                if ~isempty(o.prms)
                    structfun(@pruneLog,o.prms); 
                end
            end         
            save(o,c);
        end
        
        function beforeExperiment(o,c,evt)
            % Always set at the start of the experiment so that we can 
            % check that we can save.
            o.setFile;
            o.counter = o.saveFrequency;             
        end  
    end
    
        
    methods (Access = protected)
        function setFile(o)
            % Set the file name based on the mode and the current time.
            % Create a year/month/day structure and create a file
            % named after the current time.
            % e.g. root/2015/06/13/150523.mat for an experiment
            % that started at 3:05 PM on June 13th, 2015.
            root=fileparts(o.cic.fullFile);
            o.createDir(root,'');
            f = [o.cic.fullFile o.ext];
            if exist(f,'file')
                error(['This file ' f ' already exists?']);
            else
                o.filename =f;
                test= 'test file created to check that we can save';
                try
                    save(f,'test')
                catch me
                    disp(['Failed to create an output file: ' f])
                    rethrow(me)
                end
                delete(f);% Remove the test file.
            end
        end
    end
    
    
    
    methods (Static)
        
        function createDir(root,d)
            thisDir = fullfile(root,d);
            if ~exist(thisDir,'dir')
                mkdir(thisDir);
            end
        end
        
        
    end
    
    
end
