% (c) Anirudha Mahagaonkar, Norwegian Polar Institute, 2021
% anirudha.mahagaonkar@npolar.no

function brightness_temp = l8_brightness_temp(filename)
% Function to calculate the brightness temperature of the landsat8
% scene using K1 and K2 constants from Metadata. 

% The function will read the file and the metadata
% First, the function converts TIR DN values to TOA Radiance
% Next, the function calculates pixel by pixel brightness temperature 
% Brightness temperature is in degree Celcuis 

% filename: Path to the file/folder of the scene
    disp('Loading Band number 10.');

    tirs = double(imread([filename, '_B10.TIF']));
    
    metafilename=strcat(filename,"_MTL.txt");
    metacmd=strcat("meta=l8_meta_parser('",metafilename,"');");
    eval(metacmd);
    
    k1 = meta.TIRS_THERMAL_CONSTANTS.K1_CONSTANT_BAND_10;
    k2 = meta.TIRS_THERMAL_CONSTANTS.K2_CONSTANT_BAND_10;
    
    mult = meta.RADIOMETRIC_RESCALING.RADIANCE_MULT_BAND_10;
    add = meta.RADIOMETRIC_RESCALING.RADIANCE_ADD_BAND_10;
    
    tirs_toa_rad = add + (mult .* tirs);
    tirs_toa_rad(tirs_toa_rad == add) = NaN;
    
    brightness_temp = (k2 ./ log((k1 ./ tirs_toa_rad) + 1));
end