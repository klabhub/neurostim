classdef saccade < neurostim.plugins.behavior
    % Behavioral plugin which checks for a saccade.
    % saccade(name,fixation1,fixation2)
    % Creates a saccade from fixation1 to fixation2, adjusting start and
    % end points accordingly, and also adjusts fixation2's startTime to be 
    % equal to the end of the saccade. 
    %
    properties  (Access=private)
        fix1;
        fix2;
        vector;
        allowable;
    end
    
        
    
    methods
        function o=saccade(c,name,varargin)
            o=o@neurostim.plugins.behavior(c,name);
            o.continuous = true;
            o.addProperty('startX',0,'',@isnumeric);
            o.addProperty('startY',0,'',@isnumeric);
            o.addProperty('endX',[5 -5],'',@isnumeric);   % end possibilities - calculated as an OR
            o.addProperty('endY',[5 5],'',@(x) isnumeric(x) && all(size(x)==size(o.endX)));
            o.addProperty('minLatency',80,'',@isnumeric);
            o.addProperty('maxLatency',500,'',@isnumeric);
            if nargin == 3   % two fixation inputs
                o.fix1 = varargin{1};
                o.fix2 = varargin{2};
                
                % set initial values
                o.duration = o.minLatency;
                o.startX = ['@(' o.fix1.name ') ' o.fix1.name '.X'];
                o.startY = ['@(' o.fix1.name ') ' o.fix1.name '.Y'];
                o.endX = ['@(' o.fix2.name ') ' o.fix2.name '.X'];
                o.endY = ['@(' o.fix2.name ') ' o.fix2.name '.Y'];
                o.from = ['@(' o.fix1.name ', cic) ' o.fix1.name '.stopTime - cic.trialTime'];
                o.fix1.cic.(o.fix2.name).from = ['@(' o.name ', cic) ' o.name '.stopTime - cic.trialTime'];
                
            elseif nargin == 2
                error('Only one fixation object supplied.')
            end
            o.duration = o.maxLatency;
        end
        
        function on = validateBehavior(o)
            % calculates the validity of a saccade. This is done through
            % creating a convex hull around the two fixation points and
            % checking whether the eye position is within these parameters.
            X = o.cic.eye.x;
            Y = o.cic.eye.y;
            for a = 1:numel(o.endX)
                xvec = [o.startX; o.endX(a)];
                yvec = [o.startY; o.endY(a)];
                if sqrt((X-o.startX)^2+(Y-o.startY)^2)<=o.tolerance && (o.cic.clockTime)<=(o.startTime+o.maxLatency)
                    % if point is within tolerance of start position before
                    % max latency has passed
                    on = true;
                    break;
                elseif sqrt((X-o.endX(a))^2+(Y-o.endY(a))^2)<=o.tolerance && (o.cic.clockTime)>=o.startTime+o.minLatency && (o.cic.clockTime)<=(o.startTime+o.maxLatency)
                    % if point is within tolerance of end position
                    % after min latency has passed
                    on = true;
                    o.stopTime = o.cic.clockTime;
                    break;
                elseif Y>=min(yvec) && Y<=max(yvec) && (o.cic.clockTime)<=(o.startTime+o.maxLatency)
                    % calculate using distance formula
                    distance = abs((yvec(2)-yvec(1))*X - (xvec(2)-xvec(1))*Y...
                        + xvec(2)*yvec(1) - yvec(2)*xvec(1))/(sqrt(yvec(2)-yvec(1))^2+(xvec(2)-xvec(1))^2);
                    on = distance<=o.tolerance;
                    if on
                        break;
                    end
                elseif X>=min(xvec) && X<=max(xvec) && (o.cic.clockTime)<=(o.startTime+o.maxLatency)% else if point is within these two points
                    % calculate using distance formula
                    distance = abs((yvec(2)-yvec(1))*X - (xvec(2)-xvec(1))*Y...
                        + xvec(2)*yvec(1) - yvec(2)*xvec(1))/(sqrt(yvec(2)-yvec(1))^2+(xvec(2)-xvec(1))^2);
                    on = distance<=o.tolerance;
                    if on
                        break;
                    end
                else on=false;
                end
            end
            
        end
        
    end
    
    
    
end