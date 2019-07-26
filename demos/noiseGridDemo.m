function noiseGridDemo(varargin)
%   These demos show how to present a grid of luminance/color noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.
%   Shows how to make use of Matlab's built-in sampling distributions
%   (including clamping to a range), transparency mask, setting an update rate.
%
%   Set alphaMask to true to see usage of a transparency.
%   Type >> makedist to see a list of Matlab's supported sampling distributions.
p=inputParser;
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

%% ============== Add stimuli ==================

%Noise grid
wn = stimuli.noisegrid(c,'grid');
wn.size_w = 50;  %Dimensionality of raster (30 texels high, 50 wide)
wn.size_h = 25;
wn.height = 0.2*screenW;   %Width and height on screen
wn.width = wn.height * wn.size_w./wn.size_h;
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
    [m,n]=meshgrid(1:wn.size_w,1:wn.size_h);
    wn.alphaMask = double(hypot(m-mean(m(:)),n-mean(n(:)))>min([wn.size_h/2,wn.size_w/2]));
end

%Other stimulus to demonstrate grid's alpha mask
f = stimuli.fixation(c,'disk');
f.X = '@grid.X+sin(disk.frame/60)*0.75*grid.width';
f.size = wn.height/5;
f.color = [0.8,0.5,0.8];

%% Experimental design
c.trialDuration = 30000; 

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.X = [-10 0 10];  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.order('disk','grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

function vals = ramp(o)
vals = linspace(0,1,o.nRandels);
