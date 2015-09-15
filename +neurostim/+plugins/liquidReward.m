classdef liquidReward < neurostim.plugins.reward
    properties
        mccChannel = 1;
    end
    
    
    methods (Access=public)
        function o=liquidReward(name)
            o=o@neurostim.plugins.reward(name);
        end
        
        function afterTrial(o,c,evt)
            if isstruct(o.queue)
            a=strcmpi({o.queue.when},'AFTERTRIAL');
            if any(a)
                % sum up the reward durations for all correct responses
                b=[o.queue.response]==1;
                totalDur = sum([o.queue(a&b).duration]);
                o.activateReward(1,totalDur);
            end
            o.queue(a)=[];
            end
        end
    end
    
    methods (Access=protected)
        

        
        function activateReward(o,response,varargin)
            % activateReward(o,response,duration)
            % Responds by calling the MCC plugin to activate liquid reward.
            % This currently uses the timer() function for duration, which 
            % may be inaccurate or interrupt time-sensitive functions.
            if response
                duration = varargin{1};
                if duration>0 % if duration is not 0
                    try
                    o.cic.mcc.digitalOut(o.mccChannel,true,duration);
                    catch ME
                        if strcmpi(ME.identifier,'MATLAB:NoSuchMethodOrField')
                            warning('MCC does not exist in CIC.')
                        end
                    end
                end
            end
        end
        
    end
        
    
    
end