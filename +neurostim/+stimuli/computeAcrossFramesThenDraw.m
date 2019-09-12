classdef (Abstract) computeAcrossFramesThenDraw < neurostim.stimulus
    %Sometimes we need more than one frame to compute the next image in a
    %stimulus (e.g. updating every pixel with noise).
    %This little class provides a simple way to call an update()
    %function every frame and a draw() function every M frames.
    %The logged stimulus onset is actually the first time the image is
    %drawn, which is NOT the first frame for this stimulus.
    %
    %Make your stimulus a child of this one, then define beforeLittleFrame()
    %and draw(), and set frameInterval (in ms) to how often the image
    %should be updated on the display (while computing every frame).
    %When you have finished computing he next big frame, you should set
    %bigFrameReady to true (in your beforeLittleFrame() function).
    
    %
    %Child class provides a list of tasks to be done before the next big
    %frame. Each one is a handle to a function that returns done (true) or
    %not done (false). If done, the next task will be called immediately, if there is
    %time (otherwise, it will be called on the next little frame).
    %
    %The optimal value for maxComputeTime is that which makes the rate of
    %frame drops equal for little and big frames. This means we are distributing
    %the total task load evenly. Big frames take as much
    %time as is needed to complete any remaining tasks, and then, the drawing
    %commands. So maxComputeTime needs to be large enough to do a larger
    %share of the tasks on little frames.
    %
    %Thus, the frame-drop ratio (big to little) can be used to optimise maxComputeTime
    %on the fly. e.g. minimise abs(log((nDropsOnBig+1)/(nDropsOnLittle+1)))
    %
    properties (Access = private)

        maxTime;
        allDone = false;
        curTask = 1;
        beforeFrameTasks;
        nTasks = 0;
    end
    
    properties (GetAccess = public, SetAccess = private)
        bigFrameInterval;
        littleFrame = 0;        %Increments each frame within a bigFrame
        bigFrame = 0;           %The current scene frame number, updated every frInet
        isBigFrame = false;
        curTaskIter = 1;
        taskCompleteFame;
    end
    
    properties (Access = protected)
        
    end
    
    properties (GetAccess = public, SetAccess = protected)
    end
    
    properties
        ticTime
        ticTocTime
        debugData
    end
    
    methods (Access = public)
        function o = computeAcrossFramesThenDraw(c,name)
            
            o = o@neurostim.stimulus(c,name);
            
            %User-definable
            o.addProperty('bigFrameRate',o.cic.screen.frameRate/10);      %How long should each frame be shown for? default = 3 frames.
            o.addProperty('maxComputeTime',0.5,'sticky',true); %What proportion of the frame interval are we allowed to use for our tasks?
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
            
        end
        
        function beforeTrial(o)
            
            %Make sure the requested duration is a multiple of the display frame interval
            tol = 0.15; %5mismatch between requested frame duration and what is possible
            nFrames_float = o.cic.screen.frameRate/o.bigFrameRate;
            nFrames_int = round(nFrames_float);
            if abs(nFrames_float-nFrames_int) > tol
                o.writeToFeed(['bigFrameRate is not a divisible factor of the display frame rate. It has been rounded to ', num2str(nFrames_int) ,'ms']);
            end
            o.bigFrameInterval = nFrames_int;
            o.maxTime = o.cic.frames2ms(o.maxComputeTime);
        end
        
        function afterTrial(o)
            
            o.beforeFrameTasks = {};                        
            return;
            
            %Adapt o.maxComputeTime to reduce frame drops
            isLittleFrame = mod(1:o.frame,o.bigFrameInterval)~=0;
            
            oldCPUtime = o.maxComputeTime;
            
            fd=get(o.cic.prms.frameDrop,'trial',o.cic.trial,'struct',true);
            if ~iscell(fd.data)
                droppedFrames = fd.data(:,1);
                droppedFrames(isnan(droppedFrames)) = [];
                droppedFrames = droppedFrames + 1;% I DON'T KNOW WHY THIS IS NEEDED. See CIC.run()
    
                %WE WILL IGNORE FIRST FEW FRAMES. SOMETHING ELSE WRONG
                %THERE
                droppedFrames(droppedFrames<=o.bigFrameInterval)=[];
                %********************
                
                nLittleFrames = sum(isLittleFrame);
                nBigFrames = sum(~isLittleFrame);
                
                littleRate = sum(ismember(droppedFrames,find(isLittleFrame)))./nLittleFrames;
                bigRate = sum(ismember(droppedFrames,find(~isLittleFrame)))./nBigFrames;
                
                base = 1/o.frame;
                logRatio = log((bigRate+base)./(littleRate+base));
                
                learningRate = 0.05*sqrt(numel(droppedFrames));
                o.maxComputeTime = o.maxComputeTime + learningRate*sign(logRatio);
%                 o.maxComputeTime = o.maxComputeTime+learningRate*logRatio;
                o.maxComputeTime = max(o.maxComputeTime,0.05);
                o.maxComputeTime = min(o.maxComputeTime,0.95);
%                 disp(' ');
%                 disp('******');
%                 disp(['Ratio = ' num2str(logRatio) '; old cpu time = ', num2str(oldCPUtime),'; new cpu time = ' num2str(o.maxComputeTime)]);
%                 disp(' ');
            else
                droppedFrames = [];
            end
            subplot(3,1,1);
            plot(o.cic.trial,min(numel(droppedFrames),20),'ko-'); hold on; ylim([0,20]);
          	ylabel('nDropped');
            subplot(3,1,2);
            plot(o.cic.trial,oldCPUtime,'ko-'); hold on; ylim([0,1]);
            ylabel('cpuTime');
            subplot(3,1,3);
            plot(o.cic.trial,o.taskCompleteFame,'ko-'); hold on; ylim([1,4]);
            ylabel('Frame of task completion');
            drawnow
            
            o.debugData(o.cic.trial,1) = numel(droppedFrames);
            o.debugData(o.cic.trial,2) = oldCPUtime;
            o.debugData(o.cic.trial,3) = o.taskCompleteFame;
            if ~mod(o.cic.trial,50)
                keyboard;
            end
            %             keyboard;
        end
        
        function beforeFrame(o)
            
            %Which little frame are we up to?
            o.littleFrame = o.littleFrame+1;
            
            %Will we be drawing on this frame?
            o.isBigFrame  = o.littleFrame==o.bigFrameInterval;
            
            %If there are tasks still to be done
            if ~o.allDone && ~isempty(o.beforeFrameTasks)
  
                %How much time are we allowed to use here?
                timeAllowed = o.maxTime/1000; %use seconds here, for optim
                
                %Check the current time
                [beginTime,curTime] = deal(GetSecs);
                
                %Do as many tasks as we can within the time limit
                while ((curTime-beginTime) < timeAllowed) || o.isBigFrame %latter ensures we say here til all jobs are done on draw frame
                    %Do the next task in the list
                    
                    isDone = o.beforeFrameTasks{o.curTask}(o);
                    
                    if isDone
                        %Are there any tasks left to do?
                        if o.curTask==o.nTasks
                            %No. Break out of while()
                            o.allDone = true;
                            o.taskCompleteFame = o.littleFrame;
                            %disp(num2str(o.taskCompleteFame));
                            break;
                        else
                            %More to do. Move to next task
                            o.curTask = o.curTask+1;
                            o.curTaskIter = 1;
                        end
                    else
                        %Return to the current task on next while loop, or frame
                        o.curTaskIter = o.curTaskIter + 1;
                    end
                    
                    %Check the clock again, so we will stop now if need be
                    curTime=GetSecs;
                    
                    %curTime = beginTime;%***************TEMPORARY*************
                end       
            end
            
            %Is it time to update drawing objects/textures?
            if o.isBigFrame
                o.bigFrame = o.bigFrame + 1;
                o.beforeBigFrame();
            end
            
            %Actually, we need to draw every frame (hmmm.. fix this...)
            if o.cic.frame >= o.bigFrameInterval
                o.draw();
            end
        end
        
        function addBeforeFrameTask(o,fun)
            %Add a task to the list
            if ~iscell(fun)
                fun = {fun};
            end
            o.beforeFrameTasks = horzcat(o.beforeFrameTasks,fun);
            o.nTasks = numel(o.beforeFrameTasks);
        end
        
        function afterFrame(o)
            %Reset counters and task progress
            if o.isBigFrame
                o.littleFrame = 0;
                o.isBigFrame = false;
                o.curTask = 1;
                o.curTaskIter = 1;
                o.allDone = false;
                o.afterBigFrame();
            end
        end
        function beforeBigFrame(o)
            %To be over-loaded
        end
        function afterBigFrame(o)
            %To be over-loaded
        end
        
        function beforeFrameOld(o)
            
            %How many little frames (for computation) are there per big frame (updating display)?
            frInt = o.frameInterval_f;
            
            %Which little frame are we up to?
            o.littleFrame = mod(o.littleFrame,frInt)+1;
            
            %Perform the computation for this little frame.
            if ~o.bigFrameReady
                o.beforeLittleFrame(); %sub-class defines what this does. Usually, you might compute 1/o.frameInterval_f of the things to be done
            end
            
            %Is this a big frame? i.e. time to update display?
            o.isNewFrame = o.littleFrame==frInt;
            if o.isBigFrame
                o.draw();
                o.bigFrameReady = false;
            end
        end
        
        
        function draw(o)
            
            %To be over-loaded in child class.
            
        end
        
        function tic(o)
            o.ticTime = GetSecs;
        end
        
        function toc(o)
            elapsed = GetSecs-o.ticTime;
            o.ticTocTime = horzcat(o.ticTocTime,elapsed*1000);
        end
        
    end % public methods
    
    
    methods (Access = protected)
        
        
        %         end
    end % protected methods
    
    methods (Access = private)
        
    end
    
    methods (Static)
        
    end
end % classdef