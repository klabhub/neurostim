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
        keyFunc = struct; % structure for functions assigned to keys.
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
        

    end
    
%     methods (Access= public)
        
%         function varargout = subsref(A, S)
            
% %             overload, check for functions? add a notification for
% %             evaluation???
% %             
% %             Handle the first indexing on your obj itself
%             switch S(1).type
%                 case '.'
%                     if ismethod(A,S(1).subs)
%                         if nargout>0
%                             [varargout{1:nargout}]=builtin('subsref',A,S);
%                         else
%                             builtin('subsref',A,S);
%                         end
%                         return;
%                     else
% %                     Enable normal "." and "{}" behavior
%                         B = builtin('subsref', A, S(1));
%                     end
%                 otherwise
%                     B = builtin('subsref', A, S(1));
%             end
%             if strcmp(S(end).type,'.')
%                 keyboard;
%             end
%             varargout=builtin('subsref',A,S);
%             if numel(S) > 1
%                 varargout = subsref(B, S(2:end)); % regular call, not "builtin", to support overrides
%             else
%                 varargout={B};
%             end
%             if ~iscell(varargout)
%                 varargout={varargout};
%             end
%         end
        
%     end
    
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
                if isfield(o.listenerHandle,'pre') && isfield(o.listenerHandle.preGet,pName)
                    specs=o.listenerHandle.preGet.([pName 'specs']);
                    for a=3:length(specs)
                        if strcmp(specs{a}(1),o.name)
                            specs{a}{1}=name;
                        end
                    end
                    h =findprop(s,pName);
                    h.GetObservable=true;
                    s.listenerHandle.preGet.(pName)=s.addlistener(pName,'PreGet',@(src,evt)evalParmGet(s,src,evt,specs));
                 end
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
            subprop=strsplit(prop,{'___','__'});
            if numel(subprop)>1
                listenprop=subprop{1};
                h=findprop(o,subprop{1});
                if isempty(h)
                    tmp=subprop{1};
                    listenprop=tmp(1:end-1);
                    h=findprop(o,tmp(1:end-1));
                end
            else
                h=findprop(o,prop);
                listenprop=prop;
            end
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
            o.listenerHandle.preGet.([prop 'specs'])=specs;
            o.listenerHandle.preGet.(prop) = o.addlistener(listenprop,'PreGet',@(src,evt)evalParmGet(o,src,evt,specs));
            
        end
        
        

            
        
        % Add properties that will be time-logged automatically, fun
        % is an optional argument that can be used to modify the parameter
        % when it is set. This function will be called with the plugin object
        % as its first and the raw value as its second argument.
        % The function should return the desired value. For
        % instance, to add a Gaussian jitter around a set value:
        % jitterFun = @(obj,value)(value+randn);ed
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
            o.(prop) = value; % Set it, this will call the logParmSet function as needed.
            h.GetAccess=GetAccess;
            h.SetAccess=SetAccess;
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
            o.listenerHandle.(prop) = o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
            o.(prop) = o.(prop); % Force a call to the postprocessor.
        end
        
        function removeListener(o,prop)
            delete(o.listenerHandle.(prop));
        end
        
        % Log the parameter setting and postprocess it if requested in the call
        % to addProperty.
        function logParmSet(o,src,evt,postprocess,validate)
            % if there is a listener, delete it
            
            value = o.(src.Name); % The raw value that has just been set
            if iscell(value)
                for a=1:numel(value)
                    if ischar(value) && any(regexp(value,'@\((\w*)*'))
                        prop=[src.Name '__' num2str(a)];
                        functional(o,prop,value.(a{1}));
                        value=o.(src.Name);
                    end
                end
            end
            if isstruct(value)
                for a=fieldnames(value)
                    if ischar(value.(a{1})) && any(regexp(value.(a{1}),'@\((\w*)*'))
                        prop=[src.Name '___' a{1}];
                        functional(o,prop,value.(a{1}));
                        value=o.(src.Name);
                    end
                end
            end
            %if this is a function, add a listener
            if ischar(value) && any(regexp(value,'@\((\w*)*'))
                functional(o,src.Name,value);
                value=o.(src.Name);
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
            o.log.t(end+1)      = o.cic.clockTime;
        end
        
        
        
        % Evaluate a function to get a parameter and validate it if requested in the call
        % to addProperty.
        function evalParmGet(o,src,evt,specs)
            a={};
            if ~isfield(o.listenerHandle.preGet,src.Name)
                a=regexp(fieldnames(o.listenerHandle.preGet),[src.Name '.*'],'match');
                %%%% rename srcName to subref, change all further
                %%%% references
                if numel(a)>1
                    srcNames=a{2:2:end};
                    for b=1:numel(srcNames)
                        if ~isempty(regexp(srcNames{b},'___','ONCE'))
                            names{b}=regexprep(srcNames{b},'___','.');
                        elseif ~isempty(regexp(srcNames{b},'__','ONCE'))
                            names{b}=regexprep(srcNames{b},'__','{');
                        end
                    end
                end
                srcName=srcNames{1};
            else
                srcName=src.Name;
            end
            if ischar(o.(src.Name)) && ~strcmp(specs{1},o.(src.Name)) %if value is set to a new function
                if isfield(o.listenerHandle.preGet,srcName)
                    delete(o.listenerHandle.preGet.(srcName));
                    delete(o.listenerHandle.preGet.([srcName 'specs']));
                end
                functional(o,srcName,o.(src.Name));
            end
            prevvalues=o.log.values(strcmp(o.log.parms,src.Name));
            prevvalue=prevvalues{end};
            if numel(a)>0
                if isstruct(o.(src.Name)) && isstruct(prevvalue) && all(size(o.(src.Name))==size(prevvalue)) && numel(fieldnames(o.(src.Name)))==numel(fieldnames(prevvalue)) && all(strcmp(fieldnames(o.(src.Name)),fieldnames(prevvalue)))
                    check=fieldnames(prevvalue);
                    for c=1:numel(check)
                        if ~strcmp(specs{1},o.(src.Name)(b).(check{c})) && ((ischar(prevvalue(b).(check{c})) && ischar(o.(src.Name)(b).(check{c})) && ~strcmp(prevvalue(b),o.(src.Name)(b).(check{c}))) || (any(prevvalue(b).(check{c})~=o.(src.Name)(b).(check{c})))...
                                || (isempty(prevvalue(b).(check{c})) && ~isempty(o.(src.Name)(b).(check{c}))) || (~isempty(prevvalue(b).(check{c})) && isempty(o.(src.Name)(b).(check{c}))))
                            delete(o.listenerHandle.preGet.(srcName));
                            delete(o.listenerHandle.preGet.([srcName 'specs']));
                            return;
                        else
                            break;
                        end
                    end
                end
            elseif ~strcmp(specs{1},o.(src.Name)) && ((ischar(prevvalue) && ischar(o.(src.Name)) && ~strcmp(prevvalue,o.(src.Name))) || (any(prevvalue~=o.(src.Name)))...
                    || (isempty(prevvalue) && ~isempty(o.(src.Name))) || (~isempty(prevvalue) && isempty(o.(src.Name))))
                delete(o.listenerHandle.preGet.(srcName));
                delete(o.listenerHandle.preGet.([srcName 'specs']));
                return;
            end
            
            value=evalFunction(o,srcName,evt,specs);
            
            % Compare with existing value to see if we need to set?
            oldValue = o.(src.Name);
            
            if isstruct(value) || iscell(value) || (ischar(value) && ~(strcmp(oldValue,value))) || (ischar(oldValue)) && ~ischar(value)...
                    || (~isempty(value) && isnumeric(value) && (isempty(oldValue) || all(oldValue ~= value))) || (isempty(value) && ~isempty(oldValue))
                    
                o.(src.Name) = value; % This calls PostSet and logs the new value
            end
        end
        
        function value=evalFunction(o,srcName,evt,specs)
            fun = specs{2}; % Function handle
            nrArgs = length(specs)-2;
            args= cell(1,nrArgs);
            isstruct=false;
            iscell=false;
            if ~isempty(regexp(srcName,'___'))
                tmp=regexprep(srcName,'___','.');
                postSrcName=tmp(strfind(tmp,'.')+1:end);
                srcName=tmp(1:strfind(tmp,'.')-1);
                isstruct=true;
                value=o.(srcName);
            elseif ~isempty(regexp(srcName,'__'))
                tmp=regexprep(srcName,'__','{');
                postSrcName=str2double(tmp(strfind(tmp,'{')+1:end));
                srcName=tmp(1:strfind(tmp,'{')-1);
                iscell=true;
                value=o.(srcName);
            end
            try
            for i=1:nrArgs
                if ~isempty(specs{2+i})
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
                            
                            if strcmp(specs{i+2}{1},srcName)
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
                if isstruct
                    value.(postSrcName)=fun(args{:});
                elseif iscell
                    value{postSrcName}=fun(args{:});
                else
                    value = fun(args{:});
                end
            catch
                error(['Could not evaluate ' func2str(fun) ' to get value for ' srcName ]);
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
            if c.PROFILE;tic;end
            switch evt.EventName
                case 'BASEBEFOREEXPERIMENT'
                    notify(o,'BEFOREEXPERIMENT');
                    
                case 'BASEBEFORETRIAL'
                    notify(o,'BEFORETRIAL');
                    if c.PROFILE; c.addProfile('BEFORETRIAL',o.name,toc);end;
                    
                case 'BASEBEFOREFRAME'
                    if strcmp(o.name,'gui')
                        if ~mod(c.frame,c.guiFlipEvery)
                            return;
                        end
                    end
                    if c.clockTime-c.frameStart>(1000/c.screen.frameRate - c.requiredSlack)
                        c.writeToFeed(['Did not run ' o.name ' beforeFrame in frame ' num2str(c.frame) '.']);
                        return;
                    end
                    notify(o,'BEFOREFRAME');
                    if c.PROFILE; c.addProfile('BEFOREFRAME',o.name,toc);end;
                    
                case 'BASEAFTERFRAME'
                    if strcmp(o.name,'gui')
                        if ~mod(c.frame,c.guiFlipEvery)
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
                    if c.PROFILE; c.addProfile('AFTERFRAME',o.name,toc);end;
                    
                case 'BASEAFTERTRIAL'
                    notify(o,'AFTERTRIAL');
                    if (c.PROFILE); addProfile(c,'AFTERTRIAL',o.name,toc);end;
                    
                case 'BASEAFTEREXPERIMENT'
                    notify(o,'AFTEREXPERIMENT');
            end
        end
        
        
    end
end