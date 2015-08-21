classdef plugin  < dynamicprops & matlab.mixin.Copyable
    
    properties (SetAccess=public)
        cic@neurostim.cic;  % Pointer to CIC
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
        
        keyStrokes  = {}; % Cell array of keys that his plugin will respond to
        keyHelp     = {}; % Copy in the plugin allows easier setup of keyboard handling by stimuli and other derived classes.
        evts        = {}; % Events that this plugin will respond to.
    end
    
    properties (Access = private)
        listenerHandle = struct;
    end
    
    methods (Access=public)
        function o=plugin(n)
            % Create a named plugin
            o.name = n;
            % Initialize an empty log.
            o.log(1).parms  = {};
            o.log(1).values = {};
            o.log(1).t =[];
            
        end
        
        function s= duplicate(o,name)
            % This copies the plugin and gives it a new name. See
            % plugin.copyElement
            s=copy(o);
            s.name = name;
        end
        
        
        function keyboard(o,key,time)
            % Generic keyboard handler to warn the end user/developer.
            disp (['Please define a keyboard function to handle  ' key ' in '  o.name ])
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
    end
    
    methods (Access= protected)
        
    end
    
    % Only the (derived) class designer should have access to these
    % methods.
    methods (Access = protected, Sealed)        
        function s= copyElement(o)
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
            for p=1:numel(dynProps)
                pName = dynProps{p};
                s.addProperty(pName,o.(pName));
            end
        end
        
        % Define a property as a function of some other property.
        % This function is called at the initial logParmSet of a parameter.
        % funcstring is the function definition. It is a string which
        % references a stimulus/plugin by its assigned name and reuses that 
        %  property name if it uses an object/variable of that property. e.g. 
        % '@(cic) sin(cic.frame)' or
        % '@(dots) dots.X + 1'
        %
        function functional(o,prop,funcstring)
             h =findprop(o,prop);
            if isempty(h)
                error([prop ' is not a property of ' o.name '. Add it first']);
            end
            h.GetObservable =true;
            specs{1} = funcstring;
            % find the function end of the string
            funcend = regexp(funcstring,'\<@\((\w*)(,*\s*\w*(\.\w*)*)*\)\>\s*','end');
            func = funcstring(funcend+1:end); % store the function end of the string
            specs{2,1} = func;
            c = 0;
            variables = regexp(funcstring,'(?<=@\s*\()(\w*(\.\w*)*)|(?<=,\s*)(\w*(\.\w*)*)','tokens');  %get the main variables
            for a=1:length(variables)
                vardot = regexp(funcstring,'(?<=(??@variables{a}{1})\.)\w*(\.\w*)*','match');   %get the variable after the dot
                for b = 1:length(vardot)
                    % replace each variable in the function
                specs{2,1} = regexprep(specs{2,1},'(??@variables{a}{:})(\.(??@vardot{b}))?',char('A'+c),'once');
                c = c+1;
                specs{end+1,1} = horzcat(variables{a},vardot(b));
                end
            end
            % recreate the initial function variable list, i.e. '@(A,B)'
            for x=1:c
                if x == 1
                    vars = horzcat('@(','A');
                    if x == c
                        vars = horzcat(vars, ')');
                    end
                elseif x==c
                        vars = horzcat(vars,', ',char('A'+x-1),')');
                else
                    vars = horzcat(vars,', ',char('A'+x-1));
                end
            end
            
            if ~exist('vars','var')
                specs{2,1} = str2func(func);
            else
                % merge the function back together
                specs{2,1} = horzcat(vars,specs{2,1});
                specs{2,1} = str2func(specs{2,1});
            end
            o.listenerHandle.pre.(prop) = o.addlistener(prop,'PreGet',@(src,evt)evalParmGet(o,src,evt,specs));
            
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
        function addProperty(o,prop,value,postprocess,validate)
            h = o.addprop(prop);
            h.SetObservable = true;
            if nargin <5
                validate = '';
                if nargin<4
                    postprocess = '';
                end
            end
            % Setup a listener for logging, validation, and postprocessing
            o.listenerHandle.(prop) = o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
            o.(prop) = value; % Set it, this will call the logParmSet function as needed.
        end
        
        % For properties that have been added already, you cannot call addProperty again
        % (to prevent duplication and enforce name space consistency)
        % But the user may want to add a postprocessor to a built in property like
        % X. This function does exactly that
        function addPostSet(o,prop,postprocess,validate)
            if nargin<4
                validate ='';
            end
            h =findprop(o,prop);
            if isempty(h)
                error([prop ' is not a property of ' o.name '. Add it first']);
            end
%             h.SetObservable =true;    % This gives a read-only error -
%             setObservable in properties beforehand.
            o.listenerHandle.(prop) = o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess, validate));
            o.(prop) = o.(prop); % Force a call to the postprocessor.
        end
        
        function removeListener(o,prop)
            delete(o.listenerHandle.(prop));
        end
        
        % Log the parameter setting and postprocess it if requested in the call
        % to addProperty.
        function logParmSet(o,src,evt,postprocess,validate)
            value = o.(src.Name); % The raw value that has just been set
            % checks if this is a function reference and if the listener
            % already exists for this function
            if ischar(value) && any(regexp(value,'@\((\w*)*')) && ~isfield(o.listenerHandle,['pre.' src.Name])
                % it does not exist, call functional()
                functional(o,src.Name,value);
                %evaluate
                value = o.(src.Name);
            end
            if nargin >=5 && ~isempty(validate)
                success = validate(value);
                if ~success
                    error(['Setting ' src.Name ' failed validation ' func2str(validate)]);
                end
            end
            if nargin>=4 && ~isempty(postprocess)
                % This re-sets the value to something else.
                % Matlab is clever enough not to
                % generate another postSet event.
                o.(src.Name) = postprocess(o,value);
            end

             o.addToLog(src.Name,value);
        end
        
        % Protected access to logging
        function addToLog(o,name,value)
            o.log.parms{end+1}  = name;
            o.log.values{end+1} = value;
            o.log.t(end+1)      = GetSecs*1000;
        end
        
        
        
        % Evaluate a function to get a parameter and validate it if requested in the call
        % to addProperty.
        function evalParmGet(o,src,evt,specs)
            if ischar(o.(src.Name)) && ~strcmp(specs{1},o.(src.Name)) %if value is set to a new function
                delete(o.listenerHandle.pre.(src.Name));
                functional(o,src.Name,o.(src.Name));
            end
            fun = specs{2}; % Function handle
            nrArgs = length(specs)-2;
            args= cell(1,nrArgs);
            try
            for i=1:nrArgs
                if iscell(specs{2+i})
                    if isempty(strfind(specs{i+2}{2},'.')) 
                        %if there is no subproperty reference
                        if ischar(specs{i+2}{1}) && strcmp(specs{i+2}{1},'cic')
                            % An object of cic
                            args{i} = o.cic.(specs{i+2}{2});
                        else
                            %not an object of cic; must be a plugin/stimulus
                            if strcmp(specs{i+2}{1},o.name)
                                % if is self-referential
                                oldValues = o.log.values(strcmp(o.log.parms,specs{i+2}{2}));    % check old value was not functional
                                if ischar(oldValues{end}) && any(regexp(oldValues{end},'@\((\w*)*'))
                                    args{i} = oldValues{end-1};
                                else
                                    args{i} = o.cic.(specs{i+2}{1}).(specs{i+2}{2});
                                end
                            else % is not self-referential
                                args{i} = o.cic.(specs{i+2}{1}).(specs{i+2}{2});
                            end
                        end
                        
                    else
                        % there is a subproperty reference
                        a = strfind(specs{i+2}{2},'.'); % a is dot reference numbers
                        predot = specs{i+2}{2}(1:(a-1)); %get the initial variable
                        
                        if ischar(specs{i+2}{1}) && strcmp(specs{i+2}{1},'cic')
                            % if is an object of cic
                            args{i} = o.cic.(predot);
                        else % if is not an object of cic (plugin/stimulus)
                            args{i} = o.cic.(specs{i+2}{1}).(predot);
                            
                            if strcmp(specs{i+2}{1},src.Name)
                                % if the property is self-referential
                                oldValues = o.log.values(strcmp(o.log.parms,predot));
                                if isstruct(oldValues{end}) %if is a structure
                                    % store the last and second-last values
                                    % so that args{} can be set to the
                                    % previous non-functional value.
                                    oldValueEnd = oldValues{end};
                                    oldValue1End = oldValues{end-1};
                                    if length(a)>1
                                        for b = 1:length(a)-1
                                            postdot = specs{i+2}{2}(a(b)+1:a(b+1)-1);
                                            oldValueEnd = oldValueEnd.(postdot);
                                            oldValue1End = oldValue1End.(postdot);
                                            args{i} = args{i}.(postdot);
                                        end
                                    end
                                    postdot = specs{i+2}{2}(a(end)+1:end);
                                    oldValueEnd = oldValueEnd.(postdot);
                                    oldValue1End = oldValue1End.(postdot);
                                    if ischar(oldValueEnd) && any(regexp(oldValueEnd,'@\((\w*)*')) %if the last value was a functional string
                                        args{i} = oldValue1End; % set the value to the previous value.
                                        continue;   %skip the rest of this loop now that args{i} has been found.
                                    else
                                        args{i} = args{i}.(postdot);    %set the value to the acquired value.
                                        continue;   %skip the rest of this loop now that args{i} has been found.
                                    end
                                end
                            end
                        end
                        if length(a)>1  %if there is more than one subproperty ref
                            for b = 1:length(a)-1 % collect all the subproperty refs
                                postdot = specs{i+2}{2}(a(b)+1:a(b+1)-1);
                                args{i} = args{i}.(postdot);
                            end
                        end
                        % get the last after-dot reference
                        postdot = specs{i+2}{2}(a(end)+1:end);
                        args{i} = args{i}.(postdot);
                    end
                else
                    args{i} = specs{i+2};
                end
            end
            catch
%                 if ~isempty(o.cic) && ~all(cellfun(@isempty,args)) 
%                     error(['Could not evaluate ' func2str(fun) 'to get value for ' src.Name]);
%                 else
%                     return;
%                 end
                
            end
            try
                value = fun(args{:});
            catch
                error(['Could not evaluate ' func2str(fun) ' to get value for ' src.Name ]);
            end
            
            % Compare with existing value to see if we need to set?
            oldValue = o.(src.Name);
            if (ischar(value) && ~(strcmp(oldValue,value))) || (ischar(oldValue)) && ~ischar(value)...
                    || (~isempty(value) && isnumeric(value) && (isempty(oldValue) || all(oldValue ~= value))) || (isempty(value) && ~isempty(oldValue))
                o.(src.Name) = value; % This calls PostSet and logs the new value
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
            
            if nargin<3
                keyHelp = cell(1,length(keys));
                [keyHelp{:}] = deal('?');
            else
                if length(keys) ~= length(keyHelp)
                    error('Number of KeyHelp strings not equal to number of keys.')
                end
                
            end
            
            if any(size(o.cic))
                % Pass the information to CIC which keeps track of
                % keystrokes
                for a = 1:numel(keys)
                    addKeyStroke(o.cic,keys{a},keyHelp{a},o);
                end
                KbQueueCreate(o.cic);
                KbQueueStart(o.cic);
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
            if ischar(evts);evts= {evts};end
            if isempty(evts)
                o.evts = {};
            else
                o.evts = cat(2,o.evts,evts);
            end
        end
        
    end
    
    methods (Access = public)
        function baseEvents(o,c,evt)
            if c.PROFILE;tic;end
            switch evt.EventName
                case 'BASEBEFOREEXPERIMENT'
                    notify(o,'BEFOREEXPERIMENT');
                    
                case 'BASEBEFORETRIAL'
                    notify(o,'BEFORETRIAL');
                    if c.PROFILE; c.addProfile('BEFORETRIAL',toc);end;
                    
                case 'BASEBEFOREFRAME'
                    if GetSecs*1000-c.frameStart>(1000/c.screen.framerate - c.requiredSlack)
                        display(['Did not run ' o.name ' beforeFrame in frame ' num2str(c.frame) ' due to framerate limitations.']);
                        return;
                    end
                    notify(o,'BEFOREFRAME');
                    if c.PROFILE; c.addProfile('BEFOREFRAME',toc);end;
                    
                case 'BASEAFTERFRAME'
%                     if GetSecs*1000-c.frameStart>(1000/c.screen.framerate - c.requiredSlack)
%                         display(['Did not run ' o.name ' afterFrame in frame ' num2str(c.frame) ' due to framerate limitations.']);
%                         return;
%                     end
                    notify(o,'AFTERFRAME');
                    if c.PROFILE; c.addProfile('AFTERFRAME',toc);end;
                    
                case 'BASEAFTERTRIAL'
                    notify(o,'AFTERTRIAL');
                    if (c.PROFILE); addProfile(c,'AFTERTRIAL',toc);end;
                    
                case 'BASEAFTEREXPERIMENT'
                    notify(o,'AFTEREXPERIMENT');
            end
        end
        
        
    end
end