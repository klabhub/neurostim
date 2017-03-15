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
    % Each parameter installs a preget (getValue) and a postset (setValue)
    % callback handler on % the dynamic property in the plugin that this
    % parameter belongs to.
    % For instance, the grating.X dynamic property is associated with a
    % parameter (stored as grating.prms.X) and each time a user requests
    % grating.X, the getValue(gratings.prms.X) function is called. This
    % function assigns the correct value to the dynamic property (for instance
    % by evaluating a neurostim function). If the value changed it is logged.
    % Each time the  user assigns a value to the property, setValue(gratings.prms.X) is
    % called, this logs the change in value.
    %
    % BK - Feb 2017
    
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
        trial;    % Trial in which previous values were set.
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
            end
            
            % Setup listeners to get, log, and validate changes
            o.getListener  = p.addlistener(nm,'PreGet',@(src,evt)getValue(o,src,evt));
            o.setListener = p.addlistener(nm,'PostSet',@(src,evt)setValue(o,src,evt));
            o.value = v; % Store the current value in this paramter object
            o.plg.(nm) = v; % Assign the current value to the dynamic property. This is done to log the current value.
        end
        
        function storeInLog(o,v)
            % Store and Log
            o.value =v;
            t = o.plg.cic.clockTime;
            o.cntr=o.cntr+1;
            % Allocate space if needed
            if o.cntr> o.capacity
                o.log       = cat(2,o.log,cell(1,o.BLOCKSIZE));
                o.time      = cat(2,o.time,nan(1,o.BLOCKSIZE));
                o.trial       = cat(2,o.trial,nan(1,o.BLOCKSIZE));
                o.capacity = numel(o.log);
            end
            %% Fill the log.
            o.log{o.cntr}  = v;
            o.time(o.cntr) = t;
            o.trial(o.cntr)= o.plg.cic.trial;
        end
        
        % This function is called before the dynprop is used somewhere in the code.
        % It allows us to evaluate functions.
        function [v,ok] = getValue(o,src,evt) %#ok<INUSD>
            if isempty(o.fun)
                % Simple value.
                % In principle this could be stored directly in the
                % dynprop, but then we'd have to keep track of parameters
                % with and without listeners.
                v= o.value;
                o.setListener.Enabled = false; % Avoid a 'postset' call
                o.plg.(o.name) = v; % Assign the current value to the dynprop
                o.setListener.Enabled = true; % Avoid a 'postset' call
                ok = true;
            elseif o.plg.cic.stage >o.plg.cic.SETUP
                % We've passed SETUP phase, function evaluaton should be
                % possible.
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
            else  % -a  function but not all objects have been setup so
                % function evaluation may not work yet. Evaluate to NaN for now
                % We don't actually assign this to the dynprop.
                v = NaN;
                ok = false;
            end
        end
        
        % This function is called after each parametr set
        function setValue(o,src,evt) %#ok<INUSD>
            % First, retrieve the value that the dynprop was just set to.
            o.getListener.Enabled = false; % Avoid a 'preget' call
            v= o.plg.(o.name); % The raw value that has just been set
            o.getListener.Enabled = true; % Allow preget calls again
            ok = true; % Normally ok; only function evals can be not ok.
            %Check for a function definition
            if strncmpi(v,'@',1)
                % Parse the specified function and make it into an anonymous
                % function.
                v = neurostim.utils.str2fun(v);
            end
            if isa(v,'function_handle')
                o.fun = v;
                % Evaluate the function (without calling set again)
                o.setListener.Enabled = false;
                [v,ok]= getValue(o); %ok will be false if the function could not be evaluated yet (still in SETUP phase).
                o.setListener.Enabled = true;
            elseif ~o.isFunResult
                % This is currently a function, and someone is overriding
                % the parameter with a non-function value. Remove the fun.
                o.fun = [];
            end
            
            % validate
            if ~isempty(o.validate) && ok
                o.validate(v);
            end
            
            if ok
                % assign in this object, log, and assign to dynamic prop.
                storeInLog(o,v); % Log and store in this parameter object
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
                o.default = o.fun;
            end
        end
        
        function setDefaultToCurrent(o)
            % Put the default back as the current value
            o.plg.(o.name) = o.default;
            % We are doing this even for @function defaults, which is
            % consistent but it takes more time presumably (to parse etc).
            % Because this is done in the ITI it probably does not matter.
        end
        
        %% Functions to extract parm values from the log
        function [data,trial,trialTime,time,block] = get(o,varargin)
            % For any parameter, returns up to four vectors specifying
            % the values of the parameter during the experiment
            % data = values
            % trial = trial in whcih that value occurred
            % trialTime = Time relative to start of the trial
            % time  = time relative to start of the experiment
            %
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
            %
            p =inputParser;
            p.addParameter('atTrialTime',[],@isnumeric); % Return values at this time in the trial
            p.addParameter('after','',@ischar); % Return the first value after this event in the trial
            p.addParameter('trial',[],@isnumeric); % Return only values in these trials
            p.parse(varargin{:});
            
            % Try to make a matrix
            if all(cellfun(@(x) (isnumeric(x) || islogical(x)),o.log(1:o.cntr))) && all(cellfun(@(x) (size(x,1)==1),o.log(1:o.cntr)))
                try
                    data = cat(1,o.log{1:o.cntr});
                catch me
                    % Failed. keep the cell array
                    data = o.log(1:o.cntr);
                end
            else
                data = o.log(1:o.cntr);
            end
            trial =o.trial(1:o.cntr);
            time = o.time(1:o.cntr);
            trialTime = t2t(o,time,trial,true);
            block =nans(1,o.cntr); % Will be computed if requested 
                
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
                    [~,aTr,aTi,atETime] = get(o.plg.prms.(p.Results.after) ,'atTrialTime',inf);
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
                if iscell(data)
                    data=data(ix);
                else
                    data = data(ix,:);
                end
                trial = 1:maxTrial; % The trial where the event set came from is trial(ix);
                time = time(ix);
                trialTime = trialTime(ix);
                if any(out)
                    if iscell(data)
                        data{out} = NaN;
                    else
                        data(out)=NaN;
                    end
                    trial(out) = NaN;
                    time(out) = NaN;
                    trialTime(out) = NaN;
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
            if ET2TRT
                v= t-trialStartTime(tr);
                v(beforeFirstTrial) = -Inf;
            else
                v= t+trialStartTime(tr);
            end
        end
        
        
        
        
    end
    
    
end