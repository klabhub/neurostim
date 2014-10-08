classdef dots < neurostim.stimulus
    
properties 

end 

methods (Access = public) 
    function d = dots(name) 
        d = d@neurostim.stimulus(name);
        d.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
        d.addProperty('ndots',100);
        d.color = [255,255,255];
        d.addProperty('size',10);
        d.addProperty('center',[0,0]);
        d.addProperty('apertureSize',[12,12]);
        d.addProperty('speed',.5); %degrees/second
        d.duration = 20; %seconds
        d.addProperty('direction',30); %deg 
        d.addProperty('x',(rand(1,d.ndots)-.5)*d.apertureSize(1) + d.center(1));
        d.addProperty('y',(rand(1,d.ndots)-.5)*d.apertureSize(2) + d.center(2));
        tmp = Screen('Resolution',0);
        d.addProperty('resolution',[tmp.width,tmp.height]);
        d.addProperty('dist',32);  %cm
        d.addProperty('width',42); %cm
        d.addProperty('RandomDots','NoMotion'); 
        d.addProperty('coherence',[0,.25,.5,.75,1]);
        d.addProperty('pixposx',0);
        d.addProperty('pixposy',0);
        
    end 
    
    

function afterFrame(d,c,evt)
end 



function beforeFrame(d,c,evt)
   
 d.pixposx = angle2pix(d.cic.window,d.x);
 d.pixposy = angle2pix(d.cic.window,d.y);
 
 
   
  switch upper(d.RandomDots)
        
      case 'NOMOTION'
           Screen('DrawDots',d.cic.window,[d.pixposx;d.pixposy],d.size,[1,1,1],d.cic.center);
           pause(5);
        
      
      case 'MOTION'
          
          
         
          
          frameRate = 1/Screen('GetFlipInterval',d.cic.window,1);
          dx = d.speed*sin(d.direction*pi/180)/(frameRate);
          dy = -d.speed*cos(d.direction*pi/180)/(frameRate);
          nFrames = round(d.duration*200*frameRate);
          
          %Keeping the Dots in the Apperture
          l = d.center(1)-d.apertureSize(1)/2;
          r = d.center(1)+d.apertureSize(1)/2;
          b = d.center(2)-d.apertureSize(2)/2;
          t = d.center(2)+d.apertureSize(2)/2;
          
       
          
          
           for i = 1:nFrames
               pixpos.x = angle2pix(d.cic.window,d.x)+ d.resolution(1)/2;
               pixpos.y = angle2pix(d.cic.window,d.y)+ d.resolution(2)/2;
               
               Screen('DrawDots',d.cic.window,[d.pixposx;d.pixposy],d.size,[1,1,1],d.cic.center);
               
               d.x = d.x + dx;
               d.y = d.y + dy;
               
               %Brings back dots that move outside the aperture
               d.x(d.x<l) = (d.x(d.x<l) + d.apertureSize(1));
               d.x(d.x>r) = (d.x(d.x>r) - d.apertureSize(1));
               d.y(d.y<b) = (d.y(d.y<b) + d.apertureSize(2));
               d.y(d.y>t) = (d.y(d.y>t) - d.apertureSize(2));
               
        
               
               
           end
           
          
         
    
           
  end
end
end
end









