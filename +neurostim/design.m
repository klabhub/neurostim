classdef design 
    % Class for establishing an experimental design 
    % Constructor:
    % o=design(name)
    %
    % Inputs:
    %   name - name of the design (optional; bookkeeping only)
    %
    % Outputs:
    %   o - passes out a design structure with fields that can be modified
    %   to specify factors (e.g. o.fac1,o.fac2) to specify a factorial design,
    %   or individual conditions (o.conditions)
    %
    % Object member variables that you can changer are:
    % o.randomization
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
    % TK, BK, 2016
    
    properties
        randomization='RANDOMWITHOUTREPLACEMENT';
        name@char;                      % The name of this design; bookkeeping/logging use only.
        specs@cell={};                  % A cell array of condition specifications
        list@double;                    % The order in which conditions will be run.
        weights@double=1;               % The relative weight of each condition. (Must be scalar or the same size as specs)
    end
    
    properties (Dependent)
        nrConditions;
        nrFactors;
    end
    
    
    methods  %/get/set
        
        function v=size(o)
            v= nrLevels(o);
        end
        
        function v= get.nrFactors(o)
            v = size(o.specs,1);
        end
        
        function v=get.nrConditions(o)
            v=prod(o.nrLevels);
        end
        
        function v=nrLevels(o,factor)
            if nargin <2
                factor = 1:o.nrFactors;
            end
            if all(factor<o.nrFactors)
                v = 0;
            else
                v = sum(~cellfun(@isempty,o.specs(factor,:)),2)';
            end
        end
    end
    
    
    methods (Access = public)
        
        function o=factorial(varargin)
            % o=factorial(varargin)
            % name - name of the Factorial
            % randomization 
            p=inputParser;
            p.addParameter('name','',@ischar);
            p.addParameter('randomization','RANDOMWITHOUTREPLACEMENT',@(x) (ischar(x) && ismember(upper(x),{'SEQUENTIAL','RANDOMWITHOUTREPLACEMENT','RANDOMWITHREPLACEMENT'})));
            p.parse(varargin{:});
            o.name = p.Results.name;
            o.randomization = p.Results.randomization;
        end
        



        function reshuffle(o)
            % Shuffle the list of conditions 
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
        
        function o = subsasgn(o,S,V)
        % subsasgn to create special handling of .weights .conditions, and
        % .facN design specifications.        
            handled = false; % If not handled here, we call the builtin below.
            if strcmpi(S(1).type,'.')
                if strcmpi(S(1).subs,'WEIGHTS')
                    handled =true;
                elseif strcmpi(S(1).subs,'CONDITIONS')
                    handled =true;
                elseif strncmpi(S(1).subs,'FAC',3)
                    % Specify parameter settings for one of the factors.
                    % For instance, for a 5x3 factorial that varies X and Y
                    % in the fix stimulus:
                    % d.fac1.fix.X = 1:5 
                    % d.fac2.fix.Y = 1:3
                    handled = true;
                    if numel(S)~=3
                        error('Factor specifiction must be of the form: o.fac1.plugin.parm = values')
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
                        levelsPreviouslyDefined = sum(~cellfun(@isempty,o.specs(factor,:)));
                        if thisNrLevels==1
                            V = repmat(V,1,levelsPreviouslyDefined); % Copy the singleton to match previous specs.
                            thisNrLevels = levelsPreviouslyDefined;
                        elseif levelsPreviouslyDefined ==1
                            [o.specs{factor,1:thisNrLevels}] =deal(o.specs{factor,1}); % make copies of the singleton spec that was previosuly defined
                        elseif levelsPreviouslyDefined ==0
                            % New factor (e.g. fac2 was defined before fac1 )
                        elseif thisNrLevels ~=levelsPreviouslyDefined
                            error(['The number of levels for ' plg '.' prm ' (' num2str(thisNrLevels) ') does not match with previous specifications (' num2str(levelsPreviouslyDefined) ')']);
                        end
                    else
                        % New factor.
                    end
                    
                    % Now loop through all the new values and store them in
                    % the specs cell array [nrFactors, nrLevels] 
                    % factor 1: level1 level2...
                    % factor 2: level 1 level2
                    for i=1:thisNrLevels
                        % Special handling of the adaptive class (e.g.
                        % jitter, staircase)
                        if isa(V{i},'neurostim.plugins.adaptive')
                            V{i}.condition = conditionName; % Restrict listener to this condition only
                            V{i}.targetPlugin = plg; % Store target stim/prop in adaptive and log it.
                            V{i}.targetProperty = prm;
                        end

                        if any([factor i]>size(o.specs)) || isempty(o.specs(factor,i))
                            % New spec for this factor/level. 
                            o.specs{factor,i} = {plg,prm,V{i}};
                        else
                            %Add new spec to exsting spec
                            o.specs{factor,i} = cat(1,o.specs{factor,i}, {plg,prm,V{i}});
                        end
                    end
                end
            end
            
            if ~handled
                % Call builtin
                o = builtin('subsasgn',o,S,V);
            end
            
        end
    end
end