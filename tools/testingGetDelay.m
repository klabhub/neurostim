function testingGetDelay

%Script shows 3 ways of creating a cic and adding a plugin. All seem like
%they SHOULD be equivalent, but show vastly different delays in reading basic properties.

import neurostim.*
commandwindow;
elapsed = zeros(200,1);

%Approach 1:
disp('*** Approach 1 (cic and plugin created locally):');
c=cic;
e = neurostim.plugins.eyetracker(c);

%Time per call?
for i=1:200
    tic;
    tmp=e.x;
    elapsed(i) = toc*1000;
end

disp(['Time (ms) per get (local pointer) = ' num2str(median(elapsed))]);


for i=1:200
    tic;
    tmp=c.eye.x;
    elapsed(i) = toc*1000;
end
disp(['Time (ms) per get (cic''s pointer) = ' num2str(median(elapsed))]);


%Approach 2
disp('*** Approach 2 (cic with plugin returned by a function call, as in myRig):');

c2=getcic;
for i=1:200
    tic;
    tmp=c2.eye.x;
    elapsed(i) = toc*1000;
end
disp(['Time (ms) per get (cic''s pointer) = ' num2str(median(elapsed))]);


%Approach 3
disp('*** Approach 3 (return local pointer from function call):');
[c3,e3] = getcic2;
for i=1:200
    tic;
    tmp=e3.x;
    elapsed(i) = toc*1000;
end
disp(['Time (ms) per get ("local" pointer) = ' num2str(median(elapsed))]);

for i=1:200
    tic;
    tmp=c3.eye.x;
    elapsed(i) = toc*1000;
end
disp(['Time (ms) per get (cic''s pointer) = ' num2str(median(elapsed))]);

disp('Note: in approach 3, the cic''s pointer is now fast, just by the presence of the "local" pointer.');

function c2 = getcic
import neurostim.*
c2=cic;
neurostim.plugins.eyetracker(c2);      %If no eye tracker, use a virtual one. Mouse is used to control gaze position (click)

function [c3,e] = getcic2
import neurostim.*
c3=cic;
e = neurostim.plugins.eyetracker(c3);      %If no eye tracker, use a virtual one. Mouse is used to control gaze position (click)

    
