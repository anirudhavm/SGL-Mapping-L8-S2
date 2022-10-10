% (c) Anirudha Mahagaonkar, Norwegian Polar Institute, 2021
% anirudha.mahagaonkar@npolar.no

clc; close; clear; 

%%% STEP 1

%%% Automated script to process raw (downloaded) Landsat8 scenes to
%%% generate water masks and estimate depths for the lakes identified. the
%%% outputs are lake mask (water_bodies_filled_30m) and lake depth 
%%% (lake_depths_30m) .tif and .mat files.  

%% Parameters BEFORE Running

% Do you want to reprocess the scene and reproduce the results/outputs?
% Existing files/outputs will be overwritten. 
% 1: Yes, reprocess. 0: No, use existing. Say 1 for first time 
reprocess = 1;

%% %% HARD CODE PARAMETERS - USER INPUT

% Directory where the codes are located
code_dir = '/home/anirudha/Desktop/test_lakedepth/algo_avm';
addpath(code_dir);

% Directory of unzipped Landsat-8 files
in_dir = '/home/anirudha/Desktop/MN/data/lan8/';
processing_year = '2014-2015/';                                 % Year of interest (in-case of time series)
area_tag = 'MN';

%% Load Landsat-8 data 

% Initiate
processing_dir = [in_dir, processing_year];
mkdir ([in_dir, 'outputs']);
out_dir = [in_dir, 'outputs']; 

file_list = filenames_extract(processing_dir,'LC08'); 
n_scenes = size(file_list,1);

pixel_size = 30;            % In Meters
pixel_area = pixel_size^2;  % In Sq. Meters

total_lake_area = zeros(size(n_scenes));
total_lake_volume = zeros(size(n_scenes));
cloud_cover_percentage = zeros(size(n_scenes));
scene_ids = strings(size(n_scenes));

%% Folder by folder processing
for folder = 1:n_scenes
    %% Initialize
    disp(['Processing scene number ',num2str(folder),' of ',num2str(n_scenes)]);
    filename = strtrim(file_list(folder,:));
    scene_ids(folder) = filename;                   % Save - Collective
    disp(['Date of Scene: ', filename(24:25),'-', filename(22:23),'-', filename(18:21)]); 
    cd([processing_dir, filename]);
    
    % Load all the required bands
    disp("Loading the required bands");
    blue = l8_dn2refl_perpix(filename, 2);          % load blue band 
    green = l8_dn2refl_perpix(filename, 3);         % load green band
    red = l8_dn2refl_perpix(filename, 4);           % load red band
    % nir = l8_dn2refl_perpix(filename, 5);         % load nir band
    swir = l8_dn2refl_perpix(filename, 6);          % load swir band
    pan = l8_dn2refl_perpix(filename, 8);           % load pan band
    tir_bt = l8_brightness_temp(filename);          % brightness temp using TIRS 
    % [max(blue, [], 'all'), min(blue, [], 'all')]
    
    % Resample all non 30m bands to 30m pixels
    size_30m = size(blue);
%     tir_bt = imresize(tir_bt, size_30m, 'bilinear');
    pan = imresize(pan, size_30m, 'bilinear');
    
    % Generate RGB Composite
    rgb = cat(3, red, green, blue);
    
    % Generate ratios
    TIRS_Blue = tir_bt ./ blue;
    % [max(TIRS_Blue, [], 'all'), min(TIRS_Blue, [], 'all')]
    NDWI = (blue - red) ./ (blue + red);
    % NDWI2 = (green - nir) ./ (green + nir);
    % [max(NDWI, [], 'all'), min(NDWI, [], 'all')]
    NDSI = (green - swir) ./ (green + swir);
    % [max(NDSI, [], 'all'), min(NDSI, [], 'all')]    
    
    %% Generating Masks 
    
    % Generate Cloud Mask
    disp('Generating Cloud mask');
    cloud_mask = zeros(size(blue));
    cloud_mask(swir > 0.1 & blue > 0.6 & blue < 0.95) = 1;
    cloud_mask(NDSI > 0.8) = 0;
    
    % Calculate Cloud Cover Percentage in the Scene
    cloud_pixels = find(cloud_mask == 1);
    scene_pixels = find(blue > 0);
    total_cloud_pixels = size(cloud_pixels);
    total_scene_pixels = size(scene_pixels);
    cloud_percent = 100 * (total_cloud_pixels / total_scene_pixels);            % Save
    cloud_cover_percentage(folder) = cloud_percent;                             % Save - Collective
    disp(['Clouds cover ', num2str(cloud_percent), '% of the total scene area.']);
    clear cloud_pixels scene_pixels total_cloud_pixels total_scene_pixels
    
    % Generate Rock and Sea Water Mask
    disp('Generating Rock mask');
    rock_mask = zeros(size(blue));
    rock_mask(TIRS_Blue >= 650 & red > 0) = 1;
    rock_mask(blue > 0.35) = 0;
    
    % Generate shadow mask
    disp('Generating Shadow mask');
    shadow_mask = zeros(size(blue));
    shadow_mask((blue - green) > 0.105 & (green - red) > 0.065) = 1;
    
    %% TESTING - REMOVAL OF DARK SHADOWS CAUSED DUE TO THICK CLOUDS
      
    b1 = (blue - green)./(blue + green);
    b2 = (green - red)./(green + red);
    b3 = (red - blue)./(red + blue);
    
    b1 = rescale(b1, 'InputMin', -1, 'InputMax', 1);
    b2 = rescale(b2, 'InputMin', -1, 'InputMax', 1);
    b3 = rescale(b3, 'InputMin', -1, 'InputMax', 1);
    b123 = cat(3, b1, b2, b3);
    
    test_cond = b1 > 0.50 & b1 < 0.80 & b2 > 0.50 & b2 < 0.85 & b3 < 0.3750;
%     test_cond = b1 > 0.50 & b1 < 0.80 & b2 > 0.50 & b2 < 0.80 & b3 < b2 & b3 < b1 & b2 > b1 ;
%     test_cond = b1 > 0.50 & b1 < 0.60 & b2 > 0.50 & b2 < 0.60 & b3 < b2 & b3 < b1 & ((b2 - b1) < 0.01);
    shadow_mask2 = shadow_mask(:,:);    
    shadow_mask2(test_cond == 0) = 0;
    
    %% RESUME - TESTING OVER - BELOW THIS IS NORMAL CODE
    
    % Generate Water Mask
    disp('Delineating water areas from the scene');
    water_mask = zeros(size(blue));
    water_mask(NDWI > 0.25 & shadow_mask2 == 1) = 1; 
    water_mask(rock_mask == 1) = 0;
    water_mask(cloud_mask == 1) = 0;
%     water_mask = standardizeMissing(water_mask, 0);           % Makes 0 as NaNs
    
    % Generate Total Mask 1 = Clouds; 2 = Rocks; 3 = Shadows
    disp('Generating a single mask of all excluded pixels');
    total_mask = zeros(size(blue));
    total_mask(cloud_mask == 1) = 1;                            % Clouds = 1
    total_mask(rock_mask == 1) = 2;                             % Rock and Seawater = 2
    total_mask(shadow_mask2 == 1 & water_mask == 0) = 3;        % Shadows = 3

    %% Fix/Correct and label water bodies
    
    disp('Fixing/correcting (filling of gaps) the water bodies');
    
    % Make a water body matrix
    connected_components = bwconncomp(water_mask, 8);                               % Identify objects that are connected to each other 
    numPx = regionprops(connected_components,'Area');                               % Find number of pixels in each of the CC object
    water_bodies_find = find([numPx.Area] > 2);                                     % find out (index) CC objects that are larger than 2 pixels
    water_bodies_stats = numPx(water_bodies_find);                                  % Selected pixels
    
    water_bodies = ismember(labelmatrix(connected_components),water_bodies_find);   % label CCs and filter using the 'find' indexes
    water_bodies = double(water_bodies);                                            % converts logical to a double array type to allow functioning
    water_bodies_filled = imfill(water_bodies,'holes');                             % Fill in the holes of each water body
    
    % Add the non-filled and filled matricies to create a mask of 'filled
    % pixels: Dry = 0, Filled =1, Always Wet =2. Get rid of always wet so we
    % have just those pixels that have been filled. This will be needed
    % for the depth calculations.
    
    filled_pixels = water_bodies + water_bodies_filled;     % Output: Dry = 0, Filled = 1, Always_wet = 2
    filled_pixels(filled_pixels == 2) = 0;                  % Filled = 1, Others = 0. 
    
    water_bodies(isnan(water_bodies)) = 0;                  % converts any NaNs in the mask to 0
    water_bodies_filled(isnan(water_bodies_filled)) = 0;    % converts any NaNs in the mask to 0
    filled_pixels(isnan(filled_pixels)) = 0;                % converts any NaNs in the mask to 0
    
    % Total Area covered by water pixels
    total_water_pixels = nansum(nansum(water_bodies_filled));
    total_area = total_water_pixels * pixel_area;          % Save
    total_lake_area(folder) = total_area;                  % Save - Collective
        
    %% Depth Calculation
    
    disp('Depth calculation of individual lakes');
    
    if reprocess == 1
        lake_depths = l8_calculate_depth(pan, red, water_bodies_filled, filled_pixels);
        lake_depths(lake_depths == 0) = NaN;
    elseif reprocess == 0
        outname = ['L8_', filename(1,24:25), filename(1,22:23), filename(1,18:21), '_', filename(1, 11:16)];
        load ([outname, '_lake_depths_30m.mat']);
    end    

    deepest_depth = max(max(lake_depths));              % Save

    % Total Volume covered by water pixels
    volume = lake_depths .* pixel_area;                 
    total_volume = nansum(nansum(volume));              % Save
    total_lake_volume(folder) = total_volume;           % Save - Collective
       
    %% Save Variables
    disp('Reading reference information - to be used to save GTiff files');
    [~, R] = geotiffread([filename, '_B2.TIF']);
    
    % Define the output file name (Prefix)
    outname = ['L8_', filename(1,24:25), filename(1,22:23), filename(1,18:21), '_', filename(1, 11:16)];
    
    % Variables - Cloud cover percentage, total lake area, total lake
    % volume and deepest lake depth
%     save([outname '_deepest_depth.mat'], 'deepest_depth');
%     save([outname '_total_volume.mat'], 'total_volume');
%     save([outname '_total_area.mat'], 'total_area');
    save([outname '_cloud_percent.mat'], 'cloud_percent');
    
    % Water Bodies - 1 water/0 Others
    disp('Saving water bodies mask');
    save([outname, '_water_bodies_filled_30m.mat'], 'water_bodies_filled', '-v7.3');
    geotiffwrite([outname, '_water_bodies_filled_30m.tif'], water_bodies_filled, R, 'CoordRefSysCode', 3031);
    
    % Lake Depth
    disp('Saving Lake depths');
    save([outname, '_lake_depths_30m.mat'], 'lake_depths', '-v7.3');
    geotiffwrite([outname, '_lake_depths_30m.tif'], lake_depths, R, 'CoordRefSysCode', 3031);
           
end 

disp(['Processing of ', num2str(n_scenes), ' scenes complete!']);
disp('Saving collective variables in Output folder');

% Saving common variables like lake area, lake volume and cloud cover
% arrays into a single .mat file for all the scenes from the folder.

cd(out_dir);
collective_outname = ['L8_', processing_year(1, 1:end-1), '_', area_tag];

% save([collective_outname, '_total_lake_area.mat'], 'total_lake_area');
% save([collective_outname, '_total_lake_volume.mat'], 'total_lake_volume');
save([collective_outname, '_cloud_cover_percentage.mat'], 'cloud_cover_percentage', 'scene_ids');

disp('Processing chain complete!');

cd(in_dir);