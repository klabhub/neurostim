classdef block < dynamicprops
    % Class for establishing blocks for experiment setup.
    % Constructor:
    % myBlock=block(name,fac1[,...facLast]);
    %
    % Inputs:
    %   name - name of the block.
    %
    % Outputs:
    %   myBlock - passes out a block structure with editable fields for
    %       establishing a block of factorials for session design.
    %
    % Settable fields include:
    %   myBlock.nrRepeats - number of repeats of the current block
    %
    %   myBlock.randomization - one of 'SEQUENTIAL','RANDOMWIHOUTREPLACEMENT',
    %       RANDOMWITHREPLACEMENT', case insensitive
    %
    %   myBlock.weights = [a b]
    %       wherein the weights correspond to the equivalent factorial.
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
        factorials@neurostim.factorial; % The collection of factorial designs that will run in this block
        list=[];    % Each column corresponds to a trial. First row specifies the factorial, second row the condition in the factorial.  [1 2 3; 2 2 1] means run condition 2 from factorial 1 then condition 2 from factorial 2 and then condition 1 from
        name='';    % Name of the block
        trial=0;       
    end
    
    properties (Dependent)
        nrConditions;
        nrFactorials;
        nrTrials;
        condition;  % Spec cell for the current condition
        conditionName; % Name of the current condition
        factorialIx;    
        conditionIx;
    end
    
    methods
        
        function v = get.nrTrials(o)
            v = size(o.list,2);
        end
        
        function v = get.conditionName(o)
            v = key(o.factorials(o.factorialIx).conditions,o.conditionIx);
        end
        
        
        function v = get.nrFactorials(o)
            v = numel(o.factorials);
        end
        
        function v = get.factorialIx(o)
            v = o.list(1,o.trial);
        end
        
        function v = get.conditionIx(o)
            v = o.list(2,o.trial);
        end
        
        function set.beforeFunction(o,fun)
            o.beforeFunction = neurostim.utils.str2fun(fun);
        end
        
        function set.afterFunction(o,fun)
            o.afterFunction = neurostim.utils.str2fun(fun);
        end
        
        function v = get.nrConditions(o)
            v = sum(o.factorials.nrConditions);
        end
        
    end
    
    
    methods
        
        % Constructor
        function o = block(name,varargin)
            assert(nargin > 1,'NEUROSTIM:block:notEnoughInputs', ...
              'Not enough input arguments.');
            
            o.name = name;
            o.factorials = [varargin{:}];
            
            o.weights = ones(1,o.nrFactorials);
        end
        
        function o = nextTrial(o,c)
            o.trial = o.trial+1;
            
            % we want the block, factorial and condition to be logged for
            % each trial
            c.factorial = o.factorialIx; % index into @block.factorials
            c.condition = o.conditionIx; % index into @factorial.conditions
                        
            %Retrieve the plugin/parameter/value specs for the current condition
            specs = o.condition;
            nrParms = length(specs)/3;
            for p =1:nrParms
                plgName =specs{3*(p-1)+1};
                varName = specs{3*(p-1)+2};
                value   = specs{3*(p-1)+3};
                if isa(value,'neurostim.plugins.adaptive')
                    value = getValue(value);
                end
                c.(plgName).(varName) = value;
            end
            
        end
        
        function disp(o)
            disp([o.name ': block with ' num2str(o.nrFactorials) ' factorials']); 
        end
        
        % Return the specs (a cell array) of the current condition
        function v = get.condition(o)
            v = o.factorials(o.factorialIx).conditions(o.conditionIx);
        end

        % Parse the factorials to setup a single 2xN list of
        % N factorial/condition pairs, one for each trial
        function setupExperiment(o)
            assert(numel(o.weights) == o.nrFactorials, ...
              'NEUROSTIM:block:sizeMismatch', ...
              'Length of weight vector must match the number of factorials.');

            % Setup each factorial
            for f = 1:o.nrFactorials
                setupExperiment(o.factorials(f));
            end
                        
            for r = 1:o.nrRepeats
                % build the list of factorials..
                fNum = cell2mat(arrayfun(@(x,y) repmat(x,1,y),1:o.nrFactorials,o.weights,'UniformOutput',false));
              
                % randomize order of factorials
                switch upper(o.randomization)
                    case 'SEQUENTIAL'
                        % do nothing...
                    case 'RANDOMWITHOUTREPLACEMENT'
                        fNum = Shuffle(fNum);
                    case 'RANDOMWITHREPLACEMENT'
                        fNum = datasample(fNum,size(fNum,2));
                end
                
                for f = fNum
                    lst  = [f*ones(1,o.factorials(f).nrConditions); ...
                             o.factorials(f).list];
                    o.list = cat(2,o.list,lst); 
                    
                    % if the factorial specifies randomization, we
                    % should 'reshuffle' each repeat
                    o.factorials(f).reshuffle();
                end
            end
        end
        
    end % methods 
    
end % classdef