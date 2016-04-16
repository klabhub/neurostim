function c = bkConfig
% Function that sets up a CIC for BK based on the machine that the code is
% running on. 


computerName = getenv('COMPUTERNAME');

%% Machine independent settings
c = neurostim.cic;
c.iti = 500;
c.trialDuration = 500;
c.cursor = 'arrow';



%% Machine dependent changes
switch upper(computerName)
    case 'KLAB-U'
        if true
            % Large, full screen
        c.screen.number = 1;
        c.screen.xpixels  =[];%[];800;
        c.screen.ypixels  = [];;%[];600;
        c.screen.xorigin = [];
        c.screen.yorigin = [];
        c.screen.width= 38.3;
        c.screen.height = 38.3*1080/1920;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=30;        
        else            
        c.screen.number = 2;
        c.screen.xpixels  =[];900;
        c.screen.ypixels  = [];1900;%[];600;
        c.screen.xorigin = [];
        c.screen.yorigin = [];
        c.screen.width= 38.3;
        c.screen.height = 38.3*1620/2880;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=60;        
        end
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        
        
      case 'XPS2013'               
        c.screen.number = 0;
        c.screen.xpixels= [];800;%[1600 0 3200+1280 1024];
        c.screen.ypixels= [];600;%[1600 0 3200+1280 1024];
        c.screen.xorigin = 0;%[1600 0 3200+1280 1024];
        c.screen.yorigin= 0;%[1600 0 3200+1280 1024];
        c.screen.width = 34.5;
        c.screen.height= 19.5;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=60;
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        
    case ''
        if ismac
        c.screen.number = 0;
        c.screen.xpixels= [];800;%[1600 0 3200+1280 1024];
        c.screen.ypixels= [];600;%[1600 0 3200+1280 1024];
        c.screen.xorigin = 0;%[1600 0 3200+1280 1024];
        c.screen.yorigin= 0;%[1600 0 3200+1280 1024];
        c.screen.width = 34.5;
        c.screen.height= 19.5;
        c.screen.color.background = [0.5 0.5 0.5];
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=60;
        Screen('Preference', 'SkipSyncTests', 0); 
        
        c.dirs.output = '~/temp/';

        end
        
    otherwise
        
        error(['No CIC configuration settings defined for ' computerName]);
end
end
