classdef camera < neurostim.plugin
    % Plugin to record video (with a webcam, ip cam, or other video
    % device that the Mathworks Image Acquisition Toolbox can control).
    % PROPERTIES
    % adaptorName - Name of the adaptor to acquire video. E.g. winvideo (Default),
    %               gige, matrox, etc. ( See imaqhelp videoinput)
    % deviceID  - ID Number of the device on the adaptor [1]
    % format   - Which format to use on the device. This is
    % device-specific, get a list of allowable modes by calling
    %           imaqhwinfo(adaptorName,deviceID); ['MJPG_1280x720']
    % framerate - Framerate of the video device. Usually only a subset
    %               of rates is allowed. [30]
    %
    % trialDuration - Used only in DURINGTRIAL mode; this determines the
    %               number of frames that will be collected each trial (must be constant
    %               throughout the experiment).
    % outputFolder - Where the video output file will be stored. [o.cic.dirs.output]
    % outputFormat - Format of the video file. For allowable modes, call VideoWriter.getProfiles
    %               Defaults to ['MPEG-4']
    % outputMode - 'DURINGTRIAL' (video data are saved to file as they are
    %               acquired, if saving lags, the iti is used to catch up.
    %               If this mode (saving during the trial) leads to
    %               framedrops, use 'afterTrial' which collects video
    %               frames in memory during the trial, then saves all of
    %               them in the ITI
    % fileMode - PerExperiment - Create one video output file (with the
    %               same name as the Neurostim output file, but an extension based on the
    %               outputFormat).
    %           PerTrial - Create a new file for each trial. The file name gives the trial number
    %                       with the _00x suffix for trial x.
    % sourceSettings - A cell array containing Parm/Value pairs with settings to apply to 
    %                 the video source. (e.g. Saturation, WhiteBalance)
    %                 To find the set of parameters for your device, run the plugin
    %                   once for your adaptor/device, then look at
    %                   o.sourceParms
    % 
    % beforeExperimentPreview - Toggle to show a (live) preview of the
    %                       camera image with an adjustable ROI. Drag/reshape the rectangle then
    %                       double click it to finish the preview. Only pixels within the ROI
    %                       will be saved to disk (and shown in the preview).
    % duringExperimentPreview - Keep the preview running during the
    %                       experiment. This will slow everything down and likely cause framedrops...
    %
    %  EXAMPLE
    %   In an experiment with fixed duration trials (2000 ms), collecting
    %   data during the trial and saving them  to file continuously could
    %   work
    %       o = neurostim.plugins.camera(c)
    %       o.adaptorName= 'winvideo'; % Using buikt-in windows adapotr
    %       o.deviceID = 'Integrated Webcam' % Assuming this exists;
    %       o.trialDuration = 2000;
    %       o.framerate =30;
    %       o.outputFormat = 'MPEG-4';
    %       o.outputMode = 'DURINGTRIAL';
    %       o.fileMode = 'PEREXPERIMENT';
    % The camera starts before each trial, collects ceil(2000/30) images at
    % a rate of 30 fps, and saves those on the fly. If saving lags behind
    % some of the ITI is used to catch up.
    % The downside is that even in short trials, ceil(2000/30) frames will
    % be collected. Or, if for some reason one trial is longer thatn 2000ms, there
    % may not be video frames for the later part of the trial.
    %
    % This can be addressed by setting
    %       o.outputMode = 'PERTRIAL';
    % In this case, the .trialDuration is ignored, and images are collected
    % during the entire trial. After each trial, these images are saved to
    % disk. That is (the only?) downside; saving takes some time, hence
    % ITIs could get a bit long. (For a 3s trial with 1280x720
    % images at 30 fps, saving takes ~ 1.2s on BK's laptop). Some time can
    % be regained by using parfeval (i.e. saving in a separate
    % thread/worker so that execution can continue). To do this, set
    %       o.nrWorkers =1; % Open a parallel pool with 1 worker used only
    %       for saving video data.
    %       o.fileMode = 'PerTRIAL'; % Required
    % This only works if a new file is created each trial (fileMode
    % perTrial) as (AFAIK) there is no way to append to videowriter files,
    % and each worker has to create its own videowriter object. With this
    % the ITI for a 3s trial is reduced to 0.7 s from 1.2 s.
    %
    % ANALYSIS
    % When using the video for analysis, make sure to use the actual times
    % at which the frames were acquired. These are stored per trial in the 
    % firstVideoFrame property.
    % The time of that property corresponds to the time at which the first
    % frame was acquired, the data is the difference (in milliseconds)
    % betwen the first frame and each of the subsequent frames in the
    % trial. 
    %
    % BK - Jan 2022
    properties (GetAccess=public,SetAccess= protected)
        hwInfo;
        nrFramesTotal;

        
    end
    properties (Transient)
        hVid;
        hWriter;
        hSource;
        frameAcquiredTime;  % Used as temp record in DURINGTRIAL mode
    end
    properties (Dependent)
        outputFile;
        sourceParms;
    end

    methods
        function v = get.outputFile(o)
            %Determine the output file for the curren trial/experiment
            if strcmpi(o.fileMode,'PERTRIAL')
                v =    sprintf('%s_%03d',fullfile(o.outputFolder,o.cic.file),o.cic.trial);
            else
                v = fullfile(o.outputFolder,o.cic.file);
            end
        end
        function v=get.sourceParms(o)
            v = propinfo(o.hSource);
        end
    end

    methods (Access=public)
        function o=camera(c,name)
            %camera plugin constructor
            if isempty(which('imaqhwinfo'))
                error('The camera plugin requires the Image Acquisition Toolbox. Please install it first.')
            end
            if nargin==1
                name='camera';
            end
            o=o@neurostim.plugin(c,name);
            o.addProperty('adaptorName','winvideo'); % Name of the adaptor used to access this video source
            o.addProperty('deviceID',1); % Device ID on the adaptor (defaults to 1)
            o.addProperty('format','MJPG_1280x720'); % Specify a format to use for this device.
            o.addProperty('framerate',30); % Frames per second
            o.addProperty('trialDuration',3000); % Expected, fixed duration of each trial (duringTrial outputMode only)
            o.addProperty('ROI',[]);
            o.addProperty('outputFolder',o.cic.dirs.output); % Folder where video will be stored
            o.addProperty('outputFormat','MPEG-4'); % File format
            o.addProperty('outputMode','perTrial'); %duringTrial, afterTrial
            o.addProperty('fileMode','perExperiment'); % 'perExperiment' , 'perTrial'
            o.addProperty('nrWorkers',0); % Set to 1 to use parfeval to save in the background (perTrial/afterTrial modes only).            
            o.addProperty('sourceSettings',{});  % Parm/value pairs applied to the source input object
            
            % Logging
            o.addProperty('nrFrames',[]); % Nr Frames recorded in a trial
            o.addProperty('firstVideoFrame',[]); % Stored at the time of the first video frame of a trial. Data are the relative times of all frames.

            % Preview
            o.addProperty('beforeExperimentPreview',true); % Show a preview before the experiment. 
            o.addProperty('duringExperimentPreview',true); % Show preview during the experiment. 

            o.hwInfo = imaqhwinfo;

        end

        function beforeExperiment(o)
            % Connect to the specified hardware
            if ~ismember(o.adaptorName,cat(2,o.hwInfo.InstalledAdaptors))
                error('The %s adaptor is not supported. Install a hardware support package? See imaqhwinfo for installed hardware.')
            end
            try
                if isempty(o.format)
                    o.hVid  = videoinput(o.adaptorName,o.deviceID);
                else
                    o.hVid  = videoinput(o.adaptorName,o.deviceID,o.format);
                end
            catch me
                imaqhwinfo(o.adaptorName,o.deviceID)
                error('Constructing a video object failed (%s)  (Call imaqreset?)', me.message);
            end
            % Configure
            triggerconfig(o.hVid,'manual'); % We'll start in beforeTrial.
            if ~isempty(o.ROI)
                o.hVid.ROIPosition = o.ROI;
            end
            o.hSource= getselectedsource(o.hVid);
            frameRatesSet =set(o.hSource,'FrameRate');
            availableFramerates = cellfun(@str2num,frameRatesSet);
            [ok,ix]= ismember(o.framerate,availableFramerates);
            if ok
                set(o.hSource,'FrameRate',frameRatesSet{ix});
            else
                o.cic.error('STOPEXPERIMENT',sprintf('This device cannot generate a %.2f framerate.',o.framerate));
                availableFramerates %#ok<NOPRT>
            end

            for i=1:2:numel(o.sourceSettings)
                try
                    set(o.hSource,o.sourceSettings{i},o.sourceSettings{i+1});
                catch
                    o.cic.error('STOPEXPERIMENT',sprintf('Could not set %s',o.sourceSettings{i}))
                    fprintf(2,'Constraints:')
                    propinfo(o.hSource,o.sourceSettings{i})
                end
            end

            %% Show a preview window and allow setting an ROI.
            if o.beforeExperimentPreview
                p = propinfo(o.hVid,'VideoResolution');
                o.hVid.ROIPosition = [0 0 p.DefaultValue];
                h = preview(o.hVid);

                % Show a rectangle on the preview to select an ROI.
                ax = ancestor(h,'Axes');
                if isempty(o.ROI)
                    roi = round([10 10 0.9*p.DefaultValue]);
                else
                    roi = o.ROI;
                end
                hRoi = drawrectangle(ax,'Position',roi,'Deletable',false);
                roi = neurostim.plugins.camera.waitForRoi(hRoi);
                % Use even number of pixels (necessary for MPEG-4) and make
                % sure that the ROI is inside the bounds of the camera
                % image.
                wh = roi(3:4);
                wh = ceil(wh/2)*2;
                xy = floor(roi(1:2));
                roi = [xy wh];
                outOfBounds = (xy+wh)>p.DefaultValue;
                roi(outOfBounds) = roi(outOfBounds)-1;  %Shift (up/left) by one pixel.
                o.ROI = roi; % Store for analysis.
                o.hVid.ROIPosition = o.ROI;                
                closepreview(o.hVid); % Always close to reshape ROI.                
            end
            
            if o.duringExperimentPreview
                % Reopen preview with correct size.
               preview(o.hVid);
            end
            
            % Prepare the video input device
            switch upper(o.outputMode)
                case 'DURINGTRIAL'
                    % Use built-in logging - save throughout the trial
                    o.hVid.LoggingMode='disk&memory';                    
                    o.hVid.FramesPerTrigger = ceil(o.trialDuration/1000*o.framerate);
                    o.nrFramesTotal = 0;
                    o.hVid.TriggerRepeat = Inf;                    
                    o.hVid.FramesAcquiredFcn = @(h,e) o.frameAcquired(h,e);
                    o.hVid.FramesAcquiredFcnCount = 1;
                    % Setup a videowriter 
                    switch upper(o.fileMode)
                        case 'PEREXPERIMENT'
                            o.hWriter= VideoWriter(o.outputFile,o.outputFormat);
                            o.hVid.DiskLogger= o.hWriter;
                            start(o.hVid);  % Start now and run to the end of experiment
                        case 'PERTRIAL'
                            % Will create a new writer before each trial
                            % and start hVid there.
                        otherwise
                            error('Unknown fileMode %s',o.fileMode);
                    end                    
                case 'AFTERTRIAL'
                    % Save after the trial completes
                    o.hVid.FramesPerTrigger = Inf;
                    % Setup a videowriter 
                    switch upper(o.fileMode)
                        case 'PEREXPERIMENT'
                            % Create a single writer here, write to it
                            % after each trial, close it in
                            % afterExperiment.
                            o.hWriter= VideoWriter(o.outputFile,o.outputFormat);
                            open(o.hWriter);
                        case 'PERTRIAL'
                            % Create a new writer each trial
                        otherwise
                            error('Unknown fileMode %s',o.fileMode);
                    end
                otherwise
                    error('Unknown outputMode %s',o.outputMode);
            end
            % If saving is to take place in parallel, create a worker
            if o.nrWorkers>0
                if (strcmpi(o.outputMode,'AFTERTRIAL') && strcmpi(o.fileMode,'PERTRIAL'))                   
                    if isempty(gcp('nocreate'))
                        parpool("local",o.nrWorkers); % Use one separate worker for saves
                    end
                else
                     o.writeToFeed('Ignoring parallel save (only works in AfterTrial/PerTrial');
                end
            end
        end
        function frameAcquired(o,h,evt)
            % In DURINGTRIAL outputMode this is called after each frame to
            % store the time of the frame. After the trial, this
            % information is logged to allow accurate reproduction of frame
            % timing.

            if o.preview >0 && h.FramesAcquired >0
                        sample_frame = peekdata(h,1);
                        imagesc(sample_frame);
                        drawnow; % force an update of the figure window         
            end
            o.frameAcquiredTime(evt.Data.FrameNumber-(evt.Data.TriggerIndex-1)*o.hVid.FramesPerTrigger) = datetime(evt.Data.AbsTime);
            
        end
        function beforeTrial(o)
            switch upper(o.outputMode)
                case 'DURINGTRIAL'
                    % Setup a videowriter 
                    switch upper(o.fileMode)
                        case 'PEREXPERIMENT'    
                            %Nothing to do. Writer is open already
                        case 'PERTRIAL'
                            % Create a new logger for this trial.
                            stop(o.hVid)
                            o.hWriter= VideoWriter(o.outputFile,o.outputFormat);
                            o.hVid.DiskLogger= o.hWriter;
                            start(o.hVid);                        
                    end
                    % Clear the time log from previous trial
                    o.frameAcquiredTime = NaT(1,o.hVid.FramesPerTrigger);
                case 'AFTERTRIAL'
                    start(o.hVid);
            end
            % Make sure the videoinput is running and logging is off.
            while ~isrunning(o.hVid)
                o.writeToFeed('Waiting for video to start')
                pause(0.1);
            end
            while islogging(o.hVid)
                pause(0.1)
                o.writeToFeed('Waiting for logging to finish')
            end
            % Ready to go - Trigger recording
            trigger(o.hVid);
        end

        function afterTrial(o)
            switch upper(o.outputMode)
                case 'DURINGTRIAL'
                    % Wait until all the specified frames have been
                    % collected
                    while (o.hVid.FramesAcquired < o.hVid.FramesPerTrigger)
                        pause(0.1);
                        o.writeToFeed(sprintf('Waiting for all (%d) video frames ...please wait (%d)',o.hVid.FramesPerTrigger,o.hVid.FramesAcquired));
                    end
                    % Wait until saving has caught up with acquiistion
                    while (o.hVid.FramesAcquired ~= o.hVid.DiskLoggerFrameCount)
                        pause(0.1);
                        o.writeToFeed('Saving video data...please wait')
                    end
                    % Store logging.
                    nrFrames =o.hVid.FramesAcquired;
                    o.nrFrames = nrFrames-o.nrFramesTotal;
                    o.nrFramesTotal = o.nrFramesTotal + o.nrFrames;
                    
                    firstFrameTime = o.frameAcquiredTime(1);
                    relativeFrameTime = [0 seconds(diff(o.frameAcquiredTime))];                    
                    switch upper(o.fileMode)
                        case 'PEREXPERIMENT'
                            %Nothing to do
                        case 'PERTRIAL'
                            close(o.hWriter); % We'll open a new one in beforeTrial
                    end
                case 'AFTERTRIAL'
                    % Save the video frames recorded in this trial
                    stop(o.hVid); % Stop acquiring
                    o.nrFrames = o.hVid.FramesAcquired;
                    o.nrFramesTotal = o.nrFramesTotal+o.nrFrames;
                    % For reconstruction of the snapshots, determine the
                    % time of the first frame,
                    [frameData,relativeFrameTime,metaData] = getdata(o.hVid,o.nrFrames);
                    firstFrameTime = datetime(metaData(1).AbsTime);
                    switch upper(o.fileMode)
                        case 'PEREXPERIMENT'
                            writeVideo(o.hWriter,frameData);
                        case 'PERTRIAL'
                            if o.nrWorkers>0
                                parfeval(@neurostim.plugins.camera.write,0,o.outputFile,frameData,o.outputFormat);
                            else
                                neurostim.plugins.camera.write(o.outputFile,frameData,o.outputFormat);
                            end
                    end

            end
            % Log the acquisition times of all frames
            storeInLog(o,'firstVideoFrame',firstFrameTime,relativeFrameTime*1000);
               
        end
        
        function afterExperiment(o)
            % Cleanup
            stop(o.hVid);
            close(o.hWriter);
            close(o)
        end
        function  close(o)
            delete(o.hVid);o.hVid= [];
            delete(o.hWriter);o.hWriter=[];
        end
        function delete(o)
            close(o)
        end

        function storeInLog(o,propertyName,clockTime,data)
            % Store the data in the property at a time corresponding to the
            % clockTime. (i.e. backdating the event to when it occurred).

            % Determine offset between GetSecs and matlab clock
            msNowGetSecs = 1000*GetSecs;
            nowClock = datetime('now');            
            msSinceEvent = 1000*seconds(nowClock-clockTime);
            nsTimeEvent = msNowGetSecs-msSinceEvent;
            % Use parameter.storeInlog 
            storeInLog(o.prms.(propertyName),data,nsTimeEvent);

        end
        
    end


    methods (Static)

        %Static function to write per trial to minimize data
        % to be transferred to another thread/process.
        function write(file,data,format)
            v= VideoWriter(file,format);
            open(v);
            writeVideo(v,data);
            close(v);
        end

        function pos = waitForRoi(hROI)
            % Used to adjust the ROI interactively on the preview window.
            l = addlistener(hROI,'ROIClicked',@neurostim.plugins.camera.clickCallback);
            % Block program execution
            uiwait;
            % Remove listener
            delete(l);
            % Return the current position
            pos = hROI.Position;
        end

        function clickCallback(~,evt)
            % Exits the preview ROI selection ondouble click
            if strcmp(evt.SelectionType,'double')   
                uiresume;
            end
        end

        function o= debug
            % Test and debug
            o = neurostim.plugins.camera(neurostim.cic);
            o.deviceID =2;
            o.format='YUY2_1280x720';

             o.deviceID =1;
             o.format='MJPG_1280x720';

            o.outputFormat='MPEG-4';
            o.outputFolder = 'c:/temp/';
            o.fileMode = 'perExperiment';
            o.outputMode ='afterTrial';
            o.nrWorkers = 0;
            o.beforeExperimentPreview = true;
            o.duringExperimentPreview = true;
            o.sourceSettings = {'Brightness',100,'BacklightCompensation','off'};
            o.ROI = [500 250 251 251];
            o.beforeExperiment;

            for i=1:3
                o.cic.trial = i;
                i %#ok<NOPRT> 

                o.beforeTrial;

                pause(3)

                tic
                o.afterTrial;
                toc  % Time file saving.
            end
            o.afterExperiment;
        end
    end
end
