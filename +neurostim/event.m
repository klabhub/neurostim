classdef event
    
    properties (Constant)
        ENTRY =1;  % An ENTRY event (to allow a state to define some setup routine)
        EXIT = 2;  % An EXIT event (to allow a state to define a teardown routine);
        REGULAR = 3; % REGULAR events send updates of current variables (e.e. eye pos, key press)
        NOOP =4; % An event that shoudl not be sent out but ignored.
        AFTERTRIAL=5; %An event that signals the trial ended.
        eventTypes = {'ENTRY','EXIT','REGULAR','NOOP','AFTERTRIAL'};
    end
    properties
        % These are the properties used by current behaviors. Adding new
        % properties may be necessary when adding new behaviors and should
        % not affect existing properties.
        % Each behavior derived class can use these properties for its own
        % purposes so the meaning of each is not necessarily the same.
        % (For instance X is horizontal eye position for the eyeMovement
        % behaviors, but mouse position for the base behavior class.)
        type@double;
        X@double;
        Y@double;
        Z@double;
        key@char;
        keyNr@double;
        correct@logical;
        isBitHigh@logical;
    end
    properties (Dependent)
        isEntry@logical;
        isRegular@logical;
        isExit@logical;
        isNoop@logical;
        isAfterTrial@logical;
    end
    methods
        function v = get.isEntry(o)
            v = o.type==neurostim.event.ENTRY;
        end
        function v = get.isExit(o)
            v = o.type==neurostim.event.EXIT;
        end
        
        function v = get.isRegular(o)
            v = o.type==neurostim.event.REGULAR;
        end
        
        function v = get.isNoop(o)
            v = o.type==neurostim.event.NOOP;
        end
        
        function v = get.isAfterTrial(o)
            v = o.type==neurostim.event.AFTERTRIAL;
        end
        
    end
    
    methods
        function o = event(tp)
            if nargin <1
                tp = neurostim.event.REGULAR;
            end
            o.type = tp;
        end
        
        function disp(o)
            disp([o.eventTypes{o.type} '-event'])
            builtin('display',o)
        end
        
    end
end

