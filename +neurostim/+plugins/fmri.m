classdef fmri < neurostim.plugin
    % fMRI plugin that pauses an experiment at the start until a specified
    % number of triggers has been recorded. During the scan the plugin
    % only logs the incoming triggers.
    %
    properties
        lastTrigger = -Inf;
        subjectStartKeys = {}; % 'Want to talk key, want to start key'
        subjectStartMessage = ''; % Message shown to the subject before trial 1; explain the keys above.
        operatorMessages = false; % false means command line only, true means show to subject screen
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
            o.addProperty('subjectAnswer',''); %         
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
                
                if numel(o.subjectStartKeys)==2
                    % Ask the subject to start or talk.
                    % Force replace these two keys with the ones specified
                    % for the fmri plugin (due to the limited number of
                    % keys or the desire to reuse the same keys and
                    % minimize subject movement, we have to force replace
                    % these keys that may also be in use by a stimulus;
                    % the original mapping is restored below, before the trial starts).
                    key1 = addKey(o,o.subjectStartKeys{1},'Talk',true,[],true);
                    key2 = addKey(o,o.subjectStartKeys{2},'Start',true,[],true);                    
                    o.subjectAnswer='';                                      
                    o.cic.drawFormattedText(o.subjectStartMessage,'ShowNow',true);                        
                    while (isempty(o.subjectAnswer))                        
                        KbQueueCheck(o.cic);
                        pause(0.5);
                    end
                    % Put original key mapping back
                    if ~isempty(key1)
                        addKey(o,key1.key,key1.help,key1.isSubject,key1.fun,true,key1.plg);
                    end
                    if ~isempty(key2)
                        addKey(o,key2.key,key2.help,key2.isSubject,key2.fun,true,key2.plg);
                    end
                    
                end
                subjectTalk = strcmpi(o.subjectAnswer,o.subjectStartKeys{1});
                if subjectTalk
                    o.cic.drawFormattedText('One moment please...','ShowNow',true);  
                    commandwindow;
                    fprintf(2,'******************************************\n');
                    fprintf(2,'Subject wishes to talk to the experimenter.\n');                            
                    fprintf(2,'******************************************\n');                    
                    input('Press enter when done','s');                        
                else
                    o.cic.drawFormattedText('Starting soon...','ShowNow',true);  
                end
                % Get scan number information
                if isempty(o.scanNr) || o.scanNr ==0
                    answer=[];
                    if ~o.cic.hardware.keyEcho
                       ListenChar(0); % Need to echo now
                    end                        
                    while (isempty(answer))
                        commandwindow;                                                                           
                        if o.operatorMessages
                            o.cic.drawFormattedText('Which scan number is about to start?','ShowNow',true);                        
                        end                           
                        fprintf('*****************************************\n');
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
                if o.operatorMessages
                    o.cic.drawFormattedText('Start the scanner now ...','ShowNow',true);                
                else
                    fprintf(2,'Start the scanner now ...');
                end
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
                case upper(o.subjectStartKeys)
                    o.subjectAnswer = key;                   
            end
        end
    end
end