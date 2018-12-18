classdef plugin  < dynamicprops & matlab.mixin.Copyable & matlab.mixin.Heterogeneous
    % Base class for plugins. Includes logging, functions, etc.
    %
    properties (SetAccess=public)
        cic;  % Pointer to CIC
        overlay@logical=false; % Flag to indicate that this plugin is drawn on the overlay in M16 mode.
        window;
        feedStyle = '[0 0.5 0]'; % Command line color for writeToFeed messages.
    end
    
    
    
    properties (SetAccess=private, GetAccess=public)
        name@char= '';   % Name of the plugin; used to refer to it within cic
        prms=struct;          % Structure to store all parameters
    end
    
    methods (Static, Sealed, Access=protected)
        function o= getDefaultScalarElement
            o = neurostim.plugin([],'defaultScalarElement');
        end
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
        
        
        function addKey(o,key,keyHelp,isSubject,fun)
            %  addKey(o,key,keyHelp,isSubject,fun)
            % Runs a function in response to a specific key press.
            % key - a single key (string)
            % keyHelp -  a string that explains what this key does
            % isSubject - bool to indicate whether this is a key press the
            % subject should do. (Defaults to true for stimuli, false for
            % plugins)
            % The user must implement keyboard(o,key) or provide a
            % handle to function that takes a plugin/stimulus and a key as
            % input.
            nin =nargin;
            if nin<5
                fun =[];
                if nin < 4
                    isSubject = isa(o,'neurostim.stimulus');
                    if nin <3
                        keyHelp = '?';
                    end
                end
            end
            addKeyStroke(o.cic,key,keyHelp,o,isSubject,fun);
        end
        
        % Convenience wrapper; just passed to CIC
        function endTrial(o)
            % Move to the next trial
            endTrial(o.cic);
        end
        
        %% User output Functions
        % writeToFeed(o,messageAsString)
        % writeToFeed(o,formatSpec, variables)  (as in sprintf)
        % Note that the style of the feed can be adjusted per plugin by
        % specifying the o.feedStyle: see styles defined in cprintf.
        function writeToFeed(o,varargin)
            nin =nargin;
            if nin==1
                formatSpec ='%s';
                args = {o.name};
            elseif nin==2
                formatSpec ='%s: %s';
                args = {o.name,varargin{1}};
            elseif nargin>2
                formatSpec = ['%s: ' varargin{1}];
                args = cat(2,{o.name},varargin(2:end));
            end
            o.cic.feed(o.feedStyle,formatSpec,o.cic.trial,o.cic.trialTime,args{:});
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
            p.addParameter('sticky',false,@islogical);
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
        
        
        
        function tbl = getBIDSTable(o,varargin)
            % Create a table that can be used to generate a BIDS .tsv file
            % from the properties and events in a plugin.
            % INPUT
            % plg =  the plugin/stimulus
            % tbl = Pass a previously constructed table to concatenate.
            % Parameter/Value pairs:
            % properties - Cell array of properties to extract- one value per trial.
            % propertyNames - containers.Map object to rename a property
            %                       to something else in the table. Optional.
            %                    containers.Map('mySillyName','A better Name')
            % propertyUnits - cell array of chars that specify the units for each
            %                   property. Optional. e.g. {'m','cd/m2'}
            % propertyLevels  - Cell array of containers.Map objects that specify the
            %                   relationship between levels (e.g. a number in the table
            %                  )and what that level means. Optional.
            % propertyDescription - longer description of what each column means
            % propertyProcessing - a containers.Map with anonymous functions that take
            %                   the raw property value and process it. The processed value is stored.
            % eventTimes   = cell array of properties whose time is stored in the
            % table.
            % eventNames  - containers.Map object to rename event times
            % eventDescriptions - cell array of longer descriptions
            % alignTime - the absolute (experiment) time that all event times should be
            %               aligned to. If this is not specified, the time of the first frame in the
            %               first trial is used. This only needs to be specified once on first construction
            %               of the table, not on subsequent calls that add columns.
            % atTrialTime  - Defaults to Inf. Time at which the properties
            %                   are evaluated. 
            % trial_type  - Specify which elements are used to determine
            %               trial_type. Defaults to '' (i.e. no trial_type column). This
            %               can be a cell array of strings with one entry per trial which
            %               is used as is, or one of 'designs', or 'blocks' to use the
            %                   names of the corresponding cic elements.
            %                   (c.blocks.design, or c.blocks,
            %                   respectively)
            % 
            % Example (From experiments/bart/cardgame)
            % tbl = getBIDSTable(c); % Setuo the basic sturcture (trials,
            % blocks etc)
            %  Cardgame Parameters
            % tbl = getBIDSTable(c.card,tbl,'properties',{'rewardFraction','guess','outcome','correct'},...
            %                                 'propertyDescription',{'Fraction of trials in which subject received reward', 'The subject''s guess','The card value ','Whether the subject guessed correctly or not'},...
            %                                  'propertyProcessing',containers.Map('outcome',@(v)([v{:}]')),...
            %                                  'propertyLevels',{'',containers.Map({'-1','1'},{'Low','High'}),'',containers.Map({'-1','0','1'},{'Incorrect','N/A','Correct'})});
            %
            %
            % Panas Parameters
            % tbl = getBIDSTable(c.panas,tbl,'properties',{'word','when','answer'},...
            %                                 'propertyDescription',{'Quality','Time Period','Subject Answer'},...
            %                                 'propertyProcessing',containers.Map({'word','when'},{@(v) ({c.panas.words{v}}'),@(v) ({c.panas.whens{v}}')}));
            %
            % See also saveBIDS and sib2bids
            %
            % BK  -Nov 2018
            p=inputParser;
            p.addOptional('tbl',table,@istable);
            p.addParameter('properties',{},@iscell);  % Cell array of property values to extract - one per trial
            p.addParameter('propertyNames',containers.Map,@(x) (isa(x,'containers.Map'))); % Map properties to names to use in the table
            p.addParameter('propertyUnits',{},@iscell);
            p.addParameter('propertyLevels',{},@iscell);
            p.addParameter('propertyDescriptions',{},@iscell);
            p.addParameter('propertyProcessing',containers.Map,@(x) (isa(x,'containers.Map'))); % Specify processing (a funciton handle) to apply to a propoerty
            p.addParameter('eventTimes',{},@iscell);% Cell array of event times to extract - one per trial
            p.addParameter('eventNames',containers.Map,@(x) (isa(x,'containers.Map'))); % Map properties to names to use in the table
            p.addParameter('eventDescriptions',{},@iscell);
            p.addParameter('eventGetArgs',{'atTrialTime',Inf},@iscell); % Passed to neurostim.parameter.get to select a subset of events
            p.addParameter('atTrialTime',Inf,@isnumeric);
            p.addParameter('alignTime',[]);
            p.addParameter('trial_type',{},@(x) (ischar(x) && ismember(upper(x),{'BLOCKS'})) || iscell(x)); %
            p.parse(varargin{:});
            tbl = p.Results.tbl;
            
            if isempty(tbl.Properties.Description) % Check Description as the table data is still empty on the firs recursive call 
                % Setup basic table properties on first construction
                tbl.Properties.Description = o.cic.file;
                tbl.Properties.DimensionNames = {'Trial','Variables'};
                tbl = addprop(tbl,'VariableLevels','Variable');
                if isempty(p.Results.alignTime)
                    % No special event specified. Use first frame event in first trial
                    [~,~,~,alignTime] = get(o.cic.prms.firstFrame,'trial',1);
                else
                    alignTime = p.Results.alignTime;
                end
                tbl = addprop(tbl,'AlignTime','Table');
                tbl.Properties.CustomProperties.AlignTime = alignTime;
                
                % Recursive call to this function to setup trial and block 
                tbl = getBIDSTable(o,tbl,'atTrialTime',0,'properties',{'trial','block','blockCntr'},...
                                    'propertyDescription',{'Trial numbers','Block Number','Block Counter'},...
                                    'eventTimes',{'firstFrame','trialStopTime'},...
                                    'eventNames',containers.Map({'firstFrame','trialStopTime'},{'onset','offset'}),...
                                    'eventDescription',{'Trial start time','Trial stop time'});
                tbl = addvars(tbl,tbl.offset-tbl.onset,'NewVariableNames',{'duration'});
                tbl.Properties.VariableUnits{end} = 's';
                tbl.Properties.VariableDescriptions{end} = 'Trial Duration';
                tbl = movevars(tbl,'duration','Before','offset'); %BIDS wants Onset first, then Duration
                
                if ~isempty(p.Results.trial_type)
                    if ischar(p.Results.trial_type) 
                        switch upper(p.Results.trial_type)                            
                            case 'BLOCKS'
                                % Use the names of the blocks
                                blockNames ={o.cic.blocks.name}';
                                trialTypeNames = blockNames(tbl.block); % One per trial
                        end
                        
                    elseif numel(p.Results.trial_type)==height(tbl)
                        trialTypeNames= p.Results.trial_type;
                    else
                        p.Results.trial_type
                        error('This trial_type specification does not parse');
                    end
                    tbl = addvars(tbl,trialTypeNames,'After','duration','NewVariableNames','trial_type');
                end 
                return;
            else
                alignTime = tbl.Properties.CustomProperties.AlignTime;
            end
            
            
            
            %% Parse the inputs and supply empty units/levels/descriptions if those
            % were not provided.
            if isempty(p.Results.propertyUnits)
                units = cell(1,numel(p.Results.properties));
                [units{:}] = deal('');
            else
                units = p.Results.propertyUnits;
                if numel(units) ~= numel(p.Results.properties)
                    error('Each property needs a propertyUnits entry. Specify '''' for properties that don''t have units')
                end
            end
            
            if isempty(p.Results.propertyLevels)
                levels = cell(1,numel(p.Results.properties));
                [levels{:}] = deal('');
            else
                levels= p.Results.propertyLevels;
                if numel(levels) ~= numel(p.Results.properties)
                    error('Each property needs a propertyLevel entry. Specify '''' for properties that don''t have levels')
                end
            end
            
            if isempty(p.Results.propertyDescriptions)
                propDescriptions = cell(1,numel(p.Results.properties));
                [propDescriptions{:}] = deal('');
            else
                propDescriptions = p.Results.propertyDescriptions;
                if numel(propDescriptions) ~= numel(p.Results.properties)
                    error('Each property needs a propertyDescriptions entry.')
                end
            end
            
            if isempty(p.Results.eventDescriptions)
                evtDescriptions = cell(1,numel(p.Results.properties));
                [evtDescriptions{:}] = deal('');
            else
                evtDescriptions = p.Results.eventDescriptions;
                if numel(evtDescriptions) ~= numel(p.Results.eventTimes)
                    error('Each event needs a eventDescriptions entry.')
                end
            end
            
            
            %% Add the event times
            for i = 1:numel(p.Results.eventTimes)
                [~,~,~,time] = get(o.prms.(p.Results.eventTimes{i}),p.Results.eventGetArgs{:});
                time = (time-alignTime)/1000;
                if isKey(p.Results.eventNames,p.Results.eventTimes{i})
                    thisName = p.Results.eventNames(p.Results.eventTimes{i});
                else
                    thisName= p.Results.eventTimes{i};
                end
                tbl= addvars(tbl,time,'NewVariableNames',thisName);
                if isempty(tbl.Properties.VariableUnits)
                    tbl.Properties.VariableUnits = {'s'};
                else
                    tbl.Properties.VariableUnits{end} = 's';
                end
                if isempty(tbl.Properties.CustomProperties.VariableLevels)
                    tbl.Properties.CustomProperties.VariableLevels = {[]}; % Create the first one -events are times so no levels needed.
                  % Once one has been creatd the table object adds empties
                end
               
                if isempty(tbl.Properties.VariableDescriptions)
                    tbl.Properties.VariableDescriptions= evtDescriptions(i); % Create teh first one
                else
                    tbl.Properties.VariableDescriptions{end} = evtDescriptions{i}; % Once one has been creatd the table object adds empties- replace
                end
            end
            
              %%  Add the properties to the table.
            for i= 1:numel(p.Results.properties)
                [v] = get(o.prms.(p.Results.properties{i}),'atTrialTime',p.Results.atTrialTime);
                
                
                if isKey(p.Results.propertyProcessing,p.Results.properties{i})
                    fun = p.Results.propertyProcessing(p.Results.properties{i});
                    v= fun(v);
                end
                
                
                if isKey(p.Results.propertyNames,p.Results.properties{i})
                    thisName = p.Results.propertyNames(p.Results.properties{i});
                else
                    thisName= p.Results.properties{i};
                end
                
                tbl= addvars(tbl,v,'NewVariableNames',thisName);
                if isempty(tbl.Properties.VariableUnits)
                    tbl.Properties.VariableUnits = units(i); % Create teh first one
                else
                    tbl.Properties.VariableUnits{end} = units{i}; % Once one has been creatd the table object adds empties- replace
                end
                if isempty(tbl.Properties.CustomProperties.VariableLevels)
                    tbl.Properties.CustomProperties.VariableLevels = levels(i); % Create teh first one
                else
                    tbl.Properties.CustomProperties.VariableLevels{end} = levels{i}; % Once one has been creatd the table object adds empties- replace
                end
                if isempty(tbl.Properties.VariableDescriptions)
                    tbl.Properties.VariableDescriptions= propDescriptions(i); % Create teh first one
                else
                    tbl.Properties.VariableDescriptions{end} = propDescriptions{i}; % Once one has been creatd the table object adds empties- replace
                end
            end
            
          
            
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
    
    
    
    methods (Access = public)
        
        function baseBeforeExperiment(o)
            % Check whether this plugin should be displayed on
            % the color overlay in VPIXX-M16 mode.  Done here to
            % avoid the overhead of calling this every draw.
            if any(strcmpi(o.cic.screen.type,{'VPIXX-M16','SOFTWARE-OVERLAY'})) && o.overlay
                o.window = o.cic.overlayWindow;
            else
                o.window = o.cic.mainWindow;
            end
            beforeExperiment(o);
        end
        
        function baseBeforeBlock(o)
            beforeBlock(o);
        end
        
        function baseBeforeTrial(o)
            beforeTrial(o);
        end
        function baseBeforeFrame(o)
            beforeFrame(o);
        end
        
        function baseAfterFrame(o)
            afterFrame(o);
        end
        
        function baseAfterTrial(o)
            afterTrial(o);
        end
        
        function baseAfterBlock(o)
            afterBlock(o);
        end
        
        function baseAfterExperiment(o)
            afterExperiment(o);
        end
        
        function beforeExperiment(~)
            %NOP
        end
        
        function beforeBlock(~)
            %NOP
        end
        
        function beforeTrial(~)
            %NOP
        end
        
        function beforeFrame(~)
            %NOP
        end
        
        function afterFrame(~)
            %NOP
        end
        
        function afterTrial(~)
            %NOP
        end
        
        function afterBlock(~)
            %NOP
        end
        function afterExperiment(~)
            %NOP
        end
        
    end
    
    methods (Sealed)
        % These methods are sealed to allow the use of a heterogeneous
        % array of plugins/stimuli
        function v = eq(a,b)
            v = eq@handle(a,b);
        end
        
        function base(oList,what,c)
            
            switch (what)
                case neurostim.stages.BEFOREEXPERIMENT
                    for o=oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseBeforeExperiment(o);
                        if c.PROFILE; addProfile(c,'BEFOREEXPERIMENT',o.name,c.clockTime-ticTime);end
                    end
                    % All plugins BEFOREEXPERIMENT functions have been processed,
                    % store the current parameter values as the defaults.
                    setCurrentParmsToDefault(oList);
                case neurostim.stages.BEFOREBLOCK
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseBeforeBlock(o);
                        if c.PROFILE; addProfile(c,'BEFOREBLOCK',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.BEFORETRIAL
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseBeforeTrial(o);
                        if c.PROFILE; addProfile(c,'BEFORETRIAL',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.BEFOREFRAME
                    Screen('glPushMatrix',c.window);
                    Screen('glLoadIdentity', c.window);
                    Screen('glTranslate', c.window,c.screen.xpixels/2,c.screen.ypixels/2);
                    Screen('glScale', c.window,c.screen.xpixels/c.screen.width, -c.screen.ypixels/c.screen.height);
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        Screen('glPushMatrix',c.window);
                        baseBeforeFrame(o); % If appropriate this will call beforeFrame in the derived class
                        Screen('glPopMatrix',c.window);
                        if c.PROFILE; addProfile(c,'BEFOREFRAME',o.name,c.clockTime-ticTime);end
                    end
                    Screen('glPopMatrix',c.window);
                case neurostim.stages.AFTERFRAME
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterFrame(o);
                        if c.PROFILE; addProfile(c,'AFTERFRAME',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.AFTERTRIAL
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterTrial(o);
                        if c.PROFILE; addProfile(c,'AFTERTRIAL',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.AFTERBLOCK
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterBlock(o);
                        if c.PROFILE; addProfile(c,'AFTERBLOCK',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.AFTEREXPERIMENT
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterExperiment(o);
                        if c.PROFILE; addProfile(c,'AFTEREXPERIMENT',o.name,c.clockTime-ticTime);end
                    end
                otherwise
                    error('?');
            end
        end
        
        
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setCurrentParmsToDefault(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setCurrentToDefault,o.prms);
                end
            end
        end
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setDefaultParmsToCurrent(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setDefaultToCurrent,o.prms);
                end
            end
        end
        
        function pruneLog(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@pruneLog,o.prms);
                end
            end
            
        end
    end
    
end