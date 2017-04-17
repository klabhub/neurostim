classdef plugin  < dynamicprops & matlab.mixin.Copyable & matlab.mixin.Heterogeneous
    % Base class for plugins. Includes logging, functions, etc.
    %
    properties (SetAccess=public)
        cic;  % Pointer to CIC
    end
    
    
    properties (SetAccess=private, GetAccess=public)
        name@char= '';   % Name of the plugin; used to refer to it within cic
        prms;          % Structure to store all parameters                
    end
    
    methods (Access=public)
        function o=plugin(c,n)
            % Create a named plugin
            if ~isvarname(n)
                error('Stimulus and plugin names must be valid Matlab variable names');
            end
            o.name = n;
            
            if~isempty(c) % Need this to construct cic itself...dcopy
                c.add(o);
            end
        end
        
        
        function s= duplicate(o,name)
            % This copies the plugin and gives it a new name. See
            % plugin.copyElement
            s=copyElement(o,name);
            % Add the duplicate to cic.
            o.cic.add(s);
        end
                       
        
        function addKey(o,key,keyHelp)
            % addKey(key, fnHandle [,keyHelp])
            % Runs a function in response to a specific key press.
            % key - a single key (string)
            % handler - function handle of function to run.
            % Function must be of the format @fn(o,key).
            if nargin < 4
                keyHelp = '?';           
            end
            addKeyStroke(o.cic,key,keyHelp,o);
        end
        
        % Convenience wrapper; just passed to CIC
        function endTrial(o)
            % Move to the next trial
            endTrial(o.cic);
        end
        
        %% GUI Functions
        function writeToFeed(o,message)
            o.cic.writeToFeed(horzcat(o.name, ': ', message));
        end
        
        % Needed by str2fun
        function ok = setProperty(o,prop,value)
            o.(prop) =value;
            ok = true;
        end
        
        % Add properties that will be time-logged automatically, and that
        % can be validated after being set.
        % These properties can also be assigned a function to dynamically
        % link properties of one object to another. (g.X='@g.Y+5')
        function addProperty(o,prop,value,varargin)
            p=inputParser;
            p.addParameter('validate',[]);
            p.addParameter('SetAccess','public');
            p.addParameter('GetAccess','public');
            p.addParameter('noLog',false,@islogical);
            p.parse(varargin{:});
            
            
            if isempty(prop) && isstruct(value)
                % Special case to add a whole struct as properties (see
                % Jitter for usage example)
                fn = fieldnames(value);
                for i=1:numel(fn)
                    addProperty(o,fn{i},value.(fn{i}),varargin{:});
                end
            else
                % First check if it is already there.
                h =findprop(o,prop);
                if ~isempty(h)
                    error([prop ' is already a property of ' o.name ]);
                end
                
                % Add the property as a dynamicprop (this allows users to write
                % things like o.X = 10;
                h = o.addprop(prop);
                % Create a parameter object to do the work behind the scenes.
                % The parameter constructor adds a callback function that
                % will log changes and return correct values
                o.prms.(prop) = neurostim.parameter(o,prop,value,h,p.Results);
            end
        end
        
        function duplicateProperty(o,parm)
            % First check if it is already there.
            h =findprop(o,parm.name);
            if ~isempty(h)
                error([parm.name ' is already a property of ' o.name ]);
            end
            h= o.addprop(parm.name);
            o.prms.(parm.name) = duplicate(parm,o,h);
        end
        
    end
    
    
    % Only the (derived) class designer should have access to these
    % methods.
    methods (Access = protected, Sealed)
        function s= copyElement(o,name)
            % This protected function is called from the public (sealed)
            % copy member of matlab.mixin.Copyable. We overload it here to
            % copy not just the static properties but also the
            % dynamicprops.
            %
            % Example:
            % b=copyElement(a)
            % This will make a copy (with separate properties) of a in b.
            % This in contrast to b=a, which only copies the handle (so essentialy b==a).
            
            % First a shallow copy of fixed properties
            s = copyElement@matlab.mixin.Copyable(o);
            s.prms = []; % Remove parameter objects; new ones will be created for the
            % duplicate plugin
            % Then setup the dynamic props again. (We assume all remaining
            % dynprops are parameters of the stimulus/plugin)
            dynProps = setdiff(properties(o),properties(s));
            s.name=name;
            for p=1:numel(dynProps)
                pName = dynProps{p};
                duplicateProperty(s,o.prms.(pName));
            end
        end
        
    end
    
  
    
    methods (Access = public)
        
        function baseBeforeExperiment(o)            
            beforeExperiment(o);
        end
        function baseBeforeTrial(o)            
            beforeTrial(o);
        end
        function baseBeforeFrame(o)
%             if o.cic.clockTime-o.cic.frameStart>(1000/o.cic.screen.frameRate - o.cic.requiredSlack)
%                          o.cic.writeToFeed(['Did not run plugin ' o.name ' beforeFrame in frame ' num2str(o.cic.frame) '.']);
%                          return;
%             end
            beforeFrame(o);
        end
        function baseAfterFrame(o)            
            afterFrame(o);
        end
        
        function baseAfterTrial(o)
            afterTrial(o);
        end
        
        function baseAfterExperiment(o)
            afterExperiment(o);
        end
        
        function beforeExperiment(~)
            %NOP
        end
        function beforeTrial(~)
            %NOP
        end
        function beforeFrame(~)
            %NOP
        end
        function afterFrame(~)
            %NOP
        end
        
        function afterTrial(~)
            %NOP
        end
        
        function afterExperiment(~)
            %NOP
        end
        
    end
    
    methods (Sealed)
        % These methods are sealed to allow the use of a heterogeneous
        % array of plugins/stimuli
        function v = eq(a,b)
            v = eq@handle(a,b);
        end
        
        function base(oList,what,c)
            
            switch (what)
                case neurostim.stages.BEFOREEXPERIMENT                   
                    for o=oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseBeforeExperiment(o);                         
                         if c.PROFILE; addProfile(c,'BEFOREEXPERIMENT',o.name,c.clockTime-ticTime);end;
                    end
                    % All plugins BEFOREEXPERIMENT functions have been processed,
                    % store the current parameter values as the defaults.
                    setCurrentParmsToDefault(oList);
                case neurostim.stages.BEFORETRIAL
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseBeforeTrial(o);                       
                        if c.PROFILE; addProfile(c,'BEFORETRIAL',o.name,c.clockTime-ticTime);end;
                    end
                case neurostim.stages.BEFOREFRAME
                     Screen('glLoadIdentity', c.window);
                     Screen('glTranslate', c.window,c.screen.xpixels/2,c.screen.ypixels/2);
                     Screen('glScale', c.window,c.screen.xpixels/c.screen.width, -c.screen.ypixels/c.screen.height);           
                     for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        Screen('glPushMatrix',c.window);                                             
                        baseBeforeFrame(o); % If appropriate this will call beforeFrame in the derived class                       
                        Screen('glPopMatrix',c.window);                                                                     
                        if c.PROFILE; addProfile(c,'BEFOREFRAME',o.name,c.clockTime-ticTime);end;
                    end
                case neurostim.stages.AFTERFRAME      
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterFrame(o);                                            
                        if c.PROFILE; addProfile(c,'AFTERFRAME',o.name,c.clockTime-ticTime);end;
                    end
                case neurostim.stages.AFTERTRIAL                    
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterTrial(o);                        
                        if c.PROFILE; addProfile(c,'AFTERTRIAL',o.name,c.clockTime-ticTime);end;
                    end
                case neurostim.stages.AFTEREXPERIMENT
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterExperiment(o);                       
                        if c.PROFILE; addProfile(c,'AFTEREXPERIMENT',o.name,c.clockTime-ticTime);end;
                    end
                otherwise
                    error('?');
            end
        end
        
        
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setCurrentParmsToDefault(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setCurrentToDefault,o.prms);
                end
            end
        end
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setDefaultParmsToCurrent(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setDefaultToCurrent,o.prms);
                end
            end
        end
        
        function pruneLog(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@pruneLog,o.prms);
                end
            end
            
        end
    end
    
end