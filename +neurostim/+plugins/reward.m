classdef reward < neurostim.plugin
    % Simple reward class which presents rewards if requested by the
    % notification event getReward.
    events
        GETREWARD;
    end
    
   properties
       soundCorrectFile;
       soundIncorrectFile;
       soundCorrect;
       soundIncorrect;
       mccChannel;
       correctBuffer;
       incorrectBuffer;
   end
   
   properties (SetObservable, AbortSet)
       rewardData = struct('type','SOUND','dur',100,'when','AFTERTRIAL','respondTo',{'correct','incorrect'},'answer',true)
   end
   
   properties (Access=protected)
      paHandle;
      queue = [];
   end
   
   methods (Access=public)
       function o=reward
           o=o@neurostim.plugin('reward');
           
           o.listenToEvent({'BEFOREEXPERIMENT','AFTEREXPERIMENT','GETREWARD','AFTERTRIAL','AFTERFRAME'})
           o.soundCorrectFile = 'nsSounds\sounds\correct.wav';
           o.soundIncorrectFile = 'nsSounds\sounds\incorrect.wav';
           o.addPostSet('rewardData',[]);
       end
       
       
       
   end
   
   methods (Access=public)
       
       
       function beforeExperiment(o,c,evt)
          if any(arrayfun(@(n) strcmpi(n.type,'sound'),o.rewardData))    %if sound is set, initialise
              InitializePsychSound(1);
              o.paHandle = PsychPortAudio('Open');
              [y,~] = audioread(o.soundCorrectFile);
              
              if size(y,2) == 1
                o.soundCorrect = [y'; y'];
              else
                  o.soundCorrect = y';
              end
              
              [y,~] = audioread(o.soundIncorrectFile);
              
              if size(y,2) == 1
                o.soundIncorrect = [y'; y'];
              else
                  o.soundIncorrect = y';
              end
              
              o.correctBuffer = PsychPortAudio('CreateBuffer',o.paHandle,o.soundCorrect);
              o.incorrectBuffer = PsychPortAudio('CreateBuffer',o.paHandle,o.soundIncorrect);
              
          end
       end
       
       function afterFrame(o,c,evt)
           a = arrayfun(@(n)strcmpi(n.when,'immediate'),o.queue);
           if any(a)
               for b = 1:sum(a)
                   if strcmpi(o.queue(b).type,'SOUND')
                       soundReward(o,o.queue(b).response);
                   end
                   if strcmpi(o.queue(b).type,'LIQUID')
                       liquidReward(o,o.queue(b).response);
                   end
                   o.queue(b) = [];
               end
           end
       end
       
       function afterExperiment(o,c,evt)
           if any(arrayfun(@(n) strcmpi(n.type,'sound'),o.rewardData))   %if sound was set, close.
               PsychPortAudio('Close', o.paHandle);
           end
       end
       
       function afterTrial(o,c,evt)
           a = arrayfun(@(n)strcmpi(n.when,'aftertrial'),o.queue);
          if any(a)
              remove = [];
               for b = 1:sum(a)
                   if strcmpi(o.queue(b).type,'SOUND')
                       soundReward(o,o.queue(b).response);
                       remove = [remove b];
                   end
                   if strcmpi(o.queue(b).type,'LIQUID')
                       liquidReward(o,o.queue(b).response);
                       remove = [remove b];
                   end
               end
               o.queue(remove) = [];
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
%            display(['o.name is ' o.name]);
           for a = 1:max(size({o.rewardData.type}))
               if (any((strcmpi(o.rewardData(a).respondTo,'correct')) && o.rewardData(a).answer)) ||...
                       (any(strcmpi(o.rewardData(a).respondTo,'incorrect') && ~o.rewardData(a).answer))
                   % if respond to correct (and answer is correct) or respond
                   % to incorrect (and answer is incorrect)
                   o.rewardQueue(o.rewardData(a));
               end
           end
       end
       
   end
   
   
   methods (Access=protected)
       
       function rewardQueue(o,rewardData)
           % adds rewardData specifics to queue for later use.
           a = numel(o.queue);
           o.queue(a+1).response = rewardData.answer;
           o.queue(a+1).type = rewardData.type;
           o.queue(a+1).when = rewardData.when;
       end
       
       function soundReward(o,response)
           % function soundReward(o,response)
           % Fills buffer with sound and conducts immediate playback.
           % Inputs:
           % response - true/false, indicates whether to give a correct or
           % incorrect sound response.
           if response
               PsychPortAudio('FillBuffer', o.paHandle,o.correctBuffer);
           else
               PsychPortAudio('FillBuffer', o.paHandle, o.incorrectBuffer);
           end
           PsychPortAudio('Start',o.paHandle);
       end
       
       function liquidReward(o,response)
           % function liquidReward(o,response)
           % delegates to the MCC
           if response
               
           else
               
           end
               
       end
           
   end
    
    
end