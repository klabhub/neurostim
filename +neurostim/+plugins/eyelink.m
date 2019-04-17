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
        
        function rc = dispatchCallback(o,args, msg)
            % Adapted from PsychEyelinkDispatchCallback - The host computer
            % calls this with various arguments (callArgs) and those then get
            % passed to plugin member functions for actual drawing to the
            % screen.
            
            % TODO
            % replace persistent with object vars
            % Set this up directly without EyelinkInitDefaults
            
            % BK April 2019
            
            if nargin < 2
                msg = [];                
            end            
            if numel(args)~=4
                error('Incorrect arguments to the Eyelink callback');
            end
            eyeCmd = args(1);
            
            
            
            
            
            o.inEyeDisplay=0; % Seton setup call
            
            
            
            % Flag that tells if a new camera image was received and our camera image texture needs update:
            newCamImage = 0;
            needsUpdate = 1;
            
            switch eyeCmd
                case 1
                    % New videoframe received. See code below for actual processing.
                    newCamImage = 1;
                case 2
                    % Eyelink Keyboard query:
                    [rc, o.el] = EyelinkGetKey(o.el);
                    needsUpdate = 0;
                case 3
                    % Alert message:
                    o.writeToFeed(sprintf('Eyelink Alert: %s.\n', msg));
                    needsUpdate = 0;
                case 4
                    % Image title of camera image transmitted from Eyelink:
                    if args(2) ~= -1
                        o.title = sprintf('Camera: %s [Threshold = %f]', msg, args(2));
                    else
                        o.title = msg;
                    end
                case 5
                    % Define calibration target and enable its drawing:
                    calXY = args(2:3);
                    clearScreen=1;
                case 6
                    % Clear calibration display:
                    clearScreen=1;
                    drawInstructions=1;
                case 7
                    % Setup calibration display:
                    if o.inDrift
                        drawInstructions = 0;
                        o.inDrift = false;
                    else
                        drawInstructions = 1;
                    end
                    clearScreen=1;
                case 8
                    newCamImage = 1;
                    % Setup image display:
                    o.inEyeDisplay=1;
                    drawInstructions=1;
                case 9
                    % Exit image display:
                    clearScreen=1;
                    o.inEyeDisplay=0;
                    drawInstructions=1;
                case 10
                    % Erase current calibration target:
                    calXY = [];
                    clearScreen=1;
                case 11
                    clearScreen=1;
                case 12
                    % New calibration target sound:
                    makeSound(o,'cal_target_beep');
                    needsUpdate = 0;
                case 13
                    % New drift correction target sound:
                    makeSound(o, 'drift_correction_target_beep');
                    needsUpdate = 0;
                case 14
                    % Calibration done sound:
                    errc = args(2);
                    if errc > 0
                        % Calibration failed:
                        makeSound(o, 'calibration_failed_beep');
                    else
                        % Calibration success:
                        makeSound(o, 'calibration_success_beep');
                    end
                    needsUpdate = 0;
                case 15
                    % Drift correction done sound:
                    errc = args(2);
                    if errc > 0
                        % Drift correction failed:
                        makeSound(o, 'drift_correction_failed_beep');
                    else
                        % Drift correction success:
                        makeSound(o, 'drift_correction_success_beep');
                    end
                    needsUpdate = 0;
                case 16
                    [width, height]=Screen('WindowSize', o.window);
                    % get mouse
                    [x,y, buttons] = GetMouse(o.window);
                    
                    HideCursor
                    if find(buttons)
                        rc = [width , height, x , y,  dw , dh , 1];
                    else
                        rc = [width , height, x , y , dw , dh , 0];
                    end
                    needsUpdate = 0;
                case 17
                    o.inDrift =1;
                    needsUpdate = 0;
                otherwise
                    % Unknown command:
                    o.writeToFeed(sprintf('Eyelink callback: Unknown eyelink command (%i)\n', eyeCmd));
                    needsUpdate = 0;
            end
            
            if ~needsUpdate
                % Nope. Return from callback:
                return;
            end
            
            % Need to rebuild/redraw and flip the display:
            % need to clear screen?
            if clearScreen==1
                Screen('FillRect', o.window, o.backgroundColor);
            end
            % New video data from eyelink?
            if newCamImage
                % Video callback from Eyelink: We have a 'eyewidth' by 'eyeheight' pixels
                % live eye image from the Eyelink system. Each pixel is encoded as a 4 byte
                % RGBA pixel with alpha channel set to a constant value of 255 and the RGB
                % channels encoding a 1-Byte per channel R, G or B color value. The
                % given 'eyeimgptr' is a specially encoded memory pointer to the memory
                % buffer inside Eyelink() that encodes the image.
                ptr = args(2);
                imWidth  = args(3);
                imHeight = args(4);
                
                % Create a new PTB texture of proper format and size and inject the 4
                % channel RGBA color image from the Eyelink memory buffer into the texture.
                % Return a standard PTB texture handle to it. If such a texture already
                % exists from a previous invocation of this routiene, just recycle it for
                % slightly higher efficiency:
                
                GL_RGBA = 6408;
                GL_RGBA8 = 32856;
                GL_UNSIGNED_INT_8_8_8_8_REV = 33639;
                hostDataFormat = GL_UNSIGNED_INT_8_8_8_8_REV;
                o.eyeImageTexture = Screen('SetOpenGLTextureFromMemPointer', o.window,  o.eyeImageTexture, ptr, imWidth, imHeight, 4, 0, [], GL_RGBA8, GL_RGBA, hostDataFormat);
            end
            
            % If we're in imagemodedisplay, draw eye camera image texture centered in
            % window, if any such texture exists, also draw title if it exists.
            if ~isempty(eyeImageTexture) && o.inEyeDisplay==1
                o.drawCameraImage;
            end
            
            % Draw calibration target, if any is specified:
            if ~isempty(calXY)
                drawInstructions=0;
                o.drawCalibrationTarget(calXY);
            end
            
            % Need to draw instructions?
            if drawInstructions==1
                 o.cic.drawFormattedText(msg)
            end
            
            Screen('Flip', o.window, [], 1, 1); %Immediate flip,no clear.
            
            
        end
        
        
        function  drawCameraImage(o)
            try
                if ~isempty(o.eyeImageTexture)
                    eyerect=Screen('Rect', o.eyeImageTexture);
                    wrect=Screen('Rect', o.window);
                    [width, ~]=Screen('WindowSize', o.window);
                    dw=round(o.el.eyeimgsize/100*width);
                    dh=round(dw * eyerect(4)/eyerect(3));
                    
                    drect=[ 0 0 dw dh ];
                    drect=CenterRect(drect, wrect);
                    Screen('DrawTexture', o.window, o.eyeImageTexture, [], drect);
                end
                % imgtitle
               
                % if title is provided, we also draw title
               
            catch %myerr
                o.writeToFeed('EyelinkDrawCameraImage:error \n');         
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
        
        
        
        function drawCalibrationTarget(o,calxy)
            outerRect = [];
            innerRect = [];
            Screen('FillOval', o.window, o.clbTargetColor, outerRect);
            Screen('FillOval', o.window, o.backgroundColor, innerRect);
        end
        
        
    end
    
end