classdef plugin  < dynamicprops & matlab.mixin.Copyable
    % Base class for plugins. Includes logging, functions, etc.
    %
    % Issue: In setupFunction()
    %   While functions will work for assigning one-level structure references,
    %   i.e. fixation.diode.color = '@(cic) cic.screen.color.text'
    %   there may be timing problems if there are multiple one-level
    %   references to the same structure, as functions within the structure
    %   will be evaluated every time the structure is called.
    %   Multiple-level structure references are also currently not supported
    %   for assignation.
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
        listenerHandle = struct;
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
        
        function ok = setProperty(o,prop,value)            
            o.(prop) =value;
            ok = true;
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
                s.addProperty(pName,o.(pName)); 
                % Because the dynprops are added to the copy here, their PostSet and PreGet listeners are setup appropriately.
            end
            o.cic.add(s);
        end
        
        % Define a property as a function of some other property.
        % This function is called at the initial logParmSet of a parameter.
        % funcstring is the function definition. It is a string which
        % references a stimulus/plugin by its assigned name and reuses that 
        % property name if it uses an object/variable of that property. e.g. 
        % dots.size='@ sin(cic.frame)' or
        % fixation.X='@ dots.X + 1' or
        % fixation.color='@ cic.screen.color.background'
        % % The @ sign should be the first character in the string.
        function setupFunction(o,prop,funcstring)
            h=findprop(o,prop);
            listenprop=prop;
            if isempty(h)
                o.cic.error('STOPEXPERIMENT',[prop ' is not a property of ' o.name '. Add it first']);
            end
            h.GetObservable =true;
            % Parse the specified function and make it into an anonymous
            % function.  
            fun = neurostim.utils.str2fun(funcstring);
            % Assign the  function to be the PreGet function; it will be
            % called everytime a client requests the value of this
            % property.
            o.listenerHandle.preGet.(prop) = o.addlistener(listenprop,'PreGet',@(src,evt)evalParmGet(o,src,evt,fun));            
        end
        
       
        
        % Add properties that will be time-logged automatically, fun
        % is an optional argument that can be used to modify the parameter
        % when it is set. This function will be called with the plugin object
        % as its first and the raw value as its second argument.
        % The function should return the desired value. For
        % instance, to add a Gaussian jitter around a set value:
        % jitterFun = @(obj,value)(value+randn);
        % or, you can pass a handle to a member function. For instance the
        % @afterFirstFixation member function which will add the frame at
        % which fixation was first obtained to, for instance an on-frame.
        function addProperty(o,prop,value,postprocess,validate,SetAccess,GetAccess)
            h = o.addprop(prop);
            h.SetObservable = true;
            if nargin<7
                GetAccess='public';
                if nargin<6
                    SetAccess='public';
                    if nargin <5
                        validate = '';
                        if nargin<4
                            postprocess = '';
                        end
                    end
                end
            end
            % Setup a listener for logging, validation, and postprocessing
            o.listenerHandle.(prop) = o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
            o.(prop) = value; % Set it, this will call the logParmSet function now.
            h.GetAccess=GetAccess;
            h.SetAccess=SetAccess;
        end
        

        
        % For properties that have been added already, you cannot call addProperty again
        % (to prevent duplication and enforce name space consistency)
        % But the user may want to add a postprocessor to a built in property like
        % X. This function does exactly that
        function addPostSet(o,prop,postprocess,validate)            
            if nargin <4
                validate = '';
            end
            h =findprop(o,prop);
            if isempty(h)
                error([prop ' is not a property of ' o.name '. Add it first']);
            end
            o.listenerHandle.(prop) = o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
            o.(prop) = o.(prop); % Force a call to the postprocessor.
        end
        
        function removeListener(o,prop)
            delete(o.listenerHandle.(prop));
        end
        
        % Log the parameter setting and postprocess it if requested in the call
        % to addProperty.
        function logParmSet(o,src,evt,postprocess,validate)
            if ~strcmpi(o.name,evt.AffectedObject.name)
                disp '1'
            end
            srcName=src.Name;
            value = o.(srcName); % The raw value that has just been set
            %if this is a function, add a listener
            if ~isempty(value) && strcmpi(value(1),'@') %%ischar(value) && any(regexp(value,'@\((\w*)*'))
                setupFunction(o,srcName,value);
                value=o.(srcName);
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
                    error(['Setting ' srcName ' failed validation ' func2str(validate)]);
                end
            end
            if nargin>=4 && ~isempty(postprocess)
                % This re-sets the value to something else.
                % Matlab is clever enough not to
                % generate another postSet event.
                o.(srcName) = postprocess(o,value);
            end
             o.addToLog(srcName,value);
        end
        
        % Protected access to logging
        function addToLog(o,name,value)
            o.log.parms{end+1}  = name;
            o.log.values{end+1} = value;
            if isempty(o.cic)
                o.log.t(end+1)       = -Inf;
            else
                o.log.t(end+1)      = o.cic.clockTime;
            end
        end
        
        
        
        % Evaluate a function to get a parameter and validate it if requested in the call
        % to addProperty.
        function evalParmGet(o,src,evt,fun)            
            srcName=src.Name;
                
            oldValue = o.(srcName);            
           
            if ~isempty(o.cic) && o.cic.stage >o.cic.SETUP
                value=fun(o);
                % Check if changed, assign and log if needed.
                if ~isequal(value,oldValue) || (ischar(value) && ~(strcmp(oldValue,value))) || (ischar(oldValue)) && ~ischar(value)...
                        || (~isempty(value) && isnumeric(value) && (isempty(oldValue) || all(oldValue ~= value))) || (isempty(value) && ~isempty(oldValue))                    
                    o.(srcName) = value; % This calls PostSet and logs the new value
                end
            else
                % Not all objects have been setup so function may not work
                % yet. Evaluate to NaN for now; validation is disabled for
                % now.
                %value = NaN; 
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