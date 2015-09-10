function c = myConfig(varargin)
import neurostim.*

p=inputParser;

p.addParameter('Eyelink',true);
p.addParameter('MCC',false);
p.addParameter('Output',true);
p.parse(varargin{:});

p = p.Results;

c = cic;
c.screen.pixels = [0 0 1920 1080];
c.screen.physical = [50 28.125];
c.screen.color.background = [0 0 0];
c.screen.colorMode = 'xyl';
c.iti = 500;
c.trialDuration = 3000;
% c.mirrorPixels = [1920 1080 3840 2160];

% if p.Eyelink
%     e = plugins.eyelink;
%     e.useMouse = true;
%     c.add(e);
% end
% if p.Output
%     c.add(plugins.output);
% end
% if p.MCC
%     c.add(plugins.mcc);
% end
end