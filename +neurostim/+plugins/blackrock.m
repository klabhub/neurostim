classdef blackrock < neurostim.plugin
    % plugin class to add functionality for the blackrock system. 
    % Wrapper around CBMEX.
    
   properties
       fakeConnection@logical=false;
   end
   
   
   methods 
       
       function o=blackrock
           o=o@neurostim.plugin('blackrock');
           o.addProperty(blackrockClockTime,[],[],[],'private');
           o.addProperty(eventData,[],[],[],'private');
           o.addProperty(continuousData,[],[],[],'private');
           o.addProperty(bufferResetTime,[],[],[],'private');
           o.addProperty(mccChannel,[],[],@isnumeric)
           o.listenToEvent({'BEFOREEXPERIMENT','BEFORETRIAL','AFTERFRAME','AFTERTRIAL','AFTEREXPERIMENT'});
       end
       
       
       function beforeExperiment(o,c,evt)
           % if using a fake connection, do nothing
           if o.fakeConnection
               return;
           end
           cbmex('open');
           cbmex('fileconfig',fullfile,'',0);
           o.blackrockClockTime=cbmex('time');
           cbmex('trialconfig', 1);
           o.cic.digitalOut(o,o.mccChannel,0);
       end
       
       function afterExperiment(o,c,evt)
          cbmex('trialconfig', 0);
          cbmex('close'); 
       end
       
       function beforeTrial(o,c,evt)
           
           cbmex('comment', 0, 0, ['TrialStart_T' num2str(c.trial) '_C' num2str(c.condition)])
           o.cic.digitalOut(o,o.mccChannel,1);
           
       end
       
%        function afterFrame(o,c,evt)
%            [o.eventData, o.bufferResetTime, o.continuousData] = cbmex('trialdata', 1);
%        end
       
       function afterTrial(o,c,evt)
%            [o.eventData, o.bufferResetTime, o.continuousData] = cbmex('trialdata', 1);
           cbmex('comment', 0, 0, 'TrialStop')
           o.cic.digitalOut(o,o.mccChannel,0);
           
       end
   end
   
    
    
end