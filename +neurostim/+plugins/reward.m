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
           o=o@neurostim.plugin(['reward_' name]);
           
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
           if isstruct(o.queue)
               a=strcmpi({o.queue.when},'IMMEDIATE');
               if any(a)
                   for b = 1:sum(a)
                       o.activateReward(o.queue(a(b)).response,o.queue(a(b)).duration);
                   end
               end
               o.queue(a)=[];
           end
       end
       
       function afterExperiment(o,c,evt)
       end
       
       function afterTrial(o,c,evt)
           if isstruct(o.queue)
           a=strcmpi({o.queue.when},'AFTERTRIAL');
           if any(a)
               for b = 1:sum(a)
                   o.activateReward(o.queue(a(b)).response,o.queue(a(b)).duration);
               end
           end
           o.queue(a)=[];
           end
       end
               
       
       function giveReward(o,c,evt)
           % function giveReward(o,c,evt)
               if (any(strcmpi(o.respondTo,'correct')) && o.rewardAnswer) ||...
                       (any(strcmpi(o.respondTo,'incorrect')) && ~o.rewardAnswer)
                   % if respond to correct (and answer is correct) or respond
                   % to incorrect (and answer is incorrect)
                   o.rewardQueue(o.when,o.duration);
               end
       end
       
   end
   
   
   methods (Access=protected)
       
       function rewardQueue(o,when,duration)
           % adds rewardData specifics to queue for later use.
           a = numel(o.queue);
           o.queue(a+1).response = o.rewardAnswer;
           o.queue(a+1).when = when;
           o.queue(a+1).duration=duration;
       end
       
              function activateReward(o,response,varargin)
           % activateReward(o,response,varargin)
           % wrapper for activateReward function in subclasses.
           % In subclass, this should create and give reward immediately.
       end

           
   end
    
    
end