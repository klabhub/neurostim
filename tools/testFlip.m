function tictoc = testFlip(nrFrames,deadline,slack,verbose)
% Test the "cost" of Screen('Flip',w,when).
%
% This test is motivated by the observation that when running PTB3 on
% Linux, invoking Screen('Flip',w[,when]) with the optional 'when'
% parameter can cause a substantial (i.e., a factor of 2-5 times) slowdown
% of Matlab code in the frame loop. In extreme cases, this can cause
% dropped frames. Calling Screen('Flip',w) without the 'when' parameter
% does not incure this 'cost'.
%
% System configuration(s) for which this has been observed include:
%
%   Intel Core i7-7700 CPU @ 3.60GHz x8, 32Gb RAM, GeForce GTX980Ti/PCIe/SSE2,
%   running Ubuntu Linux 16.04 LTS, with the NVIDIA Driver version 381.22.
%   'uname -a' reports,
%
%   Linux ns2 4.8.0-53-lowlatency #56~16.04.1-Ubuntu SMP PREEMPT Tue May 16 02:33:53 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
%   
% On this system, calling Screen('Flip',w) with the 'when' parameter
% causes subsequent code (e.g., rand(100) in this test) to execute
% ~5 times slower.
%
% To see how your system performs, try the following:
%
%   >> tictoc1 = testFlip(1000,true); % with the 'when' parameter
%
% and compare the output (i.e., time taken to execute rand(100)) with
% that from:
%
%   >> tictoc0 = testFlip(1000,false); % without the 'when' parameter
%
% Usage: tictoc = testFlip([nrFrames[,deadline[,slack[,verbose]]]]);
%
%   'nrFrames' determines the number of frames (i.e. samples) to
%              take (default: 1000).
%
%   'deadline' determines whether the 'when' parameter is passed to
%              the Screen('Flip') command. (default: true).
%
%   'slack'    determines the proportion of the inter-frame interval
%              to allow for the flip (default: 0.2).
%
%   'verbose'  determines whether to produce graphical summary
%              (default: true).
%
% Note, this test does not draw anything to the ptb window. When you run
% it, you will see the ptb welcome screen and then the screen will go
% dark until the test is complete (i.e., after nrFrames)

% 2017-06-01 - Shaun L. Cloherty <s.cloherty@ieee.org>

if nargin < 1 || isempty(nrFrames)
  nrFrames = 1000; % number of frames/samples
end

if nargin < 2 || isempty(deadline)
  deadline = true; % use the deadline argument to Screen('Flip',...), (true or false)
end

if nargin < 3 || isempty(slack)
  slack = 0.2; % slack time (proportion of inter-frame interval) before flip
end

if nargin < 4 || isempty(verbose)
  verbose = true;
end

AssertOpenGL;

% open the screen
screenNumber = max(Screen('Screens'));
w = Screen('OpenWindow', screenNumber, 0);

ifi = Screen('GetFlipInterval', w); % inter-frame interval (seconds)

HideCursor; % hide the mouse cursor
Priority(MaxPriority(w)); % set maximum priority

% initial flip...
vbl = Screen('Flip', w);

tictoc = NaN([nrFrames,1]);

% the frame loop...
for iFrame = 1:nrFrames
  t0 = GetSecs();

  rand(100); % arbitrary function that we can measure the duration of
    
  tictoc(iFrame) = 1000*(GetSecs()-t0);
  
%   Screen('DrawingFinished', w);

  % flip!
  if deadline
    vbl = Screen('Flip', w, vbl + (1-slack)*ifi);
  else
    vbl = Screen('Flip', w);
  end
end;

% restore priority
Priority(0);
ShowCursor;

sca;

if ~verbose
  return;
end

% plot graphical summary...
figure
subplot(1,2,1);
histogram(tictoc);
xlabel('ms');
ylabel('# samples');

subplot(1,2,2);
plot(tictoc(2:end),tictoc(1:end-1),'.',xlim,xlim,'k--');
xlabel('ms');
ylabel('ms');

str = sprintf('nrFrames = %i, deadline = %i, slack = %.2f',nrFrames,deadline,slack);
annotation(gcf,'textbox',[0 0 1 1],'String',str,'HorizontalAlignment','Center')