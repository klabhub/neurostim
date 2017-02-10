classdef starstim < neurostim.stimulus
    % A stimulus that can stimulate electrically using the StarStim device from
    % Neurelectrics. 
    %
    % BK - Feb 2016
    
    
    % Public Get, but set through functions or internally
    properties (SetAccess=protected, GetAccess= public)
        sock;               % Socket for communication with the host.
        tacsTimer@timer =timer;    % Created as needed in o.tacs
    end
    
    % Dependent properties
    properties (Dependent)
        status@char;        % Current status (queries the device)
    end
    
    methods % get/set dependent functions
        function [v] = get.status(o)
            if o.fake
                v = ' Fake OK';
            else
                [ret, v] = MatNICQueryStatus(o.sock);
            end
        end
    end
    
    methods % Public
        
        function disp(o)
            disp(['Starstim Host: ' o.host  ' Status: ' o.status]);
        end
        
        % Constructor. Provide a handle toe CIC, the Starstim host, a 
        % stimulation template and (optional) the fake
        % boolean to simulate a StarStim device).
        function [o] = starstim(c,h,tmplate,fake)
           if nargin<4
                fake= false;
           end            
           o=o@neurostim.stimulus(c,'starstim');   
           
           if isempty(h)
               h = 'localhost';
           end
           o.addProperty('host',h,'validate',@ischar,'SetAccess','protected');
           o.addProperty('template',tmplate,'validate',@ischar,'SetAccess','protected');
           o.addProperty('fake',fake,'validate',@islogical,'SetAccess','protected');
           o.addProperty('z',NaN,'validate',@isnumeric,'SetAccess','protected');
           o.addProperty('channel',[],'validate',@isnumeric);
           o.addProperty('amplitude',[],'validate',@isnumeric);
           o.addProperty('transition',[],'validate',@isnumeric);
           o.addProperty('frequency',[],'validate',@isnumeric);
           
           o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','BEFOREFRAME'});

        end
        
        function beforeExperiment(o,c,evt)
             % Connect to the device, load the template.
            if o.fake
                o.writeToFeed(['Starstim fake conect to ' h]);
            else
                [ret, ~, o.sock] = MatNICConnect(o.host);
                o.checkRet(ret,'Host');
                ret = MatNICLoadTemplate(o.template, o.sock);
                o.checkRet(ret,'Template');
            end
            
            % Delete any remaning timers (if the previous run was ok, there
            % should be none)
            timrs = timerfind('name','starstim.tacs');
            if ~isempty(timrs)
                o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
                delete(timrs)
            end
            
            impedance(o); % Measure starting impedance.
        end

        
        function afterExperiment(o,c,evt)
            timrs = timerfind('name','starstim.tacs');
            if ~isempty(timrs)
                o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
                delete(timrs)
            end
            
            if ~strcmpi(o.status,'CODE_STATUS_STIMULATION_FINISHED')
                stop(o);
            end
            
            impedance(o); % Measure Z after experiment.
            
            
        end

        function beforeFrame(o,c,evt)
          if o.canStimulate
            o.tacs(o.amplitude,o.channel,o.transition,o.duration,o.frequency);
          end
          
        end
    end
    
    
    methods (Access=protected)
        function tacs(o,amplitude,channel,transition,duration,frequency)
            % function tacs(o,amplitude,channel,transition,duration,frequency)
            % Apply tACS at a given amplitude, channel, frequency. The current is ramped
            % up and down in 'transition' milliseconds and will last 'duration'
            % milliseconds (including the transitions).
            
            if duration>0 && isa(o.tacsTimer,'timer') && isvalid(o.tacsTimer) && strcmpi(o.tacsTimer.Running,'off')
                c.error('STOPEXPERIMENT','tACS pulse already on? Cannot start another one');
            end
            
            if o.fake
                o.writeToFeed([ datestr(now,'hh:mm:ss') ': tACS frequency set to ' num2str(frequency) ' on channel ' num2str(channel)]);
            else
                ret = MatNICOnlineFtacsChange (frequency, channel, o.sock);
                o.checkRet(ret,'FtacsChange');
            end
            if o.fake
                o.writeToFeed(['tACS amplitude set to ' num2str(amplitude) ' on channel ' num2str(channel) ' (transition = ' num2str(transition) ')']);
            else
                ret = MatNICOnlineAtacsChange(amplitude, channel, transition, o.sock);
                o.checkRet(ret,'AtacsChange');
            end
            
            if duration ==0
                toc
                stop(o.tacsTimer); % Stop it first (it has done its work)
                delete (o.tacsTimer); % Delete it.
            else
                % Setup a timer to end this stimulation at the appropriate
                % time
                tic
                off  = @(timr,events,obj,chan,trans) tacs(obj,0*chan,chan,trans,0,0);
                o.tacsTimer  = timer('name','starstim.tacs');
                o.tacsTimer.StartDelay = (duration-2*transition)/1000;
                o.tacsTimer.ExecutionMode='SingleShot';
                o.tacsTimer.TimerFcn = {off,o,channel,transition};
                start(o.tacsTimer);
            end
            
        end
        
        function start(o)
            % Trigger the template that is currently loaded.
            if o.canStimulate
                if o.fake
                    o.writeToFeed('Start Stim');
                else
                    ret = MatNICStartStimulation(o.sock);
                    o.checkRet(ret,'Trigger');
                end
            end
        end
        
        function stop(o)
            % Stop the current template running
            if o.fake
                o.writeToFeed('Stimulation stopped');
            else
                ret = MatNICAbortStimulation(o.sock);
            end
        end
                
        function impedance(o)
            % Measure and store impedance.
            if o.fake
                impedance = rand;
            else
                [ret,impedance] = MatNICGetImpedance(o.sock);
                o.checkRet(ret,'Impedance')
            end
            o.z = impedance;  % Update the impedance.          
        end
        
        function checkRet(o,ret,msg)
            % Check a return value and display a message if something is
            % wrong.
            if ret<0
                o.cic.error('STOPEXPERIMENT',['StarStim failed: Stauts ' o.status ':  ' num2str(ret) ' ' msg]);
            end
        end
        
        function ok = canStimulate(o)
            % Check status to see if we can stimulate now.
            if o.fake
                ok = true;
            else
                ok = strcmpi(o.status,'CODE_STATUS_STIMULATION_READY');
            end
        end        
    end
    
    
end