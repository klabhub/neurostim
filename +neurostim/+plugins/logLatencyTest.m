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
            subplot(5,1,1);
            dt = myProp.time-cell2mat(preLog.data);
            histogram(dt); xlabel('Time to log'); hold on;
            plot([median(dt) median(dt)],ylim);
            subplot(5,1,2);
            plot(myProp.trialTime,dt,'.');  ylabel('Time to log'); xlabel('Trial time');
            subplot(5,1,3);
            plot(myProp.time,dt,'.');  ylabel('Time to log'); xlabel('Time since experiment start');
            subplot(5,1,4);
            plot(sampleInds,dt,'.');  ylabel('Time to log'); xlabel('Event number');
            subplot(5,1,5);
            dt = cell2mat(postLog.data)-cell2mat(preLog.data);
            histogram(dt); xlabel('Total time per log'); hold on;
            plot([median(dt) median(dt)],ylim);
        end
        
    end  
end