%{
# Activity Trace
        -> Activity
        -> Fluorescence.Trace
        ---
        activity_trace: longblob  # 
%}
classdef ActivityTrace < dj.Part
    properties (Dependent)
        key_source
    end
    methods
        function v= get.key_source(o)
            %
            %         suite2p_key_source = (Fluorescence * ActivityExtractionMethod
            %                               * ProcessingParamSet.proj('processing_method')
            %                               & 'processing_method = "suite2p"'
            %                               & 'extraction_method LIKE "suite2p%"')
            %         caiman_key_source = (Fluorescence * ActivityExtractionMethod
            %                              * ProcessingParamSet.proj('processing_method')
            %                              & 'processing_method = "caiman"'
            %                              & 'extraction_method LIKE "caiman%"')
            %         return suite2p_key_source.proj() + caiman_key_source.proj()
        end
    end
    methods
        function make(self, key)
            %         method, imaging_dataset = get_loader_result(key, Curation)
            %
            %         if method == 'suite2p':
            %             if key['extraction_method'] == 'suite2p_deconvolution':
            %                 suite2p_dataset = imaging_dataset
            %                 # ---- iterate through all s2p plane outputs ----
            %                 spikes = []
            %                 for s2p in suite2p_dataset.planes.values():
            %                     mask_count = len(spikes)  # increment mask id from all "plane"
            %                     for mask_idx, spks in enumerate(s2p.spks):
            %                         spikes.append({**key, 'mask': mask_idx + mask_count,
            %                                        'fluo_channel': 0,
            %                                        'activity_trace': spks})
            %
            %                 self.insert1(key)
            %                 self.Trace.insert(spikes)
            %         elif method == 'caiman':
            %             caiman_dataset = imaging_dataset
            %
            %             if key['extraction_method'] in ('caiman_deconvolution', 'caiman_dff'):
            %                 attr_mapper = {'caiman_deconvolution': 'spikes', 'caiman_dff': 'dff'}
            %
            %                 # infer "segmentation_channel" - from params if available, else from caiman loader
            %                 params = (ProcessingParamSet * ProcessingTask & key).fetch1('params')
            %                 segmentation_channel = params.get('segmentation_channel',
            %                                                   caiman_dataset.segmentation_channel)
            %
            %                 activities = []
            %                 for mask in caiman_dataset.masks:
            %                     activities.append({
            %                         **key, 'mask': mask['mask_id'],
            %                         'fluo_channel': segmentation_channel,
            %                         'activity_trace': mask[attr_mapper[key['extraction_method']]]})
            %                 self.insert1(key)
            %                 self.Trace.insert(activities)
            %         else:
            %             raise NotImplementedError('Unknown/unimplemented method: {}'.format(method))
        end
    end
end
