%{
# general data about the reso/meso scans from header
-->Scan
---
 nfields              : tinyint   # number of fields
 nchannels            : tinyint   # number of channels
 ndepths              : int       # Number of scanning depths (planes)
 nframes              : int       # number of recorded frames
 nrois                : tinyint   # number of ROIs (see scanimage's multi ROI imaging)
 x=null               : float     # (um) ScanImage's 0 point in the motor coordinate system
 y=null               : float     # (um) ScanImage's 0 point in the motor coordinate system
 z=null               : float     # (um) ScanImage's 0 point in the motor coordinate system
 fps                  : float     # (Hz) frames per second - Volumetric Scan Rate 
 bidirectional        : boolean   # true = bidirectional scanning
 usecs_per_line=null  : float     # microseconds per scan line
 fill_fraction=null   : float     # raster scan temporal fill fraction (see scanimage)
 scan_datetime=null   : datetime  # datetime of the scan
 scan_duration=null   : float     # (seconds) duration of the scan
%}
classdef  ScanInfo < dj.Imported


    methods (Static)
        function make(self, key)
            acq_software = fetch1(Scan & key,'acq_software');

            switch upper(acq_software)
                case 'SCANBOX'
                    %import sbxreader
                    % Read the scan
                    %                     scan_filepaths = get_scan_box_files(key)
                    %                     sbx_meta = sbxreader.sbx_get_metadata(scan_filepaths[0])
                    %                     sbx_matinfo = sbxreader.sbx_get_info(scan_filepaths[0])
                    %                     is_multiROI = bool(sbx_matinfo.mesoscope.enabled)  % currently not handling "multiROI" ingestion

                    if is_multiROI
                        error('Loading routine not implemented for Scanbox multiROI scan mode');
                    end

                    % Extract and Insert in ScanInfo
                    siKey = key;

                    %             [x_zero, y_zero, z_zero] = sbx_meta('stage_pos')
                    %
                    %                 nfields=sbx_meta('num_fields')
                    %                               if is_multiROI else sbx_meta['num_planes'],
                    %                               nchannels=sbx_meta['num_channels'],
                    %                               nframes=sbx_meta['num_frames'],
                    %                               ndepths=sbx_meta['num_planes'],
                    %                               x=x_zero,
                    %                               y=y_zero,
                    %                               z=z_zero,
                    %                               fps=sbx_meta['frame_rate'],
                    %                               bidirectional=sbx_meta == 'bidirectional',
                    %                               nrois=sbx_meta['num_rois'] if is_multiROI else 0,
                    %                               scan_duration=(sbx_meta['num_frames'] / sbx_meta['frame_rate'])))
                    %
                    insert1(self,siKey)


                    %# Insert Field(s)
                    fKey = key;
                    %px_width, px_height = sbx_meta['frame_size']
                    %                 for plane_idx in range(sbx_meta['num_planes'])])
                    %                      field_idx=plane_idx,
                    %                                         px_height=px_height,
                    %                                         px_width=px_width,
                    %                                         um_height=px_height * sbx_meta['um_per_pixel_y']
                    %                                         if sbx_meta['um_per_pixel_y'] else None,
                    %                                         um_width=px_width * sbx_meta['um_per_pixel_x']
                    %                                         if sbx_meta['um_per_pixel_x'] else None,
                    %                                         field_x=x_zero,
                    %                                         field_y=y_zero,
                    %                                         field_z=z_zero + sbx_meta['etl_pos'][plane_idx])
                    %

                    insert(self.Field,fKey);


                otherwise
                    error('Loading routine not implemented for %s \n',acquisition_software)
            end

            %# Insert file(s)
            %             root_dir = find_root_directory(get_imaging_root_data_dir(),
            %             scan_filepaths[0])
            %
            %             scan_files = [pathlib.Path(f).relative_to(root_dir).as_posix()
            %                 for f in scan_filepaths]
            %                 self.ScanFile.insert([{**key, 'file_path': f} for f in scan_files])
            %                 end

        end

        function   v =   estimate_scan_duration(scan_obj)
            % Calculates scan duration for Nikon images
            %                     ti = scan_obj.frame_metadata(0).channels[0].time.absoluteJulianDayNumber  % Initial frame's JD.
            %                     tf = scan_obj.frame_metadata(scan_obj.shape[0]-1).channels[0].time.absoluteJulianDayNumber  % Final frame's JD.
            %                     fps = 1000 / scan_obj.experiment[0].parameters.periods[0].periodDiff.avg  % Frame per second
            %                     v = (tf - ti) * 86400 + 1 / fps


        end
    end
end