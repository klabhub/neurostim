classdef broadBandSingleStepDots < neurostim.stimulus

    properties (Access=protected)
        steppers;
        dotTypeNr; % see Screen('DrawDots?')
    end

    properties (Constant)
        dotTypeStrs={'square','round_performance','round_quality','round_ptb'};
    end
    methods (Access=public)
        function o=broadBandSingleStepDots(c,name)
            o=o@neurostim.stimulus(c,name);
            o.addProperty('ndots',1000,'validate',@(x)~isempty(x)&&isnumeric(x)&&round(x)==x&&x>=0);
            o.addProperty('dotDiamPx',5,'validate',@(x)~isempty(x)&&isnumeric(x));
            o.addProperty('width',10,'validate',@(x)~isempty(x)&&isnumeric(x)&&x>0); % in whatever unit screen width is specified in
            o.addProperty('height',10,'validate',@(x)~isempty(x)&&isnumeric(x)&&x>0); % IWUSWISI
            o.addProperty('speed',5,'validate',@(x)~isempty(x)&&isnumeric(x)&&x>=0); % IWUSWISI per second. Only positive speed allow to simplify boundary checks in beforeFrameStepperUpdate
            o.addProperty('coherence',1,'validate',@(x)~isempty(x)&&isnumeric(x)&&x>=0&&x<=1);
            o.addProperty('delaysFr',2:5,'validate',@(x)~isempty(x)&&isnumeric(x)&&all(round(x)==x)&&all(x>0)&&isrow(x));
            o.addProperty('dotType','round_quality','validate',@(x)ischar(x)&&any(strcmpi(x,o.dotTypeStrs))); % round_ptb is the default because it's definition
            o.addProperty('roundAperture',true,'validate',@(x)islogical); % if true, width is the diameter of the aperture
            % Tip: use superclass parameter "angle" to specify the direction 
        end

        function beforeTrial(o)

            % if a round aperture is requested, check that width==height and correct ndots so that the number of
            % visible dots is ndots
            if o.roundAperture
                if o.width~=o.height
                    error('roundAperture is true but width (%f) is not equal to height (%f)',o.width,o.height)
                end
                o.ndots=o.ndots*sqrt(2);
            end

            % Convert dotType string to number to use as dot_type argument to Screen('DrawDots')
            o.dotTypeNr=find(strcmpi(o.dotType,o.dotTypeStrs))-1;
            if isempty(o.dotTypeNr)
                error('dotType is %s, but it must be any of:\n%s',string(o.dotType),sprintf(' - ''%s''\n',o.dotTypeStrs{:}));
            end
            
            % Divide the total number of dots in signal and noise dots
            n_signal_dots=round(o.ndots*o.coherence);
            n_noise_dots=o.ndots-n_signal_dots;

            % The noise dots are always visible, they are born again on every frame. The first stepper is for
            % the noise dots.
            o.steppers=o.initStepper(0,n_noise_dots,o.width,o.height,0);          
            
            % The dots of each signal stepper are visible once per delay. So correct the total number of dots so
            % that the specified ndots is visible on each frame
            n_signal_dots_visibility_corrected=n_signal_dots*numel(o.delaysFr)/sum(1./o.delaysFr);

            % The number of dots assigned to each stepper is simply the visibility-corrected number of signal dots
            % divided by the total number of steppers. This means that steppers with a longer delay have less
            % visible dots at each time. This is what we want. In a regular rdp where dots make N
            % consecutive there are N times more dots making a 1-frame step than there are dots stepping the
            % N-frame step.
            n_signal_dots_per_stepper=n_signal_dots_visibility_corrected/numel(o.delaysFr);
            
            step_per_fr=o.speed/o.cic.screen.frameRate;
            for i=1:numel(o.delaysFr)
                o.steppers(end+1)=o.initStepper(o.delaysFr(i), n_signal_dots_per_stepper, o.width, o.height, step_per_fr);
            end
        end

        function beforeFrame(o)
            for i=1:numel(o.steppers)
                o.steppers(i)=o.beforeFrameStepperUpdate(o.steppers(i));
                todraw=o.steppers(i).age==0 | o.steppers(i).age==o.steppers(i).delay;
                x=o.steppers(i).x(todraw);
                y=o.steppers(i).y(todraw);
                if o.roundAperture
                    outside=x.^2+y.^2>(o.width/2)^2;
                    x(outside)=[];
                    y(outside)=[];
                end
                if ~isempty(x)
                    Screen('DrawDots',o.window, [x;y], o.dotDiamPx, o.color, [0 0], o.dotTypeNr);
                end
            end
        end

        function afterFrame(o)
            for i=1:numel(o.steppers)
                o.steppers(i)=o.afterFrameStepperUpdate(o.steppers(i));
            end
        end
    end

    methods (Static)

        function s=initStepper(del,ndots,wid,hei,spd)
            s.n=round(ndots);
            s.wid=wid;
            s.hei=hei;
            s.x=(rand(1,s.n)-0.5)*wid;
            s.y=(rand(1,s.n)-0.5)*hei;
            s.delay=del;
            if s.delay==0
                s.age=zeros(1,s.n);
                s.dx=nan;
            else
                s.age=randi(del,1,s.n)-1;
                s.dx=spd*del;
            end
        end

        function s=beforeFrameStepperUpdate(s)
            if s.delay>0 % delay==0 means noise-field
                s.x(s.age==s.delay)=s.x(s.age==s.delay)+s.dx;
                s.x(s.x>s.wid/2)=s.x(s.x>s.wid/2)-s.wid;
            end
        end

        function s=afterFrameStepperUpdate(s)
            if s.delay>0 % delay==0 means noise-field
                s.age=mod(s.age+1,s.delay*2);
            end
            s.x(s.age==0)=(rand(1,sum(s.age==0))-0.5)*s.wid;
            s.y(s.age==0)=(rand(1,sum(s.age==0))-0.5)*s.hei;
        end
    end
end
