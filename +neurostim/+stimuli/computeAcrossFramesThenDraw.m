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
        nTasks = 0;
        
        taskPlan;
        littleFrameLoad;
        learningRate;
        frameDropRatio = 0;
        nDroppedFrames = 0;
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
        end
        
        
        function beforeTrial(o)
            
            %Allocate tasks to little frames
            scheduleTasks(o);
            
            %Do all the tasks that can be done now
            arrayfun(@(tsk) do(tsk),o.beforeTrialTasks);            
        end
        
        
        function scheduleTasks(o)
            nTasks = numel(o.beforeFrameTasks);
            %if isempty(o.taskPlan)
                if o.cic.trial == 1
                    o.tasksByFrame = cell(1,o.nLittleFrames);
                    o.tasksByFrame{1} = o.beforeFrameTasks;
                    o.littleFrameLoad = 1;
                    return;
                end
                
                curTrial = o.cic.trial;
                if curTrial==2
                    %Tasks have not yet been split
                    updateCPUestimate(o.beforeFrameTasks,false);
                else
                    %Process the profile logs from last trial, updating the
                    %estimate of CPU time
                    allSubTasks = leaves(o.beforeFrameTasks);
                    updateCPUestimate(allSubTasks,false);
                    
                    %Re-combine all split tasks. This deletes all the children.
                    recombine(o.beforeFrameTasks);
                end
                
                tskDur = [o.beforeFrameTasks.estDur];
                
                %Express CPU time as proportion of frame
                tskDur = tskDur./o.frameDur;
                
                %taskPlan is a nLittleFrames x nTasks matrix, with how much
                %of each frame is devoted to each task
                o.learningRate = 0.03;
                loadStepSize = o.learningRate*o.nDroppedFrames*(2*normcdf(o.frameDropRatio,0,10)-1); %Cap the step size
                o.littleFrameLoad = o.littleFrameLoad + loadStepSize;
                curLittleLoad = normcdf(o.littleFrameLoad,0,1); %Keep load within bounds
                
                curLittleLoad
                
                bigFrameLoad = 1-curLittleLoad;
                perFrameLoad = horzcat(curLittleLoad*ones(1,o.nLittleFrames-1)/(o.nLittleFrames-1),bigFrameLoad);
                perFrameLoad = perFrameLoad/sum(perFrameLoad);
                
                perFrameLoad = sum(tskDur)*perFrameLoad;
                
                
                %Allocate the tasks
                o.taskPlan = [];
                unallocated=tskDur;
                for i=1:o.nLittleFrames
                    propAllocated = 0;
                    for j=1:nTasks
                        if unallocated(j)==0
                            continue;
                        end
                        o.taskPlan(i,j) = min(unallocated(j),perFrameLoad(i)-sum(propAllocated));
                        unallocated(j) = unallocated(j) - o.taskPlan(i,j);
                        propAllocated = sum(o.taskPlan(i,:));
                        if propAllocated >= perFrameLoad(i)
                            break;
                        end
                    end
                end
                
                %Re-express task plan as proportions of each task and split tasks
                o.taskPlan = o.taskPlan./repmat(tskDur,o.nLittleFrames,1);                
            %end
            
            for i=1:nTasks
                props = o.taskPlan(o.taskPlan(:,i)>0,i);
                splitTasks{i} = split(o.beforeFrameTasks(i),props);
            end
            
            %Now assign the split tasks to the little frames
            newTasks = {};
            for i=1:o.nLittleFrames
                curTasks = find(o.taskPlan(i,:));
                for j=1:numel(curTasks)
                    newTasks{i}(j) = splitTasks{curTasks(j)}(1);
                    splitTasks{curTasks(j)}(1) = [];
                end
            end
            
            %Assign the new plan
            o.tasksByFrame = newTasks;
            %cellfun(@(k) disp([k.name]),o.tasksByFrame)
        end
        
        function afterTrial(o)
            
                           
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
            arrayfun(@(tsk) profileDo(tsk),curTasks);
            
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