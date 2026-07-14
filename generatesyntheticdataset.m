function dataset = generatesyntheticdataset(num_samples, output_path, output_size, config)
    % Generate synthetic EIT measurements and tissue maps for training.

    if nargin < 1 || isempty(num_samples)
        num_samples = 2000;
    end

    if nargin < 2 || isempty(output_path)
        output_path = 'syntheticeitdataset.mat';
    end

    if nargin < 3 || isempty(output_size)
        output_size = 24;
    end

    if nargin < 4 || isempty(config)
        config = struct();
    end

    total_timer = tic;

    config = apply_dataset_config_defaults(config);
    params = default_params(output_size, config);
    pre = precompute_geometry(params);

    feature_length = size(params.drive_pairs, 1) * params.num_electrodes * 2;
    features = zeros(num_samples, feature_length);
    targets = zeros(params.output_size, params.output_size, num_samples, 'uint8');
    conductivity_maps = zeros(size(pre.X, 1), size(pre.X, 2), num_samples, 'single');

    for sample_idx = 1:num_samples
        regions = sample_regions(params);
        [sigma, classes] = rasterize_regions(regions, params, pre.X, pre.Y, pre.inside_mask);

        conductivity_maps(:, :, sample_idx) = single(sigma);
        features(sample_idx, :) = batch_voltage_features(sigma, params, pre);
        targets(:, :, sample_idx) = uint8(downsample_classes(classes, params.output_size, params, pre.X, pre.Y, pre.inside_mask));
    end

    dataset = struct();
    dataset.features = features;
    dataset.targets = targets;
    dataset.conductivity_maps = conductivity_maps;
    dataset.class_names = {'healthy', 'benign', 'malignant'};
    dataset.params = params;
    dataset.metadata = build_dataset_metadata(num_samples, feature_length, params, toc(total_timer));

    save(output_path, '-struct', 'dataset', '-v7.3');
    fprintf('Saved %d samples to %s\n', num_samples, output_path);
end

function params = default_params(output_size, config)
    params = struct();
    params.phantom_radius = 35.0;
    params.dx = 4.0;
    params.current_uA = 100.0;
    params.num_electrodes = config.num_electrodes;
    params.drive_pattern = config.drive_pattern;
    params.drive_pairs = default_drive_pairs(config.num_electrodes, config.drive_pattern);
    params.output_size = output_size;
    params.conductivity.healthy = 0.04;
    params.conductivity.benign = 0.08;
    params.conductivity.malignant = 0.16;
    params.benign_count_range = config.benign_count_range;
    params.malignant_count_range = config.malignant_count_range;
end

function metadata = build_dataset_metadata(num_samples, feature_length, params, generation_seconds)
    metadata = struct();
    metadata.num_samples = num_samples;
    metadata.feature_length = feature_length;
    metadata.output_size = params.output_size;
    metadata.phantom_radius_mm = params.phantom_radius;
    metadata.num_electrodes = params.num_electrodes;
    metadata.drive_pattern = params.drive_pattern;
    metadata.drive_pair_count = size(params.drive_pairs, 1);
    metadata.benign_count_range = params.benign_count_range;
    metadata.malignant_count_range = params.malignant_count_range;
    metadata.forward_solve_count = num_samples * size(params.drive_pairs, 1);
    metadata.generation_seconds = generation_seconds;
    metadata.seconds_per_sample = generation_seconds / max(num_samples, 1);
    metadata.created_at = datestr(now, 31);
end

function config = apply_dataset_config_defaults(config)
    if ~isfield(config, 'num_electrodes') || isempty(config.num_electrodes)
        config.num_electrodes = 8;
    end

    if ~isfield(config, 'benign_count_range') || isempty(config.benign_count_range)
        config.benign_count_range = [0, 2];
    end

    if ~isfield(config, 'malignant_count_range') || isempty(config.malignant_count_range)
        config.malignant_count_range = [0, 3];
    end

    if ~isfield(config, 'drive_pattern') || isempty(config.drive_pattern)
        config.drive_pattern = 'hybrid';
    end

    validate_count_range(config.benign_count_range, 'benign_count_range');
    validate_count_range(config.malignant_count_range, 'malignant_count_range');
    validate_drive_pattern(config.drive_pattern);

    if config.num_electrodes < 4 || mod(config.num_electrodes, 2) ~= 0
        error('generatesyntheticdataset:InvalidElectrodeCount', ...
            'num_electrodes must be an even integer greater than or equal to 4.');
    end
end

function drive_pairs = default_drive_pairs(num_electrodes, drive_pattern)
    drive_pattern = lower(string(drive_pattern));
    half_count = num_electrodes / 2;
    opposite_pairs = [(1:half_count)', (1:half_count)' + half_count];
    adjacent_pairs = [(1:num_electrodes)', [2:num_electrodes, 1]'];

    if drive_pattern == "opposite"
        drive_pairs = opposite_pairs;
    elseif drive_pattern == "adjacent"
        drive_pairs = adjacent_pairs;
    else
        drive_pairs = [adjacent_pairs; opposite_pairs];
    end
end

function validate_count_range(range_values, field_name)
    if ~isnumeric(range_values) || numel(range_values) ~= 2 || any(range_values < 0) || ...
            any(mod(range_values, 1) ~= 0) || range_values(1) > range_values(2)
        error('generatesyntheticdataset:InvalidCountRange', ...
            '%s must be a two-element nonnegative integer range [min max].', field_name);
    end
end

function validate_drive_pattern(drive_pattern)
    valid_patterns = {'opposite', 'adjacent', 'hybrid'};
    if ~ischar(drive_pattern) && ~isstring(drive_pattern)
        error('generatesyntheticdataset:InvalidDrivePattern', ...
            'drive_pattern must be ''opposite'', ''adjacent'', or ''hybrid''.');
    end

    if ~any(strcmpi(char(drive_pattern), valid_patterns))
        error('generatesyntheticdataset:InvalidDrivePattern', ...
            'drive_pattern must be ''opposite'', ''adjacent'', or ''hybrid''.');
    end
end

function pre = precompute_geometry(params)
    x = -params.phantom_radius:params.dx:params.phantom_radius;
    y = -params.phantom_radius:params.dx:params.phantom_radius;
    [X, Y] = meshgrid(x, y);
    inside_mask = X.^2 + Y.^2 <= params.phantom_radius^2;

    inside_linear = find(inside_mask);
    [inside_i, inside_j] = ind2sub(size(X), inside_linear);

    node_lookup = zeros(size(X));
    node_lookup(inside_linear) = 1:numel(inside_linear);

    electrode_angles = linspace(0, 2 * pi, params.num_electrodes + 1);
    electrode_angles(end) = [];
    electrode_positions = [
        params.phantom_radius * cos(electrode_angles(:)), ...
        params.phantom_radius * sin(electrode_angles(:))
    ];

    electrode_nodes = zeros(params.num_electrodes, 1);
    for electrode_idx = 1:params.num_electrodes
        dist2 = (X - electrode_positions(electrode_idx, 1)).^2 + ...
                (Y - electrode_positions(electrode_idx, 2)).^2;
        dist2(~inside_mask) = inf;
        [~, linear_idx] = min(dist2(:));
        [ii, jj] = ind2sub(size(X), linear_idx);
        electrode_nodes(electrode_idx) = node_lookup(ii, jj);
    end

    pre = struct();
    pre.X = X;
    pre.Y = Y;
    pre.x = x;
    pre.y = y;
    pre.inside_mask = inside_mask;
    pre.inside_linear = inside_linear;
    pre.inside_i = inside_i;
    pre.inside_j = inside_j;
    pre.node_lookup = node_lookup;
    pre.electrode_positions = electrode_positions;
    pre.electrode_nodes = electrode_nodes;
    pre.num_nodes = numel(inside_linear);
end

function regions = sample_regions(params)
    max_center_radius = params.phantom_radius - 5.0;

    benign_count = randi(params.benign_count_range);
    malignant_count = randi(params.malignant_count_range);

    regions = struct('class_id', {}, 'cx', {}, 'cy', {}, 'radius', {});

    for region_idx = 1:benign_count
        regions(end + 1) = random_region(1, [5.0, 11.0], max_center_radius); %#ok<AGROW>
    end

    for region_idx = 1:malignant_count
        regions(end + 1) = random_region(2, [5.0, 10.0], max_center_radius); %#ok<AGROW>
    end

    function region = random_region(class_id, radius_range, center_limit)
        radius = radius_range(1) + rand() * (radius_range(2) - radius_range(1));
        angle = 2 * pi * rand();
        radial_distance = rand() * max(center_limit - radius, 1.0);
        region = struct();
        region.class_id = class_id;
        region.cx = radial_distance * cos(angle);
        region.cy = radial_distance * sin(angle);
        region.radius = radius;
    end
end

function [sigma, classes] = rasterize_regions(regions, params, X, Y, inside_mask)
    sigma = params.conductivity.healthy * ones(size(X));
    classes = zeros(size(X));

    for region_idx = 1:numel(regions)
        region = regions(region_idx);
        region_mask = (X - region.cx).^2 + (Y - region.cy).^2 <= region.radius.^2;
        region_mask = region_mask & inside_mask;

        if region.class_id == 1
            sigma(region_mask) = params.conductivity.benign;
            classes(region_mask) = 1;
        else
            sigma(region_mask) = params.conductivity.malignant;
            classes(region_mask) = 2;
        end
    end
end

function feature_vector = batch_voltage_features(sigma, params, pre)
    A = build_system_matrix(sigma, pre);
    current = params.current_uA * 1e-6;
    feature_vector = zeros(1, size(params.drive_pairs, 1) * params.num_electrodes * 2);
    cursor = 1;

    for pair_idx = 1:size(params.drive_pairs, 1)
        rhs = zeros(pre.num_nodes, 1);
        source_node = pre.electrode_nodes(params.drive_pairs(pair_idx, 1));
        sink_node = pre.electrode_nodes(params.drive_pairs(pair_idx, 2));

        rhs(source_node) = current;
        rhs(sink_node) = -current;
        rhs(1) = 0;

        u = A \ rhs;
        electrode_values = u(pre.electrode_nodes);
        electrode_values = electrode_values - mean(electrode_values);
        adjacent_diffs = electrode_values([2:end 1]) - electrode_values;

        feature_vector(cursor:cursor + params.num_electrodes - 1) = electrode_values;
        cursor = cursor + params.num_electrodes;
        feature_vector(cursor:cursor + params.num_electrodes - 1) = adjacent_diffs;
        cursor = cursor + params.num_electrodes;
    end
end

function A = build_system_matrix(sigma, pre)
    max_entries = pre.num_nodes * 5;
    rows = zeros(max_entries, 1);
    cols = zeros(max_entries, 1);
    vals = zeros(max_entries, 1);
    cursor = 1;

    for node_idx = 1:pre.num_nodes
        i = pre.inside_i(node_idx);
        j = pre.inside_j(node_idx);
        center_weight = 0.0;

        neighbors = [
            i, j - 1;
            i, j + 1;
            i - 1, j;
            i + 1, j
        ];

        for neighbor_idx = 1:size(neighbors, 1)
            ni = neighbors(neighbor_idx, 1);
            nj = neighbors(neighbor_idx, 2);

            if ni < 1 || ni > size(pre.X, 1) || nj < 1 || nj > size(pre.X, 2)
                continue;
            end

            if ~pre.inside_mask(ni, nj)
                continue;
            end

            neighbor_node = pre.node_lookup(ni, nj);
            weight = 0.5 * (sigma(i, j) + sigma(ni, nj));

            rows(cursor) = node_idx;
            cols(cursor) = neighbor_node;
            vals(cursor) = weight;
            cursor = cursor + 1;

            center_weight = center_weight + weight;
        end

        rows(cursor) = node_idx;
        cols(cursor) = node_idx;
        vals(cursor) = -max(center_weight, eps);
        cursor = cursor + 1;
    end

    rows = rows(1:cursor - 1);
    cols = cols(1:cursor - 1);
    vals = vals(1:cursor - 1);

    A = sparse(rows, cols, vals, pre.num_nodes, pre.num_nodes);
    A(1, :) = 0;
    A(1, 1) = 1;
end

function output_map = downsample_classes(classes, output_size, params, X, Y, inside_mask)
    xs = linspace(-params.phantom_radius, params.phantom_radius, output_size);
    ys = linspace(-params.phantom_radius, params.phantom_radius, output_size);
    output_map = zeros(output_size, output_size);

    for row_idx = 1:output_size
        for col_idx = 1:output_size
            dist2 = (X - xs(col_idx)).^2 + (Y - ys(row_idx)).^2;
            dist2(~inside_mask) = inf;
            [~, linear_idx] = min(dist2(:));
            output_map(row_idx, col_idx) = classes(linear_idx);
        end
    end
end
