classdef liquid < neurostim.plugins.feedback
    % Feedback plugin to deliver liquid reward (through MCC).
    
    properties        
        nrDelivered = 0;
        totalDelivered = 0;
        tmr; % Timer to control duration
    end
    
    methods (Access=public)
        function o=liquid(c,name)
            o=o@neurostim.plugins.feedback(c,name);
            o.addProperty('device','mcc');
            o.addProperty('deviceFun','digitalOut');
            o.addProperty('deviceChannel',1);
            o.addProperty('jackpotPerc',1);
            o.addProperty('jackpotDur',1000);
            
        end
        
        function beforeExperiment(o)
            
            %Check that the device is reachable
            if any(hasPlugin(o.cic,o.device))
                %Iniatilise to the closed state.
                close(o);
            else
                o.cic.error('CONTINUE',['Liquid reward added but the ' o.device ' device could not be found.']);
                o.device = 'FAKE';
            end
        end
         
        
    end
    
    methods (Access=protected)
 
        function chAdd(o,varargin)
          p = inputParser;
          p.StructExpand = true; % The parent class passes as a struct
          p.addParameter('duration',Inf);
          p.parse(varargin{:});
      
          % store the duration
          o.addProperty(['item', num2str(o.nItems), 'duration'],p.Results.duration);
        end
      
        function deliver(o,item)
            % Responds by calling the device (through the device fun) to activate liquid reward.
            % This assumes that the device function has the arguments :
            % (channel, value).
            % Not that Mcc and Trellis devices use a Matlab timer to handle the "duration" aspect - this could be inaccurate or interrupt 
            % time-sensitive functions. So best not to use this in the  middle of a trial
            duration = o.(['item', num2str(item) 'duration']);
            if ~strcmpi(o.device,'FAKE')
                if rand*100<o.jackpotPerc
                    o.writeToFeed('Jackpot!!!')
                    duration = o.jackpotDur;                    
                end
                open(o,duration);                
                %Keep track of how much has been delivered.
                o.nrDelivered = o.nrDelivered + 1;
                o.totalDelivered = o.totalDelivered + duration;
            else
                o.writeToFeed(['Fake liquid reward delivered (' num2str(duration) 'ms)']);
            end
        end
        
        function open(o,duration)
            %Not the most elegant way to do this with feval, a
            %function_handle would be more flexible, but ok for now.
           feval(o.deviceFun,o.cic.(o.device),o.deviceChannel,true,duration);                                            
        end
        
        function close(o)
           feval(o.deviceFun,o.cic.(o.device),o.deviceChannel,false);                                           
        end
        
        function report(o)
            %Provide an update of performance to the user.
            o.writeToFeed(horzcat('Delivered: ', num2str(o.nrDelivered), ' (', num2str(round(o.nrDelivered./o.cic.trial,1)), ' per trial); Total duration: ',num2str(o.totalDelivered)));
        end
    end
end