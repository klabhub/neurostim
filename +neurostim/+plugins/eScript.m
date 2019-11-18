classdef eScript < neurostim.plugin
    % Class for writing simple functions/scripts.
    % This class provide a way to allow users to write simple
    % functions/scripts for behavior and stimulus control in an experiment
    % (Without the need for writing a class).
    % Users do not need to create this class specifically. Instead they
    % should just call the addScript member function of cic. See
    % demos/scripting.m for an example
    
    properties (SetAccess=protected)
        % Internal storage of the user-written functions
        beforeFrameFun@function_handle;
        afterFrameFun@function_handle;
        beforeTrialFun@function_handle;
        afterTrialFun@function_handle;
        beforeExperimentFun@function_handle;
        afterExperimentFun@function_handle;
        keyFun@function_handle;
    end
    
    
    methods
        
        % Empty constructor
        function o = eScript(c)
            o = o@neurostim.plugin(c,'eScript');
            o.addProperty('mcode','');
        end
        
        function disp(o)
            % Simple display of currently loaded handlers.
            disp('****************************************')
            disp('Script handling plugin with handlers for:')
            if ~isempty(o.beforeFrameFun)
                disp(['BeforeFrame: ' func2str(o.beforeFrameFun)]);
            end
            if ~isempty(o.afterFrameFun)
                disp(['AfterFrame: ' func2str(o.afterFrameFun)]);
            end
            if ~isempty(o.beforeTrialFun)
                disp(['BeforeTrial: ' func2str(o.beforeTrialFun)]);
            end
            if ~isempty(o.afterTrialFun)
                disp(['AfterTrial: ' func2str(o.afterTrialFun)]);
            end
            if ~isempty(o.keyFun)
                disp(['Keyboard: ' func2str(o.keyFun)]);
            end
            if ~isempty(o.beforeExperimentFun)
                disp(['BeforeExperiment: ' func2str(o.beforeExperimentFun)]);
            end
            if ~isempty(o.afterExperimentFun)
                disp(['AfterExperiment: ' func2str(o.afterExperimentFun)]);
            end
            disp('****************************************')
            
        end
        
        function addScript(o,when,fun,keys)
            % Add a script to a particular phase
            % when = event (BeforeFrame, AfterFrame, BeforeTrial, AfterTrial)
            % fun = function that takes a single input argument (cic)
           
%             funcName = func2str(fun);
%             
%             [f] = strsplit(funcName,'/'); % For subfunctions, need to get the parent file (f{1}).      
%             mfile =which(f{1});            
%             if ~exist(mfile,'file')
%                 error(['The mfile of your eScript ' mfile ' could not be found .']);
%             end
            
            switch upper(when)
                case 'BEFOREFRAME'
                    o.beforeFrameFun        = fun;
                case 'AFTERFRAME'
                    o.afterFrameFun         = fun;
                case 'BEFORETRIAL'
                    o.beforeTrialFun        = fun;
                case 'AFTERTRIAL'
                    o.afterTrialFun         = fun;
                case 'BEFOREEXPERIMENT'
                    o.beforeExperimentFun   = fun;
                case 'AFTEREXPERIMENT'
                    o.afterExperimentFun    = fun;
                case 'KEYBOARD'
                    o.keyFun                = fun;
                otherwise
                    error(['The eScript plugin does not handle ' when ' events.']);
            end
            
            if strcmpi(when,'KEYBOARD')
                o.addKey(keys)
            end
            
            %% Because the script is not logged automatically, we store
            % the entire script here as a way to work out what happened
            % after the fact (more like disaster recovery)
            
            % Read the contents of the mfile. 'type' does not work for this
            % (no output arguments);
%             fid = fopen(mfile);
%             txt = [when ' : ' funcName ' : ' mfile ]; % Start the log with the relevant event and name of the mfile.
%             while (fid~=-1)
%                 tmp = fgets(fid);
%                 if tmp==-1;
%                     break;
%                 else
%                     txt =char(txt,tmp);
%                 end
%             end
%             fclose(fid);
%             
%             % Store the mfile contents in the log.
%             o.mcode = txt;
        end
        
        %% Member functions that simply call the functions that the user
        % has provided. If the function handles have not been provided, the
        % eScript plugin will not be listening to these events so these
        % members will never be called.
        function beforeFrame(o)
            if ~isempty(o.beforeFrameFun)
                o.beforeFrameFun(o.cic);
            end
        end
        function afterFrame(o)
            if ~isempty(o.afterFrameFun)
                o.afterFrameFun(o.cic);
            end
        end
        function beforeTrial(o)
            if ~isempty(o.beforeTrialFun)
                o.beforeTrialFun(o.cic);
            end
        end
        function afterTrial(o)
            if ~isempty(o.afterTrialFun)           
                o.afterTrialFun(o.cic);
            end
        end
        function beforeExperiment(o)
            if ~isempty(o.beforeExperimentFun)           
                o.beforeExperimentFun(o.cic);
            end
        end
        function afterExperiment(o)
            if ~isempty(o.afterExperimentFun)
                o.afterExperimentFun(o.cic);
            end
        end
        function keyboard(o,key,time)
            if ~isempty(o.keyFun)
               o.keyFun(o,key,time);
            end
        end
        
    end
end