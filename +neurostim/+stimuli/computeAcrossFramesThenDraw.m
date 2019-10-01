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
    
    %% New
    properties
        beforeTrialTasks@neurostim.splittask;
        beforeFrameTasks@neurostim.splittask;
        tasksByFrame
        nTasksPerFrame
        nTasks = 0;
        nBeforeFrameTasks;
        taskPlan;
        learningRate;
        nDroppedPerLittleFrame;
        dropRate;
        nTotalDropped;
        history;
    end
    
    %% OLD
    properties (Access = private)

        maxTime;
        allDone = false;
        curTask = 1;
        frameDur
    end
    
    properties (GetAccess = public, SetAccess = private)
        nLittleFrames;
        littleFrame = 0;        %Increments each frame within a bigFrame
        bigFrame = 0;           %The current scene frame number, updated every frInet
        isBigFrame = false;
        curTaskIter = 1;
        taskCompleteFame;
        
        %Split task version
        tasks@neurostim.splittask;
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
            o.addProperty('bigFrameInterval',5);      %How long should each frame be shown for? default = 5 frames.
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
            
        end
        
        function beforeExperiment(o)
            
            o.nLittleFrames = o.bigFrameInterval;
            o.frameDur = 1000/o.cic.screen.frameRate;
            setupTasks(o);
            
            %Group tasks based on when they should be done
            o.beforeTrialTasks = o.tasks(arrayfun(@(tsk) tsk.enabled && strcmpi(tsk.when,'BEFORETRIAL'),o.tasks));
            o.beforeFrameTasks = o.tasks(arrayfun(@(tsk) tsk.enabled && strcmpi(tsk.when,'BEFOREFRAME'),o.tasks));
            
            %How many tasks are we doing per little frame? Initially, it's
            %nTasks/nLittleFrames, but is altered to distribute frame drops
            %uniformly.            
            nTasks = numel(o.beforeFrameTasks);
            o.nTasksPerFrame = nTasks/o.nLittleFrames*ones(1,o.nLittleFrames);
        end
        
        
        function beforeTrial(o)
            
            %Update the estimated time cost of each task.
            updateFrameLoad(o);
            
            %Using the estimated cost, prepare a schedule for tasks-by-littleFrame
            updateSchedule(o);
            
            %Split the tasks into the required sub-tasks, ready for execution in beforeFrame()
            splitTasks(o);
            
            %Do all the tasks that can be done now
            arrayfun(@(tsk) do(tsk),o.beforeTrialTasks);
        end
        
        function updateFrameLoad(o)
            %How many tasks are we doing per frame? Initially, it's
            %nTasks/nLittleFrames, but is altered to distribute frame drops
            %uniformly. 
            if o.cic.trial > 1
                nTasks = numel(o.beforeFrameTasks);                           
                nDropsPerLittleFrame = o.history.nDroppedPerLittleFrame(:,end)';
                if any(nDropsPerLittleFrame)
                    pDrops = nDropsPerLittleFrame./sum(nDropsPerLittleFrame);
                    nTotalDrops = o.history.nTotalDropped(end);
                    
                    o.learningRate = 0.03;
                    
                    o.nTasksPerFrame = o.nTasksPerFrame + o.learningRate*sqrt(nTotalDrops)*(1-pDrops);
                    o.nTasksPerFrame = o.nTasksPerFrame ./sum(o.nTasksPerFrame)*nTasks;
                end
            end
          
        end
        
        function updateSchedule(o)
                        
            nTasks = numel(o.beforeFrameTasks);
                        
            %Allocate the tasks in order, within the allocated task limits
            %for each little frame
            o.taskPlan = [];            
            remFrameAlloc = o.nTasksPerFrame;
            remTask = ones(1,nTasks);
            for i=1:o.bigFrameInterval
                for j=1:nTasks
                    if ~remTask(j)
                        %Task completely allocated
                        continue;
                    end
                    
                    %Add all the remaining task, if remaining time for this frame allows
                    o.taskPlan(i,j) = min(remTask(j),remFrameAlloc(i));

                    %Subtract the allocations from the remaining
                    remTask(j) = remTask(j) - o.taskPlan(i,j);
                    remFrameAlloc(i) = remFrameAlloc(i) - o.taskPlan(i,j);
                    if ~remFrameAlloc(i)
                        break;
                    end
                end
            end            
        end
        
        function splitTasks(o)
            %Read the task plan and split tasks accordingly.
            
            %First, re-combine all split tasks. This deletes all the children.
            recombine(o.beforeFrameTasks);
            
            %Now split each in the requested proportions
            nTasks = numel(o.beforeFrameTasks);
            for i=1:nTasks
                props = o.taskPlan(o.taskPlan(:,i)>0,i);
                subTasks{i} = split(o.beforeFrameTasks(i),props);
            end
            
            %Assign them to the little frames
            newTasks = {};
            for i=1:o.nLittleFrames
                curTasks = find(o.taskPlan(i,:));
                for j=1:numel(curTasks)
                    newTasks{i}(j) = subTasks{curTasks(j)}(1);
                    subTasks{curTasks(j)}(1) = [];
                end
            end
            
            %Assign the new plan
            o.tasksByFrame = newTasks;
        end
        
        function processFramedrops(o)
            %Calculate the rate of frame drops on each little frame
            
            %Create a mapping between frame number and little frame number
            frame2LittleFrame = @(frame) mod(frame-1,o.nLittleFrames)'+1;
                       
            %How many times was each little frame executed?
            littleFrameNum = frame2LittleFrame(1:o.cic.frame);            
            nExecuted = accumarray(littleFrameNum,1);
            
            %Count frame drops for each little frame
            fd=get(o.cic.prms.frameDrop,'trial',o.cic.trial,'struct',true);
            if ~iscell(fd.data)
                droppedFrames = fd.data(:,1);
                droppedFrames(isnan(droppedFrames)) = [];
                droppedFrames = droppedFrames + 1;% I DON'T KNOW WHY THIS IS NEEDED. See CIC.run()
    
                %Use unique() to do the count (ia is little frame number, ic provides the info needed to then count them
                nDropped = zeros(o.bigFrameInterval,1);
                [lfNum,~,ic] = unique(frame2LittleFrame(droppedFrames));
                counts = accumarray(ic,1);
                nDropped(lfNum) = counts;
                o.nDroppedPerLittleFrame = nDropped;
                o.dropRate = nDropped./nExecuted;
                o.nTotalDropped = numel(droppedFrames);
            else
                %No drops.
                o.dropRate = nan(o.bigFrameInterval,1);
                o.nDroppedPerLittleFrame = 0;
                o.nTotalDropped = 0;
            end
            
            %Store history of task plans and drops
            o.history.nTasksPerFrame(:,o.cic.trial) = o.nTasksPerFrame;
            o.history.costPerTask(:,o.cic.trial) = [o.beforeFrameTasks.cost];
            o.history.taskPlans{o.cic.trial} = o.taskPlan;
            o.history.nDroppedPerLittleFrame(:,o.cic.trial) = o.nDroppedPerLittleFrame;
            o.history.nTotalDropped(o.cic.trial) = o.nTotalDropped;
           
%             disp(table(o.nTotalDropped,'variablenames',{'TotalDrops'}));
%             disp(table(o.dropRate,o.taskPlan,'variablenames',{'DropRate','TaskPlan'}));
        end
        
                
        function afterTrial(o)
            
              processFramedrops(o);
              return;
%             if o.cic.trial==5
%                 keyboard;
%             end
%             return
            %Adapt o.maxComputeTime to reduce frame drops
            isLittleFrame = mod(1:o.frame,o.nLittleFrames)~=0;

            fd=get(o.cic.prms.frameDrop,'trial',o.cic.trial,'struct',true);
            if ~iscell(fd.data)
                droppedFrames = fd.data(:,1);
                droppedFrames(isnan(droppedFrames)) = [];
                droppedFrames = droppedFrames + 1;% I DON'T KNOW WHY THIS IS NEEDED. See CIC.run()
    
                %WE WILL IGNORE FIRST FEW FRAMES. SOMETHING ELSE WRONG
                %THERE
                droppedFrames(droppedFrames<=o.nLittleFrames)=[];
                %********************
                
                nLittleFrames = sum(isLittleFrame);
                nBigFrames = sum(~isLittleFrame);
                
                littleRate = sum(ismember(droppedFrames,find(isLittleFrame)))./nLittleFrames;
                bigRate = sum(ismember(droppedFrames,find(~isLittleFrame)))./nBigFrames;
                
                %base = 1/o.frame;
                if o.cic.trial > 2
                    o.frameDropRatio = log((bigRate+eps)./(littleRate+eps));
                else
                    o.frameDropRatio = 0;
                end

            else
                droppedFrames = [];
            end
            o.nDroppedFrames = numel(droppedFrames);
            
            plotDrops=false;
            if plotDrops
                plot(o.cic.trial,min(numel(droppedFrames),20),'ko-'); hold on; ylim([0,20]);
                droppedFrames(1:min(end,15))'
                drawnow;
            end
        end
        
        function beforeFrame(o)
            
            %Which little frame are we up to?
            o.littleFrame = o.littleFrame+1;
            
            %Will we be drawing on this frame?
            o.isBigFrame  = o.littleFrame==o.nLittleFrames;
            
            %If there are tasks still to be done
            %arrayfun(@(tsk) do(tsk),o.beforeFrameTasks);
            curTasks = o.tasksByFrame{o.littleFrame};
            arrayfun(@(tsk) do(tsk),curTasks);
            
            %Is it time to update drawing objects/textures?
            if o.isBigFrame
                o.bigFrame = o.bigFrame + 1;
                o.beforeBigFrame();
            end
            
            %Actually, we need to draw every frame (hmmm.. fix this...)
            if o.cic.frame >= o.nLittleFrames
                o.draw();
            end
        end
        
        function addTask(o,name,fun,splittable)
                 
            %Create a splittask object, to manage itself
            newJob = neurostim.splittask(name,o,fun,splittable);
            
            %Add it to the list.
            o.tasks = horzcat(o.tasks,newJob);
            o.nTasks = numel(o.tasks);
        end
        
        function setTaskPlan(o,schedule)
            %schedule is a o.nLittleFrames x nBeforeFrameTasks matrix of
            %proportion values: how much of each task should be done on
            %each little frame. Columns must sum to 1.            
            %This will be used for all trials unless profiling is on and used
            %to optimise through online profiling.
            o.taskPlan = schedule;
        
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
                
        function draw(o)
            
            %Called every frame, to be over-loaded in child class.
            
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