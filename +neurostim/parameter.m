classdef parameter < handle & matlab.mixin.Copyable
    % Parameter objects are used to store stimulus parameters such as X,Y, nrDots
    % etc. The plugin and stimulus classes have some built-in and users can add
    % parameters to their derived classes.
    % Parameters can:
    %       store any value (char, double, etc), %
    %       use function definitions to create dependencies on other parameters
    %       are automaritally logged whenever they change
    %
    % The parameter class is also the main source of information for data
    % analysis. The get() function provides the interface to extract
    % parameter values per trial, at certain times, etc. 
    % 
    % Implementation:
    %  Plugins add dynamic properties (plugin.addProperty). The user of the
    %  plugin can use that dynamic property just like any object property. 
    % Behind the scenes, each dynprop has a parameter associated with it
    % (which is stored in the plugin.prms member). Whenever the user calls
    % plugin.X, the parameter class returns the appropriate value (by
    % redefining the GetMethod of the dynprop. For most parameters this
    % will simply be the value that is stored in the parameter, but for
    % Neurostim function parameters (i.e. specified with '@'), their value
    % is first computed, logged (if changed), and returned. 
    % 
    % When a user sets the value of a property, this change is logged.
    %
    %
    % Note: some parameters store Matlab functions. These are simply stored
    % as values, not in o.fun. Only neurostim functions (specified as
    % strings starting with '@') have entries in o.fun and these functions
    % are evaluated before returning a value to the caller (who uses the
    % dynamic property that this parameter is associated with).
    %
    % Note: I previously implemetned this using PreGet and PostGet
    % functionality of dynprops, but this turned out to be very slow, and
    % even worse, sometimes PostSet was called even when only a Get was
    % requested. 
    % 
    % BK - Feb 2017
    % BK - Mar 17 - Changed to use GetMethod/SetMethod
    %
    
    properties (Constant)
        BLOCKSIZE = 500; % Logs are incremented with this number of values.
    end
    
    properties (SetAccess= protected, GetAccess=public)
        name;   % Name of this property
        value;  % Current value
        default; % The default value; set at the beginning of the experiment.
        log;    % Previous values;
        time;   % Time at which previous values were set
        trial;    % Trial in which previous values were set.
        cntr=0; % Counter to store where in the log we are.
        capacity=0; % Capacity to store in log
        
        fun =[];        % Function to allow across parameter dependencies
        funStr = '';    % The neurostim function string
        validate =[];    % Validation function
        plg@neurostim.plugin; % Handle to the plugin that this belongs to.        
        hDynProp;  % Handle to the dynamic property
    end
    
    methods
        function  o = parameter(p,nm,v,h,options)
            % o = parameter(p,nm,v,h,settings)
            %  p = plugin 
            % nm  - name of parameter
            % h = handle to the corresponding dynprop in the plugin
            % options = .validate = validation function
            %
            % Create a parameter for a plugin/stimulu with a name and a value.
            % This is called from plugins.addProperty
            o.name = nm;
            o.plg = p; % Handle to the plugin
            o.hDynProp  = h; % Handle to the dynamic property
            o.validate = options.validate;
            setupDynProp(o,options); 
            % Set the current value. This logs the value (and parses the
            % v if it is a neurostim function string)
            setValue(o,v);
        end
        
        function setupDynProp(o,options)
            % Set the properties of the dynprop that corresponds to this
            % parm
           
            % These are false because we do not use preGet, postSet
            o.hDynProp.SetObservable  = false; 
            o.hDynProp.GetObservable  = false;   
            o.hDynProp.AbortSet       = false;
            if ~isempty(options)
            o.hDynProp.GetAccess = options.GetAccess;
            o.hDynProp.SetAccess = options.SetAccess;
            end
            % Install two callback functions that will be called for
            % getting and setting of the dynprop
            o.hDynProp.SetMethod =  @(plgn,val)(setValue(o,val,plgn));
            o.hDynProp.GetMethod =  @(plgn)(o.value);            
        end
        
        function o = duplicate(p,plgn,h)
            % Duplicate a parameter so that it can be used in a differnt
            % plugin, with a different dynprop
            o = copyElement(p); % Deep copy
            o.plg = plgn; % Change the plugin
            o.hDynProp = h; % Change the dynprop
            setupDynProp(o,[]); % Setup the callback handlers (no options; keep Set/Get as is).            
        end
        
        
        function storeInLog(o,v)
            % Store and Log the new value for this parm
            if isequal(v,o.value) && o.hDynProp.AbortSet
               % Value has not changed, and AbortSet =true
                return;
            end

            
            % For non-function parns this is the value that will be
            % returned  to the next getValue
            o.value = v;
            % Keep a timed log.
            t = o.plg.cic.clockTime;
            o.cntr=o.cntr+1;
            % Allocate space if needed
            if o.cntr> o.capacity
                o.log       = cat(2,o.log,cell(1,o.BLOCKSIZE));
                o.time      = cat(2,o.time,nan(1,o.BLOCKSIZE));
                o.trial      = cat(2,o.trial,nan(1,o.BLOCKSIZE));
                o.capacity = numel(o.log);
            end
            %% Fill the log.
            o.log{o.cntr}  = v;
            o.time(o.cntr) = t;
            o.trial(o.cntr)= o.plg.cic.trial;
        end
        
        function [v,ok] = getFunctionValue(o,plgn) %#ok<INUSD>
            % This function is called before a function dynprop is used somewhere in the code.
            % It is installed by setValue when it detects a neurostim function.    
            if o.plg.cic.stage >o.plg.cic.SETUP
                % We've passed SETUP phase, function evaluaton should be
                % possible.
                v=o.fun(o.plg); % Evaluate the neurostim function
                storeInLog(o,v);                
                ok = true;
            else  %  not all objects have been setup so
                % function evaluation may not work yet. Evaluate to NaN for now             
                v = NaN;
                ok = false;
            end
        end
        
       
        function setValue(o,v,plgn) %#ok<INUSD>
            % Assign a new value to a parameter
            ok = true; % Normally ok; only function evals can be not ok.
            %Check for a function definition            
            if strncmpi(v,'@',1)
                % The dynprop was set to a neurostim function
                % Parse the specified function and make it into an anonymous
                % function.
                o.funStr = v; % store this to be able to restore it later.
                v = neurostim.utils.str2fun(v);
                o.fun = v;
                % Install a GetMethod that evaluates this function
                o.hDynProp.GetMethod =  @(plgn)(getFunctionValue(o,plgn));                
                % Evaluate the function to get current value
                [v,ok]= getFunctionValue(o); %ok will be false if the function could not be evaluated yet (still in SETUP phase).                
            elseif ~isempty(o.fun)
                % This is currently a function, and someone is overriding
                % the parameter with a non-function value. Remove the fun.
                o.fun = [];
                o.funStr = '';
                % Change the getMethod to a simple value return
                o.hDynProp.GetMethod =  @(plgn)(o.value);     
            end
            
            if ok
                % validate
                if ~isempty(o.validate) 
                    o.validate(v);
                end            
                % Log the new value     
                storeInLog(o,v);                 
            end
        end
        
        % Called before saving an object to clean out the empty elements in
        % the log.
        function pruneLog(o)
            out  = (o.cntr+1):o.capacity;
            o.log(out) =[];
            o.time(out) =[];
            o.trial(out) =[];
            o.capacity = numel(o.log);
        end
        
        % Called to store the current value in the default value. This
        % allows us to reset the parms to their default at the start of a
        % trial (before applying condition specific modifications).
        function setCurrentToDefault(o)
            if isempty(o.fun)
                o.default = o.value;
            else
                o.default = o.funStr;
            end
        end
        
        function setDefaultToCurrent(o)
            % Put the default back as the current value
            %
            setValue(o,o.default);
            
            % Note that for Neurostim functions ('@' strings) the string
            % value is restored, and then re-parsed in setValue. This is a
            % bit slower but this function is only called in the ITI so
            % this should not be a problem. The advantage is that
            % parameters can be constants in some conditions and functions
            % in others.
        end
        
        %% Functions to extract parm values from the log. use this to analyze the data
        function [data,trial,trialTime,time,block] = get(o,varargin)
            % For any parameter, returns up to five  vectors specifying
            % the values of the parameter during the experiment
            % data = values
            % trial = trial in whcih that value occurred
            % trialTime = Time relative to start of the trial
            % time  = time relative to start of the experiment
            % block = the block in which this trial occurred.
            %
            % Because parameters are logged only when they change,there are
            % additional input arguments that can be provided to put the
            % parameter valus in a more useful format. The raw values should
            % be inspected carefully and require parsing the trial and time
            % values for their correct interpretation.
            %
            % 'atTrialTime'   - returns exactly one value for each trial
            % that corresponds to the value of the parameter at that time in
            % the trial. By setting this to Inf, you get the last value in
            % the trial.
            % 'after' - specify an event and you'll get the first value
            % after this event.
            % 'trial'  - request only entries occuring in this set of
            % trials.
            %
            p =inputParser;
            p.addParameter('atTrialTime',[],@isnumeric); % Return values at this time in the trial
            p.addParameter('after','',@ischar); % Return the first value after this event in the trial
            p.addParameter('trial',[],@isnumeric); % Return only values in these trials
            p.parse(varargin{:});
            
            data = o.log(1:o.cntr);
            trial =o.trial(1:o.cntr);
            time = o.time(1:o.cntr);
            trialTime = t2t(o,time,trial,true);
            block =NaN(1,o.cntr); % Will be computed if requested
            
            % Now that we have the raw values, we can remove some of the less
            % usefel ones and fill-in some that were never set (only changes
            % are logged to save space).
            
            maxTrial = max(o.plg.cic.prms.trial.trial);%
            
            if ~isempty(p.Results.atTrialTime) || ~isempty(p.Results.after)
                % Return values in each trial as they were defined at a
                % certain time in that trial. By specifying atTrialTime inf,
                % you get the last value in the trial.
                if ~isempty(p.Results.after)
                    % Find the last time this event occurred in each trial
                    [~,aTr,aTi,atETime] = get(o.plg.prms.(p.Results.after) ,'atTrialTime',inf); %#ok<ASGLU>
                else
                    atETime = o.t2t(p.Results.atTrialTime,1:maxTrial,false); % Conver to eTime
                end
                % For each trial, find the value at the given experiment time
                ix = nan(1,maxTrial);
                for tr=1:maxTrial
                    % Find the last before the set time, but only those that
                    % happend in the current tr or earlier.
                    thisIx = find(time<=atETime(tr) & trial<=tr,1,'last');
                    if ~isempty(thisIx)
                        ix(tr) = thisIx;
                    end
                end
                %
                out  =isnan(ix);
                ix(out)=1;
                data=data(ix);
                trial = 1:maxTrial; % The trial where the event set came from is trial(ix);
                time = time(ix);
                trialTime = trialTime(ix);
                
                if any(out)
                    data(out)=[];
                    trial(out) = [];
                    time(out) = [];
                    trialTime(out) =[];
                end
                
                if nargout >4
                    % User asked for block information
                    [block,blockTrial]= get(o.plg.cic.prms.block,'atTrialTime',Inf); % Blck at end of trial
                    [yesno,ix] = ismember(trial,blockTrial);
                    if all(yesno)
                        block = block(ix)';
                    else
                        block = NaN; % Should never happen...
                    end
                end
                
                if iscell(data) && all(cellfun(@(x) (isnumeric(x) || islogical(x)),data))
                    if all(cellfun(@(x) (size(x,1)==1),data))
                        try
                            data = cat(1,data{:});
                        catch me %#ok<NASGU>
                            % Failed. keep the cell array
                        end
                    elseif all(cellfun(@(x) (size(x,2)==1),data))
                        try
                            data = cat(2,data{:});
                        catch me %#ok<NASGU>
                            % Failed. keep the cell array
                        end
                    end
                end
            end
            
            if ~isempty(p.Results.trial)
                stay = ismember(trial,p.Results.trial);
                data=data(stay);
                trial = trial(stay);
                time = time(stay);
                trialTime = trialTime(stay);
                block = block(stay);
            end
            
            if isvector(data)
                data=data(:);
            end
            trialTime = trialTime(:);
            time = time(:);
            block = block(:);
            trial = trial(:);
            
            
        end
        
        
        function v= t2t(o,t,tr,ET2TRT)
            % Find the time that each trial started by looking in the cic events log.
            beforeFirstTrial = tr==0;
            tr(beforeFirstTrial) =1;
            trialStartTime = o.plg.cic.prms.trialStartTime.time;
            afterLastTrial = tr > numel(trialStartTime);
            tr(afterLastTrial) = 1;
            if ET2TRT
                v= t-trialStartTime(tr);
            else
                v= t+trialStartTime(tr);
            end
            v(beforeFirstTrial) = -Inf;
            v(afterLastTrial) = +Inf;
        end
        
        
        
        
    end
    
    methods (Access = protected, Sealed)
        function o2= copyElement(o)
            % This protected function is called from the public (sealed)
            % copy member of matlab.mixin.Copyable.
            
            % Example:
            % b=copyElement(a)
            % This will make a copy (with separate properties) of a in b.
            % This in contrast to b=a, which only copies the handle (so essentialy b==a).
            
            % First a shallow copy of fixed properties
            o2 = copyElement@matlab.mixin.Copyable(o);
            
        end
    end
    
    
    
end

