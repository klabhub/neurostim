classdef design <handle & matlab.mixin.Copyable
    % Class for establishing an experimental design
    % Constructor:
    % o=design(name)
    %
    % Inputs:
    %   name - name of the design
    %
    % Outputs:
    %   o - passes out a design structure with fields that can be modified
    %   to specify factors (e.g. o.fac1,o.fac2) to specify a factorial design,
    %   or individual conditions (o.conditions)
    %
    % Object member variables that you can changer are:
    % o.randomization
    % o.fac1..o.facN
    % o.weights
    % o.conditions
    %
    % To specify what happens if a trial is unsuccessful (i.e. wrong answer
    % or a fixation break, or any required 'behavior' that is not
    % successfully completed), use the retry parameter.
    %
    % o.retry  ['IGNORE'] ('IGNORE': ignore unsucessful trials ,'RANDOM' : retry the trial at a random later point in the block,'IMMEDIATE': retry the trial in the next trial)
    % o.maxRetry : [INF] - Specify a maximum number of retries.
    %
    % Examples :
    % Factors are specified as :
    % o.fac1.(stimName).(paramName) = parameters
    % To vary multiple parameters in multiple stimuli together, add them under the same factor
    % (i.e. fac1.(stimName2).(paramName2)= parameters
    % Each subsequent factor should be added with an increasing number
    % (i.e. fac2, fac3).
    %
    % E.g.
    % To specify a single one-way factorial:
    % d=design('coherenceFactorial');
    % d.fac1.dots.coherence=[0 0.5 1];
    %
    % To vary both coherence and position together:
    % d.fac1.dots.coherence=[0 0.5 1];
    % d.fac1.dots.position=[0 -5 5];
    %
    % To vary coherence against position in a two-way factorial (3x3):
    % d.fac1.dots.coherence=[0 0.5 1];
    % d.fac2.dots.position=[0 -5 5];
    %
    % To assign different weights to conditions:
    % d.weights=[1 1 2]
    % Note that the weights matrix has to match the design. So you should
    % specify it only after specifying all factors/conditions.
    %
    % Singleton specifications are fine too. For instance to change the
    % lifetime of the dots to 100 for this factorial (as opposed to the
    % default lifetime that you may have used in a different factorial)
    % d.fac1.dots.coherence={0 0.5 1};
    % d.fac1.dots.lifetime = 100;
    %
    % Once a factorial design has been defined, you can modify individual
    % conditions by assigning modifcations to the .conditions field.
    % Think of .conditions as a matrix where each dimension represents one
    % of the factors:
    % d.conditions(1,2) = the condition that corresponds to the first
    % level of fac1 and the second level of fac2.
    % d.conditions(:,1) = all levels of the first factorial
    % d.conditions(:,:) = all levels of the first and second factorial/
    %
    % To change one element in the factorial, you write:
    % d.conditions(2,1).dots.position  = -1;
    % All adaptive parameters (staircases, quest, jitter)
    % must be set through the conditions interface so that you can specify
    % exactly to which conditions the adaptative parameter should be
    % assigned. For instance, to jitter all X and Y positions of the dots stimulus in all
    % conditiosn:
    % d.conditions(:).dots.X = plugins.jitter(...)
    % d.conditions(:).dots.Y = plugins.jitter(...)
    %
    % But if you want to jitter X only for te second level of the second factor, use:
    %  d.conditions(:,2).dots.X = plugins.jitter(...)
    %
    % Note that in this case, the adaptive plugin Jitter is shared acrosss
    % all levels that use t (i.e. the same underlying jitter object generates the
    % values). This is desirable for Jitter, but not for some staircases.
    % To use separate staircases for each level of a factor,use the
    % duplicate function:
    % d.conditions(:,2).dots.X = duplicate(plugins.quest(...),[nrLevels 1])
    % For more examples, see adaptiveDemo in the demos directory
    %
    % TK, BK, 2016
    % Feb-2017 BK
    % Major redesign without backward compatibility
    
    properties  (SetAccess =public, GetAccess=public)
        randomization='RANDOMWITHOUTREPLACEMENT';
        retry = 'IGNORE'; %IGNORE,IMMEDIATE,RANDOM
        weights@double=1;               % The relative weight of each condition. (Must be scalar or the same size as specs)
        maxRetry = Inf;
    end
    
    properties         (SetAccess =protected, GetAccess=public)
        name@char;                      % The name of this design; bookkeeping/logging use only.
        factorSpecs@cell={};            % A cell array of condition specifications for factorial designs
        conditionSpecs@cell ={};         % Conditions specifications that deviate from the full factorial
        list@double;                    % The order in which conditions will be run.
        currentTrialIx =0;                   % The condition that will be run in this trial (index in to .list)
        retryCounter = [];
    end
    
    properties (Dependent)
        nrConditions;                   % The total number of conditions in this design
        nrFactors;                      % The number fo factors in the design
        nrPlannedTrials;                % The total number of planned trials (takes .weights into account)
        nrTrials;                       % The total number of trials that will be run (includes retries).
        nrLevels;                       % The levels per factor
        done;                           % True after all conditions have been run
        levels;                         % Vector subscript (factors) for the current condition
        condition;                      % Linear index of the current condition
        nrRetried;                      % The total number of trials that have been retried.
    end
    
    
    methods  %/get/set
        
        function v= get.done(o)
            % Returns true if the currentTrialIx points to zero or the last
            % trial.
            v = ismember(o.currentTrialIx ,[0 o.nrTrials]);
        end
        
        function v = get.nrTrials(o)
            v= numel(o.list); % All trials, including retries
        end
        
        function v=get.nrPlannedTrials(o)
            % Total number of trial in this design (this includes the
            % effect of weighting, but not the retried-trials) (so it
            % reflects the number of planned trials).
            v = numel(o.list)-o.nrRetried;
        end
        
        function v = get.nrRetried(o)
            v = sum(o.retryCounter);
        end
        
        function v= get.nrFactors(o)
            %Number of factors in the design
            v = size(o.factorSpecs,1);
        end
        
        function v=get.nrConditions(o)
            % The number of conditions in this design
            v=prod(o.nrLevels);
        end
        
        function v=get.nrLevels(o)
            % Number of levels in each of the factors. For a non-factorial
            % design this returns [nrConditions 1]
            factor = 1:o.nrFactors;
            v = sum(~cellfun(@isempty,o.factorSpecs(factor,:)),2)';
            if isempty(v)
                v= max(1,numel(o.conditionSpecs)); % At least 1 condition
            end
            if numel(v)==1
                v= [v 1];
            end
        end
        
        function v = get.levels(o)
            % The currrent condition as a subscript into
            % the factorial design: % [2 3] = 2nd level first factor, 3rd level 2nd factor.
            % For a non-factorial design this is [i 1] with i the condition
            v= cond2lvl(o,o.condition);
        end
        
        function v = get.condition(o)
            % Linear index for the current condition
            v= o.list(o.currentTrialIx);
        end
        
    end
    
    
    methods (Access = public)
        
        function v= specs(o,cond)
            % Return a cell array with the specifcations for one
            % condition. If no second argument is provided, it returns the
            % specs for the current condition.
            
            if nargin <2
                cond = o.condition;
            end
            lvls = cond2lvl(o,cond);
            if isscalar(lvls)
                lvls = [lvls 1];
            end
            
            % lvls and cond provide the same information, the former is easier for
            % factorSpecs , the latter for conditionSpecs
            v={};
            for f=1:o.nrFactors
                v = cat(1,v,o.factorSpecs{f,lvls(f)});
            end
            % Now overrule with condition specs if specified
            if  ~isempty(o.conditionSpecs)
                %Check whether there are overruling condition specs for
                %this lvls. If a conditionSpec has been added for the first page
                % in the last dimension, then it wont match the
                % factorSpecs; we fix that here by comparing lvls to size
                % supplemented with 1's for the trailing dimensions
                if all(lvls<=[size(o.conditionSpecs) ones(1,numel(lvls)-ndims(o.conditionSpecs))])
                    % A condition spec exist. Add it to v and remove duplicates that were specified as factors
                    % but overruled by conditionSpecs, or duplicates that
                    % were added twice by condition specs (either a user
                    % error or, more likely, because a design was copied
                    % and then one of the variables already used was
                    % overruled in the copy).
                    for i=1:size(o.conditionSpecs{cond},1)
                        % If a conditonSpec is specified as well as a factor spec
                        % then the latter overrides the former. Even though
                        % they are applied in sequence (So the conditionspec
                        % would be used in a trial), we remove the duplicate factor spec
                        % here to avoid the confusing two assignments that get stored in the
                        % log.
                        % Look for matchin plg and trg in the v, which is
                        % initially created from factorSpecs, and then
                        % overruled by conditionSpecs.
                        if isempty(v)
                            % If a previous dplicate removal makes the
                            % FactorSpecs in v empty, then we'er done
                            % pruning v.
                            break;
                        else
                            % Check for duplicates and remove
                            duplicateSetting = strcmpi(o.conditionSpecs{cond}{i,1},v(:,1)) & strcmpi(o.conditionSpecs{cond}{i,2},v(:,2));                            
                            v(duplicateSetting,:) = []; %#ok<AGROW> %Rmove seting that came from factor specs (or previous condition spec)
                        end                         
                    end
                    v = cat(1,v,o.conditionSpecs{cond}); % Combine condition with factor specs (in v; pruned of duplcates).
                end
            end
        end
        
        
        function show(o,f,str)
            % Function to show the condition specifications in a figure.
            % f - the dimensions of the design to show (e.g. [1 2] to
            % show the first two factors, or [1 3] to show factors 1 and 3
            % against , or even  [1 2 3] to show all three in a 3D
            % representation (use rotate3D to inspect the design ).
            %str - string to add to the title (used by cic.showDesign to
            %show blocks)
            if nargin <3
                str = '';
            end
            if nargin <2 || isempty(f)
                f = 1:o.nrFactors;
                f(f>3)=[];
                if isempty(f)
                    f=1;
                end
            end
            spcs = cell(1,o.nrConditions);
            for c=1:o.nrConditions
                spcs{c} = specs(o,c);
            end
            spcs = reshape(spcs,o.nrLevels);
            others = setdiff(1:o.nrFactors,f);
            
            if numel(f)>1
                spcs = permute(spcs,[f others]);
                wghts = permute(o.weights,[f others]);
            else
                wghts = 1;
            end
            nrY = size(spcs,1);
            nrX = size(spcs,2);
            if numel(f)<3
                nrZ =1;
            else
                nrZ  =size(spcs,3);
            end
            figure('name',['Design:  ' o.name]);
            xlim([0.5 nrX+.5]);
            ylim([0.5 nrY+.5]);
            zlim([0.5 nrZ+0.5]);
            set(gca,'XTick',1:nrX,'YTick',1:nrY,'ZTick',1:nrZ);
            
            ylabel(['Factor #' num2str(f(1))])
            if nrX>1
                xlabel(['Factor #' num2str(f(2))])
            end
            if nrZ>1
                zlabel(['Factor #' num2str(f(3))])
            end
            title([str ': ' o.name ' :' num2str(o.nrFactors) '-way design. Rand: ' o.randomization]);
            hold on
            for k=1:nrZ
                for i=1:nrY
                    for j=1:nrX
                        this='';
                        for prm =1:size(spcs{i,j,k},1)
                            val = spcs{i,j,k}{prm,3};
                            if isnumeric(val)
                                val = num2str(val);
                            elseif isobject(val)
                                val = val.name;
                            elseif ~ischar(val)
                                val = '?';
                            end
                            this = char(this,strcat(spcs{i,j,k}{prm,1},'.',spcs{i,j,k}{prm,2},'=',val));
                        end
                        if numel(wghts)>1
                            this =char(this,['Weight=' num2str(wghts(i,j,k))]);
                        else
                            this =char(this,['Weight=' num2str(wghts)]);
                        end
                        cndNr = ['Condition: ' num2str(sub2ind([nrY nrX nrZ],i,j,k)) ];
                        this  = char(this,cndNr);
                        text(j,i,k,this,'HorizontalAlignment','Left','Interpreter','none','VerticalAlignment','middle')
                    end
                end
            end
            set(gcf,'Units','Normalized','Position',[0 0 1 1]);
            if numel(f)==3; view(3);end
        end
        function o=design(nm)
            % o=design(nm)
            % name - name of this design object
            o.name = nm;
        end
        
        function o2=duplicate(o1,nm)
            o2 =copyElement(o1);
            o2.name = nm;
        end
        
        % Called from block/afterTrial with information ont he success of
        % the previous trial. If success is false, the trial can be repeated
        % at a later time.
        function retry = afterTrial(o,success)
            if success || strcmpi(o.retry,'IGNORE') ||   o.retryCounter(o.condition) >= o.maxRetry
                retry = 0;
                return; % Nothing do do: either we don't want to retry, or we've retried the max already.
            end
            
            switch upper(o.retry)
                case 'IMMEDIATE'
                    insertIx = o.currentTrialIx +1 ;
                case 'RANDOM'
                    % Add the current to a random position in the list
                    % (past tbe current), then go to the next in the
                    % list.
                    insertIx= randi([o.currentTrialIx+1 numel(o.list)+1]);
                otherwise
                    error(['Unknown retry mode: ' o.retry]);
            end
            % Put a new item in the list.
            newList = cat(1,o.list(1:insertIx-1),o.list(o.currentTrialIx));
            if insertIx<=numel(o.list)
                newList= cat(1,newList,o.list(insertIx:end));
            end
            o.list = newList;
            retry = 1;
            o.retryCounter(o.condition) = o.retryCounter(o.condition) +1;  % Count the retries
        end
        
        function ok = beforeTrial(o)
            % Move the index to the next condition in the trial list.
            % Returns false if this is not possible (i.e. the design has been run completely).
            if o.currentTrialIx == numel(o.list)
                ok = false; % No next trial possible. Caller will have to shuffle the design or pick a new one.
            else
                ok = true;
                o.currentTrialIx =o.currentTrialIx +1;
            end
        end
        
        function shuffle(o)
            % Shuffle the list of conditions and set the "currentTrialIx" to
            % the first one in the list
            conds=ones(1,o.nrConditions);
            conds=cumsum(conds);
            weighted=repelem(conds(:),o.weights(:));
            weighted=weighted(:);
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    o.list=weighted;
                case 'RANDOMWITHREPLACEMENT'
                    o.list=datasample(weighted,numel(weighted));
                case 'RANDOMWITHOUTREPLACEMENT'
                    o.list=Shuffle(weighted);
            end
            o.retryCounter = zeros(o.nrConditions,1);
            o.currentTrialIx =1; % Reset the index to start at the first entry
        end
        
        function o = subsasgn(o,S,V)
            % subsasgn to create special handling of .weights .conditions, and
            % .facN design specifications.
            handled = false; % If not handled here, we call the builtin below.

            if strcmpi(S(1).type,'.')
                if strcmpi(S(1).subs,'WEIGHTS')
                    handled =true;
                    
                    %If a vector of weights (i.e. a one-factor design), make a
                    %column vector (to match up with the nLevels x 1 output of o.nrLevels
                    if isvector(V)
                        V = V(:);
                    end
                    
                    if numel(V) ==1 || isequal(size(V),o.nrLevels)
                        o.weights = V;
                    else
                        error(['These weights [' num2str(size(V)) '] do not match the design [' num2str(size(o)) ']']);
                    end
                elseif strcmpi(S(1).subs,'CONDITIONS')
                    %% CONDITIONS Spec
                    handled =true;
                    % Users should specify indices (=levels) for each of
                    % the dimensions of the design, so we do some error
                    % checking to make sure they wrote something like
                    % d.conditions(a,b).plg.parm= 5 where a and b can be
                    % vectors or even ':'
                    % note that 'end' cannot be used in this specification
                    % (beacuse matlab will try to find o.conditions first,
                    % which does not really exist...
                    if ~strcmpi(S(2).type,'()')
                        if strcmpi(S(2).type,'.') && strcmpi(S(3).type,'.')
                            plg     = S(2).subs;
                            prm     = S(3).subs;
                            error(['Conditions must be specified. e.g. d.conditions(10,:).' plg '.' prm '=...']);
                        else
                            error('Please use .conditions(i,j) to specify conditions');
                        end
                    else
                        targetFactors = S(2).subs;
                        if o.nrFactors >0 && (targetFactors{end}~=1 && numel(targetFactors) ~= o.nrFactors && ~(numel(targetFactors)==1 && strcmpi(targetFactors{1},':'))) % allow (:,1) for a one-factor
                            error(['Specify an entry for each of the ' num2str(o.nrFactors) ' dimensions of .conditions'])
                        end
                    end
                    if strcmpi(S(3).type,'.') && strcmpi(S(4).type,'.')
                        plg     = S(3).subs;
                        prm     = S(4).subs;
                    else
                        error('Please specify both a plugin/stimulus and a parameter: .conditions(i,j).plugin.parm = ...');
                    end
                    ix = S(2).subs; % The ix into the condition matrix
                    if numel(ix)==1 && strcmpi(ix{1},':') && o.nrFactors>1
                        % Singleton expansion of (:) to  (:,:)
                        ix = cell(1,o.nrFactors);
                        [ix{:}] = deal(':');
                    end
                    if o.nrFactors>0
                        %% Factors have previously been defined. Allow only
                        % modifications of the full factorial, not
                        % conditions that are outside the factorial
                        
                        % Allow users to use singleton or vectors to specify
                        % levels (if the parameter value of a single level is a
                        % vector, put it in a cell array).
                        
                        lvls = o.nrLevels;
                        
                        
                        for f=1:o.nrFactors
                            if strcmpi(ix{f},':')
                                % Replace : with  1:end
                                ix{f} = 1:lvls(f);
                            end
                        end
                        
                        if ischar(V) || (~iscell(V) && isscalar(V))
                            V = {V};
                        elseif ~iscell(V) 
                            nrInTrg = cellfun(@numel,ix);
                            nrInSrc = size(V);
                            match = false;
                            if numel(nrInTrg)==numel(nrInSrc) && all(nrInTrg==nrInSrc)
                                match = true;
                            end
                            
                            if ~match
                                % trg could have trailing singleton
                                % dimensions.
                                nrMatchingDims = min(numel(nrInSrc),numel(nrInTrg));
                                matchingDims = 1:nrMatchingDims;
                                match = all(nrInTrg(matchingDims)==nrInSrc(matchingDims)) && all(nrInTrg(nrMatchingDims+1:end)==1) && all(nrInSrc(nrMatchingDims+1:end)==1);
                            end
                               
                            if match
                                % This is a matrix where each element is
                                % intended as a level for a factor.
                                V = neurostim.utils.vec2cell(V);
                            else
                                % This is a matrix that we're
                                % assigning to each level
                                V = {V};
                            end
                        end
                        
                        for f=1:o.nrFactors
                            if ~(numel(V)==1 || size(V,f) == numel(ix{f}))
                                error(['The number of values on the RHS [' num2str(size(V)) '] does not match the number specified on the LHS [' num2str(lvls) ']']);
                            end
                        end
                        ix = neurostim.utils.allcombinations(ix{:});
                        if size(ix,2) ==1
                            ix = [ix ones(numel(ix),1)]; % NEed this below for comparison with size(conditionSpecs)
                        end
                        if any(max(ix,[],1)>lvls)
                            error(['Some conditions do not fit in the [' num2str(lvls) '] factorial. Use a separate design for these conditions']);
                        end
                        %% Everything should match, lets assign

                        % we know the number of factors and the number of
                        % levels for each... initialize o.conditionSpecs if
                        % it hasn't been initialized already
                        if isempty(o.conditionSpecs)
                          o.conditionSpecs = cell(o.nrLevels);
                        end
                        
                        for i=1:size(ix,1)
                            trgSub = neurostim.utils.vec2cell(ix(i,:));
                            if numel(V) == 1
                                srcSub = {1};
                            else
                                srcSub = trgSub;
                            end
                            thisV = V{srcSub{:}};
                            if isa(thisV,'neurostim.plugins.adaptive')
                                thisV.belongsTo(o.name,o.lvl2cond(ix(i,:))); % Tell the adaptive to listen to this design/level combination
                            end

                            % add to previous, or replace if it refers to the same property
                            curSpecs = o.conditionSpecs{trgSub{:}};
                            if ~isempty(curSpecs)
                                %Check if we need to remove an existing value for this property
                                isPlgMatch = cellfun(@(curSpecs) strcmp(curSpecs,plg),curSpecs(:,1));
                                isPrmMatch = cellfun(@(curSpecs) strcmp(curSpecs,prm),curSpecs(:,2));
                                curSpecs(isPlgMatch&isPrmMatch,:) = []; %Remove any matching line item
                            end

                            %Add this property to the list for this condition
                            o.conditionSpecs{trgSub{:}} = cat(1,curSpecs,{plg,prm,thisV});
                        end
                    else
                        %% Conditions-only design, specified one at a time
                        %d.conditions(1).bla.x = 1;
                        if numel(ix)>1 || numel(ix{1})>1
                            error('A pure .conditions design must be specified one condition at a time');
                        end
                        ix = ix{1};
                        if  isa(V,'neurostim.plugins.adaptive')
                            V.belongsTo(o.name,ix); % Tell the adaptive to listen to this design/level combination
                        end
                        if ix> numel(o.conditionSpecs)  || isempty(o.conditionSpecs{ix})
                            o.conditionSpecs{ix} = {plg,prm,V};
                        else
                            o.conditionSpecs{ix} = cat(1,o.conditionSpecs{ix},{plg,prm,V});
                        end
                    end
                elseif strncmpi(S(1).subs,'FAC',3)
                    %% FAC spec
                    % Specify parameter settings for one of the factors.
                    % For instance, for a 5x3 factorial that varies X and Y
                    % in the fix stimulus:
                    % d.fac1.fix.X = 1:5
                    % d.fac2.fix.Y = 1:3
                    handled = true;
                    if ~isempty(o.conditionSpecs)
                        error('Factors (.fac1,.fac2, etc.) must be defined before .conditions');
                    end
                    if numel(S)~=3
                        error('Factor specifiction must be of the form: o.facN.plugin.parm = values')
                    end
                    % Extrac the current specifications
                    factor  = str2double(S(1).subs(4:end));
                    plg     = S(2).subs;
                    prm     = S(3).subs;
                    
                    % Allow users to use singleton or vectors to specify
                    % levels (if the parameter value of a single level is a
                    % vector, put it in a cell array).
                    if ~iscell(V) && (ischar(V) || isscalar(V))
                        V = {V};
                    elseif ~iscell(V)
                        V = neurostim.utils.vec2cell(V);
                    end
                    % Check that the current specification matches what has
                    % already been specified (but allow singleton
                    % expansion, using repmat).
                    thisNrLevels = numel(V);
                    if factor<=o.nrFactors
                        levelsPreviouslyDefined = sum(~cellfun(@isempty,o.factorSpecs(factor,:)));
                        if thisNrLevels==1
                            V = repmat(V,1,levelsPreviouslyDefined); % Copy the singleton to match previous factorSpecs.
                            thisNrLevels = levelsPreviouslyDefined;
                        elseif levelsPreviouslyDefined ==1
                            warning(['Creating ' num2str(thisNrLevels) ' levels for ' plg '.' prm '. If you just wanted one level, use {}']);                                
                            [o.factorSpecs{factor,1:thisNrLevels}] =deal(o.factorSpecs{factor,1}); % make copies of the singleton spec that was previosuly defined
                        elseif levelsPreviouslyDefined ==0
                            % New factor (e.g. fac2 was defined before fac1 )
                        elseif thisNrLevels ~=levelsPreviouslyDefined
                            error(['The number of levels for ' plg '.' prm ' (' num2str(thisNrLevels) ') does not match with previous specifications (' num2str(levelsPreviouslyDefined) ')']);
                        end
                    else
                        % New factor.
                    end
                    
                    % Now loop through all the new values and store them in
                    % the factorSpecs cell array [nrFactors, nrLevels]
                    % factor 1: level1 level2...
                    % factor 2: level 1 level2
                    for i=1:thisNrLevels
                        if isa(V{i},'neurostim.plugins.adaptive')
                            % The .conditions interface has the flexibility
                            % to handle all adaptive parameter options
                            error('Please use design.conditions(i,j) = ... to specify adaptive parameters');
                        end
                        if any([factor i]>size(o.factorSpecs)) || isempty(o.factorSpecs(factor,i))
                            % New spec for this factor/level.
                            o.factorSpecs{factor,i} = {plg,prm,V{i}};
                        else
                            %Add new spec to exsting spec
                            o.factorSpecs{factor,i} = cat(1,o.factorSpecs{factor,i}, {plg,prm,V{i}});
                        end
                    end
                end
            end
            
            %% We're only handling a small subset  of subsasgn here, the rest is passed
            % to builtin
            if ~handled
                % Call builtin
                o = builtin('subsasgn',o,S,V);
            end
        end
    end
    
    methods (Access=protected)
        function o1= copyElement(o2)
            o1 = copyElement@matlab.mixin.Copyable(o2);
        end
        
        function v= cond2lvl(o,cond)
            % Return the factor levels for a specified condition
            if o.nrFactors>0
                lvls = cell(1,o.nrFactors);
                [lvls{:}] = ind2sub(o.nrLevels,cond);
                v = [lvls{:}];
            else
                v = [cond 1];
            end
        end
        
        function v = lvl2cond(o,lvl)
            %Return the condition number for a specific multidimensional level index.
            lvl = neurostim.utils.vec2cell(lvl);
            v = sub2ind(o.nrLevels,lvl{:});
        end
    end
end
