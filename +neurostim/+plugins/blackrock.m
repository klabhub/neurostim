classdef blackrock < neurostim.plugins.ePhys
    % Plugin class to add functionality for the blackrock system.
    % Wrapper around CBMEX.
    
    methods (Access = public)
        
        function o=blackrock(c)
            %Class constructor
            
            %Object initialisation
            o=o@neurostim.plugins.ePhys(c);
            o.addProperty('eventData',[]);
            o.addProperty('continuousData',[]);
            o.addProperty('bufferResetTime',[]);
                      
        end
        
        function delete(o)
            if o.open
                closeSession(o);
            end
        end
        
    end
    
    methods (Access = protected)
        
        function startRecording(o)
            
            % if using a fake connection, do nothing
            if o.fakeConnection
                return;
            end
            
            %Try to initialise cbmex connection to Blackrock Central
            cbmex('open');
            o.connectionStatus = true;
            
            %Give Central the filename for saving neural data
            cbmex('fileconfig',o.cic.fullFile,'',0);
            
            %Check that the mcc plugin is enabled
            if o.useMCC
                mcc = o.cic.pluginsByClass('mcc');
                if isempty(mcc)
                    o.writeToFeed('No "mcc" plugin detected. blackrock plugin expects it.');
                    o.useMCC = false;
                else
                    c.mcc.digitalOut(o,o.mccChannel,0);
                end
            end
            
            %Start recording.
            cbmex('fileconfig', o.cic.fullFile, o.startMsg,1);
            
            %Ensure no data is being cached to Neurostim
            cbmex('trialconfig', 0);
            
            %Log the clock time for later syncing
            o.clockTime = cbmex('time');
            
        end
        
        function stopRecording(o)
            
            closeSession(o)     
        end 
        
        function closeSession(o)
            
            %Stop recording.
            cbmex('fileconfig', o.cic.fullFile,' ',0);
            
            %Close down cbmex connection
            cbmex('close');
            o.connectionStatus = false;
        end 
        
        function startTrial(o)
            
            %Send a network comment to flag the start of the trial. Could be used for timing alignment.
            o.trialInfo = ['Start_T' num2str(o.cic.trial) '_C' num2str(o.cic.condition)];
            cbmex('comment', 255, 0, o.trialInfo);
            
            %Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o,o.mccChannel,1);
            end
        end        
        
        function stopTrial(o)
            
            %Send a network comment to flag the end of the trial. Could be used for timing alignment.
            o.trialInfo = ['Trial' num2str(o.cic.trial) 'complete'];
            cbmex('comment', 127, 0, o.trialInfo);
            
            %Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o,o.mccChannel,0);
            end
        end
                
    end   
end