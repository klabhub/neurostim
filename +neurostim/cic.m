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
        
        dirs                    = struct('root','','output','','calibration','')  % Output is the directory where files will be written, root is where neurostim lives, calibration stores calibration files
        subjectNr@double        = [];
        paradigm@char           = 'test';
        clear@double            = 1;   % Clear backbuffer after each swap. double not logical
        itiClear@double         = 1;    % Clear backbuffer during the iti. double. Set to 0 to keep the last display visible during the ITI (e.g. a fixation point)
        fileOverwrite           = false; % Allow output file overwrite.
        keyBeforeExperiment     = true;
        keyAfterExperiment      =true;
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
            'overlayClut',[]);    %screen-related parameters.
        
        timing = struct('vsyncMode',0,... % 0 = busy wait until vbl, 1 = schedule flip then return, 2 = free run 
                                'frameSlack',0.1,... % Allow x% slack of the frame in screen flip time.
                                'pluginSlack',0); % see plugin.m 
                
        flipTime;   % storing the frame flip time.
        getFlipTime@logical = false; %flag to notify whether to get the frame flip time.        
        guiFlipEvery=[]; % if gui is on, and there are different framerates: set to 2+
        guiOn@logical=false; %flag. Is GUI on?
        mirror =[]; % The experimenters copy
        ticTime = -Inf;
        
        %% Keyboard interaction
         kbInfo@struct= struct('keys',{[]},...% PTB numbers for each key that is handled.
            'help',{{}},... % Help info for key            
            'plugin',{{}},...  % Which plugin will handle the key (keyboard() will be called)
            'isSubject',{logical([])},... % Is this a key that is handled by subject keyboard ?
            'fun',{{}},... % Function handle that is used instead of the plugins keyboard function (usually empty)
            'default',{-1},... default keyboard -1 means all keyboard
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
        stage@double;
        flags = struct('trial',true,'experiment',true,'block',true); % Flow flags
        
        frame = 0;      % Current frame
        cursorVisible = false; % Set it through c.cursor =
        
        %% Internal lists to keep track of stimuli, , and blocks.
        stimuli;    % Vector of stimulus  handles.
        plugins;    % Vector of plugin handles.
        pluginOrder; % Vector of plugin handles, sorted by execution order
        
        blocks@neurostim.block;     % Struct array with .nrRepeats .randomization .conditions
        blockFlow;
        
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
    end
    
    %% Dependent Properties
    % Calculated on the fly
    properties (Dependent)
        nrStimuli;      % The number of stimuli currently in CIC
        nrPlugins;      % The number of plugins (Excluding stimuli) currently inCIC
        nrConditions;   % The number of conditions in this experiment
        nrTrials;       % The number of trials in the current block
        center;         % Where is the center of the display window.
        file;           % Target file name
        fullFile;       % Target file name including path
        fullPath;       % Target path name
        subject@char;   % Subject
        startTimeStr@char;  % Start time as a HH:MM:SS string
        cursor;         % Cursor 'none','arrow'; see ShowCursor
        blockName;      % Name of the current block
        trialTime;      % Time elapsed (ms) since the start of the trial
        nrTrialsTotal;   % Number of trials total (all blocks)        
        date;           % Date of the experiment.
    end
    
    %% Public methods
    % set and get methods for dependent properties
    methods
        function v=get.nrTrialsTotal(c)
            v= sum([c.blocks(c.blockFlow.list).nrTrials]);
        end
        
        function v= get.nrStimuli(c)
            v= length(c.stimuli);
        end
        
        function v= get.nrPlugins(c)
            v= length(c.plugins);
        end
        
        function v= get.nrTrials(c)
            if c.block
                v= c.blocks(c.block).nrTrials;
            else
                v=0;
            end
        end
        function v= get.nrConditions(c)
            v = sum([c.blocks.nrConditions]);
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
        
        
        function set.cursor(c,value)
            if ischar(value) && strcmpi(value,'none')
                value = -1;
            end
            if value==-1  % neurostim convention -1 or 'none'
                HideCursor(c.mainWindow);
                c.cursorVisible = false;
            else
                ShowCursor(value,c.mainWindow);
                c.cursorVisible = true;
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
                elseif c.guiFlipEvery<ceil(frInterval*0.95/(1000/c.screen.frameRate));
                    error('GUI flip interval is too small; this will cause frame drops in experimental window.')
                end
            end
        end
        
        
        
        function out=collectPropMessage(c)
            out='\n======================\n';
            for i=1:numel(c.propsToInform)
                str=strsplit(c.propsToInform{i},'/');
                for j=1:numel(str)
                    tmp = getProp(c,str{j}); % getProp allows calls like c.(stim.value)
                    if isnumeric(tmp)
                        tmp = num2str(tmp);
                    elseif islogical(tmp)
                        if (tmp);tmp = 'true';else tmp='false';end
                    end
                    if isa(tmp,'function_handle')
                        tmp = func2str(tmp);
                    end
                    tmp = tmp(:)';
                    if numel(str)>1
                        if j==1
                            out=[out c.propsToInform{i} ': ' tmp]; %#ok<AGROW>
                        else
                            out=[out '/' tmp];%#ok<AGROW>
                        end
                    else
                        out = [out c.propsToInform{i} ': ' tmp]; %#ok<AGROW>
                    end
                end
                out=[out '\n']; %#ok<AGROW>
            end
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
            c.addProperty('iti',1000,'validate',@(x) isnumeric(x) & ~isnan(x)); %inter-trial interval (ms)
            c.addProperty('trialDuration',1000,'validate',@(x) isnumeric(x) & ~isnan(x)); % duration (ms)
            
            
            
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
            for b=1:numel(c.blocks)
                blockStr = ['Block: ' num2str(b) '(' c.blocks(b).name ')'];
                for d=1:numel(c.blocks(b).designs)
                    show(c.blocks(b).designs(d),factors,blockStr);
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
                push =false;
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
                otherwise
                    error(c,'STOPEXPERIMENT',['Unknown key ' key '. Did you forget to specify a callback function (check addKey)?']);
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
            
            
            defaultOrder = cat(2,{c.stimuli.name},{c.plugins.name});
            if nargin==1
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
                ['Stimuli:' num2str(c.nrStimuli) ' Conditions:' num2str(c.nrConditions) ' Trials:' num2str(c.nrTrials) ]));
        end
        
        function endTrial(c)
            % Move to the next trial asap.
            c.flags.trial =false;
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
                    c.profile.(o.name)=struct('BEFOREEXPERIMENT',[],'BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[],'AFTEREXPERIMENT',[],'cntr',0);
                end
            end
                       
        end
        
        %% -- Specify conditions -- %%
        function setupExperiment(c,varargin)
            % setupExperiment(c,block1,...blockEnd,'input',...)
            % Creates an experimental session
            % Inputs:
            % blocks - input blocks directly created from block('name')
            % 'randomization' - 'SEQUENTIAL' or 'RANDOMWITHOUTREPLACEMENT'
            % 'nrRepeats' - number of repeats total
            % 'weights' - weighting of blocks
            % 'blockOrder' - the ordering of blocks
            p=inputParser;
            p.addParameter('randomization','SEQUENTIAL',@(x)any(strcmpi(x,{'SEQUENTIAL','RANDOMWITHOUTREPLACEMENT','ORDERED'})));
            p.addParameter('blockOrder',[],@isnumeric); %  A specific order of blocks
            p.addParameter('nrRepeats',1,@isnumeric);
            p.addParameter('weights',[],@isnumeric);
            
            %% First create the blocks and blockFlow
            isblock = cellfun(@(x) isa(x,'neurostim.block'),varargin);
            % Store the blocks
            c.blocks = [varargin{isblock}];
            
            args = varargin(~isblock);
            parse(p,args{:});
            if isempty(p.Results.weights)
                c.blockFlow.weights = ones(size(c.blocks));
            else
                c.blockFlow.weights = p.Results.weights;
            end
            c.blockFlow.randomization = p.Results.randomization;
            singleRepeatList = repelem((1:numel(c.blocks)),c.blockFlow.weights);
            c.blockFlow.list =[];
            for i=1:p.Results.nrRepeats
                switch upper(c.blockFlow.randomization)
                    case 'ORDERED'
                        c.blockFlow.list = cat(2,c.blockFlow.list,p.Results.blockOrder);
                        c.blockFlow.randomization = 'SEQUENTIAL';
                    case 'SEQUENTIAL'
                        c.blockFlow.list = cat(2,c.blockFlow.list,singleRepeatList);
                    case 'RANDOMWITHREPLACEMENT'
                        c.blockFlow.list =cat(2,c.blockFlow.list,datasample(singleRepeatList,numel(singleRepeatList)));
                    case 'RANDOMWITHOUTREPLACEMENT'
                        c.blockFlow.list= cat(2,c.blockFlow.list,Shuffle(singleRepeatList));
                end
            end
        end
        
        function beforeTrial(c)
           % Restore default values
           setDefaultParmsToCurrent(c.pluginOrder);
           
           % Call before trial on the current block.
           % This sets up all condition dependent stimulus properties (i.e. those in the design object that is currently active in the block)  
           beforeTrial(c.blocks(c.block),c);                  
           c.blockTrial = c.blockTrial+1;  % For logging and gui only
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
           
           
           if ~c.guiOn
                message=collectPropMessage(c);
                c.writeToFeed(message);
           end            
           c.collectFrameDrops;             
        end
        
        
        
        function error(c,command,msg)
            switch (command)
                case 'STOPEXPERIMENT'
                    fprintf(2,msg);
                    fprintf(2,'\n');
                    c.flags.experiment = false;
                case 'CONTINUE'
                    fprintf(2,msg);
                    fprintf(2,'\n');
                otherwise
                    error('?');
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
            
            %Check input
            if ~(exist('block1','var') && isa(block1,'neurostim.block'))
                help('neurostim/cic/run');
                error('You must supply at least one block of trials.');
            end
            
            %Log the experimental script as a string
            try
                stack = dbstack('-completenames',1);
                if ~isempty(stack) % Can happen with ctrl-retun execution of code
                    c.expScript = fileread(stack(1).file);
                    c.experiment = stack(1).file;
                end
            catch
                warning(['Tried to read experimental script  (', stack(runCaller).file ' for logging, but failed']);
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
            
            c.stage = neurostim.cic.RUNNING; % Enter RUNNING stage; property functions, validation  will now be active
            
            %Construct any function properties by setting them again (this time the actual anonymous functions will be constructed)
            for i=1:numel(c.funPropsToMake)
                c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop) = c.(c.funPropsToMake(i).plugin).(c.funPropsToMake(i).prop);
            end

            %% Set up order and blocks
            order(c);
            setupExperiment(c,block1,varargin{:});
            %%Setup PTB imaging pipeline and keyboard handling
            PsychImaging(c);
            checkFrameRate(c);
            
            %% Start preparation in all plugins.
            c.window = c.mainWindow; % Allows plugins to use .window 
            base(c.pluginOrder,neurostim.stages.BEFOREEXPERIMENT,c);
            KbQueueCreate(c); % After plugins have completed their beforeExperiment (to addKeys)
            DrawFormattedText(c.mainWindow, 'Press any key to start...', c.center(1), 'center', c.screen.color.text);
            Screen('Flip', c.mainWindow);
            if c.keyBeforeExperiment; KbWait(c.kbInfo.pressAnyKey);end
            c.flags.experiment = true;
                        
            FRAMEDURATION   = 1/c.screen.frameRate; % In seconds to match PTB convention
            if c.timing.vsyncMode==0
                ITSAMISS =  0.15*FRAMEDURATION; %Allow up to 15% overshoot in frame flip time.
            else
                ITSAMISS = c.timing.frameSlack*FRAMEDURATION;
            end
            locPROFILE      = c.PROFILE;
            frameDeadline   = NaN;
            %ListenChar(-1);
            nrBlocks = numel(c.blockFlow.list);
            for blockCntr=1:nrBlocks
                c.flags.block = true;
                c.block = c.blockFlow.list(blockCntr); % Logged.
                c.blockCntr= blockCntr;
                %% Then let each block set itself up
                beforeBlock(c.blocks(c.block));
                
                % Show a beforeBlock message, and execute a beforeBlock
                % function (if requested).
                waitforkey = false; % Only if a message/fun and requested.
                if isa(c.blocks(c.block).beforeMessage,'function_handle')
                    msg = c.blocks(c.block).beforeMessage(c);
                else
                    msg = c.blocks(c.block).beforeMessage;
                end                
                if ~isempty(msg)                                        
                    DrawFormattedText(c.mainWindow,msg,'center','center',c.screen.color.text);
                    waitforkey=c.blocks(c.block).beforeKeyPress;
                end                
                if ~isempty(c.blocks(c.block).beforeFunction)
                    c.blocks(c.block).beforeFunction(c);
                    waitforkey=c.blocks(c.block).beforeKeyPress;
                end
                Screen('Flip',c.mainWindow);
                if waitforkey
                    KbWait(c.kbInfo.pressAnyKey,2);
                end
                %% Start the trials in the block
                c.blockTrial =0;
                while ~c.blocks(c.block).done  
                    c.trial = c.trial+1;
                    
                    beforeTrial(c); % Get all plugins ready for the next trial
                    
                    %ITI - wait
                    if c.trial>1
                        nFramesToWait = c.ms2frames(c.iti - (c.clockTime-c.trialStopTime));
                        for i=1:nFramesToWait
                            Screen('Flip',c.mainWindow,0,1-c.itiClear);     % WaitSecs seems to desync flip intervals; Screen('Flip') keeps frame drawing loop on target.
                        end
                    end
                    
                    c.frame=0;
                    c.flags.trial = true;
                    PsychHID('KbQueueFlush');
                    
                    Priority(MaxPriority(c.mainWindow));
                    while (c.flags.trial && c.flags.experiment)
                        %%  Trial runnning -
                        c.frame = c.frame+1;
                        
                        %% Check for end of trial
                        if c.frame-1 >= c.ms2frames(c.trialDuration)  % if trialDuration has been reached, minus one frame for clearing screen
                            c.flags.trial=false; % This will be the last frame.
                            clr = c.itiClear; % Do not clear this last frame if the ITI should not be cleared
                        else
                            clr = c.clear;
                        end
                        
                        
                        base(c.pluginOrder,neurostim.stages.BEFOREFRAME,c);
                        Screen('DrawingFinished',c.mainWindow);
                        base(c.pluginOrder,neurostim.stages.AFTERFRAME,c);
                        
                        KbQueueCheck(c);
                        
                        
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
                        [ptbVbl,ptbStimOn] = Screen('Flip', c.mainWindow,[],1-clr,c.timing.vsyncMode);
                       
                        
                        if c.timing.vsyncMode==0 
                            % Flip returns correct values                            
                        else
                            % Flip's return arguments are not meaningful.
                            % It is now difficult to estimate when exactly
                            % the flip occurred.
                            ptbVbl = GetSecs;
                            ptbStimOn = ptbVbl;
                        end
                        missed  = (ptbVbl-frameDeadline); % Positive is too late (i.e. a drop)
                        
                        if c.frame > 1 && locPROFILE
                            addProfile(c,'FRAMELOOP','cic',c.toc);
                            tic(c)
                            addProfile(c,'FLIPTIME','cic',1000*(GetSecs-startFlipTime));
                        end
                        
                        
                        % Predict next frame and check frame drops 
                        frameDeadline = ptbVbl+ FRAMEDURATION; 
                        if c.frame == 1
                            locFIRSTFRAMETIME = ptbStimOn*1000; % Faster local access for trialDuration check
                            c.firstFrame = locFIRSTFRAMETIME;% log it                            
                            c.flipTime=0;
                        else
                            if missed>ITSAMISS
                                c.frameDrop = [c.frame-1 missed]; % Log frame and delta
                                if c.guiOn
                                    c.writeToFeed(['Missed Frame ' num2str(c.frame) ' \Delta: ' num2str(missed)]);
                                end
                            end
                        end
                                                
                        if c.getFlipTime
                            c.flipTime = ptbStimOn*1000-locFIRSTFRAMETIME;% Used by stimuli to log their onset
                            c.getFlipTime=false;
                        end                        
                        
                    end % Trial running
                                        
                    Priority(0);
                    if ~c.flags.experiment || ~ c.flags.block ;break;end
                    
                    [~,ptbStimOn]=Screen('Flip', c.mainWindow,0,1-c.itiClear);
                    c.trialStopTime = ptbStimOn*1000;
                    c.frame = c.frame+1;
                    
                    afterTrial(c);                                        
                end % one block
                
                Screen('glLoadIdentity', c.mainWindow);
                if ~c.flags.experiment;break;end                
                
                %% Perform afterBlock message/function
                waitforkey = false;
                if isa(c.blocks(c.block).afterMessage,'function_handle')
                    msg = c.blocks(c.block).afterMessage(c);
                else
                    msg = c.blocks(c.block).afterMessage;
                end                                
                if ~isempty(msg)                    
                    DrawFormattedText(c.mainWindow,msg,'center','center',c.screen.color.text);
                    waitforkey=c.blocks(c.block).afterKeyPress;
                end                
                if ~isempty(c.blocks(c.block).afterFunction)
                   c.blocks(c.block).afterFunction(c);
                   waitforkey=c.blocks(c.block).afterKeyPress;
                end
                Screen('Flip',c.mainWindow);
                if waitforkey
                    KbWait(c.kbInfo.pressAnyKey,2);
                end
            end %blocks
            c.trialStopTime = c.clockTime;
            c.stopTime = now;
            
            DrawFormattedText(c.mainWindow, 'This is the end...', 'center', 'center', c.screen.color.text);
            Screen('Flip', c.mainWindow);
            
            base(c.pluginOrder,neurostim.stages.AFTEREXPERIMENT,c);
            c.KbQueueStop;
            if c.keyAfterExperiment; KbWait(c.kbInfo.pressAnyKey);end
            
            %Prune the log of all plugins/stimuli and cic itself
            pruneLog([c.pluginOrder c]);
            c.saveData;
            Screen('CloseAll');
            %ListenChar(0);
            if c.PROFILE; report(c);end
        end
        
        function saveData(c)
            filePath = horzcat(c.fullFile,'.mat');
            save(filePath,'c');
            disp(horzcat('Data saved to ',filePath));
        end
        
        function delete(c) %#ok<INUSD>
            %Destructor. Release all resources. Maybe more to add here?
            %Screen('CloseAll');
        end
        
        %% Keyboard handling routines
        %
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
            if ischar(key) || iscellstr(key)
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
        
        %% GUI Functions
        function writeToFeed(c,message)
            if c.guiOn
                c.gui.writeToFeed(message);
            else
                message=horzcat('\n TR:',num2str(c.trial), ': ', message, '\n');
                fprintf(1,message);
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
        
        % Update the CLUT for the overlay. Specify [N 3] clut entries and
        % the location in the CLUT where they should be placed. 
        function updateOverlay(c,clut,index)
            if nargin<3
                index = 2:size(clut,1);
                if nargin <2
                    clut = [];
                end
            end
            [nrRows,nrCols] = size(c.screen.overlayClut);
            if nrCols ~=3
                error('The overlay CLUT should have 3 columns (RGB)');
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
        
    end
    
    methods (Access=private)
        
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
                otherwise
                    error(['Unknown screen type : ' c.screen.type]);
            end
            
            %%  Setup color calibration
            %
            switch upper(c.screen.colorMode)
                case 'LINLUT'
                    % Load a gamma table that linearizes each gun
                    % Dont do this for VPIXX etc. monitor types.
                    dac = ScreenDacBits(c.screen.number);
                    iGamma = InvertGammaTable(c.screen.calibration.gammaInput,c.screen.calibration.gammaTable,2.^dac);
                    Screen('LoadNormalizedGammaTable',c.screen.number,iGamma);
                case 'LUM'
                    % The user specifies luminance values per gun as color.
                    % Calibrateed responses are based on the extended gamma
                    % function fits. (although this should work, LUM works better; not recommended).
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
                        disp(['****You can safely ignore the message about '' clearcolor'' that just appeared***']);
                    end
                    c.overlayWindow = PsychImaging('GetOverlayWindow', c.mainWindow);
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
                    PsychColorCorrection('SetEncodingGamma', c.mainWindow,1./c.screen.calibration.gamma);
                    if isnan(c.screen.calibration.bias)
                        % Only gamma defined
                        PsychColorCorrection('SetColorClampingRange',c.mainWindow,0,1); % In non-extended mode, luminance is between [0 1]
                    else
                        % If the user set the calibration.bias parameters then s/he wants to perform a slightly more advanced calibration
                        % out = bias + gain * ((lum-minLum)./(maxLum-minLum)) ^1./gamma )
                        % where each parameter can be specified per gun
                        % (i.e. c.calibration.bias= [ 0 0.1 0])
                        PsychColorCorrection('SetExtendedGammaParameters', c.mainWindow, c.screen.calibration.min, c.screen.calibration.max, c.screen.calibration.gain,c.screen.calibration.bias);
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
            
            %% Setup the GUI.
            %
            %             if any(strcmpi(c.plugins,'gui'))%if gui is added
            %
            %                 guiScreen = setdiff(Screen('screens'),[c.screen.number 0]);
            %                 if isempty(guiScreen)
            %                     %                    error('You need two screens to show a gui...');
            %                     guiScreen = 0;
            %                     guiRect = [800 0 1600 600];
            %
            %                 else
            %                     guiRect  = Screen('GlobalRect',guiScreen);
            %                     %                 if ~isempty(.screen.xorigin)
            %                     %                     guiRect(1) =o.screen.xorigin;
            %                     %                 end
            %                     %                 if ~isempty(o.screen.yorigin)
            %                     %                     guiRect(2) =o.screen.yorigin;
            %                     %                 end
            %                     %                 if ~isempty(o.screen.xpixels)
            %                     %                     guiRect(3) =guiRect(1)+ o.screen.xpixels;
            %                     %                 end
            %                     %                 if ~isempty(o.screen.ypixels)
            %                     %                     guiRect(4) =guiRect(2)+ o.screen.ypixels;
            %                     %                 end
            %                 end
            %                 if isempty(c.mirrorPixels)
            %                     c.mirrorPixels=Screen('Rect',guiScreen);
            %                 end
            %                 c.guiWindow  = PsychImaging('OpenWindow',guiScreen,c.screen.color.background,guiRect);
            %
            %                 % TODO should this be separate for the mirrorWindow?
            %                 switch upper(c.screen.colorMode)
            %                     case 'XYL'
            %                         PsychColorCorrection('SetSensorToPrimary', c.guiWindow, cal);
            %
            %                     case 'RGB'
            %                         Screen(c.guiWindow,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            %                 end
            %             end
            %
            
            
            
        end   
    end
    
    
    
    methods (Static)
        function v = clockTime
            v = GetSecs*1000;
        end
    end
    
    methods
        function report(c)
            %% Profile report
            plgns = fieldnames(c.profile);
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
                    vals{i,j} = c.profile.(plgns{i}).(items{j});
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
            figure('Name',[c.file ' - framedrop report'])
            [val,tr,ti,eTi] = get(c.prms.frameDrop);
            if size(val,1)==1
                % No drops
                title 'No Drops';
                return
            end
            val = cat(1,val{:});
            delta =1000*val(:,2); % How much too late...
            slack = 0.2;
            [~,~,criticalStart] = get(c.prms.firstFrame,'atTrialTime',inf);
            [~,~,criticalStop] = get(c.prms.trialStopTime,'atTrialTime',inf);
            meanDuration = nanmean(criticalStop-criticalStart);
            out = (ti<(criticalStart(tr)-slack*meanDuration) | ti>(criticalStop(tr)+slack*meanDuration));
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
    
    
end