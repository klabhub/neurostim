%{
# Scan
->Session
scan_id : int
---
   -> [nullable] Equipment  
    -> AcquisitionSoftware  
    scan_notes='' : varchar(4095)         # free-notes
%}
classdef Scan < dj.Manual

end
