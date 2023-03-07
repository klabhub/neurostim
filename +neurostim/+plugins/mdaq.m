classdef mdaq <  neurostim.plugin
    % Neurostim plugin class that uses the Matlab Data Acquisition Toolbox
    % to generate digital/analog output signals and/or record such signals
    % on the hardware of your choice.
    
    % It is called mdaq to distinguish it from the neurstim.plugins.daq
    % which does not need the Data Acquisition Toolbox
    %
    % PROPERTIES
    %  vendor - DAQ vendor ('NI','MCC','DIRECTSOUND'); see doc daq.
    %  nrWorkers - Number of workers to start in the parallel pool (Use a
    %              negative number to use the thread pool (backgroundPool).
    %
    % See also DAQ
    %
    % BK -  Jan 2022.
    properties (SetAccess = protected)
        inputMap  % Map from named channels to daq input channel properties
        outputMap % Map from named channels to daq output channel properties
        triggerTime  % Time when data acquisition was triggered (time zero)
    end
    properties (Transient)
        hDaq;           % Handle to the daq object.
        pool;           % The pool of workers.
        dataBuffer;     % Circular buffer
        timeBuffer;     % Circular buffer for timestamps
        bufferIx;       % Current end of data in circular buffer.
        previousBufferIx;  % For graphical updates
        FID;            % FID for temporary file storage
        nrTimeStampsWritten;
        isInput;        % Logical address of input channels
        ax =[];         % Handle to the nsGui Axes.
    end

    properties (Dependent)
        inBackground;  % Do we have parallel workers?
        isRunning;
    end

    methods
        function v=get.inBackground(o)
            v = ~isempty(o.pool);
        end
        function v= get.isRunning(o)
            v= ~isempty(o.hDaq) && o.hDaq.Running;
        end
    end

    methods
        function o = mdaq(c)
            if isempty(which('daq'))
                error('The daq plugin relies on the Data Acquisition Toolbox. Please install it first.')
            end

            % Construct a daq plugin.
            o=o@neurostim.plugin(c,'mdaq'); % Fixed name 'mdaq'
            o.addProperty('nrWorkers',0);
            o.addProperty('bufferSize',10); % in seconds.
            o.addProperty('precision','double');
            o.addProperty('outputFile','');
            o.addProperty('fake',false);
            o.addProperty('nrInputChannels',0);
            o.addProperty('nrOutputChannels',0);
            o.addProperty('vendor','');
            o.addProperty('samplerate',1000);
            o.addProperty('startDaq',[],'sticky',true);
            % Setup mapping
            o.inputMap = containers.Map('KeyType','char','ValueType','any');
            o.outputMap = containers.Map('KeyType','char','ValueType','any');
        end


        function addChannel(o,name,inputOrOutput,device, channel,type)
            % Function the user uses to add channels to the acquisition.
            %
            arguments
                o (1,1) neurostim.plugins.mdaq
                name (1,1) {mustBeTextScalar}   % Name for the channel
                inputOrOutput (1,1) {mustBeTextScalar,mustBeMember(inputOrOutput,["input","output"])}
                device (1,1) {mustBeTextScalar} % Device name
                channel (1,1)                   % Channel name or number
                type (1,1) {mustBeTextScalar}   % Channel type
            end
            if inputOrOutput =="input"
                o.inputMap(name) = {device,channel,type};
            else
                o.outputMap(name) ={device,channel,type};
            end
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

            % Connect to the hardware
            % daqreset;  % Problematic if other daq usage has started already?
            list = daqvendorlist; % First time this can take a while.
            if ~ismember(o.vendor,list.ID)
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
                addinput(o,vals{:})
            end
            ks = keys(o.outputMap);
            for k=1:numel(ks)
                vals = o.outputMap(ks{k});
                addinput(o,vals{:})
            end
            o.samplerate = o.hDaq.Rate; % Some cards reset to an allowed value

            % Get a parallel pool
            if o.nrWorkers > 0
                o.pool = gcp('nocreate');
                if isempty(o.pool)
                    o.pool = parpool(o.nrWorkers);
                end
            elseif o.nrWorkers ==-1
                o.pool =backgroundPool;
            end

            % Open a file to store acquired data          
            o.outputFile= [o.cic.fullFile '.bin'];
            [o.FID,msg] = fopen(o.outputFile,'w'); % Bin file for easy append during the experiment.
            if o.FID==-1
                o.cic.error('STOPEXPERIMENT',sprintf('Could not create file %s (msg: %s)',o.outputFile,msg));
            end
            o.nrTimeStampsWritten = 0;

            % Configure ScansAvailableFcn callback
            if ~isempty(o.hDaq.Channels)
                o.hDaq.ScansAvailableFcn = @(src,event) scansAvailableCallback(o, src, event);
            end
            % Initialize the circular data buffer.
            o.dataBuffer = neurostim.utils.circularBuffer(zeros(o.bufferSize*o.hDaq.Rate,numel(o.hDaq.Channels)));
            o.timeBuffer  = neurostim.utils.circularBuffer(zeros(o.bufferSize*o.hDaq.Rate,1));
            o.bufferIx = 0;
            o.previousBufferIx =0;

            % Start acquiring.
            start(o.hDaq,"continuous");
            o.startDaq = datetime('now');
        end

        function beforeFrame(o)
            %  draw(o) - do'nt. This will lead to framedrops.
        end
        function afterTrial(o)
            % Update visual display after the trial
            draw(o)
        end
        function draw(o)
            % Draw the input channel data
             if o.fake;return;end
            if ~isempty(o.ax) && o.previousBufferIx ~= o.bufferIx
                nrSamplesToShow =o.bufferSize*o.hDaq.Rate-1;
                stay = (o.bufferIx-nrSamplesToShow):o.bufferIx;
                y = o.dataBuffer(stay,:);
                % Scale each channel to its abs max
                y = y./max(y,[],"ComparisonMethod","abs");
                % Then add 1:N to each channel to space them vertically
                % (flip to match the order of the legend).
                y = y + fliplr(1:size(y,2));
                t = o.timeBuffer(stay);
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
                end
                xlim(o.ax,o.timeBuffer(o.bufferIx)-[o.bufferSize 0]) % Show one full bufferSize in seconds.
                ylim(o.ax, [0  size(y,2)+1])    % Show all signals           
                drawnow limitrate
            end
        end
        function afterExperiment(o)
            % Stop, flush, save, delete.
            if o.fake;return;end
            if o.isRunning
                stop(o.hDaq)
                flush(o.hDaq)
                pause(1);
                removechannel(o.hDaq,1:numel(o.hDaq.Channels)); % Free 
            end
            fclose(o.FID);
            o.writeToFeed(sprintf('DAQ data saved to %s', strrep(o.outputFile,'\','/')));
            delete(o.hDaq);            
            o.hDaq= [];
        end


        function  T =readBin(o,filename)
            % Read the binary data file and return as a timetable
            arguments
                o (1,1) neurostim.plugins.mdaq
                filename {mustBeTextScalar} = o.outputFile;  %
            end
            fid = fopen(filename,'r'); % Read time stamps plus input channels
            [data] = fread(fid, [o.nrInputChannels+1,inf],['*' o.precision]);
            fclose(fid);
            [~,nrRows]  = size(data);
            assert(nrRows==o.nrTimeStampsWritten,'The timestamps in the bin file (%d) do not match the number (%d) written during the experiment.',nrRows,o.nrTimeStampsWritten);
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

        function addoutput(o,device,channel,type)
            % Add output channels
            arguments
                o (1,1) neurostim.plugins.mdaq  % The daq plugin
                device (1,1) {mustBeTextScalar}  % Name of the device
                channel  (1,1)                  % Name or number of the channel
                type {mustBeTextScalar}         % Type (voltage)
            end
            [~,ix] = addinput(o.hDaq,device,channel,type);
            o.isInput(ix) = false;
            o.nrOutputChannels = o.nrOutputChannels +1;
        end


        function addinput(o,device,channel,type)
            % Add input channels
            arguments
                o (1,1) neurostim.plugins.mdaq
                device (1,1) {mustBeTextScalar}  % name of the device
                channel  (1,1)                   % name/number of the channel
                type {mustBeTextScalar}          % measurement type
            end
            [~,ix] = addinput(o.hDaq,device,channel,type);
            o.isInput(ix) = false;
            o.nrInputChannels = o.nrInputChannels +1;
        end


        function scansAvailableCallback(o,src,event)
            % Callback function that is called whenever new scans are
            % available from the device. It logs the data to 
            % file, and fills the circular buffer for display.
            try
                [data,timestamp,tTrigger] = read(src,src.ScansAvailableFcnCount,"OutputFormat","Matrix");
                %% Log to file
                fwrite(o.FID, [timestamp data]', o.precision);                
                if timestamp(1)==0
                    o.triggerTime = datetime(tTrigger,'convertFrom','datenum');                   
                end
                %% Put in circular buffer
                [nrTimeStamps, ~] =size(data);
                o.nrTimeStampsWritten = o.nrTimeStampsWritten + nrTimeStamps;

                bufferSamples= numel(o.timeBuffer);
                if nrTimeStamps>bufferSamples
                    data = data((end-bufferSamples+1):end);
                    timestamp = timestamp((end-bufferSamples+1):end);
                    nrTimeStamps= bufferSamples;
                end
                o.dataBuffer(o.bufferIx + (1:nrTimeStamps),:) = data;
                o.timeBuffer(o.bufferIx + (1:nrTimeStamps)) = timestamp;
                o.bufferIx = o.bufferIx+nrTimeStamps;
            catch me
                % If anything fails here just stop acquisition. (Otherwise
                % the errors keep piling up in the command window)
                stop(o.hDaq)
                daqreset;
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
            % This would be setup in the run/experiment file (once)
            o.vendor = 'directsound'; % Use the soundcard
            addChannel(o,"mic","input","Audio2",1,"audio")
            addChannel(o,"mic2","input","Audio2",2,"audio")

            % Simulate what would happen in an experiment
            beforeExperiment(o); % Setup connection with DAQ
            for trial=1:10
                beforeTrial(o);
                trial
                tic;
                for j=1:20
                    beforeFrame(o) ;
                    pause(0.01);
                end
                afterTrial(o);
                toc
            end
            afterExperiment(o); 
        end

    end

end
