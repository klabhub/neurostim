classdef design <handle
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
    % Major redesign
    properties
        randomization='RANDOMWITHOUTREPLACEMENT';
        name@char;                      % The name of this design; bookkeeping/logging use only.
        factorSpecs@cell={};            % A cell array of condition specifications for factorial designs
        conditionSpecs@cell ={};         % Conditions specifications that deviate from the full factorial
        list@double;                    % The order in which conditions will be run.
        weights@double=1;               % The relative weight of each condition. (Must be scalar or the same size as specs)
        currentTrialIx =0;                   % The condition that will be run in this trial (index in to .list)
    end
    
    properties (Dependent)
        nrConditions;                   % The total number of conditions in this design
        nrFactors;                      % The number fo factors in the design
        nrTrials;                       % The total number of trials (takes .weights into account)
        nrLevels;                       % The levels per factor
        done;                           % True after all conditions have been run
        levels;                         % Vector subscript (factors) for the current condition
        condition;                  % Linear index of the current condition
        specs;                          % Cell array with specs for the current condition
    end
    
    properties (Constant)
        designNames ={};                   % List of all names given to designs. Used to ensure uniqueness.
    end
    
    
    methods  %/get/set
        
        function v=size(o)
            v= o.nrLevels;
            if isempty(v)
                v = [o.nrConditions 1];
            end
        end
        
        function v= get.done(o)
            v = ismember(o.currentTrialIx ,[0 o.nrTrials]);
        end
        
        function v=get.nrTrials(o)
            v = numel(o.list);
        end
        function v= get.nrFactors(o)
            v = size(o.factorSpecs,1);
        end
        
        function v=get.nrConditions(o)
            v=prod(o.nrLevels);
        end
        
        function v=get.nrLevels(o)
            factor = 1:o.nrFactors;
            v = sum(~cellfun(@isempty,o.factorSpecs(factor,:)),2)';
            if isempty(v)
                v= numel(o.conditionSpecs);
            end
        end
        
        function v = get.levels(o)
            % The currrent condition as a subscript into
            % the factorial design:
            % [2 3] = 2nd level first factor, 3rd level 2nd factor.
            % For a non-factorial design this is [i 1] with i the condition
            if o.nrFactors>0
                lvls = cell(1,o.nrFactors);
                [lvls{:}] = ind2sub(o.nrLevels,o.condition);
                v = [lvls{:}];
            else
                v = [o.condition 1];
            end
        end
        
        function v = get.condition(o)
            % Linear index for the current condition
            v= o.list(o.currentTrialIx);
        end
        
        function v= get.specs(o)
            % Return a cell array with the specifcations for the current
            % condition .
            
            % o.levels and o.condition provide the same information, the former is easier for
            % factorSpecs , the latter for conditionSpecs
            lvls = o.levels;
            v={};
            for f=1:o.nrFactors
                v = cat(1,v,o.factorSpecs{f,lvls(f)});
                if ~isempty(o.conditionSpecs) && lvls(f) > size(o.conditionSpecs,f)
                    error(['The ' o.name ' design is corrupted']);
                end
                if ~isempty(o.conditionSpecs{o.condition})
                    v = cat(1,v,o.conditionSpecs{o.condition});
                end
            end
        end
    end
    
    
    methods (Access = public)
        
        function o=design(nm)
            % o=design(nm)
            % name - name of this design object
            if ismember(nm,neurostim.design.designNames)
                error(['The name ' nm  ' is already in use for a design. Please choose a different one']);
            end
            o.name = nm;
            neurostim.design.designNames= cat(2,neurostim.design.designNames,nm);
        end
        
        function ok = nextTrial(o)
            if o.currentTrialIx == numel(o.list)
                ok = false; % No next trial possible. Caller will have to shuffle the design or pick a new one.
            else
                ok = true;
                o.currentTrialIx =o.currentTrialIx +1;
            end
        end
        
        function shuffle(o)
            % Shuffle the list of conditions
            conds=ones(1,o.nrConditions);
            conds=cumsum(conds);
            weighted=repelem(conds(:),o.weights(:));
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    o.list=weighted;
                case 'RANDOMWITHREPLACEMENT'
                    o.list=datasample(weighted,numel(weighted));
                case 'RANDOMWITHOUTREPLACEMENT'
                    o.list=Shuffle(weighted);
            end
            o.currentTrialIx =1; % Reset the index to start at the first entry
        end
        
        function o = subsasgn(o,S,V)
            % subsasgn to create special handling of .weights .conditions, and
            % .facN design specifications.
            handled = false; % If not handled here, we call the builtin below.
            if strcmpi(S(1).type,'.')
                if strcmpi(S(1).subs,'WEIGHTS')
                    handled =true;
                    if numel(V) ==1 ||  (ndims(V)==o.nrFactors && all(size(V)==o.nrLevels))
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
                        if o.nrFactors >0 && (targetFactors{end}~=1 && numel(targetFactors) ~= o.nrFactors) % allow (:,1) for a one-factor
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
                    if o.nrFactors>0
                        %% Factors have previously been defined. Allow only
                        % modifications of the full factorial, not
                        % conditions that are outside the factorial
                                               
                        % Allow users to use singleton or vectors to specify
                        % levels (if the parameter value of a single level is a
                        % vector, put it in a cell array).
                        if ischar(V) || isscalar(V)
                            V = {V};
                        elseif ~iscell(V)
                            V = neurostim.utils.vec2cell(V);
                        end
                        
                        lvls = o.nrLevels;
                        for f=1:o.nrFactors
                            if strcmpi(ix{f},':')
                                % Replace : with  1:end
                                ix{f} = 1:lvls(f);
                            end
                            if ~(numel(V)==1 || numel(V) == lvls(f))
                                error(['The number of values on the RHS [' num2str(size(V)) '] does not match the number specified on the LHS [' num2str(lvls) ']']);
                            end
                        end
                                               
                        ix = neurostim.utils.allcombinations(ix{:});
                        if size(ix,2) ==1
                            ix = [ix ones(numel(ix),1)]; % NEed this below for comparison with size(conditionSpecs)
                        end
                        if any(max(ix)>lvls)
                            error(['Some conditions do not fit in the [' num2str(lvls) '] factorial. Use a separate design for these conditions']);
                        end
                        %% Everything should match, lets assign
                        for i=1:size(ix,1)
                            trgSub = neurostim.utils.vec2cell(ix(i,:));
                            if numel(V)==1
                                srcSub = {1};
                            else
                                srcSub  =trgSub;
                            end
                            thisV = V{srcSub{:}};
                            if isa(thisV,'neurostim.plugins.adaptive')
                                if o.nrFactors>1
                                    linearIx = sub2ind(o.nrLevels,ix(i,:));
                                else
                                    linearIx = ix(i,1);
                                end
                                thisV.belongsTo(o.name,linearIx); % Tell the adaptive to listen to this design/level combination
                            end                            
                            if ndims(o.conditionSpecs)<numel(trgSub) || any(size(o.conditionSpecs)<[trgSub{:}]) || isempty(o.conditionSpecs(trgSub{:}))
                                % new spec for this condition
                                o.conditionSpecs{trgSub{:}} = {plg,prm,thisV};
                            else
                                % add to previous 
                                o.conditionSpecs{trgSub{:}} = cat(1,o.conditionSpecs{trgSub{:}},{plg,prm,thisV});
                            end
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
                    if ischar(V) || isscalar(V)
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
end
