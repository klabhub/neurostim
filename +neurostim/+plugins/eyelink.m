% Wrapper around the Eyelink Toolbox.
classdef eyelink < neurostim.plugins.eyetracker
    % new properties:
    % keepExperimentSetup - 1 or 0. 
    %                       1: keep Eyelink functions using the same colour
    %                       setup as the experiment (i.e. background, foreground).
    %                       0: get Eyelink colour setup from parameters
    %                       below. - still in progress.
    % backgroundColor - background colour for eyelink toolbox functions.
    % foregroundColor - foreground colour for eyelink toolbox functions.
    % clbTargetColor - calibration target color.
    
    properties
        el@struct;
        fakeConnection@logical = false;
        eye;
        commands = {'link_sample_data = LEFT,RIGHT,GAZE,AREA'};
        edfFile@char = 'test.edf';
        getSamples@logical=false;
        getEvents@logical=false;
        keepExperimentSetup = 1;
        backgroundColor;
        foregroundColor;
        clbTargetColor;
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
        function o = eyelink
            Eyelink; % Check that the EyelinkToolBox is available.
            o = o@neurostim.plugins.eyetracker;
            o.listenToKeyStroke('F9','DriftCorrect');
            o.listenToKeyStroke('F8','EyelinkSetup');
            o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','BEFORETRIAL','AFTERFRAME'}); %The parent class is also listening to the AFTERFRAME event. Intended?
            
        end
        
        function beforeExperiment(o,c,evt)
            o.el=EyelinkInitDefaults(o.cic.window);
            
            [result,dummy] = EyelinkInit(o.fakeConnection);
            if result~=1
                o.cic.error('STOPEXPERIMENT','Eyelink failed to initialize');
                ok = false;
                return;
            end
            if dummy
                o.fakeConnection = true; %Eyelink Toolbox offers user dummy connection if it fails to connect, so oblige.
            end
            
            % make sure that we get gaze data from the Eyelink
            for i=1:length(o.commands)
                Eyelink('Command', o.commands{i});
            end
            
            % open file to record data to
            [~,tmpFile] = fileparts(tempname);
            o.edfFile= [tmpFile(end-7:end) '.edf']; %8 character limit
            Eyelink('Openfile', o.edfFile);
            if o.keepExperimentSetup
                restoreExperimentSetup(o);
            else eyelinkSetup(o);
            end
        end
        
        function afterExperiment(o,c,evt)

            Eyelink('StopRecording');
            Eyelink('CloseFile');
            try
                status=Eyelink('ReceiveFile',o.edfFile,['c:\temp\' o.cic.file '.edf']); %change to OUTPUT dir
            catch
                error('Eyelink file failed to transfer to the NS computer');
            end
            Eyelink('Shutdown');
        end
        
        function beforeTrial(o,c,evt)

            % Do re-calibration if requested
            if o.doTrackerSetup && ~o.fakeConnection
                if ~o.keepExperimentSetup
                    eyelinkSetup(o);
                end
                EyelinkDoTrackerSetup(o.el); %Need to modify to allow ns to control the background RGB/lum CIE etc.
                o.doTrackerSetup = false;
            end
            if o.doDriftCorrect && ~o.fakeConnection
                if ~o.keepExperimentSetup
                    eyelinkSetup(o);
                end
                o.el.TERMINATE_KEY = o.el.ESC_KEY;
                EyelinkDoDriftCorrection(o.el);
                o.doDriftCorrect = false;
            end
            if ~o.isRecording
                available = Eyelink('EyeAvailable'); % get eye that's tracked
                if available == o.el.BINOCULAR
                    o.eye = o.el.LEFT_EYE;
                elseif o.eye ~=available
                    o.cic.error('STOPEXPERIMENT','eye not available')
                else
                    o.eye = available;
                end
                Eyelink('StartRecording');
            end
            
            Eyelink('Command','record_status_message %s%s%s',c.paradigm, '_TRIAL:',num2str(c.trial));
            Eyelink('Message','%s',['TR:' num2str(c.trial)]);   %will this be used to align clocks later?
            
            if ~o.keepExperimentSetup
                restoreExperimentSetup(o);
                EyelinkClearCalDisplay(o.el);
            end
        end
        
        function afterFrame(o,c,evt)

            if ~o.isRecording && ~o.fakeConnection
                o.cic.error('STOPEXPERIMENT','Eyelink is not recording...');
                return;
            end
            
            if o.getSamples
                % Continuous samples requested
                if Eyelink( 'NewFloatSampleAvailable') > 0
                    % get the sample in the form of an event structure
                    evt = Eyelink( 'NewestFloatSample');
                    o.x = evt.gx(o.eye+1); % +1 as we're accessing MATLAB array
                    o.y = evt.gy(o.eye+1);
                    o.size = evt.pa(o.eye+1);
                    o.valid = o.x~=o.el.MISSING_DATA && o.y~=o.el.MISSING_DATA && o.size >0;
                end %
            elseif o.getEvents
                % Only events requested
                switch  o.isConnected
                    case o.el.dummyconnected
                        % Use mousecoordinates
                        [x,y,button] = GetMouse(o.cic.window);
                        evt.type=o.el.ENDSACC;
                        evt.genx=x;
                        evt.geny=y;
                    case o.el.connected
                        evtype=Eyelink('getnextdatatype');
                        evt = Eyelink('getfloatdata', evtype);
                    otherwise
                        o.cic.error('STOPEXPERIMENT','Eyelink is not connected');
                end
                o.x = evt.genx;
                o.y = evt.geny;
            end
        end
        
        function events(o,src,evt)
            switch (evt.EventName)
                %Nothing to do?
                otherwise
                    error(['Unhandled event ' evt.EventName]);
            end
        end
        
        function keyboard(o,key,~)
            switch upper(key)
                case 'F9'
                    o.doDriftCorrect  =true;
                case 'F8'
                    o.doTrackerSetup  = true;
            end
        end
        
        % Add an eyelink command that will be executed before the
        % experiment starts. Passing an empty string resets the command
        % list.
        function command(o,string)
            if isempty(string)
                o.commands= {};
            else
                o.commands = cat(2,o.commands,{string});
                if ~isempty(strfind(upper(string),'LINK_SAMPLE_DATA'))
                    o.getSamples = true;
                elseif ~isempty(strfind(upper(string),'LINK_EVENT_DATA'))
                    o.getEvents = true;
                end
            end
        end
        
        function restoreExperimentSetup(o)
            % function restoreExperimentSetup(o)
            % restores the original experiment background/foreground
            % colours.
            o.el.backgroundcolour = o.cic.color.background;
            o.el.foregroundcolour = o.cic.color.text;
            o.el.calibrationtargetcolour = o.el.foregroundcolour;
            PsychEyelinkDispatchCallback(o.el);
        end
        
        function eyelinkSetup(o)
            % function eyelinkSetup(o)
            % sets up Eyelink functions with background/foreground colours
            % as specified.
            o.el.backgroundcolour = o.backgroundColor;
            o.el.foregroundcolour = o.foregroundColor;
            o.el.calibrationtargetcolour = o.clbTargetColor;
            PsychEyelinkDispatchCallback(o.el);

        end
    end
end