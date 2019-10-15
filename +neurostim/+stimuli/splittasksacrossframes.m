classdef (Abstract) splittasksacrossframes < neurostim.stimulus
    %Sometimes we need more than one frame to compute the next image in a
    %stimulus (e.g. updating every pixel in a display with random noise).
    %Calling rand(1024,1024), for example, takes over 10 ms on most
    %machines.
    %This class allows the computational load of preparing the next image
    %(which often includes more than one costly task) to be distributed
    %across frames and optimized to eliminate frame drops. The visible
    %image is updated every N frames.
    %
    %See splittaskstimulus.m anfd fourierfiltimage for examples.
    %
    %Subclasses provide a list of tasks to be done (function handles, see
    %addTask()) between one update of the image and the next. Each task is
    %assigned to an object that will automatically be split into sub-tasks
    %(e.g. computing a partial image, such as rand(32,1024)) in proportions
    %needed to align the load with frames and minimise drops. Sub-task
    %objects each carry a value indicating what proportion of the total
    %task it represents, which can be used, for example, to compute
    %column-wise sub-images of an image matrix, which are concatenated in
    %the final step.
    %
    %During optimisation, the distribution of tasks across the little
    %frames (i.e. frames 1:N) is altered until the probability of
    %frame-drops across little frames is flat. i.e. the frame drops are
    %either not caused by our stimulus, or are as low as they can be given
    %the total task load.
    
    %% Constants
    properties (Constant)
        PROFILE@logical = false; % Using a const to allow JIT to compile away profiler code
    end
    
    properties (Access = private)
        beforeTrialTasks@neurostim.splittask;   %Array of splittask objects (handles) to be done before trial. These aren't ever split, but having this allows for subclasses to put tasks here if constant over trials or in beforeFrameTasks if not (which can vary across experiemnts)
        beforeFrameTasks@neurostim.splittask;   %Array of splittask objects to be done before frames
        nTasksPerFrame;                         %How many tasks should be done per litle frame? 1 x o.nTasks vector
        tasksByFrame@cell                       %1 x nLittleFrames cell array of task objects, executed in order
        taskPlan;                               %o.nLittleFrames x o.nTasks matrix of how tasks are distributed
        history;                                %Record of framed drop history
        nLittleFrames;                          %Private copy of o.bigFrameInterval, for faster access.
    end
    
    properties (GetAccess = protected, SetAccess = private)
        nTasks = 0;                             %Number of beforeFrame tasks
        nTotalTasks = 0;                        %Total number, including beforeTrial tasks
    end
    
    properties (Access = protected)
        tasks@neurostim.splittask;              %All tasks.
    end
    
    properties (GetAccess = public, SetAccess = private)
        littleFrame = 0;                        %Increments from 1:bigFrameInterval, then resets.
        bigFrame = 0;                           %How many times has the image been updated?
        isBigFrame = false;                     %Flag to indicate that a frame is a big frame (i.e. update time)
        drawingStarted = false;                 %Has the stimulus appeared on the screen yet? (not true until the first big frame)
    end
    
    methods (Abstract)
        setupTasks(o);
        beforeBigFrame(o);
        draw(o);
    end
    
    methods (Access = public)
        function o = splittasksacrossframes(c,name)
            
            o = o@neurostim.stimulus(c,name);
            
            %User-definable
            o.addProperty('bigFrameInterval',5);        %How long should each frame be shown for? default = 5 frames.
            o.addProperty('optimise',true);             %Should we update o.nTasksPerFrame on the fly, using frame drop counts?
            o.addProperty('learningRate',0.03);         %How responsive should we be from trial to trial?
            o.addProperty('showReport',true);           %Plot frame-drops per trial and show task plan
                        
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
        end
        
        function beforeExperiment(o)
            
            %How many little frames are there? (passing to non-ns parameter for faster access.
            o.nLittleFrames = o.bigFrameInterval;
            
            %Allow the subclass to build the splittask objects and define
            %their properties, including whether they should be run
            %beforeTrial or beforeFrame.
            setupTasks(o);
            
            %Group tasks based on when they should be done
            o.beforeTrialTasks = o.tasks(arrayfun(@(tsk) tsk.enabled && strcmpi(tsk.when,'BEFORETRIAL'),o.tasks));
            o.beforeFrameTasks = o.tasks(arrayfun(@(tsk) tsk.enabled && strcmpi(tsk.when,'BEFOREFRAME'),o.tasks));
            o.nTasks = numel(o.beforeFrameTasks);
            
            %Set a default task plan if not supplied
            if isempty(o.nTasksPerFrame)
                o.nTasksPerFrame = ones(1,o.nLittleFrames);  %This gets scaled up to sum to nTasks below
            end           
                
        end
        
        function beforeTrial(o)
            
            %Reset some properties
            o.littleFrame = 0;
            o.drawingStarted = false;
            o.bigFrame = 0;
            
            %A limitation of this stimulus in its current form is that bigFrameInterval has to
            %be constant for the whole experiment.
            if o.bigFrameInterval~=o.nLittleFrames
                error('bigFrameInterval changed value across trials. Not currently supported.');
            end
            
            %If the tasks have not yet been split, or we need to optimise, re-combine, re-split
            if o.cic.trial==1 || o.optimise
                
                %Update the estimate of how the load should be distributed
                updateFrameLoad(o);
                
                %Using that estimate, prepare the schedule for tasks-by-littleFrame
                updateSchedule(o);
                
                %Split the task objects into the required sub-tasks, ready for execution in beforeFrame()
                splitTasks(o);
            end
            
            %Do all the tasks that can be done now, with or without profiling the tasks
            if o.PROFILE
                arrayfun(@(tsk) profileDo(tsk),o.beforeTrialTasks);
            else
                arrayfun(@(tsk) do(tsk),o.beforeTrialTasks);
            end
        end
        
        function afterTrial(o)
            if o.optimise
                processFramedrops(o);
            end
        end
      
        function afterExperiment(o)
            if o.PROFILE
                report(o.beforeFrameTasks);
            end
        end
        
        function beforeFrame(o)
            
            %Which little frame are we up to?
            o.littleFrame = o.littleFrame+1;
            
            %Is this a big frame?
            o.isBigFrame  = o.littleFrame==o.nLittleFrames;
            if o.isBigFrame
                o.bigFrame = o.bigFrame + 1;
            end
            
            %Do the tasks that have been allocated to this little frame, with or without profiling the tasks
            if o.PROFILE
                arrayfun(@(tsk) profileDo(tsk),o.tasksByFrame{o.littleFrame});
            else
                arrayfun(@(tsk) do(tsk),o.tasksByFrame{o.littleFrame});
            end                        
            
            %Is it time to update drawing objects/textures?
            if o.isBigFrame
                o.beforeBigFrame();
                if o.bigFrame==1
                    o.drawingStarted = true;
                end
            end
            
            %If we are ready to start drawing, call on the subclass to draw to the display.
            if o.drawingStarted
                o.draw();                
            end
        end
        
        function addTask(o,fun,varargin)
            %"name" is a string task name
            %"fun" is a function handle, f(o,t) to the task that should be done.
            %It receives the stimulus plugin as the first argument and the
            %splittask object as the second. The latter will contain info
            %needed to know how much of the task to do in your function.
            %"splittable" is currently not used. Some tasks cannot be
            %split, so this would be a way to mark those and to ensure they
            %are not split in the o.taskPlan. Not yet implemented.
            p=inputParser;
            p.addRequired('taskFun',@(x) isa(x,'function_handle'));
            p.addParameter('name',[]);
            p.addParameter('splittable',1);
            p.parse(fun,varargin{:});
            p = p.Results;
            
            if o.cic.trial>0
                error('Tasks can only be added before c.run() or in beforeExperiment().');
            end
            
            if isempty(p.name)
                p.name = func2str(p.taskFun);
            end
            
            %Create a splittask object
            newJob = neurostim.splittask(p.name,o,p.taskFun,p.splittable);
            
            %Add it to the list.
            o.tasks = horzcat(o.tasks,newJob);
            o.nTotalTasks = numel(o.tasks);
        end
        
        function afterFrame(o)
            %Reset counters and task progress
            if o.isBigFrame
                o.littleFrame = 0;
            end
        end
    end % public methods
        
    methods (Access = private)
        function updateFrameLoad(o)
            %How many tasks are we doing per frame? Initially, it's
            %nTasks/nLittleFrames (unless set by the user), but is altered to distribute frame drops uniformly.
            tsksPerFr = o.nTasksPerFrame;
            if o.cic.trial>1
                %Use frame drops to re-distribute the task load
                %How many frame drops were there on each of the
                %1:nLittleFrames over the whole last trial?
                nDropsPerLittleFrame = o.history.nDroppedPerLittleFrame(:,end)';
                nFramesPerLittleFrame = o.history.nFramesPerLittleFrame(:,end)';
                nDrops = sum(nDropsPerLittleFrame);
                if nDrops
                    %Convert to a frame-drop pdf over little frame space
                    pDrops = nDropsPerLittleFrame./nFramesPerLittleFrame;
                    
                    %Update the load allocation by doing fewer
                    %tasks-per-frame on frames that had drops
                    %i.e. scale o.nTasksPerFrame by the inverse of the pdf
                    %
                    %TODO: this could be done more like Bayesian updating,
                    %Kalman, etc. e.g. o.nTasksPerFrame = a*o.nTasksPerFrame + (1-a)*(1-pDrops)
                    distFromTargPDF = (pDrops - mean(pDrops))./mean(pDrops);
                    stepSize = o.learningRate*sqrt(nDrops);
                    tsksPerFr = max(tsksPerFr-stepSize*distFromTargPDF,0.0001);
                else
                    %No frame drops. Don't rock the boat.
                end
            else
                %o.nTasksPerFrame was provided by the user and we should stick to it.
            end
            
            %Convert the load to tasks-per-frame and set the ns param
            o.nTasksPerFrame = tsksPerFr./sum(tsksPerFr)*o.nTasks;
        end
        
        function updateSchedule(o)
            
            %Allocate the tasks in order, splitting as required to fit them
            %into the load allocated to each little frame (o.nTasksPerFrame).
            %"Load" is expressed perhaps counterintuitively: a small value
            %means that we can only do a small proportion of a standardized task load on that
            %frame (i.e. the task(s) being done on that frame must be more
            %costly than the standard, so we do less of it/them)
            %
            %o.taskPlan is a o.nLittleFrames x o.nTasks matrix of
            %proportion values: how much of each task should be done on
            %each little frame, i.e., columns sum to 1.
            
            if ~isempty(o.taskPlan) && ~o.optimise
                %We're using the same plan every trial. Nothing to do.
                return;
            end
            
            %Clear the previous schedule
            o.taskPlan = zeros(o.bigFrameInterval,o.nTasks);
            
            %Keep track of how much load has already been allocated to the
            %current frame (i), and how much of the current task (j) has
            %already been allocated
            remFrameAlloc = o.nTasksPerFrame;
            remTask = ones(1,o.nTasks);
            for i=1:o.bigFrameInterval
                for j=1:o.nTasks
                    if ~remTask(j)
                        %Task completely allocated. Move onto next one.
                        continue;
                    end
                    
                    %Add as much of the the current task to this frame as we can
                    if o.beforeFrameTasks(j).splittable
                        o.taskPlan(i,j) = min(remTask(j),remFrameAlloc(i)); %Allocates some or all (if last frame)
                    else
                        %We can't split, so allocate to this frame only if more than half a nominal task remains.
                        o.taskPlan(i,j) = double(remFrameAlloc(i) > 0.5);
                    end
                    
                    %Update our record of things already alloacted
                    remTask(j) = remTask(j) - o.taskPlan(i,j);
                    remFrameAlloc(i) = max(remFrameAlloc(i) - o.taskPlan(i,j),0); %Can be negative because of unsplittable tasks, so this forces zero
                    if ~remFrameAlloc(i)
                        %No further load available on this frame. Move to next.
                        break;
                    end
                end
            end
            
            %Because of unsplittable tasks, we haven't necessarily assigned
            %all to frames. Any remaining will have to be assigned to last frame.
            o.taskPlan(i,:) = o.taskPlan(i,:)+remTask;
            if sum(o.taskPlan(:))~=o.nTasks
                keyboard;
                error('Something went wrong with the scheduling of tasks. This is probably a bug.');
            end
        end
        
        function splitTasks(o)
            %Read the task plan and split task objects accordingly.
            %(nothing happens to unsplittable tasks)
            
            %First, re-combine all split tasks. This deletes all the sub-task children.
            recombine(o.beforeFrameTasks);
            
            %Now re-split them in the requested proportions
            for i=1:o.nTasks
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
            nDropped = 0;
            ignoredDroppedFrames = [];
            
            %Count frame drops for each little frame
            fd=get(o.cic.prms.frameDrop,'trial',o.cic.trial,'struct',true);
            if ~iscell(fd.data)
                droppedFrames = fd.data(:,1);
                droppedFrames(isnan(droppedFrames)) = [];
                droppedFrames = droppedFrames + 1;% I DON'T KNOW WHY THIS IS NEEDED. See CIC.run()
                
                %We'll ignore frame-drops on first big frame
                isInFirstBigFrame = droppedFrames<=o.nLittleFrames+1;
                ignoredDroppedFrames = droppedFrames(isInFirstBigFrame);
                droppedFrames(isInFirstBigFrame) = [];
                
                %Use unique() to do the count (ia is little frame number, ic provides the info needed to then count them
                nDropped = zeros(o.bigFrameInterval,1);
                [lfNum,~,ic] = unique(frame2LittleFrame(droppedFrames));
                counts = accumarray(ic,1);
                nDropped(lfNum) = counts;
            end
            
            %Store history of task plans and drops (don't think I need all this. refine and remove)
            o.history.nTasksPerFrame(:,o.cic.trial) = o.nTasksPerFrame;
            o.history.nFramesPerLittleFrame(:,o.cic.trial) = nExecuted;
            o.history.nDroppedPerLittleFrame(:,o.cic.trial) = nDropped;
            if any(nDropped)
                o.history.frameNumbers{o.cic.trial} = droppedFrames;
            else
                o.history.frameNumbers{o.cic.trial} = [];
            end
            o.history.ignoredDroppedFrames{o.cic.trial} = ignoredDroppedFrames;
            if o.showReport
                report(o);
            end
        end 
    end
    
        
    methods (Access = protected)
        
        function report(o)
            subplot(3,2,1);
            plot(sum(o.history.nDroppedPerLittleFrame,1),'o-b','linewidth',1,'markerfacecolor','b','markersize',5,'markeredgecolor','w');
            subplot(3,2,2);
            imagesc(o.history.nDroppedPerLittleFrame(:,o.cic.trial)./o.history.nFramesPerLittleFrame(:,o.cic.trial)); set(gca,'clim',[0 1]);
            subplot(3,2,3);
            imagesc(o.history.nTasksPerFrame);
            subplot(3,2,4);
            imagesc(o.taskPlan);
            
            subplot(3,2,5:6); cla
            frameNum = o.history.frameNumbers{o.cic.trial};
            ignoredDroppedFrames = o.history.ignoredDroppedFrames{o.cic.trial};
            plot(frameNum,ones(1,numel(frameNum)),'bo'); hold on;
            plot(ignoredDroppedFrames,ones(1,numel(ignoredDroppedFrames)),'rx');

            xlim([1,o.cic.frame]);
            drawnow;
        end
        %         end
    end % protected methods
    
    methods (Static)
        
    end
end % classdef