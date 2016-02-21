classdef feedback < neurostim.plugin
    % Generic feedback class for behavioral response.
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
        afterFrameQueue=[]; % Feedback items that need to be checked/delivered after evey frame
        afterTrialQueue=[]; % Feedback items that need to be checked/delivered after evey trial
    end
    
    properties (SetObservable, AbortSet)

    end
    
    properties (Access=protected)

    end
    
    properties (Dependent)

    end
    
    methods

    end
    
    methods (Access=public)
        function o=feedback(name)
            o=o@neurostim.plugin(name);
            o.listenToEvent({'BEFORETRIAL', 'AFTERTRIAL','AFTERFRAME'});
            o.addProperty('nItems',0);
        end  
    end
    
    methods (Access=public)
        function add(o,varargin)                            
            %Add a new feedback item
            p=inputParser;                             
            p.KeepUnmatched = true;
            p.addParameter('when','AFTERTRIAL', @(x) any(strcmpi(x,{'AFTERTRIAL','AFTERFRAME'})));  %When feedback should be delivered (must be a CIC event)
            p.addParameter('duration',Inf);                                                        %Duration of feedback
            p.addParameter('criterion',false);                                                       %Boolean function that determines whether the feedback will be delivered
            p.addParameter('delivered',false);
            p.parse(varargin{:});            
            
            
            %Which item number is this?
            o.nItems = o.nItems + 1;
            
            %Store the details as dynamic property item1when, item2duration etc. 
            thisItem = ['item' num2str(o.nItems)];
            flds = fieldnames(p.Results);
            for i=1:numel(flds)
                o.addProperty([thisItem lower(flds{i})],p.Results.(flds{i}));
                
            end
            if strcmpi(p.Results.when,'AFTERTRIAL')
                o.afterTrialQueue = [o.afterTrialQueue o.nItems];
            elseif strcmpi(p.Results.when,'AFTERFRAME')
                o.afterFrameQueue = [o.afterFrameQueue o.nItems];
            else
                error('??');  % Implement another queue
            end
                        
            chAdd(o,p.Unmatched);
        end
        
        function beforeTrial(o,c,evt)
            %Reset flags for all tiems.
            for i=1:o.nItems
                o.(['item' num2str(i) 'delivered'])= false;
            end
        end
          
        function deliverPending(o,queue)
            %Which feedback items should be delivered now?            
            for i=queue                
                %Check that it's the right time, that it hasn't already been delivered, and that the criterion is satisfied.                
                delivered =o.(['item' num2str(i) 'delivered']);
                criterion = o.(['item' num2str(i) 'criterion']);
                deliverNow = ~delivered & criterion;                
                %Do it!
                if deliverNow
                    o.deliver(i);
                    o.(['item' num2str(i) 'delivered']) = true;
                end
            end
        end
        
        function afterFrame(o,c,evt)
            %Check if any feedback items should be delivered
            deliverPending(o,o.afterFrameQueue);
        end

        function afterTrial(o,c,evt)
            %Check if any feedback items should be delivered
            deliverPending(o,o.afterTrialQueue);
        end
    end
    
    
    methods (Access=protected)        
        function chAdd(o,varargin)
            % to be overloaded in child classes. The user calls o.add(), which adds
            % a new feedback item in the parent class. Remaining arguments are passed
            % to chAdd() in the child class.
        end
        
        function deliver(o,item)
            %Function that should be overloaded in derived class to deliver the feedback.
            %e.g. deliver juice via the MCC plugin, or present a feedback screen to a subject.
            disp(['Feedback delivered for ' num2str(item.duration) 'ms'])
        end
    end
        
end
