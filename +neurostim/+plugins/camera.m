classdef camera < neurostim.plugin
    % Plugin to record video (with a webcam, ip cam, or other video
    % device that the Mathworks Image Acquisition Toolbox can control).
    % PROPERTIES
    % adaptorName - Name of the adaptor to acquire video. E.g. winvideo (Default),
    %               gige, matrox, etc. ( See imaqhelp videoinput)
    % deviceID  - ID Number of the device on the adaptor [1]
    % format   - Which format to use on the device. This is
    %           device-specific, get a list of allowable modes by calling
    %           imaqhwinfo(adaptorName,deviceID); ['MJPG_1280x720']   
    %
    % trialDuration - Used only in DURINGTRIAL mode; this determines the
    %               number of frames that will be collected each trial (must be constant
    %               throughout the experiment).
    % outputFolder - Where the video output file will be stored. When epty,
    %                  the video file is stored with the neurostim  output file
    % filename    - Name of the video output file. When empty, the filename
    %               is the same as the Neurostim output file.
    % outputFormat - Format of the video file. For allowable modes, call VideoWriter.getProfiles
    %               Defaults to ['MPEG-4']
    % outputMode - 'SAVEDURINGTRIAL' (video data are saved to file as they are
    %               acquired, if saving lags, the iti is used to catch up.
    %               If this mode (saving during the trial) leads to
    %               framedrops, use 'SAVEAFTERTRIAL' which collects video
    %               frames in memory during the trial, then saves all of
    %               them in the ITI
    % fileMode - PerExperiment - Create one video output file (with the
    %               same name as the Neurostim output file, but an extension based on the
    %               outputFormat).
    %           PerTrial - Create a new file for each trial. The file name gives the trial number
    %                       with the _00x suffix for trial x.
    % framerate - Read only property. Use Properties to set.
    % properties  - A cell array containing Parm/Value pairs with settings to apply to
    %                 the video source. (e.g. Saturation, WhiteBalance,Framerate)
    %                 To find the set of parameters for your device, run
    %                 neurostim.plugins.video.info it will (interactively)
    %                 show you the properties and their constraints.
    %
    % beforeExperimentPreview - Toggle to show a (live) preview of the
    %                       camera image with an adjustable ROI. Drag/reshape the rectangle then
    %                       double click it to finish the preview. Only pixels within the ROI
    %                       will be saved to disk (and shown in the preview).
    % duringExperimentPreview - Keep the preview running during the
    %                       experiment. This will slow everything down and likely cause framedrops...
    %
    % ROI       = Bounding box [left bottom width height] in pixels of the
    %                   video to acquire. You can set this manually, or interactively using
    %                   the .beforeExperimentPreview option.
    %
    %  EXAMPLE
    %   In an experiment with fixed duration trials (2000 ms), collecting
    %   data during the trial and saving them  to file continuously could
    %   work
    %       o = neurostim.plugins.camera(c)
    %       o.adaptorName= 'winvideo'; % Using buikt-in windows adapotr
    %       o.deviceID = 'Integrated Webcam' % Assuming this exists;
    %       o.trialDuration = 2000;
    %       o.properties ={'framerate',30};
    %       o.outputFormat = 'MPEG-4';
    %       o.outputMode = 'SAVEDURINGTRIAL';
    %       o.fileMode = 'PEREXPERIMENT';
    % The camera starts before each trial, collects ceil(2000/30) images at
    % a rate of 30 fps (assuming your camera has the property 'framerate'), and saves those on the fly. 
    %  If saving lags behind some of the ITI is used to catch up.
    % The downside is that even in short trials, ceil(2000/30) frames will
    % be collected. Or, if for some reason one trial is longer than 2000ms, there
    % may not be video frames for the later part of the trial.
    %
    % This can be addressed by setting
    %       o.outputMode = 'SAVEAFTERTRIAL';
    % In this case, the .trialDuration is ignored, and images are collected
    % during the entire trial. After each trial, these images are saved to
    % disk. That is (the only?) downside; saving takes some time, hence
    % ITIs could get long. (For a 3s trial with 1280x720
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
    % Finally, there is a way to run the entire acquisition plus saving on
    % a parallel worker. This requires the following three settings
    %   o.nrWorkers =1
    %   o.fileMode = 'PEREXPERIMENT';
    %   o.outputMode = 'SAVEAFTERTRIAL';
    % As the acquisition takes place on a parallel worker you cannot see a
    % preview during the experiment (but you can still  use
    % .beforeExperimentPreview to adjust the region of interest) 
    % and errors are a bit harder to debug. By setting o.diary =true, a 
    % log file of what happens on the worker will be saved to the output folder.
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
    % GETING STARTED
    % With a new camera it may help to first run 
    % 
    % neurostim.plugins.camera.info
    % this will show properties of your hardware, including the names of
    % parameters that control framerate,etc.
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
        queue; % Pollable queue to send messages to worker in allOnWorker mode.
        future; % The future for the process acquiring and saving data on the worker.
    end
    properties (Dependent)
        outputFile; % Name of the output file       
        allOnWorker; % Evaluate to true if PEREXPERIMENT/SAVEAFTERTRIAL/nrWorkers>1
        saveOnWorker;% Evaluate to true if PERTRIAL/SAVEAFTERTRIAL/nrWorkers>1
        framerate;
    end

    methods
        function v = get.framerate(o)
            % Pull framerate from video source using a case insensitive
            % search for 'framerate' property.
            fn = fieldnames(o.hSource.propinfo);
            ix = strcmpi(fn,'framerate');
            if any(ix) 
                v = str2double(o.hSource.(fn{ix}));
            else
                writeToFeed('No framerate property. Using default 30 fps');
                v = 30;
            end
        end
        function v = get.outputFile(o)
            %Determine the output file for the curren trial/experiment
            if isempty(o.outputFolder)
                fld = fileparts(o.cic.fullFile);
            else
                fld = o.outputFolder;
            end

            if isempty(o.filename)
                fl = o.cic.file;
            else
                fl = o.filename ;
            end

            if strcmpi(o.fileMode,'PERTRIAL')
                v =    sprintf('%s_%03d',fullfile(fld,fl),o.cic.trial);
            else
                v = fullfile(fld,fl);
            end
        end
       
        function v = get.allOnWorker(o)
            v = strcmpi(o.fileMode,'PEREXPERIMENT') && strcmpi(o.outputMode,'SAVEAFTERTRIAL') && o.nrWorkers>0;
        end
        function v = get.saveOnWorker(o)
            v =  strcmpi(o.outputMode,'SAVEAFTERTRIAL') && strcmpi(o.fileMode,'PERTRIAL')  &&  o.nrWorkers>0;
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
            o.addProperty('trialDuration',3000); % Expected, fixed duration of each trial (duringTrial outputMode only)
            o.addProperty('ROI',[]);
            o.addProperty('outputFolder',''); % Folder where video will be stored. Defaults to folder of the neurostim output 
            o.addProperty('filename',''); % File where video will be stored. Defaults to the same filename of the neurostim output.            
            o.addProperty('outputFormat','MPEG-4'); % File format
            o.addProperty('outputMode','saveDuringTrial'); %saveDuringTrial, saveAfterTrial
            o.addProperty('fileMode','perExperiment'); % 'perExperiment' , 'perTrial'
            o.addProperty('nrWorkers',0); % Set to 1 to use parfeval to save in the background (perTrial/afterTrial modes only).
            o.addProperty('properties',{});  % Parm/value pairs applied to the source input object. e,g, {'framerate',30} .
           
            %%
            o.addProperty('fake',false);  % Fake video for debugging
            o.addProperty('diary',false); % Set to true to create a diary output on the worker

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
            o.nrFramesTotal = 0;

            if o.fake
                o.writeToFeed('Fake video input from %s',o.adaptorName)
                return
            end
            if ~ismember(o.adaptorName,cat(2,o.hwInfo.InstalledAdaptors))
                error('The %s adaptor is not supported. Install a hardware support package? See imaqhwinfo for installed hardware.')
            end

            %% Show a preview window and allow setting an ROI.
            if o.beforeExperimentPreview
                o.hVid = configure(o);
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
                hFig = ancestor(h,'Figure');
                roi = neurostim.plugins.camera.waitForRoi(hRoi,hFig);
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

            if o.allOnWorker
                % In this mode all acquisition and saving happens on a
                % parallel worker.
                % Close the camera object - it will be reopened on the
                % worker
                delete(o.hVid)
                setupWorker(o);
            else   % Acquisition is not on worker
                if isempty(o.hVid)
                    % In case there was no preview, open it now
                    o.hVid = configure(o);
                end
                if o.duringExperimentPreview
                    % Reopen preview with correct size.
                    preview(o.hVid);
                end
                % Prepare the video writer
                switch upper(o.outputMode)
                    case 'SAVEDURINGTRIAL'
                        % Use built-in logging - save throughout the trial
                        o.hVid.LoggingMode='disk';
                        o.hVid.FramesPerTrigger = ceil(o.trialDuration/1000*o.framerate);
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
                    case 'SAVEAFTERTRIAL'
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
                if o.saveOnWorker
                    if isempty(gcp('nocreate'))
                        parpool("local",o.nrWorkers); % Use one separate worker for saves
                    end
                end
            end

        end
        function frameAcquired(o,h,evt)
            % In DURINGTRIAL outputMode this is called after each frame to
            % store the time of the frame. After the trial, this
            % information is logged to allow accurate reproduction of frame
            % timing.            
            o.frameAcquiredTime(evt.Data.FrameNumber-(evt.Data.TriggerIndex-1)*o.hVid.FramesPerTrigger) = datetime(evt.Data.AbsTime);

        end
        function beforeTrial(o)
            if o.fake
                o.writeToFeed('Fake video input from %s starting trial %d',o.adaptorName,o.cic.trial)
                return
            end

            if o.allOnWorker
                % Tell the worker to start acquiring. (Writer is open)
                sendToWorker(o,o.cic.trial)
            else
                switch upper(o.outputMode)
                    case 'SAVEDURINGTRIAL'
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
                    case 'SAVEAFTERTRIAL'
                        start(o.hVid);
                end
                % Make sure the videoinput is running and logging is off.
                while ~isrunning(o.hVid)
                    o.writeToFeed('Waiting for camera to start')
                    pause(0.25);
                end
                while islogging(o.hVid)
                    pause(0.25)
                    o.writeToFeed('Waiting for logging to finish')
                end
                % Ready to go - Trigger recording
                trigger(o.hVid);
            end
        end

        function afterTrial(o)
            if o.fake
                o.writeToFeed('Fake camera input from %s after trial %d',o.adaptorName,o.cic.trial)
                return
            end

            if o.allOnWorker
                % Tell the worker to save to the writer
                sendToWorker(o,-o.cic.trial);
            else
                switch upper(o.outputMode)
                    case 'SAVEDURINGTRIAL'
                        % Wait until all the specified frames have been
                        % collected
                        while (o.hVid.FramesAcquired < o.hVid.FramesPerTrigger)
                            pause(0.25);
                            o.writeToFeed(sprintf('Waiting for all (%d) camera frames ...please wait (%d)',o.hVid.FramesPerTrigger,o.hVid.FramesAcquired));
                        end
                        % Wait until saving has caught up with acquiistion
                        while (o.hVid.FramesAcquired ~= o.hVid.DiskLoggerFrameCount)
                            pause(0.25);
                            o.writeToFeed('Saving camera data...please wait')
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
                    case 'SAVEAFTERTRIAL'
                        % Save the camera frames recorded in this trial
                        stop(o.hVid); % Stop acquiring
                        o.nrFrames = o.hVid.FramesAcquired;
                        o.nrFramesTotal = o.nrFramesTotal+o.nrFrames;
                        % For reconstruction of the snapshots, determine the
                        % time of the first frame,
                        if o.nrFrames==0
                            o.cic.error('STOPEXPERIMENT',sprintf('No frames acquired in trial %d',o.cic.trial));
                            return; % Skip the storeInLog below
                        else
                        [frameData,relativeFrameTime,metaData] = getdata(o.hVid,o.nrFrames);
                        firstFrameTime = datetime(metaData(1).AbsTime);
                        switch upper(o.fileMode)
                            case 'PEREXPERIMENT'
                                writeVideo(o.hWriter,frameData);
                            case 'PERTRIAL'
                                if o.nrWorkers>0
                                    % Send to worker to save
                                    parfeval(@neurostim.plugins.camera.write,0,o.outputFile,frameData,o.outputFormat);
                                else
                                    % Save here.
                                    neurostim.plugins.camera.write(o.outputFile,frameData,o.outputFormat);
                                end
                        end
                        end

                end
                % Log the acquisition times of all frames
                storeInLog(o,'firstVideoFrame',firstFrameTime,relativeFrameTime*1000);
            end

        end

        function afterExperiment(o)
            if o.fake
                o.writeToFeed('Fake camera input from %s. afterExperiment')
                return
            end

            % Cleanup
            if o.allOnWorker
                sendToWorker(o,0);
            else
                stop(o.hVid);
                close(o.hWriter);
            end
            close(o);
        end
        function  close(o)
            delete(o.hVid);o.hVid= [];
            delete(o.hWriter);o.hWriter=[];
            delete(o.queue);o.queue =[];
            delete(o.future);o.future=[];
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

        function pos = waitForRoi(hROI,hFig)
            % Used to adjust the ROI interactively on the preview window.
            l = addlistener(hROI,'ROIClicked',@(x,e)neurostim.plugins.camera.clickCallback(hFig,e));
            % Block program execution            
            uiwait(hFig);
            % Remove listener
            delete(l);
            % Return the current position
            pos = hROI.Position;

        end

        function clickCallback(hFig,evt)
            % Exits the preview ROI selection ondouble click
            if strcmp(evt.SelectionType,'double')
                uiresume(hFig);
            end
        end


        %% Debug/Test functions
        function o= debugbg
            % Test and debug
            o = neurostim.plugins.camera(neurostim.cic);
              o.outputFolder = 'c:/temp/';
        
            o.deviceID =1;
            o.format='MJPG_1280x720';
            o.diary = true;
            o.outputFormat='MPEG-4';            
            o.fileMode = 'perExperiment';
            o.outputMode ='saveafterTrial';
            o.nrWorkers = 1;
            o.beforeExperimentPreview = true;
            o.duringExperimentPreview = false;
            o.properties = {'Brightness',60,'BacklightCompensation','off'};
            o.ROI = [500 250 251 251];

            o.beforeExperiment;

            for i=1:3
                o.cic.trial = i;
                i %#ok<NOPRT>

                o.beforeTrial;

                pause(5)

                tic
                o.afterTrial;
                toc  % Time file saving.
            end
            o.afterExperiment;

        end

        function o= debug
            % Test and debug
            o = neurostim.plugins.camera(neurostim.cic);
            o.outputFolder = 'c:/temp/';
        
      
            o.deviceID =1;
            o.format='MJPG_1280x720';

            o.outputFormat='MPEG-4';
            
            o.fileMode = 'perExperiment';
            o.outputMode ='saveDuringTrial';
            o.nrWorkers = 1;
            o.beforeExperimentPreview = true;
            o.duringExperimentPreview = false;
            o.properties = {'Brightness',64,'BacklightCompensation','off'};
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


        % This function sets up camera acquisition and writing on a parallel worker
        % The client (i.e. the camera plugin on the main Matlab) sends it messages at
        % the start and end of each trial
        function ok = acquireAndSave(queue,hO)
            % INPUT
            % queue - a pollable data queue
            % hO -
            ok = true;
            o =hO.Value;
            if o.diary
                diary([o.outputFile '_diary.txt'])
            end
           
            hVid = configure(o);
            hVid.FramesPerTrigger = Inf;
            hWriter= VideoWriter(o.outputFile,o.outputFormat);
            open(hWriter);

            %% Loop waiting for messages from the client
            endExperiment = false;
            while ~endExperiment
                % Wait for a message from the client's beforeTrial/afterTrial
                trial = poll(queue.Value, Inf);
                if trial>0
                    % Begin trial signal
                    start(hVid)
                    trigger(hVid);
                    fprintf('Triggered trial %d\n',trial)
                elseif trial < 0
                    % End Trial signal
                    stop(hVid)
                    o.nrFrames = hVid.FramesAcquired;
                    o.nrFramesTotal = o.nrFramesTotal+o.nrFrames;
                    % For reconstruction of the snapshots, determine the
                    % time of the first frame,
                    if o.nrFrames >1
                        [frameData,relativeFrameTime,metaData] = getdata(hVid,o.nrFrames);
                        firstFrameTime = datetime(metaData(1).AbsTime);
                        writeVideo(hWriter,frameData);
                        % Log the acquisition times of all frames
                        storeInLog(o,'firstVideoFrame',firstFrameTime,relativeFrameTime*1000);
                        fprintf('Saved %d frames for trial %d\n',o.nrFrames,-trial)
                    else
                        error('No frames acquired in trial %d',-trial);
                    end
                else
                    close(hWriter);
                    delete(hVid);
                    fprintf('Video acquisition complete') ;
                    endExperiment =true;
                end
            end

            if o.diary
                diary off
            end
        end

        function reset
            poolobj = gcp('nocreate');
            delete(poolobj);
            imaqreset;
        end

        function info
            hwInfo= imaqhwinfo;
            if isempty(hwInfo)
                fprintf('No camera adaptors found')
            end
            adaptors = hwInfo.InstalledAdaptors;
            tmp =strcat(adaptors,'\n'); 
            tmp = [tmp{:}];
            n = input(['Pick a vendor (1,2,..)\n' tmp]);
            
            adaptorInfo = imaqhwinfo(adaptors{n});
            if isempty(adaptorInfo.DeviceIDs)
                fprintf('No devices are connected to the %s adaptor\n',adaptors{n});
                return
            end
            
            for d=1:numel(adaptorInfo.DeviceIDs)
                devInfo = adaptorInfo.DeviceInfo(d);
                fprintf('*************************************\n')
                fprintf('Found ''%s'' as DeviceID %d on adaptor ''%s''\n',devInfo.DeviceName,devInfo.DeviceID,adaptors{n})
                fprintf('This camera supports the following formats:\n')
                fprintf('%s\n',devInfo.SupportedFormats{:})
                fprintf('*************************************\n')
                fprintf('Connecting now..\n')
                hVid = videoinput(adaptors{n},devInfo.DeviceID); %#ok<TNMLP> 
                hSource= getselectedsource(hVid);
                pInfo = propinfo(hSource);
                props = fieldnames(pInfo);
                nr = (1:numel(props))';
                tmp = strcat(cellstr(num2str(nr)),') ', props,'\n');                
                pNr =1;
                while true
                    answer = input(sprintf(['These are the camera properties. Show details for [%d], select one, or 0 to quit.\n' [tmp{:}]],pNr));
                    if ~isempty(answer)                        
                        pNr = answer; 
                    end
                    if pNr==0
                        break;
                    elseif pNr >numel(props)
                        fprintf('Invalid property number (%d)\n',pNr)
                    else
                        fprintf('***%s*** has the following properties: \n',props{pNr})
                        propinfo(hSource,props{pNr})
                        fprintf('Press any key to continue\n');
                        pause
                        pNr = pNr+1;
                    end
                end

            end



        end
    end

    methods (Access=protected)
        function sendToWorker(o,code)
            send(o.queue,code);
            if ~isempty(o.future.Error)
                o.cic.error('STOPEXPERIMENT','The worker failed');
                o.future.Error
            end
        end
        function hVid = configure(o)
            % Need this undocumented feature 
            imaqmex('feature','-limitPhysicalMemoryUsage',false)
            % Configure the videoinput object
            try
                if isempty(o.format)
                    hVid  = videoinput(o.adaptorName,o.deviceID);
                else
                    hVid  = videoinput(o.adaptorName,o.deviceID,o.format);
                end
            catch me
                imaqhwinfo(o.adaptorName,o.deviceID)
                error('Constructing a camera object failed (%s)  (Call imaqreset?)', me.message);
            end

            % Configure
            triggerconfig(hVid,'manual'); % We'll start in beforeTrial.
            if ~isempty(o.ROI)
                hVid.ROIPosition = o.ROI;
            end
            o.hSource= getselectedsource(hVid);
            for i=1:2:numel(o.properties)
                try
                    set(o.hSource,o.properties{i},o.properties{i+1});
                catch
                    fprintf(2,'The ***%s*** property has the following constraints:\n',o.properties{i})
                    propinfo(o.hSource,o.properties{i})
                    error('Could not set %s',o.properties{i})
                end
            end
        end

        function setupWorker(o)
            % Setup acquisition and saving on a parallel worker
            if isempty(gcp('nocreate'))
                parpool("local",o.nrWorkers);
            end
            % Share the plugin object with all workers
            oShared=  parallel.pool.Constant(o);
            % Create a shared queue
            workerQueueShared = parallel.pool.Constant(@parallel.pool.PollableDataQueue);
            % Retrieve a handle to the queue on the worker to use on the client
            o.queue = fetchOutputs(parfeval(@(x) x.Value, 1, workerQueueShared));
            % Send the plugin object to the workerto start the camera and wait for messages
            o.future = parfeval(@neurostim.plugins.camera.acquireAndSave, 1, workerQueueShared,oShared);
            if ~isempty(o.future.Error)
                o.future.Error
            end
        end
    end

    %% GUI Functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            if strcmpi(parms.onOffFakeKnob,'Fake')
                o.fake=true;
            else
                o.fake =false;
            end
        end
    end

    methods (Static)
        function guiLayout(pnl)
            % Add plugin specific elements

        end
    end



end
