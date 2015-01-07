function RandomLinearDots 

Screen('Preference', 'SkipSyncTests', 1);

%INITIAL PARAMETERS
%%%%%%%%%%%%%%%%%%%%

dot_speed = 5; % dot speed of linear dots (pixels/frame)
dot_speed2 = .001; % dot speed of random dots 
ndots = 1000; % number of dots
dot_w = 5; % width of dot (pixels)
s = 1500; % field size (pixels)

% coherence:
c = 0.5 % percentage of linear dots
c1 = 0.01 % percentage of random dots
th = 0; % heading of linear dots,   90deg = downwards


xlinear = s * rand(1,c*ndots); % initial position
ylinear = s * rand(1,c*ndots);

x2 = s * rand(1,c1*ndots); 
y2 = s * rand(1,c1*ndots);


%SCREEN PARAMETERS
%%%%%%%%%%%%%%%%%%%

try

w=Screen('OpenWindow',0,0);

Priority(MaxPriority(w));

% Enable alpha blending for smoothed points:
Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

bdown=0;

HideCursor

while(~any(bdown)) % exit loop if mouse button is pressed
[mx,my,bdown]=GetMouse;


dx1 = dot_speed * cos(th*pi/180); % x-velocity
dy1 = dot_speed * sin(th*pi/180); % y-velocity

xlinear = mod(xlinear+dx1,s); % update positions
ylinear = mod(ylinear+dy1,s);

dx2 = dot_speed2 * cos(th*pi/180); % x-velocity
dy2 = dot_speed2 * sin(th*pi/180); % y-velocity


for i=1:length(x2)

x2(i)=mod(x2(i)+100*randn,s);
y2(i)=mod(y2(i)+100*randn,s);
end

%DRAW COMMANDS
%%%%%%%%%%%%%%
 
Screen('DrawDots', w, [xlinear;ylinear], dot_w, 255, [0 0], 1);
Screen('DrawDots', w, [x2;y2], dot_w, 255, [0 0], 1);
Screen('Flip', w);

end

catch

Screen('CloseAll');
disp(lasterr);


Screen('CloseAll')

ShowCursor
Priority(0);
end
    end