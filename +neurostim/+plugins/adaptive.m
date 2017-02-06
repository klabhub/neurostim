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
    
    properties (SetAccess=protected, GetAccess=public)
        uid@double= [];
    end
    
    methods (Abstract)
        % update(s) should change the internal state of the adaptive object using the outcome of the current
        % trial (result = TRUE/Correct or FALSE/Incorrect).
        update(s,result);
        % getValue returns the current parameter value.
        v= getValue(s);
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
            o.addProperty('condition','','validate',@ischar);% The condition that this adaptive parameter belongs to. Will be set by factorial.m
            o.addProperty('targetPlugin','','validate',@ischar); % The plugin whose property is modulated by this adaptive object (set automatically in factorial; not used at runtime)
            o.addProperty('targetProperty','','validate',@ischar);% The property that is modualted by this object. (Set automatically in factorial.m, not used at runtime)
            
            o.uid = u;
            o.trialOutcome = funStr;
            o.listenToEvent('AFTERTRIAL');
        end
        
        function o= duplicate(o1,n,m)
            % Duplicate an adaptive parm ; requires setting a new unique
            % id.
            if nargin<3
                m=1;
                if nargin <2
                    n =1;
                end
            end
            
            if n*m>1
                for i=1:n
                    for j=1:m
                        o(i,j) = duplicate(o1) ; %#ok<AGROW> These are copies.
                    end
                end
            else
                u = randi(2^53-1);
                newName = strrep(o1.name,num2str(o1.uid),num2str(u));
                o =plugin.duplicate(o1,newName);
                o.uid = u;
            end
        end
        
        
        function afterTrial(s,c,~)
            % This is called after cic sends the AFTERTRIAL event
            % (in cic.run)
            if strcmpi(c.conditionName,s.condition)
                % Only update if this adaptive object is assigned to the
                % current condition. Call the derived class function to update it
                correct = s.trialOutcome; % Evaluate the function that the user provided.
                update(s,correct); % Pass it to the derived class to update
            end
        end
    end
end % classdef
