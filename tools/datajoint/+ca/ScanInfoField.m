%{
# field-specific scan information
 -> ScanInfo
        field_idx         : int
        ---
        px_height         : smallint  # height in pixels
        px_width          : smallint  # width in pixels
        um_height=null    : float     # height in microns
        um_width=null     : float     # width in microns
        field_x=null      : float     # (um) center of field in the motor coordinate system
        field_y=null      : float     # (um) center of field in the motor coordinate system
        field_z=null      : float     # (um) relative depth of field
        delay_image=null  : longblob  # (ms) delay between the start of the scan and pixels in this field
        roi=null          : int       # the scanning roi (as recorded in the acquisition software) containing this field - only relevant to mesoscale scans       
%}

classdef ScanInfoField < dj.Part
end
