classdef splittaskstimulus < neurostim.stimuli.splittasksacrossframes
    %Demo of using splittasksacrossframes to distribute tasks across frames
    %Costly tasks that take more than one frame to complete cause frame
    %drops, but can be split into sub-tasks to reduce or, if possible,
    %eliminate drops. Here, we don't actually use the computation results
    %for anything visually, just compile some lists of random numbers, but
    %it illustrates how to assign tasks, and deal with the sub-tasks that
    %they break into during optimisation.
    %If the calculations can be done within the o.bigFrameInterval, you
    %should see frame drops reduce across trials and ideally, disappear
    %entirely.
    properties
        myVar1
        myVar2
        myVar3
        myVar4
        myVar5
        displayMsg;
    end
    
    methods (Access = public)
        function o = splittaskstimulus(c,name)
            o = o@neurostim.stimuli.splittasksacrossframes(c,name);
        end
        
        function setupTasks(o)
            
            %Create a list of the tasks to be done, of different computational load
            %Here, we don't actually do anything other call rand with
            %different number of samples. Large ones will cause frame drops
            %if not split.
            tsks = {@rand1,@rand2,@rand3,@rand4};
            nSamples = [100,2000000,10000,100000];
            o.learningRate = o.learningRate/20;
            
            %Make the array of tasks, indicating that they are splittable across frames
            splittable = 1;
            for i=1:numel(tsks)
                o.addTask(func2str(tsks{i}),tsks{i},splittable);
                
                %Indices into the columns. This will get split up during optimization.
                o.tasks(i).data = 1:nSamples(i);
            end
        end
        
        
        function beforeBigFrame(o)
            %Update the variables used to show stimuli on the screen (e.g.
            %textures, dot positions, etc.)
            o.displayMsg = horzcat('Big frame #', num2str(o.bigFrame));
        end
        
        function draw(o)
            %Show the current image.
            Screen('glLoadIdentity', o.window);
            o.cic.drawFormattedText(o.displayMsg)
        end
        
        function rand1(o,t)
            ix = t.data;
            %Random luminance values
            o.myVar1(ix) = rand(1,numel(ix)); %myVar gets constructed in sections (e.g. subimages), of changing size as CPU load is distributed over frames
        end
        
        function rand2(o,t)
            ix = t.data;
            %Random luminance values
            o.myVar2(ix) = rand(1,numel(ix));%myVar gets constructed in sections (e.g. subimages), of changing size as CPU load is distributed over frames
        end
        
        function rand3(o,t)
            ix = t.data;
            %Random luminance values
            o.myVar3(ix) = rand(1,numel(ix));%myVar gets constructed in sections (e.g. subimages), of changing size as CPU load is distributed over frames
        end
        
        function rand4(o,t)
            ix = t.data;
            %Random luminance values
            o.myVar4(ix) = rand(1,numel(ix));%myVar gets constructed in sections (e.g. subimages), of changing size as CPU load is distributed over frames
        end
        
    end % public methods
    
    
    
end % classdef