% (c) Anirudha Mahagaonkar, Norwegian Polar Institute, 2021
% anirudha.mahagaonkar@npolar.no

function lake_depths = l8_calculate_depth(pan, red, water_bodies_filled, filled_pixels)

%%% Function to calculate depths of water pixels identified though
%%% 'L8_preprocess and depths' script. This will be called by the mentioned
%%% script automatically. Pixel wise depth is estimated.  

e1 = strel('disk',1); % to dilate lake mask by 1 pixel
e2 = strel('disk',2); % to dilate lake mask by 2 pixels
g_red = 0.7507; %0.8; % value from Pope and others (2016) 0.8
% g_pan = 0.3817; %0.36; % value from Pope and others (2016) 0.36
rinf_red = 0.0;
% rinf_pan = 0.0;

[water_bodies_labelled, total_lakes] = bwlabel(water_bodies_filled,8);

lake_depths = zeros(size(red));

for lake_number = 1:total_lakes
    disp(['Processing lake ', num2str(lake_number), ' of total ', num2str(total_lakes), ' lakes']);
    
%     tmpref_pan = pan; % tmpref is equal to values of pan band 
    tmpref_red = red; % tmpref is equal to values of red band 
    
    % Select a specific lake, and create a mask 
    selected_lake_mask = zeros(size(red));                                  % creates lake mask with size as above 
    selected_lake_mask(water_bodies_labelled == lake_number) = 2;           % One lake is selected and marked with value 2
    % selected_lake_mask(filled_pixels == 1) = 0;                           % Remove the filled pixels
%     num_selected_lake_pixels = sum(sum(selected_lake_mask))/2;
        
    % Dilate lake mask by one & two rings of pixels to find bare-ice albedo 
    lake_mask_dil_1 = imdilate(selected_lake_mask,e1);                      % Dilate by 1 pixel
    lake_mask_dil_2 = imdilate(selected_lake_mask,e2);                      % Dilate by 2 pixels
    lake_edge = lake_mask_dil_2 - lake_mask_dil_1;                          % d2 - d1 will give edge edge pixels 
%     edgepix_pan = (tmpref_pan(lake_edge == 2));                             % Retain only reflectance values of edge pixels
    edgepix_red = (tmpref_red(lake_edge == 2));                             % Retain only reflectance values of edge pixels 
    
    % Calculate the reflectance of edge pixels
%     Ad_pan = nansum(nansum(edgepix_pan))/sum(sum(~isnan(edgepix_pan)));     % take the mean of these values (ignore NaNs) 
    Ad_red = nansum(nansum(edgepix_red))/sum(sum(~isnan(edgepix_red)));     % take the mean of these values (ignore NaNs)  
    
    % Mask reflectance arrays - retain Selected lake pixels only 
    % FIRST: Remove the filled pixels = they might not get the correct
    % value for depth.
    selected_lake_mask(filled_pixels == 1) = 0;                             % Remove the filled pixels
%     tmpref_pan(selected_lake_mask == 0) = NaN; 
    tmpref_red(selected_lake_mask == 0) = NaN;  
    
    % Calculate Depths for the selected lake pixels
%     depth_pan = (log(Ad_pan - rinf_pan) - log(tmpref_pan - rinf_pan)) / (g_pan);    
    depth_red = (log(Ad_red - rinf_red) - log(tmpref_red - rinf_red)) / (g_red);   
    
    depth_red(depth_red<0) = 0;
%     depth_pan(depth_pan<0) = 0;
    
    % add the two depth values together and take the average of them 
    depth_red(selected_lake_mask == 0) = 0;                                 % if lake mask value = 0, then tmpdepth = 0
%     depth_pan(selected_lake_mask == 0) = 0;
%     avg_depth = (depth_red + depth_pan) ./ 2;

    
    % Calculate mean lake depth for the whole lake and use this depth value
    % for the filled pixels. 
%     mean_lake_depth = nansum(nansum(avg_depth))/num_selected_lake_pixels;
 
    % add calculated depths to lake depth array
    lake_depths = lake_depths + depth_red;
        
    %% Interpolate/Calculate depth of filled holes
    
    holes_mask = filled_pixels;                                             % Filled Pixels: Filled = 1, Others = 0. 
    selected_lake_mask = zeros(size(red));                                  % Resetting the selected lake mask to include filled pixels.
    selected_lake_mask(water_bodies_labelled == lake_number) = 2;           % Select lake and mark with value 2
    
    temp = holes_mask + selected_lake_mask;                                 % Adding selected lake(2) and filled pixels(1)
    
    % Find where there are holes in the specific lake
    selected_hole_pixels = zeros(size(filled_pixels));                      % Initialize an array for the hole pixels
    selected_hole_pixels(temp == 3) = 1;                                    % Hole pixels = 1
    
    % Inward interpolation of lake depth for filled pixels 
    mask = selected_hole_pixels;
    mask = imdilate(mask, e1);
    lake_depths = regionfill(lake_depths, mask);
    
%     % assign the specific lake holes the mean lake value
%     selected_hole_pixels(selected_hole_pixels == 1) = mean_lake_depth;
%     % add the new hole depths to the overall depth mask
%     lake_depths = lake_depths + selected_hole_pixels;
    
    
end

disp(['Lake depth estimation complete for all the ',num2str(total_lakes),' lakes']);
end
