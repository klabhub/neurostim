classdef fmri < neurostim.plugin
    % fMRI plugin that pauses an experiment at the start until a specified
    % number of triggers has been recorded. During the scan the plugin
    % only logs the incoming triggers.
    %
    properties
        lastTrigger = -Inf;
    end
    methods
             
        function o = fmri(c)
            o = o@neurostim.plugin(c,'fmri');
            o.addProperty('scanNr',[]);
            o.addProperty('preTriggers',10);
            o.addProperty('trigger',0,'sticky',true); % Keep the same value across trials
            o.addProperty('triggerKey','t');
            o.addProperty('triggersComplete',[],'sticky',true);
            o.addProperty('maxTriggerTime',inf); % If no Triggers for x s, the experiment ends
            o.addKey('t');            
        end
        
        function beforeExperiment(o)
            
        end
        
        function beforeTrial(o)
            % The goal here is to wait until the pre-triggers have been
            % received (to start at steady-state magnetization). This code
            % interacts directly with PTB Screen and other functionality
            % which is not recommended in general (but necessary here).
            if o.cic.trial==1
                % Get scan number information
                if isempty(o.scanNr) || o.scanNr ==0
                    answer=[];
                    if ~o.cic.hardware.keyEcho
                       ListenChar(0); % Need to echo now
                    end                        
                    while (isempty(answer))
                        o.cic.drawFormattedText('Which scan number is about to start?','ShowNow',true);                        
                        disp('*****************************************')
                        commandwindow;
                        answer = input('Which scan number is about to start (for logging purposes)?','s');
                        answer = str2double(answer);
                        if isnan(answer)
                            answer = []; % Try again.
                        end
                    end
                    if ~o.cic.hardware.keyEcho
                       ListenChar(-1); %Set it back to no echo
                    end    
                    o.scanNr =answer;
                end
                
                
                
                % Now wait until the requested pre triggers have been recorded
                o.cic.drawFormattedText('Start the scanner now ...','ShowNow',true);                
                % Wait until the first trigger has been received
                while o.trigger ==0
                    WaitSecs(0.1);
                    o.cic.KbQueueCheck;
                end
                while o.trigger < o.preTriggers
                    WaitSecs(0.1);
                    o.cic.KbQueueCheck;
                    if o.trigger < o.preTriggers
                        txt = ['Waiting for ' num2str(o.preTriggers-o.trigger) ' more triggers from the scanner'];
                        o.cic.drawFormattedText(txt,'ShowNow',true);
                    end                    
                end
                o.triggersComplete = true;
                o.cic.drawFormattedText('','ShowNow',true);
            end
        end
        
        function afterTrial(o)
            maxDelay = o.maxTriggerTime;
            if maxDelay > 0 && ~isinf(maxDelay)
                delta = o.cic.clockTime - o.lastTrigger;
                if delta > maxDelay *1000
                    % More than 2 maximumTR durations have gone by since
                    % the last trigger was received. This means the scanner
                    % stopped. End the experiment
                    o.writeToFeed(['Scanner stopped ' num2str(delta/1000) 's ago. Experiment done.']);
                    endExperiment(o.cic);
                end
            end
        end
        
        % Catch trigger keys. Could be extended with generic user
        % responses.
        function keyboard(o,key)
            switch upper(key)
                case 'T'
                    o.trigger = o.trigger+1;
                    o.lastTrigger = o.cic.clockTime;
            end
        end
    end
    
    %% GUI Functions
     methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = eyelink plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            o.scanNr = parms.ScanNr;
            o.maxTriggerTime = parms.maxTT;            
        end
     end
    methods (Static)  
        function p = guiLayout(p,name)
            % Call the base layout first
            p = neurostim.plugin.guiLayout(p,name);
            % Then add plugin specific elements

            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [110 39 40 22];
            h.Text = 'Scan';
            
            h = uieditfield(p, 'numeric','Tag','ScanNr');
            h.Position = [110 17 40 22];
            h.Value=0;
            
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [160 39 45 22];
            h.Text = 'Max TT';
            
            h = uieditfield(p, 'numeric','Tag','MaxTT');
            h.Value = 6;
            h.Position = [160 17 40 22];   
            
            
             h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [205 39 45 22];
            h.Text = 'Pre Triggers';
            
            h = uieditfield(p, 'numeric','Tag','PreTriggers');
            h.Value = 9;
            h.Position = [205 17 40 22];                   

        end
    end
end