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
            % Note that increasing the number of points in any of the three
            % estimated variables, or the range of the x variable all have
            % an exponential influence on the time it takes to update the
            % estimates. This computation adds to the minimum duration of the
            % intertrialinterval.
            %
            
            if exist('psybayes.m','file') ~=2
                error('Could not find the psybayes toolbox. Clone it from github (https://github.com/lacerbi/psybayes.git) and add it to your path before using neurostim.plugins.psyBayes');
            end
            
            p = inputParser;
            p.StructExpand = true;
            p.addParameter('method','ent',@(x) (ischar(x) && ismember(x,{'ent','var'}))); % Use entropy maximization or variance maximization.
            p.addParameter('vars',[1 1 1],@(x) (all(size(x)== [1 3]) && isnumeric(x))); % [1 0 0 ] means estimate mu but not sigma and lambda. [1 1 1] is estimate all.
            p.addParameter('psychofun','@(x,mu,sigma,lambda,gamma) psyfun_yesno(x,mu,sigma,lambda,gamma,@psynormcdf);'); % The psychometric function, as a string
            p.addParameter('x',(-90:90));        % Stimulus grid in orientation degrees
            p.addParameter('rangeMu',[-12 12 31]);    % Range of tested PSE[lower bound, upper bound, number of points]
            p.addParameter('rangeSigma',[0.5 45 41]); % The range for sigma is automatically converted to log spacing
            p.addParameter('rangeLambda',[0 0.5 21]); % Lapse rate
            p.addParameter('priorsMu',[0 3]);         % mean and sigma of (truncated) Student's t prior over MU
            p.addParameter('priorsLogSigma',[2.05 1.40]); % mean and sigma of (truncated) Student's t prior over log SIGMA (Inf std means flat prior)
            p.addParameter('priorsLambda',[1 19]);  % alpha and beta parameters of beta pdf over LAMBDA
            p.addParameter('unitsX','deg');         % Units are used only for graphs.
            p.addParameter('unitsMu','deg');
            p.addParameter('unitsSigma','deg');
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
            psy.x = p.Results.x;
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
        
        function update(o,response)
            % The abstract adaptive parent class requires that we implement this
            % This is called after each trial. Update the internal value. The second arg is the success of the current trial, as determined
            % in the parent class, using the trialResullt function
            % specified by the user when constructing an object of this
            % class.
            %tic;
            parmValue = getValue(o); % This is the value that we used previously
                [~,o.psy] =  psybayes(o.psy, o.method, o.vars,parmValue,response); % Call to update.
            %toc
        end
        
        function v =getValue(o)
            % The abstract adaptive parent class requires that we implement this.
            % Return the current best value according to Psy.
            v = psybayes(o.psy, o.method, o.vars);
        end
        
        function plot(o)
            % Call the psybayes_plot function on the current state.
            for i=1:numel(o)
                figure('name',o(i).name)
                psybayes_plot(o(i).psy);
            end
        end
        
       
        
        function [m,sd,hdr,threshold,thresholdHdr]= posterior(oo,alpha,plotIt,theta)
            % function [m,sd,hdr]= posterior(oo,alpha,plotIt)
            % alpha = Level for high density interval [0.25]
            % plotIt = Show a graph [false]
            % theta = compute the threshold at this level. [0.75]
            %
            % Return the estimated parameters for psybayes
            % m = maximum likely  posterior estimate
            % sd = standard deviation of the posterior estimate
            % hdi = High density region at the alpha level. [low high]
            % threshold = Th value of 'x' at the level theta; the threshold .
            if nargin <4
                theta = 0.75;
            end
            if nargin<2
                alpha = 0.25;
            end
            if nargin<3
                plotIt = false;
            end
            
            nrO = numel(oo);
            m = nan(3,nrO);
            sd = nan(3,nrO);
            threshold = nan(1,nrO);
            thresholdHdr = nan(2,nrO);
            hdr = nan(3,2,nrO);
            conditionLabel = cell(1,nrO);
            for j=1:nrO
                try
                    for i=find(oo(j).vars)
                        other = setdiff(1:3,i);
                        y = neurostim.plugins.psyBayes.marginalpost(oo(j).psy.post,oo(j).psy.psychopost,other);
                        N=100;
                        f = linspace(0,max(y),N);
                        Y = repmat(y(:),[1 N]);
                        R = Y>repmat(f,[numel(y), 1]);
                        P = sum(Y.*R);
                        fAlpha = f(find(P>(1-alpha),1,'last'));
                        ix = y>fAlpha;
                        switch i
                            case 1
                                x = oo(j).psy.mu;
                            case 2
                                x = oo(j).psy.sigma;
                            case 3
                                x = oo(j).psy.lambda;
                        end
                        y = y /sum(y);
                        m(i,j) = sum(y.*x);
                        sd(i,j) = sqrt(sum(y.*((x - m(i,j)).^2)));
                        if sum(abs(diff(ix)) >2)
                            warning('This HDR is non-contiguous');
                            % Better return nan than the wrong limits..
                            hdr(i,1,j) = NaN;
                            hdr(i,2,j) = NaN;
                        else % Contiguous HDR
                            hdr(i,1,j) = x(find(ix==1,1,'first'));
                            hdr(i,2,j) = x(find(ix==1,1,'last'));
                        end                                                               
                    end
                    
                    % Fill in the priors for the vars we did not estimate.
                    priors = {oo(j).psy.mu, oo(j).psy.sigma, oo(j).psy.lambda};
                    for i=1:3
                        if oo(j).vars(i)==0
                        % Not estimated - use prior
                        m(i,j)= priors{i};
                        sd(i,j) = 0;
                        hdr(i,j,:) = priors{i};
                        end
                    end
                    
                    if nargout >3 && ~isempty(strfind(oo(j).psy.psychofun,'psyfun_yesno')) && ~isempty(strfind(oo(j).psy.psychofun,'psynormcdf'))
                        % Yes no function uses the cumulative normal, which we can
                        % invert to find the threshold at an arbitrary level:
                        thresholdFun = @(theta,mu,sigma,lambda)(mu+sqrt(2)*sigma.*erfinv(2*(theta-lambda/2)./(1-lambda)-1));                                              
                        threshold(1,j) = thresholdFun(theta,m(1,j),m(2,j),m(3,j));
                        if nargout>4
                            [M,S,L] = ndgrid(oo(j).psy.mu,oo(j).psy.sigma,oo(j).psy.lambda);
                            x = thresholdFun(theta,M,S,L);
                            y = oo(j).psy.post{1};
                            x= x(:);
                            y = y(:);
                            N=100;
                            f = linspace(0,max(y),N);
                            Y = repmat(y(:),[1 N]);
                            R = Y>repmat(f,[numel(y), 1]);
                            P = sum(Y.*R);
                            fAlpha = f(find(P>(1-alpha),1,'last'));
                            ix = y>fAlpha;
                            if sum(abs(diff(ix)) >2)
                                warning('This HDR is non-contiguous');
                                % Better return nan than the wrong limits..
                                thresholdHdr(1,j) = NaN;
                                thresholdHdr(2,j) = NaN;
                            else % Contiguous HDR
                                thresholdHdr(1,j) = x(find(ix==1,1,'first'));
                                thresholdHdr(2,j) = x(find(ix==1,1,'last'));
                            end
                            
                        end
                    end
                    
                catch
                    lasterr
                    disp (['Failed to compute posterior on ' oo(j).name])
                end
                conditionLabel{j} = [oo(j).design ' (' num2str(oo(j).conditions') ')' ];
            end
            
            if plotIt
                parms = {'\mu','\sigma','\lambda'};
                for i=1:3
                    subplot(1,3,i);
                    hold on
                    h =bar((1:size(m,2))',m(i,:)');
                    h.FaceColor = 'w';
                    errorbar((1:size(m,2))',m(i,:)',squeeze(hdr(i,1,:))-m(i,:)',squeeze(hdr(i,2,:))-m(i,:)','*')
                    ylabel (parms{i})
                    xlabel 'Psy'
                    
                    set(gca,'XTick',1:size(m,2),'XTickLabel',conditionLabel)
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