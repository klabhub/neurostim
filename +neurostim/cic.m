% Command and Intelligence Center for Neurostim using PsychToolBox.
% See demos directory for examples
%  BK, AM, TK, 2015
classdef cic < neurostim.plugin
    
    %% Constants
    properties (Constant)
        PROFILE@logical = false; % Using a const to allow JIT to compile away profiler code
        SETUP   = 0;
        RUNNING = 1;
        POST    = 2;
    end
    
    %% Public properties
    % These can be set in a script by a user to setup the
    % experiment
    properties (GetAccess=public, SetAccess =public)
        mirrorPixels@double   = []; % Window coordinates.[left top width height].
        cursor = 'arrow';        % Cursor 'none','arrow';
        dirs                    = struct('root','','output','','calibration','')  % Output is the directory where files will be written, root is where neurostim lives, calibration stores calibration files
        subjectNr@double        = [];
        latinSqRow@double       = [];
        runNr@double            = []; % Bookkeeping
        paradigm@char           = 'test';
        clear@double            = 1;   % Clear backbuffer after each swap. double not logical
        itiClear@double         = 1;    % Clear backbuffer during the iti. double. Set to 0 to keep the last display visible during the ITI (e.g. a fixation point)
        fileOverwrite           = false; % Allow output file overwrite.
        useConsoleColor         = false; % Set to true to allow plugins and stimuli use different colors to write to the console. There is some time-cost to this (R2018a), hence the default is false.
        saveEveryN              = 10;
        saveEveryBlock          = false;
        keyBeforeExperiment     = true;
        keyAfterExperiment      = true;
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
            'calibration',struct('gamma',2.2,'bias',nan(1,3),'min',nan(1,3),'max',nan(1,3),'gain',nan(1,3)),...
            'overlayClut',[]);    % screen-related parameters.
        
        timing = struct('vsyncMode',0,... % 0 = busy wait until vbl, 1 = schedule flip then return, 2 = free run
            'frameSlack',0.1,... % Allow x% slack of the frame in screen flip time.
            'pluginSlack',0,...% see plugin.m
            'useWhen',false);  %Use the when argument to Screen('Flip') or not.
        
        hardware                = struct('sound',struct('device',-1,'latencyClass',1) ... % Sound hardware settings (device = index of audio device to use, see plugins.sound
                                            ,'keyEcho',false... % Echo key presses to the command line (listenChar(-1))
                                            ,'textEcho',false ... % ECho drawFormattedText to the command line.
                                        ); % Place to store hardware default settings that can then be specified in a script like myRig.
                                        
        flipCallbacks={}; %List of stimuli that have requested to be to called immediately after the flip, each as s.postFlip(flipTime).
        guiFlipEvery=[]; % if gui is on, and there are different framerates: set to 2+
        guiOn@logical=false; %flag. Is GUI on?
        mirror =[]; % The experimenters copy
        ticTime = -Inf;
        useFeedCache = false;  % When true, command line output is only generated in the ITI, not during a trial (theoretical optimization,in practice this does not do much)
        
        %% Keyboard interaction
        kbInfo@struct= struct('keys',{[]},... % PTB numbers for each key that is handled.
            'help',{{}},... % Help info for key
            'plugin',{{}},...  % Which plugin will handle the key (keyboard() will be called)
            'isSubject',{logical([])},... % Is this a key that is handled by subject keyboard ?
            'fun',{{}},... % Function handle that is used instead of the plugins keyboard function (usually empty)
            'default',{-1},... % default keyboard -1 means all keyboard
            'subject',{[]},... % The keyboard that will handle keys for which isSubect is true (=by default stimuli)
            'experimenter',{[]},...% The keyboard that will handle keys for which isSubject is false (plugins by default)
            'pressAnyKey',{-1},... % Keyboard for start experiment, block ,etc. -1 means any
            'activeKb',{[]});  % Indices of keyboard that have keys associated with them. Set and used internally)
        
    end
    
    %% Protected properties.
    % These are set internally
    properties (GetAccess=public, SetAccess =protected)
        %% Program Flow
        mainWindow = []; % The PTB window
        overlayWindow =[]; % The color overlay for special colormodes (VPIXX-M16)
        overlayRect = [];
        textWindow = []; % This is either the main or the overlay, depending on the mode.
        stage@double;
        flags = struct('trial',true,'experiment',true,'block',true); % Flow flags
        
        frame = 0;      % Current frame
        
        
        %% Internal lists to keep track of stimuli, , and blocks.
        stimuli;    % Vector of stimulus  handles.
        plugins;    % Vector of plugin handles.
        pluginOrder; % Vector of plugin handles, sorted by execution order
        
        
        flow@neurostim.flow= neurostim.flow;
        
        %% Logging and Saving
        startTime@double    = 0; % The time when the experiment started running
        stopTime = [];
        
        
        %% Profiling information.
        
        
        EscPressedTime;
        lastFrameDrop=1;
        propsToInform={'blockName','condition/nrConditions','trial/nrTrialsTotal'};
        
        profile=struct('cic',struct('FRAMELOOP',[],'FLIPTIME',[],'cntr',0));
        
        guiWindow;
        funPropsToMake=struct('plugin',{},'prop',{});
        % A struct to store writeToFeed information during the trial (and
        % write out after).
        feedCache =struct('style',cell(1000,1),'formatSpecs',cell(1000,1),'other',cell(1000,1),'trialTime',cell(1000,1),'trial',cell(1000,1));
        feedCacheCntr=0;
        feedCacheWriteNow = false;
        
      
    end
    properties (SetAccess= private)
        used =false; % Flag to make sure a user cannot reuse a cic object.
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
        subject@char;   % Subject
        startTimeStr@char;  % Start time as a HH:MM:SS string
        blockName;      % Name of the current block
        trialTime;      % Time elapsed (ms) since the start of the trial
        nrTrialsTotal;   % Number of trials total (all blocks)
        date;           % Date of the experiment.
        hasValidWindow; % Is the Main Window valid? 
    end
    
    %% Public methods
    % set and get methods for dependent properties
    methods
        function v = get.hasValidWindow(c)
            v = Screen(c.mainWindow,'WindowKind')>0;
        end
            
        
        function v=get.nrTrialsTotal(c)
            v= c.flow.nrTrials(true); 
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
            v = c.flow.nrBlocks(true);
        end
        
        function v= get.nrTrials(c)
            v= c.flow.nrTrials(false);            
        end
        
        function v= get.nrConditions(c)
            v = c.flow.nrConditions(true);
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
            v = c.flow.name;
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
                warning('Physical aspect ratio and Pixel aspect ration are  not the same...');
            end
        end
        
        
        function v= get.trialTime(c)
            v = (c.frame-1)*1000/c.screen.frameRate;
        end
        
    end
    
    methods (Access={?neurostim.flow})
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
        function c= cic
            
            %Check MATLAB version. Warn if using an older version.
            ver = version('-release');
            v=regexp(ver,'(?<year>\d+)(?<release>\w)','names');
            if ~((str2double(v.year) > 2015) || (str2double(v.year) == 2015 && v.release == 'b'))
                warning(['The installed version of MATLAB (' ver ') is relatively slow. Consider updating to 2015b or later for better performance (e.g. fewer frame-drops).']);
            end
            
            c = c@neurostim.plugin([],'cic');
            
            % Some very basic PTB settings that are enforced for all
            KbName('UnifyKeyNames'); % Same key names across OS.
            c.cursor = 'none';
            c.stage  = neurostim.cic.SETUP;
            % Initialize empty
            c.startTime     = now;
            c.stimuli       = [];
            c.plugins       = [];
            c.cic           = c; % Need a reference to self to match plugins. This makes the use of functions much easier (see plugin.m)
            
            % The root directory is the directory that contains the
            % +neurostim folder.
            c.dirs.root     = strrep(fileparts(mfilename('fullpath')),'+neurostim','');
            c.dirs.output   = getenv('TEMP');
            
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
            c.addProperty('block',0);
            c.addProperty('blockCntr',0);
            c.addProperty('blockTrial',0);
            c.addProperty('expScript',[]); % The contents of the experiment file
            c.addProperty('experiment',''); % The experiment file
            c.addProperty('iti',1000,'validate',@(x) isnumeric(x) & ~isnan(x)); %inter-trial interval (ms)
            c.addProperty('trialDuration',1000,'validate',@(x) isnumeric(x) & ~isnan(x)); % duration (ms)
            c.addProperty('matlabVersion', version); %Log MATLAB version used to run this experiment
            c.feedStyle = '*[0.9294    0.6941    0.1255]'; % CIC messages in bold orange
            
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
        
       
        function write(c,label,value)
            if ~isfield(c.prms,label)
                c.addProperty(label,value);
            else
                c.(label) = value;
            end
        end
        function versionTracker(c,silent,push) %#ok<INUSD>
            % Git Tracking Interface
            %
            % The idea:
            % A laboratory forks the GitHub repo to add their own experiments
            % in the experiments folder.  These additions are only tracked in the
            % forked repo, so the central code maintainer does not have to be bothered
            % by it. The new laboratory can still contribute to the core code, by
            % making changes and then sending pull requests.
            %
            % The goal of the gitTracker is to log the state of the entire repo
            % for a particular laboratory at the time an experiment is run. It checks
            % whether there are any uncommitted changes, and asks/forces them to be
            % committed before the experiment runs. The hash corresponding to the final
            % commit is stored in the data file such that the complete code state can
            % easily be reproduced later.
            %
            % BK  - Apr 2016
            if nargin<3
                push =false; %#ok<NASGU>
                if nargin <2
                    silent = false;
                end
            end
            
            if ~exist('git.m','file')
                error('The gitTracker class depends on a wrapper for git that you can get from github.com/manur/MATLAB-git');
            end
            
            [status] = system('git --version');
            if status~=0
                error('versionTracker requires git. Please install it first.');
            end
            
            [txt] = git('status --porcelain');
            changes = regexp([txt 10],'[ \t]*[\w!?]{1,2}[ \t]+(?<mods>[\w\d /\\\.\+]+)[ \t]*\n','names');
            nrMods= numel(changes);
            if nrMods>0
                disp([num2str(nrMods) ' files have changed (or need to be added). These have to be committed before running this experiment']);
                changes.mods;
                if silent
                    msg = ['Silent commit  (' getenv('USER') ' before experiment ' datestr(now,'yyyy/mm/dd HH:MM:SS')];
                else
                    msg = input('Code has changed. Please provide a commit message','s');
                end
                [txt,status]=  git(['commit -a -m ''' msg ' ('  getenv('USER') ' ) ''']);
                if status >0
                    disp(txt);
                    error('File commit failed.');
                end
            end
            
            %% now read the commit id
            txt = git('show -s');
            hash = regexp(txt,'commit (?<id>[\w]+)\n','names');
            c.addProperty('githash',hash.id);
            [~,ptb] =PsychtoolboxVersion;
            c.addProperty('PTBVersion',ptb);
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
                    if c.EscPressedTime+1>GetSecs
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
        
        
        
        
        
        function newOrder = order(c,varargin)
            % pluginOrder = c.order([plugin1] [,plugin2] [,...])
            % Returns pluginOrder when no input is given.
            % Inputs: lists name of plugins in the order they are requested
            % to be executed in.
            
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
            value = any(strcmpi(plgName,{c.plugins.name}));
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
            disp(char(['CIC. Started at ' datestr(c.startTime,'HH:MM:SS') ],...
                    ['Stimuli: ' num2str(c.nrStimuli) ],...
                    ['Blocks: ' num2str(c.flow.nrBlocks) ],...
                    ['Conditions: ' strtrim(sprintf('%d ',c.flow.nrConditions(true)))],...
                    ['Trials: ' strtrim(sprintf('%d ',c.flow.nrTrials(true))) ],...
                    ['File: ' c.fullFile '.mat']));
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
            assert(~c.used,'CIC objects are single-use only. Please create a new one to start this experiment!');
            
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
                    c.profile.(o.name)=struct('BEFOREEXPERIMENT',[],'AFTEREXPERIMENT',[],'BEFOREBLOCK',[],'AFTERBLOCK',[],'BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[],'cntr',0);
                end
            end
            
        end
        
          
             
        function error(c,command,msg)
            switch (command)
                case 'STOPEXPERIMENT'
                    neurostim.utils.cprintf('red','\n%s\n',msg);
                    c.flags.experiment = false;
                case 'CONTINUE'
                    neurostim.utils.cprintf('red','\n%s\n',msg);
                otherwise
                    error(['Rethrowing unhandled cic error: ' msg]);
            end
            
        end
        
        
        function run(c,varargin)
            % Run an experimental session (i.e. one or more blocks of trials);
            %
            % Inputs:
            % One or more neurostim.flow objects (blocks) or design objects
            % Design objects will be combined in a single block.
            %
            % varargin:  parm/value pairs that specify the experiment flow.
            %           These are the same parm/value pairs that can be
            %           specified in a flow. See neurostim.flow. 
            %           These properties will be applied to the root level
            %           flow (i.e. the single block when designs are
            %           specified, or the flow that contains the blocks 
            %           when blocks are specified (i.e. they specify how
            %           the blocks are randomized, repeated etc.)
            %
            % EXAMPLES:
            % The user prepares a flow object (with blocks and trials) and
            % then calls :
            % c.run(flow);            
            % The user only creates a design object (a factorial) and wants
            % to run all of those conditions in a single block:
            % c.run(design,'nrRepeats',4,'randomization','randomwithoutreplacement');
            % The user creates two blocks (flow objects) and wants to run
            % these blocks each 3 times , sequentiallly
            % c.run(flow1,flow2,'randomization','sequential','nrRepeats',3);
            
            assert(~c.used,'CIC objects are single-use only. Please create a new one to start this experiment!');
            c.used  = true;
             
            

            ixFlows = cellfun(@(x)(isa(x,'neurostim.flow')),varargin);
            ixDesigns = cellfun(@(x)(isa(x,'neurostim.design')),varargin);
            if ~xor(any(ixFlows),any(ixDesigns))
                error('To run an experiment, you must specify flows, or designs, not both or neither');
            end
            if any(ixFlows)
                % User specified flows
                flows = varargin(ixFlows);
                if numel(flows)==1
                    % Single flow, run as is
                    flw = flows{1};
                else
                    % Create a root flow to contain these blocks
                    flw= neurostim.flow(c);
                    for i=1:numel(flows)
                        flw.addBlock(flows{i});                        
                    end
                end
            elseif any(ixDesigns)
                % User specified designs, create a single block flow from
                % the designs
                flw = neurostim.flow(c);
                designs = varargin(ixDesigns);
                for i=1:numel(designs)
                     flw.addTrials(designs{i});                        
                end
            end
            c.flow= flw;
            % Apply the varargin to the top-level flow
            c.flow.setParms(false,varargin{~(ixFlows|ixDesigns)});% false means- do not set the defaults, but only what is specified here.
            
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
                    error(horzcat('Save folder ', c.fullPath, ' does not exist and could not be created. Check drive/write access.'));
                end
            end
            
            
            c.flags.experiment = true;  % Start with true, but any plugin code can set this to false by calling cic.error.            
            c.stage = neurostim.cic.RUNNING; % Enter RUNNING stage; property functions, validation  will now be active
            
            %Construct any function properties by setting them again (this time the actual anonymous functions will be constructed)
            for i=1:numel(c.funPropsToMake)
                c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop) = c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop);
            end
            
            %% Set up order and blocks
            order(c,c.pluginOrder);
            beforeExperiment(c.flow);% initialization of blocks and trials
            %%Setup PTB imaging pipeline and keyboard handling
            PsychImaging(c);
            checkFrameRate(c);
            
            %% Start preparation in all plugins.
            c.window = c.mainWindow; % Allows plugins to use .window
            locHAVEOVERLAY = ~isempty(c.overlayWindow);
            showCursor(c);
            base(c.pluginOrder,neurostim.stages.BEFOREEXPERIMENT,c);
            KbQueueCreate(c); % After plugins have completed their beforeExperiment (to addKeys)
            c.drawFormattedText(c.beforeExperimentText);            
            Screen('Flip', c.mainWindow);            
            
            sanityChecks(c);
            
            if c.keyBeforeExperiment; KbWait(c.kbInfo.pressAnyKey);end
            clearOverlay(c,true);
         
            FRAMEDURATION   = 1/c.screen.frameRate; % In seconds to match PTB convention
            if c.timing.vsyncMode==0
                % If beamposition queries are working, then the time
                % between flips will be an exact multiple of the frame
                % duration. In that case testing whether a frame is late by
                % 0.1, 0.5 or 0.9 of a frame is all the same. But if
                % beamposition queries are not working (many windows
                % systems), then there is slack in the time between vbl
                % times as returned by Flip; a vlbTime that is 0.5 of a
                % frame too late, could still have flipped at the right
                % time... (and then windows went shopping for a bit).
                % We allow 50% of slack to account for noisy timing.
                % If beamposition queries are correct (the startup routine of PTB runs the tests but defaults to not using
                % them even if they are ok), then use Screen('Preference', 'VBLTimestampingMode',3)
                % to force their use on windows.
                ITSAMISS =  0.5*FRAMEDURATION; %
            else
                ITSAMISS = c.timing.frameSlack*FRAMEDURATION;
            end
            locPROFILE      = c.PROFILE;
            frameDeadline   = NaN;
           
            if ~c.hardware.keyEcho
                ListenChar(-1);
            end
            
            while c.flags.experiment 
                  c.trial = c.trial+1;
                  c.condition = c.flow.conditionNr; % Tree-unique condition nr
                  beforeTrial(c.flow)                  
                  
                   %ITI - wait
                    if c.trial>1
                        nFramesToWait = c.ms2frames(c.iti - (c.clockTime-c.trialStopTime));
                        for i=1:nFramesToWait
                            Screen('Flip',c.mainWindow,0,1-c.itiClear);     % WaitSecs seems to desync flip intervals; Screen('Flip') keeps frame drawing loop on target.
                            if locHAVEOVERLAY
                                clearOverlay(c,c.itiClear);
                            end
                        end
                    end                    
                    c.frame=0;
                    c.flags.trial = true;
                    PsychHID('KbQueueFlush');                    
                    Priority(MaxPriority(c.mainWindow));
                    %draw = nan(1,1000); % Commented out. See drawingFinished code below
                    while (c.flags.trial && c.flags.experiment)
                        %%  Trial runnning -
                        c.frame = c.frame+1;
                        
                        %% Check for end of trial
                        if ~c.flags.trial || c.frame-1 >= ms2frames(c,c.trialDuration)  
                            % if trial has ended (based on behaviors for
                            % instance)
                            % or if trialDuration has been reached, minus one frame for clearing screen
                            % We are going to the ITI.
                            c.flags.trial=false; % This will be the last frame.
                            clr = c.itiClear; % Do not clear this last frame if the ITI should not be cleared
                        else
                            clr = c.clear;
                        end
                        
                        %% Call the drawing code in the plugins
                        base(c.pluginOrder,neurostim.stages.BEFOREFRAME,c);
                        % This commented out code allows measuring the draw
                        % times.
                        %draw(c.frame) = Screen('DrawingFinished',c.mainWindow,1-clr,true);
                        Screen('DrawingFinished',c.mainWindow,1-clr);
                        
                        
                        KbQueueCheck(c);
                        % After the KB check, a behavioral requirement
                        % can have terminated the trial. 
                        if ~c.flags.trial ;  clr = c.itiClear; end % Do not clear this last frame if the ITI should not be cleared
                        
                        startFlipTime = GetSecs; % Avoid function call to clocktime
                        
                        % vbl: high-precision estimate of the system time (in seconds) when the actual flip has happened
                        % stimOn: An estimate of Stimulus-onset time
                        % flip: timestamp taken at the end of Flip's execution
                        % missed: indicates if the requested presentation deadline for your stimulus has
                        %           been missed. A negative value means that dead- lines have been satisfied.
                        %            Positive values indicate a
                        %            deadline-miss.
                        % beampos: position of the monitor scanning beam when the time measurement was taken
                        
                        % Start (or schedule) the flip
                        if c.timing.useWhen
                            % Use the when argument - better(fewer drops)
                            % on at least one Windows system (win7/Quadro
                            % Pro/ViewPixx)
                            [ptbVbl,ptbStimOn,~,missed] = Screen('Flip', c.mainWindow,frameDeadline,1-clr,c.timing.vsyncMode);
                        else
                            % Don't use the when (better on some linux
                            % systems)
                            [ptbVbl,ptbStimOn] = Screen('Flip', c.mainWindow,[],1-clr,c.timing.vsyncMode);
                        end
                        if clr && locHAVEOVERLAY
                            Screen('FillRect', c.overlayWindow,0,c.overlayRect); % Fill with zeros;%clearOverlay(c,true);
                        end
                        
                        if c.timing.vsyncMode==0
                            % Flip returns correct values
                        else
                            % Flip's return arguments are not meaningful.
                            % It is now difficult to estimate when exactly
                            % the flip occurred.
                            ptbVbl = GetSecs;
                            ptbStimOn = ptbVbl;
                        end
                        if c.timing.useWhen
                           % missed is calculated by Screen('FLIP') 
                        else
                            missed  = (ptbVbl-frameDeadline); % Positive is too late (i.e. a drop)
                        end
                        
                        if locPROFILE && c.frame > 1
                            addProfile(c,'FRAMELOOP','cic',c.toc);
                            tic(c)
                            addProfile(c,'FLIPTIME','cic',1000*(GetSecs-startFlipTime));
                        end
                        
                        
                        % Predict next frame and check frame drops
                        frameDeadline = ptbVbl+ FRAMEDURATION;
                        if c.frame == 1
                            locFIRSTFRAMETIME = ptbStimOn*1000; % Faster local access for trialDuration check
                            c.firstFrame = locFIRSTFRAMETIME;% log it
                        else
                            if missed>ITSAMISS
                                c.frameDrop = [c.frame-1 missed]; % Log frame and delta
                            end
                        end
                        
                        
                        %Stimuli should set and log their onsets/offsets as soon as they happen, in case other
                        %properties in any afterFrame() depend on them. So, send the flip time those who requested it
                        if ~isempty(c.flipCallbacks)
                            flipTime = ptbStimOn*1000-locFIRSTFRAMETIME;
                            cellfun(@(s) s.afterFlip(flipTime,ptbStimOn*1000),c.flipCallbacks);
                            c.flipCallbacks = {};
                        end
                        
                        % The current frame has been flipped. Process
                        % afterFrame functions in all plugins
                        base(c.pluginOrder,neurostim.stages.AFTERFRAME,c);
                        
                    end % Trial running
                    
                    %Perform one last flip and clear the screen (if requested)
                    [~,ptbStimOn]=Screen('Flip', c.mainWindow,0,1-c.itiClear);                    
                    c.frame = c.frame+1;
                    clearOverlay(c,c.itiClear);                    
                    c.trialStopTime = ptbStimOn*1000;                    
                    Priority(0);
                    if ~c.flags.experiment ;break;end
                    
                    
                      % Calls afterTrial on the current block/design.
                    % This assesses 'success' of the behavior and updates the design
                    % if needed (i.e. retrying failed trials)
                    afterTrial(c.flow);
                    
                
                Screen('glLoadIdentity', c.mainWindow);
              
            end %flow

            c.stopTime = now;
            Screen('Flip', c.mainWindow,0,0);% Always clear, even if clear & itiClear are false
            clearOverlay(c,true);               
            c.drawFormattedText(c.afterExperimentText);
            Screen('Flip', c.mainWindow);
            
            base(c.pluginOrder,neurostim.stages.AFTEREXPERIMENT,c);
            c.KbQueueStop;
            %Prune the log of all plugins/stimuli and cic itself
            pruneLog([c.pluginOrder c]);

            % clean up CLUT textures used by SOFTWARE-OVERLAY
            if isfield(c.screen,'overlayClutTex') && ~isempty(c.screen.overlayClutTex)
                glDeleteTextures(numel(c.screen.overlayClutTex),c.screen.overlayClutTex(1));
                c.screen.overlayClutTex = [];
            end
            
            c.saveData;
            
            ListenChar(0);
            Priority(0);
            if c.keyAfterExperiment; c.writeToFeed({'','Press any key to close the screen',''}); KbWait(c.kbInfo.pressAnyKey);end
            
            Screen('CloseAll');
            if c.PROFILE; report(c);end
        end
        
        function clearOverlay(c,clear)
            if clear && ~isempty(c.overlayWindow)
                Screen('FillRect', c.overlayWindow,0,c.overlayRect); % Fill with zeros
            end
        end
        function saveData(c)
            filePath = horzcat(c.fullFile,'.mat');
            save(filePath,'c');
            c.writeToFeed('Data for trials 1:%d saved to %s',c.trial,filePath);
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
        function addKeyStroke(c,key,keyHelp,plg,isSubject,fun)
            if ischar(key)
                key = KbName(key);
            end
            if ~isnumeric(key) || key <1 || key>256
                error('Please use KbName to add keys')
            end
            if  ismember(key,c.kbInfo.keys)
                error(['The ' key ' key is in use. You cannot add it again...']);
            else
                c.kbInfo.keys(end+1)  = key;
                c.kbInfo.help{end+1} = keyHelp;
                c.kbInfo.plugin{end+1} = plg; % Handle to plugin to call keyboard()
                c.kbInfo.isSubject(end+1) = isSubject;
                c.kbInfo.fun{end+1} = fun;
            end
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
        function feed(c,style,formatSpecs,thisTrial,thisTrialTime,varargin)
            if c.flags.trial && c.useFeedCache
                c.feedCacheCntr= c.feedCacheCntr+1;
                c.feedCache(c.feedCacheCntr).style = style;
                c.feedCache(c.feedCacheCntr).formatSpecs = formatSpecs;
                c.feedCache(c.feedCacheCntr).other = varargin;   
                c.feedCache(c.feedCacheCntr).trialTime = thisTrialTime;   
                c.feedCache(c.feedCacheCntr).trial = thisTrial;   
            elseif ~c.feedCacheWriteNow
                c.feedCacheWriteNow =true;
                for i=1:c.feedCacheCntr
                    feed(c,c.feedCache(i).style,c.feedCache(i).formatSpecs,c.feedCache(i).trial,c.feedCache(i).trialTime,c.feedCache(i).other{:});                    
                end
                c.feedCache =struct('style',cell(1000,1),'formatSpecs',cell(1000,1),'other',cell(1000,1),'trialTime',cell(1000,1),'trial',cell(1000,1));
                c.feedCacheWriteNow =false;
                c.feedCacheCntr =0;
            end
                
                
            if ~c.useConsoleColor
                style = 'NOSTYLE';                
            end
               
            if numel(varargin)==2 && iscell(varargin{2})
                % multi line message
                maxChars = max(cellfun(@numel,varargin{2}));
                if c.flags.trial
                    % in trial ..
                    phaseStr = '';
                else
                    phaseStr = '(ITI)';
                end
                neurostim.utils.cprintf(style,'TR: %d: (T: %.0f %s) %s \n',thisTrial,thisTrialTime,phaseStr,varargin{1}); % First one is the plugin name
                neurostim.utils.cprintf(style,'\t%s\n',repmat('-',[1 maxChars]));
                for i=1:numel(varargin{2})
                    neurostim.utils.cprintf(style,'\t %s\n',varargin{end}{i}); % These are the message lines
                end
                neurostim.utils.cprintf(style,'\t%s\n',repmat('-',[1 maxChars]));
            else
                % single line
                neurostim.utils.cprintf(style,['TR: %d (T: %.0f): ' formatSpecs '\n'],thisTrial,thisTrialTime,varargin{:});
            end
        end
        
        function collectFrameDrops(c)
            nrFramedrops= c.prms.frameDrop.cntr-1-c.lastFrameDrop;
            if nrFramedrops>=1
                percent=round(nrFramedrops/c.frame*100);
                c.writeToFeed(['Missed Frames: ' num2str(nrFramedrops) ', ' num2str(percent) '%%'])
                c.lastFrameDrop=c.lastFrameDrop+nrFramedrops;
            end
        end
        
        
        function c = rig(c,varargin)
            % Basic screen etc. setup function, called from myRig for
            % instnace.
            pin = inputParser;
            pin.addParameter('xpixels',[]);
            pin.addParameter('ypixels',[]);
            pin.addParameter('xorigin',[]);
            pin.addParameter('yorigin',[]);
            pin.addParameter('screenWidth',[]);
            pin.addParameter('screenHeight',[]);
            pin.addParameter('screenDist',[]);
            pin.addParameter('frameRate',[]);
            pin.addParameter('screenNumber',[]);
            pin.addParameter('keyboardNumber',[]);
            pin.addParameter('subjectKeyboard',[]);
            pin.addParameter('experimenterKeyboard',[]);
            pin.addParameter('eyelink',false);
            pin.addParameter('eyelinkCommands',[]);
            pin.addParameter('outputDir',[]);
            pin.addParameter('mcc',false);
            pin.addParameter('colorMode','RGB');
            pin.parse(varargin{:});
            
            if ~isempty(pin.Results.xpixels)
                c.screen.xpixels  = pin.Results.xpixels;
            end
            if ~isempty(pin.Results.ypixels)
                c.screen.ypixels  = pin.Results.ypixels;
            end
            if ~isempty(pin.Results.frameRate)
                c.screen.frameRate  = pin.Results.frameRate;
            end
            if ~isempty(pin.Results.screenWidth)
                c.screen.width  = pin.Results.screenWidth;
            end
            if ~isempty(pin.Results.screenHeight)
                c.screen.height = pin.Results.screenHeight;
            else
                c.screen.height = c.screen.width*c.screen.ypixels/c.screen.xpixels;
            end
            if ~isempty(pin.Results.screenDist)
                c.screen.viewDist  = pin.Results.screenDist;
            end
            if ~isempty(pin.Results.screenNumber)
                c.screen.number  = pin.Results.screenNumber;
            end
            if ~isempty(pin.Results.keyboardNumber)
                c.kbInfo.default = pin.Results.keyboardNumber;
            end
            if ~isempty(pin.Results.subjectKeyboard)
                c.kbInfo.subject= pin.Results.subjectKeyboard;
            end
            if ~isempty(pin.Results.experimenterKeyboard)
                c.kbInfo.experimenter = pin.Results.experimenterKeyboard;
            end
            
            if ~isempty(pin.Results.outputDir)
                c.dirs.output  = pin.Results.outputDir;
            end
            if pin.Results.eyelink
                neurostim.plugins.eyelink(c);
                if ~isempty(pin.Results.eyelinkCommands)
                    for i=1:numel(pin.Results.eyelinkCommands)
                        c.eye.command(pin.Results.eyelinkCommands{i});
                    end
                end
            else
                e = neurostim.plugins.eyetracker(c);      %If no eye tracker, use a virtual one. Mouse is used to control gaze position (click)
                e.useMouse = true;
            end
            if pin.Results.mcc
                neurostim.plugins.mcc(c);
            end
            
            c.screen.xorigin = pin.Results.xorigin;
            c.screen.yorigin = pin.Results.yorigin;
            c.screen.colorMode = pin.Results.colorMode;
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
            if nargin < 2
                clut = [];
            end
            [nrRows,nrCols] = size(c.screen.overlayClut);
            if ~ismember(nrCols,[0 3])
                error('The overlay CLUT should have 3 columns (RGB)');
            end
          
            switch upper(c.screen.type)
                case 'VPIXX-M16'
                    if nargin < 3
                      index = 1:size(clut,1);
                    end
              
                    if nrRows ~=256
                      % Add white for missing clut entries to show error
                      % indices (assuming the bg is not max white)
                      % 0 = transparent.
                      c.screen.overlayClut = cat(1,zeros(1,3),c.screen.overlayClut,ones(256-nrRows-1,3));
                    end
                    
                    if any(index<1 | index >255)
                        error('CLUT entries can only be defined for index =1:255');
                    end
              
                    if ~isempty(clut)  && (numel(index) ~=size(clut,1) || size(clut,2) ~=3)
                        error('The CLUT update must by [N 3] and with N index values');
                    end
                    % Update with the new values in the appropriate location
                    % (index)
                    if ~isempty(index)
                        c.screen.overlayClut(index+1,:) = clut; % index +1 becuase the first entry (index =0) is always transparent
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
                        error('The CLUT update contains invalid indicies.');
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
            p.addParameter('flip',false);  % Screen(flip)?
            p.addParameter('waitForKey',false);
            p.addParameter('left','center') % The sx parameter in PTB
            p.addParameter('top','center') % The sy parameter in PTB
            p.addParameter('wrapAt',[]) % The wrapAt parameter in PTB            
            p.addParameter('flipHorizontal',0) % The flipHorizontal parameter in PTB
            p.addParameter('flipVertical',0) % The flipVertical parameter in PTB
            p.addParameter('vSpacing',1) % The vSpacing parameter in PTB
            p.addParameter('rightToLeft',0) % The righttoleft parameter in PTB
            p.addParameter('winRect',[0 0 c.screen.xpixels c.screen.ypixels]) % The winRect parameter in PTB
            
            p.parse(varargin{:});
            
            DrawFormattedText(c.textWindow,text, p.Results.left, p.Results.top, c.screen.color.text, p.Results.wrapAt, p.Results.flipHorizontal, p.Results.flipVertical, p.Results.vSpacing, p.Results.rightToLeft, p.Results.winRect);                          
            if c.hardware.textEcho
                  if ~c.useConsoleColor
                      style = 'NOSTYLE';                
                  else
                      style = 'MAGENTA';
                 end
                neurostim.utils.cprintf(style,'Screen Message: %s\n',text);
            end
            
            if p.Results.flip
                   Screen('Flip',c.mainWindow);
                   if p.Results.waitForKey
                       KbWait(c.kbInfo.pressAnyKey,2);
                   end
            end
                
         end
    end
    
    methods (Access=private)
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
        function KbQueueStop(c)
            for kb=1:numel(c.kbInfo.activeKb)
                KbQueueStop(c.kbInfo.activeKb{kb});
                KbQueueRelease(c.kbInfo.activeKb{kb});
            end
            
        end
        
        function colorOk = loadCalibration(c)
            colorOk = false;
            if ~isempty(c.screen.calFile)
                % Load a calibration from file. The cal struct has been
                % generated by utils.ptbcal
                
                c.screen.calibration = LoadCalFile(c.screen.calFile,Inf,c.dirs.calibration); % Retrieve the latest calibration
                if isempty(c.screen.calibration)
                    error(['Could not load a PTB calibration file from: ' fullfile(c.dirs.calibration,c.screen.calibration.file)]);
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
        
        %% PTB Imaging Pipeline Setup
        function PsychImaging(c)
            InitializeMatlabOpenGL;
            AssertOpenGL;
            sca;
            
            c.setupScreen;
            colorOk = loadCalibration(c);
            PsychImaging('PrepareConfiguration');
            PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');% 32 bit frame buffer values
            PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');% Unrestricted color range
            %PsychImaging('AddTask', 'General', 'UseGPGPUCompute');
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
                    dac = ScreenDacBits(c.screen.number);
                    iGamma = InvertGammaTable(c.screen.calibration.gammaInput,c.screen.calibration.gammaTable,2.^dac);
                    Screen('LoadNormalizedGammaTable',c.screen.number,iGamma);
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
                    % The user specifies "raw" RGB values as color
                    dac = 8;
                    Screen('LoadNormalizedGammaTable',c.screen.number,repmat(linspace(0,1,2^dac)',[1 3])); % Reset gamma
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
                    updateOverlay(c,c.screen.overlayClut);
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
                    updateOverlay(c,c.screen.overlayClut);
                otherwise
                    error(['Unknown screen type : ' c.screen.type]);
            end
            
            %% Add calibration to the window
            switch upper(c.screen.colorMode)
                case 'LINLUT'
                    % Nothing to do.
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
                case 'RGB'
                    % Nothing to do
                otherwise
                    error(['Unknown color mode: ' c.screen.colorMode]);
            end
            PsychColorCorrection('SetColorClampingRange',c.mainWindow,0,1); % Final pixel value is between [0 1]
            
            %% Perform additional setup routines
            Screen(c.mainWindow,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);                        
            
        end
        
    end
    
    
    
    methods (Static)
        function v = clockTime
            v = GetSecs*1000;
        end
                                
        function o = loadobj(o)
           % If the last trial does not reach firstFrame, then
           % the trialTime (which is relative to firstFrame) cannot be calculated 
           % This happens, for instance, when endExperiment is called by a plugin 
           % during an ITI.
           
           % Add a fake firstFrame to fix this.
           lastTrial = o.prms.trial.cntr-1; % trial 0 is logged as well, so -1
           nrFF = o.prms.firstFrame.cntr-1;
           if nrFF > 0 && lastTrial == nrFF +1 
                    % The last trial did not make it to the firstFrame event. 
                    % generate a fake firstFrame.
                    t = [o.prms.firstFrame.log{:}];
                    mTimeBetweenFF = median(diff(t));
                    fakeFF = t(end) + mTimeBetweenFF;
                    storeInLog(o.prms.firstFrame,fakeFF,NaN)
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
                nPerCol = floor(sqrt(nPlots));
                nPerRow = ceil(nPlots/nPerCol);
                
                for j=1:nPlots
                    subplot(nPerRow,nPerCol,j);
                    vals{i,j} = c.profile.(plgns{i}).(items{j}); %#ok<AGROW>
                    out =isinf(vals{i,j}) | isnan(vals{i,j});
                    thisVals= min(vals{i,j}(~out),MAXDURATION);
                    hist(thisVals,100);
                    xlabel 'Time (ms)'; ylabel '#'
                    title(horzcat(items{j},'; Median = ', num2str(round(nanmedian(vals{i,j}),2))));
                end
            end
            if numel(plgns)>1
                figure('Name','Total','position',[680   530   818   420]);
                clf
                frameItems = find(~cellfun(@isempty,strfind(items,'FRAME')));
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
            
            figure('Name',[c.file ' - framedrop report for behavior state changes'])
            B = c.behaviors;
            nrB = numel(B);
            colors = 'rgbcmyk';
            for i=1:nrB
                subplot(nrB,1,i)
                [state,stateTrial,stateStartT] = get(B(i).prms.state,'atTrialTime',[],'withDataOnly',true);
                uStates = unique(state);
                relativeTime  = ti(stateTrial)-stateStartT; 
                for s=1:numel(uStates)
                    thisState = ismember(state,uStates{s});
                    plot(relativeTime(thisState),stateTrial(thisState),['.' colors(s)]);
                    hold on
                end
                xlabel('Time from State start (ms)')
                ylabel 'Trial'
                title ([B(i).name '- State Transitions INTO'])
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
