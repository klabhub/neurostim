classdef rdots < neurostim.stimuli.dots

  properties (Access = private)
    initialized = false;

    cnt; % callback counter (incremented each time the callback function is called)
  end

  properties (GetAccess = public, SetAccess = private)
    callback; % function handle for returning dot directions
  end

  methods
    function o = rdots(c,name,varargin)
      o = o@neurostim.stimuli.dots(c,name);

      o.addProperty('direction',0); % deg.
      o.addProperty('speed',5); % deg./s

      % sampling distribution (see makedist for details)
      o.addProperty('sampleFun','uniform');
      o.addProperty('sampleParms',{'lower',-30,'upper',30});
      o.addProperty('sampleBounds',[]);

      % values logged for debug/reconstruction only
      o.addProperty('callbackCnt',0);
    end

    function initDots(o,ix)
      % initialises dots in the array positions indicated by ix

      initDots@neurostim.stimuli.dots(o,ix); % randomly positions the dots

      assert(o.initialized,'Sampling function callback has not been initialized!')

      n = nnz(ix);

      % sample direction for each dot
      direction = o.direction + o.callback(n);
      o.cnt = o.cnt + 1;

      % set dot directions (converting to Cartesian steps)
      [o.dx(ix,1), o.dy(ix,1)] = pol2cart(direction.*(pi/180),o.speed/o.cic.screen.frameRate);
    end

    function beforeTrial(o)
      o.setup(o.sampleFun,o.sampleParms,o.sampleBounds);

      beforeTrial@neurostim.stimuli.dots(o);
    end

    function afterTrial(o)
      afterTrial@neurostim.stimuli.dots(o);

      % log the callback counter
      o.callbackCnt = o.cnt;

      o.initialized = false;
    end

    function [xyVals,dxdyVals] = reconstructStimulus(o,varargin)
      % Reconstructs the dots stimulus offline.
      %
      % Usage:
      %
      %   [xyVals[,dxdyVals]] = o.reconstructStimulus()
      %
      % Returns the stimulus as a cell array of x,y dot positions, one entry
      % for each trial. Each entry in xyVals is an [o.nrDots x nrFrames x 2] array
      % of dot positions relative to o.position.
      %
      % The optional second output, dxdyVals, is a cell array the same size as
      % xyVals containing x,y-components of each dot's direction vector.
      %
      % Optional name-value arguments:
      %
      %   trial - a vector of trials to reconstruct (default: [1:o.cic.trial])
      %   replay - play back the stimulus in a figure window (default: false)

      p = inputParser;
      p.addParameter('trial',1:o.cic.trial);
      p.addParameter('replay',false);
      p.addParameter('replayFrameDur',50);
      p.addParameter('debug',false);
      p.parse(varargin{:});
      p = p.Results;

      % Get variables
      sFun = get(o.prms.sampleFun,'trial',p.trial,'atTrialTime',Inf);
      prms = get(o.prms.sampleParms,'trial',p.trial,'atTrialTime',Inf);
      bnds = get(o.prms.sampleBounds,'trial',p.trial,'atTrialTime',Inf,'matrixIfPossible',false);      
      rngSt = get(o.prms.rngState,'trial',p.trial,'atTrialTime',Inf);
      cbCtr = get(o.prms.callbackCnt,'trial',p.trial,'atTrialTime',Inf);

      lifetime = get(o.prms.lifetime,'trial',p.trial,'atTrialTime',Inf);

      % FIXME: are 'direction' and 'speed' a good idea...
      direction = get(o.prms.direction,'trial',p.trial,'atTrialTime',Inf);
      speed = get(o.prms.speed,'trial',p.trial,'atTrialTime',Inf);

      % FIXME: do we need aperture and apertureParams too?

      % logged x,y values
      xyVals = get(o.prms.xyVals,'trial',p.trial,'atTrialTime',Inf,'matrixIfPossible',false);
        
      % stimulus timing
      stimStart = get(o.prms.startTime,'trial',p.trial,'struct',true);
      stimStop = get(o.prms.stopTime,'trial',p.trial,'struct',true);

      % calculate stimulus duration in frames
      stimDur_Fr = floor(o.cic.ms2frames(stimStop.trialTime-stimStart.trialTime,false));

      % we need to account for dropped frames...
      frDr = get(o.cic.prms.frameDrop,'trial',p.trial,'struct',true);
      framesWereDropped = ~iscell(frDr.data);
      if framesWereDropped
        stay = ~isnan(frDr.data(:,1)); %frameDrop initialises to NaN
        frDr.data = frDr.data(stay,:);
        frDr.trial = frDr.trial(stay,:);

        % convert duration of frame drop from ms to frames (this assumes frames were synced?)
        frDr.data(:,2) = o.cic.ms2frames(1000*frDr.data(:,2));
      end

      for i = 1:numel(p.trial)
        % restore stimulus parameters
        o.sampleFun = sFun{i};
        o.sampleParms = prms{i};
        o.sampleBounds = bnds{i};

        o.lifetime = lifetime(i);

        o.direction = direction(i);
        o.speed = speed(i);

        % restore the state of the RNG stream
        o.rng.State = rngSt(i,:);

        % re-build the callback function
        o.beforeTrial();

        % get frame drop data for this trial
        ix = frDr.trial == p.trial(i);
        fd = frDr.data(ix,:);
                
        if ~isempty(fd)
          % discard drops that happened before or after the stimulus
          ix = fd(:,1) < stimStart.frame(i) | fd(:,1) >= stimStop.frame(i);
          fd(ix,:) = [];
        end

        nrFrames = stimDur_Fr(i);
        if ~isempty(fd)
          nrFrames = nrFrames - sum(fd(:,2));
        end

        % iterate over frames for this trial
        for jj = 1:nrFrames
          xy{i}(:,:,jj) = [o.x(:), o.y(:)];
          dxdy{i}(:,:,jj) = [o.dx(:), o.dy(:)];

          o.afterFrame(); % calls the callback function
        end

        % validate the reconstruction against the stored CLUT values
        assert(isequal(o.cnt,cbCtr(i)), ...
          'Stimulus reconstruction failed. The number of callback evaluations does not match the logged value.');

        assert(isequal([o.x(:),o.y(:)],xyVals{i}), ...
          'Stimulus reconstruction failed. Values do not match the logged values.');

        ix = 1:nrFrames;

        % account for the dropped frames
        if ~isempty(fd)
          % re-number the frame drops relative to our first frame
          fd(:,1) = fd(:,1) - stimStart.frame(i) + 1; % FIXME: +1?
                    
          % replicate frames that were dropped
          framesPerFrame = ones(size(ix));
          framesPerFrame(fd(:,1)) = fd(:,2) + 1;
          ix = repelem(ix,framesPerFrame);
        end

        xyVals{i} = xy{i}(:,:,ix);
        dxdyVals{i} = dxdy{i}(:,:,ix);

        % play the stimulus in a figure window
        if p.replay
          o.offlineReplay(xyVals{i},'dt',p.replayFrameDur,'type',o.type);
        end
      end
    end

    function sp = simulateNeuron(o,RF,tuning,varargin)
      % This function simulates a neuron responding to a
      % reconstructed stimulus, and returns the spiking responses of
      % the simulated neuron for receptive field reconstruction
      %
      % Outputs a cell array (sp) containing a vector of spike times
      % for each trial
      %
      % Takes as input
      % RF: a 1x3 array of receptive field centre position in X and Y, and radius
      % tuning: a 1xn array of Poisson lambda values for different motion directions

      p = inputParser;
      p.addParameter('debug',false);
      p.addParameter('noisy',true);
      p.addParameter('spontRate',2);
      p.addParameter('eye',false);
      p.addParameter('xyVals',[]);
      p.addParameter('dxdyVals',[]);
      p.parse(varargin{:});
      p = p.Results;

      % define the neuron's tuning
      mu = tuning(1);
      kappa = tuning(2);
      tScale = tuning(3);
      neuronCallback = @(x) tScale.*(exp(kappa*cos(x-mu))/(2*pi*besseli(0,kappa))); % x is in radians

      % load the gaze
      if p.eye
        d = marmodata.mdbase([o.cic.fullFile '.mat'],'loadArgs',{'loadEye',true});
      end

      % reconstruct the stimulus
      if isempty(p.xyVals) || isempty(p.dxdyVals) %|| isempty(p.chk)
        [p.xyVals,p.dxdyVals] = o.reconstructStimulus();
      end

      % hmm... I think I broke reconstructStimulus()
      p.xyVals = cellfun(@(x) permute(x,[1,3,2]),p.xyVals,'UniformOutput',false);
      
      % calculate receptive field
      rf_x = RF(1);
      rf_y = RF(2);
      rf_radius = RF(3);

      % play the stimulus for the neuron
      nTrials = numel(p.xyVals);
      sp{1} = cell(1,nTrials);
      for i = 1:nTrials
        nFrames = size(p.xyVals{i},2);

        % get dot direction(s)
        dx = squeeze(p.dxdyVals{i}(:,1,:));
        dy = squeeze(p.dxdyVals{i}(:,2,:));
        th = cart2pol(dx,dy); % -pi to pi

        % get the fixation point
        fx = get(o.prms.X,'trial',i,'atTrialTime',Inf);
        fy = get(o.prms.Y,'trial',i,'atTrialTime',Inf);

        % if simulating gaze, fix gaze perfectly at fixation
        if ~p.eye
          d.eye(i).t = linspace(0,o.duration/1e3,o.duration); % sample in ms
          d.eye(i).x = linspace(fx,fx,o.duration);
          d.eye(i).y = linspace(fy,fy,o.duration);
          d.eye(i).parea = linspace(1,1,o.duration);
        end

        % get the frame times
        frameDur = 1/o.cic.screen.frameRate;
        frameEdges = kron(0:nFrames-1,frameDur);
        eyeBins = discretize(d.eye(i).t,frameEdges);
        mx = zeros(1,nFrames); my = zeros(1,nFrames);
        for j = 1:nFrames
          % get the median eye position on a frame
          mx(j) = median(d.eye(i).x(eyeBins == j));
          my(j) = median(d.eye(i).y(eyeBins == j));
        end
        x = p.xyVals{i}(:,:,1) - mx - rf_x; % RF centered dot positions
        y = p.xyVals{i}(:,:,2) - my - rf_y;

        [~,r] = cart2pol(x,y);
        lambda = mean(neuronCallback(th).*normpdf(r,0,rf_radius)); % <-- Gaussian RF envelope

        sp{1}{i} = lambda; % <-- noise free!

        if ~p.noisy
          continue
        end

        % simulate *noisy* response
        lambda = repmat(lambda,[1,1,floor(frameDur*1e3)]);
        sp{1}{i} = mean(poissrnd(lambda),3,'omitnan') ./ floor(frameDur*1e3); % spikes/sec
      end
    end

    function [RF,STA] = getRFs(o,sp,varargin)
      % This function uses observed firing rates for each frame to
      % calculate a receptive field and tuning properties
      %
      % sp: a cell array of firing rates (sp/sec)
      %
      % RF: a 1x3 array of receptive field properties, defined as
      % centre position x,y, and radius
      % tuning: a 1x12 array of tuning curve response strengths,
      % where the 12 underlying directions are 0:30:330

      p = inputParser;
      p.addParameter('debug',false);
      p.addParameter('rect',[-10,10],@(x) validateattributes(x,{'numeric'},{'nonempty'}));
      p.addParameter('eye',false);
      p.addParameter('chan',1);
      p.addParameter('binSz',0.2,@(x) validateattributes(x,{'numeric'},{'nonempty','positive','scalar'}));
      p.addParameter('nDirs',12,@(x) validateattributes(x,{'numeric'},{'nonempty','positive'}));
      p.addParameter('lag',0.0,@(x) validateattributes(x,{'numeric'},{'nonempty','scalar'}));
      p.addParameter('xyVals',[]);
      p.addParameter('dxdyVals',[]);
      p.addParameter('noisy',true);
      p.addParameter('fitModel',true);
      p.addParameter('plotRF',false);
      p.addParameter('plotTuning',false);
      p.parse(varargin{:});
      p = p.Results;

      % determine ROI (eye-centered coordinates)
      bs = p.binSz; % analysis bin size in degrees
      binfn = @(x) (x==0) + ceil(x/bs);
      mnx = p.rect(1);
      mxx = p.rect(2);
      mny = mnx;
      mxy = mxx;
      if numel(p.rect) > 2
        mny = p.rect(3);
        mxy = p.rect(4);
      end

      % load the gaze
      if p.eye
        d = marmodata.mdbase([o.cic.fullFile '.mat'],'loadArgs',{'loadEye',true});
      end

      % reconstruct the stimulus
      if isempty(p.xyVals) || isempty(p.dxdyVals)
        [p.xyVals,p.dxdyVals] = o.reconstructStimulus();
      end

      % permute output from reconstructStimulus()
      p.xyVals = cellfun(@(x) permute(x,[1,3,2]),p.xyVals,'UniformOutput',false);
      
      % handle the spikes
      sp = sp{p.chan};

      % get necessary properties
      frameDur = 1/o.cic.screen.frameRate;

      % sort through the stimulus
      nTrials = numel(p.xyVals);
      wsx = cell(1,nTrials); wsy = cell(1,nTrials);
      xPos = cell(1,nTrials); yPos = cell(1,nTrials);
      n = 0; % Number of frames in the response
      for i = 1:nTrials
        nFrames = size(p.xyVals{i},2);

        % get the dx,dy
        dx = squeeze(p.dxdyVals{i}(:,1,:));
        dy = squeeze(p.dxdyVals{i}(:,2,:));

        % get the fixation point
        fx = get(o.prms.X,'trial',i,'atTrialTime',Inf);
        fy = get(o.prms.Y,'trial',i,'atTrialTime',Inf);

        % if simulating gaze, fix gaze perfectly at fixation
        if ~p.eye
          d.eye(i).t = linspace(0,o.duration/1e3,o.duration); % sample in ms
          d.eye(i).x = linspace(fx,fx,o.duration);
          d.eye(i).y = linspace(fy,fy,o.duration);
          d.eye(i).parea = linspace(1,1,o.duration);
        end

        % get the frame times
        frameEdges = kron(0:nFrames-1,frameDur) + p.lag;
        frameBins = discretize(d.eye(i).t,frameEdges);

        % get the median eye position for each frame
        mx = NaN([1,nFrames]);
        my = NaN([1,nFrames]);
        valid = false([1,nFrames]);

        for j = 1:nFrames
          mx(j) = median(d.eye(i).x(frameBins == j));
          my(j) = median(d.eye(i).y(frameBins == j));

          valid(j) = all(abs(d.eye(i).x(frameBins == j)) <= 10.0) & ...
            all(abs(d.eye(i).y(frameBins == j)) <= 10.0) & ...
            all(d.eye(i).parea(frameBins == j) > 0);
        end

        % convert screen centered to eye centered coordinates
        x = p.xyVals{i}(:,:,1) - mx(:)'; % nrDots x nrFrames
        % store x and y values for model fitting
        xPos{i} = x;        
        x(:,~valid) = NaN;

        y = p.xyVals{i}(:,:,2) - my(:)';
        yPos{i} = y;
        y(:,~valid) = NaN;

        % clip to ROI
        x(x < (mnx-bs/2) | x > (mxx+bs/2)) = NaN; % nBins x nFrames
        y(y < (mny-bs/2) | y > (mxy+bs/2)) = NaN;
        ix = ~isnan(x(:)) & ~isnan(y(:));

        % weight stimuli by response
        wx = dx.*sp{i};
        wy = dy.*sp{i};

        wsx{i} = full(sparse(binfn(y(ix)-(mny-bs/2)), binfn(x(ix)-(mnx-bs/2)), wx(ix), binfn(mxy - mny)+1, binfn(mxx - mnx)+1));
        wsy{i} = full(sparse(binfn(y(ix)-(mny-bs/2)), binfn(x(ix)-(mnx-bs/2)), wy(ix), binfn(mxy - mny)+1, binfn(mxx - mnx)+1));

        n = n + sum(sp{i}(valid) > 0);
      end

      % compute STA
      STA.stax = sum(cat(3,wsx{:}),3)./(n*frameDur); % average response in each bin over all trials (sp/s?)
      STA.stay = sum(cat(3,wsy{:}),3)./(n*frameDur); % average response in each bin over all trials (sp/s?)
      STA.xax = linspace(mnx, mxx, binfn(mxx - mnx)+1);
      STA.yax = linspace(mny, mxy, binfn(mxy - mny)+1);

      [STA.pref,STA.sta] = cart2pol(STA.stax,STA.stay); % <-- .sta is the preferred direction vector magnitude

      % cursory attempt at locating RF
      try
        [RFs(1), RFs(2)] = find(STA.sta == max(STA.sta,[],'all'),1);
        RFs(3) = find(STA.sta(RFs(1):end,RFs(2)) < 0.5*(max(STA.sta,[],'all') - mean(STA.sta,'all')),1) * p.binSz;
      catch
        RFs(1) = 0; RFs(2) = 0; RFs(3) = 1;
      end

      % now improve it
      RF = [];
      if p.fitModel
        RF = o.findRFs(RFs,xPos,yPos,p.dxdyVals,STA.xax,STA.yax,sp,p.noisy);
      end

      % plot the RF?
      if p.plotRF
        o.plotRFs(STA,RF,'rect',p.rect,'lag',p.lag,'smooth',true);
      end

      % plot the tuning?
      if p.plotTuning
        o.plotTuning(RF,'lag',p.lag);
      end
    end

    function plotRFs(o,STA,RF,varargin)
      % Plot receptive field map based on modality
      %% Parse optional arguments
      p = inputParser();
      p.KeepUnmatched = true;
      p.addParameter('rect',[-10 10],@(x) validateattributes(x,{'numeric'},{'nonempty'}));
      p.addParameter('lag',0.040,@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
      p.addParameter('smooth',true,@(x) validateattributes(x,{'logical'},{'scalar','nonempty'}));
      p.addParameter('chan',1,@(x) validateattributes(x,{'numeric'}));
      p.parse(varargin{:});
      args = p.Results;
      %% Get pixel weights
      sta = STA.sta; xax = STA.xax; yax = STA.yax;
      if args.smooth
        b = fspecial('gaussian',3,0.75);
        sta = filter2(b,sta);
      end
      [~,fname,~] = fileparts(o.cic.file);
      [h.fig,h.ax] = o.figure(p.Unmatched);
      h.fig.Name = sprintf('%s_sta_RF_ch%i_%ims',fname,args.chan,round(1e3*args.lag));
      if args.smooth
        h.fig.Name = sprintf('%s_sd0.75',h.fig.Name);
      end
      hold on
      h.img = imagesc(xax,yax,sta);
      axis image
      h.ax.YDir = 'normal';
      h.ax.CLim = [-1,1]*max(abs(h.ax.CLim));
      colorbar;
      % fovea is at (0,0)
      plot(xlim,zeros(1,2),'k--');
      plot(zeros(1,2),ylim,'k--');
      % plot RF?
      if ~isempty(RF)
        theta = linspace(-pi,pi,24);    % 24 points makes for 15 degree spacing
        radius = RF(3);
        xPts = radius .* cos(theta) + RF(1);
        yPts = radius .* sin(theta) + RF(2);
        scatter(xPts,yPts,5,'k','filled');
      end
      xlabel('Horiz. position (deg.)');
      ylabel('Vert. position (deg.)');
    end

    function plotTuning(o,RF,varargin)
      % Plot receptive field map based on modality
      %% Parse optional arguments
      p = inputParser();
      p.KeepUnmatched = true;
      p.addParameter('lag',0.040,@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
      p.addParameter('chan',1,@(x) validateattributes(x,{'numeric'}));
      p.parse(varargin{:});
      args = p.Results;
      %% Get the tuning directions
      xdir = linspace(0,360,1e4);
      %% Fit a von Mises function
      RF(4) = circ_ang2rad(RF(4));
      vonMises = @(x) RF(6).*(exp(RF(5)*cos(x-RF(4)))/(2*pi*besseli(0,RF(5)))); % x is in radians
      tValue = vonMises(circ_ang2rad(xdir));
      lambda = max(tValue);
      lambda = repmat(lambda,[1,100]);
      sample = nan(1,1e4);
      for i = 1:1e4
        sample(i) = mean(poissrnd(lambda),2,'omitnan') ./ 100;
      end
      mfr = mean(sample,'all','omitnan');
      %% Find the peak direction
      pd = xdir(tValue == max(tValue));
      %% Get tuning
      [~,fname,~] = fileparts(o.cic.file);
      [h.fig,h.ax] = o.figure(p.Unmatched);
      h.fig.Name = sprintf('%s_tuning_ch%i_%ims',fname,args.chan,round(1e3*args.lag));
      hold on
      plot(xdir,(tValue*mfr)./max(tValue),'k','LineWidth',2);
      YLIM = ylim;
      line([pd pd],[YLIM(1) YLIM(2)],'Color','k','LineStyle','--');
      text(ceil(pd) + 10,mfr,['Preferred Direction: ' num2str(pd,'%3.0f') '\circ'])
      xlabel('Stimulus Direction (deg.)');
      ylabel('Tuning Strength (Sp/s)');
    end

    function RF = findRFs(o,RF,xPos,yPos,dxdyVals,xax,yax,sp,noisy,varargin)
      %% Receptive field calculation
      % Use a receptive field model fit to derive optimal RF parameters
      % Define a RF via centre coordinated and radius, and a direction tuning
      % curve
      % Define a function that applies that RF to each frame of the data, to
      % output a firing rate
      % Minimise the difference between the modelled RF output and the observed
      % firing rates

      % define the RF scale
      rfScale = 20;

      % define the rng generator
      randStream = RandStream("mlfg6331_64",'Seed',0);

      % define the minimisation function
      ofun = @(p) o.fitNeuron(p,xPos,yPos,dxdyVals,xax,yax,sp,randStream,noisy);

      % set initial conditions
      minRad = 1;
      maxRad = 10;

      minXPos = 1 + maxRad;
      minYPos = 1 + maxRad;

      maxXPos = numel(xax) - maxRad;
      maxYPos = numel(yax) - maxRad;

      minMu = -pi;
      maxMu = pi;

      minKappa = 0;
      maxKappa = 8;

      minTScale = 0;
      maxTScale = 1000;

      lb = [minXPos,minYPos,minRad,minMu,minKappa,minTScale];
      ub = [maxXPos,maxYPos,maxRad,maxMu,maxKappa,maxTScale];
      intcon = [1,2,3,6];
      A = [];
      b = [];
      Aeq = [];
      beq = [];
      X = RF(1);
      Y = RF(2);
      R = RF(3);
      M = minMu:pi/2:maxMu;
      K = minKappa:2:maxKappa;
      T = minTScale:250:maxTScale;
      [Mpts,Kpts,Tpts,Rpts,Xpts,Ypts] = ndgrid(M,K,T,R,X,Y);
      Mpts = pagetranspose(Mpts); % convert to meshgrid format
      Kpts = pagetranspose(Kpts); % convert to meshgrid format
      Tpts = pagetranspose(Tpts); % convert to meshgrid format
      Rpts = pagetranspose(Rpts); % convert to meshgrid format
      Xpts = pagetranspose(Xpts); % convert to meshgrid format
      Ypts = pagetranspose(Ypts); % convert to meshgrid format
      startpts = [Xpts(:), Ypts(:), Rpts(:), Mpts(:), Kpts(:), Tpts(:)];
      options = optimoptions('surrogateopt','PlotFcn','surrogateoptplot','InitialPoints',startpts,...
        'MinSampleDistance',0.05);
      %RF = surrogateopt(ofun,lb,ub,intcon,A,b,Aeq,beq,options);

      % Sanitise RF
      RF(1) = xax(RF(1));
      RF(2) = yax(RF(2));
      RF(4) = circ_rad2ang(RF(4));
    end
  end % public methods

  methods (Access = protected)
    function setup(o,fcn,parms,bounds)
      % setup sampling function

      assert(any(strcmpi(fcn,makedist)),'Unknown distribution %s.',fcn);

      if ~iscell(parms)
        parms = num2cell(parms(:)');
      end

      % create a probability distribution object
      pd = makedist(fcn,parms{:});

      % truncate (if requested)
      if ~isempty(bounds)
        pd = truncate(pd,bounds(1),bounds(2));
      end

      % create function handle
      o.callback = @(n) random(pd,1,n); % returns n samples from pd
      o.cnt = 0;

      o.initialized = true;
    end
  end % protected methods

  methods (Static, Access = private)
    function f = fitNeuron(p,xPos,yPos,dxdyVals,xax,yax,sp,rS,noisy)
      % FIXME: Hard-code frame duration
      frameDur = 0.0167*1e3;

      % Reset the random stream
      reset(rS);

      % define tuning
      mu = p(4);
      kappa = p(5);
      tScale = p(6);
      neuronCallback = @(x) tScale.*exp(kappa*cos(x-mu))/(2*pi*besseli(0,kappa)); % x is in radians

      % define receptive field
      rf_x = xax(p(1));
      rf_y = yax(p(2));
      rf_radius = p(3);      

      % simulate response
      nTrials = numel(xPos);
      dff = nan(1,nTrials);
      for i = 1:nTrials
        % define gaussian envelope
        x = xPos{i} - rf_x; % RF centered dot positions
        y = yPos{i} - rf_y;
        [~,r] = cart2pol(x,y);
        env = normpdf(r,0,rf_radius); % <-- Gaussian RF envelope

        % extract direction vector
        dx = dxdyVals{i}(:,:,1);
        dy = dxdyVals{i}(:,:,2);
        th = cart2pol(dx,dy);   

        % smooth estimate
        lambda = abs(neuronCallback(th)) .* env;
        if noisy
          % noisy estimate
          lambda = repmat(lambda,[1,1,floor(frameDur)]);
          lambda = mean(poissrnd(lambda),3,'omitnan') ./ floor(frameDur); % spikes/sec 
        end
        
        % compute the sum of squared difference
        simSp = mean(lambda,1,'omitnan');
        dff(i) = sum((sp{i} - simSp).^2,'omitnan');
      end

      f = sum(dff,'all','omitnan');
    end

    function [fh,ah] = figure(~,varargin)
      % create a new figure window containing axes with
      % printed (i.e., on paper, or in .pdf) dimensions of
      % exactly f.width x f.height (cm).
      %
      % This is useful for exporting figures for later import
      % to Inkscape, Illustrator etc.
      p = inputParser();
      p.KeepUnmatched = true;
      p.addParameter('width',5.0,@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));
      p.addParameter('height',5.0,@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));
      p.addParameter('tickDir','out',@(x) ischar(x) && ismember(x,{'in','out'}));
      p.addParameter('tickLength',0.15,@(x) validateattributes(x,{'numeric'},{'scalar','positive'})); % cm

      p.parse(varargin{:});
      args = p.Results;
      %

      fh = figure(p.Unmatched);
      fh.PaperUnits = 'centimeters';
%       fh.PaperOrientation = 'landscape'; % note setting of x and y below

      % figure size in cm, adding 2.5cm all the final axes dimensions
      szx = args.width+5.0; szy = args.height+5.0;

      fh.PaperSize = [szx szy];
      % A4 paper is 29.7 x 21cm (W x H; landscape orientation)
%       x = (29.7-szx)/2; y = (21-szy)/2; % offsets to center the figure on the page
      x = (fh.PaperSize(1)-szx)/2; y = (fh.PaperSize(1)-szy)/2; % offsets to center the figure on the page
      fh.PaperPosition = [x y szx szy];

      % create the axes...
      ah = axes(fh,'Position',[2.5/szx, 2.5/szy, args.width/szx, args.height/szy]);

%       ah.TickDir = 'out';
%       ah.TickLength(1) = 0.15/max([f.width,f.height]); % 1.5mm
      ah.TickDir = args.tickDir;
      ah.TickLength(1) = args.tickLength/max([args.width,args.height]);

      ah.Box = 'off';

      hold on
    end

  end % static, private methods
end
