function noiseGridDemo(varargin)
%   These demos show how to present a grid of luminance/color noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.
%   Demonstrates:
%   - how to make use of Matlab's built-in sampling distributions
%   - Different types of grid (Cartesian, polar grids, hexagonal grid)
%   (including clamping to a range), transparency mask, setting an update rate.
%   
%
%   Set alphaMask to true to see usage of a transparency.
%   Type >> makedist to see a list of Matlab's supported sampling distributions.
p=inputParser;
p.addParameter('type','CARTESIAN',@(x) any(strcmpi(x,{'CARTESIAN','RADIAL','HEXAGONAL'})));
p.addParameter('demo','LUMINANCE',@(x) any(strcmpi(x,{'LUMINANCE','CUSTOM','SPARSE', 'RGB_COLORS','XYL_LUMINANCE'})));
p.addParameter('useAlphaMask', false); 
p.parse(varargin{:});
p = p.Results;

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
screenW = c.screen.width;
% c.screen.colorMode = 'XYL'; % Tell PTB that we will use xyL to specify color
% c.screen.color.text = [0.33 0.33 1]; % TODO: Text does not seem to work in xyL
% c.screen.color.background = [0.33 0.33 20 ]; % Specify the color of the background
% c.screen.calFile = 'PTB3TestCal'; % Tell CIC which calibration file to use (this one is on the search path in PTB): monitor properties
% c.screen.colorMatchingFunctions = 'T_xyzJuddVos.mat'; % Tell CIC which CMF to use : speciifies human observer properties.

%% ============== Add stimuli ==================

%Noise grid

switch upper(p.type)
    case 'CARTESIAN'
        wn = stimuli.noisegrid(c,'grid');
        wn.size_w = 50;  %Dimensionality of raster (30 texels high, 50 wide)
        wn.size_h = 25;
        wn.height = 0.2*screenW;   %Width and height on screen
        wn.width = wn.height * wn.size_w./wn.size_h;

    case 'RADIAL'
        wn = stimuli.noiseradialgrid(c,'grid');
        wn.nWedges = 40;
        wn.nRadii = 7;
        wn.innerRad = 3;
        wn.height = 0.4*screenW;   %Width and height on screen
        wn.width = 0.4*screenW;
        
    case 'HEXAGONAL'
        wn = stimuli.noisehexgrid(c,'grid');
        wn.type = 'triangle';
        wn.sz = 4;
        wn.hexRadius = 2;
        wn.spacing = 1.2;
end



switch upper(p.demo)
    case 'LUMINANCE'
        wn.sampleFun = 'normal';        %Distribution name. Any of those that Matlab's random() suports. from which luminance/color values are drawn.
        wn.parms =      [0.5 0.15];     %The parameters of the distribution (i.e. args to random(). Here, {mean sd}.
        wn.bounds =     [0 1];          %Truncate the sampling distribution at these values.
        
    case 'CUSTOM'
        wn.sampleFun = @ramp;       %Distribution from which luminance/color values are drawn.   
        
    case 'SPARSE'
        wn.sampleFun = {'normal','binomial'};        
        wn.parms =   {[0.5 0.15],[1 0.1]};             
        wn.bounds =   {[0,1],[]};
        
    case 'RGB_COLORS'
        %Use a custom CLUT function to generate random colors (wn.distribution etc. will be ignored)
        wn.sampleFun =  {'normal','normal',@ramp};       %Distribution from which luminance/color values are drawn.
        wn.parms =      {[0.5 0.15],[0.5,0.15],{}};          %{mean sd}
        wn.bounds =     {[0 1],[0 1],[]};
         
    case 'XYL_LUMINANCE'
        error('XYL_LUMINANCE not yet implemented.')
end

wn.frameInterval=1000./c.screen.frameRate*2; %Update noise every second frame


%Use an alpha mask to remove central randels.
if p.useAlphaMask
    switch upper(p.type)
        case 'CARTESIAN'
            [m,n]=meshgrid(1:wn.size_w,1:wn.size_h);
            wn.alphaMask = double(hypot(m-mean(m(:)),n-mean(n(:)))>min([wn.size_h/2,wn.size_w/2]));
        case 'RADIAL'
            wn.alphaMask  = annulusGaussianMask(wn,(wn.outerRad-wn.innerRad)/10,0,2*pi);
        otherwise
            
            error('The demo doesn''t yet show an alphaMask for this type yet.')
    end
    
end

%Other stimulus to demonstrate grid's alpha mask
f = stimuli.fixation(c,'disk');
f.X = '@grid.X+sin(disk.frame/60)*0.75*grid.width';
f.size = 0.05*screenW;
f.color = [0.8,0.5,0.8];
if strcmpi(c.screen.colorMode,'XYL')
   f.color(end)=100; 
end
%% Experimental design
c.trialDuration = 30000; 

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.X = [-10 0 10];  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.setPluginOrder('disk','grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

function vals = ramp(o)
vals = linspace(0,1,o.nRandels);
