function circlePath(c)
% Demo eScript to show how stimulus properties can be changed on the fly in
% an experiment. This eScript is called by the scripting.m demo


speed = 0.05 * sin(c.frame/30); %pixels/frame. Ths value is not logged automatically.
% To provide some disaster recovery options, each script that is used is
% stored verbatim in the output. This would allow a user to find out what
% the speed parameter was set to.



% However, any assignment to stimulus properties is logged, so the disaster
% recovery is unlikely to be needed?
c.gabor.X = 250+100*cos(c.frame * speed ); 
c.gabor.Y = 250+100*sin(c.frame * speed);

end