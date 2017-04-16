classdef liquid < neurostim.plugins.feedback
    % Feedback plugin to deliver liquid reward (through MCC).
    
    properties
        mcc = [];
        nrDelivered = 0;
        totalDelivered = 0;
    end
    
    methods (Access=public)
        function o=liquid(c,name)
            o=o@neurostim.plugins.feedback(c,name);
            o.addProperty('mccChannel',9);
            o.addProperty('jackpotPerc',1);
            o.addProperty('jackpotDur',1000);
            
        end
        
        function beforeExperiment(o)
            
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(o.cic,'mcc');
            if numel(o.mcc)==1
                o.mcc = o.mcc{1};
                
                %Iniatilise the bit low
                o.mcc.digitalOut(o.mccChannel,false);
            else
               o.cic.error('CONTINUE','Liquid reward added but no MCC plugin added (or, more than one added - currently not supported)');
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
            % Responds by calling the MCC plugin to activate liquid reward.
            % This currently uses the timer() function for duration, which
            % may be inaccurate or interrupt time-sensitive functions.
            duration = o.(['item', num2str(item) 'duration']);
            if ~isempty(o.mcc)
                if rand*100<o.jackpotPerc
                    duration = o.jackpotDur;
                end
                o.mcc.digitalOut(o.mccChannel,true,duration);
                
                %Keep track of how much has been delivered.
                o.nrDelivered = o.nrDelivered + 1;
                o.totalDelivered = o.totalDelivered + duration;
            else
                o.writeToFeed(['No MCC detected for liquid reward (' num2str(duration) 'ms)']);
            end
        end
        
        function report(o)
            %Provide an update of performance to the GUI.
            o.writeToFeed(horzcat('Delivered: ', num2str(o.nrDelivered), ' (', num2str(round(o.nrDelivered./o.cic.trial,1)), ' per trial); Total duration: ',num2str(o.totalDelivered)));
        end
    end
end