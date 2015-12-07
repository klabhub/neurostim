classdef output < neurostim.plugin
    % Simple output subclass which can be used to save files in a specific
    % format to the specified directory.
    % Variables:
    % root  - root of the directory tree to save files to.
    % saveFrequency - save after every X trials. 0 indicates no saving
    % until the end of the experiment.
    % mode = 'root' to simply save in the root directory 
    %        'dayfolders' - create folders in the yyyy/mm/dd format and
    %        save files in the deepest level.
    %
    
    properties (GetAccess=public, SetAccess=public)
        root='c:\temp\';
        mode@char   = 'DAYFOLDERS';
        saveFrequency = Inf;        
    end
    
    properties (GetAccess=public, SetAccess=protected);
        counter = Inf;
        data = struct;
        filename;
        dumpNum = -1;
        dumpLabel = '';
        variableSize = struct;
        m;
        last = 0;
        allSaveLogs=[];
        firstSave=true;
    end
    
    
    properties (Dependent)
        dumpFilename
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
            o.listenToEvent({'AFTERTRIAL','AFTEREXPERIMENT','BEFOREEXPERIMENT'});            
%             o.listenToEvent({'BASEAFTEREXPERIMENT'});          
        end
        
        function saveData(o,stimName,thisLog,varargin)
            % function saveData(o,stimName,thisLog, [,startAt])
            % saves parameters into o.data.(dumpLabel).events.(stimName)
            % data from thisLog.parms/values/t (startAt:end)
           if nargin==4
               startAt=varargin{1};
           else
               startAt=1;
           end
           
           o.data.events.(stimName)(1,:)=thisLog.parms(startAt:end);
           o.data.events.(stimName)(2,:)=thisLog.values(startAt:end);
           o.data.events.(stimName)(3,:)=num2cell(thisLog.t(startAt:end));
        end
        
            
        function collectData(o,c)

            if o.last == 1 || o.dumpNum==0  % if the file desn't exist or it is an afterExperiment save               
                saveVariables = {'screen','subjectNr','paradigm',...
                    'nrStimuli','nrConditions','nrTrials',...
                    'fullFile','subject','blocks','responseKeys','trial','condition','block',...
                    'startTime','stopTime','trialStartTime','trialEndTime', 'pluginOrder','profile','conditions'};
            else %if we are just appending data
                saveVariables = {'trial','condition','block','trialStartTime','trialEndTime'};
            end
                if isempty(o.allSaveLogs)
                    o.allSaveLogs=[c.stimuli c.plugins 'cic']; %combine all stimuli and plugins to save
                    nolog=c.pluginsByClass('neurostim.plugins.output');
                    for a=1:max(size(nolog))
                        o.allSaveLogs(strcmpi(o.allSaveLogs,nolog{a}.name))=[];
                    end
                end
                
                for a = 1:numel(o.allSaveLogs) % runs through and saves all stimuli and plugins
                    thisPlg = o.allSaveLogs{a};
                    if strcmp(thisPlg,'cic')
                        thisLog = c.log;
                    else
                        thisLog = c.(thisPlg).log;
                    end
                    if ~isempty(thisLog.parms) %if there are logs to save
                        if ~o.last && isfield(o.variableSize,thisPlg)
                            o.saveData(thisPlg,thisLog,o.variableSize.(thisPlg)+1);
                        else
                            o.saveData(thisPlg,thisLog);
                        end
                        o.variableSize.(thisPlg) = size(thisLog.parms,2);
                    end
                end
                
                for var = saveVariables % saves all requested variables to o.data
                    o.data.(var{1}) = c.(var{1});
                end
        end
                
        function saveFileBase(o,c)
            % Save output to disk.
            o.dumpNum = o.dumpNum+1;
            o.dumpLabel = horzcat('save',num2str(o.dumpNum));
            try
                collectData(o,c);
                saveFile(o,c);
                success = 1;
            catch
                success = 0;
                try
                    warning('There was a problem saving to disk. Attempting save to c:\temp');
                    [~, fname,ext] = fileparts(o.filename);
                    save(['c:\temp\' fname,ext],'c', '-mat');
                    warning('There was a problem saving to disk. Attempting save to c:\temp.... success');
                catch
                    warning('There was a problem saving to disk. Failed. Halting execution to allow manual recovery');
                    %sca; Maybe add this here?
                    keyboard;
                end
            end
            
            if o.last && success
%                 Saving worked, so delete interim dumps.
                [~,b,~]=fileparts(o.dumpFilename);
                delete([b '_*']);
            end
        end
        
        function saveFile(o,c)
            %Function that should be overloaded in derived class for custom user output formats.
            
            %If we are doing interim dumps
            if ~isinf(o.counter)
                %If the dump file is not yet open
                
                %Append the current dump
                data=o.data;
                [~,filename,~]=fileparts(o.dumpFilename);
                save([filename '_' o.dumpLabel '.mat'],'data','-mat');
            end
         
            %if the last time, save the final output file
            if o.last == 1
                data = o.data;
                save(o.filename,'data','-mat');
                disp(['Saved to ' o.filename]);
            end
            o.data=struct;
        end
        
        function afterTrial(o,c,evt)
            if o.counter==1 % if save after trial is triggered
                o.counter = o.saveFrequency;   % reset counter
                saveFileBase(o,c);
            else
                o.counter = o.counter-1;   % counter reduction
            end
        end
        
        function afterExperiment(o,c,evt)
            % always save post-experiment.
            o.last = 1;
            saveFileBase(o,c);
        end
        
        function beforeExperiment(o,c,evt)
            % Always set at the start of the experiment so that we can 
            % check that we can save.
             o.setFile;
            o.counter = o.saveFrequency;  
        end  
    end
        
    methods
        function v= get.dumpFilename(o)
            [pathName, fname,ext] = fileparts(o.filename);
            v = fullfile(pathName, [fname, '_dump',ext]);
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
                    o.createDir(o.root,today);
                    f = fullfile(o.root,today,o.timeName);
                case 'ROOT'
                    % Create a timed file in the root directory
                    o.createDir(o.root);
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
            thisDir = fullfile(root,d);
            if ~exist(thisDir,'dir')
                mkdir(thisDir);
            end
            cd(thisDir);
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
