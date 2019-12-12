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
    % Use with non LUM color modes and VPIXX requires a modified dispatchCallback
    % that is in the tools directory (neurostimEyelinkDispatchCallback.). 
    % Use o.overlay =  true to draw text (white) and the calibration targets to
    % the VPIXX overlay (using index colors that you define in
    % c.screen.overlayClut) and the eye image to the main window (which can
    % be M16 mode. If the eye image is very dim, use e.boostEyeImage to
    % boost its luminance  - a factor of 5 works well. 
    % Settting o.overlay to false will draw everything to the VPIXX main
    % window. The boostEyeImage factor will then scale the luminance of
    % calibration targets and text as well.
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
        el; %@struct;  % Information structure to communicate with Eyelink host
        commands = {'link_sample_data = GAZE'};
        edfFile = 'test.edf';
        getSamples =true;
        getEvents =false;
        nTransferAttempts = 5;
        
        callbackFun = 'PsychEyelinkDispatchCallback'; % The regular PTB version works fine for RGB displays
        boostEyeImage = 0;  % Factor by which to boost the eye image on a LUM calibrated display. [Default 0 means not boosted. Try values above 1.]         
        targetWindow;       % If an overlay is present, calibration targets can be drawn to it. This will be set automatically.
        
        doTrackerSetup = true;  % Do it before the next trial
        doDriftCorrect = false;  % Do it before the next trial
    
      
    end
        
    properties (Dependent)
        isRecording;
        isConnected; %double
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
            o.addProperty('F9PassThrough',true); % simulate F9 press on Eyelink host to do quick drift correct
            o.addProperty('transferFile',true); % afterExperiment - transfer file from the Host to here. (Only set to false in debugging to speed things  up)
        end
        
        function beforeExperiment(o)
            %Initalise default Eyelink el structure and set some values.
            % first call it with the mainWindow
            
            
            o.el=EyelinkInitDefaults(o.cic.mainWindow);
            setParms(o);            
            
            if o.overlay
                % Draw targets and text on the overlay, but the main window
                % has to be the mainWindow, because the callback calls flip
                % on it.   Note that this only works if the callback is sset to 
                % use neurostimEyelinkDispatchCallback, which is located i
                % neurostim/tools
                o.targetWindow = o.cic.overlayWindow; % Used by neurostim modified callback function only
                % Normally cic sets o.window to overlayWindow when o.overlay == true. Reset back
                o.window        = o.cic.mainWindow; %Used by PTB callback and by neurostim modified
            else
                o.targetWindow = o.window; % Everything goes to the main window
            end
                
            if ~isempty(o.host)  &&  Eyelink('IsConnected')==0
                Eyelink('SetAddress',o.host);
            end
            %Initialise connection to Eyelink.            
            if ~o.useMouse
                result = Eyelink('Initialize', o.callbackFun);
            else
                result = Eyelink('InitializeDummy', o.callbackFun);                            
            end
            
            if result ~=0
                o.cic.error('STOPEXPERIMENT','Eyelink failed to initialize');
                return;
            end
            
            o.el.TERMINATE_KEY = o.el.ESC_KEY;  % quit using ESC
            
            
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
                if o.boostEyeImage>1
                    o.backgroundColor = o.backgroundColor./o.boostEyeImage;
                end
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
            o.el.callback  = o.callbackFun;
            o.el.hPlugin   = o; % Store a handle to the Eyelink plugin so that the callback handler functionc can use it
            o.el.window  = o.cic.mainWindow; % Always main window
            EyelinkUpdateDefaults(o.el); % Store as persistent variables in callbackFun
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
                    if o.boostEyeImage>1 && strcmpi(o.cic.screen.colorMode,'LUM') && ~isnan(o.cic.screen.calibration.ns.bias)
                        % Because Eyelink does not send calibrated
                        % luminance values in its eye image, it can look
                        % very dim on a calibrated display. We hack that
                        % here by just boosting the gain of the extended gamma temporarily.
                        
                        % out = bias + gain * ((lum-minLum)./(maxLum-minLum)) ^1./gamma )                      
                        PsychColorCorrection('SetExtendedGammaParameters', o.window, o.cic.screen.calibration.ns.min, o.cic.screen.calibration.ns.max/o.boostEyeImage,o.cic.screen.calibration.ns.gain,o.cic.screen.calibration.ns.bias);                        
                    end
                    EyelinkDoTrackerSetup(o.el);
                    if o.boostEyeImage>1 && strcmpi(o.cic.screen.colorMode,'LUM') && ~isnan(o.cic.screen.calibration.ns.bias)
                        % Restore originalm, calibrated settings
                        PsychColorCorrection('SetExtendedGammaParameters', o.window, o.cic.screen.calibration.ns.min, o.cic.screen.calibration.ns.max, o.cic.screen.calibration.ns.gain ,o.cic.screen.calibration.ns.bias);
                    end                        
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
            
%             if ~o.isRecording
%                 o.cic.error('STOPEXPERIMENT','Eyelink is not recording...');
%                 return;
%             end
            
            if o.getSamples
                % Continuous samples requested               
                  % get the sample in the form of an event structure
                  sample = Eyelink( 'NewestFloatSample');                    
                  if ~isstruct(sample) 
                      % No sample or other error, just continue to next
                      % frame 
                  else
                    % convert to physical coordinates
                    eyeNr = str2eye(o,o.eye);
                    [o.x,o.y] = o.cic.pixel2Physical(sample.gx(eyeNr+1),sample.gy(eyeNr+1));    % +1 as accessing MATLAB array
                    o.pupilSize = sample.pa(eyeNr+1);
                    o.valid  = any(sample.gx(eyeNr+1)~=o.el.MISSING_DATA); % Blink or other missing data.                                                           
                  end
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
                        % �online_dcorr_trigger� is in the final.ini), then
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
    
  
    
end