classdef (Abstract) adaptive < neurostim.plugin
    % Adaptive parameter class.
    %
    %  This abstract class handles most of the behind the scenes work for adaptive parameters.
    % The details of the actual adaptation are in the derived classes
    % (e,g, quest, nDown1UpStaircase).
    %
    % As this is an abstract class, derived classes must define
    % both a getValue(s) function, which returns the current
    % value of the parameter, and an update() function that
    % updates the internal state of the adaptive method.
    %
    % BK - 11/2016
    
    properties    (SetAccess={?neurostim.design})
        active@logical=true; % Used to bind an adaptive with a specific condition. See afterTrial below
    end
    
    properties (SetAccess=protected, GetAccess=public)
        uid@double= [];
    end
    
    methods (Abstract)
        % update(s) should change the internal state of the adaptive object using the outcome of the current
        % trial (result = TRUE/Correct or FALSE/Incorrect).
        update(s,result);
        % getAdaptValue returns the current parameter value from the adaptive algorithm.
        v= getAdaptValue(s);
    end
    
    properties (SetAccess=private)
        overruleValue = []; %used to manually set the adaptive parameter value (for the rest of current trial) to something other than that returned by the adaptive algorithm. Ensures update() is based on the actual tested value.
    end
    
    methods
        %% Operators to allow easy use of adaptive parameters in functions
        function v = plus(x1,x2)
            if isa(x1,'neurostim.plugins.adaptive')
                x1 = getValue(x1);
            end
            if isa(x2,'neurostim.plugins.adaptive')
                x2 = getValue(x2);
            end
            v =x1+x2;
        end
        
        function v = uplus(x1)
            x1 = getValue(x1);
            v = +x1;
        end
        
        
        function v = minus(x1,x2)
            if isa(x1,'neurostim.plugins.adaptive')
                x1 = getValue(x1);
            end
            if isa(x2,'neurostim.plugins.adaptive')
                x2 = getValue(x2);
            end
            v =minus(x1,x2);
        end
        
        function v = uminus(x1)
            x1 = getValue(x1);
            v = -x1;
        end
        
        function v = times(x1,x2)
            if isa(x1,'neurostim.plugins.adaptive')
                x1 = getValue(x1);
            end
            if isa(x2,'neurostim.plugins.adaptive')
                x2 = getValue(x2);
            end
            v =times(x1,x2);
        end
        
        
        function v = mtimes(x1,x2)
            if isa(x1,'neurostim.plugins.adaptive')
                x1 = getValue(x1);
            end
            if isa(x2,'neurostim.plugins.adaptive')
                x2 = getValue(x2);
            end
            v =mtimes(x1,x2);
        end
        
        
        function v = rdivide(x1,x2)
            if isa(x1,'neurostim.plugins.adaptive')
                x1 = getValue(x1);
            end
            if isa(x2,'neurostim.plugins.adaptive')
                x2 = getValue(x2);
            end
            v =rdivide(x1,x2);
        end
        
        %         function v = horzcat(varargin)
        %           Not possible becuase of the Sealed method in heterogeneous
        %         end
        
        function v = getValue(x1)
            if isempty(x1.overruleValue)
                v = getAdaptValue(x1);
            else
                v = x1.overruleValue;
            end
        end
        
    end
    
    
    methods
        
        
        function o = adaptive(c,funStr)
            % c= handle to CIC
            % fun = function string that evaluates to the outcome of the
            % trial (correct/incorrect).
            
            % Create a name based on the child class and a unique ID.
            u =randi(2^53-1);
            s = dbstack;
            caller = strsplit(s(2).name,'.');
            nm = [caller{1} '_' num2str(u)]; % Child class
            % Create the object
            o=o@neurostim.plugin(c,nm);
            o.addProperty('trialOutcome','','validate',@(x) (ischar(x) && strncmpi(x,'@',1))); % The function used to evaluate trial outcome. Specified by the user.
            o.addProperty('conditions',[]);% The condition that this adaptive parameter belongs to. Will be set by design.m
            o.addProperty('ignoreN',0); % Used to ignore the first N trials (set to 1 to ignroe the first, often missed trial)
            o.uid = u;
            o.trialOutcome = funStr;
        end
        
        function activate(o,cond,toggle)
            if toggle
                % Activating
                % Log condition number for safety checks...
                o.conditions = cond;
                o.active= true;
            else
                % Deactivate
                o.active= false;
            end
        end
        
        function values = whichParms(o,prm)
            % For this adaptive object, find out which  conditions in some other
            % plugin it responds to. This is useful to make sure that it is
            % responding to the correct conditions. Especially when using a
            % single adaptive parameter for multiple conditions.
            %
            % prm = a parameter in a different object. E.g.
            % c.gabor.prms.orientation
            %
            [~,tr] = get(o.prms.conditions,'atTrialTime',inf,'withdataonly',true);
            values= unique(get(prm,'trial',tr,'atTrialTime',inf));
            
        end
        
        function o= duplicate(o1,nm)
            % Duplicate an adaptive parm ; requires setting a new unique
            % id. Note that if you ask for more than one duplicate, the
            % first element in the array of duplicates will be the
            % original, all others are new.
            % If you ask for one duplicate, with nm==1,
            % we'll assume you really just want the one you already have (so no duplicate).
            % If you really want one copy, call this without the second argument.
            
            if nargin<2
                nm = 1;
                duplicateSingleton = true;
            else
                duplicateSingleton = false;
            end
            if prod(nm)>1 || ~duplicateSingleton
                o(1) = o1;
                % Recursive call to create copies
                for i=2:prod(nm)
                    o(i) = duplicate(o1) ; %#ok<AGROW> These are copies.
                end
                o = reshape(o,nm);
            else
                u = randi(2^53-1);
                newName = strrep(o1.name,num2str(o1.uid),num2str(u));
                o =duplicate@neurostim.plugin(o1,newName);
                o.uid = u;
            end
        end
        
        function overrule(x1,newValue)
            %Manually intervene to set the adaptive parameter to a value different
            %from that returned by the current state of the adaptive algorithm.
            %This ensures that update() is based on the actual value used
            %rather than the one initially suggested.
            %Overrided value used only for the current trial.
            x1.overruleValue = newValue;
        end
        
        function afterTrial(o)
            % This is called after flow sends the AFTERTRIAL event
            % A default adaptive object, for instance a jitter assigned
            % directly to a plugin will have active=true and will be updated each trial.
            % When assigning an adaptive object to a design object its
            % active property is set to false and toggled on each trial by flow
            % Whenever that specific object is used (i.e. the
            % condition to which it is assigned starts), its .active
            % is set to true (by flow) and when the trial is done flow sets
            % it back to false. That way the adaptive only gets updated
            % when "its" condition is run.
            if o.active && o.cic.trial > o.ignoreN
                % Call the derived class function to update it
                correct = o.trialOutcome; % Evaluate the function that the user provided.
                if numel(correct)>1
                    error(['Your ''correct'' function in the adaptive parameter ' o.name ' does not evaluate to true or false']);
                end
                update(o,correct); % Pass it to the derived class to update
                o.overruleValue = [];
            else
                % Ignoring this update
            end
        end
        function beforeTrial(o)
            %Reset the overruled value.
            o.overruleValue = [];
        end
        
    end
    
    
end % classdef
