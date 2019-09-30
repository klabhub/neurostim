classdef splittask < handle & matlab.mixin.Copyable
   %A task that is completed over one or more frames, keeping track of
   %progress, and scaling the per-frame sub-task to avoid frame drops.
   
   properties
       name
       plg@neurostim.plugin;            %Which plugin owns this task?
       task@function_handle             %The task to be done. Must receive the plugin as first argument, and the splittask object as second
       splittable;                      %Can this task be done in parts?
       when = 'beforeFrame';            %When will the task be called? (beforeFrame,beforeTrial etc.)
       enabled = 1;
       cost = 1;                        %How long does it take to run this task? Normalised units. Adjusted based on frame drops. 
       nParts = 1;
       propOfTask=1;
       part = 1;
       parent@neurostim.splittask;      %Handle to parent task (empty if not yet split).
       children@neurostim.splittask;    %Handles to child tasks (empty if not yet split).
       
       data = [];                       %User-data, for any purpose
       
       %Profiling properties
       profiling = 0;
       profile_start;
       profile_dur;
       estDur;
   end
   
   methods
       function t = splittask(name,plg,fun,splittable)
           if nargin < 1
               %Empty object
               t = neurostim.splittask.empty;
               return;
           end
               
           t.name = name;
           t.plg = plg;
           t.task = fun;
           t.splittable = splittable;
       end
       
       function do(t)
           %Run the task, passing the parent plugin as first argument amd
           %this object as second, to allow function to
           %know how many parts it has been split into, which part it is up
           %to, etc.
           t.task(t.plg,t);
       end
       
       function profileDo(t)
           t.profile_start = GetSecs;
           do(t);
           t.profile_dur = horzcat(t.profile_dur,(GetSecs - t.profile_start)*1000);
       end
       
       function tOut = split(t,p)
           
           %Split a task (equally or unequally) into multiple tasks.
           %p is a vector of proportions, and must sum to 1
           %The task is split into numel(p) tasks.
           %Currently assumes t.data is a matrix and splits along columns.
           %That should be fixed.
                      
           %By default, split it into two equal parts (or as close to as possible if odd)
           if nargin < 2
               p = ones(1,2)/2;
           else
               p = p(:)';
           end
           
           if p==1
               %Nothing to do
               tOut = t;
           end
           
           if ~t.splittable
               error('This task has been marked as unsplittable. Set t.splittable to false if need be.')
           end
           
           if abs(sum(p)-1)>0.0001
               error('Split proportions must sum to 1');
           end
           
           %How many sub-tasks are we creating?
           nOut = numel(p);
           
           %Is there data to be split? Work out how many columns will be in each
        
           if ~isempty(t.data)
               %Make sure each sub-task has at least one column
               totCols = size(t.data,2);
               minP = 1/totCols;  
               p(p<minP) = minP;
               p=p./sum(p);      %Re-normalise
               
               %Calculate the segments
               nCols = diff([0,round(cumsum(p.*totCols))]); %This provides the closest approximation
           else
               nCols = [];
           end
           
           %Clear the profile data
           t.profile_dur = [];
           
           %Make the copies
           for i=1:nOut
               
               %Make a copy of the parent
               tOut(i) = copy(t);

               %Keep track of which sub-task the child is
               tOut(i).name = horzcat(tOut(i).name,num2str(i));
               tOut(i).part = i;
               tOut(i).propOfTask = p(i);
               tOut(i).nParts = nOut; 
               tOut(i).parent = t;
               
               %Calculate an estimate of how long this sub-task will take
               %We just assume linearity. This could be improved by
               %allowing some other function of N (e.g. exponential)
               tOut(i).estDur = tOut(i).estDur*p(i);
                              
               %Split the data 
               if ~isempty(t.data)
                   if i==1
                       startAt = 1;
                   else
                       startAt = sum(nCols(1:i-1))+1;
                   end
                   tOut(i).data = t.data(:,startAt:startAt+nCols(i)-1);
               end                            
           end

           %Keep track of our family
           t.children = tOut;
           t.nParts = nOut;
           t.data = []; %Clear the data. It is now stored in the children.
           t.estDur = [];
       end
       
       function recombine(t)
           %Reverse a split operation, restoring all data into
           %one object, and deleting the children.
           nTasks = numel(t);
           if nTasks>1
               %An array of tasks. Recombine each with recursive call
               for i=1:nTasks
                   recombine(t(i)); 
               end
               return;
           end
           
           %We get here when we are dealing with just one task and its children
           if isempty(t.children)
               %Nothing to do.
               return;
           end
            
           for i=1:numel(t.children)
               %Check whether our child also has children. Recombine if so.
               if ~isempty(t.children(i).children)
                   recombine(t.children(i));
               end
               
               %Concatenate the data for all our children
               t.data = horzcat(t.data,t.children(i).data);
           end
           t.estDur = sum([t.children.estDur]);
           t.propOfTask = sum([t.children.propOfTask]);
           t.nParts = 1;
           t.part = 1;
           delete(t.children);
           t.children = neurostim.splittask;
       end

       function allLeaves = leaves(tList)
           %Returns all sub-tasks at the bottom of a task tree
           %Traverses tree gathering the bottom-most tasks
           %Done so through recursion
           allLeaves = [];
           for i=1:numel(tList)
               if isempty(tList(i).children)
                   %This task is a leaf
                   allLeaves = horzcat(allLeaves,tList(i));
               else
                   %Task has children. Call this function on the children
                   allLeaves = horzcat(allLeaves,leaves(tList(i).children));
               end
           end
       end
       
       function v=isSibling(tList,t)
           %Which of the tasks in the list are siblings of the task t?
           v = arrayfun(@(k) ~isempty(k.parent) && isequal(k.parent,t.parent),tList);
       end
              
       function profile(t,isOn)
           t.profiling = isOn;        
       end
       
       function updateCPUestimate(t,plotHist)
           nTasks = numel(t);
           for i=1:nTasks
               %t(i).estDur = prctile(t(i).profile_dur,75);
               t(i).estDur = max(t(i).profile_dur);
               if plotHist && ~isempty(strfind(t(i).name,'fft'))
                   n = ceil(sqrt(nTasks));
                   subplot(n,n,i);
                   histogram(t(i).profile_dur,0:20); title(horzcat(t(i).name,'; - prop = ', num2str(t(i).propOfTask))); drawnow;
               end     
           end
       end
   end
end