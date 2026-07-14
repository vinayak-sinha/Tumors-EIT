function summary = analyzetissuemap(class_map, class_names, phantom_radius_mm)
    % Summarize separate benign/malignant regions from a predicted class map.

    if nargin < 2 || isempty(class_names)
        class_names = {'healthy', 'benign', 'malignant'};
    end

    if nargin < 3 || isempty(phantom_radius_mm)
        phantom_radius_mm = 35.0;
    end

    map_size = size(class_map, 1);
    pixel_spacing_mm = (2 * phantom_radius_mm) / max(map_size - 1, 1);
    x_coords = linspace(-phantom_radius_mm, phantom_radius_mm, size(class_map, 2));
    y_coords = linspace(-phantom_radius_mm, phantom_radius_mm, size(class_map, 1));

    regions = struct( ...
        'class_id', {}, ...
        'class_name', {}, ...
        'pixel_count', {}, ...
        'estimated_area_mm2', {}, ...
        'centroid_row', {}, ...
        'centroid_col', {}, ...
        'centroid_x_mm', {}, ...
        'centroid_y_mm', {}, ...
        'bbox_row_min', {}, ...
        'bbox_row_max', {}, ...
        'bbox_col_min', {}, ...
        'bbox_col_max', {});

    for class_id = 1:2
        class_regions = collectregionsforclass(class_map, class_id, class_names{class_id + 1}, x_coords, y_coords, pixel_spacing_mm);
        if isempty(regions)
            regions = class_regions;
        else
            regions = [regions, class_regions]; %#ok<AGROW>
        end
    end

    summary = struct();
    summary.region_count = numel(regions);
    summary.benign_count = sum([regions.class_id] == 1);
    summary.malignant_count = sum([regions.class_id] == 2);
    summary.regions = regions;
end

function regions = collectregionsforclass(class_map, class_id, class_name, x_coords, y_coords, pixel_spacing_mm)
    mask = class_map == class_id;
    visited = false(size(mask));
    regions = struct( ...
        'class_id', {}, ...
        'class_name', {}, ...
        'pixel_count', {}, ...
        'estimated_area_mm2', {}, ...
        'centroid_row', {}, ...
        'centroid_col', {}, ...
        'centroid_x_mm', {}, ...
        'centroid_y_mm', {}, ...
        'bbox_row_min', {}, ...
        'bbox_row_max', {}, ...
        'bbox_col_min', {}, ...
        'bbox_col_max', {});

    for row_idx = 1:size(mask, 1)
        for col_idx = 1:size(mask, 2)
            if ~mask(row_idx, col_idx) || visited(row_idx, col_idx)
                continue;
            end

            component_pixels = floodfill(mask, visited, row_idx, col_idx);
            visited(component_pixels(:, 1) + (component_pixels(:, 2) - 1) * size(mask, 1)) = true;

            centroid_row = mean(component_pixels(:, 1));
            centroid_col = mean(component_pixels(:, 2));
            bbox_row_min = min(component_pixels(:, 1));
            bbox_row_max = max(component_pixels(:, 1));
            bbox_col_min = min(component_pixels(:, 2));
            bbox_col_max = max(component_pixels(:, 2));

            region = struct();
            region.class_id = class_id;
            region.class_name = class_name;
            region.pixel_count = size(component_pixels, 1);
            region.estimated_area_mm2 = region.pixel_count * (pixel_spacing_mm ^ 2);
            region.centroid_row = centroid_row;
            region.centroid_col = centroid_col;
            region.centroid_x_mm = interp1(1:numel(x_coords), x_coords, centroid_col);
            region.centroid_y_mm = interp1(1:numel(y_coords), y_coords, centroid_row);
            region.bbox_row_min = bbox_row_min;
            region.bbox_row_max = bbox_row_max;
            region.bbox_col_min = bbox_col_min;
            region.bbox_col_max = bbox_col_max;
            regions(end + 1) = region; %#ok<AGROW>
        end
    end
end

function component_pixels = floodfill(mask, visited, start_row, start_col)
    max_pixels = numel(mask);
    queue = zeros(max_pixels, 2);
    component_pixels = zeros(max_pixels, 2);

    head = 1;
    tail = 1;
    count = 0;

    queue(tail, :) = [start_row, start_col];
    tail = tail + 1;

    local_visited = visited;
    local_visited(start_row, start_col) = true;

    while head < tail
        row_idx = queue(head, 1);
        col_idx = queue(head, 2);
        head = head + 1;

        count = count + 1;
        component_pixels(count, :) = [row_idx, col_idx];

        for row_offset = -1:1
            for col_offset = -1:1
                if row_offset == 0 && col_offset == 0
                    continue;
                end

                next_row = row_idx + row_offset;
                next_col = col_idx + col_offset;

                if next_row < 1 || next_row > size(mask, 1) || next_col < 1 || next_col > size(mask, 2)
                    continue;
                end

                if ~mask(next_row, next_col) || local_visited(next_row, next_col)
                    continue;
                end

                local_visited(next_row, next_col) = true;
                queue(tail, :) = [next_row, next_col];
                tail = tail + 1;
            end
        end
    end

    component_pixels = component_pixels(1:count, :);
end
