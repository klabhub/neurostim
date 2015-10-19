% Functionality
%   Generate output as sib object/infos
%  Tricky.
%   Mirror window
%       Neeed for ephys, to position stimuli etc.
%
%   nsMonitor
%
%
% Plugins ready to test:
%   Eyelink (32 bt windows or 64 bit linux needed)
%   MCC     (MCC needed... or demoboard...?)
%
% Plugins to make
%  COLORCAL
% 	Colorcal2.m under psychhardware
%
%   RIPPLE
%
%
% LOW PRRIORITY
%   More generic adaptive parm.
%       There is a max entropy staircase built in , just need to wrap.
% 	Remote monitoring?


classdef cic < neurostim.plugin
    
    %% Events
    % All communication with plugins is through events. CIC generates events
    % to notify plugins (which includes stimuli) about the current stage of
    % the experiment. Plugins tell CIC that they want to listen to a subset
    % of all events (plugin.listenToEvent()), and plugins have the code to
    % respond to the events (plugin.events()).
    % Note that plugins are completely free to do what they want in the
    % event handlers. For stimuli, however, each event is first processed
    % by the base @stimulus class and only then passed to the derived
    % class. This helps neurostim to generate consistent behavior.
    events
        
        %% Experiment Flow
        % Events to which the @stimulus class responds (internal)
        BASEBEFOREEXPERIMENT;
        BASEAFTEREXPERIMENT;
        BASEBEFORETRIAL;
        BASEAFTERTRIAL;
        BASEBEFOREFRAME;
        BASEAFTERFRAME;
        
        % Events to which client developed @plugin and @stimulus classes
%         % respond
%         BEFOREEXPERIMENT;
%         AFTEREXPERIMENT;
%         BEFORETRIAL;
%         AFTERTRIAL;
%         BEFOREFRAME;
%         AFTERFRAME;
        FIRSTFRAME;
        
        %%
        GIVEREWARD;
        
    end
    %% Constants
    properties (Constant)
        PROFILE@logical = true; % Using a const to allow JIT to compile away profiler code
        
%         defaultPluginOrder = {'mcc','stimuli','eyetracker','behavior','unknown'};
    end
    
    %% Public properties
    % These can be set in a script by a user to setup the
    % experiment
    properties (GetAccess=public, SetAccess =public)
        mirrorPixels@double   = []; % Window coordinates.[left top width height].
        root@char               = pwd;    % Root target directory for saving files.
        subjectNr@double        = 0;
        paradigm@char           = 'test';
        clear@double            = 1;   % Clear backbuffer after each swap. double not logical
        iti@double              = 1000; % Inter-trial Interval (ms) - default 1s.
        trialDuration@double    = 1000;  % Trial Duration (ms)
        screen                  = struct('pixels',[],'physical',[],'color',struct('text',[1/3 1/3 50],...
                                    'background',[1/3 1/3 5]),'colorMode','xyL',...
                                    'framerate',60);    %screen-related parameters.
        flipTime;   % storing the frame flip time.
        getFlipTime@logical = false; %flag to notify whether to getg the frame flip time.
        requiredSlack = 0;  % required slack time in frame loop (stops all plugins after this time has passed)
        
        profile=struct;
        guiOn@logical=false;
        mirror =[]; % The experimenters copy
    end
    
    %% Protected properties.
    % These are set internally
    properties (GetAccess=public, SetAccess =protected)
        %% Program Flow
        window =[]; % The PTB window
        onscreenWindow=[]; % The display/onscreen window
        
        flags = struct('trial',true,'experiment',true,'block',true); % Flow flags
        block = 0;      % Current block.
        condition = [];  % Current condition
        trial = 0;      % Current trial
        frame = 0;      % Current frame
        cursorVisible = false; % Set it through c.cursor =
        vbl = [];
        %% Internal lists to keep track of stimuli, conditions, and blocks.
        stimuli;    % Cell array of char with stimulus names.
        conditions; % Map of conditions to parameter specs.
        blocks;     % Struct array with .nrRepeats .randomization .conditions
        plugins;    % Cell array of char with names of plugins.
        responseKeys; % Map of keys to actions.(See addResponse)
        
        %% Logging and Saving
        startTime@double    = 0; % The time when the experiment started running
        stopTime = [];
        frameStart = 0;
        frameDeadline;
        %data@sib;
        
        %% Profiling information.
        
        %% Keyboard interaction
        allKeyStrokes          = []; % PTB numbers for each key that is handled.
        allKeyHelp             = {}; % Help info for key
        keyDeviceIndex          = []; % Use the first device by default
        keyHandlers             = {}; % Handles for the plugins that handle the keys.
        
        
        pluginOrder = {};
        
    end
    
    %% Dependent Properties
    % Calculated on the fly
    properties (Dependent)
        nrStimuli;      % The number of stimuli currently in CIC
        nrConditions;   % The number of conditions in this experiment
        nrTrials;       % The number of trials in this experiment
        center;         % Where is the center of the display window.
        file;           % Target file name
        fullFile;       % Target file name including path
        subject@char;   % Subject
        startTimeStr@char;  % Start time as a HH:MM:SS string
        cursor;         % Cursor 'none','arrow'; see ShowCursor
        conditionName;  % The name of the current condition.
        blockName;      % Name of the current block
        defaultPluginOrder;

    end
    
    %% Public methods
    % set and get methods for dependent properties
    methods
        function v= get.nrStimuli(c)
            v= length(c.stimuli);
        end
        function v= get.nrTrials(c)
            v= length(c.blocks.conditions);
        end
        function v= get.nrConditions(c)
            v= length(c.conditions);
        end
        function v = get.center(c)
            [x,y] = RectCenter(c.screen.pixels);
            v=[x y];
        end
        function v= get.startTimeStr(c)
            v = datestr(c.startTime,'HH:MM:SS');
        end
        function v = get.file(c)
            v = [c.subject '.' c.paradigm '.' datestr(c.startTime,'HHMMSS') ];
        end
        function v = get.fullFile(c)
            v = fullfile(c.root,datestr(c.startTime,'YYYY/mm/DD'),c.file);
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
        
        function v = get.conditionName(c)
            v = key(c.conditions,c.condition);
        end
        
        function v = get.blockName(c)
            if c.block <= numel(c.blocks)
                v = c.blocks(c.block).name;
            else
                v = '';
            end
        end
        
        function set.subject(c,value)
            if ischar(value)
                c.subjectNr = double(value);
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
                HideCursor(c.window);
                c.cursorVisible = false;
            else
                ShowCursor(value,c.window);
                c.cursorVisible = true;
            end
        end
        
        function getFramerate(c)
            if isempty(c.screen.framerate) && ~isempty(c.window)
                frameDur = Screen('GetFlipInterval',c.window);
                c.screen.framerate = 1/frameDur;
            end
        end
        
        function set.screen(c,value)
            if ~isequal(value.physical,c.screen.physical)
                if ~isequal(c.screen.pixels(3)/value.physical(1),c.screen.pixels(4)/value.physical(2))
                    warning('Physical dimensions are not the same aspect ratio as pixel dimensions.');
                end
            end
            c.screen = value;
        end
        
        function v=get.defaultPluginOrder(c)
            v = [fliplr(c.stimuli) fliplr(c.plugins)];
        end
           

        
    end
    
    
    methods (Access=public)
        % Constructor.
        function c= cic
            c = c@neurostim.plugin('cic');
            % Some very basic PTB settings that are enforced for all
            KbName('UnifyKeyNames'); % Same key names across OS.
            % c.cursor = 'none';           
            % Initialize empty
            c.startTime     = now;
            c.stimuli       = {};
            c.conditions    = neurostim.map;
            c.plugins       = {};
            
            % Setup the keyboard handling
            c.responseKeys  = neurostim.map;
            c.allKeyStrokes = [];
            c.allKeyHelp  = {};
            % Keys handled by CIC
            addKeyStroke(c,KbName('q'),'Quit',c);
            c.addProperty('missedFrame',[]);
            c.addProperty('trialStartTime',[]);
            c.addProperty('trialEndTime',[]);
            c.add(neurostim.plugins.output);
            c.addKey('q',@keyboardResponse,'Quit');
            c.addKey('n',@keyboardResponse,'Next Trial');
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
            if ismember('eScript',c.plugins)
                plg = c.eScript;
            else
                plg = neurostim.plugins.eScript;
                
            end
            plg.addScript(when,fun,keys);
            % Add or update the plugin (must call after adding script
            % so that all events are listened to
            c.add(plg);
        end
        
        function addResponse(c,key,varargin)
            % function addResponse(c,key,varargin)
            % Add a key that the subject can press to give a response. The
            % optional parameter/value pairs define what the key does:
            %
            % 'write' : the value to log []
            % 'after' : only respond to this key after this time [-Inf]
            % 'before' : only respond to this key before this time [+Inf];
            % 'nextTrial' : logical to indicate whether to start a new trial
            % 'keyHelp' : a short string to document what this key does.
            %
            p =inputParser;
            p.addParameter('write',[]);
            p.addParameter('after',-Inf,@isnumeric);
            p.addParameter('before',Inf,@isnumeric);
            p.addParameter('nextTrial',false,@islogical);
            p.addParameter('keyHelp','?',@ischar);
            p.parse(varargin{:});
            addKeyStroke(c,KbName(key),p.Results.keyHelp,c);
            c.responseKeys(key) = p.Results;
        end
        
        function keyboardResponse(c,key)
%             CIC Responses to keystrokes.
%             q = quit experiment
            switch (key)
                case 'q'
                    c.flags.experiment = false;
                    c.flags.trial = false;
                case 'n'
                    c.flags.trial = false;
                otherwise
                    % Respond to the keys added by cic.addResponse
                    actions = c.responseKeys(key);
                    if c.frame >= actions.after && c.frame <= actions.before
                        c.write(key,actions.write)
                        disp([key ':' num2str(actions.write)]);
                        if actions.nextTrial
                            c.nextTrial;
                        end
                    end
            end
        end
        
        function [x,y,buttons] = getMouse(c)
              [x,y,buttons] = GetMouse(c.onscreenWindow);            
              [x,y] = c.pixel2Physical(x,y);
        end
        
        
        function glScreenSetup(c,window)            
            Screen('glLoadIdentity', window);
            Screen('glTranslate', window,c.screen.pixels(3)/2,c.screen.pixels(4)/2);
            Screen('glScale', window,c.screen.pixels(3)/c.screen.physical(1), -c.screen.pixels(4)/c.screen.physical(2));
        end
        
        
        function restoreTextPrefs(c)
            
            defaultfont = Screen('Preference','DefaultFontName');
            defaultsize = Screen('Preference','DefaultFontSize');
            defaultstyle = Screen('Preference','DefaultFontStyle');
            Screen('TextFont', c.window, defaultfont);
            Screen('TextSize', c.window, defaultsize);
            Screen('TextStyle', c.window, defaultstyle);
            
        end
        
        
        function createEventListeners(c)
           % creates all Event Listeners
           if isempty(c.pluginOrder)
            c.pluginOrder = c.defaultPluginOrder;
           end
           for a = 1:numel(c.pluginOrder)
               o = c.(c.pluginOrder{a});
               
               for i=1:length(o.evts)
                   if isa(o,'neurostim.plugin')
                       % base events allow housekeeping before events
                       % trigger, but giveReward and firstFrame do not require a
                       % baseEvent.
                        if strcmpi(o.evts{i},'GIVEREWARD')
                            h=@(c,evt)(o.giveReward(o.cic,evt));
                       elseif strcmpi(o.evts{i},'FIRSTFRAME')
                           h=@(c,evt)(o.firstFrame(o.cic,evt));
                       else
                           addlistener(c,['BASE' o.evts{i}],@o.baseEvents);
                           switch upper(o.evts{i})
                               case 'BEFOREEXPERIMENT'
                                   h= @(c,evt)(o.beforeExperiment(o.cic,evt));
                               case 'BEFORETRIAL'
                                   h= @(c,evt)(o.beforeTrial(o.cic,evt));
                               case 'BEFOREFRAME'
                                   h= @(c,evt)(o.beforeFrame(o.cic,evt));
                               case 'AFTERFRAME'
                                   h= @(c,evt)(o.afterFrame(o.cic,evt));
                               case 'AFTERTRIAL'
                                   h= @(c,evt)(o.afterTrial(o.cic,evt));
                               case 'AFTEREXPERIMENT'
                                   h= @(c,evt)(o.afterExperiment(o.cic,evt));
                           end
                       end
                        % Install a listener in the derived class so that it
                       % can respond to notify calls in the base class
                       addlistener(o,o.evts{i},h);
                   end
               end
           end
        end
        
        
        function pluginOrder = order(c,varargin)
            % pluginOrder = c.order([plugin1] [,plugin2] [,...])
            % Returns pluginOrder when no input is given.
            % Inputs: lists name of plugins in the order they are requested
            % to be executed in.
                 if isempty(c.pluginOrder)
                    c.pluginOrder = c.defaultPluginOrder;
                end
                
                if nargin>1
                    if iscellstr(varargin)
                        a = varargin;
                    else
                        for j = 1:nargin-1
                            a{j} = varargin{j}.name;
                        end
                    end
                    
                    [~,indpos]=ismember(c.pluginOrder,a);
                    reorder=c.pluginOrder(logical(indpos));
                    [~,i]=sort(indpos(indpos>0));
                    reorder=fliplr(reorder(i));
                    neworder=cell(size(c.pluginOrder));
                    neworder(~indpos)=c.pluginOrder(~indpos);
                    neworder(logical(indpos))=reorder;
                    c.pluginOrder=neworder;
                    
                end
                if numel(c.pluginOrder)<numel(c.defaultPluginOrder)
                   b=ismember(c.defaultPluginOrder,c.pluginOrder);
                   index=find(~b);
                   c.pluginOrder=[c.pluginOrder(1:index-1) c.defaultPluginOrder(index) c.pluginOrder(index:end)];
                end
            pluginOrder = c.pluginOrder;
        end
        


       
        
        function disp(c)
            % Provide basic information about the CIC
            disp(char(['CIC. Started at ' datestr(c.startTime,'HH:MM:SS') ],...
                ['Stimuli:' num2str(c.nrStimuli) ' Conditions:' num2str(c.nrConditions) ' Trials:' num2str(c.nrTrials) ]));
        end
        
        function nextTrial(c)
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
            
            if ismember(o.name,c.(nm))
                %    error(['This name (' o.name ') already exists in CIC.']);
                % Update existing
            elseif  isprop(c,o.name)
                error(['Please use a different name for your stimulus. ' o.name ' is reserved'])
            else
                h = c.addprop(o.name); % Make it a dynamic property
                c.(o.name) = o;
                h.SetObservable = false; % No events
                c.(nm) = cat(2,c.(nm),o.name);
                % Set a pointer to CIC in the plugin
                o.cic = c;
                if strcmp(nm,'plugins') && c.PROFILE
                    c.profile.(o.name)=struct('BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[]);
                end
            end
            
            % Call the keystroke function
            for i=1:length(o.keyStrokes)
                addKeyStroke(c,o.keyStrokes{i},o.keyHelp{i},o);
            end

        end
        
        
        
        %% -- Specify conditions -- %%
        function addCondition(c,name,specs)
            % Add one condition
            % name  =  name of the condition
            % parms = triplets {'stimulus name','variable', value}
            stimNames = specs(1:3:end);
            unknownStimuli = ~ismember(stimNames,cat(2,c.stimuli,'cic'));
            if any(unknownStimuli)
                error(['These stimuli are unknown, add them first: ' specs{3*(find(unknownStimuli)-1)+1}]);
            else
                c.conditions(name) = specs;
            end
        end
        
        
            
        
        function addFactorial(c,name,varargin)
            % Add a factor to the design.
            % name = name of the factorial
            % parms  = A cell array specifying the factorial with elements
            % specifying the stimulus name, the variable, and the values.
            % Note that the values must be specified as a cell array.
            % A single one-way factorial varying coherence:
            %    addFactorial(c,'coherenceFactorial',{'lldots','coherence',{0 0.5 1}};
            % Or to vary both the coherence and the position together:
            %    addFactorial(c,'coherenceFactorial',{'lldots','coherence',{0 0.5 1},'lldots','X',[-1 0 1]};
            % To specify a two-way factorial, simply add multipe specs cell
            % arrays as the argument:
            % E.g. a two-way [3x2] with 6 conditions
            %    addFactorial(c,'coherenceFactorial',
            %                   {'lldots','coherence',[0 0.5 1]};
            %                   {'lldots','X',[-1 1]});
            % Implementation note: this function simply translates the
            % factorial specs into specs for individual conditions and stores
            % those just like individual conditions would have been. So this is
            % merely a convenience function for the user.
            nrFactors =numel(varargin);
            nrLevels = nan(nrFactors,1);
            parmValues  = cell(nrFactors,1);
            for f=1:nrFactors
                factorSpecs =varargin{f};

                if ~all(cellfun(@iscell,factorSpecs(3:3:end)))
                    error('Levels must be specified as cell arrays');
                end
                thisNrLevels = unique(cellfun(@numel,factorSpecs(3:3:end)));
                if length(thisNrLevels)>1
                    error(['The number of levels in factor ' num2str(f) ' is not consistent across variables']);
                else
                    nrLevels(f) =  thisNrLevels;
                end
                parmValues{f} = factorSpecs{3:3:end};
            end
            conditionsInFactorial = 1:prod(nrLevels);
            subs = cell(1,nrFactors);
            for thisCond=conditionsInFactorial;
                [subs{:}]= ind2sub(nrLevels',thisCond);
                conditionName = [name num2str(thisCond)];
                conditionSpecs= {};
                for f=1:nrFactors
                    factorSpecs =varargin{f};
                    nrParms = numel(factorSpecs)/3;
                    for p=1:nrParms
                        value = factorSpecs{3*p}{subs{f}};
                        specs = factorSpecs(3*p-2:3*p);
                        specs{3} = value;
                        conditionSpecs = cat(2,conditionSpecs,specs);
                    end
                end
                c.addCondition(conditionName,conditionSpecs);
            end
        end
        
        function addBlock(c,blockName,conditionNames,nrRepeats,randomization)
            % Select certain conditions to be part of a block.
            % blockName = a descriptive name for this block
            % conditionNames = which (existing) condtions or factorials should
            % be run in this block. (Char or cell array of names)
            % nrRepeats = how often should these conditions/factorials be
            % repeated
            % randomization = how should conditions be randomized across trials
            
            
            blck.name = blockName;
            blck.nrRepeats = nrRepeats;
            blck.randomization = randomization;
            conditionNames = strcat('^',conditionNames,'\d*');
            conditionNumbers = index(c.conditions,conditionNames);
            if any(isnan(conditionNumbers))
                notFound = unique(conditionNames(isnan(conditionNumbers)));
                notFound = strrep(notFound,'^','');notFound = strrep(notFound,'\d*','');
                disp('These Conditions are undefined: ' );
                notFound
                error('Conditions not found');
            end
            switch (randomization)
                case 'SEQUENTIAL'
                    blck.conditions = repmat(conditionNumbers,[1 nrRepeats]);
                case 'RANDOMWITHREPLACEMENT'
                    blck.conditions = repmat(conditionNumbers,[1 nrRepeats]);
                    blck.conditions = blck.conditions(randperm(numel(blck.conditions)));
                case 'BLOCKRANDOMWITHREPLACEMENT'
                    blck.conditions = zeros(1,0);
                    for i=1:nrRepeats
                        blck.conditions = cat(2,blck.conditions, conditionNumbers(randperm(numel(conditionNumbers))));
                    end
                otherwise
                    error(['This randomization mode is unknown: ' randomization ]);
            end
            c.blocks = cat(1,c.blocks,blck);
        end
        
        
        
        function beforeTrial(c)
            % Assign values specified in the design to each of the stimuli.
            specs = c.conditions(c.condition);
            nrParms = length(specs)/3;
            for p =1:nrParms
                stimName =specs{3*(p-1)+1};
                varName = specs{3*(p-1)+2};
                value   = specs{3*(p-1)+3};
                if strcmpi(stimName,'CIC')
                    % This condition changes one of the CIC properties
                    c.(varName) = value;
                else
                    % Change a stimulus or plugin property
                    stim  = c.(stimName);
                    stim.(varName) = value;
                end
            end
            
            
        end
        
        function afterTrial(c)
            
        end
        
        function error(c,command,msg)
            switch (command)
                case 'STOPEXPERIMENT'
                    fprintf(2,msg);
                    c.flags.experiment = false;
                otherwise
                    error('?');
            end
            
        end
        
        function run(c)
            %Add a generic output plug-in (there may be others already added)
            
            if isempty(c.screen.physical)
                % Assuming code is in pixels
                c.screen.physical = c.screen.pixels(3:4);
            end
            
            % Set up order and event listeners
            c.order;
            c.createEventListeners;
            % Setup PTB
            PsychImaging(c);
            c.KbQueueCreate;
            c.KbQueueStart;
            c.getFramerate;
            notify(c,'BASEBEFOREEXPERIMENT');
            DrawFormattedText(c.onscreenWindow, 'Press any key to start...', c.center(1), 'center', WhiteIndex(c.onscreenWindow));
            Screen('Flip', c.onscreenWindow);
            KbWait();
            c.flags.experiment = true;
            nrBlocks = numel(c.blocks);
%             ititime = GetSecs*1000;
            for blockNr=1:nrBlocks
                c.flags.block = true;
                c.block = blockNr;
                disp(['Begin Block: ' c.blockName]);
                for conditionNr = c.blocks(blockNr).conditions
                    
                    c.condition = [c.condition conditionNr];
                    c.trial = c.trial+1;
                    %                     disp(['Begin Trial #' num2str(c.trial) ' Condition: ' c.conditionName]);
                    beforeTrial(c);
                    notify(c,'BASEBEFORETRIAL');
                    if c.trial>1
                        while (round(c.iti-(GetSecs*1000-c.trialEndTime(c.trial-1)))*c.screen.framerate/1000)>0
                            Screen('Flip',c.onscreenWindow,0,1);     % WaitSecs seems to desync flip intervals; Screen('Flip') keeps frame drawing loop on target.
                        end
                    end
                    c.frame=0;
                    c.flags.trial = true;
                    PsychHID('KbQueueFlush');
                    c.frameStart=GetSecs*1000;
                    while (c.flags.trial && c.flags.experiment)
                        c.frame = c.frame+1;
                        notify(c,'BASEBEFOREFRAME');
                        Screen('DrawingFinished',c.window);
                        Screen('DrawTexture',c.onscreenWindow,c.window,c.screen.pixels,c.screen.pixels,[],0);
                        Screen('DrawingFinished',c.onscreenWindow);
                        notify(c,'BASEAFTERFRAME');
                        c.KbQueueCheck;
                        [vbl,stimon,flip,~] = Screen('Flip', c.onscreenWindow,0,1-c.clear);
                        if c.frame>1 && abs(c.frameDeadline-(flip*1000)) > (100/c.screen.framerate)
                            c.missedFrame = c.frame;
                            if c.guiOn
                                c.gui.writeToFeed('Missed Frame');
                            end
                        elseif c.getFlipTime
                            c.flipTime = stimon*1000;
                            c.getFlipTime=false;
                        end
                        
                        c.frameStart = flip*1000;
                        c.frameDeadline = (flip*1000)+(1000/c.screen.framerate);
                        
                        if c.frame == 1
                            notify(c,'FIRSTFRAME');
                            c.trialStartTime(c.trial) = vbl*1000; % for trialDuration check
                        end
                        if (floor(c.trialDuration/c.screen.framerate))<= ((GetSecs*1000-c.trialStartTime(c.trial))/c.screen.framerate)  % if trialDuration has been reached, minus one frame for clearing screen
                            c.flags.trial=false;
                        end
                        if c.clear
                            Screen('FillRect',c.window,c.screen.color.background);
                        end
                    end % Trial running
                    
                    if ~c.flags.experiment || ~ c.flags.block ;break;end
                    Screen('DrawTexture',c.onscreenWindow,c.window,c.screen.pixels,c.screen.pixels,[],0);

                    vbl=Screen('Flip', c.onscreenWindow,0,1-c.clear);
                    c.trialEndTime(c.trial) = GetSecs * 1000;
                    notify(c,'BASEAFTERTRIAL');
                    afterTrial(c);
                end %conditions in block
                if ~c.flags.experiment;break;end
            end %blocks
            if length(c.trialEndTime)<c.trial
                c.trialEndTime(c.trial) = GetSecs * 1000;
            end
            c.stopTime = now;
            DrawFormattedText(c.onscreenWindow, 'This is the end...', 'center', 'center', c.screen.color.text);
            Screen('Flip', c.onscreenWindow);
            notify(c,'BASEAFTEREXPERIMENT');
            Screen('glLoadIdentity',c.window);
            c.KbQueueStop;
            KbWait;
            Screen('CloseAll');
%             if c.PROFILE; report(c);end
        end
        
        
        
        %% Keyboard handling routines
        %
        function addKeyStroke(c,key,keyHelp,p)
            if ischar(key)
                key = KbName(key);
            end
            if ~isnumeric(key) || key <1 || key>256
                error('Please use KbName to add keys to keyhandlers')
            end
            if ismember(key,c.allKeyStrokes)
                error(['The ' key ' key is in use. You cannot add it again...']);
            else
                c.allKeyStrokes = cat(2,c.allKeyStrokes,key);
                c.keyHandlers{end+1}  = p;
                c.allKeyHelp{end+1} = keyHelp;
            end
        end
        
        function removeKeyStrokes(c,key)
            % removeKeyStrokes(c,key)
            % removes keys (cell array of strings) from cic. These keys are
            % no longer listened to.
            if ischar(key) || iscellstr(key)
                key = KbName(key);
            end
            if ~isnumeric(key) || any(key <1) || any(key>256)
                error('Please use KbName to add keys to keyhandlers')
            end
            if any(~ismember(key,c.allKeyStrokes))
                error(['The ' key(~ismember(key,c.allKeyStrokes)) ' key is not in use. You cannot remove it...']);
            else
                index = ismember(c.allKeyStrokes,key);
                c.allKeyStrokes(index) = [];
                c.keyHandlers(index)  = [];
                c.allKeyHelp(index) = [];
            end
        end
        
        function [a,b] = pixel2Physical(c,x,y)
            % converts from pixel dimensions to physical ones.
            tmp = [1 -1].*([x y]./c.screen.pixels(3:4)-0.5).*c.screen.physical(1:2);
            a = tmp(1);
            b = tmp(2);
        end
        
        function [a,b] = physical2Pixel(c,x,y)
            tmp = c.screen.pixels(3:4).*(0.5 + [x y]./([1 -1].*c.screen.physical(1:2)));
            a = tmp(1);
            b = tmp(2);
        end
    end
    
    
    methods (Access=public)
        
        %% Keyboard handling routines(protected). Basically light wrappers
        % around the PTB core functions
        function KbQueueCreate(c,device)
            if nargin>1
                c.keyDeviceIndex = device;
            end
            keyList = zeros(1,256);
            keyList(c.allKeyStrokes) = 1;
            KbQueueCreate(c.keyDeviceIndex,keyList);
        end
        
        function KbQueueStart(c)
            KbQueueStart(c.keyDeviceIndex);
        end
        
        function KbQueueStop(c)
            KbQueueStop(c.keyDeviceIndex);
        end
        
        function KbQueueCheck(c)
            [pressed, firstPress, firstRelease, lastPress, lastRelease]= KbQueueCheck(c.keyDeviceIndex);
             if pressed
                % Some key was pressed, pass it to the plugin that wants
                % it.
                %                 firstRelease(out)=[]; not using right now
                %                 lastPress(out) =[];
                %                 lastRelease(out)=[];
                ks = find(firstPress);
                for k=ks
                    ix = find(c.allKeyStrokes==k);% should be only one.
                    if length(ix) >1;error(['More than one plugin (or derived class) is listening to  ' KbName(k) '??']);end
                    % Call the keyboard member function in the relevant
                    % class
                    c.keyHandlers{ix}.keyboard(KbName(k),firstPress(k));
                end
            end
        end
        
        
        %% PTB Imaging Pipeline Setup
        function PsychImaging(c)
            AssertOpenGL;
            
            cal=setupScreen(c);
%             PsychImaging('PrepareConfiguration');
            screens=Screen('Screens');
            screenNumber=max(screens);
            
            % if bitspp
            %                PsychImaging('AddTask', 'General', 'EnableBits++Mono++OutputWithOverlay');
            PsychImaging('AddTask','General','UseFastOffscreenWindows');
            if any(strcmpi(c.plugins,'gui'))%if gui is added
                if ~isempty(c.mirrorPixels)
                c.mirrorPixels = [c.screen.pixels(1) c.screen.pixels(2) c.mirrorPixels(3) c.mirrorPixels(4)];
                else
                    c.mirrorPixels = [c.screen.pixels(1) c.screen.pixels(2) c.screen.pixels(3)*2 c.screen.pixels(4)];
                end
                % *****
                c.onscreenWindow = PsychImaging('OpenWindow',0, c.screen.color.background, c.mirrorPixels,[],[],[],[],kPsychNeedFastOffscreenWindows);
                c.window=Screen('OpenOffscreenWindow',c.onscreenWindow,c.screen.color.background,c.screen.pixels,[],2);
%               
            
            elseif ~isempty(c.mirrorPixels) % add a mirror by spanning both screens.
                PsychImaging('AddTask','General','MirrorDisplayToSingleSplitWindow');
                
                c.window = PsychImaging('OpenWindow',screenNumber, c.screen.color.background, c.mirrorPixels);
            else% otherwise open screen as normal
                c.onscreenWindow = PsychImaging('OpenWindow',screenNumber, c.screen.color.background, c.screen.pixels);
                c.window=Screen('OpenOffscreenWindow',c.onscreenWindow,c.screen.color.background,c.screen.pixels,[],2);
                
            end

            switch upper(c.screen.colorMode)
                case 'XYL'
                    PsychColorCorrection('SetSensorToPrimary', c.onscreenWindow, cal);
%                     PsychColorCorrection('SetSensorToPrimary',c.mirror,cal);
                case 'RGB'
%                     Screen(c.window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end
            


        end
        
        
        
        function cal=setupScreen(c)
            PsychImaging('PrepareConfiguration');
            % 32 bit frame buffer values
            PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');
            % Unrestricted color range
            PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');

            switch upper(c.screen.colorMode)
                case 'XYL'
                    % Use builtin xyYToXYZ() plugin for xyY -> XYZ conversion:
                    PsychImaging('AddTask', 'AllViews', 'DisplayColorCorrection', 'xyYToXYZ');
                    % Use builtin SensorToPrimary() plugin:
                    PsychImaging('AddTask', 'AllViews', 'DisplayColorCorrection', 'SensorToPrimary');
                    % Check color validity
                    PsychImaging('AddTask', 'AllViews', 'DisplayColorCorrection', 'CheckOnly');
                    
                    cal = LoadCalFile('PTB3TestCal');
                    load T_xyz1931
                    T_xyz1931 = 683*T_xyz1931;
                    cal = SetSensorColorSpace(cal,T_xyz1931,S_xyz1931);
                    cal = SetGammaMethod(cal,0);
                    
                case 'RGB'
                    cal = []; %Placeholder. Nothing implemented.
            end
        end
    end
    
    methods
        function report(c)
            subplot(2,2,1)
            x = c.profile.BEFOREFRAME;
            low = 5;high=95;
            %             bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            %             hist(1000*x,bins)
            hist(1000*x)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'BeforeFrame'
            
            subplot(2,2,2)
            x = c.profile.AFTERFRAME;
            %             bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            %             hist(1000*x,bins)
            hist(1000*x)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'AfterFrame'
            
            subplot(2,2,4)
            x = c.profile.AFTERTRIAL;
            %             bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            %             hist(1000*x,bins)
            hist(1000*x)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'AfterTrial'
            
            subplot(2,2,3)
            x = c.profile.BEFORETRIAL;
            %             bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            %             hist(1000*x,bins)
            hist(1000*x)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'BeforeTrial'
            
        end
        function addProfile(c,what,name,duration)
            c.profile.(name).(what) = [c.profile.(name).(what) duration];
        end
        

    end
    
end