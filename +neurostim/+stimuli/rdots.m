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

%     function [x,y] = getApertureCoords(o,bs)
%       % This function generates x-y coordinates (screen-centered) for the rdots aperture
%       switch o.aperture
%         case 'CIRC'
%           nx = o.apertureParms(1);
%           ny = o.apertureParms(1); % apply square analysis window over the circle aperture (fix?)
%         case 'RECT'
%           nx = o.apertureParms(1);
%           ny = o.apertureParms(2);
%       end
%       
%       %x = linspace(-1, 1,nx/bs)*nx*(1 - 1/nx);
%       %y = linspace( 1,-1,ny/bs)*ny*(1 - 1/ny);
%       x = -nx:bs:nx;
%       y = -ny:bs:ny;
% 
%       [x,y] = meshgrid(x,y);
%     end

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
      
      % stimStop remains Inf if we terminated the experiment via Esc-Esc
      [~,~,trialStopTime] = get(o.cic.prms.trialStopTime,'trial',p.trial);
      ix = isinf(stimStop.trialTime);
      stimStop.trialTime(ix) = trialStopTime(ix);
            
      % calculate stimulus duration in frames
      stimDur_Fr = o.cic.ms2frames(stimStop.trialTime-stimStart.trialTime);
      
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
          ix = fd(:,1) < stimStart.frame(i) | fd(:,1) > stimStop.frame(i);
          fd(ix,:) = [];
        end

        nrFrames = stimDur_Fr(i);
        if ~isempty(fd)
          nrFrames = nrFrames - sum(fd(:,2));
        end

        % iterate over frames for this trial
        for jj = 1:nrFrames+1
          % note: +1 here because afterFrame() is called after the last frame,
          %       and before the "final" xyVals are logged... the "final" values
          %       are never actually presented but we need to generate them here
          %       to compare with the loged values to verify our reconstruction
          xy{i}(:,:,jj) = [o.x(:), o.y(:)];
          dxdy{i}(:,:,jj) = [o.dx(:), o.dy(:)];

          o.afterFrame(); % calls the callback function
        end

        % validate the reconstruction against the stored CLUT values
        %
        % FIXME: o.cnt off by one when lifetime is finite?
        assert(isequal(o.cnt-~isinf(o.lifetime),cbCtr(i)), ...
          'Stimulus reconstruction failed. The number of callback evaluations does not match the logged value.');

        assert(isequal(xy{i}(:,:,nrFrames+1),xyVals{i}), ...
          'Stimulus reconstruction failed. Values do not match the logged values.');

        ix = 1:nrFrames; % excludes the "extra" frame we generated at the end

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
%       p.addParameter('chk',[]);
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
      rf_width = RF(3);
      rf_height = RF(3);

      % play the stimulus for the neuron
      nTrials = numel(p.xyVals);
      sp{1} = cell(1,nTrials);
      for i = 1:nTrials
%         if ~p.chk(i) % bad reconstruction
%           continue;
%         end
        nFrames = size(p.xyVals{i},2);

        % get the dx,dy
%         dx = p.xyVals{i}(:,2,1) - p.xyVals{i}(:,1,1); <-- first frame estimates get trashed by dots leaving the aperture
%         dy = p.xyVals{i}(:,2,2) - p.xyVals{i}(:,1,2);

%         dx = median(diff(p.xyVals{i}(:,:,1),1,2),2);
%         dy = median(diff(p.xyVals{i}(:,:,2),1,2),2);
        dx = squeeze(p.dxdyVals{i}(:,1,:));
        dy = squeeze(p.dxdyVals{i}(:,2,:));
        th = cart2pol(dx,dy); % dot directions... -pi to pi

        % get the fixation point
        fx = get(o.prms.X,'trial',i,'atTrialTime',Inf);
        fy = get(o.prms.Y,'trial',i,'atTrialTime',Inf);

        % if simulating gaze, fix gaze perfectly at fixation
        if ~p.eye
          d.eye(i).t = linspace(0,1,o.duration); % sample in ms
          d.eye(i).x = linspace(fx,fx,o.duration);
          d.eye(i).y = linspace(fy,fy,o.duration);
          d.eye(i).parea = linspace(1,1,o.duration);
        end

        % get the frame times
        frameDur = 1/o.cic.screen.frameRate;
        frameEdges = kron(0:nFrames-1,frameDur);
        eyeBins = discretize(d.eye(i).t,frameEdges);
        for j = 1:nFrames
          % get the median eye position on a frame
          mx = median(d.eye(i).x(eyeBins == j));
          my = median(d.eye(i).y(eyeBins == j));

%           valid = all(abs(d.eye(i).x(eyeBins == j)) <= 10.0) & ...
%             all(abs(d.eye(i).y(eyeBins == j)) <= 10.0) & ...
%             all(d.eye(i).parea(eyeBins == j) > 0);
%         
%           x = rf_x - mx(valid) + fx; % fixation-centered receptive field coordinates
%           y = rf_y - my(valid) + fy;
% 
%           % clip dots to the receptive field
%           ix = p.xyVals{i}(:,j,1) > x-rf_width & p.xyVals{i}(:,j,1) < x+rf_width & ...
%             p.xyVals{i}(:,j,2) > y-rf_height & p.xyVals{i}(:,j,2) < y+rf_height;
% 
%           % calculate average direction
%           th = cart2pol(mean(dx(ix),'omitnan'),mean(dy(ix),'omitnan'));          
          
          x = p.xyVals{i}(:,j,1) - mx - rf_x; % RF centered dot positions
          y = p.xyVals{i}(:,j,2) - my - rf_y;

          [~,r] = cart2pol(x,y);
          lambda = mean(neuronCallback(th(:,j)).*normpdf(r,0,rf_width)); % <-- Gaussian RF envelope

          sp{1}{i}(j) = lambda; % <-- noise free!
          
          if ~p.noisy
            continue
          end

          % simulate *noisy* response
%           lambda = neuronCallback(th);
%           if isnan(lambda); lambda = p.spontRate; end
          samples = zeros(1,floor(frameDur*1e3));
          for tt = 1:floor(frameDur*1e3) % ms in a frame
            samples(tt) = poissrnd(lambda);
          end
          sp{1}{i}(j) = mean(samples,'omitnan') ./ floor(frameDur*1e3); % spikes/sec
        end
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
%       p.addParameter('chk',[]);      
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
      
      % get aperture coordinates
      [rx,ry] = o.getApertureCoords(bs);

      % load the gaze
      if p.eye
        d = marmodata.mdbase([o.cic.fullFile '.mat'],'loadArgs',{'loadEye',true});
      end

      % reconstruct the stimulus
      if isempty(p.xyVals) || isempty(p.dxdyVals) %|| isempty(p.chk)
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
      dir = cell(1,nTrials);
      ws = cell(1,nTrials);
      n = 0; % Number of frames in the response
      for i = 1:nTrials
%         if ~p.chk(i) % bad reconstruction
%           continue;
%         end
        nFrames = size(p.xyVals{i},2);
        %if nFrames ~= size(xyVals{9},2) % Trial did not complete. This is janky and seems to be causing problems.
        %  sp{i} = [];
        %  continue;
        %end

        % get the dx,dy
%         dx = p.xyVals{i}(:,2,1) - p.xyVals{i}(:,1,1);
%         dy = p.xyVals{i}(:,2,2) - p.xyVals{i}(:,1,2);
        
%         dx = median(diff(p.xyVals{i}(:,:,1),1,2),2);
%         dy = median(diff(p.xyVals{i}(:,:,2),1,2),2);
        dx = squeeze(p.dxdyVals{i}(:,1,:));
        dy = squeeze(p.dxdyVals{i}(:,2,:));

        % get the fixation point
        fx = get(o.prms.X,'trial',i,'atTrialTime',Inf);
        fy = get(o.prms.Y,'trial',i,'atTrialTime',Inf);

        % if simulating gaze, fix gaze perfectly at fixation
        if ~p.eye
          d.eye(i).t = linspace(0,1,o.duration); % sample in ms
          d.eye(i).x = linspace(fx,fx,o.duration);
          d.eye(i).y = linspace(fy,fy,o.duration);
          d.eye(i).parea = linspace(1,1,o.duration);
        end

        % get the frame times        
        frameEdges = kron(0:nFrames-1,frameDur) + p.lag;
        frameBins = discretize(d.eye(i).t,frameEdges);
        
        mx = NaN([1,nFrames]); % get the median eye position
        my = NaN([1,nFrames]);    
        valid = false([1,nFrames]);

        % get the average stimulus direction        
        for j = 1:nFrames 
          mx(j) = median(d.eye(i).x(frameBins == j));
          my(j) = median(d.eye(i).y(frameBins == j));

          valid(j) = all(abs(d.eye(i).x(frameBins == j)) <= 10.0) & ...
            all(abs(d.eye(i).y(frameBins == j)) <= 10.0) & ...
            all(d.eye(i).parea(frameBins == j) > 0);

%           % xyVals are relative to o.position, which is the fixation point
%           dix = zeros(size(rx,1)*size(rx,2),o.nrDots);
%           diy = zeros(size(ry,1)*size(ry,2),o.nrDots);
%           for dd = 1:o.nrDots            
%             dix(:,dd) = dx(dd) .* (p.xyVals{i}(dd,j,1) >= (rx(:) - bs/2) & p.xyVals{i}(dd,j,1) < (rx(:) + bs/2) & ...
%               p.xyVals{i}(dd,j,2) >= (ry(:) - bs/2) & p.xyVals{i}(dd,j,2) < (ry(:) + bs/2));
%             diy(:,dd) = dy(dd) .* (p.xyVals{i}(dd,j,1) >= (rx(:) - bs/2) & p.xyVals{i}(dd,j,1) < (rx(:) + bs/2) & ...
%               p.xyVals{i}(dd,j,2) >= (ry(:) - bs/2) & p.xyVals{i}(dd,j,2) < (ry(:) + bs/2));            
%           end
%           %dix(~dix) = NaN; diy(~diy) = NaN; % NaN zeros
%           % calculate average direction
%           th = cart2pol(mean(dix,2,'omitnan'),mean(diy,2,'omitnan'));          
%           dir{i}(:,j) = th;
        end

        % convert screen centered to eye centered coordinates
%         x = rx(:) - mx(:,valid) + fx;
%         y = ry(:) - my(:,valid) + fy;
        x = p.xyVals{i}(:,:,1) - mx(:)'; % nrDots x nrFrames
        x(:,~valid) = NaN;

        y = p.xyVals{i}(:,:,2) - my(:)';
        y(:,~valid) = NaN;
        
        % clip to ROI
        x(x < (mnx-bs/2) | x > (mxx+bs/2)) = NaN; % nBins x nFrames
        y(y < (mny-bs/2) | y > (mxy+bs/2)) = NaN;
        ix = ~isnan(x(:)) & ~isnan(y(:));
        
        % weight stimuli by response
%         w = dir{i}.*sp{i};
%         w = w(:,valid);
        wx = dx.*sp{i}; % <-- for limited lifetime dots dx is nrDots x nrFrames
        wy = dy.*sp{i};

%         ws{i} = full(sparse(binfn(y(ix)-(mny-bs/2)), binfn(x(ix)-(mnx-bs/2)), w(ix), binfn(mxy - mny)+1, binfn(mxx - mnx)+1));
%         n = n + sum(sp{i}(valid) > 0);
        wsx{i} = full(sparse(binfn(y(ix)-(mny-bs/2)), binfn(x(ix)-(mnx-bs/2)), wx(ix), binfn(mxy - mny)+1, binfn(mxx - mnx)+1));
        wsy{i} = full(sparse(binfn(y(ix)-(mny-bs/2)), binfn(x(ix)-(mnx-bs/2)), wy(ix), binfn(mxy - mny)+1, binfn(mxx - mnx)+1));

        n = n + sum(sp{i}(valid) > 0);
      end
      
      % compute STA
%       STA.sta = sum(cat(3,ws{:}),3,'omitnan')./(n*frameDur); % average response in each bin over all trials (sp/s?)
      STA.stax = sum(cat(3,wsx{:}),3)./(n*frameDur); % average response in each bin over all trials (sp/s?)
      STA.stay = sum(cat(3,wsy{:}),3)./(n*frameDur); % average response in each bin over all trials (sp/s?)
      STA.xax = linspace(mnx, mxx, binfn(mxx - mnx)+1);
      STA.yax = linspace(mny, mxy, binfn(mxy - mny)+1);

      [STA.pref,STA.sta] = cart2pol(STA.stax,STA.stay); % <-- .sta is the preferred direction vector magnitude

      % clean up memory
      clearvars('dix','diy','dx','dy','frameBins','frameEdges','ix','rx','ry','w','ws');

      % cursory attempt at locating RF
      try
        [RFs(1), RFs(2)] = find(STA.sta == max(STA.sta,[],'all'),1);
        RFs(3) = find(STA.sta(RFs(1):end,RFs(2)) < 0.5*(max(STA.sta,[],'all') - mean(STA.sta,'all')),1) * p.binSz;      
      catch
        RFs(1) = 0; RFs(2) = 0; RFs(3) = 1;
      end

      % now improve it
      RF = [];
%       RF = findRFs(RFs,dir,STA.xax,STA.yax,sp);

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
        theta = linspace(-pi,pi,24);        % 24 points makes for 15 degree spacing
        radius = diff([xax(1),xax(RF(3))]);     % convert to xax/yax spacing
        xPts = radius .* cos(theta) + xax(RF(1));
        yPts = radius .* sin(theta) + yax(RF(2));
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
    %function [tuning] = getTuning(RF,xdir,ysp,varargin)
    %       % This function computes the tuning curve observed at a single voxel
    %       %
    %       % v: a linear or subscript index pointing to the voxel in question
    %       % xdir: an array of average directions presented in each voxel for each frame
    %       % ysp: the spiking response on each frame
    %       % tuning: a 2xn array of mean and std response values to n
    %       % equally spaced directions
    %       %
    %       % Tim Allison-Walker, 2022-05-26
    %
    %       p = inputParser;
    %       p.addParameter('debug',false);
    %       p.addParameter('nDirs',12,@(x) validateattributes(x,{'numeric'},{'nonempty','positive'}));
    %       p.parse(varargin{:});
    %       p = p.Results;
    %
    %       % get the linear index of the centre voxel
    %       v = sub2ind([sqrt(size(xdir,1)),sqrt(size(xdir,1))],RF(1),RF(2));
    %
    %       % discretize direction bins
    %       dirEdges = kron(0:p.nDirs,360/p.nDirs);
    %       dirBins = discretize(xdir,dirEdges);
    %       % nan out dirBins for xdir == 0
    %       dirBins(xdir(:,:) == 0) = NaN;
    %
    %       % mean response per voxel per direction
    %       tuning = zeros(2,p.nDirs);
    %       for j = 1:p.nDirs
    %         tuning(1,j) = mean(ysp(dirBins(v-RF(3):v+RF(3),:)==j),'all','omitnan'); % mean spiking response in this voxel
    %         tuning(2,j) = std(ysp(dirBins(v-RF(3):v+RF(3),:)==j),[],'all','omitnan'); % mean spiking response in this voxel
    %       end
    %     end

    %function p = fitGauss2(xx,yy,z)
    %       % fit 2d Gaussian function (see gauss2)
    %
    %       if isvector(xx) && isvector(yy)
    %         [xx,yy] = meshgrid(xx,yy);
    %       end
    %
    %       [~,ix] = max(abs(z(:)));
    %
    %       ofun = @(p) mean((z(:) - z(ix).*gauss2(p,xx(:),yy(:))).^2);
    %
    %       %    p0 = [ ...
    %       %     min(xx(:)) + range(xx(:))/2, min(yy(:)) + range(yy(:))/2, ...
    %       %     range(xx(:))/5, range(yy(:))/5, ...
    %       %     0.0, 1.0];
    %       p0 = [ ...
    %         xx(ix), yy(ix), ...
    %         range(xx(:))/5, range(yy(:))/5, ...
    %         0.0, 1.0];
    %
    %       p = fminunc(ofun,p0);
    %     end

    function RF = findRFs(RF,dir,xax,yax,sp,varargin)
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
      ofun = @(p) fitNeuron(p,dir,sp,randStream);

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
      maxKappa = 5;

      minTScale = 1;
      maxTScale = 1000;

      lb = [minXPos,minYPos,minRad,minMu,minKappa,minTScale];
      ub = [maxXPos,maxYPos,maxRad,maxMu,maxKappa,maxTScale];
      intcon = [1,2,3,6];
      A = [];
      b = [];
      Aeq = [];
      beq = [];
      X = [RF(1),minXPos:rfScale:maxXPos];
      Y = [RF(2),minYPos:rfScale:maxYPos];
      R = [RF(3),minRad:2:maxRad];
      M = minMu:pi/2:maxMu;
      K = minKappa:1:maxKappa;
      T = minTScale:200:maxTScale;
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
      RF = surrogateopt(ofun,lb,ub,intcon,A,b,Aeq,beq,options);

      % Sanitise RF
      RF(4) = circ_rad2ang(RF(4));
    end

    function f = fitNeuron(p,dir,sp,rS)
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
      nTrials = size(dir,2);
      xindex = round(p(1)-p(3)):ceil(p(1)+p(3));
      yindex = round(p(2)-p(3)):ceil(p(2)+p(3));
      if numel(xindex) ~= numel(yindex)
        keyboard;
      end
      for i = 1:nTrials
        if ~isempty(dir{i})
          break
        end
      end
      rf = sub2ind([sqrt(size(dir{i}(:,1))),sqrt(size(dir{i}(:,1)))],xindex,yindex);

      % simulate response
      dff = nan(1,nTrials);
      for i = 1:nTrials
        nFrames = size(dir{i},2);
        tff = nan(1,nFrames);
        for j = 1:nFrames
          th = mean(dir{i}(rf,j),'omitnan');
          lambda = abs(neuronCallback(th));
          if isnan(lambda); lambda = 2; end
          lambda = repmat(lambda,[1,1,floor(frameDur)]);
          tff(j) = sp{i}(j) - (mean(poissrnd(lambda),3,'omitnan') ./ floor(frameDur)); % spikes/sec
        end
        dff(i) = sum(tff.^2);
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
      %    fh.PaperOrientation = 'landscape'; % note setting of x and y below

      % figure size in cm, adding 2.5cm all the final axes dimensions
      szx = args.width+5.0; szy = args.height+5.0;

      fh.PaperSize = [szx szy];
      %    % A4 paper is 29.7 x 21cm (W x H; landscape orientation)
      %    x = (29.7-szx)/2; y = (21-szy)/2; % offsets to center the figure on the page
      x = (fh.PaperSize(1)-szx)/2; y = (fh.PaperSize(1)-szy)/2; % offsets to center the figure on the page
      fh.PaperPosition = [x y szx szy];

      % create the axes...
      ah = axes(fh,'Position',[2.5/szx, 2.5/szy, args.width/szx, args.height/szy]);

      %    ah.TickDir = 'out';
      %    ah.TickLength(1) = 0.15/max([f.width,f.height]); % 1.5mm
      ah.TickDir = args.tickDir;
      ah.TickLength(1) = args.tickLength/max([args.width,args.height]);

      ah.Box = 'off';

      hold on
    end

  end % static, private methods
end
