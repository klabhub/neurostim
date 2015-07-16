classdef reward < neurostim.plugin
    
   properties
       soundCorrect;
       soundIncorrect;
       soundReady = false;
   end
   
   properties (SetObservable, AbortSet)
       rewardData = struct('type','SOUND','dur',100,'when','IMMEDIATE','respondTo',{'correct','incorrect'},'answer',true)
   end
   
   properties (Access=protected)
      paHandle; 
   end
   
   methods (Access=protected)
       function o=reward
           o=o@neurostim.plugin('reward');
           
           o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','GETREWARD','AFTERTRIAL'})
       end
       
       
       
   end
   
   methods (Access=public)
       
       
       function beforeExperiment(o,c,evt)
          if any(arrayfun(@(n) strcmpi(o.rewardData(n).type,'sound'),1:numel(o.rewardData)))    %if sound is set, initialise
              InitializePsychSound(1);
              o.paHandle = PsychPortAudio('Open');
          end
       end
       
       function afterExperiment(o,c,evt)
           if any(arrayfun(@(n) strcmpi(o.rewardData(n).type,'sound'),1:numel(o.rewardData)))   %if sound was set, close.
               PsychPortAudio('Close', o.paHandle);
           end
       end
       
       function afterTrial(o,c,evt)
           if o.soundReady && any(arrayfun(@(n) strcmpi(o.rewardData(n).type,'sound'),1:numel(o.rewardData)))  % if sound is ready and was set
               PsychPortAudio('Start', o.paHandle);
               o.soundReady = false;    %reset soundReady flag.
           end
           
       end
               
       
       function getReward(o,c,evt)
           % function getReward(o,c,evt)
           % o.rewardData should have:
           % type - type of reward (from 'SOUND','LIQUID'...)
           % dur - duration of reward (ms)
           % when - immediate or aftertrial
           % respondTo - cell array of 'correct', 'incorrect' to respond to.
           % answer - true/false for correct/incorrect.
           for a = 1:max(size(o.rewardData))
               if (any(strcmpi(o.rewardData(a).respondTo,'correct')) && o.rewardData(a).answer) ||...
                       (any(strcmpi(o.rewardData(a).respondTo,'incorrect')) && ~o.rewardData(a).answer)
                   % if respond to correct (and answer is correct) or respond
                   % to incorrect (and answer is incorrect)
                   
                   if any(strcmpi(o.rewardData(a).type,'sound'))   % if respond to sound, call function
                       o.soundReward(o.rewardData(a));
                   end
                   
                   if any(strcmpi(o.rewardData(a).type,'liquid')) && o.rewardData(a).answer
                       o.liquidReward(o.rewardData(a));
                   end
                   
                   
               end
           end
       end
       
   end
   
   
   methods (Access=protected)
       
       function soundReward(o,rewardData)
           % function soundReward(o,rewardData)
           % Fills buffer with sound, conducts playback if immediate is
           % set.
           % Inputs:
           % rewardData - the specific rewardData struct.
           if rewardData.answer
%                PsychPortAudio('FillBuffer', o.paHandle, o.soundCorrect);
           else
%                PsychPortAudio('FillBuffer', o.paHandle, o.soundIncorrect);
           end
           
           if strcmpi(rewardData.when,'IMMEDIATE')
%                PsychPortAudio('Start', o.paHandle);
           elseif strcmpi(rewardData.when,'AFTERTRIAL')
               o.soundReady = true;
           end
           
       end
       
       function liquidReward(o,rewardData)
           
       end
           
   end
    
    
end