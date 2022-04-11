%{
# Fluoresence Trace 
        ->Fluorescence
        -> Segmentation.Mask
        -> scan.Channel.proj(fluo_channel='channel')  # the channel that this trace comes from         
        ---
        fluorescence                : longblob  # fluorescence trace associated with this mask
        neuropil_fluorescence=null  : longblob  # Neuropil fluorescence trace
%}
classdef FluoresenceTrace < dj.Part
    methods
        function make(self, key)
            %         method, imaging_dataset = get_loader_result(key, Curation)
            %
            %         if method == 'suite2p':
            %             suite2p_dataset = imaging_dataset
            %
            %             # ---- iterate through all s2p plane outputs ----
            %             fluo_traces, fluo_chn2_traces = [], []
            %             for s2p in suite2p_dataset.planes.values():
            %                 mask_count = len(fluo_traces)  # increment mask id from all "plane"
            %                 for mask_idx, (f, fneu) in enumerate(zip(s2p.F, s2p.Fneu)):
            %                     fluo_traces.append({
            %                         **key, 'mask': mask_idx + mask_count,
            %                         'fluo_channel': 0,
            %                         'fluorescence': f,
            %                         'neuropil_fluorescence': fneu})
            %                 if len(s2p.F_chan2):
            %                     mask_chn2_count = len(fluo_chn2_traces) # increment mask id from all planes
            %                     for mask_idx, (f2, fneu2) in enumerate(zip(s2p.F_chan2, s2p.Fneu_chan2)):
            %                         fluo_chn2_traces.append({
            %                             **key, 'mask': mask_idx + mask_chn2_count,
            %                             'fluo_channel': 1,
            %                             'fluorescence': f2,
            %                             'neuropil_fluorescence': fneu2})
            %
            %             self.insert1(key)
            %             self.Trace.insert(fluo_traces + fluo_chn2_traces)
            %         elif method == 'caiman':
            %             caiman_dataset = imaging_dataset
            %
            %             # infer "segmentation_channel" - from params if available, else from caiman loader
            %             params = (ProcessingParamSet * ProcessingTask & key).fetch1('params')
            %             segmentation_channel = params.get('segmentation_channel',
            %                                               caiman_dataset.segmentation_channel)
            %
            %             fluo_traces = []
            %             for mask in caiman_dataset.masks:
            %                 fluo_traces.append({**key, 'mask': mask['mask_id'],
            %                                     'fluo_channel': segmentation_channel,
            %                                     'fluorescence': mask['inferred_trace']})
            %
            %             self.insert1(key)
            %             self.Trace.insert(fluo_traces)
            %
            %         else:
            %             raise NotImplementedError('Unknown/unimplemented method: {}'.format(method))
        end
    end
end
