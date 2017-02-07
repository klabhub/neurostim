classdef block < dynamicprops
    % Class for establishing blocks for experiment setup.
    % Constructor:
    % myBlock=block(name,design[,...designLast]);
    %
    % Inputs:
    %   name - name of the block.
    %
    % Outputs:
    %   myBlock - passes out a block structure that defines the experimental design
    %               for one block.
    %
    % Settable fields include:
    %   myBlock.nrRepeats - number of repeats of the current block
    %
    %   myBlock.randomization - one of 'SEQUENTIAL','RANDOMWIHOUTREPLACEMENT',
    %       RANDOMWITHREPLACEMENT', case insensitive
    %
    %   myBlock.weights = [a b]
    %       wherein the weights correspond to the equivalent design (i.e. a factorial or set of conditions).
    %
    %   myBlock.beforeMessage - a string containing a message which will
    %       write to screen before the block begins, and wait for a keypress.
    %       myBlock.afterMessage - a string containing a message which will write
    %       to screen after the block ends. (and wait for keypress)
    %
    %   myBlock.beforeFunction - function handle to a function to run before the block.
    %       e.g.:
    %       out=myFunction(c)
    %           Output: true or false, whether run() should wait for a keypress
    %               before continuing
    %           Input: cic - use to reference other properties as required.
    %
    %   myBlock.afterFunction - same format as beforeFunction.
    %
    %
    
    properties
        
        randomization='SEQUENTIAL';
        weights=1;
        nrRepeats=1;
        beforeMessage@char='';
        afterMessage@char='';
        beforeFunction; % function handle which takes cic as first arg
        afterFunction;
    end
    
    properties (GetAccess=public, SetAccess = protected)
        designs@neurostim.design; % The collection of designs that will run in this block
        list=[];    % Order of the designs that will be run.
        name='';    % Name of the block
        designIx;      % Design we are currently running
    end
    
    properties (Dependent)
        nrConditions;
        nrDesigns;
        nrTrials;
        condition;  % Spec cell for the current condition
        conditionName; % Name of the current condition
        done@logical; % Any trials left in this block?
    end
    
    methods
        
        function v = get.done(o)
            v = o.designIx == numel(o.list) && o.designs(o.list(o.designIx)).done;
        end
        
        function v = get.nrTrials(o)            
            v = sum([o.designs(o.list).nrTrials]);
        end
        
        function v = get.conditionName(o)
            v = o.designs(o.list(o.designIx)).conditionName;
        end
        
        
        function v = get.nrDesigns(o)
            v = numel(o.designs);
        end
        
        
        function set.beforeFunction(o,fun)
            o.beforeFunction = neurostim.utils.str2fun(fun);
        end
        
        function set.afterFunction(o,fun)
            o.afterFunction = neurostim.utils.str2fun(fun);
        end
        
        function v = get.nrConditions(o)
            nr = {o.designs.nrConditions};
            v = sum([nr{:}]);
        end
        
    end
    
    
    methods
        
        % Constructor
        function o = block(name,varargin)
            assert(nargin > 1,'NEUROSTIM:block:notEnoughInputs', ...
                'Not enough input arguments.');
            o.name = name;
            o.designs = [varargin{:}];
            o.weights = ones(1,o.nrDesigns);
        end
        
        
        function nextTrial(o,c)
            %Retrieve the plugin/parameter/value specs for the current condition
            if o.designIx ==0 || o.designs(o.list(o.designIx)).done
                % This design is done, move to the next one
                o.designIx = o.designIx +1;
                if o.designIx > numel(o.list)
                    error('Ran out of designs to run???');
                else
                    o.designs(o.list(o.designIx)).shuffle; % Randomize as requested to setup list of conditions
                    c.design = o.list(o.designIx); % Log the change
                end
            end
            
            [specs,c.condition] = o.designs(o.list(o.designIx)).nextCondition;
            
            %% Now apply the values to the parms in the plugins.
            nrParms = size(specs,1);
            for p =1:nrParms
                plgName =specs{p,1};
                varName = specs{p,2};
                value   = specs{p,3};
                if isa(value,'neurostim.plugins.adaptive')
                    value = getValue(value);
                end
                c.(plgName).(varName) = value;
            end
            
        end
        
        function disp(o)
            disp([o.name ': block with ' num2str(o.nrDesigns) ' designs']);
        end
        
        
        % Parse the designs to setup a single 2xN list of
        % N design/condition pairs, one for each trial
        function setupExperiment(o)
            % build the list of designs..
            o.list = repelem(repmat(1:o.nrDesigns,[1 o.nrRepeats]),repmat(o.weights,[1 o.nrRepeats]));
            % randomize order of factorials
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    % do nothing...
                case 'RANDOMWITHOUTREPLACEMENT'
                    o.list= Shuffle(o.list);
                case 'RANDOMWITHREPLACEMENT'
                    o.list= datasample(o.list,numel(o.list));
            end
            
            o.designIx =0;
        end
        
    end % methods
    
end % classdef