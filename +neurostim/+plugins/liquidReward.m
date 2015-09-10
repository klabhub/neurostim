classdef liquidReward < neurostim.plugins.reward
    properties
        mccChannel = 1;
    end
    
    
    methods (Access=public)
        function o=liquidReward
            o=o@neurostim.plugins.reward;
        end
        
        function afterTrial(o,c,evt)
            a=strcmpi({o.queue.when},'AFTERTRIAL');
            if any(a)
                b=[o.queue.response]==1;
                totalDur = sum([o.queue(a&b).duration]);
                o.activateReward(1,totalDur);
            end
            o.queue(a)=[];
        end
    end
    
    methods (Access=protected)
        

        
        function activateReward(o,response,varargin)
            % activateReward(o,response,duration)
            duration = varargin{1};
            
            o.cic.mcc.digitalOut(o.mccChannel,true,duration);
        end
        
    end
        
    
    
end