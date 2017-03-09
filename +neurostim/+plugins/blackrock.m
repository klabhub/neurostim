classdef blackrock < neurostim.plugin
    % Plugin class to add functionality for the blackrock system. 
    % Wrapper around CBMEX.
    
   properties
       fakeConnection@logical=false;
       open@logical
   end
   
   
   methods 
       
       function o=blackrock(c)
           o=o@neurostim.plugin(c,'blackrock');
           o.addProperty('useMCC',true);
           o.addProperty('blackrockClockTime',[]);
           o.addProperty('eventData',[]);
           o.addProperty('continuousData',[]);
           o.addProperty('bufferResetTime',[]);
           o.addProperty('mccChannel',[],'validate',@isnumeric);
           o.addProperty('comments','Neurostim experiment','validate',@ischar);  %String sent to Central at start of experiment, saved with data file and displayed
           o.listenToEvent('BEFOREEXPERIMENT','BEFORETRIAL','AFTERTRIAL','AFTEREXPERIMENT');
       end
       
       
       function beforeExperiment(o,c,evt)
           
           % if using a fake connection, do nothing
           if o.fakeConnection
               return;
           end
           
           %Try to initialise cbmex connection to Blackrock Central
           cbmex('open');
           o.open = true;
           
           %Give Central the filename for saving neural data
           cbmex('fileconfig',c.fullFile,'',0);
           
           %Check that the mcc plugin is enabled
           if o.useMCC
               mcc = c.pluginsByClass('mcc');
               if isempty(mcc)
                   o.writeToFeed('No "mcc" plugin detected. blackrock plugin expects it.');
                   o.useMCC = false;
               else
                   c.mcc.digitalOut(o,o.mccChannel,0);
               end
           end
           
           %Start recording.
           cbmex('fileconfig', c.fullFile, o.comments,1);
           
           %Ensure no data is being cached to Neurostim
           cbmex('trialconfig', 0);
           
           %Log the clock time for later syncing
           o.blackrockClockTime=cbmex('time');
       end
       
       function afterExperiment(o,c,evt)
          o.closeSession();
       end
          
       function closeSession(o)
     
          %Stop recording.
          cbmex('fileconfig', o.cic.fullFile,' ',0);
          
          %Close down cbmex connection
          cbmex('close');
          o.open = false;
          
       end
       
       function beforeTrial(o,c,evt)
           
           %Send a network comment to flag the start of the trial. Could be used for timing alignment.
           cbmex('comment', 255, 0, ['Start_T' num2str(c.trial) '_C' num2str(c.condition)]);
           
           %Send a second trial marker, through digital I/O box (Measurement Computing)
           if o.useMCC
               c.mcc.digitalOut(o,o.mccChannel,1);
           end
       end
       
       
       function afterTrial(o,c,evt)
           
           %Send a network comment to flag the end of the trial. Could be used for timing alignment.
           cbmex('comment', 127, 0, 'Stop');
           
           %Send a second trial marker, through digital I/O box (Measurement Computing)
           if o.useMCC
               c.mcc.digitalOut(o,o.mccChannel,0);
           end
       end
       
       function delete(o)
           if o.open
               closeSession(o);
           end
       end
   end
   
    
    
end