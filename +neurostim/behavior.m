classdef (Abstract) behavior <  neurostim.plugin
    
    properties (SetAccess=public,GetAccess=public)
        failEndsTrial       = true;             %Does violating behaviour end trial?
        successEndsTrial    = false;         % Does completing the behavior successfully end the trial?     
        everyFrame@logical =true;
        
    end
    
    properties (SetAccess=protected,GetAccess=public)
         currentState; % Function handle that represents the current state. 
         beforeExperimentState; % Must be non-empty
         beforeTrialState;  % If empty,the currentState is used
         
    end
    properties (Dependent)
        stateName@char;       
    end
    
    methods %get/set
        function v = get.stateName(o)
            pattern = '@\(varargin\)o\.(?<name>[\w\d]+)\(varargin{:}\)'; % This is what a state function looks like when using func2str : @(varargin)o.freeViewing(varargin{:})
            match = regexp(func2str(f.currentState),pattern,'names');
            if isempty(match)
                error('State name extraction failed');
            else
                v= match.name;
            end
       end
    end
    
    %% Standard plugin member functions
    methods (Sealed)
        % Users should add functionality by defining new states, or
        % if a different response modailty (touchbar, keypress, eye) is
        % needed, by overloading the getEvent function. The regular plugin
        % functions are sealed. 
        function beforeExperiment(o)
            assert(~isempty(o.beforeExperimentState),['Behavior ' o.name '''s beforeExperimentState has not been defined']);
        end
        
        
        function beforeTrial(o)
            if ~isempty(o.beforeTrialState)
                o.currentState = o.beforeTrialState;
            end
            
        end
        
        function beforeFrame(o)
            t = o.cic.trialTime;
            on = t >= o.on && t <= o.off;
            
            
            if on && o.everyFrame    
                e= getEvent(o);     % Get current events
                o.currentState(t,e);  % Each state is a member function- just pass the event
            end
        end
        
%         function afterFrame(o)
%         end
%         
%         function afterTrial(o)
%         end
%         function afterExperiment(o)
%         end
%         
        
        function transition(o,state)
            o.currentState = state;
            o.state = o.stateName; % Log time/state transition
            
        end
    end
    
    %% 
    methods (Access=public)  % Derived classes can overrule these if needed
       
        % Constructor. In the non-abstract derived clases, the user must
        % set currentState to an existing state.
        function o = behavior(c,name)
            o = o@neurostim.plugin(c,name);     
            o.addProperty('on',0,'validate',@isnumeric);
            o.addProperty('off',Inf,'validate',@isnumeric);
            o.addProperty('from',Inf,'validate',@isnumeric);
            o.addProperty('to',Inf,'validate',@isnumeric);
            
            
            
          
            o.feedStyle = 'blue';
        end
           
        function e = getEvent(o)
            [e.X,e.Y,e.buttons] = GetMouse;               
        end
      
    end
    
    %% States
    methods
        function fail(o,t,e)
            o.writeToFeed('fail');
            if o.failEndsTrial
                o.cic.endTrial();
            end
        end
        
        function success(o,t,e)
           o.writeToFeed('fail');
           
            if o.successEndsTrial
                o.cic.endTrial();
            end
        end
        
        function v= stateDuration(o,t,s)
            %Return how long the state s has been active at time t.
            
        end
    end
    
    
end