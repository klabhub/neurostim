function RadialDots(showSprites, waitframes)

AssertOpenGL;

if nargin < 1
    showSprites = [];
end

if isempty(showSprites)
    showSprites = 0;
end

if nargin < 2
    waitframes = [];
end

if isempty(waitframes)
    waitframes = 1;
end

try

    % ------------------------
    % set dot field parameters
    % ------------------------

    nframes     = 3600; % number of animation frames in loop
    mon_width   = 39;   % horizontal dimension of viewable screen (cm)
    v_dist      = 60;   % viewing distance (cm)
    if showSprites > 0
        dot_speed   = 0.07; % dot speed (deg/sec) - Take it sloooow.
        f_kill      = 0.00; % Don't kill (m)any dots, so user can see better.
    else
        dot_speed   = 7;    % dot speed (deg/sec)
        f_kill      = 0.05; % fraction of dots to kill each frame (limited lifetime)
    end
    ndots       = 2000; % number of dots
    max_d       = 15;   % maximum radius of  annulus (degrees)
    min_d       = 1;    % minumum
    dot_w       = 0.1;  % width of dot (deg)
    fix_r       = 0.15; % radius of fixation point (deg)
    differentcolors =1; % Use a different color for each point if == 1. Use common color white if == 0.
    differentsizes = 2; % Use different sizes for each point if >= 1. Use one common size if == 0.
    % waitframes = 1;     % Show new dot-images at each waitframes'th monitor refresh.
    
    if differentsizes>0  % drawing large dots is a bit slower
        ndots=round(ndots/5);
    end
    
    % ---------------
    % open the screen
    % ---------------

    doublebuffer=1
    screens=Screen('Screens');
	screenNumber=max(screens);

    % [w, rect] = Screen('OpenWindow', screenNumber, 0,[1,1,801,601],[], doublebuffer+1);
    [w, rect] = Screen('OpenWindow', screenNumber, 0,[], 32, doublebuffer+1);
    
    % If you'd uncomment these lines and had the Psychtoolbox kernel driver
    % loaded on a OS/X or Linux box with ATI Radeon X1000 or later, you'd
    % probably enjoy a 10 bit per color channel framebuffer...
    %PsychImaging('PrepareConfiguration');
    %PsychImaging('AddTask', 'General', 'FloatingPoint16Bit');
    %PsychImaging('AddTask', 'General', 'EnableNative10BitFramebuffer');
    %[w, rect] = PsychImaging('OpenWindow', screenNumber, 0,[], [], doublebuffer+1);

    % Enable alpha blending with proper blend-function. We need it
    % for drawing of smoothed points:
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [center(1), center(2)] = RectCenter(rect);
	 fps=Screen('FrameRate',w);      % frames per second
    ifi=Screen('GetFlipInterval', w);
    if fps==0
       fps=1/ifi;
    end;
    
    black = BlackIndex(w);
    white = WhiteIndex(w);
    HideCursor;	% Hide the mouse cursor
    Priority(MaxPriority(w));
    
    % Do initial flip...
    vbl=Screen('Flip', w);
    
    % ---------------------------------------
    % initialize dot positions and velocities
    % ---------------------------------------

    ppd = pi * (rect(3)-rect(1)) / atan(mon_width/v_dist/2) / 360;    % pixels per degree
    pfs = dot_speed * ppd / fps;                            % dot speed (pixels/frame)
    s = dot_w * ppd;                                        % dot size (pixels)
    fix_cord = [center-fix_r*ppd center+fix_r*ppd];

    rmax = max_d * ppd;	% maximum radius of annulus (pixels from center)
    rmin = min_d * ppd; % minimum
    r = rmax * sqrt(rand(ndots,1));	% r
    r(r<rmin) = rmin;
    t = 2*pi*rand(ndots,1);                     % theta polar coordinate
    cs = [cos(t), sin(t)];
    xy = [r r] .* cs;   % dot positions in Cartesian coordinates (pixels from center)

    mdir = 2 * floor(rand(ndots,1)+0.5) - 1;    % motion direction (in or out) for each dot
    dr = pfs * mdir;                            % change in radius per frame (pixels)
    dxdy = [dr dr] .* cs;                       % change in x and y per frame (pixels)

    % Create a vector with different colors for each single dot, if
    % requested:
    if (differentcolors==1)
        colvect = uint8(round(rand(3,ndots)*255));
    else
        colvect=white;
    end;
    
    % Create a vector with different point sizes for each single dot, if
    % requested:
    if (differentsizes>0)
        s=(1+rand(1, ndots)*(differentsizes-1))*s;        
    end;
    
    buttons=0;

    % Wanna show textured sprites instead of dots?
    if showSprites == 1
        % Create a small texture as offscreen window: Size is 30 x 30
        % pixels, background color is black and transparent:
        tex = Screen('OpenOffScreenWindow', w, [0,0,0,0], [0 0 30 30]);
        % Draw a little white smiley into the window. The white color will
        % be modulated by 'colvect' during drawing, so white is basically
        % just a placeholder:
        Screen('TextSize', tex, 24);
        Screen('DrawText', tex, ':)', 0, 0, 255);
        
        % Scale down a bit, otherwise visual clutter ensues:
        s = s * 0.2;

        % Define randomly distributed rotation angles in a +/- 30 degree
        % range around a "vertical" smiley face:
        angles = (rand(1, ndots) - 0.5) * 60 + 90;
    end

    if showSprites == 2
        % Create a small texture as offscreen window: Size is 30 x 30
        % pixels, background color is black and transparent:
        tex = Screen('OpenOffScreenWindow', w, [255,255,255,0], [0 0 30 30]);
        % Draw a white rectangle into the window. The white color will
        % be modulated by 'colvect' during drawing, so white is basically
        % just a placeholder:
        Screen('FillRect', tex, 255, [1 1 29 29]);
        
        s = 1;

        % Define randomly distributed rotation angles in a +/- 30 degree
        % range around a "vertical" smiley face:
        angles = (rand(1, ndots) - 0.5) * 60 + 90;
    end

    % --------------
    % animation loop
    % --------------    
    for i = 1:nframes
        if (i>1)
            Screen('FillOval', w, uint8(white), fix_cord);	% draw fixation dot (flip erases it)
            if showSprites
                % Draw little "sprite textures" instead of dots:
                PsychDrawSprites2D(w, tex, xymatrix, s, angles, colvect, center, 1);  % change 1 to 0 to draw unfiltered sprites.
            else
                % Draw nice dots:
                Screen('DrawDots', w, xymatrix, s, colvect, center,1);  % change 1 to 0 to draw square dots
            end
            Screen('DrawingFinished', w); % Tell PTB that no further drawing commands will follow before Screen('Flip')
        end;
        
        [mx, my, buttons]=GetMouse(screenNumber);
        if KbCheck | any(buttons) % break out of loop
            break;
        end;
        
        xy = xy + dxdy;						% move dots
        r = r + dr;							% update polar coordinates too

        % check to see which dots have gone beyond the borders of the annuli

        r_out = find(r > rmax | r < rmin | rand(ndots,1) < f_kill);	% dots to reposition
        nout = length(r_out);

        if nout

            % choose new coordinates

            r(r_out) = rmax * sqrt(rand(nout,1));
            r(r<rmin) = rmin;
            t(r_out) = 2*pi*(rand(nout,1));

            % now convert the polar coordinates to Cartesian

            cs(r_out,:) = [cos(t(r_out)), sin(t(r_out))];
            xy(r_out,:) = [r(r_out) r(r_out)] .* cs(r_out,:);

            % compute the new cartesian velocities

            dxdy(r_out,:) = [dr(r_out) dr(r_out)] .* cs(r_out,:);
        end;
        xymatrix = transpose(xy);
        
        if (doublebuffer==1)
            vbl=Screen('Flip', w, vbl + (waitframes-0.5)*ifi);
         end;
         %pause(0.001);
         %pause;
    end;
    Priority(0);
    ShowCursor
    Screen('CloseAll');
catch
    Priority(0);
    ShowCursor
    Screen('CloseAll');
end