%{
# A mask produced by segmentation.
        -> Segmentation
        mask            : smallint
        ---
        -> scan.Channel.proj(segmentation_channel='channel')  # channel used for segmentation
        mask_npix       : int       # number of pixels in ROIs
        mask_center_x   : int       # center x coordinate in pixel
        mask_center_y   : int       # center y coordinate in pixel
        mask_center_z   : int       # center z coordinate in pixel
        mask_xpix       : longblob  # x coordinates in pixels
        mask_ypix       : longblob  # y coordinates in pixels      
        mask_zpix       : longblob  # z coordinates in pixels        
        mask_weights    : longblob  # weights of the mask at the indices above
%}
classdef SegmentationMask < dj.Part
    methods (Access=public)
        function make(self, key)

            %         method, imaging_dataset = get_loader_result(key, Curation)
            %
            %         if method == 'suite2p':
            %             suite2p_dataset = imaging_dataset
            %
            %             # ---- iterate through all s2p plane outputs ----
            %             masks, cells = [], []
            %             for plane, s2p in suite2p_dataset.planes.items():
            %                 mask_count = len(masks)  # increment mask id from all "plane"
            %                 for mask_idx, (is_cell, cell_prob, mask_stat) in enumerate(zip(
            %                         s2p.iscell, s2p.cell_prob, s2p.stat)):
            %                     masks.append({
            %                         **key, 'mask': mask_idx + mask_count,
            %                         'segmentation_channel': s2p.segmentation_channel,
            %                         'mask_npix': mask_stat['npix'],
            %                         'mask_center_x':  mask_stat['med'][1],
            %                         'mask_center_y':  mask_stat['med'][0],
            %                         'mask_center_z': mask_stat.get('iplane', plane),
            %                         'mask_xpix':  mask_stat['xpix'],
            %                         'mask_ypix':  mask_stat['ypix'],
            %                         'mask_zpix': np.full(mask_stat['npix'],
            %                                              mask_stat.get('iplane', plane)),
            %                         'mask_weights':  mask_stat['lam']})
            %                     if is_cell:
            %                         cells.append({
            %                             **key,
            %                             'mask_classification_method': 'suite2p_default_classifier',
            %                             'mask': mask_idx + mask_count,
            %                             'mask_type': 'soma', 'confidence': cell_prob})
            %
            %             self.insert1(key)
            %             self.Mask.insert(masks, ignore_extra_fields=True)
            %
            %             if cells:
            %                 MaskClassification.insert1({
            %                     **key,
            %                     'mask_classification_method': 'suite2p_default_classifier'},
            %                     allow_direct_insert=True)
            %                 MaskClassification.MaskType.insert(cells,
            %                                                    ignore_extra_fields=True,
            %                                                    allow_direct_insert=True)
            %         elif method == 'caiman':
            %             caiman_dataset = imaging_dataset
            %
            %             # infer "segmentation_channel" - from params if available, else from caiman loader
            %             params = (ProcessingParamSet * ProcessingTask & key).fetch1('params')
            %             segmentation_channel = params.get('segmentation_channel',
            %                                               caiman_dataset.segmentation_channel)
            %
            %             masks, cells = [], []
            %             for mask in caiman_dataset.masks:
            %                 masks.append({**key,
            %                               'segmentation_channel': segmentation_channel,
            %                               'mask': mask['mask_id'],
            %                               'mask_npix': mask['mask_npix'],
            %                               'mask_center_x': mask['mask_center_x'],
            %                               'mask_center_y': mask['mask_center_y'],
            %                               'mask_center_z': mask['mask_center_z'],
            %                               'mask_xpix': mask['mask_xpix'],
            %                               'mask_ypix': mask['mask_ypix'],
            %                               'mask_zpix': mask['mask_zpix'],
            %                               'mask_weights': mask['mask_weights']})
            %                 if caiman_dataset.cnmf.estimates.idx_components is not None:
            %                     if mask['mask_id'] in caiman_dataset.cnmf.estimates.idx_components:
            %                         cells.append({
            %                             **key,
            %                             'mask_classification_method': 'caiman_default_classifier',
            %                             'mask': mask['mask_id'], 'mask_type': 'soma'})
            %
            %             self.insert1(key)
            %             self.Mask.insert(masks, ignore_extra_fields=True)
            %
            %             if cells:
            %                 MaskClassification.insert1({
            %                     **key,
            %                     'mask_classification_method': 'caiman_default_classifier'},
            %                     allow_direct_insert=True)
            %                 MaskClassification.MaskType.insert(cells,
            %                                                    ignore_extra_fields=True,
            %                                                    allow_direct_insert=True)
            %         else:
            %             raise NotImplementedError(f'Unknown/unimplemented method: {method}')
        end
    end
end