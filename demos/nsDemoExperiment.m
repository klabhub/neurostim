function  nsDemoExperiment

import neurostim.*
% Factorweights.
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference','TextRenderer',1);
Screen('Preference', 'ConserveVRAM', 397312);
% c = myConfig('Eyelink',false);
% c = cic;                            % Create Command and Intelligence Center...
% c.screen.pixels = [0 0 1600 1000];         % Set the position and size of the window
% c.screen.color.background= [0 0 0];
% c.screen.colorMode = 'xyl';
% c.iti = 2000;
% c.trialDuration = inf;
c = myConfig;
c.output.saveFrequency=5;
% e = plugins.eyelink;
% e.useMouse = true;
% c.add(e);
c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'
c.add(plugins.output);
% g=stimuli.gabor('gabor');           % Create a gabor stimulus.
% g.color = [1/3 1/3 30];
% g.X = 0;                          % Position the Gabor
% g.Y = 0;                          
% g.sigma = 25;                       % Set the sigma of the Gabor.
% g.phaseSpeed = 10;
% c.add(g);



% t = stimuli.text('text');           % create a text stimulus
% t.message = 'Hello World';
% t.font = 'Courier New';
% t.textsize = 50;
% t.textalign = 'c';
% t.X = '@(mouse) mouse.mousex';
% t.Y = '@(mouse) mouse.mousey';
% t.antialiasing = 0;
% t.color = [1 1 0.5];
% c.add(t);


% 
f=stimuli.fixation('fix');           % Create a fixation stimulus.
% f.on = 0;
% f.duration = 100;
f.duration = Inf;
f.color = [1 1 50];
f.diode.on=true;
f.diode.size='@(fix) fix.size/100';
f.diode.color='@(fix) fix.color';
% f.color = '@(cic,fix) [cic.screen.color.background(1) fix.color(1) fix.color(3)]';
f.shape = 'STAR';
f.size = 1; 
f.size2 = '@(fix) fix.size';
function thisFunction(o,key)
o.X = o.X + 5;
end
f.addKey('r',@thisFunction);

% 
% f.rsvp(30,30,{'angle',{0 45 90 135 180 225 270 315 360}});
% f.angle = '@(cic) cic.frame';
% f.Y = '@(mouse) mouse.mousey';
% f.X = 0;
% f.Y = 0;
% 
c.add(f);
% 

f1 = stimuli.fixation('fix1');
f1.on = 200;
f1.duration = Inf;
f1.shape = 'CIRC';
f1.X = -10;
f1.Y = 10;
f1.color=[1/3 1/3 1/3];

c.add(f1);


m = stimuli.mouse('mouse');
c.add(m);


%  
s = stimuli.rdp('dots');
s.color = [1 1 100];
s.motionMode = 1;
s.noiseMode = 0;
s.noiseDist = 1;
s.coherence = 1;
s.lifetime = 10;
s.duration = Inf;
s.size = 2;
s.maxRadius = 8;
c.add(s);



k = plugins.nafcResponse('key');
c.add(k);
k.keys = {'a' 'z'};
k.correctKey = '@(dots) double(dots.direction < 0) + 1';
k.keyLabels = {'clockwise', 'counterclockwise'};


s = stimuli.shadlendots('dots2');
s.apertureD = 20;
s.color = [1 1 1];
s.coherence = 0.8;
s.speed = 10;
s.direction = 0;
s.Y='@(mouse) mouse.mousey';
c.add(s);


% c.addFactorial('myFactorial',...
%     {'fix','Y',{-5 5 -5},'fix','X',{-10,-10, 10}},{'dots','direction',{-90 90 0}},{'fix','shape',{'CIRC','STAR'}},{'dots','color',{[1/3 1/3 1], [1/3 1/3 5], [1/3 1/3 50]}});
% f.rsvp = {{'shape',{'CIRC' 'STAR' 'CIRC'}},'duration',200,'isi',0};
myFac=factorial('myFactorial',2);
myFac.fac1.fix.X={-10 -10 10};
myFac.fac1.dots.direction={-90 90 0};
myFac.fac2.fix.Y={5 -5};
myFac.fac2.weights=[2 1];
myFac.fac1.weights=[1 1 1];
myFac2=factorial('myFactorial2',1);
myFac2.fac1.fix.shape={'CIRC','STAR'};
% c.addFactorial('myFactorial',myFac);



myBlock=block('myBlock',myFac,myFac2);
myBlock.weights=[1 1];
myBlock.randomization='SEQUENTIAL';
myBlock.nrRepeats=1;

myBlock.afterMessage='wait for keypress';
myFac3=factorial('myFactorial3',1);
myFac3.fac1.dots.coherence={0.8 1};
myBlock2=block('myBlock2',myFac3);
myBlock2.nrRepeats=2;
% myBlock2.beforeFunction=@myFunc2;

%     function out=myFunc2(c)
%        out=true;
%        DrawFormattedText(c.window,'beforemessage',[],[],c.screen.color.text)
%         
%     end




% c.createSession(myBlock,myBlock);
% c.addBlock('myBlock',myBlock) % Add a block in whcih we run all conditions in the factorial 10 times.
% c.add(plugins.mcc);
% c.add(plugins.output);
% % 
% b = plugins.fixate;
% c.add(b);
% c.add(plugins.reward);
% 
% e=plugins.eyelink;
% e.eyeToTrack = 'binocular';

% f1 = plugins.fixate('f1');
% f1.X = 0;
% f1.Y = 0;
% f1.duration = 500;
% c.add(f1);
% f2 = plugins.fixate('f2');
% f2.X = 5;
% f2.Y = 0;
% c.add(f2);

c.add(plugins.gui);
% s=plugins.saccade('sac1',f1,f2);
% c.add(s);

c.cursor='arrow';
% b = plugins.liquidReward('liquid');
% b.when='AFTERTRIAL';
% c.add(b);
% c.add(plugins.mcc);
% d = plugins.soundReward('sound');
% c.add(d);
c.order('dots','dots2','fix','fix1','gui');
c.run(myBlock,'nrRepeats',20);

end