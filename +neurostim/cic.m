% Command and Intelligence Center for Neurostim using PsychToolBox.
% See demos directory for examples
%  BK, AM, TK, 2015
classdef cic < neurostim.plugin

    %% Constants
    properties (Constant)
        PROFILE = false; % Using a const to allow JIT to compile away profiler code
        SETUP   = 0;
        RUNNING = 1;
        INTRIAL = 2;
        POST    = 3;
    end

    %% Public properties
    % These can be set in a script by a user to setup the
    % experiment
    properties (GetAccess=public, SetAccess =public)
        mirrorPixels           = []; % Window coordinates.[left top width height].
        cursor = 'arrow';        % Cursor 'none','arrow';
        dirs                    = struct('root','','output','','calibration','')  % Output is the directory where files will be written, root is where neurostim lives, calibration stores calibration files
        subjectNr               = [];
        latinSqRow              = [];
        runNr                   = []; % Bookkeeping. runNr is a sequential number indicating the number of times the same subject has run the experiment.
        seqNr                   = []; %Bookkeeping. seqNr is a sequential number indicating how many subjects have already run this experiment.
        paradigm                = 'test';
        clear                   = 1;   % Clear backbuffer after each swap. double not logical
        itiClear                 = 1;    % Clear backbuffer during the iti. double. Set to 0 to keep the last display visible during the ITI (e.g. a fixation point)
        fileOverwrite           = false; % Allow output file overwrite.
        useConsoleColor         = false; % Set to true to allow plugins and stimuli use different colors to write to the console. There is some time-cost to this (R2018a), hence the default is false.
        saveEveryN              = 10;
        saveEveryBlock          = false;
        keyBeforeExperiment     = true;
        keyAfterExperiment      = true;
        doublePressToQuit       = true; % User must press "escape" twice to exit. If false, once only.
        beforeExperimentText    = 'Press any key to start...'; % Shown at the start of an experiment
        afterExperimentText     = 'This is the end...';
        screen                  = struct('xpixels',[],'ypixels',[],'xorigin',0,'yorigin',0,...
            'width',[],'height',[],...
            'color',struct('text',[1 1 1],...
            'background',[1/3 1/3 5]),...
            'colorMode','xyL',...
            'colorCheck',false,...  % Check color validity- testing only
            'type','GENERIC',...
            'frameRate',60,'number',[],'viewDist',[],...
            'calFile','','colorMatchingFunctions','',...
            'calibration',struct('gammaTable',[],'ns',struct('gamma',2.2*ones(1,3),'bias',zeros(1,3),'min',zeros(1,3),'max',60*ones(1,3),'gain',ones(1,3))),...
            'overlayClut',[]);    % screen-related parameters.

        timing = struct('vsyncMode',0); % 0 = busy wait until vbl, 1 = schedule flip asynchronously then continue

        hardware                = struct('sound',struct('device',-1,'latencyClass',1) ... % Sound hardware settings (device = index of audio device to use, see plugins.sound
            ,'keyEcho',false... % Echo key presses to the command line (listenChar(-1))
            ,'textEcho',false ... % Echo drawFormattedText to the command line.
            ,'maxPriorityPerTrial',true ... % request max priority before/after each trial (as opposed to before/after the experiment)
            ,'busyWaitITI',true ... % add busy work in the ITI to prevent the sceduler demoting us
            ); % Place to store hardware default settings that can then be specified in a script like myRig.

        flipCallbacks={}; %List of stimuli that have requested to be to called immediately after the flip, each as s.postFlip(flipTime).
        guiFlipEvery=[]; % if gui is on, and there are different framerates: set to 2+
        guiOn   =false; %flag. Is GUI on?
        mirror =[]; % The experimenters copy
        ticTime = -Inf;

        %% Logging/experimenter feedback during the experimtn
        messenger; % @neurostim.messenger;
        useFeedCache = false;  % When true, command line output is only generated in the ITI, not during a trial (theoretical optimization,in practice this does not do much)
        spareRNGstreams = {};  %Cell array of independent RNG streams, not yet allocated (plugins can request one through requestRNGstream()).
        spareRNGstreams_GPU = {};%Clones of the above CPU rng streams, operating on the GPU with gpuArray functions and objects

        %% Keyboard interaction
        kbInfo  = struct('keys',{[]},... % PTB numbers for each key that is handled.
            'help',{{}},... % Help info for key
            'plugin',{{}},...  % Which plugin will handle the key (keyboard() will be called)
            'isSubject',{logical([])},... % Is this a key that is handled by subject keyboard ?
            'fun',{{}},... % Function handle that is used instead of the plugins keyboard function (usually empty)
            'default',{-1},... % default keyboard -1 means all keyboard
            'subject',{[]},... % The keyboard that will handle keys for which isSubect is true (=by default stimuli)
            'experimenter',{[]},...% The keyboard that will handle keys for which isSubject is false (plugins by default)
            'pressAnyKey',{-1},... % Keyboard for start experiment, block ,etc. -1 means any
            'activeKb',{[]});  % Indices of keyboard that have keys associated with them. Set and used internally)

        %% Git version tracking
        % Set on=true to use version tracking. When false, no tracking is
        % used.
        % Set commit=true to always commit local changes (when false, local
        % commits are ignored).
        % Set silent = true to generate an automatic commit message (when
        % false, the user is asked to provide one).
        % See neurostim.utils.git.versionTracker
        gitTracker = struct('on',false,'silent',false,'commit',true);
    end

    %% Protected properties.
    % These are set internally
    properties (GetAccess=public, SetAccess ={?neurostim.plugin})
        %% Program Flow
        mainWindow = []; % The PTB window
        overlayWindow =[]; % The color overlay for special colormodes (VPIXX-M16)
        overlayRect = [];
        textWindow = []; % This is either the main or the overlay, depending on the mode.
        stage;
        flags = struct('trial',true,'experiment',true,'block',true); % Flow flags

        frame = 0;      % Current frame


        %% Internal lists to keep track of stimuli, , and blocks.
        stimuli;    % Vector of stimulus  handles.
        plugins;    % Vector of plugin handles.
        pluginOrder; % Vector of plugin handles, sorted by execution order

        blocks;   % Struct array with .nrRepeats .randomization .conditions
        blockFlow =struct('list',[],'weights',[],'randomization','','latinSquareRow',[]);

        %% Logging and Saving
        startTime    = 0; % The time when the experiment started running
        stopTime = [];


        %% Profiling information.


        EscPressedTime=-Inf;
        lastFrameDrop=1;
        propsToInform={'blockName','condition/nrConditions','trial/nrTrialsTotal'};

        profile=struct('cic',struct('FRAMELOOP',[],'FLIPTIME',[],'cntr',0));

        guiWindow;
        funPropsToMake=struct('plugin',{},'prop',{});


    end
    properties (SetAccess= {?neurostim.plugin}) 
        used =false; % Flag to make sure a user cannot reuse a cic object.
        loadedFromFile = false; % Flag set by loadobj - primarily used to avoid initializing things that are only relevant during the experiment.
    end

    %% Dependent Properties
    % Calculated on the fly
    properties (Dependent)
        nrStimuli;      % The number of stimuli currently in CIC
        nrPlugins;      % The number of plugins (Excluding stimuli) currently inCIC
        nrBehaviors     % The number of behaviors in the CIC
        behaviors       % A plugin array consisting of only the behaviors.
        nrConditions;   % The number of conditions in this block
        nrBlocks;       % The number of blocks in this experiment
        nrTrials;       % The number of trials in the current block
        center;         % Where is the center of the display window.
        file;           % Target file name
        fullFile;       % Target file name including path
        fullPath;       % Target path name
        subject;   % Subject
        startTimeStr;  % Start time as a HH:MM:SS string
        blockName;      % Name of the current block
        trialTime;      % Time elapsed (ms) since the start of the trial
        nrTrialsTotal;   % Number of trials total (all blocks)
        date;           % Date of the experiment.
        blockDone;      % Is the current block done?
        hasValidWindow; % Is the Main Window valid?
    end

    %% Public methods
    % set and get methods for dependent properties
    methods
        function v = get.hasValidWindow(c)
            v = Screen(c.mainWindow,'WindowKind')>0;
        end

        function v = get.blockDone(c)
            v = c.blocks(c.block).done;
        end

        function v=get.nrTrialsTotal(c)
            v= sum([c.blocks(c.blockFlow.list).nrPlannedTrials]) + sum([c.blocks.nrRetried]);
        end

        function v= get.nrStimuli(c)
            v= length(c.stimuli);
        end

        function v= get.nrPlugins(c)
            v= length(c.plugins);
        end

        function v = get.behaviors(c)
            fun = @(x) (isa(x,'neurostim.behavior'));
            isBehavior =arrayfun(fun,c.plugins);
            v = c.plugins(isBehavior);
        end

        function v  = get.nrBehaviors(c)
            v = numel(c.behaviors);
        end

        function v= get.nrBlocks(c)
            v = numel(c.blockFlow.list);
        end

        function v= get.nrTrials(c)
            if c.block
                v= c.blocks(c.block).nrTrials;
            else
                v=0;
            end
        end
        function v= get.nrConditions(c)
            if c.block
                v= c.blocks(c.block).nrConditions;
            else
                v=0;
            end
        end
        function v = get.center(c)
            [x,y] = RectCenter([0 0 c.screen.xpixels c.screen.ypixels]);
            v=[x y];
        end
        function v= get.startTimeStr(c)
            v = datestr(c.startTime,'HH:MM:SS');
        end
        function v = get.file(c)
            v = [c.subject '.' c.paradigm '.' datestr(c.startTime,'HHMMSS') ];
        end
        function v = get.fullPath(c)
            v = fullfile(c.dirs.output,datestr(c.startTime,'YYYY/mm/DD'));
        end
        function v = get.fullFile(c)
            v = fullfile(c.fullPath,c.file);
        end
        function v=get.date(c)
            v=datestr(c.startTime,'DD mmm YYYY');
        end
        function v=get.subject(c)
            if length(c.subjectNr)>1
                % Initials stored as ASCII codes
                v = char(c.subjectNr);
            else
                % True subject numbers
                v= num2str(c.subjectNr);
            end
        end

        function v = get.blockName(c)
            v = c.blocks(c.block).name;
        end

        function set.subject(c,value)
            if isempty(value)
                c.subjectNr =0;
            elseif ischar(value)
                asDouble = str2double(value);
                if isnan(asDouble)
                    % Someone using initials
                    c.subjectNr = double(value);
                else
                    c.subjectNr = asDouble;
                end
            else
                c.subjectNr = value;
            end
        end

        % Allow thngs like c.('lldots.X')
        function v = getProp(c,prop)
            ix = strfind(prop,'.');
            if isempty(ix)
                v =c.(prop);
            else
                o= getProp(c,prop(1:ix-1));
                v= o.(prop(ix+1:end));
            end
        end


        function setupScreen(c,value)
            if isempty(c.screen.number)
                value.number = max(Screen('screens',1));
            end

            windowPixels = Screen('Rect',c.screen.number); % Full screen
            if ~isfield(c.screen,'xpixels') || isempty(c.screen.xpixels)
                c.screen.xpixels  = windowPixels(3)-windowPixels(1); % Width in pixels
            end
            if ~isfield(c.screen,'ypixels') || isempty(c.screen.ypixels)
                c.screen.ypixels  = windowPixels(4)-windowPixels(2); % Height in pixels
            end

            screenPixels = Screen('GlobalRect',c.screen.number); % Full screen
            if ~isfield(c.screen,'xorigin') || isempty(c.screen.xorigin)
                c.screen.xorigin = screenPixels(1);
            end
            if ~isfield(c.screen,'yorigin') || isempty(c.screen.yorigin)
                c.screen.yorigin = screenPixels(2);
            end

            if ~isfield(c.screen,'width') || isempty(c.screen.width)
                % Assuming code is in pixels
                c.screen.width = c.screen.xpixels;
            end
            if ~isfield(c.screen,'height') || isempty(c.screen.height)
                % Assuming code is in pixels
                c.screen.height = c.screen.ypixels;
            end
            if ~isequal(round(c.screen.xpixels/c.screen.ypixels,2),round(c.screen.width/c.screen.height,2))
                warning('Physical aspect ratio and Pixel aspect ratio are not the same...');
            end
        end


        function v= get.trialTime(c)
            v = (c.frame-1)*1000/c.screen.frameRate;
        end

    end

    methods (Access=private)
        function checkFrameRate(c)

            if isempty(c.screen.frameRate)
                error('frameRate not specified');
            end

            frInterval = Screen('GetFlipInterval',c.mainWindow)*1000;
            percError = abs(frInterval-(1000/c.screen.frameRate))/frInterval*100;
            if percError > 5
                sca;
                error(['Actual frame rate ( ' num2str(1000./frInterval) ' ) doesn''t match the requested rate (' num2str(c.screen.frameRate) ')']);
            else
                c.screen.frameRate = 1000/frInterval;
            end

            if ~isempty(c.pluginsByClass('gui'))
                frInterval=Screen('GetFlipInterval',c.guiWindow)*1000;
                if isempty(c.guiFlipEvery)
                    c.guiFlipEvery=ceil(frInterval*0.95/(1000/c.screen.frameRate));
                elseif c.guiFlipEvery<ceil(frInterval*0.95/(1000/c.screen.frameRate))
                    error('GUI flip interval is too small; this will cause frame drops in experimental window.')
                end
            end

        end


        % Collect information about (user specified) properties and display
        % these on the command line feed.
        function collectPropMessage(c)
            msg =cell(1,numel(c.propsToInform));
            for i=1:numel(c.propsToInform)
                str=strsplit(c.propsToInform{i},'/');
                val = cell(1,numel(str));
                for j=1:numel(str)
                    val{j} = getProp(c,str{j}); % getProp allows calls like c.(stim.value)
                    if isnumeric(val{j})
                        val{j} = num2str(val{j});
                    elseif islogical(val{j})
                        if (val{j})
                            val{j} = 'true';
                        else
                            val{j}='false';
                        end
                    end
                    if isa(val{j},'function_handle')
                        val{j} = func2str(val{j});
                    end
                    val{j} = val{j}(:)';
                end
                msg{i} = sprintf('%s: %s/%s',c.propsToInform{i},val{:});
                if strcmpi(msg{i}(end),'/');msg{i}(end) ='';end
            end
            c.writeToFeed(msg);
        end
    end


    methods (Access=public)
        % Constructor.

        function c= cic(varargin)

            p=inputParser;
            p.addParameter('trialDuration',1000);
            p.addParameter('iti',1000);
            p.addParameter('cursor','none');
            p.addParameter('rootDir',strrep(fileparts(mfilename('fullpath')),'+neurostim',''));
            p.addParameter('outputDir',tempdir);
            p.addParameter('rngArgs',{});    %control RNG behaviour, including, for example, the number of streams, or using a particular seed. See createRNGstreams()
            p.addParameter('fromFile',false);   % Used by loadobj to create an empty cic without having PTB installed.
            p.parse(varargin{:});
            p=p.Results;

            %Check MATLAB version. Warn if using an older version.
            ver = version('-release');
            v=regexp(ver,'(?<year>\d+)(?<release>\w)','names');
            if ~((str2double(v.year) > 2015) || (str2double(v.year) == 2015 && v.release == 'b'))
                warning(['The installed version of MATLAB (' ver ') is relatively slow. Consider updating to 2015b or later for better performance (e.g. fewer frame-drops).']);
            end

            c = c@neurostim.plugin([],'cic');

            % Some very basic PTB settings that are enforced for all
            c.loadedFromFile  =p.fromFile;
            if ~c.loadedFromFile
                KbName('UnifyKeyNames'); % Same key names across OS.
            end
            c.cursor = p.cursor;

            c.stage  = neurostim.cic.SETUP;
            % Initialize empty
            c.startTime     = now;
            c.stimuli       = [];
            c.plugins       = [];
            c.cic           = c; % Need a reference to self to match plugins. This makes the use of functions much easier (see plugin.m)

            % The root directory is the directory that contains the
            % +neurostim folder.
            c.dirs.root     = p.rootDir;
            c.dirs.output   = p.outputDir;

            % Setup the keyboard handling
            % Keys handled by CIC
            c.addKey('ESCAPE','Quit');
            c.addKey('n','Next Trial');
            c.addKey('F1','Toggle Cursor');

            c.addProperty('trial',0); % Should be the first property added (it is used to log the others).
            c.addProperty('frameDrop',[NaN NaN]);
            c.addProperty('firstFrame',[]);
            c.addProperty('trialStopTime',[]);
            c.addProperty('condition',[]);  % Linear index, specific to a design
            c.addProperty('design',[]);
            c.addProperty('block',0);
            c.addProperty('blockCntr',0);
            c.addProperty('blockTrial',0);
            c.addProperty('expScript',[]); % The contents of the experiment file
            c.addProperty('experiment',''); % The experiment file
            c.addProperty('iti',p.iti,'validate',@(x) isnumeric(x) & ~isnan(x)); %inter-trial interval (ms)
            c.addProperty('trialDuration',p.trialDuration,'validate',@(x) isnumeric(x) & ~isnan(x)); % duration (ms)
            c.addProperty('matlabVersion', []); %Log MATLAB version used to run this experiment - set at runtime
            c.addProperty('ptbVersion',[]); % Log PTB Version used to run this experiment - set at runtime
            c.addProperty('repoVersion',[]); % Information on the git version/hash. - set at runtime
            c.feedStyle = '*[0.9294    0.6941    0.1255]'; % CIC messages in bold orange


            % Set up a messenger object that provides online feedback to the experimenter
            % either on the local command prompt or on a remote Matlab instance. A remote messenger client can be added by
            % specifying a host name (c.messenger.host) or ip in the experiment file.
            c.messenger = neurostim.messenger;

            %Build a set of RNG streams. Arguments can be provided to
            %control RNG behaviour, including, for example, the number of streams, or returning CIC
            %to the state of a previous run to replay a "stochastic" stimulus (e.g. cic('rngArgs',{'seed',myStoredSeed})
            createRNGstreams(c,p.rngArgs{:});

        end


        function v = trialSuccess(c,behaviors)
            % trialSuccess: True/False
            % Returns whether this a successful trial (as defined by all or a subset of behaviors)
            v = true;

            allBehaviors  = c.behaviors;
            if nargin>1
                stay = ismember({allBehaviors.name},behaviors);
                allBehaviors= allBehaviors(stay);
            end

            for i=1:numel(allBehaviors)
                v = v && (~allBehaviors(i).required || allBehaviors(i).isSuccess);
            end
        end


        function showCursor(c,name)
            if nargin <2
                name =c.cursor;
            end
            if strcmpi(name,'none')
                HideCursor(c.mainWindow);
            else
                ShowCursor(name,c.mainWindow);
            end
            c.cursor = name;
        end

        function nextTrial(c)
            c.flags.trial = false;
        end

        function addPropsToInform(c,varargin)
            c.propsToInform = cat(2,c.propsToInform,varargin{:});
        end

        function setPropsToInform(c,varargin)
            c.propsToInform = varargin;
        end

        function showDesign(c,factors)
            if nargin<2
                factors = [];
            end
            blk = get(c.prms.block,'atTrialTime',0);
            cnd = get(c.prms.condition,'atTrialTime',0);
            for b=1:numel(c.blocks)
                blockStr = ['Block: ' num2str(b) '(' c.blocks(b).name ') - ' num2str(sum(blk==b)) ' trials'];
                condition = cnd(blk==b);
                for d=1:numel(c.blocks(b).designs)
                    show(c.blocks(b).designs(d),factors,blockStr,condition);
                end
            end
        end

        function write(c,label,value)
            if ~isfield(c.prms,label)
                c.addProperty(label,value);
            else
                c.(label) = value;
            end
        end

        function addScript(c,when, fun,keys)
            % It may sometimes be more convenient to specify a function m-file
            % as the basic control script (rather than write a plugin that does
            % the same).
            % when = when should this script be run
            % fun = function handle to the script. The script will be called
            % with cic as its sole argument.
            if nargin <4
                keys = {};
            end
            plg = pluginsByClass(c,'eScript');
            if isempty(plg)
                plg = neurostim.plugins.eScript(c);
            end
            plg.addScript(when,fun,keys);
        end


        function keyboard(c,key)
            %             CIC Responses to keystrokes.
            switch (key)
                case 'n'
                    c.flags.trial = false;
                case 'ESCAPE'
                    if ((c.EscPressedTime+1)>GetSecs) || ~c.doublePressToQuit
                        c.flags.experiment = false;
                        c.flags.trial = false;
                    else
                        c.EscPressedTime=GetSecs;
                    end
                case 'F1'
                    %Toggle the cursor visibility
                    if strcmpi(c.cursor,'none')
                        showCursor(c,'arrow');
                    else
                        showCursor(c,'none');
                    end
                otherwise
                    c.error('STOPEXPERIMENT',['Unknown key ' key '. Did you forget to specify a callback function (check addKey)?']);
            end
        end

        function [x,y,buttons] = getMouse(c)
            [x,y,buttons] = GetMouse(c.mainWindow);
            [x,y] = c.pixel2Physical(x,y);
        end



        function restoreTextPrefs(c)

            defaultfont = Screen('Preference','DefaultFontName');
            defaultsize = Screen('Preference','DefaultFontSize');
            defaultstyle = Screen('Preference','DefaultFontStyle');
            Screen('TextFont', c.mainWindow, defaultfont);
            Screen('TextSize', c.mainWindow, defaultsize);
            Screen('TextStyle', c.mainWindow, defaultstyle);

        end



        function newOrder = setPluginOrder(c,varargin)
            % Set and return pluginOrder.
            %
            %   pluginOrder = c.setPluginOrder([plugin1] [,plugin2] [,...])
            %
            % Inputs:
            %   A list of plugin names in the order they are requested to
            %   be executed in.
            %
            %   If called with no arguments, the plugin order will be reset
            %   to the default order, i.e., the order in which plugins were
            %   added to cic.
            %
            % Output:
            %   A list of plugin names reflecting the new plugin order.

            %If there is an existing order, preserve it, unless an empty
            %vector has been supplied (to clear it back to default order)
            if numel(varargin) == 1 && isa(varargin{1},'neurostim.plugin')
                varargin = arrayfun(@(plg) plg.name,varargin{1},'uniformoutput',false);
            end

            if ~isempty(c.plugins)
                defaultOrder = {c.plugins.name};
            else
                defaultOrder = {};
            end
            if ~isempty(c.stimuli)
                defaultOrder = cat(2,defaultOrder,{c.stimuli.name});
            end

            if nargin==1 || (numel(varargin)==1 && isempty(varargin{1}))
                newOrder = defaultOrder;
            else
                newOrder = varargin;
                notKnown = ~ismember(newOrder,defaultOrder);
                if any(notKnown)
                    warning(['Not a stimulus or plugin: ' neurostim.utils.separatedString(newOrder(notKnown)) ' . Ordering failed. Removed from list']);
                    newOrder(notKnown) = [];
                end
                notSpecified = defaultOrder(~ismember(defaultOrder,newOrder));
                newOrder = cat(2,newOrder,notSpecified);
                % Force gui to be first
                isGui = strcmpi('gui',newOrder);
                if any(isGui) && ~isGui(1)
                    newOrder = cat(2,'gui',newOrder(~isGui));
                end
            end

            c.pluginOrder = [];
            for i=1:numel(newOrder)
                c.pluginOrder =cat(2,c.pluginOrder,c.(newOrder{i}));
            end

        end

        function value = hasPlugin(c,plgName)
            value = ~isempty(c.plugins) && any(strcmpi(plgName,{c.plugins.name}));
        end

        function value = hasStimulus(c,stmName)
            value = ~isempty(c.stimuli) && any(strcmpi(stmName,{c.stimuli.name}));
        end

        function plgs = pluginsByClass(c,classType)
            %Return pointers to all active plugins of the specified class type.
            stay= false(1,c.nrPlugins);
            for p =1:c.nrPlugins
                if isa(c.plugins(p),horzcat('neurostim.plugins.',classType))
                    stay(p) =true;
                end
            end
            plgs = c.plugins(stay);
        end



        function disp(c)
            % Provide basic information about the CIC
            for i=1:numel(c)
                msg = char(['CIC. Started at ' datestr(c(i).startTime,'HH:MM:SS') ],...
                    ['Stimuli: ' num2str(c(i).nrStimuli) ', Blocks: ' num2str(c(i).nrBlocks)]);
                if c(i).nrBlocks
                    msg = char(msg, ['Conditions: ' strtrim(sprintf('%d ',[c(i).blocks.nrConditions])) ...
                        ', Trials: ' strtrim(sprintf('%d ',[c(i).blocks.nrTrials]))]);
                end

                msg = char(msg, ['File: ' c.fullFile '.mat']);

                disp(msg)
            end
        end

        function endTrial(c)
            % Move to the next trial asap.
            c.flags.trial =false;
        end

        function endExperiment(c)
            % End the experiment (used by other plugisn to terminate)
            c.flags.experiment =false;
        end

        function o = add(c,o)
            % Add a plugin.
            if ~isa(o,'neurostim.plugin')
                error('Only plugin derived classes can be added to CIC');
            end

            % Add to the appropriate list
            if isa(o,'neurostim.stimulus')
                nm   = 'stimuli';
            else
                nm = 'plugins';
            end

            if any(o==c.(nm))
                warning(['This name (' o.name ') already exists in CIC. Updating...']);
                % Update existing
            elseif  isprop(c,o.name)
                error(['Please use a different name for your stimulus. ' o.name ' is reserved'])
            else
                h = c.addprop(o.name); % Make it a dynamic property
                c.(o.name) = o;
                h.SetObservable = false; % No events
                c.(nm) = cat(2,c.(nm),o);
                % Set a pointer to CIC in the plugin
                o.cic = c;
                if c.PROFILE
                    c.profile.(o.name)=struct('BEFOREEXPERIMENT',[],'AFTEREXPERIMENT',[],'BEFOREBLOCK',[],'AFTERBLOCK',[],'BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[],'BEFOREITIFRAME',[],'cntr',0);
                end
            end

        end

        %% -- Specify conditions -- %%
        function setupExperiment(c,varargin)
            % setupExperiment(c,block1,...blockEnd,'input',...)
            % Creates an experimental session
            % Inputs:
            % blocks - input blocks directly created from block('name')
            % 'randomization' - 'SEQUENTIAL' or 'RANDOMWITHOUTREPLACEMENT',
            % 'ORDERED' ( a specific ordering provided by the caller) or
            % 'LATINSQUARES' - uses a balanced latin square design, (even
            % number of blocks only). The row number can be provide as the
            % 'c.latinSqRow' property. If this is empty, the user is prompted to enter
            % the row number.
            % 'nrRepeats' - number of repeats total
            % 'weights' - weighting of blocks
            % 'blockOrder' - the ordering of blocks
            p=inputParser;
            p.addParameter('randomization','SEQUENTIAL',@(x)any(strcmpi(x,{'SEQUENTIAL','RANDOMWITHOUTREPLACEMENT','ORDERED','LATINSQUARES'})));
            p.addParameter('blockOrder',[],@isnumeric); %  A specific order of blocks
            p.addParameter('nrRepeats',1,@isnumeric);
            p.addParameter('weights',[],@isnumeric);

            % check the block inputs
            isBlock = cellfun(@(x) isa(x,'neurostim.block'),varargin);
            % store the blocks
            c.blocks = [varargin{isBlock}];

            % make sure that all block objects are unique, i.e., *not* handles
            % to the same object (otherwise becomes a problem for counters)
            names = arrayfun(@(x) x.name,c.blocks,'uniformoutput',false);
            if numel(unique(names)) ~= numel(c.blocks)
                error('Duplicate block object(s) detected. Use the "nrRepeats" or "weights" arguments of c.run() to repeat blocks.');
            end

            % create the blocks and blockFlow
            args = varargin(~isBlock);
            parse(p,args{:});
            if isempty(p.Results.weights)
                c.blockFlow.weights = ones(size(c.blocks));
            else
                c.blockFlow.weights = p.Results.weights;
            end

            if strcmpi(p.Results.randomization,'LATINSQUARES')
                nrUBlocks = numel(c.blocks);
                if ~(rem(nrUBlocks,2)==0)
                    error(['Latin squares randomization only works with an even number of blocks, not ' num2str(nrUBlocks)]);
                end
                allLS = neurostim.utils.ballatsq(nrUBlocks);

                if isempty(c.latinSqRow) || c.latinSqRow==0
                    lsNr = input(['Latin square group number (1-' num2str(size(allLS,1)) ')'],'s');
                    lsNr = str2double(lsNr);
                end
                if isnan(lsNr)  || lsNr>size(allLS,1) || lsNr <1
                    error(['The Latin Square group ' num2str(lsNr) ' does not exist for ' num2str(nrUBlocks) ' conditions/blocks']);
                end
                blockOrder = allLS(lsNr,:);
                c.blockFlow.latinSquareRow = lsNr;
            else
                blockOrder = p.Results.blockOrder;
                c.blockFlow.latinSquareRow = NaN;
            end

            c.blockFlow.randomization = p.Results.randomization;
            singleRepeatList = repelem((1:numel(c.blocks)),c.blockFlow.weights);
            c.blockFlow.list =[];
            for i=1:p.Results.nrRepeats
                switch upper(c.blockFlow.randomization)
                    case {'ORDERED','LATINSQUARES'}
                        c.blockFlow.list = cat(2,c.blockFlow.list,blockOrder);
                    case 'SEQUENTIAL'
                        c.blockFlow.list = cat(2,c.blockFlow.list,singleRepeatList);
                    case 'RANDOMWITHREPLACEMENT'
                        c.blockFlow.list =cat(2,c.blockFlow.list,datasample(singleRepeatList,numel(singleRepeatList)));
                    case 'RANDOMWITHOUTREPLACEMENT'
                        c.blockFlow.list= cat(2,c.blockFlow.list,Shuffle(singleRepeatList));
                end
            end
        end

        function beforeBlock(c)
            % Setup the randomziation in each block
            [msg,waitForKey] = beforeBlock(c.blocks(c.block),c);
            % Calls beforeBlock on all plugins, in pluginOrder.
            base(c.pluginOrder,neurostim.stages.BEFOREBLOCK,c);
            % Draw block message and wait for keypress if requested.
            if ~isempty(msg)
                c.drawFormattedText(msg,'ShowNow',true);
            end
            if waitForKey
                KbWait(c.kbInfo.pressAnyKey,2);
            end
            clearOverlay(c,true);
        end

        function afterBlock(c)

            % Calls afterBlock on all plugins, in pluginOrder.
            base(c.pluginOrder,neurostim.stages.AFTERBLOCK,c);

            % now show message/wait for key if requested.
            waitforkey = false;
            if isa(c.blocks(c.block).afterMessage,'function_handle')
                msg = c.blocks(c.block).afterMessage(c);
            else
                msg = c.blocks(c.block).afterMessage;
            end
            if ~isempty(msg)
                Screen('Flip',c.mainWindow); % Clear screen
                c.drawFormattedText(msg,'ShowNow',true);
                waitforkey=c.blocks(c.block).afterKeyPress;
            end
            if ~isempty(c.blocks(c.block).afterFunction)
                c.blocks(c.block).afterFunction(c);
                waitforkey=c.blocks(c.block).afterKeyPress;
            end
            %
            if c.saveEveryBlock
                ttt=tic;
                c.saveData;
                c.writeToFeed(sprintf('Saving the file took %f s',toc(ttt)));
            end
            if waitforkey
                KbWait(c.kbInfo.pressAnyKey,2);
            end
            clearOverlay(c,true);
        end

        function beforeTrial(c)
            % Restore default values
            setDefaultParmsToCurrent(c.pluginOrder);

            % Call before trial on the current block.
            % This sets up all condition dependent stimulus properties (i.e.,
            % those in the design object that is currently active in the block)
            beforeTrial(c.blocks(c.block),c);
            c.blockTrial = c.blockTrial+1;  % For logging and user output only

            % Calls before trial on all plugins, in pluginOrder.
            base(c.pluginOrder,neurostim.stages.BEFORETRIAL,c);
        end


        function afterTrial(c)
            % Calls after trial on all the plugins
            base(c.pluginOrder,neurostim.stages.AFTERTRIAL,c);
            % Calls afterTrial on the current block/design.
            % This assesses 'success' of the behavior and updates the design
            % if needed (i.e. retrying failed trials)
            afterTrial(c.blocks(c.block),c);
            collectPropMessage(c);
            collectFrameDrops(c);
            if rem(c.trial,c.saveEveryN)==0
                ttt=tic;
                c.saveData;
                c.writeToFeed(sprintf('Saving the file took %f s',toc(ttt)));
            end
            afterTrial(c.messenger);
        end


        function error(c,command,msg)
            switch (command)
                case 'STOPEXPERIMENT'
                    c.writeToFeed(msg,'style','red');
                    c.flags.experiment = false;
                case 'CONTINUE'
                    c.writeToFeed(msg,'style','red');
                otherwise
                    error(['Rethrowing unhandled cic error: ' msg]);
            end

        end

        %% Main function to run an experiment. All input args are passed to
        % setupExperiment.
        function run(c,block1,varargin)
            % Run an experimental session (i.e. one or more blocks of trials);
            %
            % Inputs:
            % list of blocks, created using myBlock = block('name');
            %
            % e.g.
            %
            % c.run(myBlock1,myBlock2,'randomization','SEQUENTIAL');
            %
            % 'randomization' - 'SEQUENTIAL' or 'RANDOMWITHOUTREPLACEMENT'
            % 'nrRepeats' - number of repeats total
            % 'weights' - weighting of blocks

            assert(~c.used,'CIC objects are single-use only. Please create a new one to start this experiment!');
            c.used  = true;

            % Make sure openGL is working properly.
            InitializeMatlabOpenGL;
            AssertOpenGL;
            sca; % Close any open PTB windows.

            % Version tracking  at run time.
            c.matlabVersion = version;
            c.ptbVersion = Screen('Version');
            c.repoVersion = neurostim.utils.git.versionTracker(c.gitTracker);

            % Setup the messenger
            c.messenger.localCache = c.useFeedCache;
            c.messenger.useColor = c.useConsoleColor;
            setupLocal(c.messenger,c);

            c.flags.experiment = true;  % Start with true, but any plugin code can set this to false by calling cic.error.

            %Check input
            if ~(exist('block1','var') && isa(block1,'neurostim.block'))
                help('neurostim/cic/run');
                error('You must supply at least one block of trials, e.g., c.run(myBlock1,myBlock2)');
            end

            %Log the experimental script as a string
            try
                stack = dbstack('-completenames',1);
                if ~isempty(stack) % Can happen with ctrl-retun execution of code
                    c.expScript = fileread(stack(1).file);
                    c.experiment = stack(1).file;
                end
            catch
                warning(['Tried to read experimental script  (', stack(1).file ' for logging, but failed']);
            end

            if isempty(c.subject)
                response = input('Subject code?','s');
                c.subject = response;
            end

            %Make sure save folder exists.
            if ~exist(c.fullPath,'dir')
                success = mkdir(c.fullPath);
                if ~success
                    error(horzcat('Save folder ', strrep(c.fullPath,'\','/'), ' does not exist and could not be created. Check drive/write access.'));
                end
            end

            c.stage = neurostim.cic.RUNNING; % Enter RUNNING stage; property functions, validation  will now be active

            %Construct any function properties by setting them again (this time the actual anonymous functions will be constructed)
            for i=1:numel(c.funPropsToMake)
                c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop) = c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop);
            end

            %% Set up order and blocks
            setPluginOrder(c,c.pluginOrder);
            setupExperiment(c,block1,varargin{:});

            % Force adaptive plugins assigned directly to parameters into
            % the block design object(s) instead. This ensures the adaptive
            % plugins are updated correctly (by the block object(s)).
            handleAdaptives(c)

            %%Setup PTB imaging pipeline and keyboard handling
            PsychImaging(c);
            checkFrameRate(c);

            %% Start preparation in all plugins.
            c.window = c.mainWindow; % Allows plugins to use .window
            locHAVEOVERLAY = ~isempty(c.overlayWindow);

            base(c.pluginOrder,neurostim.stages.BEFOREEXPERIMENT,c);
            showCursor(c);
            KbQueueCreate(c); % After plugins have completed their beforeExperiment (to addKeys)
            c.drawFormattedText(c.beforeExperimentText,'ShowNow',true);

            sanityChecks(c);

            if c.keyBeforeExperiment; KbWait(c.kbInfo.pressAnyKey);end
            clearOverlay(c,true);


            % If PTB reports that it can synchronize to the VBL
            % or if you have measured that it does, then the time
            % between flips will be an exact multiple of the frame
            % duration. In that case testing whether a frame is late by
            % 0.1, 0.5 or 0.9 of a frame is all the same. But if
            % beamposition queries are not working (many windows
            % systems), then there is slack in the time between vbl
            % times as returned by Flip; a vlbTime that is 0.5 of a
            % frame too late, could still have flipped at the right
            % time... (and then windows went shopping for a bit).
            % We allow 50% of slack to account for noisy timing.
            FRAMEDURATION   = 1/c.screen.frameRate; % In seconds to match PTB convention
            ITSAMISS        =  0.5*FRAMEDURATION; %
            locPROFILE      = c.PROFILE;
            WHEN            = 0; % Always flip on the next VBL
            DONTCLEAR       = 1;

            if ~c.hardware.maxPriorityPerTrial
                % request max priority for the whole experiment (NOT per trial)
                Priority(MaxPriority(c.mainWindow));
            end

            if ~c.hardware.keyEcho
                ListenChar(-1);
            end
            % We can only flush those keyboard devices that have been
            % activated:
            kbDeviceIndices = unique([c.kbInfo.default c.kbInfo.subject c.kbInfo.experimenter]);
            for blockCntr=1:c.nrBlocks
                if ~c.flags.experiment;break;end % in case a plugin has generated a STOPEXPERIMENT error
                c.flags.block = true;
                c.block = c.blockFlow.list(blockCntr); % Logged.
                c.blockCntr= blockCntr;

                beforeBlock(c);

                %% Start the trials in the block
                c.blockTrial =0;
                while ~c.blocks(c.block).done
                    c.trial = c.trial+1;

                    beforeTrial(c); % Get all plugins ready for the next trial

                    %ITI - wait
                    if c.trial>1
                        nFramesToWait = c.ms2frames(c.iti - (c.clockTime-c.trialStopTime));
                        for i=1:nFramesToWait
                            base(c.pluginOrder,neurostim.stages.BEFOREITIFRAME,c);
                            ptbVbl = Screen('Flip',c.mainWindow,0,1-c.itiClear);     % WaitSecs seems to desync flip intervals; Screen('Flip') keeps frame drawing loop on target.

                            if locHAVEOVERLAY
                                clearOverlay(c,c.itiClear);
                            end

                            if c.hardware.busyWaitITI
                                % Sitting idle in 'flip' during the ITI seems to cause
                                % unwanted behaviour when the trial starts, and for
                                % several frames into it. At least on some Windows
                                % machines. For example, the time to complete a call to
                                % rand() was hugely variable and with occasional extreme
                                % lags. Performance was improved massively by adding
                                % load here to prevent the OS from releasing priority.
                                %
                                % Here, we make an arbitrary assignment as a temporary
                                % fix. There would certainly be a better way.
                                %
                                % Note that *not* downgrading our Priority() in the
                                % ITI (e.g., maxPriorityPerTrial == False) didn't fix
                                % the problem, busyWaitITI == True did.
                                postITIflip = GetSecs;
                                while GetSecs-postITIflip < 0.6*FRAMEDURATION
                                    dummyAssignment = 1; %#ok<NASGU>
                                end
                            end
                        end
                    else
                        % FLIP at least once to get started (and predict the next vbl)
                        [ptbVbl] = Screen('Flip', c.mainWindow,WHEN,DONTCLEAR);
                    end
                    predictedVbl = ptbVbl+FRAMEDURATION; % Predict upcoming

                    c.frame=0;
                    c.flags.trial = true;
                    PsychHID('KbQueueFlush',kbDeviceIndices);

                    if c.hardware.maxPriorityPerTrial
                        % request max priority for this trial
                        Priority(MaxPriority(c.mainWindow));
                    end

                    % Timing the draw : commented out. See drawingFinished code below
                    % draw = nan(1,1000);

                    while (c.flags.trial && c.flags.experiment)
                        %%  Trial runnning -
                        c.frame = c.frame+1;
                        c.stage = neurostim.cic.INTRIAL;
                        %% Check for end of trial
                        if ~c.flags.trial || c.frame >= ms2frames(c,c.trialDuration)
                            % if trial has ended (based on behaviors for instance)
                            % or if trialDuration has been reached (the screen is cleared by a post-trial flip)

                            % We are going to the ITI.
                            c.flags.trial=false; % This will be the last frame.
                            clr = c.itiClear; % Do not clear this last frame if the ITI should not be cleared
                        else
                            clr = c.clear;
                        end

                        %% Before frame
                        % Call beforeFrame code in all plugins (i.e drawing
                        % to the backbuffer).
                        base(c.pluginOrder,neurostim.stages.BEFOREFRAME,c);

                        % This commented out code allows measuring the draw
                        % times.
                        % draw(c.frame) = Screen('DrawingFinished',c.mainWindow,1-clr,true);
                        % Or you can use this on most modern GPUs:
                        % tmp = Screen('GetWindowInfo',c.mainWindow,0);
                        % draw(c.frame) = tmp.GPULastFrameRenderTime;
                        % Screen('GetWindowInfo',c.mainWindow,5); % Start GPU clock

                        % All drawing to the backbuffer should be ready.
                        % Let the GPU start processing this
                        Screen('DrawingFinished',c.mainWindow,1-clr);



                        KbQueueCheck(c);
                        % After the KB check, a behavioral requirement
                        % can have terminated the trial. Check for that.
                        if ~c.flags.trial ;  clr = c.itiClear; end % Do not clear this last frame if the ITI should not be cleared

                        if c.timing.vsyncMode ==1
                            % In vsyncMode 1 we schedule the flip now (but
                            % then proceed asynchronously to do some
                            % non-drawing related tasks).
                            %Screen('AsyncFlipBegin', windowPtr , when =0, dontclear = 1-clr , dontsync =0 , multiflip =0);
                            % Note that this should be after the clr =
                            % c.itiClear line, otherwise the scheduled clr
                            % argument could be different from the desired
                            % clr if itiClear = false). In principle we
                            % could catch this condition after the
                            % frameloop and then draw the last frame again,
                            % but the small performance enhancement
                            % (checking the keyboard) does not seem worth
                            % it.
                            Screen('AsyncFlipBegin',c.mainWindow,WHEN,1-clr,0,0);
                        end

                        % In VSync mode 0 we start the flip and wait for it
                        % to finish before proceeding.
                        if c.timing.vsyncMode ==0
                            % Do the flip at the next available VBL (WHEN=0)
                            % This is done synchronously; execution will
                            % wait here until after the flip has completed.
                            startFlipTime = GetSecs;
                            % ptbVbl: high-precision estimate of the system time (in seconds) when the actual flip has happened
                            % ptbStimOn: An estimate of Stimulus-onset time
                            % flipDoneTime: timestamp taken at the end of Flip's execution
                            % missed: indicates if the requested presentation deadline for your stimulus has
                            %           been missed. A negative value means that dead- lines have been satisfied.
                            %            Positive values indicate a
                            %            deadline-miss.
                            % beampos: position of the monitor scanning beam when the time measurement was taken


                            %Screen('Flip', windowPtr , when =0, dontclear = 1-clr , dontsync =0 , multiflip =0);
                            [ptbVbl,ptbStimOn,flipDoneTime] = Screen('Flip', c.mainWindow,WHEN,1-clr,0,0);
                            flipDuration = flipDoneTime-startFlipTime; % For profiling only: includes the busy wait time
                            vblIsLate = ptbVbl-predictedVbl;
                            predictedVbl = ptbVbl+FRAMEDURATION; % Prediction for next frame
                            % in vsyncMode ==0 we know the  frame has
                            % flipped, log it now if it is the first frame.
                            if c.frame == 1
                                locFIRSTFRAMETIME = ptbStimOn*1000; % Faster local access for trialDuration check
                                c.firstFrame = locFIRSTFRAMETIME;% log it
                            end
                            %Stimuli should set and log their onsets/offsets as soon as they happen, in case other
                            %properties in any afterFrame() depend on them. So, send the flip time those who requested it
                            if ~isempty(c.flipCallbacks)
                                flipTime = ptbStimOn*1000-locFIRSTFRAMETIME;
                                cellfun(@(s) s.afterFlip(flipTime,ptbStimOn*1000),c.flipCallbacks);
                                c.flipCallbacks = {};
                            end
                        end


                        % Special clearing instructions for overlays
                        if clr && locHAVEOVERLAY
                            Screen('FillRect', c.overlayWindow,0,c.overlayRect); % Fill with zeros;%clearOverlay(c,true);
                        end

                        % Profiling information for debugging/tuning
                        if locPROFILE && c.frame > 1
                            addProfile(c,'FRAMELOOP','cic',c.toc);
                            tic(c)
                        end

                        % In Vsyncmode 0, the frame will have flipped by
                        % now, we start the afterFrame functions in all
                        % plugins.

                        % In Vsyncmode 1 the frame may not have flipped
                        % yet, but because afterFrame code should not do
                        % ANY drawing, we still start executing now (this is the
                        % downside of mode 1). This
                        % essentially allows us to do this processing in
                        % the time that we're otherwise waiting for the
                        % flip to occur. This has substantial, measureable
                        % advantages in reducing frame drops.
                        base(c.pluginOrder,neurostim.stages.AFTERFRAME,c);


                        % Even in asynchronous vsync mode we have to wait
                        % for the flip to complete at some point, we do
                        % that here, at the last possible time point in the
                        % frame loop.
                        if c.timing.vsyncMode ==1
                            % This will return the timing associated with
                            % the last completed flip.
                            startFlipTime = GetSecs;
                            [ptbVbl,ptbStimOn,flipDoneTime] = Screen('AsyncFlipEnd',c.mainWindow); %Blocking call.
                            flipDuration = flipDoneTime-startFlipTime; % For loggin only; includes the busy wait time, but can be negative if the flip already completed
                            vblIsLate = ptbVbl-predictedVbl;
                            predictedVbl = ptbVbl+FRAMEDURATION; % Prediction for next frame
                            % Log if this is the first frame
                            if c.frame == 1
                                locFIRSTFRAMETIME = ptbStimOn*1000; % Faster local access for trialDuration check
                                c.firstFrame = locFIRSTFRAMETIME;% log it
                            end

                            % In vsyncMode==1 we call the flipCallbacks
                            % once we know the actual ptbStimOn times and the
                            % flip has actually ocurred .
                            % This means that in vsyncMode ==1
                            % afterFrame() should not use
                            % .startTime and .stopTime. (shouldnt' really
                            % do this ever).
                            % the stimulus.logOnset/logOffset functions are
                            % callled from inside the flipCallbacks and are
                            % therefore guaranteed to run after the flip
                            % has occured. Becuase afterFram() has already
                            % completed in this mode, these are called
                            % slightly later in vsync==1 than in vsync==0.
                            if ~isempty(c.flipCallbacks)
                                flipTime = ptbStimOn*1000-locFIRSTFRAMETIME;
                                cellfun(@(s) s.afterFlip(flipTime,ptbStimOn*1000),c.flipCallbacks);
                                c.flipCallbacks = {};
                            end
                        end

                        if locPROFILE
                            addProfile(c,'FLIPTIME','cic',1000*flipDuration);
                        end

                        % check and log frame drops.
                        if c.frame > 1 && vblIsLate >ITSAMISS
                            c.frameDrop = [c.frame-1 vblIsLate]; % Log frame and delta
                        end

                    end % Trial running
                    c.stage = neurostim.cic.RUNNING;
                    %
                    % Call beforeItiFrame (can have some ITI drawing commands),
                    % then flip and clear (if requested)
                    base(c.pluginOrder,neurostim.stages.BEFOREITIFRAME,c);
                    [~,ptbStimOn]=Screen('Flip', c.mainWindow,0,1-c.itiClear);
                    clearOverlay(c,c.itiClear);
                    c.trialStopTime = ptbStimOn*1000;


                    c.frame = c.frame+1;
                    if c.hardware.maxPriorityPerTrial
                        % request 'normal' priority for the ITI
                        Priority(0);
                    end
                    afterTrial(c); %Run afterTrial routines in all plugins, including logging stimulus offsets if they were still on at the end of the trial.

                    %Exit experiment or block if requested
                    if ~c.flags.experiment || ~ c.flags.block ;break;end
                end % one block

                Screen('glLoadIdentity', c.mainWindow);
                % Perform afterBlock message/function
                afterBlock(c);
                % Exit experiment if requested 
                if ~c.flags.experiment;break;end
            end %blocks
            c.stage = neurostim.cic.POST;
            c.stopTime = now;
            Screen('Flip', c.mainWindow,0,0);% Always clear, even if clear & itiClear are false
            clearOverlay(c,true);


            base(c.pluginOrder,neurostim.stages.AFTEREXPERIMENT,c);
            c.KbQueueStop;
            %Prune the log of all plugins/stimuli and cic itself
            pruneLog([c.pluginOrder c]);

            if c.keyAfterExperiment && isempty(c.afterExperimentText)
                c.afterExperimentText = 'Press any key to close the screen';
            end
            c.drawFormattedText(c.afterExperimentText ,'ShowNow',true);


            % clean up CLUT textures used by SOFTWARE-OVERLAY
            if isfield(c.screen,'overlayClutTex') && ~isempty(c.screen.overlayClutTex)
                glDeleteTextures(numel(c.screen.overlayClutTex),c.screen.overlayClutTex(1));
                c.screen.overlayClutTex = [];
            end

            c.saveData;


            ListenChar(0);
            Priority(0);
            if c.keyAfterExperiment
                KbWait(c.kbInfo.pressAnyKey);
            end

            Screen('CloseAll');
            if c.PROFILE; report(c);end
            close(c.messenger);
        end

        function clearOverlay(c,clear)
            if clear && ~isempty(c.overlayWindow)
                Screen('FillRect', c.overlayWindow,0,c.overlayRect); % Fill with zeros
            end
        end
        function saveData(c)
            filePath = horzcat(c.fullFile,'.mat');
            save(filePath,'c');
            c.writeToFeed(sprintf('Data for trials 1:%d saved to %s',c.trial,filePath));
        end

        function delete(c) %#ok<INUSD>
            %Destructor. Tricky, because there will be many references to
            %CIC in each of the plugins etc. So the variable will be
            %cleared, but the object still exists. This is the reason to
            %define experiments as functions (so that all plugins and
            %stimuli go out of scope at the same time on return and nothing remains in the
            %workspace)

            %Screen('CloseAll');
        end

        %% Keyboard handling routines
        function oldKey = addKeyStroke(c,key,keyHelp,plg,isSubject,fun,force)
            if c.loadedFromFile
                % When loading fro file, PTB may not be installed and none
                % of the "online/intractive" funcationality is relevant.
                oldKey = struct; % empty struct
                return;
            end
            if ischar(key)
                key = KbName(key);
            end
            if ~isnumeric(key) || key <1 || key>256
                error('Please use KbName to add keys')
            end
            ix = ismember(c.kbInfo.keys,key);
            if  any(ix)
                if ~force
                    error(['The ' key ' key is in use. You cannot add it again...']);
                else
                    % Forcing a replacement - return old key so that the
                    % user can restore later.
                    oldKey.key = c.kbInfo.keys(ix);
                    oldKey.help = c.kbInfo.help{ix};
                    oldKey.plg = c.kbInfo.plugin{ix};
                    oldKey.isSubject  = c.kbInfo.isSubject(ix);
                    oldKey.fun  = c.kbInfo.fun{ix};
                end
            else
                oldKey = [];
                ix = numel(c.kbInfo.keys)+1; % Add a new one
            end
            c.kbInfo.keys(ix)  = key;
            c.kbInfo.help{ix} = keyHelp;
            c.kbInfo.plugin{ix} = plg; % Handle to plugin to call keyboard()
            c.kbInfo.isSubject(ix) = isSubject;
            c.kbInfo.fun{ix} = fun;
        end

        function removeKeyStroke(c,key)
            % removeKeyStrokes(c,key)
            % removes keys (cell array of strings) from cic. These keys are
            % no longer listened to.
            if ischar(key) || iscellstr(key) || isstring(key)
                key = KbName(key);
            end
            ix = ismember(key,c.kbInfo.keys);
            if ~any(ix)
                warning(['The ' key(~ix) ' key is not in use. You cannot remove it...??']);
            else
                out = ismember(c.kbInfo.keys,key);
                c.kbInfo.keys(out) = [];
                c.kbInfo.help(out)  = [];
                c.kbInfo.plugin(out) = [];
                c.kbInfo.isSubject(out) = [];
                c.kbInfo.fun(out) =[];
            end
        end

        function [a,b] = pixel2Physical(c,x,y)
            % converts from pixel dimensions to physical ones.
            a = (x./c.screen.xpixels-0.5)*c.screen.width;
            b = -(y./c.screen.ypixels-0.5)*c.screen.height;
        end

        function [a,b] = physical2Pixel(c,x,y)
            a = c.screen.xpixels.*(0.5+x./(c.screen.width));
            b = c.screen.ypixels.*(0.5-y./(c.screen.height));
        end

        function [fr,rem] = ms2frames(c,ms,rounded)
            %Convert a duration in msec to frames.
            %If rounded is true, fr is an integer, with the remainder
            %(in frames) returned as rem.
            if nargin<3, rounded=true;end
            fr = ms.*c.screen.frameRate/1000;
            if rounded
                inFr = round(fr);
                rem = fr-inFr;
                fr = inFr;
            end
        end

        function ms = frames2ms(c,frames)
            ms = frames*(1000/c.screen.frameRate);
        end

        %% User output Functions

        function collectFrameDrops(c)
            nrFramedrops= c.prms.frameDrop.cntr-1-c.lastFrameDrop;
            if nrFramedrops>=1
                percent=round(nrFramedrops/c.frame*100);
                c.writeToFeed(['Missed Frames: ' num2str(nrFramedrops) ', ' num2str(percent) '%%'])
                c.lastFrameDrop=c.lastFrameDrop+nrFramedrops;
            end
        end


        function addFunProp(c,plugin,prop)
            %Function properties are constructed at run-time
            %This adds one to the list to be created.
            isMatch = arrayfun(@(x) strcmpi(x.plugin,plugin)&&strcmpi(x.prop,prop),c.funPropsToMake);

            if isempty(isMatch) || ~any(isMatch)
                c.funPropsToMake(end+1).plugin = plugin;
                c.funPropsToMake(end).prop = prop;
            end
        end
        function delFunProp(c,plugin,prop)
            %Remove the specified funProp. Someone must have changesd their mind before run-time.
            isMatch = arrayfun(@(x) strcmpi(x.plugin,plugin)&&strcmpi(x.prop,prop),c.funPropsToMake);
            c.funPropsToMake(isMatch) = [];
        end

        % Update the CLUT for the overlay. Optionally specify [N 3] CLUT
        % entries and a vector of indicies into the CLUT where they should
        % be placed.
        function updateOverlay(c,clut,index)
            if nargin<3
                index = [];
                if nargin <2
                    clut  =[];
                end
            end

            [nrRows,nrCols] = size(c.screen.overlayClut);
            if ~ismember(nrCols,[0 3])
                error('The overlay CLUT should have 3 columns (RGB)');
            end

            switch upper(c.screen.type)
                case 'VPIXX-M16'
                    if nrRows ~=256
                        % Add white for missing clut entries to show error
                        % indices (assuming the bg is not max white)
                        % 0 = transparent.
                        c.screen.overlayClut = cat(1,zeros(1,3),c.screen.overlayClut,ones(256-nrRows-1,3));
                    end

                    if  isempty(clut) && isempty(index)
                        % Nothing to do
                    elseif numel(index) ~=size(clut,1) && size(clut,2) ==3 && all(index>0 & index < 255)
                        % Put in new values
                        c.screen.overlayClut(index+1,:) = clut; % index +1 becuase the first entry (index =0) is always transparent
                    else
                        error('The CLUT update contains invalid indices.');
                    end

                    Screen('LoadNormalizedGammaTable',c.mainWindow,c.screen.overlayClut,2);  %2= Load it into the VPIXX CLUT

                case 'SOFTWARE-OVERLAY'
                    % here we build a combined CLUT: indicies 1-255 are applied to
                    % the main (subject) display and indicies 257-511 are applied
                    % to the console (experimenter) display.
                    %
                    % This gives us independent control over the visibility of the
                    % contents of the overlay on the subject and experimenter displays.
                    if nrRows ~= 512
                        % generate default combined CLUT (all transparent?)
                        locClut = cat(1,zeros(1,3),repmat(c.screen.color.background,255,1));
                        locClut = repmat(locClut,2,1); % 512 x 3

                        % poke in the entries from c.screen.overlayClut
                        [idx,id] = ind2sub([nrRows/2,2],1:nrRows);
                        idx = idx + (id-1)*256;

                        locClut(idx+1,:) = c.screen.overlayClut; % +1 because the first entry in each CLUT is *always* transparent
                        c.screen.overlayClut = locClut;
                    end

                    % poke in any updates from clut...
                    [nrRows,nrCols] = size(clut);

                    if nargin < 3
                        % no indicies provided.. assume clut contains an equal
                        % number of corresponding entries for each CLUT and
                        % generate index appropriately
                        [idx,id] = ind2sub([nrRows/2,2],1:nrRows);
                        index = idx + (id-1)*256;
                    end

                    if any(index <= 0 | index == 256 | index >= 512)
                        error('The CLUT update contains invalid indices.');
                    end

                    if ~isempty(clut)  && (numel(index) ~= nrRows || nrCols ~= 3)
                        error('The CLUT update must by [N 3], with N index values (optional).');
                    end

                    c.screen.overlayClut(index+1,:) = clut; % +1 because the first entry in each CLUT is *always* transparent

                    % now we assign the CLUTs to the lookup textures...
                    locClut = c.screen.overlayClut;
                    [nrRows,nrCols] = size(locClut);

                    info = Screen('GetWindowInfo', c.mainWindow);
                    InitializeMatlabOpenGL(0,0); % defines GL.xxx constants etc.
                    if info.GLSupportsTexturesUpToBpc >= 32
                        % full 32 bit single precision float textures
                        info.internalFormat = GL.LUMINANCE_FLOAT32_APPLE;
                    elseif info.GLSupportsTexturesUpToBpc >= 16
                        % no float32 textures... use 16 bit float textures
                        info.internalFormat = GL.LUMINANCE_FLOAT16_APPLE;
                    else
                        % no support for >8 bit textures at all and/or no need for
                        % more than 8 bit precision or range... use 8 bit texture
                        info.internalFormat = GL.LUMINANCE;
                    end

                    % assign CLUT texture for the main/subject display...
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, c.screen.overlayClutTex(1));
                    % setup the filters
                    %
                    % 1. nearest neighbour (i.e., no filtering), linear filtering/interpolation
                    % is done in the ICM shader so we get accelerated linear interpolation
                    % on all GPU's (even if they're old)
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
                    % 2. clamp-to-edge, to saturate at minimum and maximum values and
                    % to make sure that a pure-luminance (1 column) CLUT is "replicated"
                    % to all three color channels in rgb modes
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);

                    glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, info.internalFormat, nrRows/2, nrCols, 0, GL.LUMINANCE, GL.FLOAT, single(locClut(1:nrRows/2,:)));
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);

                    % assign CLUT texture for the console/experimenter display...
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, c.screen.overlayClutTex(2));
                    % setup the filters...
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);

                    glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, info.internalFormat, nrRows/2, nrCols, 0, GL.LUMINANCE, GL.FLOAT, single(locClut((nrRows/2+1):nrRows,:)));
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
                otherwise
                    error('No overlay for screen type : %s',c.screen.type);
            end
        end
    end


    methods (Access=public)


        %% Keyboard handling routines(protected). Basically light wrappers
        % around the PTB core functions
        function KbQueueCreate(c)
            % Put the requested keys in KBQueues, if requested, create a
            % separate queue for stimuli (subject keybaord) and plugins
            % (experimenter keyboard)
            clear KbCheck; % Seems to be necessary on Ubuntu
            c.kbInfo.activeKb = {}; % Use a cell to store [] for "default keyboard"
            if ~isempty(c.kbInfo.subject) && ~isempty(c.kbInfo.experimenter)
                % Separate subject/experimenter keyboard defined
                keyList = zeros(1,256);
                if any(c.kbInfo.isSubject)
                    keyList(c.kbInfo.keys(c.kbInfo.isSubject)) = 1;
                    if any(keyList)
                        KbQueueCreate(c.kbInfo.subject,keyList);
                        KbQueueStart(c.kbInfo.subject);
                        c.kbInfo.activeKb{end+1} = c.kbInfo.subject;
                    end
                end
                keyList = zeros(1,256);
                if any(~c.kbInfo.isSubject)
                    keyList(c.kbInfo.keys(~c.kbInfo.isSubject)) = 1;
                    if any(keyList)
                        KbQueueCreate(c.kbInfo.experimenter,keyList);
                        KbQueueStart(c.kbInfo.experimenter);
                        c.kbInfo.activeKb{end+1} = c.kbInfo.experimenter;
                    end
                end
            else
                keyList = zeros(1,256);
                keyList(c.kbInfo.keys) = 1;
                if any(keyList)
                    KbQueueCreate(c.kbInfo.default,keyList);
                    KbQueueStart(c.kbInfo.default);
                    c.kbInfo.activeKb{end+1} = c.kbInfo.default;
                end
            end
        end


        function KbQueueCheck(c)
            for kb=1:numel(c.kbInfo.activeKb)
                [pressed, firstPress, firstRelease, lastPress, lastRelease]= KbQueueCheck(c.kbInfo.activeKb{kb});%#ok<ASGLU>
                if pressed
                    % Some key was pressed, pass it to the plugin that wants
                    % it.
                    %                 firstRelease(out)=[]; not using right now
                    %                 lastPress(out) =[];
                    %                 lastRelease(out)=[];
                    ks = find(firstPress);
                    for k=ks
                        ix = find(c.kbInfo.keys==k);% should be only one.
                        if length(ix) >1;error(['More than one plugin (or derived class) is listening to  ' KbName(k) '??']);end
                        if isempty(c.kbInfo.fun{ix})
                            % Use the plugin's keyboard function
                            keyboard(c.kbInfo.plugin{ix},KbName(k));%,firstPress(k));
                        else
                            % Use the specified function
                            c.kbInfo.fun{ix}(c.kbInfo.plugin{ix},KbName(k));%,firstPress(k));
                        end
                    end
                end
            end
        end

        function drawFormattedText(c,text,varargin)
            % Wrapper around PTB function that can send an echo to the
            % command line (useful if the experimenter cannot see the
            % subject screen). Needs to be public to allow (some) plugins
            % access.
            p = inputParser;
            p.addParameter('left','center') % The sx parameter in PTB
            p.addParameter('top','center') % The sy parameter in PTB
            p.addParameter('wrapAt',[]) % The wrapAt parameter in PTB
            p.addParameter('flipHorizontal',0) % The flipHorizontal parameter in PTB
            p.addParameter('flipVertical',0) % The flipVertical parameter in PTB
            p.addParameter('vSpacing',1) % The vSpacing parameter in PTB
            p.addParameter('rightToLeft',0) % The righttoleft parameter in PTB
            p.addParameter('winRect',[0 0 c.screen.xpixels c.screen.ypixels]) % The winRect parameter in PTB
            p.addParameter('showNow',false); % Call Screen('Flip') immediately
            p.addParameter('echo',true); % Overrule hardware.echo
            p.parse(varargin{:});

            DrawFormattedText(c.textWindow,text, p.Results.left, p.Results.top, c.screen.color.text, p.Results.wrapAt, p.Results.flipHorizontal, p.Results.flipVertical, p.Results.vSpacing, p.Results.rightToLeft, p.Results.winRect);
            if c.hardware.textEcho && p.Results.echo
                if ~c.useConsoleColor
                    style = 'NOSTYLE';
                else
                    style = 'MAGENTA';
                end
                c.writeToFeed(sprintf('Screen Message: %s\n',text),'style',style);
            end
            if p.Results.showNow
                Screen('Flip',c.mainWindow,[],0); % This will clear text from the backbuffer
                if c.textWindow == c.overlayWindow
                    clearOverlay(c,true); % If text is written to overlay, clear the overlay too
                end
            end
        end

    end

    methods (Access=private)
        function createRNGstreams(c, varargin)
            %USAGE:
            %
            %c.createRNGstreams('nStreams',4,'type','mrg32k3a','seed',mySeed);
            %c.createRNGstreams('type','gpuCompatible');
            %
            %Create a set of independent RNG streams. One is assigned to
            %CIC and used as the global RNG. Plugins can request their own
            %with addRNGstream(o) (e.g. as currently done in noiseclut.m)
            %to hold a private stream. See RandStream for info about
            %creating streams in Matlab and why we handle this centrally.
            %We handle some RandStream arguments here, to provide defaults,
            %but all other param-value pairs are passed onto Matlab's
            %RandStream.create(). You could use the 'seed' argument to
            %return CIC RNG streams to a previous state.
            %
            %** Using RNGs with gpuArrays (Parallel Computing Toolbox) **
            %
            %gpuArrays are a fast way to make, for example, large random
            %noise images (computed on the GPU). But if we do nothing,
            %rand(..,'gpuArray'), randn(..,'gpuArray'), etc. will use an
            %RNG that is not controlled by us, not independent of ours on
            %the CPU, and not logged. Use 'gpuCompatible' type to force the
            %CPU and GPU random number generators to match (seed,
            %algorithm, normTransform) - there's only one we can use -
            %allowing RNG streams of both types to be reconstructed
            %offline.
            %
            %The N RNG streams on the CPU and CPU are clones, give
            %identical numbers. addRNGstream(o,1,false) or
            %addRNGstream(o,1,true), will add a CPU or GPU RNG respectively to
            %your plugin (o.rng). The unused counterpart is deleted. i.e.
            %stream 2 can be used as a CPU or GPU RNG but not both.
            %
            %You will need the Parallel Computing Toolbox to use gpuArrays
            %and to re-gain access to a GPU-based RNG for a saved CIC
            %object. Without it, load() will warn that it cannot create an
            %object of class "RandStream" (class not found), but it is
            %actualy looking for parallel.gpu.RandStream. You could still
            %recreate your GPU streams using CPU-based RNGs with the
            %parameters stored in c.rng. (Note, all streams are created
            %from c.rng.Seed)

            p=inputParser;
            p.addParameter('type','mrg32k3a',@(t) ismember(t,{'gpuCompatible','mrg32k3a','mlfg6331_64', 'mrg32k3a','philox4x32_10','threefry4x64_20'}));  %These support multiple streams
            p.addParameter('nStreams',3);       %We'll leave the argument validation to RandStream.
            p.addParameter('seed','shuffle');   %shuffle means RandStream uses clocktime
            p.addParameter('normalTransform',[]);
            p.parse(varargin{:});

            %Put any RandStream param-value pairs into a cell array
            prms = fieldnames(p.Unmatched);
            vals = struct2cell(p.Unmatched);
            args(1:2:numel(prms)*2-1) = prms;
            args(2:2:numel(prms)*2) = vals;

            p = p.Results;

            if strcmpi(p.type,'gpuCompatible')
                if ~any(arrayfun(@(pkg) strcmpi(pkg.Name,'Parallel Computing Toolbox'),ver))
                    error('GPU operations requested but resource missing: Parallel Computing Toolbox must be installed.');
                end
                if ~gpuDeviceCount
                    error('GPU operations requested but resource missing: No gpuDevice on this system. Type "help gpuDevice" for info.');
                end

                %The default cpu RNG algorithm does not exist on the GPU. Also, only the "inversion" normal transformation is supported on both CPU and GPU (needed for randn to produce identical numbers).
                %So, check for those parameters here and overrule if necessary.
                warning('RNG type has been switched to ''threefry'' to support GPU-based RNGs');
                warning('RNG normal transformation has been switched to ''inversion'' to support GPU-based RNGs');

                if ~isempty(prms)
                    warning('Supplied custom RNG arguments have been ignored to ensure CPU and GPU RNGs are identical');
                end

                makeGPUstreams = true;
                p.type = 'threefry4x64_20';
                p.normalTransform = 'Inversion';
                args={};
            else
                makeGPUstreams = false;
            end

            %Make the CPU streams
            c.spareRNGstreams = RandStream.create(p.type,'NumStreams',p.nStreams,'seed',p.seed, 'NormalTransform',p.normalTransform, 'cellOutput',true,args{:});

            if makeGPUstreams
                %Make GPU streams that are identical to those on the CPU
                c.spareRNGstreams_GPU = parallel.gpu.RandStream.create(p.type,'NumStreams',p.nStreams,'seed',c.spareRNGstreams{1}.Seed, 'NormalTransform',p.normalTransform, 'cellOutput',true);

                %Do a quick check to make sure that the CPU and GPU RNGs give the same result
                cpuRNG = c.spareRNGstreams{1};
                gpuRNG = c.spareRNGstreams_GPU{1};
                origState = cpuRNG.State;
                if ~isequal(cpuRNG.State,gpuRNG.State) || ~isequal(rand(cpuRNG,1,10),gather(rand(gpuRNG,1,10)))
                    error('GPU and CPU RNGs are not matched. Something is wrong!');
                else
                    %All good. Restore initial state
                    [cpuRNG.State,gpuRNG.State] = deal(origState);
                end
            end

            %Add a CPU stream to CIC
            addRNGstream(c);

            %Set the global CPU stream to use CIC's rng (we don't set the global stream on the GPU - that's up to plugins that request a GPU RNG to deal with)
            RandStream.setGlobalStream(c.rng);

        end

        function sanityChecks(c)
            % This function is called just before starting the first trial, whic his kist
            % after running beforeExperiment in all plugins. It serves to
            % do some error checking and provide the user with information
            % on what is about to happen.

            % Plugin order
            disp(['================ ' c.file ' =============================='])
            disp('Plugin/Stimulus code will be evaluated in the following order:')
            fprintf(1,'%s --> ', c.pluginOrder.name)
            disp('Parameter plugins should depend only on plugins with earlier execution (i.e. to the left)');
        end
            
        function handleAdaptives(c)
            % Force adaptive plugins assigned directly to parameters into
            % the block design object(s) instead. This ensures the adaptive
            % plugins are updated correctly (by the block object(s)).
           
            plgs = {c.pluginOrder.name}; % *all* plugins
            for ii = 1:numel(plgs)
              plg = plgs{ii};
              prms = prmsByClass(c.(plg),'neurostim.plugins.adaptive');
              if isempty(prms)
                % no adaptive plugins/parameters
                continue
              end

              for jj = 1:numel(prms)
                prm = prms{jj};
                obj = c.(plg).(prm);
                c.(plg).(prm) = obj.getAdaptValue(); % default value?
 
                % loop over blocks, adding plg.prm = obj
                arrayfun(@(x) addAdaptive(x,plg,prm,obj),c.blocks);
              end
            end
        end
        %% PTB Imaging Pipeline Setup
        function PsychImaging(c)
            % Tthis initializes the
            % main winodw (and if requested, an overlay) according to the
            % specifications in c.screen. This is typically called once (by
            % cic.run)
            %

            c.setupScreen; % Physical parameters
            colorOk = loadCalibration(c); % Monitor calibration parameters from file.


            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');% 32 bit frame buffer values
            PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');% Unrestricted color range
            PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');


            %% Setup pipeline for use of special monitors like the ViewPixx or CRS Bits++
            switch upper(c.screen.type)
                case 'GENERIC'
                    % Generic monitor.              
                case 'VPIXX-M16'
                    % The VPIXX monitor in Monochrome 16 bit mode.
                    % Set up your vpixx once, using
                    % BitsPlusImagingPipelineTest(screenID);
                    % BitsPlusIdentityClutTest(screenID,1); this will
                    % create correct identity cluts.
                    PsychImaging('AddTask', 'General', 'UseDataPixx');
                    PsychImaging('AddTask', 'General', 'EnableDataPixxM16OutputWithOverlay');
                    % After upgrading to Win10 we seem to need this.
                    PsychDataPixx('PsyncTimeoutFrames' , 1);
                case 'DISPLAY++'
                    % The CRS Display++
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
                    PsychImaging('AddTask', 'General', 'EnableBits++Mono++Output');
                case 'DISPLAY++COLOR'
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
                    PsychImaging('AddTask', 'General', 'EnableBits++Color++Output',2);
                case 'SOFTWARE-OVERLAY'
                    % Magic software overlay... replicates (in software) the
                    % dual CLUT overlay of the VPixx M16 mode. See below
                    % for more details.
                otherwise
                    error(['Unknown screen type : ' c.screen.type]);
            end

            %%  Setup color calibration
            %
            switch upper(c.screen.colorMode)
                case 'LINLUT'
                    % Load a gamma table that linearizes each gun
                    % Dont do this for VPIXX etc. monitor types.(although this should work, LUM works better; not recommended).
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'LookupTable');
                case 'LUM'
                    % The user specifies luminance values per gun as color.
                    % Calibrateed responses are based on the extended gamma
                    % function fits.
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
                case 'XYZ'
                    % The user specifies tristimulus values as color.
                    if ~colorOk; error('Please specify a calibration file (cic.screen.calFile) and color matching functions (cic.screen.colorMatchingFunctions) ');end
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SensorToPrimary');
                case 'XYL'
                    % The user specifies CIE chromaticity and luminance (xyL) as color.
                    if ~colorOk; error('Please specify a calibration file (cic.screen.calFile) and color matching functions (cic.screen.colorMatchingFunctions) ');end
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'xyYToXYZ');
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SensorToPrimary');
                case 'RGB'
                    % The user specifies "raw" RGB values as color. These may or may not have been gamma
                    % corrected by specifying a gammatable (c.screen.calibration.gammaTable ) or calibration
                    % file (c.screen.calFile) that contains a gammatable.
                    Screen('LoadNormalizedGammaTable',c.screen.number,c.screen.calibration.gammaTable);
                    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'None');
                otherwise
                    error(['Unknown color mode: ' c.screen.colorMode]);
            end
            % Check color validity
            if c.screen.colorCheck
                PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'CheckOnly');
            end
            %% Open the window
            c.mainWindow = PsychImaging('OpenWindow',c.screen.number, c.screen.color.background,[c.screen.xorigin c.screen.yorigin c.screen.xorigin+c.screen.xpixels c.screen.yorigin+c.screen.ypixels],[],[],[],[],kPsychNeedFastOffscreenWindows);
            c.textWindow = c.mainWindow; % By default - changed below if needed.

            %% Perform initialization that requires an open window
            switch upper(c.screen.type)
                case 'GENERIC'
                    % nothing to do
                case 'VPIXX-M16'
                    if (all(round(c.screen.color.background) == c.screen.color.background))
                        % The BitsPlusPlus code thinks that any luminance
                        % above 1 that is an integer is a 0-255 lut entry.
                        % The warning is wrong; with the new graphics
                        % pipeline setup it works fine as a calibrated
                        % luminance.
                        c.writeToFeed('****You can safely ignore the message about '' clearcolor'' that just appeared***');
                    end
                    % Create an overlay window to show colored items such
                    % as a fixation point, or text.
                    c.overlayWindow = PsychImaging('GetOverlayWindow', c.mainWindow);
                    c.overlayRect =  Screen('Rect',c.overlayWindow);
                    c.textWindow = c.overlayWindow;
                    Screen('Preference', 'TextAntiAliasing',0); %Antialiasing on the overlay will result in weird colors
                    updateOverlay(c);
                case {'DISPLAY++', 'DISPLAY++COLOR'}
                    % nothing to do
                case 'SOFTWARE-OVERLAY'
                    % With this display type you draw your stimuli on the
                    % left half of c.mainWindow and it is mirrored on the right
                    % half. You can optionally also draw to an overlay
                    % window, c.overlayWindow. The contents of the overlay
                    % are drawn over the top of your stimulus, optionally
                    % using different CLUTs for the left and right half of
                    % the screen.
                    %
                    % This is most useful when c.screen.number spans two
                    % physical displays, one for the subject (the main display)
                    % and one for the experimenter (the console display).
                    % Using separate overlay CLUTs for each allows you to
                    % independently control the content of the overlay
                    % visible to the subject and experimenter. You can for
                    % example show eye position on the console display
                    % without it being visible to the subject.

                    InitializeMatlabOpenGL(0,0); % defines GL.xxx constants etc.

                    % halve the screen width so that drawing of stimuli works as expected
                    c.screen.xpixels = c.screen.xpixels/2;

                    % Create a custom shader for overlay texel fetch:
                    %
                    % Our gpu panel scaler might be active, so the size of the
                    % virtual window - and thereby our overlay window - can be
                    % different from the output framebuffer size. As the sampling
                    % position for the overlay is always provided in framebuffer
                    % coordinates, we need to subsample in the overlay fetch.
                    %
                    % Calculate proper scaling factor, based on virtual and real
                    % framebuffer size:
                    [wC, hC] = Screen('WindowSize', c.mainWindow);
                    [wF, hF] = Screen('WindowSize', c.mainWindow, 1);
                    sampleX = wC / wF;
                    sampleY = hC / hF;

                    % string definition of overlay panel-filter index shader
                    % (solution for dealing with retina resolution displays carried over from BitsPlusPlus.m)
                    shSrc = sprintf('uniform sampler2DRect overlayImage; float getMonoOverlayIndex(vec2 pos) { return(texture2DRect(overlayImage, pos * vec2(%f, %f)).r); }', sampleX, sampleY);

                    % temporarily set the color range (this will be inherited by the offscreen overlay window)
                    colorRange = Screen('ColorRange', c.mainWindow, 255);
                    % create the overlay window, note: the window size (c.screen.xpixels) is assumed to have been halved above...
                    c.overlayWindow = Screen('OpenOffscreenWindow', c.mainWindow, 0, [0 0 c.screen.xpixels c.screen.ypixels], 8, 32);
                    % restore the color range setting
                    Screen('ColorRange', c.mainWindow, colorRange);

                    c.overlayRect = Screen('Rect',c.overlayWindow);

                    % retrieve low-level OpenGl texture handle for the overlay window
                    overlayTexture = Screen('GetOpenGLTexture', c.mainWindow, c.overlayWindow);

                    % disable bilinear filtering on this texture... always use nearest neighbour
                    % sampling to avoid interpolation artifacts
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, overlayTexture);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
                    glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
                    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);

                    % get information on current processing chain
                    debuglevel = 1;
                    [icmShaders, icmIdString, icmConfig] = PsychColorCorrection('GetCompiledShaders', c.mainWindow, debuglevel);

                    % build panel-filter compatible shader from source
                    overlayShader = glCreateShader(GL.FRAGMENT_SHADER);
                    glShaderSource(overlayShader, shSrc); % shSrc is the src string from above
                    glCompileShader(overlayShader);

                    % append to list of shaders
                    icmShaders(end+1) = overlayShader;

                    shader = LoadGLSLProgramFromFiles(fullfile(c.dirs.root,'+neurostim','overlay_shader.frag'), debuglevel, icmShaders);

                    % create textures for overlay CLUTs
                    c.screen.overlayClutTex = glGenTextures(2);

                    % set variables in the shader
                    glUseProgram(shader);
                    glUniform1i(glGetUniformLocation(shader, 'lookup1'), 3);
                    glUniform1i(glGetUniformLocation(shader, 'lookup2'), 4);
                    glUniform2f(glGetUniformLocation(shader, 'res'), c.screen.xpixels*(1/sampleX), c.screen.ypixels);  % [partially] corrects overlay width & position on retina displays
                    glUniform3f(glGetUniformLocation(shader, 'transparencycolor'), c.screen.color.background(1), c.screen.color.background(2), c.screen.color.background(3));
                    glUniform1i(glGetUniformLocation(shader, 'overlayImage'), 1);
                    glUniform1i(glGetUniformLocation(shader, 'Image'), 0);
                    glUseProgram(0);

                    % assign the overlay texture as the input 1 ('overlayImage' as set above)
                    % It gets passed to the HookFunction call.
                    % Input 0 is the main pointer by default.
                    pString = sprintf('TEXTURERECT2D(1)=%i ', overlayTexture);
                    pString = [pString sprintf('TEXTURERECT2D(3)=%i ', c.screen.overlayClutTex(1))];
                    pString = [pString sprintf('TEXTURERECT2D(4)=%i ', c.screen.overlayClutTex(2))];

                    % add information to the current processing chain
                    idString = sprintf('Overlay Shader : %s', icmIdString);
                    pString  = [ pString icmConfig ];
                    Screen('HookFunction', c.mainWindow, 'Reset', 'FinalOutputFormattingBlit');
                    Screen('HookFunction', c.mainWindow, 'AppendShader', 'FinalOutputFormattingBlit', idString, shader, pString);
                    PsychColorCorrection('ApplyPostGLSLLinkSetup', c.mainWindow, 'FinalFormatting');

                    c.textWindow = c.overlayWindow;

                    % setup CLUTs...
                    updateOverlay(c);
                otherwise
                    error(['Unknown screen type : ' c.screen.type]);
            end

            %% Add calibration to the window
            switch upper(c.screen.colorMode)
                case 'LINLUT'
                    % Invert the supplied gamma table

                    % note: here we read the current gamma table to determine the number of slots in the
                    %       hardware lookup table and compute the inverse gamma table to suit...
                    tbl = Screen('ReadNormalizedGammaTable', c.mainWindow);
                    iGamma = InvertGammaTable(c.screen.calibration.gammaInput, c.screen.calibration.gammaTable, size(tbl,1));
                    clear tbl
                    PsychColorCorrection('SetLookupTable', c.mainWindow, iGamma, 'FinalFormatting');
                case 'LUM'
                    % Default gamma is set to 2.2. User can change in c.screen.calibration.gamma
                    PsychColorCorrection('SetEncodingGamma', c.mainWindow,1./c.screen.calibration.ns.gamma);
                    if isnan(c.screen.calibration.ns.bias)
                        % Only gamma defined
                        PsychColorCorrection('SetColorClampingRange',c.mainWindow,0,1); % In non-extended mode, luminance is between [0 1]
                    else
                        % If the user set the calibration.bias parameters then s/he wants to perform a slightly more advanced calibration
                        % out = bias + gain * ((lum-minLum)./(maxLum-minLum)) ^1./gamma )
                        % where each parameter can be specified per gun
                        % (i.e. c.calibration.bias= [ 0 0.1 0])
                        PsychColorCorrection('SetExtendedGammaParameters', c.mainWindow, c.screen.calibration.ns.min, c.screen.calibration.ns.max, c.screen.calibration.ns.gain,c.screen.calibration.ns.bias);
                        % This mode accepts luminances between min and max
                    end
                case {'XYZ','XYL'}
                    % Apply color calibration to the window
                    PsychColorCorrection('SetSensorToPrimary', c.mainWindow, c.screen.calibration);
                case {'RGB'}
                    % Nothing to do (gamma table already loaded for the screen above)
                otherwise
                    error(['Unknown color mode: ' c.screen.colorMode]);
            end
            PsychColorCorrection('SetColorClampingRange',c.mainWindow,0,1); % Final pixel value is between [0 1]

            %% Perform additional setup routines
            Screen(c.mainWindow,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            assignWindow(c.pluginOrder); % Tell the plugins about this window
        end


        function KbQueueStop(c)
            for kb=1:numel(c.kbInfo.activeKb)
                KbQueueStop(c.kbInfo.activeKb{kb});
                KbQueueRelease(c.kbInfo.activeKb{kb});
            end
        end

        function colorOk = loadCalibration(c)
            colorOk = false;

            switch upper(c.screen.colorMode)
                case 'RGB'
                    if isempty(c.screen.calFile) && isempty(c.screen.calibration.gammaTable)
                        % Neither a file specified, nor a table. Set a linear gamma table
                        % The experiment will use pure,uncorrected RGB
                        % values.
                        dac =8;% 8 bits
                        c.screen.calibration.gammaTable =repmat(linspace(0,1,2^dac)',[1 3]);
                    elseif ~isempty(c.screen.calFile) && isempty(c.screen.calibration.gammaTable)
                        % Load a variable called gammaTable* from a named
                        % file. If the file as multiple variables that
                        % match this, pick the first. If there are none,
                        % generate an error.
                        ff =fullfile(c.dirs.calibration,c.screen.calFile);
                        if ~exist(ff,'file')
                            error('The calibration file %s does not exist.',ff);
                        end
                        tmp=load(ff);
                        fn = fieldnames(tmp);
                        ix= find(startsWith(fn,'gammaTable','IgnoreCase',true));
                        if numel(ix)>1
                            c.writeToFeed(sprintf('There are %d gammaTable variables in %s. Using the first (%s)',numel(ix), ff,fn{ix(1)}));
                            ix =ix(1);
                        elseif isempty(ix)
                            error('No gammaTable in %s', ff);
                        end
                        tbl = tmp.(fn{ix});
                        if size(tbl,2)==1
                            tbl = repmat(tbl,[1 3]);
                        end
                        c.screen.calibration.gammaTable = tbl;
                    elseif ~isempty(c.screen.calFile) && ~isempty(c.screen.calibration.gammaTable)
                        error('Both a gamma table and a gamma table file (%s) were specified. Please pick one.',c.screen.calFile);
                    else 
                        % c.screen.calibration.gammatable specified
                        % somehow- nothing to do, it will be used.
                    end
                otherwise
                    if ~isempty(c.screen.calFile)
                        % Load a full calibration from file. The cal struct has been
                        % generated by utils.ptbcal

                        c.screen.calibration = LoadCalFile(c.screen.calFile,Inf,c.dirs.calibration); % Retrieve the latest calibration
                        if isempty(c.screen.calibration)
                            error(['Could not load a PTB calibration file from: ' fullfile(c.dirs.calibration,c.screen.calFile)]);
                        end

                        if ~isempty(c.screen.colorMatchingFunctions)
                            % The "sensor" is the human observer and we can pick different ones by
                            % chosing a different CMF (in c.screen.cmf). Sensor coordinates
                            % are XYZ tristimulus values.
                            % Apply color matching functions
                            tmpCmf = load(c.screen.colorMatchingFunctions);
                            fn = fieldnames(tmpCmf);
                            Tix = strncmpi('T_',fn,2); % Assuming the convention that the variable starting with T_ contains the CMF
                            Six = strncmpi('S_',fn,2); % Variable starting with S_ specifies the wavelengths
                            T = tmpCmf.(fn{Tix}); % CMF
                            S = tmpCmf.(fn{Six}); % Wavelength info
                            T = 683*T;
                            c.screen.calibration = SetSensorColorSpace(c.screen.calibration,T,S);
                            colorOk = true;
                        end

                        c.screen.calibration = SetGammaMethod(c.screen.calibration,0); % Linear interpolation for Gamma table
                    end
            end

        end



    end

    methods (Access=?neurostim.plugin)

        function rng = requestRNGstream(c,nStreams,makeItAGPUrng)
            %Plugins can request their own RNG stream. We created N (3) RNG
            %streams on construction of CIC, so allocate one of those now.
            %If all are exhausted, issue error and instruct user to
            %increase the initial allocation number through the rngArgs
            %argument of the CIC constructor.
            %
            %Some plugins/tasks require an RNG on the GPU (for use with
            %gpuArray objects), so if requested, return one of that type.
            %
            %nStreams [1]:          number of streams to add to this plugin. If
            %                       greater than 1, o.rng will be a cell array of streams.
            %makeItAGPUrng [false]: should the returned RNG(s) be on the CPU or GPU?

            if nargin < 2 || isempty(nStreams)
                nStreams = 1;
            end

            if nargin < 3 || isempty(makeItAGPUrng)
                makeItAGPUrng = false(1,nStreams);
            end

            if nStreams~=numel(makeItAGPUrng)
                error('''makeItAGPUrng'' must be a logical vector of length equal to nStreams');
            end

            %Make sure there are enough RNG streams left
            if numel(c.spareRNGstreams)< nStreams
                error('Not enough RNG streams available to meet the request. Increase the initial allocation through the ''rngArgs'' argument of the CIC constructor.');
            end

            %Make sure that GPU-based RNGs were created, if one is requested
            if any(makeItAGPUrng) && isempty(c.spareRNGstreams_GPU)
                error('GPU RNG requested but CIC was not asked to create any of that type. Type "help neurostim.cic.createRNGstreams"');
            end

            %OK, allocate them
            rng = cell(1,nStreams);
            for i=1:nStreams
                if ~makeItAGPUrng(i)
                    %Return a CPU rng
                    rng{i} = c.spareRNGstreams{i};
                else
                    %Return a GPU rng
                    rng{i} = c.spareRNGstreams_GPU{i};
                end
            end

            %Remove the allocated streams from CPU list (and GPU list if one was made, to keep both types in alignment)
            c.spareRNGstreams(1:nStreams) = [];
            if ~isempty(c.spareRNGstreams_GPU)
                c.spareRNGstreams_GPU(1:nStreams) = [];
            end


            if numel(rng)==1
                rng = rng{1};
            end
        end
    end


    methods (Static)
        function v = clockTime
            v = GetSecs*1000;
        end

        function c = loadobj(o)
            % Classdef has changed over time - fix some things here.
            if isstruct(o)
                % Current CIC classdef does not match classdef in force
                % when this object was saved.
                % Create an object according to the current classdef
                current = neurostim.cic('fromFile',true); % Create an empty cic of current classdef that does not need PTB (loadedFromFile =true)
                % And upgrade the one that was stored using the plugin
                % static member.
                c = neurostim.plugin.updateClassDef(o,current);
            else
                % No need to call the plugin.loadobj
                c = o;
            end

            c.loadedFromFile = true; % Set to true to avoid PTB dependencies
            % Some postprocessing.

            % The saved plugins and parameters of CIC still refer to the old-style (i.e. saved)
            % cic. Update the handle
            c.cic = c; % Self reference needed

            for plg = c.pluginOrder
                plg.cic = c; % Point each plugin to the updated/new style cic.
            end


            % If the last trial does not reach firstFrame, then
            % the trialTime (which is relative to firstFrame) cannot be calculated
            % This happens, for instance, when endExperiment is called by a plugin
            % during an ITI.

            % Add a fake firstFrame to fix this.
            lastTrial = c.prms.trial.cntr-1; % trial 0 is logged as well, so -1
            nrFF = c.prms.firstFrame.cntr-1;
            if nrFF > 0 && lastTrial == nrFF +1
                % The last trial did not make it to the firstFrame event.
                % generate a fake firstFrame.
                t = [c.prms.firstFrame.log{:}];
                mTimeBetweenFF = median(diff(t));
                fakeFF = t(end) + mTimeBetweenFF;
                storeInLog(c.prms.firstFrame,fakeFF,NaN)
            end

            % Check c.stage and issue a warning if this seems like a crashed session
            if c.stage ~= neurostim.cic.POST
                warning('This experiment ended unexpectedly (c.stage == %i; Should be %i). Some trials may be missing.', ...
                    c.stage,neurostim.cic.POST);
            end

        end



    end

    methods


        function report(c)
            %% Profile report
            plgns = fieldnames(c.profile);
            items={};
            for i=1:numel(plgns)
                if c.profile.(plgns{i}).cntr==0;break;end
                MAXDURATION = 3*1000/c.screen.frameRate;
                figure('Name',plgns{i},'position',[680   530   818   420]);
                clf;
                items = fieldnames(c.profile.(plgns{i}));
                items(strcmpi(items,'cntr'))=[];
                nPlots = numel(items);
                nPerRow = floor(sqrt(nPlots));
                nPerCol = ceil(nPlots/nPerRow);

                for j=1:nPlots
                    subplot(nPerCol,nPerRow,j);
                    vals{i,j} = c.profile.(plgns{i}).(items{j}); %#ok<AGROW>
                    out =isinf(vals{i,j}) | isnan(vals{i,j});
                    thisVals= min(vals{i,j}(~out),MAXDURATION);
                    histogram(thisVals,100);
                    xlabel 'Time (ms)'; ylabel '#'
                    title(horzcat(items{j},'; Median = ', num2str(round(nanmedian(vals{i,j}),2))));
                end
            end
            if numel(plgns)>1
                figure('Name','Total','position',[680   530   818   420]);
                clf
                frameItems = find(~cellfun(@isempty,strfind(items,'FRAME'))); %#ok<STRCLFH>
                cntr=1;
                for j=frameItems'
                    subplot(1,2,cntr);
                    total = cat(1,vals{2:end,j});
                    total =sum(total);
                    out =isinf(total) | isnan(total);
                    total = min(total(~out),MAXDURATION);
                    histogram(total,100);
                    xlabel 'Time (ms)'; ylabel '#'
                    title(horzcat(items{j},'; Median = ', num2str(round(nanmedian(total)))));
                    cntr = cntr+1;
                    hold on
                    plot(1000./c.screen.frameRate*ones(1,2),ylim,'r')
                end
            end
            %% Framedrop report
            [val,tr,ti,eTi] = get(c.prms.frameDrop,'atTrialTime',[]); %#ok<ASGLU>
            if size(val,1)==1
                % No drops
                disp('*** No Framedrops!***');
                return
            end
            delta =1000*val(:,2); % How much too late...
            slack = 0.2;
            [~,~,criticalStart] = get(c.prms.firstFrame,'atTrialTime',inf);
            [~,~,criticalStop] = get(c.prms.trialStopTime,'atTrialTime',inf);
            meanDuration = nanmean(criticalStop-criticalStart);
            out = (ti<(criticalStart(tr)-slack*meanDuration) | ti>(criticalStop(tr)+slack*meanDuration));


            figure('Name',[c.file ' - framedrop report for stimuli'])

            for i=1:c.nrStimuli
                subplot(c.nrStimuli+2,1,i)
                [~,~,stimstartT] = get(c.stimuli(i).prms.startTime,'atTrialTime',inf);
                relativeTime  = ti(~out)-stimstartT(tr(~out));
                relativeTrial  = tr(~out);
                plot(relativeTime,relativeTrial,'.')
                xlabel('Time from stim start (ms)')
                ylabel 'Trial'
                title (c.stimuli(i).name )
                set(gca,'YLim',[0 max(relativeTrial)+1],'YTick',1:max(relativeTrial),'XLIm',[-slack*meanDuration (1+slack)*meanDuration])
            end
            subplot(c.nrStimuli+2,1,c.nrStimuli+1)
            nrBins = max(10,round(numel(ti)/10));

            histogram(ti-criticalStart(tr),nrBins,'BinLimits',[-slack*meanDuration (1+slack)*meanDuration]);%,tBins)

            xlabel 'Time from trial start (ms)'
            ylabel '#drops'


            subplot(c.nrStimuli+2,1,c.nrStimuli+2)
            frameduration = 1000./c.screen.frameRate;
            bins  = linspace(-frameduration,frameduration,20);
            histogram(delta,bins);%
            title(['median = ' num2str(nanmedian(delta))])
            xlabel 'Delta (ms)'
            ylabel '#drops'

            if c.nrBehaviors>0
                %% Compare frame drops to state transitions
                % Currenlty only loking at the first transition iunto a
                % state...
                figure('Name',[c.file ' - framedrop report for behavior state changes'])
                B = c.behaviors;
                nrB = numel(B);
                colors = 'rgbcmyk';
                for i=1:nrB
                    subplot(nrB,1,i)
                    % Get first state transition in trials with drops,
                    [state,stateTrial,stateStartT] = get(B(i).prms.state,'atTrialTime',[],'withDataOnly',true,'trial',unique(tr),'first',1);
                    uStates = unique(state);
                    for s=1:numel(uStates)
                        thisState = ismember(state,uStates{s});
                        thisTrials = stateTrial(thisState);
                        trialsWithStateAndDrops = tr(ismember(tr,thisTrials));
                        dropTime = ti(ismember(tr,trialsWithStateAndDrops));
                        relativeTime = dropTime-stateStartT(trialsWithStateAndDrops);
                        plot(relativeTime,trialsWithStateAndDrops,['o' colors(s)]);
                        hold on
                    end
                    xlabel('Time from State start (ms)')
                    ylabel 'Trial'
                    title ([B(i).name '- First State Transitions INTO'])
                    set(gca,'YLim',[0 max(stateTrial)+1],'YTick',1:max(stateTrial),'XLIm',[-slack*meanDuration (1+slack)*meanDuration])
                    legend (uStates)
                end

            end

        end


        function addProfile(c,what,name,duration)
            BLOCKSIZE = 1500;
            c.profile.(name).cntr = c.profile.(name).cntr+1;
            thisCntr = c.profile.(name).cntr;
            if thisCntr > numel(c.profile.(name).(what))
                c.profile.(name).(what) = [c.profile.(name).(what) nan(1,BLOCKSIZE)];
            end
            c.profile.(name).(what)(thisCntr) =  duration;
        end

        function tic(c)
            c.ticTime = GetSecs*1000;
        end

        function elapsed = toc(c)
            elapsed = GetSecs*1000 - c.ticTime;
        end
    end

    methods (Access = {?neurostim.stimulus})
        function addFlipCallback(o,s)
            o.flipCallbacks = horzcat(o.flipCallbacks,{s});
        end
    end


end
