classdef feedback < neurostim.plugin
    % Generic feedback class.
    %
    % All feedback items of a particular type (e.g. sound) are handled by
    % a single instance of a (derived) feedback plugin. One or more
    % feedback items are added, and the delivery of each is linked to one
    % or more behaviors (or any other plugin) through an arbitrary
    % "criterion" function (that must return TRUE/FALSE).
    %
    % The criterion function is evaluated either after every frame
    % ('afterFrame') or at the end of the trial ('afterTrial'), e.g.,
    %
    %   r = plugins.liquid('juice');
    %   r.add('duration',100,'when','afterFrame','criterion','@fixation1.success');
    %   r.add('duration',500,'when','afterTrial','criterion','@fixation2.success');
    %
    % See add() below for usage details.
    
    % Implementation notes.
    %
    % Feedback items are stored in a somewhat clumsy manner, using dynamic
    % properties with names that are constructed on the fly, e.g.,
    % o.item1duration, o.item2duration etc.
    %
    % The advantage of this is that each field is an independent property,
    % whose values are automtically logged (because they are plugin
    % properties). The disadvantage is that accessing the value requires
    % constructing the dynamic property name, which may be inefficient. 
    % 
    % An alternative would be to store item1 as a struct with fields
    % duration, when, criterion etc. This would only require construcing
    % one dynamic property name on the  fly (e.g., 'item1' , 'item2'). But
    % it has the disadvantage that PreGet events get triggered for all item
    % fields (e.g., criterion, which are likely to be functions) even when
    % only one is requested. 
    % 
    % Another alternative would be to use a vector of items (structs). This
    % is the cleanest solution code-wise, but gives up on automatic
    % logging. I tried this even with making this vector a autolog
    % property, but having nested elements (structs or vectors) as
    % propoerties creates problems for functions. (the parser would have to
    % find each element that is a function).
    
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
        function o=feedback(c,name)
            o=o@neurostim.plugin(c,name);
            
            o.addProperty('nItems',0,'validate',@isnumeric);         
        end  
    end
    
    methods (Access=public)
        function add(o,varargin)                            
            %Add a new feedback item
            p = inputParser;                             
            p.KeepUnmatched = true;
            p.addParameter('when','AFTERTRIAL', @(x) any(strcmpi(x,{'AFTERTRIAL','AFTERFRAME'})));  % When the criterion should be evaluated (and the fedback delivered) (must be a CIC event)
            p.addParameter('criterion',false);                                                      % Boolean function that determines whether the feedback will be delivered
            p.addParameter('repeat',false);                                                         %If false, will be delivered once only. If true, will deliver it whenever criterion is true
            p.parse(varargin{:});            
            
            
            %Which item number is this?
            o.nItems = o.nItems + 1;
            
            %Store the details as dynamic property item1when, item2duration etc. 
            thisItem = ['item' num2str(o.nItems)];
            flds = fieldnames(p.Results);
            for i=1:numel(flds)
                o.addProperty([thisItem lower(flds{i})],p.Results.(flds{i}));                
            end
            o.addProperty([thisItem 'delivered'],false);
            
            if strcmpi(p.Results.when,'AFTERTRIAL')
                o.afterTrialQueue = [o.afterTrialQueue o.nItems];
            elseif strcmpi(p.Results.when,'AFTERFRAME')
                o.afterFrameQueue = [o.afterFrameQueue o.nItems];
            else
                o.cic.error('STOPEXPERIMENT',['The ' p.Results.when ' feedback delivery time has not been implemented yet?']);                
            end
                        
            chAdd(o,p.Unmatched);
        end
        
        function beforeTrial(o)
            %Reset flags for all items.
            reset(o);
        end
        
        function reset(o)
            %Reset flags for all items.
            for i=1:o.nItems
                o.(['item' num2str(i) 'delivered']) = false;
            end
        end
        
        function deliverPending(o,queue)
            %Which feedback items should be delivered now?            
            for i=queue                
                %Check that it hasn't already been delivered
                if o.(['item' num2str(i) 'delivered'])
                  continue;
                end
                
                % ... and that the criterion is satisfied.
                if o.(['item' num2str(i) 'criterion'])
                    o.deliver(i);
                    o.(['item' num2str(i) 'delivered']) = true; %Logs delivery
                    if o.(['item' num2str(i) 'repeat'])
                        o.(['item' num2str(i) 'delivered']) = false; %Reset to allow repeat
                    end
                end
            end
        end
        
        function afterFrame(o)
            %Check if any feedback items should be delivered
            deliverPending(o,o.afterFrameQueue);
        end

        function afterTrial(o)
            %Check if any feedback items should be delivered
            deliverPending(o,o.afterTrialQueue);
            report(o);
        end
    end
    
    
    methods (Access=protected)        
        function chAdd(o,varargin) %#ok<INUSD>
            % to be overloaded in child classes. The user calls o.add(), which adds
            % a new feedback item in the parent class. Remaining arguments are passed
            % to chAdd() in the child class.
        end
        
        function deliver(o,item)
            %Function that should be overloaded in derived class to deliver the feedback.
            %e.g. deliver juice, or present a feedback screen to a subject.            
            o.writeToFeed('Feedback delivered for %d ms', o.(['item' num2str(item) 'duration']));
        end
        
        function report(o) %#ok<MANU>
            %Overload in child class. Called at the end of the trial to
            %provide some info to the GUI. e.g. number of rewards,
            %proportion correct etc.
        end
    end
        
end
