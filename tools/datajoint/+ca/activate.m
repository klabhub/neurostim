% Set up the Calcium Imaging pipeline. Based on the Python Element Calcium Imaging     
% https://github.com/datajoint/element-calcium-imaging
% but (partially) ported to Matlab.
% 



% Put default values in lookup tables (matching Python base code; not all
% methods have been ported!)
insert(ca.CellCompartment,struct('cell_compartment',{'axon', 'soma', 'bouton'}));
insert(ca.MaskType,struct('mask_type',{'soma', 'axon', 'dendrite', 'neuropil', 'artefact', 'unknown'}));
insert(ca.MaskClassificationMethod,struct('mask_classification_method',{'suite2p_default_classifier','caiman_default_classifier'}));
insert(ca.ActivityExtractionMethod,struct('extraction_method',{'suite2p_deconvolution', 'caiman_deconvolution', 'caiman_dff'}));
insert(ca.ProcessingMethod,struct('processing_method',{'suite2p','caiman'},'processing_method_desc',{'suite 2p analysis suite','caiman analysis suite'}));
insert(ca.Channel,struct('channel',num2cell(0:5)));
insert(ca.AcquisitionSoftware,struct('acq_software',{'ScanImage', 'Scanbox', 'NIS'}));
