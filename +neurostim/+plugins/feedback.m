classdef feedback < neurostim.plugin
    %All feedback items of a particular type (e.g. sound) are handled by a single
    %instance of a (derived) feedback plugin.
    %One or more feedback items are added, and the delivery of each is linked to one or
    %more behaviors (or any other plugin) through an arbitrary "criterion" function (that should return TRUE/FALSE).
    %The delivery time is either immediate ('afterFrame') or at the end of
    %the trial ('afterTrial')
    %
    %e.g.   r = plugins.liquid('juice');
    %       r.add('duration',100,'when','afterFrame','criterion','@(fixation1) fixation1.success');
    %       r.add('duration',500,'when','afterTrial','criterion','@(fixation2) fixation2.success');
    %
    %See add() for usage details.
    
    properties

    end
    
    properties (SetObservable, AbortSet)

    end
    
    properties (Access=protected)

    end
    
    properties (Dependent)
        nItems % Number of feedback items added. 
    end
    
    methods
        function v= get.nItems(o)
            v= numel(o.item);
        end
    end
    
    methods (Access=public)
        function o=feedback(name)
            o=o@neurostim.plugin(name);
            o.listenToEvent({'BEFORETRIAL', 'AFTERTRIAL','AFTERFRAME'});
            o.addProperty('item',struct('criterion',[],'duration',[],'when',[]));
        end  
    end
    
    methods (Access=public)
        function childArgs = add(o,varargin)
         
            %Partition the parent class' arguments from those that should be returned for the derived class to deal with
            isForParent = cellfun(@(arg) any(strcmpi(arg,{'when','duration','criterion'})),varargin);
            theseInds = sort([find(isForParent),find(isForParent)+1]);
            args = varargin(theseInds);
            varargin(theseInds) = [];
            childArgs = varargin;
                   
            %Add a new feedback item
            p=inputParser;                             
            p.addParameter('when','AFTERTRIAL', @(x) any(strcmpi(x,{'AFTERTRIAL','AFTERFRAME'})));  %When feedback should be delivered (must be a CIC event)
            p.addParameter('duration',1000);                                                        %Duration of feedback
            p.addParameter('criterion',true);                                                       %Boolean function that determines whether the feedback will be delivered
            p.parse(args{:});
            p = p.Results;
            
            %Which item number is this?
            if isempty(o.item.duration)
                ind = 1;
            else
                ind = o.nItems + 1;
            end
            
            %Store the details
            o.item(ind).duration = p.duration;
            o.item(ind).when = upper(p.when);
            o.item(ind).criterion = p.criterion;
            o.item(ind).delivered = false;
            
            %Check that the criterion returns a logical
            if ~islogical(o.item(ind).criterion)
                error('Feedback criterion is returning something other than a logical');
            end
        end
        
        function beforeTrial(o,c,evt)
            %Reset flags for all tiems.
            for i=1:o.nItems
                o.item(i).delivered = false;
            end
        end
          
        function deliverPending(o,type)
            
            %Which feedback items should be delivered now?
                %Check that it's the right time, that it hasn't already been delivered, and that the criterion is satisfied.
            toDeliver = find(arrayfun(@(thisItem) strcmp(type,thisItem.when) & ~thisItem.delivered & thisItem.criterion,o.item));
            
            %If any, do it.
            for i=1:numel(toDeliver)
                o.deliver(o.item(toDeliver(i)));
                o.item(toDeliver(i)).delivered=true;
            end
        end
        
        function afterFrame(o,c,evt)
            %Check if any feedback items should be delivered
            deliverPending(o,'AFTERFRAME');
        end

        function afterTrial(o,c,evt)
            deliverPending(o,'AFTERTRIAL');
        end
    end
    
    
    methods (Access=protected)
        
        function deliver(o,item)
            %Function that should be overloaded in derived class to deliver the feedback.
            %e.g. deliver juice via the MCC plugin, or present a feedback screen to a subject.
            disp(['Feedback delivered for ' num2str(item.duration) 'ms'])
        end
    end
        
end
