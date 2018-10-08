classdef logLatencyTest < neurostim.plugin
    % Calculates the delay from setting a parameter to the time at which it
    % is logged.
      
    properties (Access=protected)

    end
    
    properties

    end
    
    methods (Access = public)
        function o = logLatencyTest(c,name)
            o = o@neurostim.plugin(c,name);

            o.addProperty('myLoggedProp',[],'validate',@isnumeric);
            o.addProperty('preLogTime',[],'validate',@isnumeric);
            o.addProperty('postLogTime',[],'validate',@isnumeric);
            o.addProperty('dataSize',[1 1],'validate',@isnumeric);
        end
              
        function beforeFrame(o)
            o.preLogTime = GetSecs*1000;
            o.myLoggedProp = rand(o.dataSize);
            o.postLogTime = GetSecs*1000;
        end

        function results(o)
            [preLog.data,preLog.trial,preLog.trialTime,preLog.time] = get(o.prms.preLogTime);
            [myProp.data,myProp.trial,myProp.trialTime,myProp.time] = get(o.prms.myLoggedProp);
            [postLog.data,postLog.trial,postLog.trialTime,postLog.time] = get(o.prms.postLogTime);
            sampleInds = 1:numel(preLog.data);
            kill = cellfun(@isempty,preLog.data);
            fNames = fieldnames(preLog);
            for i=1:numel(fNames)
                preLog.(fNames{i})(kill) = [];
                myProp.(fNames{i})(kill) = [];
                postLog.(fNames{i})(kill) = [];
            end
            sampleInds(kill) = [];
            
            figure
            subplot(2,1,1);
            dt = myProp.time-cell2mat(preLog.data);
            histogram(dt); xlabel('Time to log (ms)'); hold on;
            plot([median(dt) median(dt)],ylim);
            
            subplot(2,1,2);
            dt = cell2mat(postLog.data)-cell2mat(preLog.data);
            histogram(dt); xlabel('Total time per log (ms)'); hold on;
            plot([median(dt) median(dt)],ylim);
            
            %By trial time
            figure
            subplot(3,2,1);
            plot(myProp.trialTime,dt,'.'); 
            ylabel('Time to log'); xlabel('Trial time (ms)');
            subplot(3,2,2);
            bins = {(min(myProp.trialTime):100:max(myProp.trialTime)),linspace(0, max(dt),200)};
            n = hist3([myProp.trialTime,dt],bins); 
            imagesc(bins{1},bins{2},n'); ylabel('Time to log (ms)');set(gca,'ydir','normal');xlabel('Trial time (ms)'); hold on;

           
            %By experiment time
            subplot(3,2,3);
            myProp.time = myProp.time-myProp.time(1);
            plot(myProp.time,dt,'.');  ylabel('Time to log (ms)'); xlabel('Time since experiment start (ms)'); hold on;
            plot(myProp.time,movmedian(dt,10),'linewidth',4);
            subplot(3,2,4);
            bins = {(min(myProp.time):100:max(myProp.time)),linspace(0, max(dt),200)};
            n = hist3([myProp.time,dt],bins);
            imagesc(bins{1},bins{2},n'); ylabel('Time to log (ms)');set(gca,'ydir','normal');xlabel('Time since experiment start (ms)');  hold on;
            
            subplot(3,2,5);
            plot(sampleInds,dt,'.');  ylabel('Time to log (ms)'); xlabel('Event number'); hold on;
            plot(sampleInds,movmedian(dt,10),'linewidth',4);
            subplot(3,2,6);
            bins = {(min(sampleInds):100:max(sampleInds)),linspace(0, max(dt),200)};
            n = hist3([sampleInds',dt],bins);
            imagesc(bins{1},bins{2},n'); ylabel('Time to log (ms)');set(gca,'ydir','normal');xlabel('Event Number'); hold on;
            

        end
        
    end  
end