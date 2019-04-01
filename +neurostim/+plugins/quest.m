 classdef quest < neurostim.plugins.adaptive
    % The quest class is used to adaptively estimate a parameter using
    % the Quest procedure.
    %
    % The core functionality is in the PTB Quest* functions by Pelli. This
    % class wraps around those scripts to hide implementation detail and to
    % make it compatible with the NS approach.
    %
    % For usage, see adaptiveDemo
    %
    % BK - Nov 2016
    properties (SetAccess=protected, GetAccess=public)
        Q@struct; % The struct that containst the Quest bookkeeping info.
        momentFun;
    end
    
    methods
        function o=quest(c,trialResult, varargin)
            %o=quest(c,varargin)
            %
            % This function takes two required inputs:
            % c  - handle to CIC
            % trialResult =  A NS function string that evaluates to
            %                       true/false to indicate correct/incorrect answer on the
            %                       current trial.
            % Two optional function handles convert between the
            % quest-internal intensity and the actual parameter value. This
            % can be used, for instance, to limit values to a certain
            % range:
            % i2p - Convert an quest intensity to a parameter value
            % p2i - Convert a parameter to a quest intensity.
            %
            % For isntance i2p = @(x) (min(10^x,1))
            % and p2i = @(x) (log10(x)) to map between the infinite range
            % of the quest intensity and a contrast that runs from 0 to 1.
            %
            % The other (optional) parameters set the Quest parameters.
            % Their defaults are set as recommended for Quest, See Quest
            % and QuestCreate for details.
            % guess
            % guessSD
            % threshold
            % beta
            % delta
            % gamma
            % grain
            % range
            % plotIt
            % normalizePdf
            %
            p = inputParser;
            p.addParameter('guess',-1);   % Initial guess for the parameter
            p.addParameter('guessSD',2);  %SD of the initial guess (i.e. prior)
            p.addParameter('threshold',0.82); %Target threshold
            p.addParameter('beta',3.5); % Steepness of assumed Weibull
            p.addParameter('delta',0.01); % Fraction of blind presses
            p.addParameter('gamma',0.5); % Fraction of trials that will generate response yes for intensity = -inf. (chance level)
            p.addParameter('grain',0.01); % Discretization of the range
            p.addParameter('range',5); % Range centered on guess.
            p.addParameter('plotIt',false);
            p.addParameter('normalizePdf',1);
            p.addParameter('i2p',@(x) (isa(x,'function_handle'))); % Postprocess the 'intensity' returned by Quest with this function
            p.addParameter('p2i',@(x) (isa(x,'function_handle')));
            p.addParameter('pdfMoment','QUANTILE', @(x) ismember(x,{'QUANTILE','MEAN','MODE'})); %Where do we want to place the next trial? Which moment of the posterior PDF?
            p.parse(varargin{:});
            
            % Initialize the object
            o = o@neurostim.plugins.adaptive(c,trialResult);
            addProperty(o,'',p.Results); % Add all input parser fields as logged properties ( and set their values).
            o.Q = QuestCreate(p.Results.guess,p.Results.guessSD,p.Results.threshold,p.Results.beta,p.Results.delta,p.Results.gamma,p.Results.grain,p.Results.range,p.Results.plotIt);
        
            funs = {@QuestQuantile, @QuestMean, @QuestMode};
            o.momentFun = funs{ismember({'QUANTILE','MEAN','MODE'},p.Results.pdfMoment)};
        end
        
        function update(o,correct)
            % The abstract adaptive parent class requires that we implement this
            % This is called after each trial. Update the internal value. The second arg is the success of the current trial, as determined
            % in the parent class, using the trialResullt function
            % specified by the user when constructing an object of this
            % class.
            parmValue = o.getValue; % This is the value that was used previously
            intensity = o.p2i(parmValue); % Converti it to Quest intensity
            if ~isempty(correct)
                o.Q=QuestUpdate(o.Q,intensity,correct); % Add the new datum .
            end
        end
        
        function v =getAdaptValue(o)
            % The abstract adaptive parent class requires that we implement this.
            % Return the current best value according to Quest.
            v=o.i2p(o.momentFun(o.Q));
        end
        
        
%         
        function [m,sd]= threshold(oo)
            % Return the estimated thresholds for all conditions
            % m = threshold estimate  (QuestMean)
            % sd = standard deviation estimate (QuestStd)
            m = nan(size(oo)) ; sd =nan(size(oo));
            cntr=0;
            for o=oo
                cntr= cntr+1;
            if ~isempty(o.Q)
                x =QuestMean(o.Q);                
                m(cntr)= o.i2p(x);
                % Calculate sd while taking i2p mapping into account
                x = o.i2p(o.Q.x);
                p=sum(o.Q.pdf);
                sd(cntr)=sqrt(sum(o.Q.pdf.*x.^2)/p-(sum(o.Q.pdf.*x)/p).^2);
            end                                  
            end
        end
        
    end
    
end