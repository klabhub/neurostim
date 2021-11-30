function circlePath(c)
% Demo eScript to show how stimulus properties can be changed on the fly in
% an experiment. This eScript is called by the scripting.m demo


speed = 0.1 * sin(c.frame/30); %cm/frame. Ths value is not logged automatically.
% To provide some disaster recovery options, each script that is used is
% stored verbatim in the output. This would allow a user to find out what
% the speed parameter was set to.


radius = 0.1*sqrt(sum(c.screen.width.^2));
% However, any assignment to stimulus properties is logged, so the disaster
% recovery is unlikely to be needed?
c.gabor.X = radius*cos(c.frame * speed ); 
c.gabor.Y = radius*sin(c.frame * speed);

end