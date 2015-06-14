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
        % respond
        BEFOREEXPERIMENT;
        AFTEREXPERIMENT;
        BEFORETRIAL;
        AFTERTRIAL;
        BEFOREFRAME;
        AFTERFRAME;
        
        %%
        reward;
        
    end
    %% Constants
    properties (Constant)
        PROFILE@logical = true; % Using a const to allow JIT to compile away profiler code
    end
    
    %% Public properties
    % These can be set in a script by a user to setup the
    % experiment
    properties (GetAccess=public, SetAccess =public)
        color                   = struct('text',[1/3 1/3 50],'background',[1/3 1/3 5]); % Colors
        colorMode               = 'xyL'; % xyL, RGBA
        pixels@double           = [];    % Window coordinates.[left top width height]
        physical@double         = []; % Window size in physical units [width height]
        mirrorPixels@double   = []; % Window coordinates.[left top width height].
        root@char               = pwd;    % Root target directory for saving files.
        subjectNr@double        = 0;
        paradigm@char           = 'test';
        clear@double            = 1;   % Clear backbuffer after each swap. double not logical
        iti@double              = 1000; % Inter-trial Interval (ms) - default 1s.
        trialDuration@double    = 1000;  % Trial Duration (ms)
        
        
    end
    
    %% Protected properties.
    % These are set internally
    properties (GetAccess=public, SetAccess =protected)
        %% Program Flow
        window =[]; % The PTB window
        mirror =[]; % The experimenters copy
        flags = struct('trial',true,'experiment',true,'block',true); % Flow flags
        block;      % Current block.
        condition;  % Current condition
        trial;      % Current trial
        frame;      % Current frame
        cursorVisible = false; % Set it through c.cursor =
        
        %% Internal lists to keep track of stimuli, conditions, and blocks.
        stimuli;    % Cell array of char with stimulus names.
        conditions; % Map of conditions to parameter specs.
        blocks;     % Struct array with .nrRepeats .randomization .conditions
        plugins;    % Cell array of char with names of plugins.
        responseKeys; % Map of keys to actions.(See addResponse)
        
        %% Logging and Saving
        startTime@double    = 0; % The time when the experiment started running
        %data@sib;
        
        %% Profiling information.
        profile@struct =  struct('BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[]);
        
        %% Keyboard interaction
        allKeyStrokes          = []; % PTB numbers for each key that is handled.
        allKeyHelp             = {}; % Help info for key
        keyDeviceIndex          = []; % Use the first device by default
        keyHandlers             = {}; % Handles for the plugins that handle the keys.
        
    end
    
    %% Dependent Properties
    % Calculated on the fly
    properties (Dependent)
        nrStimuli;      % The number of stimuli currently in CIC
        nrConditions;   % The number of conditions in this experiment
        nrTrials;       % The number of trials in this experiment
        center;         % Were is the center of the display window.
        file;           % Target file name
        fullFile;       % Target file name including path
        subject@char;   % Subject
        startTimeStr@char;  % Start time as a HH:MM:SS string
        cursor;         % Cursor 'none','arrow'; see ShowCursor
        conditionName;  % The name of the current condition.
        blockName;      % Name of the current block
    end
    
    %% Public methods
    % set and get methods for dependent properties
    methods
        function v= get.nrStimuli(c)
            v= length(c.stimuli);
        end
        function v= get.nrTrials(c)
            v= 0;
        end
        function v= get.nrConditions(c)
            v= length(c.conditions);
        end
        function v = get.center(c)
            [x,y] = RectCenter(c.pixels);
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
        
        function keyboard(c,key,time)
            % CIC Responses to keystrokes.
            % q = quit experiment
            %
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
              [x,y,buttons] = GetMouse(c.window);            
              tmp = [1 -1].*([x y]./c.pixels(3:4)-0.5).*c.physical;
              x= tmp(1);y=tmp(2);
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
                error(['Please use a differnt name for your stimulus. ' o.nae ' is reserved'])
            else
                h = c.addprop(o.name); % Make it a dynamic property
                c.(o.name) = o;
                h.SetObservable = false; % No events
                c.(nm) = cat(2,c.(nm),o.name);
                % Set a pointer to CIC in the plugin
                o.cic = c;
            end
            
            
            % Call the keystroke function
            for i=1:length(o.keyStrokes)
                addKeyStroke(c,o.keyStrokes{i},o.keyHelp{i},o);
            end
            
            % Setup the plugin to listen to the events it requested
            for i=1:length(o.evts)
                if isa(o,'neurostim.stimulus')
                    % STIMULUS events are special; the BASE event
                    % handlers look at them first and decide whether to
                    % pass them on to the stimulus itself.
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
                    % Install a listener in the derived class so that it
                    % can respond to notify calls in the base class
                    addlistener(o,o.evts{i},h);
                else
                    switch upper(o.evts{i})
                        case 'BEFOREEXPERIMENT'
                            h= @(c,evt)(o.beforeExperiment(c,evt));
                        case 'BEFORETRIAL'
                            h= @(c,evt)(o.beforeTrial(c,evt));
                        case 'BEFOREFRAME'
                            h= @(c,evt)(o.beforeFrame(c,evt));
                        case 'AFTERFRAME'
                            h= @(c,evt)(o.afterFrame(c,evt));
                        case 'AFTERTRIAL'
                            h= @(c,evt)(o.afterTrial(c,evt));
                        case 'AFTEREXPERIMENT'
                            h= @(c,evt)(o.afterExperiment(c,evt));
                    end
                    % Install a listener in CIC. It will distribute.
                    addlistener(c,o.evts{i},h);
                end
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
                parmValues{f} = varargin{f}(3:3:end);
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
            % Assign values specified in the desing to each of the stimuli.
            specs = c.conditions(c.condition);
            nrParms = length(specs)/3;
            for p =1:nrParms
                stimName =specs{3*(p-1)+1};
                varName = specs{3*(p-1)+2};
                value   = specs{3*(p-1)+3};
                if strcmpi(stimName,'CIC')
                    % This codition changes one of the CIC properties
                    c.(varName) = value;
                else
                    % Change a stimulus  or plugin property
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
                    fprintf(2,msg)
                    c.flags.experiment = false;
                otherwise
                    error('?');
            end
            
        end
        
        function run(c)
            
            if isempty(c.physical)
                % Assuming code is in pixels
                c.physical = c.pixels(3:4);
            end
            
            % Setup PTB
            PsychImaging(c);
            
            c.KbQueueCreate;
            c.KbQueueStart;
            
            c.trial = 0;
            DrawFormattedText(c.window, 'Press any key to start...', 'center', 'center', c.color.text);
            Screen('Flip', c.window);
            KbWait();
            notify(c,'BASEBEFOREEXPERIMENT');
            notify(c,'BEFOREEXPERIMENT');
            c.flags.experiment = true;
            when =0;
            nrBlocks = numel(c.blocks);
            trialEndTime = GetSecs*1000;
            for blockNr=1:nrBlocks
                c.flags.block = true;
                c.block = blockNr;
                disp(['Begin Block: ' c.blockName]);
                for conditionNr = c.blocks(blockNr).conditions
                    c.condition = conditionNr;
                    c.trial = c.trial+1;
                    
                    disp(['Begin Trial #' num2str(c.trial) ' Condition: ' c.conditionName]);
                    
                    %                     if ~isempty(c.mirror)
                    %                         Screen('CopyWindow',c.window,c.mirror);
                    %                     end
                    if (c.PROFILE); tic;end
                    beforeTrial(c);
                    notify(c,'BASEBEFORETRIAL');
                    notify(c,'BEFORETRIAL');
                    if (c.PROFILE); addProfile(c,'BEFORETRIAL',toc);end
                    WaitSecs((trialEndTime+c.iti)/1000-GetSecs);    % wait ITI before next trial
                    c.flags.trial = true;
                    c.frame=0;
                    trialStartTime = GetSecs*1000;  % for trialDuration check
                    while (c.flags.trial)
                        %                         time = GetSecs;
                        c.frame = c.frame+1;
                        if (c.PROFILE); tic;end
                        notify(c,'BASEBEFOREFRAME');
                        notify(c,'BEFOREFRAME');
                        if (c.PROFILE); addProfile(c,'BEFOREFRAME',toc);end
                        Screen('DrawingFinished',c.window);
                        if (c.PROFILE); tic;end
                        notify(c,'BASEAFTERFRAME');
                        notify(c,'AFTERFRAME');
                        c.KbQueueCheck;
                        if (c.PROFILE); addProfile(c,'AFTERFRAME',toc);end
                        vbl=Screen('Flip', c.window,when,1-c.clear);
                        %                         if (vbl - time) > (2/60 - .5*2/60)
                        %                             warning('Missed frame.');     % check for missed frames
                        %                         end
                        %                         if ~isempty(c.mirror)
                        %                             Screen('CopyWindow',c.window,c.mirror);
                        %                         end
                        if (c.trialDuration <= (GetSecs*1000-trialStartTime))   % if trialDuration has been reached
                            c.flags.trial=false;
                        end
                    end % Trial running
                    trialEndTime = GetSecs * 1000;
                    if ~c.flags.experiment || ~ c.flags.block ;break;end
                    if (c.PROFILE); tic;end
                    vbl=Screen('Flip', c.window,when,1-c.clear);
                    notify(c,'BASEAFTERTRIAL');
                    notify(c,'AFTERTRIAL');
                    afterTrial(c);
                    if (c.PROFILE); addProfile(c,'AFTERTRIAL',toc);end
                end %conditions in block
                if ~c.flags.experiment;break;end
            end %blocks
            notify(c,'BASEAFTEREXPERIMENT');
            notify(c,'AFTEREXPERIMENT');
            Screen('glLoadIdentity',c.window);
            DrawFormattedText(c.window, 'This is the end...', 'center', 'center', c.color.text);
            Screen('Flip', c.window);
            c.KbQueueStop;
            KbWait;
            Screen('CloseAll');
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
                    ix = unique(find(c.allKeyStrokes==k));% should be only one.
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
            PsychImaging('PrepareConfiguration');
            % 32 bit frame buffer values
            PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');
            % Unrestricted color range
            PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
            switch upper(c.colorMode)
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
                    
            end
            
            
            % if bitspp
            %                PsychImaging('AddTask', 'General', 'EnableBits++Mono++OutputWithOverlay');
            
            
            % end
            screens=Screen('Screens');
            screenNumber=max(screens);
            c.window = PsychImaging('OpenWindow',screenNumber, c.color.background, c.pixels);
            
            switch upper(c.colorMode)
                case 'XYL'
                    PsychColorCorrection('SetSensorToPrimary', c.window, cal);
                case 'RGB'
                    Screen(c.window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end
            
            
            if ~isempty(c.mirrorPixels)
                c.mirror = PsychImaging('OpenWindow',screenNumber, c.color.background, c.mirrorPixels);
            end
        end
    end
    
    methods
        function report(c)
            subplot(2,2,1)
            x = c.profile.BEFOREFRAME;
            low = 5;high=95;
            bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            hist(1000*x,bins)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'BeforeFrame'
            
            subplot(2,2,2)
            x = c.profile.AFTERFRAME;
            bins = 1000*linspace(prctile(x,low),prctile(x,high),20);
            hist(1000*x,bins)
            xlabel 'Time (ms)'
            ylabel '#'
            title 'AfterFrame'
            
            
        end
        function addProfile(c,what,duration)
            c.profile.(what) = [c.profile .(what) duration];
        end
    end
    
end