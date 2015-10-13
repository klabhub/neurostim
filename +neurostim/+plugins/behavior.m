classdef behavior < neurostim.plugin
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    % Properties:
    % on - true when conditions met, false when not.
    % beforeframe, afterframe), case insensitive.
    % reward - struct containing type, duration, etc.
    
    events
        GIVEREWARD
    end
    
    properties
    acquireEvent = {};    % checks behaviour, for acquiring data
    validateEvent = {'afterFrame'}; % checks whether this behaviour is 'correct'
    endsTrial = false;  %does violating behaviour end trial?
    rewardOn = true;
    reward;
    data;
    prevOn = false;
    end
    
    properties (Access=public,SetObservable=true,GetObservable=true,AbortSet)
       on@logical = false;
       done@logical=false;
       endTime;
       startTime;
    end
    
    methods
        function o=behavior(name)
            o = o@neurostim.plugin(name);
            o.addPostSet('done',[]);
            o.addPostSet('on',[]);
            o.addProperty('response',[]);
            o.addProperty('continuous',false,[],@islogical);
            o.addProperty('duration',1000,[],@isnumeric);
            o.addProperty('from',0,[],@isnumeric);
            o.addProperty('X',0,[],@isnumeric);
            o.addProperty('Y',0,[],@isnumeric);
            o.addProperty('Z',0,[],@isnumeric);
            o.addProperty('tolerance',1,[],@isnumeric);
            o.addPostSet('startTime',[]);
            o.addProperty('rewardNames',{},[],@iscellstr);
            
            o.listenToEvent('BEFORETRIAL');
            
            if any(strcmpi('afterframe',[o.validateEvent o.acquireEvent]))
                o.listenToEvent('AFTERFRAME');
            end
            
            if any(strcmpi('aftertrial',[o.validateEvent o.acquireEvent]))
                o.listenToEvent('AFTERTRIAL');
            end
            
            if any(strcmpi('beforeframe',[o.validateEvent o.acquireEvent]))
                o.listenToEvent('BEFOREFRAME');
            end
         end
        
        function beforeTrial(o,c,evt)
            % reset all flags
            o.on = false;
            o.done = false;
            o.startTime = Inf;
            o.prevOn = false;
            o.endTime = Inf;
            
            if o.rewardOn && isempty(o.rewardNames)
                % collects reward plugin names in a cell array of strings
                temp=fieldnames(c);
                temp2 = strfind(temp,'reward_');
                o.rewardNames = temp(find(~cellfun('isempty',temp2)));
            end
        end
            
        
        function beforeFrame(o,c,evt)
            if any(strcmpi('beforeframe',o.validateEvent))
                processBehavior(o,c);
                
            end
            
            if any(strcmpi('beforeframe',o.acquireEvent))
                getBehavior(o,c);
            end
        end
        
        function afterFrame(o,c,evt)
            if any(strcmpi('afterframe',o.validateEvent))
                processBehavior(o,c);
            end
            
            if any(strcmpi('afterframe',o.acquireEvent))
                getBehavior(o,c);
            end
            
        end
        
        function afterTrial(o,c,evt)
            if any(strcmpi('afterTrial',o.validateEvent))
                processBehavior(o,c);
            end
            
            if any(strcmpi('afterTrial',o.acquireEvent))
                getBehavior(o,c);
            end
            
        end
        
        function afterExperiment(o,c,evt)
            
            if any(strcmpi('afterExperiment',o.validateEvent))
                processBehavior(o,c);
            end
            
            if any(strcmpi('afterExperiment',o.acquireEvent))
                getBehavior(o,c);
            end
        end
        
        
%         function events(o,src,evt)
%             
%             if any(strcmpi(evt.Name,o.validateEvent))
%                 processBehavior(o,c);
%             end
%             
%             if any(strcmpi(evt.Name,o.acquireEvent))
%                 getBehavior(o,c);
%             end
%             
%         end
            
            
        function data = acquireBehavior(o)
            % wrapper for acquireBehavior function, to be overloaded in
            % subclasses. This should return the current value(s) of the
            % requested behaviour (i.e. eye position, mouse position) to be
            % stored in matrix o.data for later processing by
            % validateBehavior(o).
        end
        
        function on = validateBehavior(o)
           % wrapper for checkBehavior function, to be overloaded in
           % subclasses. Should return true if behavior is satisfied and false if not.
            
        end
        
        function getBehavior(o,c)
            % to call and store acquireBehavior result
            
            
        end
            
        function processBehavior(o,c)
            % processes all behavioural responses.
            if ~o.done && ~ischar(o.from) && ~isempty(o.from) && GetSecs*1000-c.trialStartTime(c.trial) >=o.from 
                o.on = validateBehavior(o);   %returns o.on = true if true.
                if o.continuous % if the behaviour needs to be continuous (i.e. has a duration)
                    if o.on && ~o.prevOn  % if behaviour is on for the first time
                        o.startTime = GetSecs*1000;     % set start time.
%                         display(['startTime of ' o.name ' is ' num2str(o.startTime)]);
                        o.prevOn = true;
                    end
                    if ~o.on && o.prevOn       % if behaviour is not on, but was on previously
                        o.startTime = Inf;      % reset start time and done flag
                        o.done = true;
                        o.prevOn = false;
                        % %                         display('wrong');
                        if o.rewardOn       % if we want to trigger rewards
                            for a=1:numel(o.rewardNames)
                                o.cic.(o.rewardNames{a}).rewardAnswer=false;
                                notify(o.cic.(o.rewardNames{a}),'GIVEREWARD');
                            end
                        end
                        if o.endsTrial    % if we want failure to end trial
%                             keyboard;
                            c.nextTrial;  % quit trial
                            return;
                        end
                    end
                    if ~o.done && o.on && (((GetSecs*1000)-o.startTime>=o.duration) || o.endTime~=Inf)   % if duration has been met and behaviour is still on
                        o.done = true;  % set done flag
                        o.endTime = GetSecs*1000;
% %                         display('right')
                        if o.rewardOn   % if we want to trigger rewards
                            for a=1:numel(o.rewardNames)
                                o.cic.(o.rewardNames{a}).rewardAnswer=true;
                                notify(o.cic.(o.rewardNames{a}),'GIVEREWARD');
                            end
                        end
                    end
                else    % if behaviour is discrete
                    o.done = o.on;
                    if o.rewardOn && o.done  % if we want to trigger rewards
                        
                        if o.response
                            for a=1:numel(o.rewardNames)
                                o.cic.(o.rewardNames{a}).rewardAnswer=true;
                                notify(o.cic.(o.rewardNames{a}),'GIVEREWARD');
                            end
                        else
                            for a=1:numel(o.rewardNames)
                                o.cic.(o.rewardNames{a}).rewardAnswer=false;
                                notify(o.cic.(o.rewardNames{a}),'GIVEREWARD');
                            end
                        end
                    end
                    if o.done && o.endsTrial
                        c.nextTrial;
                        return;
                    end
                        
                end
            end
            
        end
    end
    
   
    
    
end