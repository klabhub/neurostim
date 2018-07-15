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
    %       write to screen before the block begins.
    %       myBlock.afterMessage - a string containing a message which will write
    %       to screen after the block ends. (and wait for keypress)
    %
    %   myBlock.beforeFunction - function handle to a function to run before the block.
    %       e.g.:
    %       out=myFunction(c)
    %           Output: ignored.
    %           Input: cic - use to reference other properties as required.
    %
    %   myBlock.afterFunction - same format as beforeFunction.
    %
    %   myBlock.beforeKeyPress = logical; whether to wait after showing the
    %   before message and/or executing the before function.
    %
    %   myBlock.afterKeyPress = same as beforeKeyPress.
    %
    % Note that the function is evaluated and the message is written to the
    % screen first, and then cic will wait until the user presses a key (if
    % requested).
    %
    
    properties
        randomization='SEQUENTIAL';
        weights=1;
        nrRepeats=1;
        beforeMessage=''; %String to display before the start of a block (can be a function, f(cic), that returns a string)
        afterMessage='';
        beforeFunction; % function handle which takes cic as first arg
        afterFunction;
        beforeKeyPress@logical = true;
        afterKeyPress@logical = true;
        nrRetried = 0;
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
        nrPlannedTrials;
        condition;  % Linear index, current condition
        done@logical; % Any trials left in this block?
        design;  % current design
    end
    
    methods
        function v=get.design(o)
            % Current design
            v =o.designs(o.list(o.designIx));
        end
        
        function v = get.done(o)
            % Current design done, an we're at the last design in the list
            v = o.designIx == numel(o.list) && o.design.done;
        end
        
        function v = get.nrPlannedTrials(o)
            v =sum([o.designs(o.list).nrPlannedTrials]);
        end
        
        function v = get.nrTrials(o)
            v = o.nrRetried+o.nrPlannedTrials;
        end
        
        function v = get.condition(o)
            v = o.design.condition;
        end
        
        function v = get.nrDesigns(o)
            v = numel(o.designs);
        end
        
        function set.beforeMessage(o,fun)
            %Function must accept cic as the sole input argument and return a string
            if isa(fun,'function_handle')
                o.beforeMessage = fun;
            elseif ischar(fun)
                o.beforeMessage = fun;
            else
                error('beforeMessage must be a string');
            end
        end
        function set.afterMessage(o,fun)
            %Function must accept cic as the sole input argument and return a string
            if isa(fun,'function_handle')
                o.afterMessage = fun;
            elseif ischar(fun)
                o.afterMessage = fun;
            else
                error('afterMessage must be a string');
            end
        end
        function set.beforeFunction(o,fun)
            %Function must accept cic as the sole input argument.
            if isa(fun,'function_handle')
                o.beforeFunction = fun;
            elseif isempty(fun)
                o.beforeFunction = [];
            else
                error('Unknown function format');
            end
        end
        
        function set.afterFunction(o,fun)
            %Function must accept cic as the sole input argument.
            if isa(fun,'function_handle')
                o.afterFunction = fun;
            elseif isempty(fun)
                o.afterFunction = [];
            else
                error('Unknown function format');
            end
        end
        
        function v = get.nrConditions(o)
            nr = {o.designs.nrConditions};
            v = sum([nr{:}]);
        end
        
    end
    
    
    methods
        
        % Constructor.
        % 
        function o = block(name,varargin)
            assert(nargin > 1,'NEUROSTIM:block:notEnoughInputs', ...
                'Not enough input arguments.');
            isDesign = cellfun(@(x) isa(x,'neurostim.design'),varargin);
            if ~any(isDesign)
                error('block construction needs at least one design');
            end
            o.name = name;
            o.designs = [varargin{isDesign}];
            o.weights = ones(1,o.nrDesigns);
            % The remaining args are parameter/value pairs
            pv = varargin(~isDesign);
            for i=1:2:numel(pv)
                o.(pv{i}) = pv{i+1};
            end
        end
        
        function afterTrial(o,c)
            allBehaviors  = behaviors(c);
            success = true;
            for i=1:numel(allBehaviors)
                success = success && (~allBehaviors(i).required || allBehaviors(i).isSuccess);
            end
            o.nrRetried = o.nrRetried + afterTrial(o.design,success); % Update the design object
        end
        
        function beforeTrial(o,c)
            %Retrieve the plugin/parameter/value specs for the current condition
            % and apply to each of the plugins
            %% Check whether we need to go to the next design in this block
            if o.designIx ==0 ||  ~beforeTrial(o.design)% Move the design to the next trial
                % This design is done, move to the next one
                o.designIx = o.designIx +1;
                if o.designIx > numel(o.list)
                    error('Ran out of designs to run???');
                else
                    o.design.shuffle; % Randomize as requested to setup list of conditions
                    c.design = o.design.name; % Log the change
                end
            end
            
            c.condition = o.condition; % Log the condition change (this is a linear index, specific to the current design)
            spcs = specs(o.design); % Retrieve the specs from the design
            %% Now apply the values to the parms in the plugins.
            nrParms = size(spcs,1);
            for p =1:nrParms
                plgName =spcs{p,1};
                varName = spcs{p,2};
                if isa( spcs{p,3},'neurostim.plugins.adaptive')
                    value = getValue(spcs{p,3});
                else
                    value =  spcs{p,3};
                end
                c.(plgName).(varName) = value;
            end
            
        end
        
        % Parse the designs to setup a single 2xN list of
        % N design/condition pairs, one for each trial
        function [msg,waitForKey] = beforeBlock(o,c)
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
            
            %% User interaction if requested
            % Show a beforeBlock message, and execute a beforeBlock
            % function (if requested).            
            if isa(o.beforeMessage,'function_handle')
                msg = o.beforeMessage(c);
            else
                msg = o.beforeMessage;
            end            
            if ~isempty(o.beforeFunction)
                o.beforeFunction(c);                
            end            
            % Wait for a key only if requested andif the beforeFun or
            % message has content. 
            waitForKey = o.beforeKeyPress && (~isempty(msg) || ~isempty(o.beforeFunction));
        end
        
    end % methods
    
end % classdef
