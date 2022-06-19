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
      xyVals0 = get(o.prms.xyVals,'trial',p.trial,'atTrialTime',Inf,'matrixIfPossible',false);
        
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

      nrTrials = numel(p.trial);
      xyVals = cell(1,nrTrials); dxdyVals = cell(1,nrTrials);

      for ii = 1:nrTrials
        % restore stimulus parameters
        o.sampleFun = sFun{ii};
        o.sampleParms = prms{ii};
        o.sampleBounds = bnds{ii};

        o.lifetime = lifetime(ii);

        o.direction = direction(ii);
        o.speed = speed(ii);

        % restore the state of the RNG stream
        o.rng.State = rngSt(ii,:);

        % re-build the callback function
        o.beforeTrial();

        % get frame drop data for this trial
        ix = frDr.trial == p.trial(ii);
        fd = frDr.data(ix,:);
                
        if ~isempty(fd)
          % discard drops that happened before or after the stimulus
          ix = fd(:,1) < stimStart.frame(ii) | fd(:,1) >= stimStop.frame(ii);
          fd(ix,:) = [];
        end

        nrFrames = stimDur_Fr(ii);
        if ~isempty(fd)
          nrFrames = nrFrames - sum(fd(:,2));
        end

        % iterate over frames for this trial
        for jj = 1:nrFrames
          xyVals{ii}(:,:,jj) = [o.x(:), o.y(:)];
          dxdyVals{ii}(:,:,jj) = [o.dx(:), o.dy(:)];

          o.afterFrame(); % calls the callback function
        end

        % validate the reconstruction against the stored CLUT values
        assert(isequal(o.cnt,cbCtr(ii)), ...
          'Stimulus reconstruction failed. The number of callback evaluations does not match the logged value.');

        assert(isequal([o.x(:),o.y(:)],xyVals0{ii}), ...
          'Stimulus reconstruction failed. Values do not match the logged values.');

        ix = 1:nrFrames;

        % account for the dropped frames
        if ~isempty(fd)
          % re-number the frame drops relative to our first frame
          fd(:,1) = fd(:,1) - stimStart.frame(ii) + 1; % FIXME: +1?
                    
          % replicate frames that were dropped
          framesPerFrame = ones(size(ix));
          framesPerFrame(fd(:,1)) = fd(:,2) + 1;
          ix = repelem(ix,framesPerFrame);
        end

        xyVals{ii} = xyVals{ii}(:,:,ix);
        dxdyVals{ii} = dxdyVals{ii}(:,:,ix);

        % play the stimulus in a figure window
        if p.replay
          o.offlineReplay(xyVals{ii},'dt',p.replayFrameDur,'type',o.type);
        end
      end
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

end % classdef
