%{
# Summary images for each field and channel after corrections
        -> master
        -> scan.ScanInfo.Field
        ---
        ref_image               : longblob  # image used as alignment template
        average_image           : longblob  # mean of registered frames
        correlation_image=null  : longblob  # correlation map (computed during cell detection)
        max_proj_image=null     : longblob  # max of registered frames
%}
classdef Summary < dj.Part
    methods (Access=public)
        function make(self, key)
            %         method, imaging_dataset = get_loader_result(key, Curation)
            %
            %         field_keys, _ = (scan.ScanInfo.Field & key).fetch('KEY', 'field_z', order_by='field_z')
            %
            %         if method == 'suite2p':
            %             suite2p_dataset = imaging_dataset
            %
            %             motion_correct_channel = suite2p_dataset.planes[0].alignment_channel
            %
            %             # ---- iterate through all s2p plane outputs ----
            %             rigid_correction, nonrigid_correction, nonrigid_blocks = {}, {}, {}
            %             summary_images = []
            %             for idx, (plane, s2p) in enumerate(suite2p_dataset.planes.items()):
            %                 # -- rigid motion correction --
            %                 if idx == 0:
            %                     rigid_correction = {
            %                         **key,
            %                         'y_shifts': s2p.ops['yoff'],
            %                         'x_shifts': s2p.ops['xoff'],
            %                         'z_shifts': np.full_like(s2p.ops['xoff'], 0),
            %                         'y_std': np.nanstd(s2p.ops['yoff']),
            %                         'x_std': np.nanstd(s2p.ops['xoff']),
            %                         'z_std': np.nan,
            %                         'outlier_frames': s2p.ops['badframes']}
            %                 else:
            %                     rigid_correction['y_shifts'] = np.vstack(
            %                         [rigid_correction['y_shifts'], s2p.ops['yoff']])
            %                     rigid_correction['y_std'] = np.nanstd(
            %                         rigid_correction['y_shifts'].flatten())
            %                     rigid_correction['x_shifts'] = np.vstack(
            %                         [rigid_correction['x_shifts'], s2p.ops['xoff']])
            %                     rigid_correction['x_std'] = np.nanstd(
            %                         rigid_correction['x_shifts'].flatten())
            %                     rigid_correction['outlier_frames'] = np.logical_or(
            %                         rigid_correction['outlier_frames'], s2p.ops['badframes'])
            %                 # -- non-rigid motion correction --
            %                 if s2p.ops['nonrigid']:
            %                     if idx == 0:
            %                         nonrigid_correction = {
            %                             **key,
            %                             'block_height': s2p.ops['block_size'][0],
            %                             'block_width': s2p.ops['block_size'][1],
            %                             'block_depth': 1,
            %                             'block_count_y': s2p.ops['nblocks'][0],
            %                             'block_count_x': s2p.ops['nblocks'][1],
            %                             'block_count_z': len(suite2p_dataset.planes),
            %                             'outlier_frames': s2p.ops['badframes']}
            %                     else:
            %                         nonrigid_correction['outlier_frames'] = np.logical_or(
            %                             nonrigid_correction['outlier_frames'], s2p.ops['badframes'])
            %                     for b_id, (b_y, b_x, bshift_y, bshift_x) in enumerate(
            %                             zip(s2p.ops['xblock'], s2p.ops['yblock'],
            %                                 s2p.ops['yoff1'].T, s2p.ops['xoff1'].T)):
            %                         if b_id in nonrigid_blocks:
            %                             nonrigid_blocks[b_id]['y_shifts'] = np.vstack(
            %                                 [nonrigid_blocks[b_id]['y_shifts'], bshift_y])
            %                             nonrigid_blocks[b_id]['y_std'] = np.nanstd(
            %                                 nonrigid_blocks[b_id]['y_shifts'].flatten())
            %                             nonrigid_blocks[b_id]['x_shifts'] = np.vstack(
            %                                 [nonrigid_blocks[b_id]['x_shifts'], bshift_x])
            %                             nonrigid_blocks[b_id]['x_std'] = np.nanstd(
            %                                 nonrigid_blocks[b_id]['x_shifts'].flatten())
            %                         else:
            %                             nonrigid_blocks[b_id] = {
            %                                 **key, 'block_id': b_id,
            %                                 'block_y': b_y, 'block_x': b_x,
            %                                 'block_z': np.full_like(b_x, plane),
            %                                 'y_shifts': bshift_y, 'x_shifts': bshift_x,
            %                                 'z_shifts': np.full((len(suite2p_dataset.planes),
            %                                                      len(bshift_x)), 0),
            %                                 'y_std': np.nanstd(bshift_y), 'x_std': np.nanstd(bshift_x),
            %                                 'z_std': np.nan}
            %
            %                 # -- summary images --
            %                 motion_correction_key = (scan.ScanInfo.Field * Curation
            %                                          & key & field_keys[plane]).fetch1('KEY')
            %                 summary_images.append({**motion_correction_key,
            %                                        'ref_image': s2p.ref_image,
            %                                        'average_image': s2p.mean_image,
            %                                        'correlation_image': s2p.correlation_map,
            %                                        'max_proj_image': s2p.max_proj_image})
            %
            %             self.insert1({**key, 'motion_correct_channel': motion_correct_channel})
            %             if rigid_correction:
            %                 self.RigidMotionCorrection.insert1(rigid_correction)
            %             if nonrigid_correction:
            %                 self.NonRigidMotionCorrection.insert1(nonrigid_correction)
            %                 self.Block.insert(nonrigid_blocks.values())
            %             self.Summary.insert(summary_images)
            %         elif method == 'caiman':
            %             caiman_dataset = imaging_dataset
            %
            %             self.insert1({**key, 'motion_correct_channel': caiman_dataset.alignment_channel})
            %
            %             is3D = caiman_dataset.params.motion['is3D']
            %             if not caiman_dataset.params.motion['pw_rigid']:
            %                 # -- rigid motion correction --
            %                 rigid_correction = {
            %                     **key,
            %                     'x_shifts': caiman_dataset.motion_correction['shifts_rig'][:, 0],
            %                     'y_shifts': caiman_dataset.motion_correction['shifts_rig'][:, 1],
            %                     'z_shifts': (caiman_dataset.motion_correction['shifts_rig'][:, 2]
            %                                  if is3D
            %                                  else np.full_like(
            %                         caiman_dataset.motion_correction['shifts_rig'][:, 0], 0)),
            %                     'x_std': np.nanstd(caiman_dataset.motion_correction['shifts_rig'][:, 0]),
            %                     'y_std': np.nanstd(caiman_dataset.motion_correction['shifts_rig'][:, 1]),
            %                     'z_std': (np.nanstd(caiman_dataset.motion_correction['shifts_rig'][:, 2])
            %                               if is3D
            %                               else np.nan),
            %                     'outlier_frames': None}
            %
            %                 self.RigidMotionCorrection.insert1(rigid_correction)
            %             else:
            %                 # -- non-rigid motion correction --
            %                 nonrigid_correction = {
            %                     **key,
            %                     'block_height': (caiman_dataset.params.motion['strides'][0]
            %                                      + caiman_dataset.params.motion['overlaps'][0]),
            %                     'block_width': (caiman_dataset.params.motion['strides'][1]
            %                                     + caiman_dataset.params.motion['overlaps'][1]),
            %                     'block_depth': (caiman_dataset.params.motion['strides'][2]
            %                                     + caiman_dataset.params.motion['overlaps'][2]
            %                                     if is3D else 1),
            %                     'block_count_x': len(
            %                         set(caiman_dataset.motion_correction['coord_shifts_els'][:, 0])),
            %                     'block_count_y': len(
            %                         set(caiman_dataset.motion_correction['coord_shifts_els'][:, 2])),
            %                     'block_count_z': (len(
            %                         set(caiman_dataset.motion_correction['coord_shifts_els'][:, 4]))
            %                                       if is3D else 1),
            %                     'outlier_frames': None}
            %
            %                 nonrigid_blocks = []
            %                 for b_id in range(len(caiman_dataset.motion_correction['x_shifts_els'][0, :])):
            %                     nonrigid_blocks.append(
            %                         {**key, 'block_id': b_id,
            %                          'block_x': np.arange(*caiman_dataset.motion_correction[
            %                                                    'coord_shifts_els'][b_id, 0:2]),
            %                          'block_y': np.arange(*caiman_dataset.motion_correction[
            %                                                    'coord_shifts_els'][b_id, 2:4]),
            %                          'block_z': (np.arange(*caiman_dataset.motion_correction[
            %                                                     'coord_shifts_els'][b_id, 4:6])
            %                                      if is3D
            %                                      else np.full_like(
            %                              np.arange(*caiman_dataset.motion_correction[
            %                                             'coord_shifts_els'][b_id, 0:2]), 0)),
            %                          'x_shifts': caiman_dataset.motion_correction[
            %                                          'x_shifts_els'][:, b_id],
            %                          'y_shifts': caiman_dataset.motion_correction[
            %                                          'y_shifts_els'][:, b_id],
            %                          'z_shifts': (caiman_dataset.motion_correction[
            %                                           'z_shifts_els'][:, b_id]
            %                                       if is3D
            %                                       else np.full_like(
            %                              caiman_dataset.motion_correction['x_shifts_els'][:, b_id], 0)),
            %                          'x_std': np.nanstd(caiman_dataset.motion_correction[
            %                                                 'x_shifts_els'][:, b_id]),
            %                          'y_std': np.nanstd(caiman_dataset.motion_correction[
            %                                                 'y_shifts_els'][:, b_id]),
            %                          'z_std': (np.nanstd(caiman_dataset.motion_correction[
            %                                                  'z_shifts_els'][:, b_id])
            %                                    if is3D
            %                                    else np.nan)})
            %
            %                 self.NonRigidMotionCorrection.insert1(nonrigid_correction)
            %                 self.Block.insert(nonrigid_blocks)
            %
            %             # -- summary images --
            %             summary_images = [
            %                 {**key, **fkey, 'ref_image': ref_image,
            %                  'average_image': ave_img,
            %                  'correlation_image': corr_img,
            %                  'max_proj_image': max_img}
            %                 for fkey, ref_image, ave_img, corr_img, max_img in zip(
            %                     field_keys,
            %                     caiman_dataset.motion_correction['reference_image'].transpose(2, 0, 1)
            %                     if is3D else caiman_dataset.motion_correction[
            %                         'reference_image'][...][np.newaxis, ...],
            %                     caiman_dataset.motion_correction['average_image'].transpose(2, 0, 1)
            %                     if is3D else caiman_dataset.motion_correction[
            %                         'average_image'][...][np.newaxis, ...],
            %                     caiman_dataset.motion_correction['correlation_image'].transpose(2, 0, 1)
            %                     if is3D else caiman_dataset.motion_correction[
            %                         'correlation_image'][...][np.newaxis, ...],
            %                     caiman_dataset.motion_correction['max_image'].transpose(2, 0, 1)
            %                     if is3D else caiman_dataset.motion_correction[
            %                         'max_image'][...][np.newaxis, ...])]
            %             self.Summary.insert(summary_images)
            %         else:
            %             raise NotImplementedError('Unknown/unimplemented method: {}'.format(method))
        end
    end
end

