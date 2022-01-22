classdef video < neurostim.plugin
    % Plugin to record video (with a webcam, ip cam, or other video
    % device that the Mathworks Image Acquisition Toolbox can control)
    properties (GetAccess=public,SetAccess= protected)
        hwInfo;
    end
    properties (Transient)
        hVid;
        hWriter;
        hSource;
    end

    methods
    end 
    methods (Access=public)
        function o=video(c,name)
            if isempty(which('imaqhwinfo'))
                error('The video plugin requires the Image Acquisition Toolbox. Please install it first.')
            end
            if nargin==1
                name='video';
            end
            o=o@neurostim.plugin(c,name);
            o.addProperty('adaptorName','winvideo'); % Name of the adaptor used to access this video source
            o.addProperty('deviceID',1); % Device ID on the adaptor (defaults to 1)
            o.addProperty('format','MJPG_1280x720'); % Specify a format to use for this device.
            o.addProperty('videoFramerate',30);
            o.addProperty('framesPerTrigger',10);
            o.addProperty('trialDuration',3000);
            o.addProperty('outputFolder',o.cic.dirs.output);

            o.hwInfo = imaqhwinfo;

        end

        function beforeExperiment(o)
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
                imaqhwinfo(o.adaptorName,o.deviceID);
                error('Constructing a video object failed (%s)', me.message);
            end
            o.hSource= getselectedsource(o.hVid);            

            triggerconfig(o.hVid,'manual'); % We'll trigger in beforeTrial.
            frameRatesSet =set(o.hSource,'FrameRate'); 
            availableFramerates = cellfun(@str2num,frameRatesSet); 
            [ok,ix]= ismember(o.videoFramerate,availableFramerates);
            if ok
                set(o.hSource,'FrameRate',frameRatesSet{ix});
            else
                o.cic.error('STOPEXPERIMENT',sprintf('This device cannot generate a %.2f framerate.',o.videoFramerate));
                availableFramerates %#ok<NOPRT> 
            end  
            
            o.hVid.FramesPerTrigger = ceil(o.trialDuration/1000*o.videoFramerate);
            o.hWriter= VideoWriter(fullfile(o.outputFolder,o.cic.file));%, 'Motion JPEG 2000');
            o.hVid.DiskLogger = o.hWriter;
            o.hVid.LoggingMode = 'disk';
            start(o.hVid);
            if ~strcmpi(o.hVid.Running,'On')
                o.cic.error('STOPEXPERIMENT','The video object failed to start');
            end
        end

        function beforeTrial(o)
            if o.hVid.FramesPerTrigger ~= ceil(o.trialDuration/1000*o.videoFramerate)
                % trial duration changed... 
                stop(o.hVid);
                o.hVid.FramesPerTrigger = ceil(o.trialDuration/1000*o.videoFramerate);
                start(o.hVid);
            end
            trigger(o.hVid);
            % Trigger recording a set of frames
        end
        function afterTrial(o)
            % Save the video frames
            while (o.hVid.FramesAcquired ~= o.hVid.DiskLoggerFrameCount) 
                o.writeToFeed('Writing video to disk...')
                pause(.1)
            end
        end
        function afterExperiment(o)
            % Cleanup
            stop(o.hVid);
            close(o);
        end
        function  close(o)            
            delete(o.hVid);o.hVid= [];
            delete(o.hWriter);o.hWriter=[];
        end
        function delete(o)
           close(o)         
        end
    end

    methods (Static)
        function o= debug
            o = neurostim.plugins.video(neurostim.cic);
            o.trialDuration = 3000;
            o.outputFolder = 'c:/temp/';

            o.beforeExperiment;
            o.beforeTrial;
            o.afterTrial;
           % o.afterExperiment;
        end
    end
end
