function c = adamsConfig(varargin)
import neurostim.*

p=inputParser;
p.addParameter('Eyelink',true);
p.addParameter('MCC',false);
p.addParameter('Blackrock',true);
p.addParameter('Output',true);
p.parse(varargin{:});
p = p.Results;

c = cic;
c.screen.pixels = [0 0 1680 1050];
c.screen.physical = [50 50/c.screen.pixels(3)*c.screen.pixels(4)];
c.screen.colorMode = 'RGB';
c.screen.color.background= [0.5 0.5 0.5];
c.trialDuration = Inf;
c.iti = 500;
end