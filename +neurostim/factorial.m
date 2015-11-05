classdef factorial < dynamicprops
    % Class for establishing factorials and default properties.
    % Constructor:
    % o=factorial(name,nrFactors)
    %
    % Inputs:
    % name - name of the Factorial
    % nrFactors - number of factors (for property creation)
    %
    % Outputs:
    % o - passes out a factorial structure with editable fields for
    % establishing a factorial design.
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
    
    properties
        randomization='SEQUENTIAL';
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
            for a=1:o.nrFactors
                field1=fieldnames(o.(['fac' num2str(a)]));
                field1=field1(~strcmp(field1,'weights'));
                for b=numel(field1)
                    q=field1{b};
                    field2=fieldnames(o.(['fac' num2str(a)]).(q));
                    for c=numel(field2)
                        x=field2{c};
                        nrLevels=numel(o.(['fac' num2str(a)]).(q).(x));
                        currV(end+1)=nrLevels;
                    end
                    if all(currV==currV(1))
                        v(a)=currV(1);
                        currV=[];
                    else
                        error('Number of levels is inconsistent.');
                    end
                end
            end
        end
        
        function v=get.nrConditions(o)
            v=prod(o.nrLevels);
        end
        
        function v=get.weights(o)
            for a=1:o.nrFactors
                
                if ~isempty(o.(['fac' num2str(a)]).weights)
                    if max(size(o.(['fac' num2str(a)]).weights))~=o.nrLevels(a)
                        error('Number of weights are not equal to the number of levels.');
                    elseif a==1
                        weights=o.(['fac' num2str(a)]).weights;
                    else
                        vec=o.(['fac' num2str(a)]).weights;
                        weights=kron(vec,weights);
                    end
                else
                    weights=ones(1,o.nrConditions);
                    break;
                end
            end
            v=weights;
        end
        
        
        function v=get.conditionList(o)
            conditions=ones(1,prod(o.nrLevels));
            conditions=cumsum(conditions);
            weighted=o.repeatElem(conditions,o.weights);
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
            conditions=neurostim.map;
            subs = cell(1,o.nrFactors);
            for a=1:o.nrConditions
               conditionName=[o.name num2str(a)];
               conditionSpecs= {};
               [subs{:}]= ind2sub(o.nrLevels,a);
                for f=1:o.nrFactors
                    currSpecs =o.factorSpecs.(['fac' num2str(f)]);
                    nrParms = numel(currSpecs)/3;
                    for p=1:nrParms
                        value = currSpecs{3*p}{subs{f}};
                        specs = currSpecs(3*p-2:3*p);
                        specs{3} = value;
                        conditionSpecs = cat(2,conditionSpecs,specs);
                    end
                end
                conditions(conditionName)=conditionSpecs;
            end
            v=conditions;
        end
        
        function v=get.factorSpecs(o)
            for f=1:o.nrFactors
                    list2=fieldnames(o.(['fac' num2str(f)]));
                    list2=list2(~strcmpi(list2,'weights'));
                    for g=1:numel(list2)
                        list3=fieldnames(o.(['fac' num2str(f)]).(list2{g}));
                        for h=1:numel(list3)
                        factorSpecs.(['fac' num2str(f)]){1,(g-1)*3+1}=list2{g};
                        factorSpecs.(['fac' num2str(f)]){1,(g-1)*3+2}=list3{h};
                        factorSpecs.(['fac' num2str(f)]){1,(g-1)*3+3}=o.(['fac' num2str(f)]).(list2{g}).(list3{h});
                        end
                    end
            end
            v=factorSpecs;
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
            o.nrFactors=nrFactors;
            % levels under the name 'fac1','fac2',etc.
                for a=1:nrFactors
%                     o.addProperty(['fac' num2str(a)],struct('weights',[]),[],@(x)(all(ismember(fieldnames(x),[c.stimuli 'weights']))))
                    o.addProperty(['fac' num2str(a)],struct('weights',[]))

                end
                
        end
        
        
        function addProperty(o,prop,value,postprocess,validate)
            h = o.addprop(prop);
            h.SetObservable=true;
            if nargin <5
                validate = '';
                if nargin<4
                    postprocess = '';
                end
            end
            % Setup a listener for logging, validation, and postprocessing
            o.addlistener(prop,'PostSet',@(src,evt)logParmSet(o,src,evt,postprocess,validate));
             % Set it, this will call the logParmSet function as needed.
            o.(prop)=value;

        end
        
        function logParmSet(o,src,evt,postprocess,validate)
            value=o.(src.Name);
            if nargin >=5 && ~isempty(validate)
                success = validate(value);
                if ~success
                    error(['Setting ' src.Name ' failed validation ' func2str(validate)]);
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