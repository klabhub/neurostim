classdef visualFeedback < neurostim.plugins.feedback
  % Plugin class to present visual feedback.
  %
  % This plugin will present a given visual stimulus when the provided
  % criterion is satisfied, e.g.,
  %
  %   s = stimuli.text(c,'msg'); % stimulus object
  %   s.duration = 1000;
  %    :
  %    :
  %
  %   b = plugins.fixate(c,'fix'); % behaviour object
  %    :
  %    :
  %
  %   fb = plugins.visualFeedback(c,'vfb'); % feedback object
  %   fb.add('stimulus',s,'criterion','@fix.success');
  %
  % The supplied criterion function must return TRUE or FALSE. The
  % criterion function is evaluated after every frame and the stimulus is
  % presented when it returns TRUE.
  %
  % Note: When adding visual feedback to your experiment you need to allow
  %       time (s.duration) within the trial (i.e., before cic exits the
  %       trial loop and issues the AFTERTRIAL event), after the criterion
  %       function returns TRUE, to display the feedback stimuli. As a
  %       result, visual feedback cannot be presented *after* a trial. To
  %       achieve your desired outcome, you likely need to explicitly set
  %       the off property of your other stimuli which might otherwise be
  %       displayed until the end of the trial, interfering with your
  %       feedback stimuli.
  
  % 2016-09-27 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties
%     tex@neurostim.stimuli.texture;
  end
    
  methods (Access=public)
    function o = visualFeedback(c,name)
      o = o@neurostim.plugins.feedback(c,name);
%       o.listenToEvent('BEFORETRIAL'); % parent class is already listening to BEFORETRIAL
%       o.tex = neurostim.stimuli.texture(c,'fbtex_');
    end
    
    function beforeTrial(o)
      % call the parent class beforeTrial() method
      beforeTrial@neurostim.plugins.feedback(o);

      % reset stimulus on times
      for ii = 1:o.nItems,
        o.(['item', num2str(ii), 'stimulus']).on = Inf;
      end
    end
  end % pubic methods
    
  methods
    function add(o,varargin)
      % add a new feedback item
      p = inputParser;
      p.KeepUnmatched = true;
      p.addParameter('stimulus',[],@(x) validateattributes(x,{'neurostim.stimulus'},{'numel',1})); % a stimulus object
      p.parse(varargin{:});

      args = p.Unmatched;
      
      % check for any supplied 'when' parameter
      if isfield(args,'when') && ~strcmpi(args.when,'AFTERFRAME')
          o.cic.error('STOPEXPERIMENT','''Invalid ''when'' parameter for visual feedback item. Type ''help visualFeedback'' for details.');
      end
      
      args.when = 'AFTERFRAME';
      
      % call the parent add() method
      add@neurostim.plugins.feedback(o,args);
              
      % Feedback items, or rather their individual properties, are stored
      % using dynamic properties with names that are constructed on the
      % fly, e.g., o.item1stimulus, o.item2stimulus etc.
      %
      % See the parent class neurostim.plugins.feedback for the background.
      o.addProperty(['item', num2str(o.nItems), 'stimulus'],p.Results.stimulus);
    end
  end
  
  methods (Access=protected)
    function deliver(o,item)
      tex = o.(['item', num2str(item), 'stimulus']);
      tex.on = o.cic.trialTime; % now?
    end
  end % protected methods  
    
end % classdef