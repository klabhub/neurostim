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
    % Fields include:
    %   myBlock.nrRepeats - number of repeats of the current block
    %
    %   myBlock.name - name of the block (string)
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
        factorials={};
        weights=[];
        nrRepeats=1;
        name;
        beforeMessage@char='';
        afterMessage@char='';
        beforeFunction; % function handle which takes cic as first arg
        afterFunction;
    end
    
    
    properties (Dependent)
        conditions;
        nrConditions;
        conditionList;
    end
    
    methods
        
        function set.beforeFunction(o,fun)
            o.beforeFunction = neurostim.str2fun(fun);            
        end
        
        function set.afterFunction(o,fun)
            o.afterFunction = neurostim.str2fun(fun);
        end
        
        
        function v=get.conditions(o)
            v=neurostim.map;
            for a=1:numel(o.factorials)
                temp=o.factorials{a}.conditions;
                v([temp.keys v.keys])=[temp.values v.values];
            end            
        end
        
        
            function v=get.nrConditions(o)
                v=0;
                for a=1:numel(o.factorials)
                    v=v+o.factorials{a}.nrConditions;
                end
            end
            
            function v=get.conditionList(o)
                v=[];
                for a=1:o.nrRepeats
                    thisV=[];
                    condNr=0;
                    for b=1:numel(o.factorials)
                        tmp=[];
                        currList=o.factorials{b}.conditionList;
                        if isempty(o.weights) || numel(o.weights)~=numel(o.factorials)
                            o.weights=ones(1,numel(o.factorials));
                        end
                        for c=1:o.weights(b)
                            tmp = [tmp currList]; %#ok<AGROW>
                        end
                        thisV=[thisV tmp+condNr]; %#ok<AGROW>
                        condNr=max(thisV);
                    end
                    switch upper(o.randomization)
                        case 'SEQUENTIAL'
                        case 'RANDOMWITHOUTREPLACEMENT'
                            thisV=Shuffle(thisV);
                        case 'RANDOMWITHREPLACEMENT'
                            thisV=datasample(thisV,numel(thisV));
                    end
                    v=[v thisV]; %#ok<AGROW>
                end
            end
                
                
                
    end
        
    
    
    
    methods
        function o=block(name,fac1,varargin)
            % o=block(name,fac1[,...facLast]);
            o.name=name;
            o.factorials={fac1};
            if nargin>2
                tmp=varargin{1};
                for a=1:(nargin-2)
                    o.factorials=[o.factorials {tmp(a)}];
                end
            end
        end
        
        
        
        
        
    end
    
    
    
    
    
end