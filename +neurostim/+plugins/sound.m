classdef sound < neurostim.plugin
   properties (Access=protected)
       paHandle
   end
   
   
   methods (Access=public)
       function o=sound
           o=o@neurostim.plugin('sound');
           o.listenToEvent({'BEFOREEXPERIMENT', 'AFTEREXPERIMENT'});
       end
   
   function beforeExperiment(o,c,evt)
   
   % Sound initialization
   InitializePsychSound(1);
   o.paHandle = PsychPortAudio('Open');
   
   o.audioBufferAllocation;
   end
   
   function afterExperiment(o,c,evt)
            PsychPortAudio('Close', o.paHandle);
   end
   
   function audioBufferAllocation(o)
      %to be overwritten in subclasses 
   end
   
   
   end
    
    
end