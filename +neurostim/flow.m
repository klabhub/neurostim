classdef flow <handle & matlab.mixin.Copyable
    % The flow class defines the experimental flow: the way an experiment is structured in terms of blocks
    % and trials, how many times to repeat each condition, in which order,
    % and what to do when a trial was not completed successfully.
    %
    % The flow is a tree, where the root is the entire experiment, each branch
    % is a block , and each leaf is a trial. Experiment flow starts at the
    % root, then goes into the first branch, finds the first leaf and runs
    % that trial.
    % If the trial is successfull (or if the experiment specified that the
    % outcome is to be ignored), the experiment continues with the next
    % leaf.  Once all leaves on a branch have been completed, the flow
    % continues on the next branch.
    %
    % EXAMPLES:
    %
    %
    % Test files : tools\testFlow
    %
    
    properties (GetAccess = public, SetAccess=public)
        % These variables are assigned default values in the constructor
        % (see setParms)
        name@char;                  % Name for this element
        randomization@char;         % Mode of randomization. SEQUENTIAL, RANDOMWITHREPLACEMENT, RANDOMWITHOUTREPLACEMENT, LATINSQUARES, ORDERED
        latinSqRow;                 % For latin squares randomization; which row .
        order;                      % A specific order for randomization. Used only in combination with 'ORDERED'
        weights;                    % 1 integer number per child
        nrRepeats;                  % How often to repeat each child
        beforeMessage;              % String to display before the start of a block (can be a function, f(cic), that returns a string)
        afterMessage;               % String to display before the start of a block (can be a function, f(cic), that returns a string)
        beforeFunction;             % function handle that takes cic as first arg. Executes at the start of a block
        afterFunction;              % function handle that takes cic as first arg. Executes at the end of a block
        successFunction;            % function handle that takes cic as first arg and returns a logical to indicate whether the trial/block was terminated successfully.
        beforeKeyPress@logical;     % Require a keypress before starting this block.
        afterKeyPress@logical;      % Require a keypress after completing this block.
        retry;                      % If a trial/block fails, what should happen : IGNORE, IMMEDIATE, RANDOMINBLOCK
        maxRetry;                   % Maximum number of times a block/trial will be retried
    end
    
    properties (GetAccess= public, SetAccess= protected)
        parent@neurostim.flow;  % The parent element in the flow-tree
        children@cell;          % The children of this element. Each element of the cell can be a specification of a trial (which is a cell with stim parm value) or a block (a neurostim.flow object)
        cic@neurostim.cic;      % Handle to CIC
        conditionsBefore;       % Conditions in the tree before the current level. Populated by shuffle.
        list=[];                % A list of numbers that specifies the order in which the child objects (blocks or trials) will be executed.
        listNr=0;               % Current element - a linear index into list.
        
        retryCounter=[];        % Tally of the number of times a condition has been retried
    end
    
    properties (Dependent)
        isBlock;                % True for the first element of a block
        currentChild;           % The current element in the flow (block)
        childNr;                % Linear index into children
        nrChildren;             % How many children (i.e. blocks or conditions)
        nrList;                 % How many trials
        conditionNr;            % Unique sequence number in the tree.        
    end
    
    methods   % get/set methods
        function v=get.conditionNr(o)
            v= currentCondition(o);
        end
        
        function v=get.name(o)
            % Return the name of the currently active block of trials
            if o.isBlock
                v = o.currentChild.name;
            else
                v = o.name;
            end
        end
        
        function v = get.isBlock(o)
            % Logical to determine whether the current child is a block
            if o.nrChildren>0
                v = isa(o.currentChild,'neurostim.flow');
            else
                v = false;
            end
        end
        
        function v  = get.nrChildren(o)
            % The number of children (i.e.blocks and trials) of this flow
            % element.
            v = numel(o.children);
        end
        
        function v = get.currentChild(o)
            % The currently active child, can be a trial (cell array with specs)
            % or a block (a flow object)
            v = o.children{o.childNr};
        end
        
        function v = get.childNr(o)
            % The index of the currently active child.
            if o.listNr>0
                v = o.list(o.listNr);
            else
                v =1;
            end
        end
        
        function v = get.nrList(o)
            % The number of items that will be run in this flow. Both blocks
            %and trials count as 1
            v = numel(o.list);
        end
                
    end
    
    %% Public access methods
    methods (Access=public)
        function o = flow(c,varargin)
            % The flow constructor. Can be called with parameter value
            % pairs for each of the public properties
            % INPUT
            % c = handle to cic
            % parm/value pairs.
            
            if nargin ==0
                % Should only be used by CIC on construction. Users should
                % always specify a cic when constructing a flow.
            else
                o.cic = c;
            end
            setParms(o,true,varargin{:});  % Set all including defaults
        end
        
        function o2=duplicate(o1)
            % flow is a handle class, hence assigning one to a new variable
            % does not create a new object. To create a new one, use this
            % duplicate function: it will copy the settings from the
            % original but create a new one.
            o2 =copyElement(o1);
            o2.list =[];
            o2.listNr = 0;
            o2.retryCounter =[];
            [blcks,ix] = o1.blocks;
            % Recursively copy all child blocks
            for i=1:numel(blcks)
                o2.children(ix(i)) = duplicate(blcks(i));
            end
        end
        
        function addTrials(o,design)
            % Add trials from the design (a neurostim.design object) to
            % this flow. Conditions from the design are added sequentially
            % to the end of the current flow.
            % INPUT
            % design =  a neurostim.design object that specifies parameter
            % settings.
            %
            if ~isa(design,'neurostim.design')
                error('The design input to addTrials must be a neurostim.design object');
            end
            for c=1:design.nrConditions
                o.children{o.nrChildren+1} = design.specs(c); % Add at the end
            end
        end
        
        function blck = addBlock(o,blck)
            % Add another neurostim.flow element to this flow to create a
            % hierarchy of blocks and trials.
            % INPUT
            % blck =  A neurostim.flow. Can be empty to add an empty block,
            %               with default parameter settings. Note that
            %               this code makes a duplicate of the block that
            %               is passed. This makes it easier for the user to
            %               reuse the block s/he created.
            % OUTPUT
            % blck =  handle to the newly created block. You can use this
            %                   to add further levels to the flow tree.
            %
            if nargin<2 || isempty(blck)
                blck = neurostim.flow;
            end
            if ~isa(blck,'neurostim.flow')
                error('Only blocks can be added as blocks to other blocks');
            end
            blck = duplicate(blck); % Force a duplicate, not the passed handle.
            blck.parent = o;
            o.children{o.nrChildren+1} = blck; % Add at the end
        end
        
    
        function plot(o,forceConditions,root)
            % Show a tree view of this flow. 
            % If the flow has not been shuffled yet (i.e. it has conditions
            % but not yet stored the actual trial sequence), the tree shows
            % the conditions in each block across the flow tree. 
            % After shuffling and creating the trial order, it will show
            % each individual trial.
            % Clicking on an element in the tree will show the parameter
            % values associated with the block and/or the trial.
            % INPUT
            % forceConditions = Toggle to force showing conditions, not trials
            %               even when trials have been generated. [false]
            
            % root = No need to set.  It is the root element (used in the 
            %               recursion, leave out or set to [] on first call). [[]]
            
            if nargin <3 || isempty(root)
                % First call, create the figure and tree.
                f=uifigure;
                f.Position = [60 60 400 800];
                tree= uitree(f);
                tree.Position = [10 10 f.Position(3:4)-20];                
                root = uitreenode(tree,'text','root');
                tree.SelectionChangedFcn = @dispTree;
                if nargin<2
                    forceConditions = false;
                end            
            end
            
            cntr =0;
            if numel(o.list)==0 || forceConditions
                % No trials yet, display the conditions.
                thisList = 1:o.nrChildren;
                prefix = '';
            else
                % We have trials and will show all...
                thisList = o.list;
                prefix = 'Trial';
            end
            for i=1:numel(thisList)
                thisChild  =o.children{thisList(i)};
                if isa(thisChild,'neurostim.flow')
                    node = uitreenode(root,'text',['Block: ' thisChild.name],'nodedata',thisChild);
                    plot(thisChild,forceConditions,node);
                else
                    cntr= cntr+1;
                    condition = o.conditionsBefore+thisList(i);
                    uitreenode(root,'text',[prefix '#' num2str(cntr) ': Condition ' num2str(condition)],'nodedata',spec2code(o,thisChild,false));
                end
            end
            if exist('tree','var')
                expand(tree,'all')
            end          
            
            function dispTree(src, event) %#ok<INUSD>
            % Nested function to show the specs or the block info on the
            % command line from the uitree. Called by the selection changed 
            % callback
            disp(char('============================',src.SelectedNodes.Text))
            if ischar(src.SelectedNodes.NodeData)
                disp(src.SelectedNodes.NodeData)
            else
                obj = src.SelectedNodes.NodeData;
                fn = fieldnames(obj);
                exclude = {'parent','children','cic','currentChild'};
                for n=1:numel(fn)
                    if ~isempty(obj.(fn{n})) && ~ismember(fn{n},exclude)
                        v.(fn{n}) = obj.(fn{n});
                    end
                end
                disp(v)
            end
            end
        end
        
         function shuffle(o,recursive)
            % Shuffle the list of children and start the flow at the first one in the list
            % This generates the order of execution of trials and blocks of
            % the root level of the flow. The order and number is
            % determined by the randomization, weights, and nrRepeats
            % properties of the flow at the top level of the tree.
            % INPUT
            % recursive = initializes all levels of the tree, using
            % ramdomization,weights, and nrRepeats as specified at each
            % level. [false]
            % 
            % This function is called by CIC before the experiment starts.
            % A user does not need to call it, but can do so to test
            % randomization etc. (Usually followed by a call to plot(o);
            % 
            if nargin<2
                recursive = false; % By default only the top level is randomized.
            end
            
            weighted=repmat(repelem(1:o.nrChildren,o.weights(:)),[1 o.nrRepeats])';
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    o.list=weighted;
                case 'RANDOMWITHREPLACEMENT'
                    o.list=datasample(weighted,numel(weighted));
                case 'RANDOMWITHOUTREPLACEMENT'
                    o.list=Shuffle(weighted);
                case 'ORDERED'
                    o.list = repmat(repelem(o.order,o.weights(:)),[1 o.nrRepeats])';
                case 'LATINSQUARES'
                    if ~(rem(o.nrChildren,2)==0)
                        error(['Latin squares randomization only works with an even number of blocks, not ' num2str(o.nrChildren)]);
                    end
                    allLS = neurostim.utils.ballatsq(o.nrChildren);
                    if isempty(o.latinSqRow) || o.latinSqRow==0
                        lsNr = input(['Latin square group number (1-' num2str(size(allLS,1)) ')'],'s');
                        lsNr = str2double(lsNr);
                    end
                    if isnan(lsNr)  || lsNr>size(allLS,1) || lsNr <1
                        error(['The Latin Square group ' num2str(lsNr) ' does not exist for ' num2str(o.nrChildren) ' conditions/blocks']);
                    end
                    blockOrder = allLS(lsNr,:);
                    o.list  = repmat(blockOrder,[1 o.nrRepeats]); % Ignoring weights which do not make sense in LSQ
            end
            % Reset counters
            o.retryCounter = zeros(o.nrChildren,1);
            o.listNr =1; % Reset the index to start at the first entry
            % Process the children 
            if recursive
                cellfun(@(x) shuffle(x,true),o.blocks);
            end
            
            % some preparation to make it easier to assign unique
            % condition numbers at runtime
            if isempty(o.parent)
                o.conditionsBefore = 0;
                countConditions(o,0);
            end
         end         
    end
    
    %% Functions that CIC uses for bookkeeping/reporting
    methods %(Access = {?neurostim.cic})
        
        function v = currentCondition(o)
            % Returns a number that identifies the currently active
            % condition (within the tree). Used by CIC for bookkeeping   
            if o.isBlock                
                v=currentCondition(o.currentChild);
            else                  
                v = o.conditionsBefore+o.childNr;      
            end
        end
        
        function v = nrBlocks(o,recursive)
            % Returns the number of blocks at the root level of this flow.
            % INPUT
            % recursive = Set to true to get the number of blocks in the
            %               entire tree [false]
            %
            if nargin<2
                recursive =false;
            end
            v= numel(o.blocks);
            if recursive
                v=v+sum(cellfun(@nrBlocks,o.blocks));
            end
        end
        
        function v=nrConditions(o,recursive)
            % Returns the number of conditions at the top level of the
            % flow.
            % INPUT
            % recursive =  set to true to get the number of conditiosn in
            %               the entire tree. [false]
            if nargin<2
                recursive = false;
            end
            v = numel(o.conditions);
            if recursive
                v= v+ sum(cellfun(@(x) (nrConditions(x,true)),o.blocks));
            end
        end
        
        function v = nrTrials(o,recursive)
            % Returns the number of trials at the top level of the
            % flow.
            % INPUT
            % recursive =  set to true to get the number of trials in
            %               the entire tree. [false]
            if nargin<2
                recursive = false;
            end
            [blcks,ix] = blocks(o);
            v = sum(~ismember(o.list,ix));
            if recursive
                % Count # occurrences of blocks
                n = arrayfun(@(t)nnz(o.list==t), ix);                                
                v= v + sum(n.*cellfun(@(x) (nrTrials(x,true)),blcks));
            end
        end
        
        
        function beforeExperiment(o)
            % CIC calls this just before starting the experiment. This
            % generates the complete order of trials 
            
            
            % TODO Sanity checks for weights
            %              function set.weights(o,v)
            %             if ~ismember(numel(v), [1 o.nrChildren])
            %                 error(['There are ' num2str(numel(v)) ' weights, but ' num2str(o.nrChildren) ' children in this flow']);
            %             end
            %         end
            %
            
            if ~hasChildren(o)
                warning('No trials in one ore more blocks ... did you forget to addTrials?');
            end
            shuffle(o,true); % recursive initialization
            
        end
        
        function beforeTrial(o)
            % CIC calls this before each trial to setup parameters for the upcoming trial
            if o.isBlock
                % If the top level is a block, then drill down to the trial               
                % Step down - recursive call that eventually ends up after
                % the else below
                beforeTrial(o.currentChild);
            else
                % Trial node                 
                 if o.listNr ==1
                    beforeBlock(o); % Starting a new block
                end
                % First restore default values
                setDefaultParmsToCurrent(o.cic.pluginOrder);                
                %Then apply the specs for this trial to the plugins.
                spec2code(o,o.currentChild,true);                                
                % Then tell all plugins to perform their beforeTrial code.
                base(o.cic.pluginOrder,neurostim.stages.BEFORETRIAL,o.cic);
            end
        end
        
        function checkAdaptive(o)
            spec = o.currentChild;
            ix  = find(cellfun(@(x)(isa(x,'neurostim.plugins.adaptive')),spec(:,3)));
            for i=ix
                activate(spec{i,3},o.conditionNr,false);
            end
        end
        
        function afterTrial(o)
            % CIC calls this after each trial to move to the next item
            if o.isBlock
                % Drill down to the currently active trial. Recursive call
                % that eventually ends up below the else.
                afterTrial(o.currentChild);
            else
                % Tell all plugins to run thei afterTrial code
                base(o.cic.pluginOrder,neurostim.stages.AFTERTRIAL,o.cic);
             
                % Check whether this trial was completed successfully or
                % needs to be retried.
                
                % Check behavior or other success measures                       
                if isempty(o.successFunction) 
                    % For regular trials the default definition of 'success' is
                    % that all behaviors that were required have been completed
                    % successfully. 
                    allBehaviors  = o.cic.behaviors;
                    success = true;
                    for i=1:numel(allBehaviors)
                        success = success && (~allBehaviors(i).required || allBehaviors(i).isSuccess);
                    end
                else
                    % If the user provided a successFunction  (for this
                    % particular block in the flow tree), then it defines
                    % succes.
                    success = o.successFunction(o.cic);
                end
            
                setupRetry(o,success);
                % Make sure adaptive parameters are turned off if needed.
                checkAdaptive(o);
                % Move to the next child in the flow (trial or block)
                nextChild(o);
                % Provide some feedback to the experimenter 
                collectPropMessage(o.cic);
                collectFrameDrops(o.cic);
                if rem(o.cic.trial,o.cic.saveEveryN)==0
                    ttt=tic;
                    o.cic.saveData;
                    o.cic.writeToFeed('Saving the file took %f s',toc(ttt));
                end
            end
        end
        
           function setParms(o,includeDefaults, varargin)
            % Set the public properties of the flow object. 
            % This is called by the constructor, hence every flow object
            % will get these proprerties by default (but can be changed
            % after construciton, or during construction by providing
            % parm/value parirs).
            % INPUT 
            % includeDefaults = Set all properties, including the
            % properties that are not explicitly specified in varargin (and
            % therefore will get the default properteis speciied in the
            % inputParser below.
            % varargin = parm/value pairs.
            
            p = inputParser;
            p.addParameter('randomization','SEQUENTIAL',@(x)(ischar(x) && ismember(upper(x),{'SEQUENTIAL','RANDOMWITHREPLACEMENT','RANDOMWITHOUTREPLACEMENT','ORDERED','LATINSQUARES'})));
            p.addParameter('weights',1);
            p.addParameter('nrRepeats',1);
            p.addParameter('beforeMessage','');
            p.addParameter('afterMessage','');
            p.addParameter('beforeFunction',[],@(x)(isa(x,'function_handle')));
            p.addParameter('afterFunction',[],@(x)(isa(x,'function_handle')));
            p.addParameter('successFunction',[],@(x)(isa(x,'function_handle')));
            p.addParameter('beforeKeyPress',false,@islogical);
            p.addParameter('afterKeyPress',false,@islogical);
            p.addParameter('retry','IGNORE',@(x) (ischar(x) && ismember(upper(x),{'IGNORE','IMMEDIATE','RANDOMINBLOCK'})));
            p.addParameter('maxRetry',Inf,@isnumeric);
            p.addParameter('latinSqRow',0,@isnumeric);
            p.addParameter('order',[],@isnumeric);
            p.addParameter('name','',@ischar);
            p.parse(varargin{:});
            
            fn = fieldnames(p.Results);
            for i=1:numel(fn)
                if ~includeDefaults && ismember(fn{i},p.UsingDefaults)
                    continue;
                end
                o.(fn{i}) = p.Results.(fn{i});
            end
        end
        
    end
    %% Protected functions, called only by flow
    methods (Access=protected)
        
        function ok= hasChildren(o)
            ok = o.nrChildren>0;
            for i=1:o.nrChildren
                 if isa(o.children{i},'neurostim.flow')
                     ok = ok && hasChildren(o.children{i});
                 end
             end
        end
            
        function [blcks,ix] =blocks(o)
            % Retrieve those children that are flows (i.e. blocks of
            % trials)
            % OUTPUT
            % blcks = cell array of handles to the blocks in the flow (at the root level)
            % ix = the index of these blocks in the .children array.
            
            if o.nrChildren>1
                stay = cellfun(@(x) (isa(x,'neurostim.flow')),o.children);
                blcks = o.children(stay);
                ix = find(stay);
            else % No children no blocks
                blcks={};
                ix =[];
            end
        end
        
        function [cnds,ix] = conditions(o)
            % Retrieve those children that are not flows (i.e. they are
            % conditions that can be run in one or more trials).
            % OUTPUT
            % cnds = Cell array of condition specifications.
            % ix = index of these condition specs in the .children array.
            stay = ~cellfun(@(x) (isa(x,'neurostim.flow')),o.children);
            cnds = o.children(stay);
            ix = find(stay);
        end
        
        
        function nr = countConditions(o,nr)
            % Function that counts conditions per level and stores how many
            % there are before each level (in .conditionsBefore). This
            % simplifies runtime code to extract a unique condition number.
            % Called by shuffle.
             if nargin <2
                 nr =0;
             end
             for i=1:o.nrChildren
                 if isa(o.children{i},'neurostim.flow')
                     o.children{i}.conditionsBefore = nr;
                     nr = countConditions(o.children{i},nr);
                 else
                     nr = nr+1;
                 end
             end
         end
        
         function setupRetry(o,success)
            
            if success || strcmpi(o.retry,'IGNORE') ||   o.retryCounter(o.childNr) >= o.maxRetry
                %Either successful, or we are ignoring failures. Nothing to
                %do
            else
                switch upper(o.retry)
                    case 'IMMEDIATE'
                        insertIx = o.listNr +1 ;
                    case 'RANDOMINBLOCK'
                        % Add the current to a random position in the list
                        % (past tbe current)
                        insertIx= randi([o.listNr+1 o.nrList+1]);
                    otherwise
                        error(['Unknown retry mode: ' o.retry]);
                end
                % Put a new item in the list.
                newList = cat(1,o.list(1:insertIx-1),o.list(o.listNr));
                if insertIx<=numel(o.list)
                    newList= cat(1,newList,o.list(insertIx:end));
                end
                o.list = newList;
                o.retryCounter(o.childNr) = o.retryCounter(o.childNr) +1;  % Count the retries
            end
        end
        
        
        function nextChild(o)
            % Move the pointer (o.listNr) to the next element in the tree.
            if o.listNr < o.nrList
                % More elements (trials or blocks) to go at the current
                % level
                o.listNr = o.listNr +1;
            else  % Last trial at the current level.
                afterBlock(o); % Do some afterBlock processing/messaging
                if ~isempty(o.parent)                                       
                    nextChild(o.parent);
                else % No parent
                    % All done
                    o.cic.endExperiment;
                end
            end
        end
        
        function beforeBlock(o)
            % Called whenever the flow moves into a new block.
            % Tell all plugins a new block is about to start          
             base(o.cic.pluginOrder,neurostim.stages.BEFOREBLOCK,o.cic); % Send to plugins
            % Show a beforeMessage, and execute a beforeFunction (if requested).            
            if isa(o.beforeMessage,'function_handle')
                msg = o.beforeMessage(o.cic);
            else
                msg = o.beforeMessage;
            end
            if ~isempty(o.beforeFunction)
                o.beforeFunction(o.cic);
            end
            % Wait for a key only if requested andif the beforeFun or
            % message has content.
            waitForKey = o.beforeKeyPress && (~isempty(msg) || ~isempty(o.beforeFunction));            
            % Draw message, flip screen, and wait for keypress if requested.
            if ~isempty(msg)
                o.cic.drawFormattedText(msg,'flip',true,'waitForKey',waitForKey);
            end
            clearOverlay(o.cic,true);
        end
        
        function afterBlock(o)
            % Called whenever the last trial of a block has been completed.            
            base(o.cic.pluginOrder,neurostim.stages.AFTERBLOCK,o.cic); % Send to plugins          
            if isa(o.afterMessage,'function_handle')
                msg = o.afterMessage(o.cic);
            else
                msg = o.afterMessage;
            end
            if ~isempty(o.afterFunction)
                o.afterFunction(o.cic);
            end
            waitForKey = o.afterKeyPress && (~isempty(msg) || ~isempty(o.afterFunction));
            if ~isempty(msg)
                o.cic.drawFormattedText(msg,'flip',true,'waitForKey',waitForKey);
            end
            %
            if o.cic.saveEveryBlock
                ttt=tic;
                o.cic.saveData;
                o.cic.writeToFeed('Saving the file took %f s',toc(ttt));
            end            
            clearOverlay(o.cic,true);
            
            if isempty(o.successFunction)
                success=true;
            else
                success = o.successFunction(o.cic);
            end
            setupRetry(o.parent,success);
            shuffle(o); % Shuffle this block to prepare for reuse
        end
        
    
        
        function out = spec2code(o,spec,execute)
            % Function that translates the cell array with a condition
            % specification into a command to execute by cic. 
            % INPUT
            % spec = the specification a Nx3 cell array where column
            % specifies the plugin, column 2 the member variable, and 3 the
            % value to assign.
            % execute  = Toggle to execute the spec (i.e assign to the
            % relevant plugin) or to create a char that shows the
            % assignements that would be done (used by the plot/tree view)
            % OUTPUT
            % out = the text that shows what will be done.
            
            if nargin <3
                execute = false;
            end
            nrParms = size(spec,1);
            txt = '';
            for p =1:nrParms
                plgName =spec{p,1};
                varName = spec{p,2};
                if isa( spec{p,3},'neurostim.plugins.adaptive')
                    activate(spec{p,3},o.conditionNr,true); %In this trial, this adaptive should receive updates.                    
                    value = getValue(spec{p,3});
                else
                    value =  spec{p,3};
                end
                if execute
                    % Use cic to assign the value to the relavant plugin
                    o.cic.(plgName).(varName) = value;
                else
                    % Create a char array to show pseudo code that explains
                    % what would be done.
                    if isnumeric(value)
                        valueFmt = '%f';
                    elseif ischar(value)
                        valueFmt = '%s';
                    else
                        valueFmt = '%s';
                        value = class(value);
                    end
                    txt= sprintf(['%s%s.%s=' valueFmt '\n'],txt,plgName,varName,value);out=txt;
                end
            end
            if ~execute
                out = txt;
            end
        end
        
     
    end
    
    methods (Static)
        
    end
end