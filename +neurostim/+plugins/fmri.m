classdef fmri < neurostim.plugin
    % fMRI plugin that allows subjects to indicate whether they are ready
    % and pauses an experiment at the start until a specified
    % number of triggers has been recorded. During the scan the plugin
    % logs the incoming triggers.
    % In fake mode, the plugin generates its own scan triggers. 
    % For logging purposes, the plugn records the scan number (i.e. the
    % number assigned to the run by the MRI Scanner).
    properties
        lastTrigger = -Inf;
        subjectStartKeys = {}; % 'Want to talk key, want to start key'
        subjectStartMessage = ''; % Message shown to the subject before trial 1; explain the keys above.'Press left to talk, right to start the experiment'
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
            o.addProperty('fake',false);
            o.addProperty('fakeTR',2);
            o.addProperty('subjectAnswer',''); %       
            o.addKey('t');            
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
                    subjectTalk = strcmpi(o.subjectAnswer,o.subjectStartKeys{1});
                    if subjectTalk
                        o.cic.drawFormattedText('One moment please...','ShowNow',true);  
                        commandwindow;
                        fprintf(2,'******************************************\n');
                        fprintf(2,'Subject wishes to talk to the experimenter.\n');                            
                        fprintf(2,'******************************************\n');                    
                        input('Press enter when done','s');                        
                    end
                end                                
                o.cic.drawFormattedText('Starting soon...','ShowNow',true);  
                
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
                
                if o.fake
                    startFakeScanner(o);
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
        
        %% Some debugging functionality to fake a scan trigger with TR
        function startFakeScanner(o)
            tmr= timer('Name','FakeScanner','Period',o.fakeTR,'StartDelay',0,'ExecutionMode','fixedRate','TimerFcn',@o.generateTrigger);
            start(tmr);
            writeToFeed(o,['Started fake scanner triggers with TR =' num2str(o.fakeTR)]); 
        end
        
        function generateTrigger(o,tmr,evt) %#ok<INUSD>
            keyboard(o,'T');
            writeToFeed(o,'Fake scan trigger');
        end
        
        function stopFakeScanner(o)
            tmr = timerfind('Name','FakeScanner');
            stop(tmr);
            delete(tmr);
            writeToFeed(o,'Stopped fake scanner triggers.');
        end
        function afterExperiment(o)
            if o.fake
            stopFakeScanner(o); 
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
            o.maxTriggerTime = parms.MaxTT;       
            o.fake = strcmpi(parms.onOffFakeKnob,'fake');
                
        end
     end
    methods (Static)  
        function guiLayout(p)
            % Add plugin specific elements
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [110 39 40 22];
            h.Text = 'Scan';
            
            h = uieditfield(p, 'numeric','Tag','ScanNr');
            h.Position = [110 17 40 22];
            h.Value=0;
            h.Tooltip = 'Enter the scan number (as defined by the scanner)';
            
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [160 39 45 22];
            h.Text = 'Max TT';
            
            h = uieditfield(p, 'numeric','Tag','MaxTT');
            h.Value = 6;
            h.Position = [160 17 40 22];   
            h.Tooltip = 'The experiment will stop if the scanner fails to send a trigger for this many seconds';
            
             h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [205 39 45 22];
            h.Text = 'Pre Triggers';
            
            h = uieditfield(p, 'numeric','Tag','PreTriggers');
            h.Value = 9;
            h.Position = [205 17 40 22];                   
            h.Tooltip = 'The experiment starts once this many triggers have been received from the scanner';
            
            h = uibutton(p,'Push','Text','Quench');
            h.Position = [255 17 65 22];
            h.ButtonPushedFcn = @stopFake;
            h.Tooltip = 'Push this is the fake scanner keeps running after the experiment ends...';
            function stopFake(o,e)
                knob = findobj(o.Parent,'Tag','onOffFakeKnob');
                if ~isempty(knob)
                if strcmpi(knob.Value,'Fake') 
                    tmr = timerfind('Name','FakeScanner');
                    if isa(tmr,'timer')
                        stop(tmr);
                        delete(tmr);                    
                    end
                end
                end
            end
            
        end
    end
end