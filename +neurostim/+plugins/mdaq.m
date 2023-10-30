classdef mdaq <  neurostim.plugin
    % Neurostim plugin class that uses the Matlab Data Acquisition Toolbox
    % to generate digital/analog output signals and/or record such signals
    % on the hardware of your choice.
    %
    % It is called mdaq to distinguish it from the neurstim.plugins.daq
    % which does not need the Data Acquisition Toolbox
    %
    % In nsGui this plugin shows a running record of the acquired data.
    % Updates of the display are restricted to the intertrial interval to
    % avoid interfering with timing.
    %
    % PROPERTIES
    %  vendor - DAQ vendor ('NI','MCC','DIRECTSOUND'); see doc daq.
    %  useWorker - Set this to true to perform acquisition and saving on a
    %               a paralllel worker.
    %  bufferSize - Seconds of data to show in the nsGUI [10]
    %  precision  - Precision to use for storing acquired data ['double']
    %  fake       - Set to true to run in fake mode for debugging [false]
    %  vendor     - which hardware vendor to use. Run daqvendorlist to get
    %               a list of options. Note that each may require a
    %               separate hardware support package to be installed.
    %  samplerate - Sample rate to use. The DAQ vendor may reset this if
    %               the requested rate cannot be achieved.
    %   diary      - Set this to true to keep an outptut diary on the data
    %                   acquisition worker for troubleshooting purposes
    %                   [false].
    % keepAliveAfterExperimet - Set this to true to skip shutdown in
    % afterExperiment. The user is then responsible for calling this at the
    % right time (this is a hack to allow the scanbox to stop its grabbing
    % first, and only then shutdown mdaq. In other words this allows a
    % different order at beginExperiment (mdaq starts first) compared to
    % afterExperiment (scanbox shuts down first).
    %
    % Read only properties
    %  dataFile - Name of output file (assigned by neurostim) where the acquired data are saved.
    %               Use mdaq.readBin to read the contents of this file as a
    %               timetable.
    % nrInputChannels  - Number of input channels
    % nrOutputChannels  - Number of output channels.
    % startDaq      - Log the time data acquisition was triggered
    %
    % EXAMPLE
    % neurostim.plugins.mdaq(c)      % Add an mdaq plugin to CIC
    % c.mdaq.bufferSize = 10; % 10 seconds of circular buffer
    % c.mdaq.vendor = 'ni'; % Use the NiDaq vendor
    % Let's assume dev1 is the name of a nidaq card (use daqlist to get names)
    % Record an analog input connected to analog in channel 19, call it
    % "diode"
    % addChannel(c.mdaq,"diode","input","dev2","ai9","voltage");
    % And a digital input that we call laserOnDig
    % addChannel(c.mdaq,"laserOnDig","input","dev2","port0/line0","Digital")
    % Run acquisition and saving on a parallel worker to minimize potential interference
    % between daq and other time consuming work on the main matlab
    % c.mdaq.useWorker= true;
    %
    % NOTES
    % The GUI shows the contents of a circular buffer, this is in-memory normally,
    % but shared via a memory mapped file when running on a separate worker.
    %
    % The first time you setup new hardware you probably want to use
    % list = daqlist(vendorName) to see what is conneceted, and then
    % list.DeviceInfo to get more detailed information on your device
    % (inlcuding the names and measurement types each port supports).
    %
    % See also DAQ
    %
    % If the raw data acquired from the daq are not that informative, you
    % can defined a o,postproces function handle that takes the raw data
    % time stamps and the mdaq plugin and returns processed data and timestamps for display
    % in the gui. Note that only the raw data are saved to disk.
    %
    % BK -  Jan 2022.

    properties
        postprocess function_handle
    end
    properties (SetAccess = protected)
        inputMap  % Map from named channels to daq input channel properties
        outputMap % Map from named channels to daq output channel properties
        triggerTime  % Time when data acquisition was triggered (time zero)
        nrTimeStamps;
        outputValue;  % Last set values for outputs
    end
    properties (Transient)
        hDaq;           % Handle to the daq object.
        pool;           % The pool of workers.
        dataBuffer;     % Circular buffer
        timeBuffer;     % Circular buffer for timestamps
        bufferIx;       % Current end of data in circular buffer.
        previousBufferIx;  % For graphical updates
        FID;            % FID for temporary file storage

        ax =[];         % Handle to the nsGui Axes.

        % Properties used in useWorker = true (i.e., parallel data
        % acquisition) mode
        receiveQueue;          % Pollable queue to send messages to the worker.
        sendQueue;
        future;         % The future for the process acquiring and saving data on the worker.
        mmap;           % memory mapped file to transfer circular buffer from worker to client.
        mmapFile;       % Filename
    end

    properties (Dependent)
        isRunning;
        outputOnly;
        dataFile;
    end

    methods
        function v= get.isRunning(o)
            v= ~isempty(o.hDaq) && o.hDaq.Running;
        end
        function v=  get.outputOnly(o)
            v = isempty(o.inputMap);
        end
        function v = get.dataFile(o)
            v = [o.cic.fullFile '.bin'];
        end
    end

    methods
        function plot(o,digEvent, pv)
            arguments
                o (1,1) neurostim.plugins.mdaq
                digEvent (1,1) {mustBeTextScalar}
                pv.folderMap (1,2) cell = {}
                pv.trials (1,:) = [1 inf]
                pv.slack (1,1) = seconds(10)
            end
            
            T = readBin(o,drive=pv.folderMap);
            [~,trial,~,time] = get(o.cic.prms.trial);
            time = seconds(time/1000);
            digOnset = find([false; diff(T.(digEvent))>0.5]);
            digOnsetNsTime = T.nsTime(digOnset)';
            digOnsetClockTime = T.clockTime(digOnset)'; %#ok<NASGU>

            nrDigOnsetsTotal = numel(digOnsetNsTime); %#ok<NASGU>
            startTime = time(find(trial>= pv.trials(1),1,'first'));
            stopTime  = time(find(trial<= pv.trials(end),1,'last'));

            keepTrial = time >=startTime-pv.slack & time <= stopTime+pv.slack;
            keepOnset = digOnsetNsTime >=startTime-pv.slack &  digOnsetNsTime <=stopTime+pv.slack;
            time=time(keepTrial);
            trial =trial(keepTrial);
            digOnsetNsTime = digOnsetNsTime(keepOnset);
            nrDigOnsets = numel(digOnsetNsTime);
            nrTrials = numel(trial);
            plot([time';time'],repmat([0;1],[1 nrTrials]),'k','LineWidth',2)

            hold on
            for tr= 1:numel(trial)
                text(time(tr),0.9,num2str(trial(tr)))
            end
            plot([digOnsetNsTime;digOnsetNsTime],repmat([0;.5],[1 nrDigOnsets]),'r')

            [~,~,~,time] = get(o.prms.startDaq,'withData',true);
            time = seconds(time/1000);
            if time > startTime && time<stopTime
                plot([time;time],[0;1],'m','LineWidth',2)
            end

            [~,~,~,time] = get(o.prms.startDaq,'withData',true);
            time = seconds(time/1000);
            if time > startTime && time<stopTime
                plot([time;time],[0;1],'m','LineWidth',2)
            end

            xlim([startTime-pv.slack stopTime+pv.slack])
        end

        function o = mdaq(c,name)
            arguments
                c (1,1) neurostim.cic
                name = 'mdaq'
            end
            if isempty(which('daq'))
                error('The daq plugin relies on the Data Acquisition Toolbox. Please install it first.')
            end
            % Construct a daq plugin.
            o=o@neurostim.plugin(c,name);
            o.addProperty('useWorker',false);
            o.addProperty('bufferSize',10); % in seconds.
            o.addProperty('precision','double');            
            o.addProperty('fake',false);
            o.addProperty('nrInputChannels',0);
            o.addProperty('nrOutputChannels',0);
            o.addProperty('vendor','');
            o.addProperty('samplerate',1000);
            o.addProperty('startDaq',[],'sticky',true);
            o.addProperty('diary',false); % Debug parallel.
            o.addProperty('keepAliveAfterExperiment',false);
            % Setup mapping
            o.inputMap = containers.Map('KeyType','char','ValueType','any');
            o.outputMap = containers.Map('KeyType','char','ValueType','any');
        end


        function addChannel(o,name,inputOrOutput,device, channel,type,pvPairs)
            % Function the user uses to add channels to the acquisition.
            %
            arguments
                o (1,1) neurostim.plugins.mdaq
                name (1,1) {mustBeTextScalar}   % Name for the channel
                inputOrOutput (1,1) {mustBeTextScalar,mustBeMember(inputOrOutput,["input","output"])}
                device (1,1) {mustBeTextScalar} % Device name
                channel (1,1)                   % Channel name or number
                type (1,1) {mustBeTextScalar}   % Channel type
                pvPairs (1,:) cell = {}         % Channel properties (e.g., {'TerminalConfig','SingleEnded', 'Range',[-10 10]}
            end
            if inputOrOutput =="input"
                o.inputMap(name) = {device,channel,type,pvPairs};
            else
                o.outputMap(name) ={device,channel,type,pvPairs};
            end
        end

        function props = configure(o)
            % Connect to the hardware (on worker)

            % daqreset;  % Problematic if other daq usage has started already?
            list = daqvendorlist; % First time this can take a while.
            if ~ismember(upper(o.vendor),upper(list.ID))
                fprintf(2,'Please install the hardware support package for vendor %s first (see doc daq.m)\n',o.vendor);
                error(['Unknown vendor ' o.vendor]);
            else
                try
                    o.hDaq = daq(o.vendor);
                catch me
                    error(['Failed to connect to DAQ ' o.vendor ' ( ' me.message ')']);
                end
            end
            o.hDaq.Rate = o.samplerate;  % Try to use this
            % Add input and output channels to the hDaq.
            ks = keys(o.inputMap);
            for k=1:numel(ks)
                vals = o.inputMap(ks{k});
                addinput(o,vals{:});
            end
            ks = keys(o.outputMap);
            for k=1:numel(ks)
                vals = o.outputMap(ks{k});
                addoutput(o,vals{:});
            end

            % Initialize output to 0
            if o.nrOutputChannels>0
                write(o.hDaq,zeros(1,o.nrOutputChannels));
                o.outputValue = zeros(1,o.nrOutputChannels);
            end
            o.samplerate = o.hDaq.Rate; % Some cards reset to an allowed value
            

            props.samplerate = o.samplerate;
            props.nrInputChannels = o.nrInputChannels;
            props.nrOutputChannels = o.nrOutputChannels;
        end

        function startInput(o)
            % Open a file to store acquired data

            [o.FID,msg] = fopen(o.dataFile,'w'); % Bin file for easy append during the experiment.
            if o.FID==-1
                o.cic.error('STOPEXPERIMENT',sprintf('Could not create file %s (msg: %s)',o.dataFile,msg));
            end
            o.nrTimeStamps = 0;

            % Configure ScansAvailableFcn callback
            if ~isempty(o.hDaq.Channels)
                o.hDaq.ScansAvailableFcn = @(src,event) scansAvailableCallback(o, src, event);
            end


            % Initialize the circular data buffer.
            o.dataBuffer = neurostim.utils.circularBuffer(nan(o.bufferSize*o.hDaq.Rate,numel(o.hDaq.Channels)));
            o.timeBuffer  = neurostim.utils.circularBuffer(nan(o.bufferSize*o.hDaq.Rate,1));
            o.bufferIx = 0;
            o.previousBufferIx =0;
            % Start acquiring.
            start(o.hDaq,"continuous");

        end

        function createMMap(o,pv)
            arguments
                o (1,1) neurostim.plugins.mdaq
                pv.initialize (1,1) logical = false
                pv.writable (1,1) logical = false
                pv.samplerate (1,1) double = o.samplerate
                pv.nrInputChannels (1,1) double = o.nrInputChannels
                pv.filename  = o.mmapFile;
            end
            % Create a memory mapped file for the circular
            % buffer
            nrSamplesToShow =o.bufferSize*pv.samplerate;
            % Initialize it with zeros.
            if pv.initialize
                o.mmapFile = tempname;
                mFid = fopen(o.mmapFile,'w');
                fwrite(mFid,zeros(nrSamplesToShow,1+pv.nrInputChannels),o.precision);
                fclose(mFid);
            else
                o.mmapFile = pv.filename;
            end
            % The circular buffer contains nrSamplesToShow time points
            % and associated values. They are mapped to Data.t and
            % Data.acq respectively.

            o.mmap = memmapfile(o.mmapFile,'Repeat',1,'Format',{o.precision [nrSamplesToShow 1] 't'; o.precision, [nrSamplesToShow pv.nrInputChannels], 'acq'},'Offset',0,'Writable',pv.writable);
        end

        function digitalOut(o,name,value)
            % Set a named digital output channel to the specified value
            % (true/false)
            arguments
                o (1,1) neurostim.plugins.mdaq
                name (1,1) string
                value (1,1) logical

            end
            if o.fake; o.writeToFeed(sprintf('Digital out %s - %d\n',name,value));return;end
            % First map the name to a daq channel
            if ~isKey(o.outputMap,name)
                error('No output channel named %s',name)
            end

            prms = o.outputMap(name);
            channelName = prms{1} + "_" + prms{2}; % e.g. "Dev1_port0/line0";
            [tf,ix]= ismember(channelName,{o.hDaq.Channels.Name});
            if ~tf
                error('Output channel %s has not yet been setup on the DAQ (%s)',name,channelName)
            end
            newOutput = o.outputValue;
            newOutput(ix) =value;
            write(o.hDaq,newOutput);
            o.outputValue = newOutput;
        end

        function beforeExperiment(o)
            if o.fake;return;end
            % Delete lines from the axes
            if ~isempty(o.ax)
                delete(o.ax.Children);
            end
            if numel(o.inputMap)==0 && numel(o.outputMap)==0
                o.writeToFeed('No DAQ channels?')
                return;
            end

            o.writeToFeed('Configuring DAQ ');
            tic
            if o.outputOnly
                configure(o);
            else
                % Input
                if o.useWorker
                    o.writeToFeed('Setting up the worker');
                    % Start the worker queue,
                    setupWorker(o);
                    % Configure on the worker, retrieve parms that may have
                    % changed
                    o.writeToFeed('Configuring DAQ on worker...')
                    parms = sendToWorker(o,"CONFIGURE");
                    o.writeToFeed('Setting up MMap on Client...')
                    createMMap(o,initialize= false,writable=false,filename=parms.filename , nrInputChannels=parms.nrInputChannels,samplerate=parms.samplerate);
                    o.writeToFeed('Starting DAQ ...')
                    sendToWorker(o,"START")
                else
                    configure(o);
                    startInput(o);
                end
            end
            o.startDaq = datetime('now'); % Log on the client
            o.writeToFeed(sprintf('Done in %4.0f s. DAQ Running ',toc));
        end


        function afterTrial(o)
            % Update visual display after the trial to avoid frame drops.
            if o.useWorker && ~isempty(o.future.Error)
                o.cic.error('STOPEXPERIMENT',sprintf('The worker failed (msg: %s)',o.future.Error));
                return
            end
            if o.outputOnly
                if ~isempty(o.ax)
                    delete(o.ax)
                end
            else
                draw(o)
            end
        end

        function draw(o)
            % Draw the input channel data
            if o.fake;return;end
            if ~isempty(o.ax)
                if o.useWorker
                    % Collection runs on a worker.
                    % Read from the mmap file
                    y = o.mmap.Data.acq;
                    t = o.mmap.Data.t;
                    if isempty(y)
                        return;
                    end
                else
                    % Read from the circular buffer directly
                    nrSamplesToShow =o.bufferSize*o.hDaq.Rate-1;
                    stay = (o.bufferIx-nrSamplesToShow):o.bufferIx;
                    y = o.dataBuffer(stay,:);
                    t = o.timeBuffer(stay);
                end


                % Scale each channel to its abs max
                y = y./max(y,[],"ComparisonMethod","abs");
                % Then add 1:N to each channel to space them vertically
                % (flip to match the order of the legend).
                y = y + fliplr(1:size(y,2));

                ks = keys(o.inputMap);
                if isempty(o.ax.Children)
                    % First time, draw
                    h = plot(o.ax,t,y);
                    [h.Tag] = deal(ks{:});
                    title(o.ax,sprintf('%s (%.1fkHz) - %d in, %d out',o.vendor,o.samplerate/1000,o.nrInputChannels,o.nrOutputChannels))
                    legend(h,ks)
                else
                    % Updates, only change x/y data. Supposedly faster?
                    for i=1:numel(ks)
                        set(findobj(o.ax.Children,"Tag",ks{i}),'XData',t,'YData',y(:,i));
                    end
                    title(o.ax,sprintf('%s (%.1fkHz) - %d in, %d out',o.vendor,o.samplerate/1000,o.nrInputChannels,o.nrOutputChannels))
                end
                xlim(o.ax,t(end)-[o.bufferSize 0]) % Show one full bufferSize in seconds.
                ylim(o.ax, [0  size(y,2)+1])    % Show all signals
                drawnow limitrate
            end
        end
        function afterExperiment(o)
            % Stop, flush, save, delete.
            if o.fake;return;end
            if o.keepAliveAfterExperiment;return;end

            if o.useWorker
                sendToWorker(o,"SHUTDOWN");
            else
                shutdown(o);
            end
            o.writeToFeed(sprintf('DAQ data saved to %s', strrep(o.dataFile,'\','/')));
        end

        function shutdown(o)
            if o.isRunning
                stop(o.hDaq)
                flush(o.hDaq)
                pause(1);
                removechannel(o.hDaq,1:numel(o.hDaq.Channels)); % Free
            end
            if ~isempty(o.FID) && o.FID ~=-1
                try
                    fclose(o.FID);
                catch
                end
            end
            delete(o.hDaq);
            o.hDaq= [];
        end

        function setupWorker(o)
            % Setup a communication channel with a parallel worker
            if isempty(gcp('nocreate'))
                parpool("local",1);
            end
            % Create a shared queue for communication
            workerQueueShared = parallel.pool.Constant(@parallel.pool.PollableDataQueue);
            % Retrieve a handle to the queue on the worker to use on the client
            o.sendQueue = fetchOutputs(parfeval(@(x) x.Value, 1, workerQueueShared));
            o.receiveQueue = workerQueueShared.Value;

            % Share the plugin object with the worker. This is a copy of
            % the object, so changes on the client do not  affect the object here.
            o.future = parfeval(@neurostim.plugins.mdaq.acquireAndSaveOnWorker, 0, o.sendQueue,o.receiveQueue, o);
            o.writeToFeed('Waiting for worker...Ctrl-c to abort ')
            [ack,ok] = poll(o.receiveQueue,inf);
            if ~ok || ack~="RUNNING"
                o.cic.error('STOPEXPERIMENT','Failed to setup worker')
                o.future
                cancel(o.future)
            end
            o.writeToFeed('Worker ready.')
        end


        function  T =readBin(o,pv)
            % Read the binary data file and return as a timetable
            % use 'root' to remap  the root ( {'c:\','d:\'} for a recording
            % that saved to c:\ but the data are now stored on d:\/
            % Or use file to specify a complete file name.
            arguments
                o (1,1) neurostim.plugins.mdaq                
                pv.root (1,:) = {}
                pv.file (1,1) string =""
            end
            if pv.file==""
                filename = o.dataFile;
                if ~isempty(pv.root)
                    filename =strrep(filename,pv.root{1},pv.root{2});
                end
            else
                filename = pv.file;
            end
            if ~exist(filename,"file")
                error('Bin file %s does not exist \n',filename);
            end
            fid = fopen(filename,'r'); % Read time stamps plus input channels
            [data] = fread(fid, [o.nrInputChannels+1,inf],['*' o.precision]);
            fclose(fid);
            % Make a timetable
            timestamps  = double(data(1,:)');
            clockTime = seconds(timestamps) + o.triggerTime;
            % Use the startDaq event to determine the neurostim experiment
            % time for each sample.
            [daqTriggerTime,~,~,exptTime]=get(o.prms.startDaq,'withdata',true);
            nsTime = timestamps + seconds(o.triggerTime-daqTriggerTime)+exptTime/1000;
            data = num2cell(data(2:end,:)',1);
            names = keys(o.inputMap);
            T = timetable(clockTime,seconds(nsTime),data{:},'VariableNames',cat(2,'nsTime',names));
        end
    end


    methods (Access=protected)
        function out = sendToWorker(o,code)


            send(o.sendQueue,code);
            [fromWorker,ok] = poll(o.receiveQueue, 15);
            if ok
                %fromWorker
            else
                cancel(o.future)
            end

            if ~isempty(o.future.Error) || strcmpi(o.future.State,'finished')
                o.cic.error('STOPEXPERIMENT','The mdaq worker failed');
                o.future.Error
            end
            if nargout>0
                out = fromWorker;
            end
        end

        function ix= addoutput(o,device,channel,type,settings)
            % Add output channels
            arguments
                o (1,1) neurostim.plugins.mdaq  % The daq plugin
                device (1,1) {mustBeTextScalar}  % Name of the device
                channel  (1,1)                  % Name or number of the channel
                type {mustBeTextScalar}         % Type (voltage)
                settings (1,:) cell             %
            end
            [ch,ix] = addoutput(o.hDaq,device,channel,type);
            if ~isempty(settings)
                % I could not find a way to pass these settings (e.g.
                % Range, TerminalConfig) to addinput, so we have to get the
                % warnign first, then fix it afterwards.
                [~,id] = lastwarn;
                if ismember(id,{'daq:Channel:closestRangeChosen','daqsdk:Internal:vendorDriverCommandFailed'})
                    o.writeToFeed('The DAQ warnings above can be ignored, if your channel settings passed to addChannel correct these issues.')
                end
                set(ch,settings{:});
            end
            o.nrOutputChannels = o.nrOutputChannels +1;
        end


        function ix = addinput(o,device,channel,type,settings)
            % Add input channels
            arguments
                o (1,1) neurostim.plugins.mdaq
                device (1,1) {mustBeTextScalar}  % name of the device
                channel  (1,1)                   % name/number of the channel
                type {mustBeTextScalar}          % measurement type
                settings (1,:) cell             %
            end
            [ch,ix] = addinput(o.hDaq,device,channel,type);
            if ~isempty(settings)
                % I could not find a way to pass these settings (e.g.
                % Range, TerminalConfig) to addinput, so we have to get the
                % warnign first, then fix it afterwards.
                [~,id] = lastwarn;
                if ismember(id,{'daq:Channel:closestRangeChosen','daqsdk:Internal:vendorDriverCommandFailed'})
                    o.writeToFeed('The DAQ warnings above can be ignored, if your channel settings passed to addChannel correct these issues.')
                end
                set(ch,settings{:});
            end
            o.nrInputChannels = o.nrInputChannels +1;
        end


        function scansAvailableCallback(o,src,~)
            % Callback function that is called whenever new scans are
            % available from the device. It logs the data to
            % file, and fills the circular buffer for display.
            % Runs on the worker if useWorker =true
            % In parallle mode, changes to o in this function are not
            % saved.
            % Note that the columns represent the input channels in
            % alphabetiacl order (as in o.inputMap.keys)
            try
                [data,timestamp,tTrigger] = read(src,src.ScansAvailableFcnCount,"OutputFormat","Matrix");
                %% Log to file
                fwrite(o.FID, [timestamp data]', o.precision);
                if timestamp(1)==0
                    % Store the origin of the time axis
                    o.triggerTime = datetime(tTrigger,'convertFrom','datenum');
                end
                %% Update the circular buffer
                if ~isempty(o.postprocess)
                    [data,timestamp] = o.postprocess(data,timestamp,o); % Postprocess with a user-specified function for display
                end
                [nrTmStmps, ~] =size(data);
                o.nrTimeStamps= o.nrTimeStamps + nrTmStmps;
                bufferSamples= numel(o.timeBuffer);
                if nrTmStmps>bufferSamples
                    data = data((end-bufferSamples+1):end);
                    timestamp = timestamp((end-bufferSamples+1):end);
                    nrTmStmps= bufferSamples;
                end
                o.dataBuffer(o.bufferIx + (1:nrTmStmps),:) = data;
                o.timeBuffer(o.bufferIx + (1:nrTmStmps)) = timestamp;

               
                o.bufferIx = o.bufferIx+nrTmStmps;
                if o.useWorker
                    %% Copy to the mmap
                    % We're runnning on the worker: save the circular
                    % buffer to the mmap.
                    o.mmap
                    nrSamplesToShow =o.bufferSize*o.hDaq.Rate-1;
                    ix = (o.bufferIx-nrSamplesToShow):o.bufferIx;
                    o.mmap.Data.t   = o.timeBuffer(ix);
                    o.mmap.Data.acq  = o.dataBuffer(ix,:);
                end
            catch me
                % If anything fails here just stop acquisition. (Otherwise
                % the errors keep piling up in the command window)
                shutdown(o);
                o.cic.error('STOPEXPERIMENT',sprintf('Failure in callback: %s',me.message))
            end
        end
    end

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
            o.ax = findobj(parms.hPnl.Children,"tag","ax");
        end
    end

    methods (Static)

        
        % This function sets up data acquisition and writing on a parallel worker
        % The client (i.e. the mdaq plugin on the main Matlab) sends it messages
        function acquireAndSaveOnWorker(receiveQueue,sendQueue,o)
            % INPUT
            % queue - a pollable data queue
            % hO - handle to the mdaq object
            %o = hO.Value;
            if o.diary
                %Log  the worker for trouble shooting
                diary([o.cic.fullFile '_diary.txt'])
            end
            send(sendQueue,'RUNNING');
            %% Loop waiting for messages from the client
            endExperiment = false;
            while ~endExperiment
                % Wait for a message from the mdaq plugin
                code = poll(receiveQueue, Inf);
                fprintf('Code: %s\n',code)
                ack ='ACK';
                switch (code)
                    case "SHUTDOWN"
                        shutdown(o);
                        endExperiment =true;
                    case "START"
                        start(o);
                    case "CONFIGURE"
                        ack = configure(o);
                        createMMap(o,initialize=true,writable=true); % Iniitialze on worker
                        ack.filename = o.mmapFile;
                    otherwise
                        fprintf('Unknown code %s\n',code)
                end
                send(sendQueue,ack);
            end
            if o.diary
                diary off
            end
        end


        function guiLayout(pnl)
            % Add plugin specific elements
            pnl.Position(4) =250;
            h = uiaxes(pnl,"Tag","ax");
            h.Position = [60 10 530 220];
            xlabel(h,"Time (s)")
            ylabel(h,"")
            title(h,'Watiing for samples....')
        end


        function o = debug(mode)
            % Debug tool to run without other neurostim plugins
            o = neurostim.plugins.mdaq(neurostim.cic);
            o.cic.dirs.output = pwd;
            mkdir(o.cic.fullFile)
            o.bufferSize = 10; % 10 seconds of buffer

            switch upper(mode)
                case 'DS'
                    % This would be setup in the run/experiment file (once)
                    o.vendor = 'directsound'; % Use the soundcard
                    addChannel(o,"mic","input","Audio2",1,"audio")
                    o.useWorker = true;
                    o.diary = true;
                    % Simulate what would happen in an experiment
                case 'MCC'
                    o.vendor = 'MCC';
                    addChannel(o,"portA","input","")
                    beforeExperiment(o); % Setup connection with DAQ
                    for trial=1:20
                        beforeTrial(o);
                        trial %#ok<NOPRT>
                        tic;
                        for j=1:30
                            beforeFrame(o) ;
                            pause(0.01);
                        end
                        afterTrial(o);
                        toc
                    end
                    afterExperiment(o);
                case 'NI'
                    o.vendor = 'NI';
                    addChannel(o,"trial","output","Dev1","port0/line0","Digital")
                    addChannel(o,"stimulus","output","Dev1","port0/line1","Digital")
                    beforeExperiment(o); % Setup connection with DAQ
            end

        end

    end
end
