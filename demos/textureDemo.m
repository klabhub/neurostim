function textureDemo(varargin)
% TEXTUREDEMO demo of the texture stimulus plugin.
%   TEXTUREDEMO([NUM][,NAME1,VALUE1]) runs demo NUM with the supplied
%   options (given as a list of name-value pairs).
%
%   NUM defines the demo to run (Default: 1).
%
%   Available options are:
%     RSVP - TRUE or FALSE, enables an rsvp variant of the requested demo
%            (Default: FALSE). See the description of the demos below.
%
%   Available demos are:
%     1 - Generates a single texture, consisting of the product of two
%         sinusoids (in polar coordinates), and presents it within a
%         gaussian window.
%
%         If RSVP is TRUE, this demo uses rsvp to rotate the texture
%         through 360 degrees.
%
%     2 - Generates a library containing multiple textures, consisting of
%         various stages of an expanding wedge.
%
%         If RSVP is TRUE, this demo uses rsvp to cycle through the
%         library, in effect animating the expanding wedge.

% 2016-09-24 - Shaun L. Cloherty <s.cloherty@ieee.org>

import neurostim.*
commandwindow;

%
% parse input
%
p = inputParser;
p.addOptional('demo',1,@(x) validateattributes(x,{'numeric'},{'nonempty'}));
p.addParameter('rsvp',false,@(x) validateattributes(x,{'logical'},{'nonempty'}));
p.addParameter('width',5.0,@(x) validateattributes(x,{'numeric'},{'nonempty'}));
p.addParameter('height',5.0,@(x) validateattributes(x,{'numeric'},{'nonempty'}));

p.parse(varargin{:});

%
% rig configuration
%
c = myRig;
c.screen.color.background = [0.5 0.5 0.5];

%
% stimuli
%

% a texture stimulus...
f = stimuli.texture(c,'texture');

sz = [256,256]; % texture size in pixels, [wdth,hght]

N = 60; % number of textures/images

switch p.Results.demo,
  case 1,
    % demo 1: a single image...
    img = mkimg1(sz,3);
    img = repmat(img,1,1,3); % RGB
    img(:,:,4) = mkwin(sz,0.15); % RGBA..., A = gaussian window
    f.add(1,round(255*img));
        
    % optional rsvp...
    rsvp = design('rsvp');
    rsvp.randomization = 'SEQUENTIAL';
    rsvp.fac1.texture.angle = linspace(0,360,N);
  case 2,
    % demo 2: multiple images...
    img = mkimg2(sz,N); % expanding wedge, luminance (L) only
%     img = mkimg3(sz,N); % integers 1..N

    for ii = 1:N,
%       img_ = repmat(img(:,:,ii),1,1,3);
      f.add(ii,round(255*img(:,:,ii)));
    end
    
    % optional rsvp...
    rsvp = design('rsvp');
    rsvp.randomization = 'SEQUENTIAL';
    rsvp.fac1.texture.id = f.texIds; %1:N;
  otherwise,
    error('Unrecognised demo ''%i''. Type ''help textureDemo'' for usage information.',p.Results.demo);
end

f.width = p.Results.width; % in screen units
f.height = p.Results.height;
f.on = 0;
% f.id = 1;

%
% presentation options
%
if p.Results.rsvp,
  f.addRSVP(rsvp,'duration',50,'isi',0); % 50ms presentations...
  c.trialDuration = N*50;
else
  c.trialDuration = 1000;
end

c.iti = 1000;

% factorial design
d = design('factorial');
d.randomization = 'SEQUENTIAL';
d.fac1.texture.id = f.texIds;

% specify a block of trials
blk = block('block',d);
blk.nrRepeats = 10;

% now run the experiment...
% c.setPluginOrder('texture');
c.subject = 'demo';
c.paradigm = 'textureDemo';
c.run(blk);
end


function img = mkimg1(sz,n)
  % generates a single image of size sz showing
  % the produce of two sinusoids in polar coordinates
  %
  % n determines the number of cycle of the two sinusoids
  [x,y] = meshgrid([1:sz(2)]',1:sz(1));

  x0 = round(0.5*sz(1));
  y0 = round(0.5*sz(2));

  [th,r] = cart2pol(x-x0,y-y0);
  
  th = th + (sign(th)<0)*2*pi;
  th = fliplr(th)';
  
  img = 0.5*(sin(2*pi*n*(r/sz(1))).*sin(n*th) + 1.0); % 0.0..1.0
end

function win = mkwin(sz,k)
  % generates a gaussian window of size
  % sz, with sigma = k*min(sz)
  [x,y] = meshgrid([1:sz(2)]',1:sz(1));

  x0 = round(0.5*sz(1));
  y0 = round(0.5*sz(2));

  [~,r] = cart2pol(x-x0,y-y0);
    
  win = normpdf(r,0.0,k*min(sz));
  win = win - min(win(:));
  win = win./max(win(:)); % 0.0..1.0
end

function img = mkimg2(sz,n)
  % generates a stack of n images of size
  % sz showing an expanding wedge
  [x,y] = meshgrid([1:sz(2)]',1:sz(1));

  x0 = round(0.5*sz(1));
  y0 = round(0.5*sz(2));

  [th,r] = cart2pol(x-x0,y-y0);
  
  th = th + (sign(th)<0)*2*pi;
  th = fliplr(th)';
  
  r_ = round(0.4*min(sz)); % pixels
  th_ = 2*pi/n;
  
  fprintf(1,'Generating textures (expanding wedge):\n');
  
  img = NaN(sz(2),sz(1),n);
  for ii = 1:n,
    img(:,:,ii) = 0.5;
    
    idx = find(th <= th_*(ii));
    idx = intersect(idx,find(r < r_));

    img((ii-1)*prod(sz)+idx) = 0.25;
    
    fprintf(1,'.');
  end
  fprintf(1,'\nDone!\n');
end

function img = mkimg3(sz,n)
  % generates a stack of n images of size
  % sz showing the integers 1..n
  dx = round(0.5*sz(1));
  dy = round(0.5*sz(2));

  fh = figure();
  fh.Visible = 'off';

  fprintf(1,'Generating textures (integers 1..%i):\n',n);

  img = NaN([sz(2),sz(1),n]);
  for ii = 1:n,
    clf(fh);

    h = text(0,0,sprintf('%i',ii));
  
    xlim(dx*[-1,1]);
    ylim(dy*[-1,1]);
  
    set(h,'FontSize',64,'HorizontalAlignment','center');
  
    axis equal

    set(gca,'Visible','off');
  
    f = getframe(gca);
    img_ = rgb2ind(f.cdata,gray(256));
  
    img_(img_ < 128) = 1; % black
    img_(img_ >= 128) = 128; % mean gray
  
    sz = size(img_);
    img(:,:,ii) = 0.5*double(img_(round(sz(1)/2)+[-dx:dx-1], ...
                                  round(sz(2)/2)+[-dy:dy-1])-1)./127;
                              
    % show progress
    fprintf(1,'.');
  end
  delete(fh);

  fprintf(1,'\nDone!\n');
end
