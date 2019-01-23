classdef webcam < neurostim.plugin
    % Webcam plugin
    % Jacob 2019-01-21
    
    properties (Access=private)
        cam@webcam=[];
        zoomboxidx@logical=[]; % index of zoom box (subset of frame that's stored
        zoomboxwid@double=[];
        zoomboxhei@double=[];
    end
    properties % (Access=hidden)
        frame@uint8=0; % Should have default values, otherwise behavior checking can fail.
        timestamp@double=NaN; % timestamp provided by "webcam.snapshot", store comparison with internal timestampe
    end
    methods
        function o = webcam(c)
            o = o@neurostim.plugin(c,'webcam');
            o.addProperty('name','');
            o.addProperty('res','');
            o.addProperty('zoombox',''); % leftx topy width height
            o.addProperty('opt',struct); % struct with additional options such as 'Brightness' or 'WhiteBalanceMode' which are nor available on all webcam
            o.addProperty('gray',false);
        end
        function beforeExperiment(o)
            connectedCams=webcamlist;
            if isempty(connectedCams)
                o.cic.error('STOPEXPERIMENT','No webcam found');
            end
            if isempty(o.name)
                o.cam = webcam(connectedCams{1});
            end
            if isempty(o.res)
                o.res=o.cam.Resolution; % store the default resolution of the connected cam in the resolution property
            else
                try
                    o.cam.Resolution=o.res; % will fail if o.res is not in o.cam.Resolution
                catch me
                    o.cic.error('STOPEXPERIMENT',me.message);
                end
            end
            if ~isempty(o.zoombox)
                R=regexp(o.cam.Resolution,'x','split');
                wid=str2double(R{1});
                hei=str2double(R{2});
                o.zoomboxidx=false(hei,wid,3);
                leftx=max(1,min(o.zoombox(1),wid));
                topy=max(1,min(o.zoombox(2),hei));
                rightx=max(1,min(o.zoombox(1)+o.zoombox(3),wid));
                bottomy=max(1,min(o.zoombox(2)+o.zoombox(4),wid));
                o.zoomboxidx(topy:bottomy,leftx:rightx,:)=true;
                o.zoomboxwid=rightx-leftx+1;
                o.zoomboxhei=bottomy-topy+1;
                if all(o.zoomboxidx)
                    o.zoomboxidx=[]; % no need to zoom if entire frame is inside box
                end
            end     
        end
        function afterFrame(o)
            [fr, o.timestamp] = snapshot(o.cam);
            if ~isempty(o.zoomboxidx)
                fr=reshape(fr(o.zoomboxidx),o.zoomboxhei,o.zoomboxwid,3);
            end
            if o.gray
                fr=uint8(round(mean(fr,3)));
            end
            o.frame=fr;
        end
        function afterExperiment(o)
            o.cam.delete;
        end
    end
end