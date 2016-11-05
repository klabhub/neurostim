classdef adaptive < neurostim.plugin
    % Adaptive parameter class.
    %
    % This plugin stores and updates adaptive parameters.
    % BK - 11/2016
    
    properties
        parms@containers.map; % Map from condition numbers to adaptive Parm objects
        perCondition@logical =true;
    end
    
    methods
        function s = adaptive(c)
            % s = adaptive(c)
            %
            %   c         - handle to cic
            s = s@neurostim.plugin(c,'ADAPTIVE');
            s.listenToEvent({'BEFOREEXPERIMENT','AFTERTRIAL'});
            s.parms = containers.map('keyType',double,'valyeType',neurostim.adaptiveParameter);
        end
        
        function add(s,aClass,condition,varargin)
            % Add an adaptive parameter
            if isempty(condition)
                condition = -1;
            end
            s.parms(condition) = feval(aClass,varargin{:});
        end
        
        function beforeExperiment(s,c,evt)
            if s.perCondition && length(s.parms)==1 && keys(s.parms==-1)
                % Single adaptiveParameter specified, do singleton expansion
                for i=c.conditions(:)'
                    s.parms(i) = s.parms(-1);
                end
                remove(s.parms,-1);
            end
            for i=keys(s.parms)
                s.parms(i).initialize(c);
            end
        end
        
        function afterTrial(s,c,evt)
            % The trial has completed, update the relevant adaptiveParms
            if s.perCondition
                currentCondition = c.condition;
            else
                currentCondition = -1;
            end
            s.parms(currentCondition).update(c);
        end
    end
    
    
    
end % classdef
