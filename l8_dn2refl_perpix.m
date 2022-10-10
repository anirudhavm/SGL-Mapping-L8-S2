%% (c) Neil Arnold, University of Cambridge 

function [reflectpp] = l8_dn2refl_perpix(filename,band)

    % l8_dn2refl_perpix Convert landsat 8 digital numbers to reflectance using per pixel solar angles
    %
    %   Uses formulae at:
    %       https://www.usgs.gov/land-resources/nli/landsat/using-usgs-landsat-level-1-data-product
    %   Requires the compiled solar angle calculators at: 
    %       https://www.usgs.gov/land-resources/nli/landsat/solar-illumination-and-sensor-viewing-angle-coefficient-files?qt-science_support_page_related_con=1#qt-science_support_page_related_con
    %   Requires the envi file reader at:
    %       https://uk.mathworks.com/matlabcentral/fileexchange/15629-envi-file-reader-updated-2-9-2010?s_tid=mwa_osa_a
    %
    % Usage:
    % Outputs:
    % rawdn = raw band DN
    % toa = band top-of-atmosphere reflectance
    % reflectpp = reflectance corrected with per-pixel solar angle
    % reflect = reflactance with image-centre solar angle
    % Inputs:
    % imfilename = image file (file name 'header')
    % band = image band required
    
    disp(['Loading Band number ', num2str(band), '.']);
    
    % Create pixel solar angles
    angfilename=strcat(filename,"_ANG.txt");
    pixcmd=strcat("/home/anirudha/l8_angles/l8_angles ",angfilename," BOTH 1 -f 0 -b ",num2str(band), " > /dev/null 2>&1"); % this must point to l8_angles
    system(pixcmd);
    %
    % Create pixel angle variables
    pixangfilename=strcat(filename,"_solar_B0",num2str(band),".img");
    solarcmd=strcat("solar=enviread('",pixangfilename,"');");
    eval(solarcmd);
    %
    % Get metadata
    metafilename=strcat(filename,"_MTL.txt");
    metacmd=strcat("meta=l8_meta_parser('",metafilename,"');");
    eval(metacmd);
    %
    switch band
        case 1
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_1;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_1;
        case 2
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_2;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_2;
        case 3
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_3;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_3;
        case 4
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_4;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_4;
        case 5
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_5;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_5;
        case 6
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_6;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_6;
        case 7
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_7;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_7;
        case 8
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_8;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_8;
        case 9
            band_mult=meta.RADIOMETRIC_RESCALING.REFLECTANCE_MULT_BAND_9;
            band_add=meta.RADIOMETRIC_RESCALING.REFLECTANCE_ADD_BAND_9;
        case 10
            band_mult=meta.RADIOMETRIC_RESCALING.RADIANCE_MULT_BAND_10;
            band_add=meta.RADIOMETRIC_RESCALING.RADIANCE_ADD_BAND_10;
    end
    
    % Load image
    bandfilename=strcat(filename,"_B",num2str(band),".TIF");
    readcmd=strcat("imdata=imread('",bandfilename,"');");
    eval(readcmd);
    rawdn=imdata;
    
    % TOA reflectance (no solar correction)
    toa=band_mult*double(rawdn)+band_add;
    toa(rawdn==0)=0;
    
    % Get solar zenith angle from metadata (USE THIS FOR ONE VALUE FOR THE
    % ENTIRE SCENE)
    solzen=90-meta.IMAGE_ATTRIBUTES.SUN_ELEVATION;
    
    % Calculate reflectance with solar correction (USE THIS FOR PIXEL BY
    % PIXEL VALUES OF THE SOLAR ZENITH ANGLE)
    reflectpp=toa./cosd(double(solar.z(:,:,2))/100); %Factor of 100 from angle file format
    % reflect=toa./cosd(solzen);
    
    reflectpp(reflectpp <= 0) = NaN;
    % reflect(reflect <= 0) = NaN;
    
    delete_cmd = "rm *sensor*";
    delete_cmd2 = "rm *solar*";
    system(delete_cmd);
    system(delete_cmd2);
end

