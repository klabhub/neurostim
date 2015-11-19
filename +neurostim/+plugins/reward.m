classdef reward < neurostim.plugin
    % Simple reward class which presents rewards if requested by the
    % notification event getReward.
    events
        GIVEREWARD;
    end
    
    properties
        
    end
    
    properties (SetObservable, AbortSet)
        rewardAnswer@logical=true;
    end
    
    properties (Access=protected)
        queue = [];
    end
    
    methods (Access=public)
        function o=reward(name)
            o=o@neurostim.plugin(name);
            
            o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','GIVEREWARD','AFTERTRIAL','AFTERFRAME'})
            
            o.addProperty('duration',100,[],@isnumeric);
            o.addProperty('when','IMMEDIATE',[],@(x)ischar(x)&&any(strcmpi(x,{'IMMEDIATE','AFTERTRIAL'}))); %
            o.addProperty('respondTo',{'correct','incorrect'},[],@iscellstr);
        end  
    end
    
    methods (Access=public)
        
        
        function beforeExperiment(o,c,evt)
        end
        
        function afterFrame(o,c,evt)
            deliverQueued(o,'IMMEDIATE');
        end
        
        function afterExperiment(o,c,evt)
            deliverQueued(o,'AFTEREXPERIMENT');
        end
        
        function afterTrial(o,c,evt)
            deliverQueued(o,'AFTERTRIAL');
        end
        
        function giveReward(o,c,evt)
            % function giveReward(o,c,evt)
            if (any(strcmpi(o.respondTo,'correct')) && o.rewardAnswer) ||...
                    (any(strcmpi(o.respondTo,'incorrect')) && ~o.rewardAnswer)
                % if respond to correct (and answer is correct) or respond
                % to incorrect (and answer is incorrect)
                o.addToQueue(o.when,o.duration);
            end
        end
        
    end
    
    
    methods (Access=protected)
        
        function addToQueue(o,when,duration)
            % adds rewardData specifics to queue for later use.
            a = numel(o.queue);
            o.queue(a+1).response = o.rewardAnswer;
            o.queue(a+1).when = when;
            o.queue(a+1).duration=duration;
        end
        
        function deliverReward(o,response,varargin)
            % deliverReward(o,response,varargin)
            % wrapper for deliverReward function in subclasses.
            % In subclass, this should create and give reward immediately.
%             disp(['Reward ' num2str(response) ' would be given now.']);
        end
        
        function deliverQueued(o,scheduleType)
            
            %Traverse queue and deliver any rewards that should be
            %delivered now, then remove from queue.
            if numel(o.queue)>0
                for these = find(strcmpi({o.queue.when},scheduleType))
                    o.deliverReward(o.queue(these).response,o.queue(these).duration);
                end
                o.queue(these)=[];
            end
        end
    end
    
    
end