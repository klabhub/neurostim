classdef flow <handle & matlab.mixin.Copyable
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
        children;               % The children of this element. This can be one or more other neurostim.flow objects (typically a block), or a cell array with specifications per condition
        cic@neurostim.cic;      % Handle to CIC
        
        list=[];                % A list of numbers that specifies the order in which the child objects (blocks or trials) will be executed.
        listNr=0;               % Current element - a linear index into list.
        
        retryCounter=[];        % Tally of the number of times a condition has been retried        
    end
    
    properties (Dependent)
        isBlockStart;           % True for the first element of a block        
        currentChild;           % The current element in the flow (block)
        currentSpec;            % The current trial specification in the flow.
        childNr;                % Linear index into children
        nrChildren;             % How many children (i.e. blocks or conditions)
        nrList;                 % How many trials
        isBlock;                % True for blocks (i.e. flows with children that are flows)
     end
    
    methods
        function v = get.isBlock(o)
            v = any(isa(o.children,'neurostim.flow'));
        end
        
        function v = get.isBlockStart(o)
            v = o.listNr==1 && o.isBlock;
        end
        
        function v  = get.nrChildren(o)
            v = numel(o.children);
        end
        
        function v = get.currentChild(o)
            v = o.children(o.childNr);
        end
        
        function v = get.currentSpec(o)
            v = o.children{o.childNr};
        end
        
        function v = get.childNr(o)
            if o.listNr>0
                v = o.list(o.listNr);
            else
                v =1;
            end
        end
        
        function v = get.nrList(o)
            v = numel(o.list);
        end
        
       
        
        function v = get.name(o)
            if o.isBlock
                v = [o.name '/' o.currentChild.name];
            else
                v = o.name;
            end
        end
        
        function set.weights(o,v)
            if ~ismember(numel(v), [1 o.nrChildren])
                error(['There are ' num2str(numel(v)) ' weights, but ' num2str(o.nrChildren) ' children in this flow']);
            end
        end
        
    end
    
    methods
        function o = flow(c,varargin)
            if nargin ==0
                % Allowing an empty block makes initialization in CIC
                % easier.
            else
                o.cic = c;
                o = setParms(o,true,varargin{:});  % Set all including defaults
            end
        end
        
        
        function v = nrBlocks(o,recursive)
            if nargin<2
                recursive =false;
            end
            if o.isBlock
                v=o.nrChildren;
                if recursive
                    v=v+sum(arrayfun(@nrBlocks,o.children));
                end
            else
                v=0;
            end
        end
        function v=nrConditions(o)
            if o.isBlock
                v= sum(arrayfun(@nrConditions,o.children));
            else
                v = o.nrChildren;
            end
        end
        
        function v = nrTrials(o)
            if o.isBlock
                v = sum(arrayfun(@nrTrials,o.children));
            else
                v = o.nrList;
            end
        end
        
        function o2=duplicate(o1)
            o2 =copyElement(o1);
        end
        
        function blck = addBlock(o,blck,varargin)
            if nargin<2 || isempty(blck)
                blck = neurostim.flow;
            end
            if isa(blck,'neurostim.flow')
                blck.parent = o;
                blck = duplicate(blck);
                setParms(blck,false,varargin{:});
                o.children = cat(2,o.children,blck);
            else
                error('Only blocks can be added as blocks to other blocks');
            end
        end
        
        function addTrials(o,design,varargin)
            for c=1:design.nrConditions
                o.children = cat(2,o.children,{design.specs(c)});
            end
        end
        
        function plot(o,root)
            if nargin <2
                f=uifigure;
                tree= uitree(f);
                root = uitreenode(tree,'text','root');
                tree.SelectionChangedFcn = @(src, event)(disp(src.SelectedNodes.NodeData));
            end
            for i=1:o.nrChildren
                if o.isBlock
                    node = uitreenode(root,'text',['Block: ' o.name]);
                    plot(o.children(i),node);
                else
                    uitreenode(root,'text',['Trial-' num2str(i)],'nodedata',o.children{i});
                end
            end
            if nargin<2
                expand(tree,'all')
            end
        end
        function shuffle(o,recursive)
            % Shuffle the list of children and set the "currentTrialIx" to
            % the first one in the list
            if nargin<2
                recursive = false;
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
            
            o.retryCounter = zeros(o.nrChildren,1);
            o.listNr =1; % Reset the index to start at the first entry
            
            if recursive && o.isBlock
                arrayfun(@shuffle,o.children);
            end
        end
        
        
        function beforeExperiment(o)
            shuffle(o,true); % recursive initialization
            
        end
        
        function beforeTrial(o)
            
            if o.listNr ==0
                beforeBlock(o);
                
                % randomize the list of children
                shuffle(o);
            end
            
            if o.isBlock
                beforeTrial(o.currentChild);
            else
                % Leaf node (no children)
                
                % Restore default values
                %setDefaultParmsToCurrent(o.cic.pluginOrder);
                
                
                %c.condition = o.condition; % Log the condition change (this is a linear index, specific to the current design)
                
                
                %% Now apply the values to the parms in the plugins.
                nrParms = size(o.currentSpec,1);
                for p =1:nrParms
                    plgName =o.currentSpec{p,1};
                    varName = o.currentSpec{p,2};
                    if isa( o.currentSpec{p,3},'neurostim.plugins.adaptive')
                        value = getValue(o.currentSpec{p,3});
                    else
                        value =  o.currentSpec{p,3};
                    end
                    o.cic.(plgName).(varName) = value;
                end
                
                
                
                
                %c.blockTrial = c.blockTrial+1;  % For logging and user output only
                % Calls before trial on all plugins, in pluginOrder.
                base(o.cic.pluginOrder,neurostim.stages.BEFORETRIAL,o.cic);
            end
        end
        
        function afterTrial(o)
            if o.isBlock
                afterTrial(o.currentChild);
            else
                % Calls after trial on all the plugins
                base(o.cic.pluginOrder,neurostim.stages.AFTERTRIAL,o.cic);
                
                % Now check behavior or other success
                if o.isSuccess || strcmpi(o.retry,'IGNORE') ||   o.retryCounter(o.childNr) >= o.maxRetry
                    
                else
                    switch upper(o.retry)
                        case 'IMMEDIATE'
                            insertIx = o.listNr +1 ;
                        case 'RANDOMINBLOCK'
                            % Add the current to a random position in the list
                            % (past tbe current), then go to the next in the
                            % list.
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
                nextChild(o);
                
                
                collectPropMessage(o.cic);
                collectFrameDrops(o.cic);
                if rem(o.cic.trial,o.cic.saveEveryN)==0
                    ttt=tic;
                    o.cic.saveData;
                    o.cic.writeToFeed('Saving the file took %f s',toc(ttt));
                end
            end
        end
        
        function nextChild(o)
            if o.listNr < o.nrList
                o.listNr = o.listNr +1;
            else  % Last trial in a block
                afterBlock(o);
                if ~isempty(o.parent)
                    nextChild(o.parent);
                else % No parent
                    % All done
                    o.cic.endExperiment;
                end
            end
        end
        
        function beforeBlock(o)
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
                o.cic.drawFormattedText(msg,true,waitForKey);
            end
            clearOverlay(o.cic,true);
        end
        
        function afterBlock(o)
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
                o.cic.drawFormattedText(msg,true,waitForKey);
            end
            %
            if o.cic.saveEveryBlock
                ttt=tic;
                o.cic.saveData;
                o.cic.writeToFeed('Saving the file took %f s',toc(ttt));
            end
            
            clearOverlay(o.cic,true);
        end
        
        function success = isSuccess(o)
            if isempty(o.successFunction) && ~o.isBlock
                % A leaf (trial)
                allBehaviors  = o.cic.behaviors;
                success = true;
                for i=1:numel(allBehaviors)
                    success = success && (~allBehaviors(i).required || allBehaviors(i).isSuccess);
                end
            else
                success = o.successFunction(o.cic);
            end
        end
        
    end
    
    methods (Access=protected)
        function o = setParms(o,includeDefaults, varargin)
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
end