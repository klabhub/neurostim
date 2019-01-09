classdef block <handle
    properties (GetAccess = public, SetAccess=public)
        name@char;
        randomization@char;
        weights=1;
        nrRepeats=1;
        beforeMessage; %String to display before the start of a block (can be a function, f(cic), that returns a string)
        afterMessage;
        beforeFunction; % function handle which takes cic as first arg
        afterFunction;
        successFunction='';
        beforeKeyPress@logical;
        afterKeyPress@logical;
        maxRetry;
        retry;
        latinSqRow;
        order;
    end
    
    properties (GetAccess= public, SetAccess= protected)
        parent@neurostim.block;
        children;
        cic@neurostim.cic;
        
        list=[];
        listNr=0; % Linear index into list.
        
        nrRetried = 0;
        retryCounter=[];
        
    end
    
    properties (Dependent)
        isBlockStart;
        
        currentChild;
        currentSpec;
        childNr; % Linear index into children
        nrChildren;
        nrList;
        isBlock;
        nrBlocks;
    end
    
    methods
        function v = get.isBlock(o)
            v = any(isa(o.children,'neurostim.block'));
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
        
        function v = get.nrBlocks(o)
            if o.isBlock
                v = o.nrChildren;
            else
                v = 1;
            end
        end
        
        function v = get.name(o)
             if o.isBlock
                v = [o.name '/' o.currentChild.name];
            else
                v = o.name;
            end
        end
        
    end
    
    methods
        function o = block(c,name,varargin)
            if nargin ==0
                % Allowing an empty block makes initialization in CIC
                % easier.
            else               
                o.cic = c;
                o.name = name;
                o = setParms(o,true,varargin{:});  % Set all including defaults
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
        function addBlock(o,blck)
            if isa(blck,'neurostim.block')
                blck.parent = o;
                o.children = cat(2,o.children,blck);
            else
                error('Only blocks can be added as blocks to other blocks');
            end
        end
        
        function addTrials(o,design,varargin)
            setParms(o,false,varargin{:}); % Only set those actually specified.
            for c=1:design.nrConditions
                o.children = cat(2,o.children,{design.specs(c)});
            end
        end
        
        
        function shuffle(o,recursive)
            % Shuffle the list of children and set the "currentTrialIx" to
            % the first one in the list
                        
            
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