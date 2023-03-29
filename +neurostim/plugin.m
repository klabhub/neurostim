classdef plugin  < dynamicprops & matlab.mixin.Copyable & matlab.mixin.Heterogeneous
    % Base class for plugins. Includes logging, functions, etc.
    %
    properties (SetAccess=public)
        cic;  % Pointer to CIC
        overlay=false;      % Flag to indicate that this plugin is drawn on the overlay in M16 mode.
        window;
        feedStyle = '[0 0.5 0]';    % Command line color for writeToFeed messages.
        
        
    end
    
    
    properties (SetAccess=protected, GetAccess=public)
        name= '';   % Name of the plugin; used to refer to it within cic
        prms=struct;          % Structure to store all parameters
        trialDynamicPrms;  %  A list of parameters that (can) change within a trial. See localizeParms for how it is filled and used.
    end
    
    properties (SetAccess=private, GetAccess=public)
        rng                         % This plugin's RNG stream, issued from a set of independent streams by CIC.
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
        
        
        function oldKey = addKey(o,key,keyHelp,isSubject,fun,force,plg)
            %  addKey(o,key,keyHelp,isSubject,fun)
            % Runs a function in response to a specific key press.
            % key - a single key (string)
            % keyHelp -  a string that explains what this key does
            % isSubject - bool to indicate whether this is a key press the
            % subject should do. (Defaults to true for stimuli, false for
            % plugins)
            % fun - The user must implement keyboard(o,key) or provide a
            % handle to function that takes a plugin/stimulus and a key as
            % input.
            % force - set to true to force adding this key (and thereby
            % taking it away from anihter plugin). This only makes sense if
            % you restore it soon after, using the returned keyInfo.
            nin =nargin;
            if nin <7
                plg = o;
                if nin <6
                    force =false;
                    if nin<5
                        fun =[];
                        if nin < 4
                            isSubject = isa(o,'neurostim.stimulus') || isa(o,'neurostim.behavior');
                            if nin <3
                                keyHelp = '?';
                            end
                        end
                    end
                end
            end
            oldKey = addKeyStroke(o.cic,key,keyHelp,plg,isSubject,fun,force);
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
        function writeToFeed(o,msg,varargin)
            p=inputParser;
            p.KeepUnmatched = true;
            p.PartialMatching = false;
            p.addParameter('style',o.feedStyle,@ischar);
            p.parse(varargin{:});
            nin =nargin;
            if nin==1
                msg = '';
            end
            % Send it to the logger in CIC.
            o.cic.messenger.feed(o.cic.frame>0,p.Results.style,o.cic.trial,o.cic.trialTime,msg,o.name);
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
            p.addParameter('changesInTrial',false,@islogical); % Indicate that this is a variable that gets new values assiged inthe beforeFrame/afterFrame user code.
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
        
        function makeSticky(o,prp)
            % Make this property sticky (i.e. keep a value across trials).
            if ~isfield(o.prms,prp)
                error([prp ' is not a property of ' o.name]);
            end
            o.prms.(prp).sticky = true; % plugin class has setaccess to this
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
        
        function prms = prmsByClass(o,cls)
            % return the names of the ns parameters that are
            % instances of the class specified by cls
            prms = fieldnames(o.prms);
            ix = cellfun(@(x) isa(o.(x),cls),prms);
            prms(~ix) = [];
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
                
                % If a parm is a vector in some trials but a scalar NaN in
                % other trials, we make sure to create a matching vector of
                % NaNs. (Otherwise the table will hae missing values, and
                % BIDS validation will fail).
                if iscell(v) && isnumeric(v{1})
                    nrCols = cellfun(@(x) size(x,2),v);
                    mismatch = nrCols ~=max(nrCols);
                    if any(mismatch)
                        if all(isnan([v{mismatch}]))
                            [v{mismatch}] = deal(nan(1,max(nrCols)));
                            v =cat(1,v{:}); % Make it into a matrix; each row will be an entry in the table below.
                        end
                    end
                end
                
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
        
        function addRNGstream(o,nStreams,makeItAGPUrng)
            %Ask CIC to allocate RNG(s) to this plugin.
            %
            %nStreams [1]: number of streams to add to this plugin. If greater than 1, o.rng will be a cell array of streams.
            %makeItAGPUrng [false]: should the RNG be on the CPU or GPU?
            %
            %see cic.createRNGstreams() for more info about RNG management.
            if nargin < 2 || isempty(nStreams)
                nStreams = 1;
            end
            
            if nargin < 3 || isempty(makeItAGPUrng)
                makeItAGPUrng = false;
            end
            
            o.rng = requestRNGstream(o.cic,nStreams,makeItAGPUrng);
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
        
        function baseBeforeItiFrame(o)
            beforeItiFrame(o);
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
        
        function beforeItiFrame(~)
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
        
        
        % Add this neurostim.parameter to the set of parameters that need
        % to be updated each frame (and not each trial). Needs public
        % access so that derived classes can use it.
        function setChangesInTrial(o,prm)
            nrDynamic = size(o.trialDynamicPrms,2);
            if ischar(prm)
                prm = o.prms.(prm);
            end
            o.trialDynamicPrms{1,nrDynamic+1} = ['loc_' prm.name] ;
            o.trialDynamicPrms{2,nrDynamic+1} = prm; % Store the handle to the parms
            prm.changesInTrial = true;
        end
    end
    
    methods (Access={?neuorstim.plugin,?neurostim.parameter,?neurostim.stimulus})
        
        %Accessing neurostim.parameters is much slower than accessing a raw
        %member variable. Because we define many such parms (with addProperty) in the base
        %stimulus /plugin classes, and becuase they need to be read each
        %frame ( see stimulus.baseBeforeFrame) this adds substantial
        %overhead (~ 1ms per stimulus) and can quickly lead to framedrops.
        % In any given experiment most parameters never change during the trial
        % so checing every frame is a waste. This function makes local
        % member variable copies to speedup this access.
        % 1. A plugin derived class defines member variables whose names start with loc_
        %    that match up with neurostim.parameters. (e.g. loc_X for the X
        %     property set with addProperty)
        % 2. In its beforeFrame and afterFrame code (and ONLY there), the
        %   derived class uses loc_X instead of X (using X does no harm,
        %   but it would slow down the code again).
        % That's it.
        % Currently this is implemented for the neurostim.stimulus class
        % where it leads to most improvement in perforamace. Users may not
        % need this, but could add it to their own code if they run into
        % performance issues. See neurostim.stimulus for more tips.
        %
        % The code below (Called after the user beforeTrial code, but before the trial
        % really starts, and then again with frameUpdate == true before each beforeFrame)
        % will make sure that the localized variables (loc_ ) have the correct value throughout
        % the triall
        function localizeParms(o,frameUpdate)
            if nargin<2
                frameUpdate = false;
            end
            if frameUpdate
                % A call just before the beforeFrame code is called; we'll
                % update only those variables that were previously
                % identified as being "dynamic" (by the code below in this
                % function)
                if size(o.trialDynamicPrms,2)>0
                    targetMembers = o.trialDynamicPrms(1,:);
                    srcParameters = o.trialDynamicPrms(2,:);
                else
                    % No trial dynamic parms. Done.
                    return;
                end
            else
                % A call just after beforeTrial user code. Create a list
                % of loc_ variables
                classInfo      = metaclass(o);
                targetMembers = {classInfo.PropertyList.Name};
                targetMembers = targetMembers(startsWith(targetMembers,'loc_'));
                for prm = 1:numel(targetMembers)
                    src = char(extractAfter(targetMembers{prm},'loc_'));
                    srcParameters{prm} = o.prms.(src); %#ok<AGROW>
                end
                % Create space to store the names of the parameters that need to be updated each frame
                % (row 1) and the associated neurostim.parameter (row 2).
                % This will be used in the frameUpdate call to this
                % function.
                o.trialDynamicPrms = cell(2,0);
            end
            
            for prm = 1:numel(targetMembers)
                % Walk through the list - updating each value
                trg =targetMembers{prm};
                src = srcParameters{prm};
                value = src.getValue();
                if isa(value,'neurostim.plugins.adaptive')
                    value = +value;
                end
                o.(trg) = value; % Copy the current value in the loc_ member
                if ~frameUpdate
                    % A call just before the trial updates- check which
                    % ones we will have to update each trial/
                    if src.changesInTrial
                        setChangesInTrial(o,src);
                    end
                end
            end
        end
        
        % Return whether this parameter name has a localized version in
        % this plugin (i.e. loc_X exists for X) - used by parameter class.
        function yesno = checkLocalized(o,nm)
            classInfo  = metaclass(o);
            yesno = ismember(['loc_' nm],{classInfo.PropertyList.Name});
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
                        % Store the list of localized parameters.
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
                        localizeParms(o); % Copy neurostim.parms to localized members to speed up.
                        if c.PROFILE; addProfile(c,'BEFORETRIAL',o.name,c.clockTime-ticTime);end
                    end
                case neurostim.stages.BEFOREFRAME
                    Screen('glLoadIdentity', c.window);
                    Screen('glTranslate', c.window,c.screen.xpixels/2,c.screen.ypixels/2);
                    Screen('glScale', c.window,c.screen.xpixels/c.screen.width, -c.screen.ypixels/c.screen.height);
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        Screen('glPushMatrix',c.window);
                        localizeParms(o,true); % Copy neurostim.parms to localized members to speed up (True means 'only dynamic parameters').
                        baseBeforeFrame(o); % If appropriate this will call beforeFrame in the derived class
                        Screen('glPopMatrix',c.window);
                        if c.PROFILE; addProfile(c,'BEFOREFRAME',o.name,c.clockTime-ticTime);end
                    end
                    Screen('glLoadIdentity', c.window); % Guarantee identity transformation in non plugin code (i.e. in CIC)
                case neurostim.stages.AFTERFRAME
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        baseAfterFrame(o);
                        if c.PROFILE; addProfile(c,'AFTERFRAME',o.name,c.clockTime-ticTime);end
                    end
                    
                case neurostim.stages.BEFOREITIFRAME
                    Screen('glLoadIdentity', c.window);
                    Screen('glTranslate', c.window,c.screen.xpixels/2,c.screen.ypixels/2);
                    Screen('glScale', c.window,c.screen.xpixels/c.screen.width, -c.screen.ypixels/c.screen.height);
                    for o= oList
                        if c.PROFILE;ticTime = c.clockTime;end
                        Screen('glPushMatrix',c.window);
                        baseBeforeItiFrame(o); % If appropriate this will call beforeItiFrame in the derived class
                        Screen('glPopMatrix',c.window);
                        if c.PROFILE; addProfile(c,'BEFOREITIFRAME',o.name,c.clockTime-ticTime);end
                    end
                    Screen('glLoadIdentity', c.window); % Guarantee identity transformation in non plugin code (i.e. in CIC)
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
        
        
        function assignWindow(oo)
            % Tell this plugin which window it should draw to. Called from
            % cic.PsychImaging on creation of  the main window
            
            %%Recursive call to here to allow calling with a vector of plugins.
            if numel(oo)>1
                for i=1:numel(oo)
                    assignWindow(oo(i));
                end
                return;
            end
            
            % Check whether this plugin should be displayed on
            % the color overlay in VPIXX-M16 mode.  Done here to
            % avoid the overhead of calling this every draw.
            if any(strcmpi(oo.cic.screen.type,{'VPIXX-M16','SOFTWARE-OVERLAY'})) && oo.overlay
                oo.window = oo.cic.overlayWindow;
            else
                oo.window = oo.cic.mainWindow;
            end
        end
    end
    
    
    %% GUI Functios
    methods (Access= public)
        function guiSet(o,parms) %#ok<INUSD>
            %The nsGui calls this just before the experiment starts; derived plugins
            % with gui panels shoould use it to transfer values from the
            % guipanel (using handle h) into property settings. The base plugin class does
            % nothing (Except a warning).
            % See plugins.eyelink for an example.
            writeToFeed(o,['The ' o.name ' plugin has no guiSet function. GUI settings will be ignored']);
        end
        
    end
    
    
    methods (Static, Access=public)
        function guiLayout(parent) %#ok<INUSD>
            % nsGui calls this function with parent set to the parent uipanel
            % Plugins can add graphical (appdesigner) elements to this parent.
            % See plugins.eyelink for an example
        end
    end
    
    methods (Static)
        
        function fromCurrentClassdef = updateClassDef(fromFile,fromCurrentClassdef)
            % This function is called from a loadobj function in a plugins
            % derived class to resolve backward compatibility
            % fromFile    - the struct that was loaded from file (this plugin's properties
            %         no longer match the current class definition, hence the need
            %         for updating)
            % fromCurrentClassdef - An object that matches the current class definition
            %           (presumably created in the derived class by calling the
            %           constructor)
            % OUTPUT
            %  fromCurrentClassdef - An object mactching the current class definition,
            %  with default  values for "new" properties, and the old
            %  (saved) values for the old properties.
            %
            % Becuase this is a static member of the parent plugin class, it needs
            % access to all properties of the derived classes. Achieve this
            % by using public properties in plugins, or if they should be
            % protected, use SetAccess={!neurostim.plugin}, which gives the
            % neurostim.plugin class access. Not ideal but afaik Matlab does not
            % have a way to allow only parent classes tohave SetAccess.
            % BK noticed that trying to update protected members (i.e. without the 
            % SetAccess given to neurostim.plugin Matlab can crash.)
            %
            % Note that this also deals with the problem (first noted in
            % R2020a) that dynamicproperties saved to disk are not restored
            % properly.
            %
            % Note that for most plugins saved versions still match the
            % classdef; they won't have a loadobj  function.
            % Once a plugin needs a loadobj, it should create its own
            % function (where a new, empty object with the curent
            % classdef can be constructe, do any derived class specific changes,
            % and then call this plugin.loadobj. For examples see cic.m ad
            % stimuli.starstim.m
            %
            % BK - Sept 2021
            
            
            m= metaclass(fromCurrentClassdef);
            dependent = [m.PropertyList.Dependent];
            % Find properties that we can set now (based on the stored fromFile object)
            storedFn = fieldnames(fromFile);
            missingInSaved  = strcat(setdiff({m.PropertyList(~dependent).Name},storedFn),' / ');
            missingInCurrent  = strcat(setdiff(storedFn,{m.PropertyList(~dependent).Name}),' / ');
            toCopy= intersect(storedFn,{m.PropertyList(~dependent).Name});
            fprintf('Fixing backward compatibility of stored ***%s*** object.\n',m.Name)
            if ~isempty(missingInSaved)
                fprintf('Not defined when saved (will get current default values):\n ');
                fprintf('\t%s',missingInSaved{:})
                fprintf('\n')
            end
            if ~isempty(missingInCurrent)
                fprintf('Not defined currently (will be removed):\n');
                fprintf('\t%s' ,missingInCurrent{:})
                fprintf('\n');
            end
            for i=1:numel(toCopy)
                %skip readonly
                this = strcmp({m.PropertyList.Name},toCopy{i});
                if any(strcmpi({'none'},m.PropertyList(this).SetAccess))
                    fprintf('\t Cannot set %s (will get current default value)\n', toCopy{i})
                else
                    try
                        fromCurrentClassdef.(toCopy{i}) = fromFile.(toCopy{i});
                    catch me
                        fprintf(2,'\t Failed to set %s. Please use SetAccess={?neurostim.plugin} for this property. (without this, it will get current default value , but this is known to cause Matlab crashes): %s\n', toCopy{i})
                    end
                end
            end
            
            
            % Restore dynamic properties which appear to be lost (probably
            % because a struct (old) cannot have dynprops
            prmsNames= fieldnames(fromCurrentClassdef.prms);
            for p=1:numel(prmsNames)
                hDynProp = findprop(fromCurrentClassdef,prmsNames{p});
                if isempty(hDynProp)
                    % Stored object had a dynprop that is no longer
                    % constructed now. Recreate it (ignoring anys special
                    % options)
                    hDynProp = addprop(fromCurrentClassdef,prmsNames{p});
                end
                % Delete the handle to the dynprop that was stored (but not
                % restored on load)
                delete(fromCurrentClassdef.prms.(prmsNames{p}).hDynProp)
                % Then link the neurostim.parameter to the dynprop created
                % in the default constructor call using the current
                % classdef (current) (By now current.prms has the values
                % corresponding to the saved object)
                fromCurrentClassdef.prms.(prmsNames{p}).hDynProp = hDynProp;
                % And set the dynprop to return only the current (i.e.
                % last) value in the neurostim.parameter and never update.
                hDynProp.GetMethod = @(varargin) (fromCurrentClassdef.prms.(prmsNames{p}).value);
                hDynProp.SetMethod = @(varargin) (NaN);
                
                % Then make sure the .plg member of the parameter links to
                % the newly updated plg
                if p==1
                    % This still points to the old style object. It will be
                    % deleted when it goes out of scope, but if the
                    % destructor references dynprops, it will generate an
                    % warning. Instead delete it explicitly here, and hide the warning
                    % to avoid confusion
                    warning('off','MATLAB:class:DestructorError')
                    delete(fromCurrentClassdef.prms.(prmsNames{p}).plg);
                    warning('on','MATLAB:class:DestructorError')
                end
                fromCurrentClassdef.prms.(prmsNames{p}).plg = fromCurrentClassdef;
            end
        end
    end
end