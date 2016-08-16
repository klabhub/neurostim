classdef egiNetStation < neurostim.plugin
    % Plugin class to add functionality for the EGI system. 
    % Wrapper around NetStation
    % http://docs.psychtoolbox.org/NetStation
    % Jacob Duijnhouwer 20160816
    
   properties (SetAccess=protected,GetAccess=public)
       open@logical=false;
   end
   methods  
       function o=egiNetStation(c)
           o=o@neurostim.plugin(c,'egiNetStation');
           o.addProperty('host','10.10.10.42','SetAccess','public');
           o.addProperty('port','55513','SetAccess','public');
           o.addProperty('syncTolMs',2.5,'SetAccess','public');
           o.listenToEvent({'BEFOREEXPERIMENT','BEFORETRIAL','AFTERTRIAL','AFTEREXPERIMENT'});
       end
       function beforeExperiment(o,c,evt)
           % if using a fake connection, do nothing
           if o.fakeConnection
               return;
           end
           %Try to initialise cbmex connection to Blackrock Central
           [status,errstr]=NetStation('Connect', o.host, o.port);
           o.open=status==0;
           if ~o.open
               warning('a:b',[mfilename ' could not connect to EGI Net Station because:\n\t"' errstr '"']);
           else
               NetStation('Synchronize',o.syncTolMs);
               NetStation('StartRecording');
               NetStation('Event','BEXP',GetSecs,0.001,'BEXP',datestr(now));
           end
       end
       function afterExperiment(o,c,evt)
           if o.open
               NetStation('Event','AEXP',GetSecs,0.001,'AEXP',datestr(now));
               o.closeSession();
           end
       end
       function closeSession(o)
           if o.open
               NetStation('FlushReadbuffer');
               NetStation('StopRecording');
               NetStation('Disconnect');
               o.open=false;
           end
       end
       function beforeTrial(o,c,evt)
           if o.open
               %Send a network comment to flag the start of the trial. Could be used for timing alignment.
               NetStation('Event','BTRL',GetSecs,0.001,'BTRL',['Start_T' num2str(c.trial) '_C' num2str(c.condition)]);
           end
       end
       function afterTrial(o,c,evt)
           if o.open
               %Send a network comment to flag the start of the trial. Could be used for timing alignment.
               NetStation('Event','ATRL',GetSecs,0.001,'ATRL',['Stop_T' num2str(c.trial) '_C' num2str(c.condition)]);
               NetStation('FlushReadbuffer');  % TODO 666 Not sure when this should be done, if it's important, or if it takes long at. Will look into this (jacob 20160816)
           end
       end
       function delete(o)
           closeSession(o);
       end
   end
end