classdef plugin  < dynamicprops
    properties (SetAccess=public)
        cic@neurostim.cic;  % Pointer to CIC
    end
    
    properties (SetAccess=private, GetAccess=public)
        name@char= '';   % Name of the plugin; used to refer to it within cic
        log;             % Log of parameter values set in this plugin
    end
    
    properties (SetAccess=private, GetAccess=public)
        keyStrokes  = {}; % Cell array of keys that his plugin will respond to
        keyHelp     = {};
        evts        = {}; % Events that this plugin will respond to.
    end
    
    
    methods (Access=public)
        function o=plugin(n)
            % Create a named plugin
            o.name =n;
            % Initialize an empty log.
            o.log(1).parms  = {};
            o.log(1).values = {};
            o.log(1).t =[];
        end
        
        function keyboard(o,key,time)
            % Generic keyboard handler to warn the end user/developer.
            disp (['Please define a keyboard function to handle  ' key ' in '  o.name ])
        end
        
        function events(o,src,evt)
            % Generic event handler to warn the end user/developer.
            disp (['Please define a events function to handle  the ' evt.EventName  ' from '  src.name ' in plugin ' o.name ])
        end
    
       % Define a property as a function of some other property. 
       % specs is the function definition. The first element in this cell
       % array is a function_handle, all subsequent arguments are arguments
       % that will be passed to that function.
       % Object/variable references can be constructed by using a
       % two-element cell array : the first is a handle to the object or the name of the
       % objet,the second is the object property. 
        function functional(o,prop,specs)
            h =findprop(o,prop);
            if isempty(h)
                error([prop ' is not a property of ' o.name '. Add it first']);
            end
            h.GetObservable =true;
            o.addlistener(prop,'PreGet',@(src,evt)evalParmGet(o,src,evt,specs));            
        end
    end
    
    
    
    % Only the (derived) class designer should have access to these
    % methods.
    methods (Access = protected, Sealed)
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
            o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
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
            h.SetObservable =true;
            o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess, validate));
            o.(prop) = o.(prop); % Force a call to the postprocessor.
        end
        
        
        % Log the parameter setting and postprocess it if requested in the call
        % to addProperty.
        function logParmSet(o,src,evt,postprocess,validate)
            value = o.(src.Name); % The raw value that has just been set
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
            o.log.parms{end+1}  = src.Name;
            o.log.values{end+1} = value;
            o.log.t(end+1)      = GetSecs;
        end
        
       
        
        
        % Evaluate a function to get a parameter and validate it if requested in the call
        % to addProperty.
        function evalParmGet(o,src,evt,specs)            
            fun = specs{1}; % Function handle
            nrArgs = length(specs)-1;
            args= cell(1,nrArgs);
            for i=1:nrArgs
                if iscell(specs{1+i})
                    if isa(specs{i+1}{1},'neurostim.plugin')
                        % Handle to a plugin: interpret as dots.X
                        args{i} = specs{i+1}{1}.(specs{i+1}{2});
                    elseif ischar(specs{i+1}{1})
                        % Name of a plugin. Find its handle first.
                        args{i} = o.cic.(specs{i+1}{1}).(specs{i+1}{2});
                    else
                        error('dasds');
                    end
                else
                    args{i} = specs{i+1};
                end
            end
            try
                value = fun(args{:});
            catch
                error(['Could not evaluate ' func2str(fun) ' to get value for ' src.Name ]);
            end
            
            % Compare with existing value to see if we need to set?
            oldValue = o.(src.Name);
            if (ischar(value) && ~(strcmp(oldValue,value))) ...
                    || (isnumeric(value) && oldValue ~= value)
                o.(src.Name) = value; % This calls PostSet and logs the new value
            end
        end
        
    end
    
    % Convenience wrapper functions to pass the buck to CIC
    methods (Sealed)
        function nextTrial(o)
            % Move to the next trial
            nextTrial(o.cic);
        end
        
        
        function listenToKeyStroke(o,key,keyHelp)
            % Add  a key that this plugin will respond to. Note that the
            % user must implement the keyboard function to do the work. The
            % keyHelp is a short string that can help the GUI user to
            % understand what the key does.
            if ischar(key);key= {key};end
            if nargin<3
                keyHelp = cell(1,length(key));
                [keyHelp{:}] = deal('?');
            end
            if isempty(key)
                o.keyStrokes = {};
            else
                o.keyStrokes= cat(2,o.keyStrokes,key);
                o.keyHelp= cat(2,o.keyHelp,keyHelp);
            end
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
    
    methods (Static)
            end
    
end