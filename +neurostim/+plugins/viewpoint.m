% Wrapper around the Eyelink Toolbox.
classdef viewpoint < neurostim.plugins.eyetracker
    % New properties:
    %   keepExperimentSetup - 1 or 0.
    %                         1: keep Eyelink functions using the same colour
    %                               setup as the experiment (i.e. background, foreground).
    %                         0: get Eyelink colour setup from parameters
    %                               below.
    %
    %   getSamples - if true, stores eye position/sample validity on every frame.
    %   getEvents - if true, stores eye event data in eyeEvts.
    %   eyeEvts - saves eyelink data in its original structure format.
    %
    %   doTrackerSetup - true or false, setup before experiment.
    %   doDriftCorrect - true or false, setup before experiment.
    
    
    properties
        vp@struct;
        eye='LEFT'; %LEFT,RIGHT, or BOTH
        valid;
        %eyelink commands commands = {'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,VELOCITY'};
        edfFile@char = 'test.edf';
        getSamples@logical=true;
        getEvents@logical=false;
    end
    
    properties
        doTrackerSetup@logical  = true;  % Do it before the next trial
        doDriftCorrect@logical  = false;  % Do it before the next trial
    end
    
    properties (Dependent)
        isRecording@logical;
        isConnected@double;
    end
    
    methods%needs attention
        function v = get.isRecording(~)
            %             v =Eyelink('CheckRecording');%returns 0 if connected.
            %             v = v==0;
            [v]=vpx_GetStatus(3) && ~vpx_GetStatus(4); %checks if viewpoint data file is open and data file is not paused
        end
        
        function v = get.isConnected(~)
            % Can return el.dummyconnected too
            %v = Eyelink('isconnected');
            [v]=vpx_GetStatus(1); %checks if viewpoint is running, returns 1 if running
        end
    end
    
    
    methods
        function o = viewpoint(c)
            assert(exist('ViewPoint_EyeTracker_Toolbox','file')==7,'The Viewpoint toolbox is not available?'); % Check that the ViewpointToolBox is available.
            
            o = o@neurostim.plugins.eyetracker(c);
            o.addKey('F9','DriftCorrect');
            o.addKey('F8','EyelinkSetup');
            
            o.addProperty('eyeEvts',struct);
            o.addProperty('clbTargetInnerSize',[]); %Inner circle of annulus
        end
        
        function beforeExperiment(o)
            if ~o.useMouse
                vpx_Initialize;
                %warning should be given in vpx_Initialize
            end
            
            
            %o.cic.mainWindow
            %                                                                                                                                                                                                                                                                                                                                                                       
            %Initalise default Viewpoint vp structure and set some values.
            % first call it with the mainWindow
            o.vp=ViewpointInitDefaults(o.cic.mainWindow);
            %give vp the screen number,width and height
            o.vp.ScrNum=o.cic.screen.number;
            o.vp.Pwidth=o.cic.screen.width;
            o.vp.Pheight=o.cic.screen.height;
            %
            %o.vp.window=Screen('OpenWindow',1);
            %
            o.vp.calibrationtargetcolour = o.clbTargetColor;
            o.vp.msgfontcolour = o.cic.screen.color.text;
            o.vp.calibrationtargetsize = o.clbTargetSize./o.cic.screen.width*100; %Eyelink sizes are percentages of screen
            if isempty(o.clbTargetInnerSize)
                o.vp.calibrationtargetwidth = o.clbTargetSize/2/o.cic.screen.width*100; %default to half radius
            else
                o.vp.calibrationtargetwidth = o.clbTargetInnerSize/o.cic.screen.width*100;
            end
            
            %Initialise connection to viewpoint toolbox

  
            
            %Tell Eyelink about the pixel coordinates
            %             rect=Screen(o.window,'Rect');
            %             Eyelink('Command', 'screen_pixel_coords = %d %d %d %d',rect(1),rect(2),rect(3)-1,rect(4)-1);
            
            
            % setup sample rate
            %             if any(o.sampleRate==[250, 500, 1000])
            %                 o.command(horzcat('sample_rate = ', num2str(o.sampleRate)))
            %             else
            %                 c.error('STOPEXPERIMENT','Requested eyelink sample rate is invalid');
            %             end
            %
            
            
            % open file to record data to (will be renamed on copy)
            [~,tmpFile] = fileparts(tempname);
            o.edfFile= [tmpFile(end-7:end) '.vpx']; %8 character limit
            %             Eyelink('Openfile', o.edfFile);
            vpx_SendCommandString( 'dataFile_UnPauseUponClose 0' ); % so that next date file starts paused

            x=sprintf('dataFile_NewName "C:\\Users\\andreww\\Documents\\MATLAB\\ViewPoint\\Data\\%s"',o.edfFile);
            vpx_SendCommandString('dataFile_Pause 1'); %pauses file
            vpx_SendCommandString('datafile_includeEvents 1');
            vpx_SendCommandString(x);
            
            switch upper(o.eye)
                case 'LEFT'
                    %                     Eyelink('Command','binocular_enabled=NO');
                    %                     Eyelink('Command','active_eye=LEFT');
                    %                     Eyelink('Message','%s', 'EYE_USED 0');
                    vpx_SendCommandString('dataFile_InsertString "EYE_USED 0 " ' );
                case 'RIGHT'
                    %                     Eyelink('Command','binocular_enabled=NO');
                    %                     Eyelink('Command','active_eye=RIGHT');
                    %                     Eyelink('Message','%s', 'EYE_USED 1');
                    vpx_SendCommandString('dataFile_InsertString "EYE_USED 1 " ' );
                case {'BOTH','BINOCULAR'}
                    %                     Eyelink('Command','binocular_enabled=YES');
                    %                     Eyelink('Command','active_eye=LEFT,RIGHT');
                    %                     Eyelink('Message','%s', 'EYE_USED 2');
                    vpx_SendCommandString('dataFile_InsertString "EYE_USED 2 " ' );
            end
            
            %             %Pass all commands to Eyelink
            %             for i=1:length(o.commands)
            %                result = Eyelink('Command', o.commands{i}); %TODO: handle results
            %             end
            
            %Can do later ch 19.19
                        if o.keepExperimentSetup
                            restoreExperimentSetup(o);
                        else
                            viewpointSetup(o);
                        end
            %
            %             Eyelink('Command','add_file_preamble_text',['RECORDED BY ' o.cic.experiment]);
            %             Eyelink('Command','add_file_preamble_text',['NEUROSTIM FILE ' o.cic.fullFile]);
            
            %             Eyelink('Message','DISPLAY_COORDS %d %d %d %d',0, 0, o.cic.screen.xpixels,o.cic.screen.ypixels);
            %             Eyelink('Message','%s',['DISPLAY_SIZE ' num2str(o.cic.screen.width) ' ' num2str(o.cic.screen.height)]);
            %             Eyelink('Message','%s', ['FRAMERATE ' num2str(o.cic.screen.frameRate) ' Hz.']);
            msg1=sprintf('dataFile_InsertString "DISPLAY_COORDS %d %d %d %d"',0, 0, o.cic.screen.xpixels,o.cic.screen.ypixels);
            msg2=sprintf('dataFile_InsertString "DISPLAY_SIZE %.2f %.2f"',o.cic.screen.width,o.cic.screen.height);
            msg3=sprintf('dataFile_InsertString "FRAMERATE %d Hz."',o.cic.screen.frameRate);
            vpx_SendCommandString(msg1)
            vpx_SendCommandString(msg2)
            vpx_SendCommandString(msg3)
            
        end
        
        function afterExperiment(o)
            
            vpx_SendCommandString('dataFile_Pause 1'); % pause recording ;  Eyelink('StopRecording');
            vpx_SendCommandString('DataFile_Close');%closes data File  ;    Eyelink('CloseFile');
%             try  %for viewpoint just say in 'beforeexperiment' where data
%                  %should be saved
%                 writeToFeed(o,'Attempting to receive Viewpoint edf file');
%                 newFileName = [o.cic.fullFile '.edf'];
%                 status=Eyelink('ReceiveFile',o.edfFile,newFileName); %change to OUTPUT dir
%                 if status>0
%                     o.edfFile = newFileName;
%                     writeToFeed(o,['Success: transferred ' num2str(status) ' bytes']);
%                 else
%                     writeToFeed(o,['Fail: EDF file did not transfer ' num2str(status)]);
%                 end
%             catch
%                 error(horzcat('Eyelink file transfer failed. Saved on Eyelink PC as ',o.edfFile));
%             end
            vpx_Unload; %Eyelink('Shutdown');
        end
        
        function beforeTrial(o)
            %o.trackedEye; %This doesn't currently do anything for Eyelink??
            %update trial number so that correct coordinate system is used
            %in Calibration.m
            o.vp.trialnum=o.cic.trial;
            
            % Do re-calibration if requested
            if o.doTrackerSetup && ~o.useMouse
                if ~o.keepExperimentSetup
                    viewpointSetup(o);
                end
                ViewpointDoTrackerSetup(o.vp); %Need to modify to allow ns to control the background RGB/lum CIE etc.
                o.doTrackerSetup = false;
                restoreExperimentSetup(o);
            end
            if o.doDriftCorrect && ~o.useMouse
                if ~o.keepExperimentSetup
                    viewpointSetup(o);
                end
                o.vp.TERMINATE_KEY = o.vp.ESC_KEY;  % quit using ESC
                ViewpointDoDriftCorrection(o.vp); %actually using slip correction ch 8.9 in User Guide
                o.doDriftCorrect = false;
                restoreExperimentSetup(o);
            end
            
            
            if ~o.isRecording
                vpx_SendCommandString('dataFile_Resume')  %Eyelink('StartRecording');
                %available = o.eye; % get eye that's tracked
%                 if available == o.el.BINOCULAR
%                     o.eye = o.el.LEFT_EYE;
%                 elseif available == -1
%                     %                     o.eye = available;
%                     %                     o.eye = o.el.LEFT_EYE;
%                     o.cic.error('STOPEXPERIMENT','eye not available')
%                 else
%                     o.eye = available;
%                 end
            end
            
            %Eyelink('Command','record_status_message %s%s%s',o.cic.paradigm, '_TRIAL:',num2str(o.cic.trial));
            
            vpx_SendCommandString(sprintf('dataFile_InsertString "TR: %d"',o.cic.trial));
            %Eyelink('Message','%s',['TR:' num2str(o.cic.trial)]);   %will this be used to align clocks later?
            
            vpx_SendCommandString(sprintf('dataFile_InsertString "TRIALID %d-%d"',o.cic.condition,o.cic.trial));
            %Eyelink('Message','TRIALID %d-%d',o.cic.condition,o.cic.trial);
            
            
            o.eyeClockTime = vpx_GetDataTime(0); %Eyelink('TrackerTime');
            
        end
        
        function afterFrame(o)
            
            if ~o.isRecording
                o.cic.error('STOPEXPERIMENT','Eyelink is not recording...');
                return;
            end
            
            if o.getSamples
                % Continuous samples requested
                %if Eyelink('NewFloatSampleAvailable') > 0
                    % get the sample in the form of an event structure
                    [xV,yV]=vpx_GetGazePoint();
                    o.x=xV;
                    o.y=yV;
                    %ViewToNeuro(o,xV,yV)
                   sprintf('xV:%.4f  yV:%.4f\n',xV,yV) 
                   sprintf('%.4f  %.4f\n',o.x,o.y)

                    o.pupilSize = vpx_GetPupilSize;
                    o.valid = isnumeric(o.x) && isnumeric(o.y) && o.pupilSize >0;
                %end %
            end
%             if o.getEvents    % viewpoint dcan save events to the data file or to a seprarate file but does not have these function
%                 % Only events requested
%                 switch  o.isConnected
%                     case o.el.connected
%                         evtype=Eyelink('getnextdatatype');
%                         if any(ismember(evtype,[o.el.ENDSACC, o.el.ENDFIX, o.el.STARTBLINK,...
%                                 o.el.ENDBLINK,o.el.STARTSACC,o.el.STARTFIX,...
%                                 o.el.FIXUPDATE, o.el.INPUTEVENT,o.el.MESSAGEEVENT,...
%                                 o.el.BUTTONEVENT, o.el.STARTPARSE, o.el.ENDPARSE]))
%                             o.eyeEvts = Eyelink('GetFloatData', evtype);
%                         else
%                             %                             o.cic.error('STOPEXPERIMENT','Eyelink is not connected');
%                         end
%                 end
%                 % x and y
%                 
%             end
        end
        

        
        function keyboard(o,key,~)
            switch upper(key)
                case 'F9'
                    o.doDriftCorrect  =true;
                case 'F8'
                    o.doTrackerSetup  = true;
            end
        end
        
    end
    
    methods (Access=protected)
        
        
        function restoreExperimentSetup(o)
            % function restoreExperimentSetup(o)
            % restores the original experiment background/foreground
            % colours.
            o.vp.backgroundcolour = o.cic.screen.color.background;
            o.vp.foregroundcolour = o.cic.screen.color.text;
            
            %PsychViewpointDispatchCallback(o.vp);
            ViewpointClearCalDisplay(o.vp);
            
        end
        
        function viewpointSetup(o)
            % function eyelinkSetup(o)
            % sets up Eyelink functions with background/foreground colours
            % as specified.
            o.vp.backgroundcolour = o.backgroundColor;
            o.vp.foregroundcolour = o.foregroundColor;
            %PsychViewpointDispatchCallback(o.vp);


        end


        function ViewToNeuro(o,xV,yV)
            
            o.x=xV*o.cic.screen.width-0.5*o.cic.screen.width;
            o.y=-1*o.cic.screen.height*(yV-0.5);
            
           
            
        end
    end
end