classdef reward < neurostim.plugin
   properties
       answerCorrect;
       answerIncorrect;
   end
   
   
   methods (Access=protected)
       function o=reward
           o=o@neurostim.plugin('reward');
           o.addProperty('type','SOUND');
           o.addProperty('duration',10);
           o.listenToEvent('BEFOREEXPERIMENT')
           
       end
       
       function beforeExperiment(o,c,evt)
          if strcmpi(o.type,'sound')
              InitializePsychSound(1);
              
          end
              
           
       end
       
       
   end
   
   methods (Access=public)
       function GetReward(type,dur)
          % function GetReward(type,dur)
          % type - type of reward (from 'SOUND','LIQUID'...)
          % dur - duration of reward (ms)
          
          switch lower(type)
              case 'sound'
                  
                  
              case 'liquid'
                  
                  
          end
          
          
       end
       
       
       function soundReward(correct,incorrect)
           
       end
   end
    
    
end