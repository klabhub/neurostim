classdef liquidReward < neurostim.plugins.reward
    properties
        mccChannel = 1;
        mcc
    end
    
    
    methods (Access=public)
        function o=liquidReward(name)
            o=o@neurostim.plugins.reward(name);
            o.listenToEvent('BEFORETRIAL');
        end
        
        function beforeTrial(o,c,evt)
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(c,'neurostim.plugins.mcc');
            if numel(o.mcc)==1
                o.mcc = o.mcc{1};
            else
                error('Liquid reward added but no MCC plugin added (or, more than one added - currently not supported)');
            end
        end
    end
   
    
    methods (Access=protected)
        
        function addToQueue(o,when,duration)
            % Overloading this function to add together liquid rewards that
            % are to be delivered at the same time.
            
            %Check for an existing reward for the scheduled time
            createNew = true;
            nQueued = numel(o.queue);
            if nQueued>0
                thisRew = strcmpi({o.queue.when},when);
                if any(thisRew) && o.rewardAnswer
                    %Add the new duration to the old.
                    o.queue(thisRew).duration=o.queue(thisRew).duration+duration;
                    createNew = false;
                end
            end
            
            if createNew
                %Create a new entry in the queue.
                o.queue(nQueued+1).response = o.rewardAnswer;
                o.queue(nQueued+1).when = when;
                o.queue(nQueued+1).duration=duration;
            end
        end
        
        function deliverReward(o,response,varargin)
            % deliverReward(o,response,duration)
            % Responds by calling the MCC plugin to activate liquid reward.
            % This currently uses the timer() function for duration, which
            % may be inaccurate or interrupt time-sensitive functions.
            if response
                duration = varargin{1};
                if duration>0 % if duration is not 0
                    o.mcc.digitalOut(o.mccChannel,true,duration);
                end
            end
        end
    end
    
    
    
end