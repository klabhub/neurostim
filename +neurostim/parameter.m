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
    % getmet
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
    
    properties (SetAccess= {?neurostim.plugin}, GetAccess=  public)
        sticky;                     % set this to true to make value(s) sticky, i.e., across trials
        % To do this for a previously defined
        % parameter, call
        % makeSticky(plugin,parameterName)
        
        changesInTrial;             % Flag to indicate that this prm is changed within the trial frame loop
        % To set this for a previously defined parameter call
        % setChangesInTrial(plugin,parameterName) in your stimulus/plugin
        % class.
         
        
        hDynProp;                   % Handle to the dynamic property. See pulgin.updateClassdef for why this needs plugin write access
        plg; %@neurostim.plugin;    % Handle to the plugin that this belongs to.     

    end
    
    properties (SetAccess= protected, GetAccess=public)
        
        name;                       % Name of this property
        value;                      % Current value
        default;                    % The default value; set at the beginning of the experiment.
        log;                        % Previous values;
        time;                       % Time at which previous values were set
        cntr=0;                     % Counter to store where in the log we are.
        capacity=0;                 % Capacity to store in log
        noLog;                      % Set this to true to skip logging
        fun =[];                    % Function to allow across parameter dependencies
        funPrms;
        funStr = '';                % The neurostim function string
        validate =[];               % Validation function
        hasLocalized;               % Flag to indicate whether the plugin has a localized variable for this parameter (i.e. loc_X for X). Detected on construction
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
            
            %Handle post-hoc construction from loadobj()
            if isstruct(p)
                f = intersect(properties(o),fieldnames(p));
                for i=1:numel(f)
                    o.(f{i}) = p.(f{i});
                end
                return
            elseif isa(p,'neurostim.parameter')
                o=p;
                return;
            end
            
            %Regular construction
            o.name = nm;
            o.plg = p; % Handle to the plugin
            o.hDynProp  = h; % Handle to the dynamic property
            o.validate = options.validate;
            o.noLog = options.noLog;
            o.sticky = options.sticky;
            o.changesInTrial = options.changesInTrial;
            o.hasLocalized = checkLocalized(o.plg,nm);
            if p.cic.loadedFromFile % We are loading from file, don't call the code below as it needs PTB for GetSecs.
                return;
            end
            setupDynProp(o,options);
            % Set the current value. This logs the value (and parses the
            % v if it is a neurostim function string)
            
            %Deal with special case of empty vector. Won't be logged now unless we do something
            %because the new value (v) matches the current value (o.value). So, we temporarily
            %set it to something weird so that storeInLog() finds no match and hence logs it.
            if isempty(v)
                o.value = {'this is a highly unlikely value that will no be logged anyway'};
            end
            
            %Set it and log it
            setValue(o,[],v);
        end
        
        function stopLog(o)
            o.noLog =true;
        end
        
        function startLog(o)
            o.noLog =false;
        end
        
        function setupDynProp(o,options)
            % Set the properties of the dynprop that corresponds to this
            % parm
            
            % These are false because we do not use preGet, postSet and
            % making the prop unobservable allows the JIT compiler to do
            % better optimization.
            o.hDynProp.SetObservable  = false;
            o.hDynProp.GetObservable  = false;
            o.hDynProp.AbortSet       = false; % Always false
            if ~isempty(options)
                o.hDynProp.GetAccess = options.GetAccess;
                o.hDynProp.SetAccess = options.SetAccess;
            end
            % Install two callback functions that will be called for
            % getting and setting of the dynprop
            o.hDynProp.SetMethod =  @o.setValue;
            o.hDynProp.GetMethod =  @o.getValue;
        end
        
        function o = duplicate(p,plgn,h)
            % Duplicate a parameter so that it can be used in a differnt
            % plugin, with a different dynprop
            o = copyElement(p); % Deep copy
            o.plg = plgn; % Change the plugin
            o.hDynProp = h; % Change the dynprop
            setupDynProp(o,[]); % Setup the callback handlers (no options; keep Set/Get as is).
        end
        
        
        function storeInLog(o,v,t)
            % Store and Log the new value for this parm
            
            
            % Check if the value changed and log only the changes.
            % (at some point this seemed to be slower than just logging everything.
            % but tests on July 1st 2017 showed that this was (no longer) correct.
            if  (isnumeric(v) && numel(v)==numel(o.value) && isnumeric(o.value) && isequaln(v(:),o.value(:))) || (ischar(v) && ischar(o.value) && strcmp(v,o.value))
                % No change, no logging.
                return;
            end
            
            % For non-function params this is the value that will be
            % returned to the next getValue
            o.value = v;
            
            if o.noLog
                return
            end
            
            % Keep a timed log.
            o.cntr=o.cntr+1;
            % Allocate space if needed
            if o.cntr> o.capacity
                o.log       = cat(2,o.log,cell(1,o.BLOCKSIZE));
                o.time      = cat(2,o.time,nan(1,o.BLOCKSIZE));
                o.capacity = numel(o.log);
            end
            %% Fill the log.
            if isa(v,'neurostim.plugins.adaptive')
                v = getValue(v);
            end
            o.log{o.cntr}  = v;
            o.time(o.cntr) = t; % Avoid the function call to cic.clockTime
        end
        
        function v = getValue(o,~)
            % The dynamic property uses this as its GetMethod
            if isempty(o.fun)
                v = o.value;
            else
                % The dynamic property defined with a function uses this as its GetMethod
                v=o.fun(o.funPrms);
                %The value might have changed, so allow it to be logged if need be
                t = GetSecs*1000;
                storeInLog(o,v,t);
            end
        end
        
        function setValue(o,~,v)
            
            
            %Check the clock immediately. If we need to log, this is the most accurate time-stamp.
            t = GetSecs*1000;
            
            
            %Check for a function definition
            if strncmpi(v,'@',1)
                % The dynprop was set to a neurostim function
                % Parse the specified function and make it into an anonymous function.
                o.funStr = v; % store this to be able to restore it later.
                o.changesInTrial = true; % At least potentially; we'll mark this as a parm that needs to be updated each frame
                %If we are still at setup (i.e. not run-time), don't build the function b/c referenced objects might not exist yet.
                %It will happen once c.run() starts using o.funStr
                if o.plg.cic.stage >o.plg.cic.SETUP
                    %Construct the anonymous function (f(args), where args are neurostim.parameter handles)
                    %If still in setup, the function properties will just return the function string
                    [o.fun,o.funPrms] = neurostim.utils.str2fun(v,o.plg.cic);
                    
                    % Evaluate the function to get current value
                    v= getValue(o);
                else
                    %Add it to the list of functions to be made at runtime.
                    addFunProp(o.plg.cic,o.plg.name,o.hDynProp.Name)
                end
            elseif ~isempty(o.fun)
                % This is currently a function, and someone is overriding
                % the parameter with a non-function value. Remove the fun.
                o.fun = [];
                o.funStr = '';
                o.funPrms = [];
                delFunProp(o.plg.cic,o.plg.name,o.hDynProp.Name);
                % lets keep changesInTrial...
            end
            
            
            % This parameter was actually changed during the trial, but
            % the user did not specify it as such.
            if ~o.changesInTrial && o.hasLocalized &&  o.plg.cic.stage == neurostim.cic.INTRIAL                
                setChangesInTrial(o.plg,o); % Add it to the list of parms that need to be updated before each frame.
                writeToFeed(o.plg,[o.name ' is changing within the trial; performance would improve with c.' o.plg.name '.setChangesInTrial(''' o.name ''') in your experiment file. (where ''c'' is your cic object)']);
                o.changesInTrial  = true;
            end
            
            % validate
            % AM: commented out because no action was being taken on validation fail
            % anyway. Perhaps it was deemed too costly?
            %
            %TODO: restore validation.
            
%             if ~isempty(o.validate)
%                 o.validate(v);
%             end
            
            % Log the new value
            storeInLog(o,v,t);
        end
        
        
        % Called before saving an object to clean out the empty elements in
        % the log.
        function pruneLog(o)
            out  = (o.cntr+1):o.capacity;
            o.log(out) =[];
            o.time(out) =[];
            o.capacity = numel(o.log);
        end
        
        % Called to store the current value in the default value. This
        % allows us to reset the parms to their default at the start of a
        % trial (before applying condition specific modifications).
        function setCurrentToDefault(o)
            if o.sticky
                return
            end
            
            if isempty(o.fun)
                o.default = o.value;
            else
                o.default = o.funStr;
            end
        end
        
        function setDefaultToCurrent(o)
            if o.sticky
                return
            end
            
            % Put the default back as the current value
            setValue(o,[],o.default);
            
            % Note that for Neurostim functions ('@' strings) the string
            % value is restored, and then re-parsed in setValue. This is a
            % bit slower but this function is only called in the ITI so
            % this should not be a problem. The advantage is that
            % parameters can be constants in some conditions and functions
            % in others.
        end
        
        function replaceLog(o,val,eTime)
            % This function replaces the log and time values with new
            % values. We use this, for instance, to re-time the button
            % presses of the Vpixx response box in terms of PTB time.
            if size(val,2)~=numel(eTime)
                warning('Mismatch between the number of values and time points in replaceLog ');
            end
            o.log = val;
            o.time = eTime(:)'; % Row
            o.capacity = numel(val);
            o.cntr = numel(val);
        end
        %% Functions to extract parm values from the log. use this to analyze the data
        function [data,trial,trialTime,time,block,frame] = get(o,varargin)
            % Usage example:
            %     [data,trial,trialTime,time,block] = get(c.dots.prms.Y,'atTrialTime',Inf)
            %     data = get(c.dots.prms.Y,'struct',true)
            %
            % For any parameter, returns up to five vectors (or a struct with five fields)
            % specifying the values of the parameter during the experiment:
            %
            % data = values
            % trial = trial in which that value occurred
            % trialTime = Time relative to start of the trial
            % time  = time relative to start of the experiment
            % block = the block in which this trial occurred.
            % frame = the value of c.frame at the time the event was logged (i.e. the c.run() loop number).
            %
            % Optional input arguments as param/value pairs:
            %
            % 'atTrialTime'   - returns exactly one value for each trial
            % that corresponds to the value of the parameter at that time in
            % the trial. By setting this to Inf, you get the last value in
            % the trial.
            % 'after' - specify an event and you'll get the first value
            % after this event.
            % 'trial'  - request only entries occuring in this set of
            % trials.
            % 'withDataOnly' - return only events with data.
            % 'dataIsMember' - return only those events where the data
            % matches this cell/vector of elements.
            % 'struct' - set to true to return all outputs as a data structure
            % 'first' - return the first N (applied after all other
            % selections)
            % matrixIfPossible if set to true [default] it will try to
            % convert the data to a [NRTRIALS N] matrix. This is somewhat
            % time consuming, so use sparingly.
                        
            maxTrial = o.plg.cic.prms.trial.cntr-1; % trial 0 is logged as well, so -1
            
            p =inputParser;
            p.addParameter('atTrialTime',[],@isnumeric); % Return values at this time in the trial
            p.addParameter('after','',@ischar); % Return the first value after this event in the trial
            p.addParameter('trial',[],@(tr) isnumeric(tr) && all(tr<=maxTrial & tr > 0)); % Return only values in these trials
            p.addParameter('withDataOnly',false,@islogical); % Only those values that have data
            p.addParameter('dataIsMember',{});  %Only when data is a member of the list
            p.addParameter('dataIsNotNan',false,@islogical);%Only when data is not nan.
            p.addParameter('matrixIfPossible',true); % Convert to a [NRTRIALS N] matrix if possible
            p.addParameter('struct',false,@islogical); % Pack the output arguments into a structure.
            p.addParameter('first',inf); % Return the first N (defaults to all =inf)            
            p.parse(varargin{:});
            returnMatrixIfPossible = p.Results.matrixIfPossible;
            
            %% Extract the raw data from the log. All as single column.
            data = o.log(1:o.cntr)';
            time = o.time(1:o.cntr)'; % Force a column for consistency.           
            [trialTime, trial] = o.eTime2TrialTime(time);
            
            %% Correct times
            %If the parameter is a stored value from flip(), use the data as the time rather than the time it was logged.
            isStimOnOrOff = (ismember(o.name,{'startTime','stopTime'}) && isa(o.plg,'neurostim.stimulus'));
            isTrialStopTime = ismember(o.name,{'trialStopTime'}) && isa(o.plg,'neurostim.cic');
            isFirstFrame = strcmp(o.name,'firstFrame') && isa(o.plg,'neurostim.cic');
            if isFirstFrame
                % Trial time for first frame is zero by definition.
                % And the experiment time is retrieved from the stored data
                % (in .firstFrameTime).
                % The offset between the time when the event occurred
                % (Screen('Flip')) and the time it was logged is stored as
                % the data - this can be useful for someone using this.
                time = o.firstFrameTime;
                trial= (1:numel(time))';
                data = num2cell(trialTime(2:end));  % Store the offset (ix 1 is always nonsense)
                trialTime = zeros(size(time));
                block = NaN(size(time));
            elseif isTrialStopTime
                out = cellfun(@isempty,data); % Loggin error
                data(out) = [];
                trial(out) = [];
                out = [false; diff(trial)==0]; % Duplicate possible in last trial.
                data(out) = [];
                trial(out) = [];
                tmpTrialTime =cell2mat(data); % This is relative to firstFrame ptbStimOnset
                time = inf(maxTrial,1);
                time(trial) = tmpTrialTime;
                trialTime = inf(maxTrial,1);
                trialTime(trial) = tmpTrialTime-o.firstFrameTime;
                trial = (1:maxTrial)';
                block = nan(maxTrial,1);
                data = cell(maxTrial,1);
                [data{:}] = deal(NaN);%Replace data with NaNs to force external use of trialTimes and not data
            elseif isStimOnOrOff
                % Adjust the times for all entries that were flip synced to
                % match the time returned by Screen('Flip')
                % If the start or stop never occurred the time is Inf.
                out = cellfun(@isempty,data);
                data(out) = [];
                trial(out) = [];
                tmpTrialTime =cell2mat(data); % This is relative to firstFrame ptbStimOnset
                out = isinf(tmpTrialTime); % The inf's are logging artefacts. Remove.
                tmpTrialTime(out) = [];
                trial(out) = [];
                ffTime = o.firstFrameTime;
                tmpTime = tmpTrialTime + ffTime(trial);
                time = inf(maxTrial,1);
                time(trial) = tmpTime;
                trialTime = inf(maxTrial,1);
                trialTime(trial) = tmpTrialTime;
                trial = (1:maxTrial)';
                block = nan(maxTrial,1);
                data = cell(maxTrial,1);
                [data{:}] = deal(NaN);%Replace data with NaNs to force external use of trialTimes and not data
            else
                % Nothing to do
            end
            
            %% Select from the raw events or fill in from "previous" trials
            if ~isempty(p.Results.atTrialTime) || ~isempty(p.Results.after)
                % Return values in each trial as they were defined at a
                % certain time in that trial. By specifying atTrialTime inf,
                % you get the last value in the trial.
                if ~isempty(p.Results.after)
                    % Find the last time this event occurred in each trial
                    [~,aTr,aTi,atETime] = get(o.plg.prms.(p.Results.after) ,'atTrialTime',inf,'matrixIfPossible',false); %#ok<ASGLU>
                    withinTrialOnly = true;
                    if ~isempty(p.Results.atTrialTime)
                        atETime = atETime+p.Results.atTrialTime; % Interpret atTrialTime as the time after the .after event.
                    end
                    % becuase atTrialTime defaults to empty, just using
                    % .after means at the time the .after event occurred.
                else
                    atETime = o.trialTime2ETime(p.Results.atTrialTime,1:maxTrial); % Conver to eTime
                    withinTrialOnly = false;
                end
                % For each trial, find the value at the given experiment time
                nrTrialTimes= max(1,numel(p.Results.atTrialTime));
                newData =cell(maxTrial,1);
                ix = nan(maxTrial,nrTrialTimes);
                for tr=1:maxTrial
                    % Find the last before the set time, but only those that
                    % happend in the current tr or earlier.
                    for tt =1:nrTrialTimes
                        if withinTrialOnly
                            stayTrial =trial==tr;
                        else
                            stayTrial = trial<=tr;
                        end
                        thisIx = find(time<=atETime(tr,tt) & stayTrial,1,'last');
                        if ~isempty(thisIx)
                            ix(tr,tt) = thisIx;
                        end
                    end
                    if ~isnan(ix(tr,:)) 
                        if  returnMatrixIfPossible 
                            newData{tr} =  neurostim.parameter.matrixIfPossible([data{ix(tr,:)}]);
                        else
                            newData(tr) =  data(ix(tr,:));
                        end
                    end
                end
                %
                out  =isnan(ix);
                ix(out)=1;
                data=newData;
                trial = repmat((1:maxTrial)',[1 nrTrialTimes]); % The trial where the event set came from is trial(ix);
                time = time(ix);
                trialTime = trialTime(ix);
                
                
                if any(out)
                    trial(out) = NaN;
                    time(out) = NaN;
                    trialTime(out)= NaN;
                end
                
                
            end
            
            % Some more pruning if requested
            out = false(size(data));
            
            %% Prune if requested
            if ~isempty(p.Results.trial)
                out = out | ~ismember(trial,p.Results.trial);
            end
            
            if p.Results.withDataOnly
                out  = out | cellfun(@isempty,data);
            end
            
            if p.Results.dataIsNotNan
                if ~isempty(cell2mat(data))
                    n = zeros(numel(data),1); % initiate a NaN label, default to false
                    n(~cellfun(@isempty,data)) = any(isnan(cell2mat(data)),2); % fill in true for trials containing NaN
                    out  = out | n;
                end
            end
            
            if ~isempty(p.Results.dataIsMember)
                % Check whether data is a member of p.Results.dataIsMember
                % - Note that empty never matches.
                out = out | cellfun(@(x)(isempty(x) || ~ismember(x,p.Results.dataIsMember)),data);
            end
            
            % Prune
            data(out) =[];
            time(out,:) =[];
            
            trial(out,:) =[];
            trialTime(out,:)=[];
            
            
            
            if ~isinf(p.Results.first)
                % Take first N in each trial
                out =false(size(data));
                for tr = unique(trial)'
                    stay = trial==tr;
                   out = out | cumsum(stay)>p.Results.first;
                end
            end
            
            
            
            if returnMatrixIfPossible 
                data=  neurostim.parameter.matrixIfPossible(data);
            end
            
            if nargout >4 || p.Results.struct
                % User asked for block information
                block= get(o.plg.cic.prms.block,'atTrialTime',0,'matrixIfPossible',false); % Blck at end of trial
                block = [block{trial}]'; % Match other info that is returned. Make it a column vector to match other data/trial info.
            end
            
            if (nargout >5 || p.Results.struct) && ~strcmp(o.name,'frameDrop')
                % User asked for the c.frame number (loop number)
                % c.frame is not logged, so we need to get frame drops and work back
                % from there. c.frame increments once per loop in c.run()
                %
                timeShift = 0; %Will be changed below if there are drops
                [fdData,fdTrial,fdTrialTime] = get(o.plg.cic.prms.frameDrop,'trial',trial);
                if ~isempty(fdData)
                    kill = isnan(fdData(:,1)); %frameDrop initialises to NaN
                    fdData(kill,:) = []; fdTrial(kill) = []; fdTrialTime(kill)=[];
                    if ~isempty(fdData)
                        %Convert trialTime to frames
                        trialTime_fr = o.plg.cic.ms2frames(trialTime);
                        
                        %What time did drops happen? Convert that to frames too
                        timeOfDrop_fr = o.plg.cic.ms2frames(fdTrialTime);
                        
                        %How much time was added at each drop?
                        durOfDrop_ms = (1000*fdData(:,2));
                        
                        %Count how many were dropped in total prior to the logged time of the event
                        totTimeAdded = @(tr,t) sum(durOfDrop_ms(fdTrial==tr & timeOfDrop_fr<=t));
                        timeShift = arrayfun(totTimeAdded,trial,trialTime_fr);
                    end
                end
                %Shift event in time and convert to cic frame number (+1 becaude c.frame==1 when t==0)
                frame = o.plg.cic.ms2frames(trialTime-timeShift)+1;
            else
                frame = nan(numel(trialTime),1);
            end
            
            if p.Results.struct
                %Return everything in a structure (done this way rather than using struct() because that function returns a struct array when "data" is a cell array)
                tmp.data = data; tmp.trial = trial; tmp.trialTime = trialTime; tmp.time = time; tmp.block = block; tmp.frame = frame;
                data = tmp;
            end
        end
        
        
        function t = trialStartTime(o)
            % Return the time that the trial started
            %
            % Note: this is *not* the time of the first frame of the
            %       stimulus on each trial... for that see firstFrameTime()
            %       below.
            %
            %       Event trialTimes returned by get() are relative to firstFrame
            tr = [o.plg.cic.prms.trial.log{:}]; % This includes trial=0
            t = o.plg.cic.prms.trial.time;   % Start of the trial
            t(tr==0) = [];
            t(isnan(t))= [];
            %assert(numel(t)<=o.plg.cic.nrTrialsTotal,'The trial counter %d does not match the number of started trials (%d)',o.plg.cic.nrTrialsTotal,numel(t));
        end
        
        function t = firstFrameTime(o)
            %  t = firstFrameTime(o)
            % Return the time of the first frame in each trial, as a column
            % vector.  
            t = [o.plg.cic.prms.firstFrame.log{:}]'; % By using the log we use the stimOnsetTime returned by Screen('flip') on the first frame.
            % BK NOTE: using o.plg.cic.trial (the dynprop) here leads to
            % load errors (i.e. when reading data from file) with Matlab complaining that .trial is not a property. I dont understand why 
            % findprop finds the property at load time in cic.loadobj. THis
            % fix (Reading from .prms instead of the dynprop) seems harmless but maybe the error is a sign of a
            % bigger/different problem.
            if o.plg.cic.prms.trial.value >numel(t)  
                % A trial has started but not reached first frame yet. Set
                % its start time to inf.
                t = [t;inf];
            end
        end
        
        function tr = eTime2TrialNumber(o,eventTime)
            % tr = eTime2TrialNumber(o,eventTime)
            % Returns the trial corresponding to an experiment time.
            %
            trStartT = trialStartTime(o);
            tr= nan(size(eventTime));
            for i=1:numel(eventTime)
                tempTr = find(trStartT <= eventTime(i),1,'last');
                if isempty(tempTr)
                    tempTr = 1;
                end
                tr(i) = tempTr;
            end
        end
        
        function [trTime,tr]= eTime2TrialTime(o,eventTime)
            % [trTime,tr]= eTime2TrialTime(o,eventTime)
            % Returns a [nrTrials nrTimes] matrix/vector of trial
            % times for a given (vector of) experiment times.
            % and a [nrTimes] vector with the corresponding trial numbers.
            tr = eTime2TrialNumber(o,eventTime);
            trStartT = firstFrameTime(o);
            if isempty(trStartT) &&  all(tr==1)
                error('This file contains 1 trial that did not even make it to the first frame. Nothing to analyze');
            end
            trTime = eventTime - trStartT(tr);            
        end
        
        function eTime= trialTime2ETime(o,trTime,tr)
            %  eTime= trialTime2ETime(o,trTime,tr)
            % Returns a [nrTrials nrTimes] matrix/vector of experiment
            % times for a given (vector of) trial times.
            if iscolumn(trTime)
                trTime = trTime';
            end
            trStartT = firstFrameTime(o);                                    
            eTime = repmat(trTime,[numel(trStartT) 1]) + repmat(trStartT(tr),[1 numel(trTime)]);
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
    
    methods (Static)
        function data = matrixIfPossible(data)
            % Try to convert to a matrix 
            % cellstr conversion to a char array can lead to weird
            % reshaping;  excluded
            % Some properties are initial as an empty struct with not
            % fields, but get fields at some point in the trial. Cannot
            % concatenate those; so exclude.
            isStructNoFields =  @(x) (isstruct(x) && numel(fieldnames(x))==0);
            if iscell(data) && any(diff(cellfun(isStructNoFields,data))~=0); return;end
            
            % First check whether this conversion could work (same size ,
            % same type)            
            if iscell(data) && ~isempty(data) && ~iscellstr(data) && ~isa(data{1},'function_handle') ...               
                && (all(cellfun(@(x) (strcmpi(class(data{1}),class(x))),data)) || all(cellfun(@(x) (isnumeric(x) || islogical(x)),data)))...
                && all(cellfun(@(x) isequal(size(data{1}),size(x)),data))
                %Look for a singleton dimension
                sz = size(data{1});
                catDim = find(sz==1,1,'first');
                if isempty(catDim)
                    %None found. Matrix. So we'll add a dimension.
                    catDim = numel(sz)+1;
                end
                
                %Convert to matrix
                if all(cellfun(isStructNoFields,data))
                    % Replace a struct with no fields with a logical
                    data  = true(size(data));
                else
                    data = cat(catDim,data{:});                     
                end
                %Put trials in the first dimension
                data = permute(data,[catDim,setdiff(1:numel(sz),catDim)]);
            end            
        end
        
        function o = loadobj(o)
            %Parameters that were initialised to [] and remained empty were not logged properly
            %on construction in old files. Fix it here
            if ~o.cntr
                o.cntr = 1;
                o.log{1} = [];
                o.time = -Inf;
            end
            
            o = neurostim.parameter(o);
        end
        
    end
    
    
    
end

