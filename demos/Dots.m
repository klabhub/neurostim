function Dots

import fixation.*

try



    Dots.nframes     = 1000; % number of animation frames in loop
    Dots.mon_width   = 39;   % horizontal dimension of viewable screen (cm)
    Dots.v_dist      = 60;   % viewing distance (cm)
    Dots.dot_speed   = 7;    % dot speed (deg/sec)
    Dots.ndots       = 100; % number of dots
    Dots.max_d       = 15;   % maximum radius of  annulus (degrees)
    Dots.in_d       = 1;    % minumum
    Dots.coherence   = 0.5;
    Dots.dot_w       = 0.1;  % width of dot (deg)
    Dots.fix_r      = 0.15; % radius of fixation point (deg)
    Dots.f_kill     = 0.05; % fraction of dots to kill each frame (limited lifetime)    
    Dots.differentcolors =0; % Use a different color for each point if == 1. Use common color white if == 0.
    Dots.differentsizes = 0; % Use different sizes for each point if >= 1. Use one common size if == 0.
    Dots.waitframes = 1;     % Show new dot-images at each Dots.waitframes'th monitor refresh.
    

    
    

    doublebuffer=1
    screens=Screen('Screens');
	screenNumber=max(screens);

    % [w, rect] = Screen('OpenWindow', screenNumber, 0,[1,1,801,601],[], doublebuffer+1);
    [w, rect] = Screen('OpenWindow', screenNumber, 0,[], 32, doublebuffer+1);
    
  

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
    
    
    % Do initial flip...
    vbl=Screen('Flip', w);
    
    % ---------------------------------------
    % initialize dot positions and velocities
    % ---------------------------------------

    ppd = pi * (rect(3)-rect(1)) / atan(Dots.mon_width/Dots.v_dist/2) / 360;    % pixels per degree
    pfs =Dots.dot_speed * ppd / fps;                            % dot speed (pixels/frame)
    s = Dots.dot_w * ppd;                                        % dot size (pixels)

    fix_cord = [center-Dots.fix_r*ppd center+Dots.fix_r*ppd];
    

    rmax = Dots.max_d * ppd;	% maximum radius of annulus (pixels from center)
    rmin = Dots.in_d * ppd; % minimum
    r = rmax * sqrt(rand(Dots.ndots,1));	% r
    r(r<rmin) = rmin;
    t = 2*pi*rand(Dots.ndots,1);                     % theta polar coordinate
    cs = [cos(t), sin(t)];
    xy = [r r] .* cs;   % dot positions in Cartesian coordinates (pixels from center)
    
   
	
	
			

    mdir = 2 * floor(rand(Dots.ndots,1)+0.5) - 1;    % motion direction (in or out) for each dot 
    dr = pfs * mdir;                            % change in radius per frame (pixels)
    dxdy = [dr dr] .* cs;                       % change in x and y per frame (pixels)

    % Create a vector with different colors for each single dot, if
    % requested:
    if (Dots.differentcolors==1)
        colvect = uint8(round(rand(3,Dots.ndots)*255));
    else
        colvect=white;
    end;
    
    % Create a vector with different point sizes for each single dot, if
    % requested:
    if (Dots.differentsizes>0)
        s=(1+rand(1, Dots.ndots)*(Dots.differentsizes-1))*s;        
    end;
    
    buttons=0;
        
    % --------------
    % animation loop
    % --------------    
    for i = 1:Dots.nframes
        if (i>1)
            Screen('FillOval', w, uint8(white), fix_cord);	% draw fixation dot (flip erases it)
            Screen('DrawDots', w, xymatrix, s, colvect, center,1);  % change 1 to 0 to draw square dots
            Screen('DrawingFinished', w); % Tell PTB that no further drawing commands will follow before Screen('Flip')
        end;
        
        [mx, my, buttons]=GetMouse(screenNumber);
        if KbCheck | any(buttons) % break out of loop
            break;
        end;
        
        xy = xy + dxdy;						% move dots
        r = r + dr;							% update polar coordinates too

        % check to see which dots have gone beyond the borders of the annuli

        r_out = find(r > rmax | r < rmin | rand(Dots.ndots,1) < Dots.f_kill);	% dots to reposition
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
            vbl=Screen('Flip', w, vbl + (Dots.waitframes-0.5)*ifi);
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
    