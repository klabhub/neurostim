classdef factorial < dynamicprops
    % Class for establishing factorial designs for experiments.
    % Constructor:
    % o=factorial(name,nrFactors)
    %
    % Inputs:
    %   name - name of the Factorial
    %   nrFactors - number of factors (for property creation)
    %
    % Outputs:
    %   o - passes out a factorial structure with editable fields for
    %       establishing a factorial design.
    %
    % Object member variables that you can changer are:
    % o.randomization
    %
    % Examples :
    % This should be of the format:
    % o.fac1.(stimName).(paramName) = parameters
    % To vary multiple parameters in multiple stimuli together, add them under the same factor
    % (i.e. fac1.(stimName2).(paramName2)= parameters
    
    % Each subsequent factor should be added with an increasing number
    % (i.e. fac2, fac3).
    %
    % E.g.
    % To specify a single one-way factorial:
    % myFac=factorial('myFactorial',1);
    % myFac.fac1.dots.coherence={0 0.5 1};
    %
    % To vary both coherence and position together:
    % myFac.fac1.dots.coherence={0 0.5 1};
    % myFac.fac1.dots.position={0 -5 5};
    %
    % To vary coherence against position in a two-way factorial (3x3):
    % myFac.fac1.dots.coherence={0 0.5 1};
    % myFac.fac2.dots.position={0 -5 5};
    %
    % To assign different weights to conditions:
    % myFac.fac1.weights=[1 1 2] % assigns fac1's parameters the according
    %   weights (in order), by repeating conditions the number of weighed times.
    %
    % Singleton specifications are fine too. For instance to change the
    % lifetime of the dots to 100 for this factorial (as opposed to the
    % default lifetime that you may have used in a different factorial)
    % myFac.fac1.dots.coherence={0 0.5 1};
    % myFac.fac1.dots.lifetime = 100;
    %
    % TK, BK, 2016
    
    properties
        randomization='RANDOMWITHOUTREPLACEMENT';
        name;
        nrFactors;
        conditions@neurostim.map;
        list;
    end
    
    properties (Dependent)
        nrLevels;
        weights;
        nrConditions;
    end
    
    
    properties (Dependent,Access=private)
        factorSpecs;
    end
    
    
    methods  %/get/set
        
        function v=size(o)
            v= o.nrLevels;
        end
        
        function v=get.nrLevels(o)
            %Get the number of levels for each factor
            for i=1:o.nrFactors
               thisFac = (horzcat('fac',num2str(i)));
               plugins = fieldnames(o.(thisFac));
               plugins = setdiff(plugins,'weights');
               
               %Can just check first entry because all are ensured to match at the time they are set
               if ~isempty(plugins)     %Empty only when factors are yet to be specified.
                   props = fieldnames(o.(thisFac).(plugins{1}));
                   v(i) = numel(o.(thisFac).(plugins{1}).(props{1}));
               else
                   v(i) = 0;
               end
            end
        end
        
        function v=get.nrConditions(o)
            v=prod(o.nrLevels);
        end
        
        function v=get.weights(o)
            v =[];
            for a=1:o.nrFactors
                if ~isempty(o.(['fac' num2str(a)]).weights)
                    if max(size(o.(['fac' num2str(a)]).weights))~=o.nrLevels(a)
                        error('Number of weights are not equal to the number of levels.');
                    elseif a==1
                        v=o.(['fac' num2str(a)]).weights;
                    else
                        vec=o.(['fac' num2str(a)]).weights;
                        v=kron(vec,v);
                    end
                else
                    v=ones(1,o.nrConditions);
                    break;
                end
            end
        end
        
        
        function v=get.factorSpecs(o)
            v=struct;
            for f=1:o.nrFactors
                plgins=fieldnames(o.(['fac' num2str(f)]));
                plgins=plgins(~strcmpi(plgins,'weights'));
                cntr= 0;
                for plgNr=1:numel(plgins)
                    props=fieldnames(o.(['fac' num2str(f)]).(plgins{plgNr}));
                    for propNr=1:numel(props)
                        v.(['fac' num2str(f)]){1,cntr+1}=plgins{plgNr}; %Plgin/stimulus
                        v.(['fac' num2str(f)]){1,cntr+2}=props{propNr}; % Parameter
                        v.(['fac' num2str(f)]){1,cntr+3}=o.(['fac' num2str(f)]).(plgins{plgNr}).(props{propNr}); % Value
                        cntr=cntr+3;
                    end
                end
            end
        end
    end
    
    methods (Access = public)
        
        function o=factorial(name,nrFactors)
            % o=factorial(name,nrFactors)
            % name - name of the Factorial
            % nrFactors - number of factors (for property creation)
            if nargin<2
                nrFactors=1;
            end
            o.name = name;
            % levels under the name 'fac1','fac2',etc.
            for a=1:nrFactors
                prop = ['fac' num2str(a)];
                h = o.addprop(prop);
                h.SetObservable=true;
                % Setup a listener for postprocessing
                o.addlistener(prop,'PostSet',@(src,evt)postSetProperty(o,src,evt));
                % Set it, this will call the postSetProperty function.
                o.(prop)=struct('weights',[]);
            end
            o.nrFactors=nrFactors; % Only set once the fac1..N properties have been added.
        end
        
        
        %% Unpack the factorial into a conditions map and a list.
        function setupExperiment(o)
            
            % Setup the conditions map.
            o.conditions = neurostim.map; %  Start empty
            subs = cell(1,o.nrFactors);
            for a=1:o.nrConditions
                conditionName=[o.name '_' num2str(a)];
                conditionSpecs= {};
                [subs{:}]= ind2sub(o.nrLevels,a);
                for f=1:o.nrFactors
                    currSpecs =o.factorSpecs.(['fac' num2str(f)]);
                    nrParms = numel(currSpecs)/3;
                    for p=1:nrParms
                        thisSpecs = currSpecs(3*p-2:3*p);
                        thisSpecs(3)= currSpecs{3*p}(subs{f});
                        conditionSpecs = cat(2,conditionSpecs,thisSpecs);
                    end
                end
                o.conditions(conditionName)=conditionSpecs;
            end
            
            o.reshuffle; % Setup the list
            
        end
        function reshuffle(o)
            conds=ones(1,o.nrConditions);
            conds=cumsum(conds);
            weighted=neurostim.utils.repeat(conds,o.weights);
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    o.list=weighted;
                case 'RANDOMWITHREPLACEMENT'
                    o.list=datasample(weighted,numel(weighted));
                case 'RANDOMWITHOUTREPLACEMENT'
                    o.list=Shuffle(weighted);
            end
        end
        
        
        
    end
    
    
    
    
    methods (Access = protected)
        
        
        
        % Postprocess factorial specification to ensure validity
        % and to allow users to use vectors, and single
        % entries that should be used for all levels of a factor.
        % This is called in response to o.fac1.stim.prop = value
        function postSetProperty(o,src,evt)
            for f=1:o.nrFactors
                nLevels = [];
                plgins=fieldnames(o.(['fac' num2str(f)]));
                plgins=plgins(~strcmpi(plgins,'weights'));
                for plgNr=1:numel(plgins)
                    thisPlugIn = o.(['fac' num2str(f)]).(plgins{plgNr});                    
                    props=fieldnames(thisPlugIn);
                    nLev = structfun(@numel,thisPlugIn);
                    
                    %Allow the user to give a single value for a property to be used for all levels of the current factor
                    if any(nLev==1) && max(nLev) > 1
                        
                        %Duplicate the single value across all levels to match the other property
                        theseProps = props(nLev==1);
                        for i=1:numel(theseProps)
                            thisPlugIn.(theseProps{i}) = repmat(thisPlugIn.(theseProps{i}),1,max(nLev));
                        end
                    end
                    
                    %Check that all properties now have the same number of levels
                    nLev = structfun(@numel,thisPlugIn);
                    if numel(unique(nLev))>1
                        error('Invalid factorial specification. The number of levels must be constant across properties.');
                    else
                        nLevels(plgNr) = unique(nLev);
                    end
                    
                    %If a vector is specified rather than a cell array, convert
                    theseProps = props(~structfun(@iscell,thisPlugIn));
                    for i=1:numel(theseProps)
                        values = thisPlugIn.(theseProps{i});
                        if ischar(values) || isscalar(values)
                            values = {values};
                        else
                            values = neurostim.utils.vec2cell(values);
                        end
                        thisPlugIn.(theseProps{i}) = values;
                    end
                    
                    %All done. Use this structure
                    o.(['fac' num2str(f)]).(plgins{plgNr}) = thisPlugIn;
                end
                
                %Check that number of levels match across plugins
                if numel(unique(nLevels))>1
                    error('Invalid factorial specification. The number of levels is inconsistent across plugins.');
                end
            end
        end
        
    end
end