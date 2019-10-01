classdef splittaskstimulus < neurostim.stimuli.computeAcrossFramesThenDraw
    
    properties        
        nSamples = [100,5000000,10000,3000000,100000];
        samples = [];        
    end
    
    methods (Access = public)
        function o = splittaskstimulus(c,name)
            
            o = o@neurostim.stimuli.computeAcrossFramesThenDraw(c,name);
            
        end
                
        function setupTasks(o)
            
            %Create a list of the tasks to be done to create the filtered image.
            tsks = {@rand1,@rand2,@rand3,@rand4,@rand5};
            
            %Make the array of tasks, indicating that they are splittable across frames
            splittable = 1;
            for i=1:numel(tsks)
                o.addTask(func2str(tsks{i}),tsks{i},splittable);

                %Indices into the columns. This will get split up during optimization.
                o.tasks(i).data = 1:o.nSamples(i);
            end
            
            m=[];
            o.setTaskPlan(m);
        end

        
        function beforeBigFrame(o)
            

        end
        
        function draw(o)

        end
        
        function rand1(o,t)
            ix = t.data;
            %Gaussian white noise.
            o.samples = rand(1,numel(ix));
        end
        
        function rand2(o,t)
            ix = t.data;
            %Gaussian white noise.
            o.samples = rand(1,numel(ix));
        end
        
        function rand3(o,t)
            ix = t.data;
            %Gaussian white noise.
            o.samples = rand(1,numel(ix));
        end
        
        function rand4(o,t)
            ix = t.data;
            %Gaussian white noise.
            o.samples = rand(1,numel(ix));
        end
        
        function rand5(o,t)
            ix = t.data;
            %Gaussian white noise.
            o.samples = rand(1,numel(ix));
        end
    end % public methods
    
    

end % classdef