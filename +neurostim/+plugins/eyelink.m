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
        end
        
        function beforeExperiment(o)
            
            %Initalise default Eyelink el structure and set some values.
            % first call it with the mainWindow
            o.el=EyelinkInitDefaults(o.cic.mainWindow);
            % Careful, Eyelink toolbox uses British spelling...
            if isempty(o.backgroundColor)
                % If the user did not set the background for the eyelink
                % then use screen background
                o.backgroundColor = o.cic.screen.color.background;
            end
            if isempty(o.clbTargetColor)
                % If the user did not set the calibration target color 
                % then make it maximally different from the background (5%)
                o.clbTargetColor = max(o.backgroundColor)-0.95*o.backgroundColor;
            end
            if isempty(o.foregroundColor)
                o.foregroundColor = o.cic.screen.color.text;
            end
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
            
            if ~isempty(o.host)  &&  Eyelink('IsConnected')==0
                Eyelink('SetAddress',o.host);
            end
            %Initialise connection to Eyelink.
            if ~o.useMouse
                result = Eyelink('Initialize', 'PsychEyelinkDispatchCallback');
            else
                result =0;
            end
            
            if result ~=0
                o.cic.error('STOPEXPERIMENT','Eyelink failed to initialize');
                return;
            end
            
            o.el.TERMINATE_KEY = o.el.ESC_KEY;  % quit using ESC
            
            % Tell eyelink about the o.el properties we just set.
            PsychEyelinkDispatchCallback(o.el);
            
            %Tell Eyelink about the pixel coordinates
            rect=Screen(o.window,'Rect');
            Eyelink('Command', 'screen_pixel_coords = %d %d %d %d',rect(1),rect(2),rect(3)-1,rect(4)-1);
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
            
            Eyelink('Message','DISPLAY_COORDS %d %d %d %d',0, 0, o.cic.screen.xpixels,o.cic.screen.ypixels);
            Eyelink('Message','%s',['DISPLAY_SIZE ' num2str(o.cic.screen.width) ' ' num2str(o.cic.screen.height)]);
            Eyelink('Message','%s', ['FRAMERATE ' num2str(o.cic.screen.frameRate) ' Hz.']);
            
        end
        
        function afterExperiment(o)
            
            Eyelink('StopRecording');
            Eyelink('CloseFile'); pause(0.1);
            try
                newFileName = [o.cic.fullFile '.edf'];
                for i=1:o.nTransferAttempts
                    writeToFeed(o,'Attempting to receive Eyelink edf file');
                    
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
            Eyelink('Shutdown');
        end
        
        function beforeTrial(o)
            
            if ~o.useMouse && (o.doTrackerSetup || o.doDriftCorrect)
                % Prepare for Eyelink drawing.
                
                % The Eyelink toolbox draws its targets in pixels. Undo any
                % transformations.
                Screen('glPushMatrix',o.cic.window);
                Screen('glLoadIdentity',o.cic.window);
                
                % Do setup or drift correct
                if o.doTrackerSetup
                    EyelinkDoTrackerSetup(o.el);
                elseif o.doDriftCorrect
                    EyelinkDoDriftCorrect(o.el); % Using default center of screen.
                end
                Screen('glPopMatrix',o.cic.window); % restore neurostim transformations
                o.doTrackerSetup = false;
                o.doDriftCorrect = false; % done for now
                EyelinkClearCalDisplay(o.el);
                % Eyelink clears the screen with fillrect which changes the
                % background color. Change it back.
                Screen('FillRect', o.cic.window, o.cic.screen.color.background);
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
                    % Do a manual drift correction right now
                    Eyelink('StopRecording');
                    [tx,ty ] = o.cic.physical2Pixel(0,0);
                    draw = 0; % Assume NS has drawn a dot
                    allowSetup  = 0; % If it fails it fails..(we coudl be in the middle of a trial; dont want to mess up the flow)
                    EyelinkDoDriftCorrect(o.el,tx,ty,draw, allowSetup);
                    Eyelink('StartRecording');
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