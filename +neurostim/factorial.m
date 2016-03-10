classdef factorial < dynamicprops
    % Class for establishing factorials for experiment setup.
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
    % This should be of the format:
    % o.fac1.(stimName).(paramName) = {cell list of parameters}
    % To vary multiple parameters together, add them under the same factor
    % (i.e. fac1.(stimName2).(paramName2)={another cell list}.
    % Each subsequent factor should be added with an increasing number
    % (i.e. fac2, fac3).
    %
    % E.g.
    % To specify a single one-way factorial:
    % myFac=factorial('myFactorial',c,1)
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
    
    
    properties
        randomization='RANDOMWITHOUTREPLACEMENT';
        nrFactors;
        name;
    end
    
    properties (Dependent)
        nrLevels;
        weights;
        conditionList;
        conditions;
        nrConditions;
    end
    
    properties (Dependent,Access=private)
        factorSpecs;
    end
    
    methods
        function v=get.nrLevels(o)
            currV=[];
            %             v=zeros(size(o.nrFactors,1));
            for f=1:o.nrFactors
                field1=fieldnames(o.(['fac' num2str(f)]));
                field1=field1(~strcmp(field1,'weights'));
                for b=1:numel(field1)
                    q=field1{b};
                    field2=fieldnames(o.(['fac' num2str(f)]).(q));
                    for c=1:numel(field2)
                        x=field2{c};
                        v=numel(o.(['fac' num2str(f)]).(q).(x));
                        currV(end+1)=v; %#ok<AGROW>
                    end                   
                end
                 uV = unique(currV);
                    % The nrLevels should be the same for all parameters, except that we
                    % allow parameters to have just one value (that applies
                    % to all levels of the other parms).
                    if (numel(uV)==1 || numel(uV(uV~=1))==1)
                        v(f)=max(uV); % Unique sorts 
                        currV=[];
                    else
                        error('Number of levels is inconsistent.');
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
        
        
        function v=get.conditionList(o)
            conds=ones(1,prod(o.nrLevels));
            conds=cumsum(conds);
            weighted=o.repeatElem(conds,o.weights);
            switch upper(o.randomization)
                case 'SEQUENTIAL'
                    v=weighted;
                case 'RANDOMWITHOUTREPLACEMENT'
                    v=Shuffle(weighted);
                case 'RANDOMWITHREPLACEMENT'
                    v=datasample(weighted,numel(weighted));
            end
        end
        
        function v=get.conditions(o)
            v=neurostim.map;
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
                        if numel(currSpecs{3*p})==1 % Allow specifications of a single value for one property to apply to all levels of another property (i.e. scalar->vector expansion)
                            thisSpecs(3) =currSpecs{3*p};
                        else
                            thisSpecs(3)= currSpecs{3*p}(subs{f});
                        end
                        conditionSpecs = cat(2,conditionSpecs,thisSpecs);
                    end
                end
                v(conditionName)=conditionSpecs;
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
    
    
    
    methods
        
        function o=factorial(name,nrFactors)
            % o=factorial(name,nrFactors)
            % name - name of the Factorial
            % c - pass in a reference to cic.
            % nrFactors - number of factors (for property creation)
            if nargin<2
                nrFactors=1;
            end
            o.name=name;
              % levels under the name 'fac1','fac2',etc.
            for a=1:nrFactors
                o.addProperty(['fac' num2str(a)],struct('weights',[]))
            end
            o.nrFactors=nrFactors; % Only set once the fac1..N properties have been added.          
        end
        
        
        function addProperty(o,prop,value)
            h = o.addprop(prop);
            h.SetObservable=true;
            % Setup a listener for postprocessing
            o.addlistener(prop,'PostSet',@(src,evt)postSetProperty(o,src,evt));
            % Set it, this will call the postSetProperty function.
            o.(prop)=value;
        end
        
        
        
        function postSetProperty(o,src,evt)             
            for f=1:o.nrFactors
                plgins=fieldnames(o.(['fac' num2str(f)]));
                plgins=plgins(~strcmpi(plgins,'weights'));                
                for plgNr=1:numel(plgins)
                    props=fieldnames(o.(['fac' num2str(f)]).(plgins{plgNr}));
                    for propNr=1:numel(props)
                        values = o.(['fac' num2str(f)]).(plgins{plgNr}).(props{propNr});
                        % All values should be cells, but to allow users to
                        % specify vectors or scalars more easily, we
                        % postprocess here
                        if ~iscell(values)
                            if ischar(values) || isscalar(values) 
                                values = {values};
                            else
                                values = neurostim.utils.vec2cell(values);
                            end
                            o.(['fac' num2str(f)]).(plgins{plgNr}).(props{propNr}) = values;
                        end
                    end
                end
            end
        end
        
        function v=repeatElem(o,x,ind)
            % repeats elements of vector x by the number of times given by
            % indices ind.
            if any(size(ind)~=size(x))
                ind=ones(size(x))*ind;
            end
            cs=cumsum(ind);
            idx=zeros(1,cs(end));
            idx(1+[0 cs(1:end-1)]) = 1;
            idx=cumsum(idx);
            v=x(idx);
        end
        
    end
end