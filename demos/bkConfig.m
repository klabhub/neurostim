function c = bkConfig
% Function that sets up a CIC for BK based on the machine that the code is
% running on. 


computerName = getenv('COMPUTERNAME');

%% Machine independent settings
c = neurostim.cic;
c.iti = 500;
c.trialDuration = 500;
c.root = 'c:\temp\';
c.cursor = 'arrow';


%% Machine dependent changes
switch upper(computerName)
    case 'KLAB-U'
        c.screen.number =1;
        c.screen.xpixels  = 1920/2;
        c.screen.ypixels  = 1080/2;
        c.screen.width= 38.3;
        c.screen.height = 38.3*1080/1920;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=30;        
      case 'XPS2013'               
        c.screen.number = 0;
        c.screen.xpixels= 400;%[1600 0 3200+1280 1024];
        c.screen.ypixels= 300;%[1600 0 3200+1280 1024];
        c.screen.xorigin = 250;%[1600 0 3200+1280 1024];
        c.screen.yorigin= 100;%[1600 0 3200+1280 1024];
        c.screen.width = 4;
        c.screen.height= 3;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=60;
        
    otherwise
        error(['No CIC configuration settings defined for ' computerName]);
end
end
