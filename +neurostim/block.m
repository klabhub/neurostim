classdef block < dynamicprops
    % Class for establishing blocks and default properties.
    % Constructor:
    % myBlock=block(name,fac1[,...facLast]);
    % 
    % Inputs:
    % name - name of the block.
    %
    % Outputs:
    % myBlock - passes out a block structure with editable fields for
    % establishing a block of factorials for session design.
    % 
    % Fields should be of the format:
    % myBlock.weights = [a b]
    % wherein the weights correspond to the equivalent factorial.
    
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
        function v=get.conditions(o)
            conditions=neurostim.map;
            for a=1:numel(o.factorials)
                temp=o.factorials{a}.conditions;
                conditions([temp.keys conditions.keys])=[temp.values conditions.values];
            end
            v=conditions;
        end
        
            
            function v=get.nrConditions(o)
                nrConditions=0;
                for a=1:numel(o.factorials)
                    nrConditions=nrConditions+o.factorials{a}.nrConditions;
                end
                v=nrConditions;
            end
            
            function v=get.conditionList(o)
                v=[];
                for a=1:o.nrRepeats
                    conditions=[];
                    condNr=0;
                    for b=1:numel(o.factorials)
                        tmp=[];
                        currList=o.factorials{b}.conditionList;
                        if isempty(o.weights) || numel(o.weights)~=numel(o.factorials)
                            o.weights=ones(1,numel(o.factorials));
                        end
                        for c=1:o.weights(b)
                            tmp = [tmp currList];
                        end
                        conditions=[conditions tmp+condNr];
                        condNr=max(conditions);
                    end
                    switch o.randomization
                        case 'SEQUENTIAL'
                        case 'RANDOMWITHOUTREPLACEMENT'
                            conditions=Shuffle(conditions);
                        case 'RANDOMWITHREPLACEMENT'
                            conditions=datasample(conditions,numel(conditions));
                    end
                    v=[v conditions];
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