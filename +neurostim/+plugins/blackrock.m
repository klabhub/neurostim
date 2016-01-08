classdef blackrock < neurostim.plugin
    % plugin class to add functionality for the blackrock system. 
    % Wrapper around CBMEX.
    
   properties
       dataFile@char = 'test';
       fakeConnection@logical=false;
   end
   
   
   methods 
       
       function o=blackrock
           o=o@neurostim.plugin('blackrock');
           o.addProperty(blackrockClockTime,[],[],[],'private');
           o.addProperty(eventData,[],[],[],'private');
           o.addProperty(continuousData,[],[],[],'private');
           o.addProperty(bufferResetTime,[],[],[],'private');
           o.listenToEvent({'BEFOREEXPERIMENT','BEFORETRIAL','AFTERFRAME','AFTERTRIAL','AFTEREXPERIMENT'});
       end
       
       
       function beforeExperiment(o,c,evt)
           % if using a fake connection, do nothing
           if o.fakeConnection
               return;
           end
           [connection instrument]=cbmex('open');
           cbmex('fileconfig',['C:\temp\' o.dataFile],'',0);
           o.blackrockClockTime=cbmex('time');
           cbmex('trialconfig', 1);
       end
       
       function afterExperiment(o,c,evt)
          cbmex('trialconfig', 0);
          cbmex('close'); 
       end
       
       function beforeTrial(o,c,evt)
           
           cbmex('comment', 0, 0, ['TrialStart_T' num2str(c.trial) '_C' num2str(c.condition)])
           
           
       end
       
%        function afterFrame(o,c,evt)
%            [o.eventData, o.bufferResetTime, o.continuousData] = cbmex('trialdata', 1);
%        end
       
       function afterTrial(o,c,evt)
%            [o.eventData, o.bufferResetTime, o.continuousData] = cbmex('trialdata', 1);
           cbmex('comment', 0, 0, 'TrialStop')
           
           
       end
   end
   
    
    
end