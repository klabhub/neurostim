%{
#  Method, package, analysis suite used for processing of calcium imaging data (e.g. Suite2p, CaImAn, etc.)
processing_method: char(8)
---
processing_method_desc: varchar(1000)  
%}
classdef ProcessingMethod < dj.Lookup
end