classdef autologprops < dynamicprops
    % Allows the use of dynamic properties that automatically keep track of
    % the history of values that were assigned.
    %
    % BK -2018
    
    properties
        prms=struct;          % Structure to store all parameters
    end
    
    methods
        function o = autologprops
        end
        
        
        % Add properties that will be time-logged automatically, and that
        % can be validated after being set.
        % These properties can also be assigned a function to dynamically
        % link properties of one object to another. (g.X='@g.Y+5')
        function addProperty(o,prop,value,varargin)
            p=inputParser;
            p.addParameter('validate',[]);
            p.addParameter('SetAccess','public');
            p.addParameter('GetAccess','public');
            p.addParameter('noLog',false,@islogical);
            p.parse(varargin{:});
            
            
            if isempty(prop) && isstruct(value)
                % Special case to add a whole struct as properties (see
                % Jitter for usage example)
                fn = fieldnames(value);
                for i=1:numel(fn)
                    addProperty(o,fn{i},value.(fn{i}),varargin{:});
                end
            else
                % First check if it is already there.
                h =findprop(o,prop);
                if ~isempty(h)
                    error([prop ' is already a property of ' o.name ]);
                end
                
                % Add the property as a dynamicprop (this allows users to write
                % things like o.X = 10;
                h = o.addprop(prop);
                % Create a parameter object to do the work behind the scenes.
                % The parameter constructor adds a callback function that
                % will log changes and return correct values
                o.prms.(prop) = neurostim.parameter(o,prop,value,h,p.Results);
            end
        end
        
        
        
        function duplicateProperty(o,parm)
            % First check if it is already there.
            h =findprop(o,parm.name);
            if ~isempty(h)
                error([parm.name ' is already a property of ' o.name ]);
            end
            h= o.addprop(parm.name);
            o.prms.(parm.name) = duplicate(parm,o,h);
        end
    end
    
    methods (Sealed)
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setCurrentParmsToDefault(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setCurrentToDefault,o.prms);
                end
            end
        end
        
        % Wrapper to call setCurrentToDefault in the parameters class for
        % each parameter
        function setDefaultParmsToCurrent(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@setDefaultToCurrent,o.prms);
                end
            end
        end
        
        function pruneLog(oList)
            for o=oList
                if ~isempty(o.prms)
                    structfun(@pruneLog,o.prms);
                end
            end
            
        end
    end
    
end



