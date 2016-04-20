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
        log;             % Log of parameter values set in this plugin
    end
    
    properties (SetAccess=private, GetAccess=public)
        keyFunc = struct; % structure for functions assigned to keys.
        keyStrokes  = {}; % Cell array of keys that his plugin will respond to
        keyHelp     = {}; % Copy in the plugin allows easier setup of keyboard handling by stimuli and other derived classes.
        evts        = {}; % Events that this plugin will respond to.
    end
    
    properties (Access = private)
        propertyValues; % Internal storage for the current values of the parameters of stimuli/plugins. 
    end
    
    methods (Access=public)
        function o=plugin(c,n)
            % Create a named plugin
            if ~isvarname(n)
                error('Stimulus and plugin names must be valid Matlab variable names');
            end
            o.name = n;
            % Initialize an empty log.
            o.log(1).parms  = {};
            o.log(1).values = {};
            o.log(1).t =[];
            if~isempty(c) % Need this to construct cic itself...dcopy
                c.add(o);
            end
        end
        
        function s= duplicate(o,name)
            % This copies the plugin and gives it a new name. See
            % plugin.copyElement
            s=copyElement(o,name);
        end
        
        
        function keyboard(o,key,time)
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
        
        function write(o,name,value)
            % User callable write function.
            o.addToLog(name,value);
        end
        
        % Convenience wrapper; just passed to CIC
        function nextTrial(o)
            % Move to the next trial
            nextTrial(o.cic);
        end
        
        %% GUI Functions
        function writeToFeed(o,message)
            o.cic.writeToFeed(horzcat(o.name, ': ', message));
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
            % b=copy(a)
            % This will make a copy (with separate properties) of a in b.
            % This in contrast to b=a, which only copies the handle (so essentialy b==a).
            
            % First a shallow copy of fixed properties
            s = copyElement@matlab.mixin.Copyable(o);
            
            % Then setup the dynamic props again.
            dynProps = setdiff(properties(o),properties(s));
            s.name=name;
            for p=1:numel(dynProps)
                pName = dynProps{p};
                %TODO: postprocess/validate/set/get access
                s.addProperty(pName,o.(pName));
            end
            o.cic.add(s);
        end
        
        
        
        % Add properties that will be time-logged automatically, and that
        % can be validated, and postprocessed after being set.
        % These properties can also be assigned a function to dynamically
        % link properties of one object to another. (g.X='@g.Y+5')
        function addProperty(o,prop,value,varargin)
            p=inputParser;
            p.addParameter('postprocess',[]);
            p.addParameter('validate',[]);
            p.addParameter('SetAccess','public');
            p.addParameter('GetAccess','public');
            p.addParameter('thisIsAnUpdate',false,@islogical);
            p.parse(varargin{:});
            
            
            % First check if it is already there.
            h =findprop(o,prop); 
            if p.Results.thisIsAnUpdate
                if isempty(h)
                    error([prop ' is not a property of ' o.name '. (Use addProperty to add new properties) ']);
                end
            else
                if ~isempty(h)
                    error([prop ' is already a property of ' o.name '. (Use updateProperty if you want to change postprocessing or validation)']);
                end
                % Add the property as a dynamicprop (this allows users to write
                % things like o.X = 10;
                h = o.addprop(prop);
            end
            
            % Behind the scenes we have special handlers that control
            % setting values
            h.SetMethod  = @(obj,value) setProperty(obj,value,prop,p.Results.postprocess,p.Results.validate);
            % and getting values.
            h.GetMethod = @(obj) getProperty(obj,prop,[]);
            o.(prop) = value; % Set the value, this will call the SetMethod now.
            h.GetAccess= p.Results.GetAccess;
            h.SetAccess= 'public'; p.Results.SetAccess; % Restric access if requested. (e.g. limit users from writing to cic.frameDrop)
        end
        
        
        % For properties that have been added already, you cannot call addProperty again
        % (to prevent duplication and enforce name space consistency)
        % But the user may want to add a postprocessor to a built in property like
        % X. This function allows that.
        function updateProperty(o,prop,value,varargin)
            addProperty(o,prop,value,varargin{:},'thisIsAnUpdate',true);
        end
        
       
        % Log the parameter setting and postprocess it if requested in the call
        % to addProperty.
        function setProperty(o,value,prop,postprocess,validate)
            %if this is a function, add a listener
            if strncmpi(value,'@',1)
                fun = neurostim.utils.str2fun(value);
                % Assign the  function to be the PreGet function; it will be
                % called everytime a client requests the value of this
                % property.
                h= findprop(o,prop);
                h.GetMethod = @(obj) getProperty(obj,prop,fun);
                value =fun;
                if isempty(o.cic) || o.cic.stage <= o.cic.SETUP
                    % Validation and postprocessing doesn't necessarily
                    % work yet because not all objects that this property
                    % depends on have been setup.
                    validate = '';
                    postprocess = '';
                end
            end
            
            if  nargin >=5 && ~isempty(validate)
                success = validate(value);
                if ~success
                    error(['Setting ' prop ' failed validation ' func2str(validate)]);
                end
            end
            
            if nargin>=4 && ~isempty(postprocess)
                % This re-sets the value to something else.
                value  = postprocess(o,value);
            end
            o.propertyValues.(prop) = value; % Store the value in a separate struct to avoid calling SetMethod again.
            addToLog(o,prop,value); % Log 
        end
        
        
        % Evaluate a function to get a parameter and validate it if requested in the call
        % to addProperty.
        function newValue = getProperty(o,prop,fun)
            if isempty(fun)
                newValue = o.propertyValues.(prop);
            elseif ~isempty(o.cic) && o.cic.stage >o.cic.SETUP
                oldValue = o.propertyValues.(prop);
                newValue=fun(o);
                % Check if changed, assign and log if needed.
                if ~isequal(newValue,oldValue) || (ischar(newValue) && ~(strcmp(oldValue,newValue))) || (ischar(oldValue)) && ~ischar(newValue)...
                        || (~isempty(newValue) && isnumeric(newValue) && (isempty(oldValue) || all(oldValue ~= newValue))) || (isempty(newValue) && ~isempty(oldValue))
                    o.(prop) = newValue; % This calls SetMethod and stores,validates, postprocesses, and logs the new value
                end
            else
                % Not all objects have been setup so function may not work
                % yet. Evaluate to NaN for now; validation is disabled for
                % now.
                newValue = NaN;
            end            
        end
        
        
        % Log name/value pairs in a simple growing struct.
        % TODO: improve performance by block allocating space and keeping a
        % counter.
        function addToLog(o,name,value)
            o.log.parms{end+1}  = name;
            o.log.values{end+1} = value;
            if isempty(o.cic)
                o.log.t(end+1)       = -Inf;
            else
                o.log.t(end+1)      = o.cic.clockTime;
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
        
        
        function listenToEvent(o,evts)
            % Add  an event that this plugin will respond to. Note that the
            % user must implement the events function to do the work
            % Checks to make sure function is called in constructor.
            callStack = dbstack;
            tmp=strsplit(callStack(2).name,'.');
            if ~strcmp(tmp{1},tmp{2}) && ~strcmpi(tmp{2},'addScript')
                error('Cannot create event listener outside constructor.')
            else
                if ischar(evts);evts= {evts};end
                if isempty(evts)
                    o.evts = {};
                else
                    o.evts = union(o.evts,evts)';    %Only adds if not already listed.
                end
            end
        end
        
    end
    
    
    methods (Access = public)
        
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