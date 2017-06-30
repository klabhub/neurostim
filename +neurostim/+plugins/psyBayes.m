classdef psyBayes < neurostim.plugins.adaptive
    % The psyBayes class is used to adaptively estimate a parameter using
    % the Kontsevich and Tyler method.
    %
    % Almost all of the real work is done by the psybayes
    % toolbox by Luigi Acerbi.
    % To install this, clone the repository from github:
    % https://github.com/lacerbi/psybayes.git
    %
    % This class wraps around those scripts to hide implementation detail and to
    % make it compatible with the NS approach.
    %
    %
    %
    % BK - Jun 2017
    
    properties (SetAccess=protected, GetAccess=public)
        psy@struct; % The struct that containst the psy bookkeeping info.
        method@char ='ent'; % Entropy maximization.
        vars  = [1 1 1];% Which variables to estimate (mu,sigma, lapse);
    end
    
    methods
        function o=psyBayes(c,trialResult, varargin)
            % o=psyBayes(c,trialResult, varargin)
            %
            % This function takes two required inputs:
            % c  - handle to CIC
            % trialResult =  A NS function string that evaluates to
            %                       true/false to indicate correct/incorrect answer on the
            %                       current trial.
            % The other (optional) parameters set the Psy parameters.
            % The defaults of these parameters are set to reasonable
            % settings for a psychometric function for orientation (from
            % the psytest_orientation demo in the psybayes toolbox.
            %
            
            if exist('psybayes.m','file') ~=2
                error('Could not find the psybayes toolbox. Clone it from github (https://github.com/lacerbi/psybayes.git) and add it to your path before using neurostim.plugins.psyBayes');
            end
                
            p = inputParser;
            p.addParameter('method','ent',@(x) (ischar(x) && ismember(x,{'ent','var'}))); % Use entropy maximization or variance maximization.
            p.addParameter('vars',[1 1 1],@(x) (all(size(x)== [1 3]) && isnumeric(x))); % [1 0 0 ] means estimate mu but not sigma and lambda. [1 1 1] is estimate all.
            p.addParameter('psychofun','@(x,mu,sigma,lambda,gamma) psyfun_yesno(x,mu,sigma,lambda,gamma,@psynormcdf);'); % The psychometric function, as a string
            p.addParameter('rangeX',(-90:90));        % Stimulus grid in orientation degrees  [lower bound, upper bound, number of points]
            p.addParameter('rangeMu',[-12 12 31]);    % Range of tested PSE
            p.addParameter('rangeSigma',[0.5 45 41]); % The range for sigma is automatically converted to log spacing
            p.addParameter('rangeLambda',[0 0.5 21]); % Lapse rate
            p.addParameter('priorsMu',[0 3]);         % mean and sigma of (truncated) Student's t prior over MU
            p.addParameter('priorsLogSigma',[2.05 1.40]); % mean and sigma of (truncated) Student's t prior over log SIGMA (Inf std means flat prior)
            p.addParameter('priorsLambda',[1 19]);  % alpha and beta parameters of beta pdf over LAMBDA
            p.addParameter('unitsX','deg');         % Units are used only for graphs.
            p.addParameter('unitsMu','deg');
            p.addParameter('unitsSigma','logDeg');
            p.addParameter('unitsLambda','');
            p.addParameter('unitsPsychoFun',{'Normal'});
            
            % Refractory time before presenting same stimulus again
            p.addParameter('refTime',0);            % Expected number of trials (geometric distribution)
            p.addParameter('refRadius',0);           % Refractory radius around stimulus (in x units)
            p.parse(varargin{:});
            
            % Initialize the object
            o = o@neurostim.plugins.adaptive(c,trialResult);
            
            o.method = p.Results.method;
            o.vars = p.Results.vars;
            
            % Copy the parameter settings to a struct.
            psy = [];
            psy.psychofun = p.Results.psychofun;
            psy.x = p.Results.rangeX;
            psy.range.mu = p.Results.rangeMu;     % Psychometric function mean
            psy.range.sigma = p.Results.rangeSigma;
            psy.range.lambda = p.Results.rangeLambda;
            psy.priors.mu = p.Results.priorsMu;
            psy.priors.logsigma = p.Results.priorsLogSigma;
            psy.priors.lambda = p.Results.priorsLambda;
            psy.units.x = p.Results.unitsX;
            psy.units.mu = p.Results.unitsMu;
            psy.units.sigma = p.Results.unitsSigma;
            psy.units.lambda =p.Results.unitsLambda;
            psy.units.psychofun = p.Results.unitsPsychoFun;
            psy.reftime = p.Results.refTime;
            psy.refradius = p.Results.refRadius;
            o.psy = psy;
            
        end
        
        function update(o,correct)
            % The abstract adaptive parent class requires that we implement this
            % This is called after each trial. Update the internal value. The second arg is the success of the current trial, as determined
            % in the parent class, using the trialResullt function
            % specified by the user when constructing an object of this
            % class.
            parmValue = getValue(o); % This is the value that we used previously
            [~,o.psy] =  psybayes(o.psy, o.method, o.vars,parmValue,correct); % Call to update.
        end
        
        function v =getValue(o)
            % The abstract adaptive parent class requires that we implement this.
            % Return the current best value according to Psy.
            v = psybayes(o.psy, o.method, o.vars);
        end
        
        function plot(o)
            % Call the psybayes_plot function on the current state.
            psybayes_plot(o.psy);
        end
        
        function [m,sd]= posterior(oo)
            % Return the estimated parameters for psybayes
            % m = maximum likely  posterior estimate
            % sd = standard deviation of the posterior estimate
            nrO = numel(oo);            
            m = nan(nrO,3);
            sd = nan(nrO,3);
            for j=1:nrO
                try
                for i=find(oo(j).vars)
                    other = setdiff(1:3,i);
                    y = neurostim.plugins.psyBayes.marginalpost(oo(j).psy.post,oo(j).psy.psychopost,other);
                    switch i
                        case 1
                            x = oo(j).psy.mu;
                        case 2
                            x = oo(j).psy.sigma;
                        case 3
                            x = oo(j).psy.lambda;
                    end
                    y = y /sum(y);
                    m(j,i) = sum(y.*x);
                    sd(j,i) = sqrt(sum(y.*x.^2) - m(j,i)^2);
                end
                catch
                    lasterr
                    disp (['Failed to compute posterior on ' oo(j).name])
                end
            end
        end
        
        function afterExperiment(o)
            [~,o.psy] = psybayes(o.psy); % Cleanup temps
        end
    end
    
    methods (Static)
            % copied from psybayes_plot
            function y = marginalpost(post,w,idx)
                %MARGINALPOST Compute marginal posterior
                
                Nfuns = numel(post);
                for k = 1:Nfuns
                    for j = idx
                        post{k} = sum(post{k},j);
                    end
                end
                y = zeros(size(post{1}));
                for k = 1:Nfuns; y = y + w(k)*post{k}; end
            end
    end
    
end