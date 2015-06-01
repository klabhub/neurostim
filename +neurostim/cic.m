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


classdef cic < dynamicprops
    
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
        position@double         = [];    % Window coordinates.[left top width height]
        mirrorPosition@double   = []; % Window coordinates.[left top width height].
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
        condition;  % Current condition
        trial;      % Current trial
        frame;      % Current frame
        name = 'cic'; %
        cursorVisible           = false; % Set it through c.cursor =
        
        %% Internal lists to keep track of stimuli, conditions, and blocks.
        stimuli;    % Cell array of char with stimulus names.
        conditions; % Map of conditions to parameter specs.
        blocks;     % Struct array with .nrRepeats .randomization .conditions
        plugins;    % Cell array of char with names of plugins.
        
        
        %% Logging and Saving
        startTime@double    = 0; % The time when the experiment started running
        %data@sib;
        
        %% Profiling information.
        profile@struct =  struct('BEFORETRIAL',[],'AFTERTRIAL',[],'BEFOREFRAME',[],'AFTERFRAME',[]);
        
        %% Keyboard interaction
        keyStrokes          = []; % PTB numbers for each key that is handled.
        keyHelp             = {}; % Help info for key
        keyDeviceIndex      = []; % Use the first device by default
        keyHandlers         = {}; % Handles for the plugins that handle the keys.
        
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
            [x,y] = RectCenter(c.position);
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
            % Some very basic PTB settings that are enforced for all
            KbName('UnifyKeyNames'); % Same key names across OS.
            % c.cursor = 'none';
            
            % Initialize empty
            c.startTime     = now;
            c.stimuli       = {};
            c.conditions    = neurostim.map;
            c.plugins       = {};
            
            % Setup the keyboard handling
            c.keyStrokes = [];
            c.keyHelp  = {};
            % Keys handled by CIC
            addKeyStroke(c,KbName('q'),'Quit',c);
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
                    error('How did you get here?');
            end
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
        
        function add(c,o)
            % Add a plugin.
            if ~isa(o,'neurostim.plugin')
                error('Only plugin derived classes can be added to CIC');
            end
            if isprop(c,o.name)
                error(['This name (' o.name ') already exists in CIC.']);
            else
                h = c.addprop(o.name);
                c.(o.name) = o;
                h.SetObservable = false; % No events
            end
            
            % Add to the appropriate list
            if isa(o,'neurostim.stimulus')
                nm   = 'stimuli';
            else
                nm = 'plugins';
            end
            c.(nm) = cat(2,c.(nm),o.name);
            % Set a pointer to CIC in the plugin
            o.cic = c;
            
            
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
            unknownStimuli = ~ismember(stimNames,c.stimuli);
            if any(unknownStimuli)
                error(['These stimuli are unknown, add them first: ' specs(3*(find(unknownStimuli)-1)+1)]);
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
        
        % Select certain conditions to be part of a block.
        function addBlock(c,conditionNames,nrRepeats,randomization)
            
            block.nrRepeats = nrRepeats;
            block.randomization = randomization;
            conditionNames = strcat('^',conditionNames,'\d*');
            conditionNumbers = index(c.conditions,conditionNames);
            switch (randomization)
                case 'SEQUENTIAL'
                    block.conditions = repmat(conditionNumbers,[1 nrRepeats]);
                case 'RANDOMWITHREPLACEMENT'
                    block.conditions = repmat(conditionNumbers,[1 nrRepeats]);
                    block.conditions = block.conditions(randperm(numel(block.conditions)));
                case 'BLOCKRANDOMWITHREPLACEMENT'
                    block.conditions = zeros(1,0);
                    for i=1:nrRepeats
                        block.conditions = cat(2,block.conditions, conditionNumbers(randperm(numel(conditionNumbers))));
                    end
                otherwise
                    error(['This randomization mode is unknown: ' randomization ]);
            end
            c.blocks = cat(1,c.blocks,block);
        end
        
        
        
        function beforeTrial(c)
            
            % Assign values specified in the desing to each of the stimuli.
            specs = c.conditions(c.condition);
            nrParms = length(specs)/3;
            for p =1:nrParms
                stim  = c.(specs{3*(p-1)+1});
                varName = specs{3*(p-1)+2};
                value   = specs{3*(p-1)+3};
                stim.(varName) = value;
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
                disp(['Begin block ' num2str(blockNr)]);
                c.flags.block = true;
                for conditionNr = c.blocks(blockNr).conditions
            
                    c.condition = conditionNr;
                    c.trial = c.trial+1;
                    
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
                    notify(c,'BASEAFTERTRIAL');
                    notify(c,'AFTERTRIAL');
                    vbl=Screen('Flip', c.window,when,1-c.clear);
                    afterTrial(c);
                    if (c.PROFILE); addProfile(c,'AFTERTRIAL',toc);end
                end %conditions in block
                if ~c.flags.experiment;break;end
            end %blocks
            notify(c,'BASEAFTEREXPERIMENT');
            notify(c,'AFTEREXPERIMENT');
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
            if ismember(key,c.keyStrokes)
                error(['The ' key ' key is in use. You cannot add it again...']);
            else
                c.keyStrokes = cat(2,c.keyStrokes,key);
                c.keyHandlers{end+1}  = p;
                c.keyHelp{end+1} = keyHelp;
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
            if any(~ismember(key,c.keyStrokes))
                error(['The ' key(~ismember(key,c.keyStrokes)) ' key is not in use. You cannot remove it...']);
            else
                index = ismember(c.keyStrokes,key);
                c.keyStrokes(index) = [];
                c.keyHandlers(index)  = [];
                c.keyHelp(index) = [];
            end
        end
        
    end
    
    
    methods (Access=protected)
        
        %% Keyboard handling routines(protected). Basically light wrappers
        % around the PTB core functions
        function KbQueueCreate(c,device)
            if nargin>1
                c.keyDeviceIndex = device;
            end
            keyList = zeros(1,256);
            keyList(c.keyStrokes) = 1;
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
                    ix = unique(find(c.keyStrokes==k));% should be only one.
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
            c.window = PsychImaging('OpenWindow',screenNumber, c.color.background, c.position);
            
            switch upper(c.colorMode)
                case 'XYL'
                    PsychColorCorrection('SetSensorToPrimary', c.window, cal);
                case 'RGB'
                    
            end
            
            
            if ~isempty(c.mirrorPosition)
                c.mirror = PsychImaging('OpenWindow',screenNumber, c.color.background, c.mirrorPosition);
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