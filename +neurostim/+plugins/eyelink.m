% Wrapper around the Eyelink Toolbox.
classdef eyelink < neurostim.plugins.eyetracker
    %
    % Plugin to interact with the Eyelink eyetracker.
    %
    % Set c.eye.clbTargetSize (in your space units) and c.eye.clbTargetColor
    % in the color units that you chose with cic.screen.colorMode) to define
    % the size and color of the calbriation targets. If you want a different color background
    % than the main cic.screen.color.background during calibration
    % then set c.eye.backgroundColor.
    %
    % Use with non RGB color modes.
    %
    % Eyelink toolbox can only draw to the main window, this complicates
    % working with VPIxx and similar devices.
    % All drawing of graphics (calibration donut, the camera image) uses
    % commands that are processed by the PTB pipeline. Therefore, if you
    % are in LUM mode (i.e. a single number specifies the gray scale
    % luminance of the pixel), you should specify eye.backroundColor etc in the same
    % format.
    % Text, however, is problematic as it does not appear to go through the
    % pipeline (not an Eyelink specific issue), and becuase you cannot tell
    % Eylink to write text to an overlay, you cannot use an overlay's
    % indices either. I have not found a solution to this, and have just
    % accepted for now that the text will appear black/dark grey in VPIXX  M16
    % mode (BK - Oct 2018). Usually not critical anyway.
    %
    %
    % Properties
    %   getSamples - if true, stores eye position/sample validity on every frame.
    %   getEvents - if true, stores eye event data in eyeEvts.
    %   eyeEvts - saves eyelink data in its original structure format.
    %
    %   doTrackerSetup - [true]: do tracker setup before next trial.
    %   doDriftCorrect - [false]: do drift correction on next trial
    %
    % Commands:
    % You can execute an arbitrary set of Eyelink commands by specifying
    % them in the .commands field. For instance, to define your own
    % (random?) calibration routine:
    %
    % xy = rand(9,2);
    % c.eye.commands = {'generate_default_targets = NO',...
    %                   'calibration_samples = 9',...
    %                   'calibration_sequence = 0,1,2,3,4,5,6,7,8',...
    %                   ['calibration_targets =' xy ],...
    %                   'validation_samples = 9',...
    %                   'validation_sequence = 0,1,2,3,4,5,6,7,8',...
    %                   ['validation_targets =' xy]};
    %
    % The Commands cell array is also the way to change what is sent along
    % the TCP link from eyelink to neurostim or to change other Eyelink
    % settings.
    %
    % Interactive Keys:
    %       F8: Do tracker setup before the next trial starts.
    %       F9: Start a drift correction immediately (assume the subject is
    %       fixating (0,0). Confirm correct fixation by pressing the space
    %       bar, or press Esc to abort drift correction and continue.
    %       By setting F9PassThrough to true, the confirmation is skipped
    %       (i.e. it mimics the use of F9 on the Host keyboard - an
    %       immediate drift correct, as long as the correction is smaller
    %       than the setting final.ini.
    %
    %       F10: Start drift correction before the next trial. (Eyelink
    %       will draw a target).
    %
    % See demos/gazeContingent
    %
    % TK, BK,  2016,2017
    properties
        el@struct;  % Information structure to communicate with Eyelink host
        commands = {'link_sample_data = GAZE'};
        edfFile@char = 'test.edf';
        getSamples@logical=true;
        getEvents@logical=false;
        nTransferAttempts = 5;
    end
    
    properties
        doTrackerSetup@logical  = true;  % Do it before the next trial
        doDriftCorrect@logical  = false;  % Do it before the next trial
    end
    
    properties (Dependent)
        isRecording@logical;
        isConnected@double;
    end
    
    methods
        function v = get.isRecording(~)
            v =Eyelink('CheckRecording');%returns 0 if connected.
            v = v==0;
        end
        
        function v = get.isConnected(~)
            % Can return el.dummyconnected too
            v = Eyelink('isconnected');
        end
    end
    
    
    methods
        function o = eyelink(c)
            assert(exist('Eyelink.m','file')==2,'The Eyelink toolbox is not available?'); % Check that the EyelinkToolBox is available.
            o = o@neurostim.plugins.eyetracker(c);
            o.addKey('F8','EyelinkSetup');
            o.addKey('F9','QuickDriftCorrect');
            o.addKey('F10','FullDriftCorrect');
            
            o.addProperty('eyeEvts',struct);
            o.addProperty('clbTargetInnerSize',[]); %Inner circle of annulus
            o.addProperty('clbType','HV9');
            o.addProperty('host','');
            o.addProperty('F9PassThrough',false); % simulate F9 press on Eyelink host to do quick drift correct
            o.addProperty('transferFile',true); % afterExperiment - transfer file from the Host to here. (Only set to false in debugging to speed things  up)
        end
        
        function beforeExperiment(o)
            %Initalise default Eyelink el structure and set some values.
            % first call it with the mainWindow
            
            
            o.el=EyelinkInitDefaults(o.cic.mainWindow);
            setParms(o);
            
            
            if ~isempty(o.host)  &&  Eyelink('IsConnected')==0
                Eyelink('SetAddress',o.host);
            end
            %Initialise connection to Eyelink.
            if ~o.useMouse
                result = Eyelink('Initialize', 'PsychEyelinkDispatchCallback');
            else
                result = Eyelink('InitializeDummy', 'PsychEyelinkDispatchCallback');
                %result =0;
            end
            
            if result ~=0
                o.cic.error('STOPEXPERIMENT','Eyelink failed to initialize');
                return;
            end
            
            o.el.TERMINATE_KEY = o.el.ESC_KEY;  % quit using ESC
            
            % Tell eyelink about the o.el properties we just set.
            PsychEyelinkDispatchCallback(o.el);
            
            %Tell Eyelink about the pixel coordinates
            Eyelink('Command', 'screen_pixel_coords = %d %d %d %d',o.cic.screen.xorigin,o.cic.screen.yorigin,o.cic.screen.xorigin+o.cic.screen.xpixels,o.cic.screen.yorigin + o.cic.screen.ypixels);
            Eyelink('Command', 'calibration_type = %s',o.clbType);
            Eyelink('command', 'sample_rate = %d',o.sampleRate);
            
            
            % open file to record data to (will be renamed on copy)
            [~,tmpFile] = fileparts(tempname);
            o.edfFile= [tmpFile(end-7:end) '.edf']; %8 character limit
            Eyelink('Openfile', o.edfFile);
            
            switch upper(o.eye)
                case 'LEFT'
                    Eyelink('Command','binocular_enabled=NO');
                    Eyelink('Command','active_eye=LEFT');
                    Eyelink('Message','%s', 'EYE_USED 0');
                case 'RIGHT'
                    Eyelink('Command','binocular_enabled=NO');
                    Eyelink('Command','active_eye=RIGHT');
                    Eyelink('Message','%s', 'EYE_USED 1');
                case {'BOTH','BINOCULAR'}
                    Eyelink('Command','binocular_enabled=YES');
                    Eyelink('Command','active_eye=LEFT,RIGHT');
                    Eyelink('Message','%s', 'EYE_USED 2');
            end
            
            %Pass all commands to Eyelink
            for i=1:length(o.commands)
                result = Eyelink('Command', o.commands{i});
                if result ~=0
                    writeToFeed(o,['Eyelink Command: ' o.commands{i} ' failed!']);
                end
            end
            
            Eyelink('Command','add_file_preamble_text',['RECORDED BY ' o.cic.experiment]);
            Eyelink('Command','add_file_preamble_text',['NEUROSTIM FILE ' o.cic.fullFile]);
            
            Eyelink('Message','DISPLAY_COORDS %d %d %d %d',o.cic.screen.xorigin, o.cic.screen.yorigin, o.cic.screen.xpixels,o.cic.screen.ypixels);
            Eyelink('Message','%s',['DISPLAY_SIZE ' num2str(o.cic.screen.width) ' ' num2str(o.cic.screen.height)]);
            Eyelink('Message','%s', ['FRAMERATE ' num2str(o.cic.screen.frameRate) ' Hz.']);
            
        end
        
        
        function setParms(o)
            % Careful, Eyelink toolbox uses British spelling...
            if isempty(o.backgroundColor)
                % If the user did not set the background for the eyelink
                % then use screen background
                o.backgroundColor = o.cic.screen.color.background;
            end
            if isempty(o.clbTargetColor)
                % If the user did not set the calibration target color
                % then set it to red
                o.clbTargetColor = [1 0 0];
            end
            if isempty(o.foregroundColor)
                o.foregroundColor = [1 1 1];
            end
            
            % Push to el struct
            o.el.backgroundcolour  = o.backgroundColor;
            o.el.foregroundcolour  = o.foregroundColor;
            o.el.msgfontcolour = o.foregroundColor;
            o.el.imgtitlecolour = o.foregroundColor;
            o.el.calibrationtargetcolour = o.clbTargetColor;
            
            o.el.calibrationtargetsize = o.clbTargetSize/o.cic.screen.width*100; %Eyelink sizes are percentages of screen
            if isempty(o.clbTargetInnerSize)
                o.el.calibrationtargetwidth = o.clbTargetSize/2/o.cic.screen.width*100; %default to half radius
            else
                o.el.calibrationtargetwidth = o.clbTargetInnerSize/o.cic.screen.width*100;
            end
            
            o.el.callback = @o.dispatchCallback;
            dispatchCallback(o,o.el);
        end
        
        function afterExperiment(o)
            
            o.cic.drawFormattedText('Transfering data from Eyelink host, please wait.','ShowNow',true);
            Eyelink('StopRecording');
            Eyelink('CloseFile');
            pause(0.1);
            if o.transferFile
                try
                    newFileName = [o.cic.fullFile '.edf'];
                    for i=1:o.nTransferAttempts
                        status=Eyelink('ReceiveFile',o.edfFile,newFileName); %change to OUTPUT dir
                        if status>0
                            o.edfFile = newFileName;
                            writeToFeed(o,['Success: transferred ' num2str(status) ' bytes']);
                            break
                        else
                            o.nTransferAttempts = o.nTransferAttempts - 1;
                            writeToFeed(o,['Fail: EDF file (' o.edfFile ')  did not transfer ' num2str(status)]);
                            writeToFeed(o,['Retrying. ' num2str(o.nTransferAttempts) ' attempts remaining.']);
                        end
                    end
                catch
                    error(horzcat('Eyelink file transfer failed. Saved on Eyelink PC as ',o.edfFile));
                end
            end
            Eyelink('Shutdown');
        end
        
        function beforeTrial(o)
            
            if ~o.useMouse && (o.doTrackerSetup || o.doDriftCorrect)
                % Prepare for Eyelink drawing.
                % The Eyelink toolbox draws its targets in pixels. Undo any
                % transformations.
                Screen('glPushMatrix',o.window);
                Screen('glLoadIdentity',o.window);
                
                
                % Do setup or drift correct
                if o.doTrackerSetup
                    EyelinkDoTrackerSetup(o.el);
                elseif o.doDriftCorrect
                    EyelinkDoDriftCorrect(o.el); % Using default center of screen.
                end
                
                o.doTrackerSetup = false;
                o.doDriftCorrect = false; % done for now
                
                
                % Change back to CIC background
                Screen('FillRect', o.window, o.cic.screen.color.background);
                Screen('glPopMatrix',o.window); % restore neurostim transformations
                
                Screen('Flip',o.cic.mainWindow); % Back to the original window
            end
            
            
            if ~o.isRecording
                Eyelink('StartRecording');
                available = Eyelink('EyeAvailable'); % get eye that's tracked
                if available ==-1
                    % No eye
                    o.cic.error('STOPEXPERIMENT','eye not available')
                else
                    o.eye = eye2str(o,available);
                end
            end
            
            Eyelink('Command','record_status_message %s%s%s',o.cic.paradigm, '_TRIAL:',num2str(o.cic.trial));
            Eyelink('Message','%s',['TR:' num2str(o.cic.trial)]);   %will this be used to align clocks later?
            Eyelink('Message','TRIALID %d-%d',o.cic.condition,o.cic.trial);
            
            o.eyeClockTime = Eyelink('TrackerTime');
            %o.writeToFeed(num2str(o.eyeClockTime/100));
            
        end
        
        function afterFrame(o)
            
            if ~o.isRecording
                o.cic.error('STOPEXPERIMENT','Eyelink is not recording...');
                return;
            end
            
            if o.getSamples
                % Continuous samples requested
                if Eyelink('NewFloatSampleAvailable') > 0
                    % get the sample in the form of an event structure
                    sample = Eyelink( 'NewestFloatSample');
                    % convert to physical coordinates
                    eyeNr = str2eye(o,o.eye);
                    [o.x,o.y] = o.cic.pixel2Physical(sample.gx(eyeNr+1),sample.gy(eyeNr+1));    % +1 as accessing MATLAB array
                    o.pupilSize = sample.pa(eyeNr+1);
                    o.valid = o.x~=o.el.MISSING_DATA && o.y~=o.el.MISSING_DATA && o.pupilSize >0;
                end %
            end
            if o.getEvents
                % Only events requested
                switch  o.isConnected
                    case o.el.dummyconnected
                        % Use mousecoordinates, save everything as a
                        % endsacc event.
                        %                         [o.x,o.y] = o.mouseConnection(c);
                        eyeEvts = o.eyeEvts;
                        [eyeEvts.gx,eyeEvts.gy,eyeEvts.type] = deal(x,y,o.el.ENDSACC);
                        o.eyeEvts = eyeEvts;
                    case o.el.connected
                        evtype=Eyelink('getnextdatatype');
                        if any(ismember(evtype,[o.el.ENDSACC, o.el.ENDFIX, o.el.STARTBLINK,...
                                o.el.ENDBLINK,o.el.STARTSACC,o.el.STARTFIX,...
                                o.el.FIXUPDATE, o.el.INPUTEVENT,o.el.MESSAGEEVENT,...
                                o.el.BUTTONEVENT, o.el.STARTPARSE, o.el.ENDPARSE]))
                            o.eyeEvts = Eyelink('GetFloatData', evtype);
                        else
                            %                             o.cic.error('STOPEXPERIMENT','Eyelink is not connected');
                        end
                end
                % x and y
                
            end
        end
        
        % Add an eyelink command that will be executed before the
        % experiment starts. Passing an empty string resets the command
        % list.
        function command(o,commandStr)
            %Currently, only beforeExperiment commands are accepted
            if o.cic.trial>0
                o.cic.error('STOPEXPERIMENT','Eyelink commands are currently not permitted once the experiment has started.');
            end
            
            %Assign the command
            if isempty(commandStr)
                o.commands= {};
            else
                o.commands = cat(2,o.commands,{commandStr});
                if ~isempty(strfind(upper(commandStr),'LINK_SAMPLE_DATA')) %#ok<STREMP>
                    o.getSamples = true;
                elseif ~isempty(strfind(upper(commandStr),'LINK_EVENT_DATA')) %#ok<STREMP>
                    o.getEvents = true;
                end
            end
        end
        
        function keyboard(o,key,~)
            switch upper(key)
                case 'F9'
                    % Do a manual drift correction right now, by sending an
                    % F9 to Eyelink.
                    if o.F9PassThrough
                        % If the tracker has been setup to use F9 as the
                        % online drift correct button (i.e. key_function F9
                        % “online_dcorr_trigger” is in the final.ini), then
                        % just sending an F9 does an immediate drift
                        % correct without interfering with the operation on
                        % the stimulus end (i.e. here)
                        Eyelink('SendKeyButton', o.el.F9_KEY, 0, o.el.KB_PRESS );
                    else
                        % Slightly more involved drift correct. This
                        % happens immediately but because the experimenter
                        % has to confirm, this takes more time and can
                        % cause a small timing error in the current trial
                        % This is the default because it does not require a
                        % change on the Eyelink host computer.
                        Eyelink('StopRecording');
                        [tx,ty ] = o.cic.physical2Pixel(0,0);
                        draw = 0; % Assume NS has drawn a dot
                        allowSetup  = 0; % If it fails it fails..(we coudl be in the middle of a trial; dont want to mess up the flow)
                        EyelinkDoDriftCorrect(o.el,tx,ty,draw, allowSetup);
                        Eyelink('StartRecording');
                    end
                case 'F8'
                    % Do tracker setup before next trial
                    o.doTrackerSetup  = true;
                case 'F10'
                    % Do a drift correct with eyelink calibration target
                    % before next trial
                    o.doDriftCorrect = true;
            end
        end
        
        function str  = eye2str(o,eyeNr)
            % Convert an eyelink number to a string that identifies the eye
            % Matching with plugnis.eyetracker)
            eyes = {'LEFT','RIGHT','BOTH'};
            eyeNrs = [o.el.LEFT_EYE,o.el.RIGHT_EYE,o.el.BINOCULAR];
            str = eyes{eyeNr ==eyeNrs};
        end
        
        function nr = str2eye(o,eye)
            % Convert a string that identifies the eye
            %  to an eyelink number
            eyes = {'LEFT','RIGHT','BOTH','BINOCULAR'};
            eyeNrs = [o.el.LEFT_EYE,o.el.RIGHT_EYE,o.el.BINOCULAR,o.el.BINOCULAR];
            nr = eyeNrs(strcmpi(eye,eyes));
        end
        
        
        
    end
    
    methods
    
    %% Dispatch
    
    function rc = dispatchCallback(o,callArgs, msg)
    % Retrieve live eye-image from Eyelink, show it in onscreen window.
    %
    % This function is normally called from within the Eyelink() mex file.
    % Normal user code only calls it once to supply the eyelink defaults struct.
    % This is handled within the EyelinkInitDefaults.m file, so you generally
    % should not have to worry about this. However, if you change settings in
    % the el structure, you may need to call it yourself.
    %
    % To define which onscreen window the eye image should be
    % drawn to, call it with the return value from EyelinkInitDefaults, e.g.,
    % w=Screen('OpenWindow', ...);
    % el=EyelinkInitDefaults(w);
    % myEyelinkDispatchCallback(el);
    %
    %
    % to actually receive and display the images, register this function as eyelink's callback:
    % if Eyelink('Initialize', 'myEyelinkDispatchCallback') ~=0
    %   error('eyelink failed init')
    % end
    % result = Eyelink('StartSetup',1) %put the tracker into a mode capable of sending images
    % then you must hit 'return' on the PTB computer, this key command will be sent to the tracker host to initiate sending of images.
    %
    % This function fetches the most recent live image from the Eylink eye
    % camera and displays it in the previously assigned onscreen window.
    %
    % History:
    % 15.3.2009   Derived from MemoryBuffer2TextureDemo.m (MK).
    %  4.4.2009   Updated to use EyelinkGetKey + fixed eyelinktex persistence crash (edf).
    % 11.4.2009   Cleaned up. Should be ready for 1st release, although still
    %             pretty alpha quality. (MK).
    % 15.6.2010   Added some drawing routines to get standard behaviour back. Enabled
    %             use of the callback by default. Clarified in helptext that user
    %             normally should not have to worry about calling this file. (fwc)
    % 20.7.2010   drawing of instructions, eye-image+title, playing sounds in seperate functions
    %
    %  1.2.2010   modified to allow for cross hair and fix bugs. (nj)
    % 29.10.2018  Drop 'DrawDots' for calibration target. Some white-space fixes.
    
    
    disp ('Hi!')
    % Cached texture handle for eyelink texture:
    persistent eyelinktex;
    global dw dh offscreen;
    
    % Cached window handle for target onscreen window:
    persistent eyewin;
    persistent calxy;
    persistent imgtitle;
    persistent eyewidth;
    persistent eyeheight;
    
    % Cached(!) eyelink stucture containing keycodes
    persistent el;
    persistent lastImageTime; %#ok<PUSE>
    persistent drawcount;
    persistent ineyeimagemodedisplay;
    persistent clearScreen;
    persistent drawInstructions;
    
    % Cached constant definitions:
    persistent GL_RGBA;
    persistent GL_RGBA8;
    persistent hostDataFormat;
    
    persistent inDrift;
    offscreen = 0;
    newImage = 0;
    
    
    if 0 == Screen('WindowKind', eyelinktex)
        eyelinktex = []; % got persisted from a previous ptb window which has now been closed; needs to be recreated
    end
    if isempty(eyelinktex)
        % Define the two OpenGL constants we actually need. No point in
        % initializing the whole PTB OpenGL mode for just two constants:
        GL_RGBA = 6408;
        GL_RGBA8 = 32856;
        GL_UNSIGNED_BYTE = 5121; %#ok<NASGU>
        GL_UNSIGNED_INT_8_8_8_8 = 32821; %#ok<NASGU>
        GL_UNSIGNED_INT_8_8_8_8_REV = 33639;
        hostDataFormat = GL_UNSIGNED_INT_8_8_8_8_REV;
        drawcount = 0;
        lastImageTime = GetSecs;
    end
    
    % Preinit return code to zero:
    rc = 0;
    
    if nargin < 2
        msg = [];
    end
    
    if nargin < 1
        callArgs = [];
    end
    
    if isempty(callArgs)
        error('You must provide some valid "callArgs" variable as 1st argument!');
    end
    
    if ~isnumeric(callArgs) && ~isstruct(callArgs)
        error('"callArgs" argument must be a EyelinkInitDefaults struct or double vector!');
    end
    
    % Eyelink el struct provided?
    if isstruct(callArgs) && isfield(callArgs,'window')
        % Check if el.window subfield references a valid window:
        if Screen('WindowKind', callArgs.window) ~= 1
            %        error('argument didn''t contain a valid handle of an open onscreen window!  pass in result of EyelinkInitDefaults(previouslyOpenedPTBWindowPtr).');
        end
        
        % Ok, valid handle. Assign it and return:
        eyewin = callArgs.window;
        
        % Assume rest of el structure is valid:
        el = callArgs;
        clearScreen=1;
        eyelinktex=[];
        lastImageTime=GetSecs;
        ineyeimagemodedisplay=0;
        drawInstructions=1;
        return;
    end
    
    
    % Not an eyelink struct.  Either a 4 component vector from Eyelink(), or something wrong:
    if length(callArgs) ~= 4
        error('Invalid "callArgs" received from Eyelink() Not a 4 component double vector as expected!');
    end
    
    % Extract command code:
    eyecmd = callArgs(1);
    
    if isempty(eyewin)
        warning('Got called as callback function from Eyelink() but usercode has not set a valid target onscreen window handle yet! Aborted.'); %#ok<WNTAG>
        return;
    end
    
    % Flag that tells if a new camera image was received and our camera image texture needs update:
    newcamimage = 0;
    needsupdate = 0;
    
    switch eyecmd
        case 1,
            % New videoframe received. See code below for actual processing.
            newcamimage = 1;
            needsupdate = 1;
        case 2,
            % Eyelink Keyboard query:
            [rc, el] = EyelinkGetKey(el);
        case 3,
            % Alert message:
            fprintf('Eyelink Alert: %s.\n', msg);
            needsupdate = 1;
        case 4,
            % Image title of camera image transmitted from Eyelink:
            % fprintf('Eyelink image title is %s. [Threshold = %f]\n', msg, callArgs(2));
            if callArgs(2) ~= -1
                imgtitle = sprintf('Camera: %s [Threshold = %f]', msg, callArgs(2));
            else
                imgtitle = msg;
            end
            needsupdate = 1;
        case 5,
            % Define calibration target and enable its drawing:
            % fprintf('draw_cal_target.\n');
            calxy = callArgs(2:3);
            clearScreen=1;
            needsupdate = 1;
        case 6,
            % Clear calibration display:
            % fprintf('clear_cal_display.\n');
            clearScreen=1;
            drawInstructions=1;
            needsupdate = 1;
        case 7,
            % Setup calibration display:
            if inDrift
                drawInstructions = 0;
                inDrift = 0;
            else
                drawInstructions = 1;
            end
            
            clearScreen=1;
            % drawInstructions=1;
            drawcount = 0;
            lastImageTime = GetSecs;
            needsupdate = 1;
        case 8,
            newImage = 1;
            % Setup image display:
            eyewidth  = callArgs(2);
            eyeheight = callArgs(3);
            % fprintf('setup_image_display for %i x %i pixels.\n', eyewidth, eyeheight);
            drawcount = 0;
            lastImageTime = GetSecs;
            ineyeimagemodedisplay=1;
            drawInstructions=1;
            needsupdate = 1;
        case 9,
            % Exit image display:
            %         fprintf('exit_image_display.\n');
            %         fprintf('AVG FPS = %f Hz\n', drawcount / (GetSecs - lastImageTime));
            clearScreen=1;
            ineyeimagemodedisplay=0;
            drawInstructions=1;
            needsupdate = 1;
        case 10,
            % Erase current calibration target:
            %         fprintf('erase_cal_target.\n');
            calxy = [];
            clearScreen=1;
            needsupdate = 1;
        case 11,
            %               fprintf('exit_cal_display.\n');
            %         fprintf('AVG FPS = %f Hz\n', drawcount / (GetSecs - lastImageTime));
            clearScreen=1;
            %       drawInstructions=1;
            needsupdate = 1;
        case 12,
            % New calibration target sound:
            %         fprintf('cal_target_beep_hook.\n');
            EyelinkMakeSound(el, 'cal_target_beep');
        case 13,
            % New drift correction target sound:
            %         fprintf('dc_target_beep_hook.\n');
            EyelinkMakeSound(el, 'drift_correction_target_beep');
        case 14,
            % Calibration done sound:
            errc = callArgs(2);
            %         fprintf('cal_done_beep_hook: %i\n', errc);
            if errc > 0
                % Calibration failed:
                EyelinkMakeSound(el, 'calibration_failed_beep');
            else
                % Calibration success:
                EyelinkMakeSound(el, 'calibration_success_beep');
            end
        case 15,
            % Drift correction done sound:
            errc = callArgs(2);
            %         fprintf('dc_done_beep_hook: %i\n', errc);
            if errc > 0
                % Drift correction failed:
                EyelinkMakeSound(el, 'drift_correction_failed_beep');
            else
                % Drift correction success:
                EyelinkMakeSound(el, 'drift_correction_success_beep');
            end
            % add by NJ
        case 16,
            [width, height]=Screen('WindowSize', eyewin);
            % get mouse
            [x,y, buttons] = GetMouse(eyewin);
            
            HideCursor
            if find(buttons)
                rc = [width , height, x , y,  dw , dh , 1];
            else
                rc = [width , height, x , y , dw , dh , 0];
            end
            % add by NJ to prevent flashing of text in drift correct
        case 17,
            inDrift =1;
        otherwise
            % Unknown command:
            fprintf('PsychEyelinkDispatchCallback: Unknown eyelink command (%i)\n', eyecmd);
            return;
    end
    
    % Display redraw and update needed?
    if ~needsupdate
        % Nope. Return from callback:
        return;
    end
    
    % Need to rebuild/redraw and flip the display:
    % need to clear screen?
    if clearScreen==1
        Screen('FillRect', eyewin, el.backgroundcolour);
        clearScreen=0;
    end
    % New video data from eyelink?
    if newcamimage
        % Video callback from Eyelink: We have a 'eyewidth' by 'eyeheight' pixels
        % live eye image from the Eyelink system. Each pixel is encoded as a 4 byte
        % RGBA pixel with alpha channel set to a constant value of 255 and the RGB
        % channels encoding a 1-Byte per channel R, G or B color value. The
        % given 'eyeimgptr' is a specially encoded memory pointer to the memory
        % buffer inside Eyelink() that encodes the image.
        eyeimgptr = callArgs(2);
        eyewidth  = callArgs(3);
        eyeheight = callArgs(4);
        
        % Create a new PTB texture of proper format and size and inject the 4
        % channel RGBA color image from the Eyelink memory buffer into the texture.
        % Return a standard PTB texture handle to it. If such a texture already
        % exists from a previous invocation of this routiene, just recycle it for
        % slightly higher efficiency:
        eyelinktex = Screen('SetOpenGLTextureFromMemPointer', eyewin, eyelinktex, eyeimgptr, eyewidth, eyeheight, 4, 0, [], GL_RGBA8, GL_RGBA, hostDataFormat);
    end
    
    % If we're in imagemodedisplay, draw eye camera image texture centered in
    % window, if any such texture exists, also draw title if it exists.
    if ~isempty(eyelinktex) && ineyeimagemodedisplay==1
        imgtitle=o.EyelinkDrawCameraImage(eyewin, el, eyelinktex, imgtitle,newImage);
    end
    
    % Draw calibration target, if any is specified:
    if ~isempty(calxy)
        drawInstructions=0;
        o.EyelinkDrawCalibrationTarget(eyewin, el, calxy);
    end
    
    % Need to draw instructions?
    if drawInstructions==1
        o.EyelinkDrawInstructions(eyewin, el,msg);
        drawInstructions=0;
    end
    
    % Show it: We disable synchronization of Matlab to the vertical retrace.
    % This way, display update itself is still synced and tear-free, but we
    % don't waste time waiting for swap completion. Potentially higher
    % performance for calibration displays and eye camera image updates...
    % Neither do we erase buffer
    %Screen('Flip', eyewin, [], 1, 1);
    
    % Some counter, just to measure update rate:
    drawcount = drawcount + 1;
    
    end
    
    function drawInstructions(o,eyewin, el,msg)
    
    oldFont=Screen(eyewin,'TextFont',el.msgfont);
    oldFontSize=Screen(eyewin,'TextSize',el.msgfontsize);
    DrawFormattedText(eyewin, el.helptext, 20, 20, el.msgfontcolour, [], [], [], 1);
    
    if el.displayCalResults && ~isempty(msg)
        DrawFormattedText(eyewin, msg, 20, 150, el.msgfontcolour, [], [], [], 1);
    end
    
    Screen(eyewin,'TextFont',oldFont);
    Screen(eyewin,'TextSize',oldFontSize);
    end
    
    
    function  imgtitle=drawCameraImage(o,eyewin, el, eyelinktex, imgtitle,newImage)
    persistent lasttitle;
    global dh dw offscreen;
    try
        if ~isempty(eyelinktex)
            eyerect=Screen('Rect', eyelinktex);
            % we could cash some of the below values....
            wrect=Screen('Rect', eyewin);
            [width, heigth]=Screen('WindowSize', eyewin);
            dw=round(el.eyeimgsize/100*width);
            dh=round(dw * eyerect(4)/eyerect(3));
            
            drect=[ 0 0 dw dh ];
            drect=CenterRect(drect, wrect);
            Screen('DrawTexture', eyewin, eyelinktex, [], drect);
            %     fprintf('EyelinkDrawCameraImage:DrawTexture \n');
        end
        % imgtitle
        % if title is provided, we also draw title
        if ~isempty(eyelinktex) && exist( 'imgtitle', 'var') && ~isempty(imgtitle)
            %oldFont=Screen(eyewin,'TextFont',el.imgtitlefont);
            %oldFontSize=Screen('TextSize',eyewin,el.imgtitlefontsize);
            rect=Screen('TextBounds', eyewin, imgtitle );
            [w2, h2]=RectSize(rect);
            
            % added by NJ as a quick way to prevent over drawing and to clear text
            if newImage || isempty(lasttitle) || ~strcmp(imgtitle,lasttitle)
                if -1 == Screen('WindowKind', offscreen)
                    Screen('Close', offscreen);
                end
                
                sn = Screen('WindowScreenNumber', eyewin);
                offscreen = Screen('OpenOffscreenWindow', sn, el.backgroundcolour, [], [], 32);
                Screen(offscreen,'TextFont',el.imgtitlefont);
                Screen(offscreen,'TextSize',el.imgtitlefontsize);
                Screen('DrawText', offscreen, imgtitle, width/2-dw/2, heigth/2+dh/2+h2, el.imgtitlecolour);
                Screen('DrawTexture',eyewin,offscreen,  [width/2-dw/2 heigth/2+dh/2+h2 width/2-dw/2+500 heigth/2+dh/2+h2+500], [width/2-dw/2 heigth/2+dh/2+h2 width/2-dw/2+500 heigth/2+dh/2+h2+500]);
                Screen('Close',offscreen);
                newImage = 0;
            end
            %imgtitle=[]; % return empty title, so it doesn't get drawn over and over again.
            lasttitle = imgtitle;
        end
    catch %myerr
        fprintf('EyelinkDrawCameraImage:error \n');
        disp(psychlasterror);
    end
    end
    
    
    function makeSound(o,el, s)
    % set all sounds in one place, sound params defined in
    % eyelinkInitDefaults
    
    switch(s)
        case 'cal_target_beep'
            doBeep=el.targetbeep;
            f=el.cal_target_beep(1);
            v=el.cal_target_beep(2);
            d=el.cal_target_beep(3);
        case 'drift_correction_target_beep'
            doBeep=el.targetbeep;
            f=el.drift_correction_target_beep(1);
            v=el.drift_correction_target_beep(2);
            d=el.drift_correction_target_beep(3);
        case 'calibration_failed_beep'
            doBeep=el.feedbackbeep;
            f=el.calibration_failed_beep(1);
            v=el.calibration_failed_beep(2);
            d=el.calibration_failed_beep(3);
        case 'calibration_success_beep'
            doBeep=el.feedbackbeep;
            f=el.calibration_success_beep(1);
            v=el.calibration_success_beep(2);
            d=el.calibration_success_beep(3);
        case 'drift_correction_failed_beep'
            doBeep=el.feedbackbeep;
            f=el.drift_correction_failed_beep(1);
            v=el.drift_correction_failed_beep(2);
            d=el.drift_correction_failed_beep(3);
        case 'drift_correction_success_beep'
            doBeep=el.feedbackbeep;
            f=el.drift_correction_success_beep(1);
            v=el.drift_correction_success_beep(2);
            d=el.drift_correction_success_beep(3);
        otherwise
            % some defaults
            doBeep=el.feedbackbeep;
            f=500;
            v=0.5;
            d=1.5;
    end
    
    if doBeep==1
        Beeper(f, v, d);
    end
    end
    
    
    
    function drawCalibrationTarget(o,eyewin, el, calxy)
    [width, heigth]=Screen('WindowSize', eyewin);
    size=round(el.calibrationtargetsize/100*width);
    inset=round(el.calibrationtargetwidth/100*width);
    
    insetSize = size-2*inset;
    if insetSize < 1
        insetSize = 1;
    end
    
    % Use FillOval for larger dots:
    Screen('FillOval', eyewin, el.calibrationtargetcolour, [calxy(1)-size/2 calxy(2)-size/2 calxy(1)+size/2 calxy(2)+size/2], size+2);
    Screen('FillOval', eyewin, el.backgroundcolour, [calxy(1)-inset/2 calxy(2)-inset/2 calxy(1)+inset/2 calxy(2)+inset/2], inset+2);
    end
    

    end

end