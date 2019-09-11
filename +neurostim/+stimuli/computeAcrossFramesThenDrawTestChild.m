classdef computeAcrossFramesThenDrawTestChild < neurostim.stimuli.computeAcrossFramesThenDraw
    
    properties
        nRandsToGenerate = 1024^2;
        data=[];
        nPerIter;
    end
    
    methods (Access = public)
        function o = computeAcrossFramesThenDrawTestChild(c,name)
            
            o = o@neurostim.stimuli.computeAcrossFramesThenDraw(c,name);
            
            
            o.maxComputeTime = 0.5;
            o.bigFrameRate = 15;
        end
        
        function beforeTrial(o)
            
            %First, do some housekeeping upstairs
            beforeTrial@neurostim.stimuli.computeAcrossFramesThenDraw(o);
            
            
            %Tell the parent class which ones we need to do on the fly
            o.addBeforeFrameTask({@subJob,@subJob});
            
            %o.data = zeros(1,o.nRandsToGenerate);
            o.nPerIter = o.nRandsToGenerate/32;
            
        end
        
        function done = subJob(o)
            
            startInd = (o.curTaskIter-1)*o.nPerIter+1;
            stopInd = startInd + o.nPerIter-1;
            tic(o);
            b = rand(1,o.nPerIter);
            toc(o);
            o.debugData(o.cic.trial,o.frame+1) = o.ticTocTime(end);
            done = stopInd==o.nRandsToGenerate;     
            
        end
        
        function beforeBigFrame(o)
            % pause(2/1000);
        end
    end
end % classdef