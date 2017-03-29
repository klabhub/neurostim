classdef plugin  < dynamicprops & matlab.mixin.Copyable
    % Base class for plugins. Includes logging, functions, etc.
    %
    properties (SetAccess=public)
        cic;  % Pointer to CIC
    end
    
    events
        BEFOREFRAME;
        AFTERFRAME;
        BEFORETRIAL;
        AFTERTRIAL;
        BEFOREEXPERIMENT;
        AFTEREXPERIMENT;
    end
    
    properties (SetAccess=private, GetAccess=public)
        name@char= '';   % Name of the plugin; used to refer to it within cic
        prms;          % Structure to store all parameters
    end
    
    properties (SetAccess=private, GetAccess=public)
        keyFunc = struct; % structure for functions assigned to keys.
        keyStrokes  = {}; % Cell array of keys that his plugin will respond to
        keyHelp     = {}; % Copy in the plugin allows easier setup of keyboard handling by stimuli and other derived classes.
        evts        = {}; % Events that this plugin will respond to.
    end
    
    properties (Access = private)
        
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
        
        
        function keyboard(o,key,time) %#ok<INUSD>
            % Generic keyboard handler; when keys are added using keyFun,
            % this evaluates the function attached.
            if any(strcmpi(key,fieldnames(o.keyFunc)))
                o.keyFunc.(key)(o,key);
            end
        end
        
        
        function success=addKey(o,key,fnHandle,varargin)
            % addKey(key, fnHandle [,keyHelp])
            % Runs a function in response to a specific key press.
            % key - a single key (string)
            % fnHandle - function handle of function to run.
            % Function must be of the format @fn(o,key).
            if nargin < 4
                keyhelp = func2str(fnHandle);
            else
                keyhelp = varargin{1};
            end
            o.listenToKeyStroke(key,keyhelp);
            o.keyFunc.(key) = fnHandle;
            success=true;
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
    
    % Convenience wrapper functions to pass the buck to CIC
    methods (Sealed)
        
        function listenToKeyStroke(o,keys,keyHelp)
            % listenToKeyStroke(o,keys,keyHelp)
            % keys - string or cell array of strings corresponding to keys
            % keyHelp - string or cell array of strings corresponding to key array,
            % defining a help function for that key.
            %
            % Adds an array of keys that this plugin will respond to. Note that the
            % user must implement the keyboard function to do the work. The
            % keyHelp is a short string that can help the GUI user to
            % understand what the key does.
            if ischar(keys), keys = {keys};end
            if exist('keyHelp','var')
                if ischar(keyHelp), keyHelp = {keyHelp};end
            end
            
            if nargin<3 % if keyHelp is empty
                keyHelp = cell(1,length(keys));
                [keyHelp{:}] = deal('?');
            else
                if length(keys) ~= length(keyHelp)
                    error('Number of KeyHelp strings not equal to number of keys.')
                end
                
            end
            
            if any(size(o.cic)) || strcmpi(o.name,'cic')
                if strcmpi(o.name,'cic')
                    cicref=o;
                else
                    cicref=o.cic;
                end
                % Pass the information to CIC which keeps track of
                % keystrokes
                for a = 1:numel(keys)
                    addKeyStroke(cicref,keys{a},keyHelp{a},o);
                end
                KbQueueCreate(cicref);
                KbQueueStart(cicref);
            end
            
            
            if ~isempty(keys)
                o.keyStrokes= cat(2,o.keyStrokes,keys);
                o.keyHelp= cat(2,o.keyHelp,keyHelp);
            end
        end
        
        
        function ignoreKeyStroke(o,keys)
            % ignoreKeyStroke(o,keys)
            % An array of keys that this plugin will stop responding
            % to. These keys must have been added in listenToKeyStroke
            % previously.
            removeKeyStrokes(o.cic,keys);
            o.keyStrokes = o.keyStrokes(~ismember(o.keyStrokes,keys));
            o.keyHelp = o.keyHelp(~ismember(o.keyStrokes,keys));
            KbQueueCreate(o.cic);
            KbQueueStart(o.cic);
        end
        
        
        function listenToEvent(o,varargin)
            % Add  an event that this plugin will respond to. Note that the
            % user must implement the events function to do the work
            % Checks to make sure function is called in constructor.
            callStack = dbstack;
            tmp=strsplit(callStack(2).name,'.');
            if ~strcmp(tmp{1},tmp{2}) && ~strcmpi(tmp{2},'addScript')
                error('Cannot create event listener outside constructor.')
            else
                if numel(varargin)==0 || (numel(varargin)==1 && isempty(varargin{1}))
                    o.evts = {};
                else
                    o.evts = union(o.evts,varargin)';    %Only adds if not already listed.
                end
            end
        end
        
    end
    
    
    methods (Access = public)
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setCurrentParmsToDefault(o)
            if ~isempty(o.prms) 
                structfun(@setCurrentToDefault,o.prms);
            end
        end

                % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setDefaultParmsToCurrent(o)
            if ~isempty(o.prms) 
                structfun(@setDefaultToCurrent,o.prms);
            end
        end

        
        function baseEvents(o,c,evt)
            if c.PROFILE;ticTime = c.clockTime;end
            
            switch evt.EventName
                case 'BASEBEFOREEXPERIMENT'
                     notify(o,'BEFOREEXPERIMENT');
                    
                case 'BASEBEFORETRIAL'
                    notify(o,'BEFORETRIAL');
                    if c.PROFILE; c.addProfile('BEFORETRIAL',o.name,c.clockTime-ticTime);end;
                    
                case 'BASEBEFOREFRAME'
                    if strcmp(o.name,'gui')
                        if mod(c.frame,c.guiFlipEvery)>0
                            return;
                        end
                    end
                    if c.clockTime-c.frameStart>(1000/c.screen.frameRate - c.requiredSlack)
                        c.writeToFeed(['Did not run ' o.name ' beforeFrame in frame ' num2str(c.frame) '.']);
                        return;
                    end
                    notify(o,'BEFOREFRAME');
                    if c.PROFILE; c.addProfile('BEFOREFRAME',o.name,c.clockTime-ticTime);end;
                    
                case 'BASEAFTERFRAME'
                    if strcmp(o.name,'gui')
                        if mod(c.frame,c.guiFlipEvery)>0
                            return;
                        end
                    end
                    if c.requiredSlack ~= 0
                        if c.frame ~=1 && c.clockTime-c.frameStart>(1000/c.screen.frameRate - c.requiredSlack)
                            c.writeToFeed(['Did not run ' o.name ' afterFrame in frame ' num2str(c.frame) '.']);
                            return;
                        end
                    end
                    notify(o,'AFTERFRAME');
                    if c.PROFILE; c.addProfile('AFTERFRAME',o.name,c.clockTime-ticTime);end;
                    
                case 'BASEAFTERTRIAL'
                    notify(o,'AFTERTRIAL');
                    if (c.PROFILE); addProfile(c,'AFTERTRIAL',o.name,c.clockTime-ticTime);end;
                case 'BASEAFTEREXPERIMENT'
                    notify(o,'AFTEREXPERIMENT');
            end
        end
    end
end