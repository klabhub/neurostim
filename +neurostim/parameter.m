classdef parameter < handle
    % Parameter objects are used to store stimulus parameters such as X,Y, nrDots
    % etc. The plugin and stimulus classes have some built-in and users can add
    % parameters to their derived classes.
    % Parameters can:
    %       store any value (char, double, etc), %
    %       use function definitions to create dependencies on other parameters
    %       are automaritally logged whenever they change
    %
    %
    % BK - Feb 2017
    
    % Define a property as a function of some other property.
    % This function is called at the initial logParmSet of a parameter.
    % funcstring is the function definition. It is a string which
    % references a stimulus/plugin by its assigned name and reuses that
    % property name if it uses an object/variable of that property. e.g.
    % dots.size='@ sin(cic.frame)' or
    % fixation.X='@ dots.X + 1' or
    % fixation.color='@ cic.screen.color.background'
    % % The @ sign should be the first character in the string.
    
    
    properties (Constant)
        BLOCKSIZE = 500; % Logs are incremented with this number of values.
    end
    
    properties (Transient, SetAccess = protected, GetAccess =public);
        setListener; % Stored to allow enable/disable
        getListener; % Stored to allow enable/disable
    end
    
    properties (SetAccess= protected, GetAccess=public)
        name;   % Name of this property
        value;  % Current value
        default; % The default value; set at the beginning of the experiment.
        log;    % Previous values;
        time;   % Time at which previous values were set
        cntr=0; % Counter to store where in the log we are.
        capacity=0; % Capacity to store in log
        
        fun =[];        % Function to allow across parameter dependencies
        validate =[];    % Validation function
        
        plg@neurostim.plugin; % Handle to the plugin that this belongs to.
        
        isFunResult@logical=false; % Used in getValue/setValue
    end
    
    methods
        % Create a parameter for a plugin/stimulu with a name and a value.
        function  o = parameter(p,nm,v,valFun)
            o.name = nm;
            o.plg = p;
            
            if nargin>3
                o.validate = valFun;
            end
            
            %Check for a function definition
            if strncmpi(v,'@',1)
                % Parse the specified function and make it into an anonymous
                % function.
                o.fun = neurostim.utils.str2fun(v);
                % Setup get listener so that we can do function call
                % whenever this parameter is retrieved.
                o.getListener  = p.addlistener(nm,'PreGet',@(src,evt)getValue(o,src,evt));
                %o.value = v; % For now.. the function cannot be evaluated yet.
            else
                o.value =v;
            end
            
            % Setup a listener to log and validate changes
            o.setListener = p.addlistener(nm,'PostSet',@(src,evt)setValue(o,src,evt));
            o.plg.(nm) = v;
        end
        
        
      
        
        function assign(o,v)
            o.value =v;
            t = GetSecs;
            % Log
            o.cntr=o.cntr+1;
            % Allocate space if needed
            if o.cntr> o.capacity
                o.log       = cat(2,o.log,cell(1,o.BLOCKSIZE));
                o.time      = cat(2,o.time,nan(1,o.BLOCKSIZE));
                o.capacity = numel(o.log);
            end
            %% Fill the log.
            o.log{o.cntr}  = o.value;
            o.time(o.cntr) = t;
        end
        
        % This function can be called after a get to evaluate a function
        function [v,ok] = getValue(o,src,evt) %#ok<INUSD>
            
            if o.plg.cic.stage >o.plg.cic.SETUP
                v=o.fun(o.plg); % Evaluate the function
                o.isFunResult =true; % A flag to allow the setValue function to detect
                % whether it is being called from here (to log the outcome of
                % the function) or somewhere else (to change the function to something else).
                
                % Assign to the dynprop in the plugin so that the caller gets
                % the result of the function. This will generate a postSet
                % event  (if the value changed), which calls setValue and logs the new value .
                o.plg.(o.name) = v;
                o.isFunResult =false;
                ok = true;
            else
                % Not all objects have been setup so function may not work
                % yet. Evaluate to NaN for now
                v = NaN;
                ok = false;
            end
            
        end
        
        % This function is called after each parametr set to validate
        function v = setValue(o,src,evt) %#ok<INUSD>
            % Get the value that the dynprop was just set to.
            if ~isempty(o.getListener)
                o.getListener.Enabled = false; % Avoid a 'preget' call
            end
            v= o.plg.(o.name); % The raw value that has just been set
            if ~isempty(o.getListener)
                o.getListener.Enabled = true; % Allow preget calls again
            end
            ok = true; % Normally ok; only function evals can be not ok.
            %Check for a function definition
            if strncmpi(v,'@',1)
                % Parse the specified function and make it into an anonymous
                % function.
                o.fun = neurostim.utils.str2fun(v);
                if isempty(o.getListener)
                    % Parm has only now become a function. Need to add a getListener.
                    o.getListener  = o.plg.addlistener(o.name,'PreGet',@(src,evt)getValue(o,src,evt));
                else
                    %- nothing to do; same listener will work with the new
                    %o.fun
                end%
                % Evaluate the function (without calling set again)
                o.setListener.Enabled = false;
                [v,ok]= getValue(o); %ok will be false if the function could not be evaluated yet (still in SETUP phase).
                o.setListener.Enabled = true;
            elseif ~o.isFunResult && ~isempty(o.getListener)
                % This is currently a function, and someone is overriding
                % the parameter with a non-function value
                o.fun = [];
                delete(o.getListener); % No longer needed.
            end
            
            % validate
            if ~isempty(o.validate) && ok 
                o.validate(v);
            end
            
            if ok
                % log
                assign(o,v); % Log and store in this parameter object
                % Assign to dynamic property
                o.plg.(o.name) = v;
            end
        end
      
        % Called before saving an object to clean out the empty elements in
        % the log.
        function pruneLog(o)
            o.log(o.cntr+1:end) =[];
            o.time(o.cntr+1:end) =[];
            o.capacity = numel(o.log);
        end
        
        % Called to store the current value in the default value. This
        % allows us to reset the parms to their default at the start of a
        % trial (before applying condition specific modifications).
        function setCurrentToDefault(o)
            o.default = o.value;
        end
        
        function setDefaultToCurrent(o)
            if isempty(o.fun)
                % Put the default back as the current value
                % but not for functions as that would overwrite the
                % function definition.
                o.value = o.default;
            end
        end
    end
    
    
end