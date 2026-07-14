function metrics = traintissuemapper(num_samples, dataset_path, artifact_dir, config)
    % Train the tissue-mapping MLP on synthetic EIT data.

    if nargin < 1 || isempty(num_samples)
        num_samples = 2000;
    end

    if nargin < 2 || isempty(dataset_path)
        dataset_path = fullfile('artifacts', 'syntheticeitdataset.mat');
    end

    if nargin < 3 || isempty(artifact_dir)
        artifact_dir = 'artifacts';
    end

    if nargin < 4 || isempty(config)
        config = struct();
    end

    config = apply_training_config_defaults(config);

    desired_output_size = config.output_size;
    desired_num_electrodes = config.num_electrodes;
    desired_drive_pattern = char(config.drive_pattern);
    desired_malignant_count_range = config.malignant_count_range;
    execution_mode = lower(config.execution_mode);
    hidden_layer_sizes = config.hidden_layer_sizes;
    epochs = config.epochs;
    train_algorithm = config.train_algorithm;
    test_fraction = config.test_fraction;
    validation_fraction = config.validation_fraction;

    total_timer = tic;

    dataset_folder = fileparts(dataset_path);
    if ~isempty(dataset_folder)
        ensure_folder(dataset_folder);
    end
    ensure_folder(artifact_dir);

    dataset_timer = tic;
    dataset_generated_now = false;
    if isfile(dataset_path)
        dataset = load(dataset_path);
        existing_output_size = read_dataset_output_size(dataset);
        existing_sample_count = read_dataset_sample_count(dataset);
        existing_num_electrodes = read_dataset_num_electrodes(dataset);
        existing_drive_pattern = read_dataset_drive_pattern(dataset);
        existing_benign_count_range = read_dataset_count_range(dataset, 'benign_count_range', [0, 2]);
        existing_malignant_count_range = read_dataset_count_range(dataset, 'malignant_count_range', [0, 3]);
        if existing_output_size ~= desired_output_size || ...
                existing_sample_count ~= num_samples || ...
                existing_num_electrodes ~= desired_num_electrodes || ...
                ~strcmpi(existing_drive_pattern, desired_drive_pattern) || ...
                any(existing_benign_count_range ~= config.benign_count_range) || ...
                any(existing_malignant_count_range ~= desired_malignant_count_range)
            fprintf(['Existing dataset is %d samples at %d x %d with %d electrodes ', ...
                'using %s drive pairs, with benign range [%d %d] and malignant range [%d %d]; ', ...
                'regenerating %d samples at %d x %d with %d electrodes, %s drive pairs, ', ...
                'benign range [%d %d], and malignant range [%d %d].\n'], ...
                existing_sample_count, existing_output_size, existing_output_size, ...
                existing_num_electrodes, ...
                existing_drive_pattern, ...
                existing_benign_count_range(1), existing_benign_count_range(2), ...
                existing_malignant_count_range(1), existing_malignant_count_range(2), ...
                num_samples, desired_output_size, desired_output_size, ...
                desired_num_electrodes, ...
                desired_drive_pattern, ...
                config.benign_count_range(1), config.benign_count_range(2), ...
                desired_malignant_count_range(1), desired_malignant_count_range(2));
            dataset = generatesyntheticdataset(num_samples, dataset_path, desired_output_size, config);
            dataset_generated_now = true;
        end
    else
        dataset = generatesyntheticdataset(num_samples, dataset_path, desired_output_size, config);
        dataset_generated_now = true;
    end
    dataset_access_seconds = toc(dataset_timer);

    [features, targets, class_names] = unpack_dataset(dataset);
    sample_count = size(features, 1);
    if sample_count < 2
        error('traintissuemapper:NotEnoughSamples', ...
            'At least two samples are required to train and evaluate the surrogate.');
    end

    map_size = size(targets, 1);
    flat_targets = reshape(permute(double(targets), [3, 1, 2]), sample_count, []);

    ordering = randperm(sample_count);
    if strcmp(execution_mode, 'trainonly')
        test_count = 0;
    else
        test_count = round(test_fraction * sample_count);
        test_count = max(1, test_count);
        test_count = min(test_count, sample_count - 1);
    end

    if test_count == 0
        test_idx = zeros(0, 1);
        remaining_idx = ordering;
    else
        test_idx = ordering(1:test_count);
        remaining_idx = ordering(test_count + 1:end);
    end

    if validation_fraction > 0 && numel(remaining_idx) > 1
        val_count = round(validation_fraction * numel(remaining_idx));
        val_count = max(1, val_count);
        val_count = min(val_count, numel(remaining_idx) - 1);
    else
        val_count = 0;
    end

    val_idx = remaining_idx(1:val_count);
    train_idx = remaining_idx(val_count + 1:end);

    train_features = double(features(train_idx, :));
    train_targets = flat_targets(train_idx, :);
    if isempty(test_idx)
        test_features = zeros(0, size(features, 2));
        test_targets = zeros(0, size(flat_targets, 2));
    else
        test_features = double(features(test_idx, :));
        test_targets = flat_targets(test_idx, :);
    end

    if isempty(train_idx)
        error('traintissuemapper:SplitFailed', ...
            'Unable to create a non-empty training split from the dataset.');
    end

    if isempty(val_idx)
        validation_features = zeros(0, size(features, 2));
        validation_targets = zeros(0, size(flat_targets, 2));
    else
        validation_features = double(features(val_idx, :));
        validation_targets = flat_targets(val_idx, :);
    end

    feature_mean = mean(train_features, 1);
    feature_std = std(train_features, 0, 1);
    feature_std(feature_std == 0) = 1;

    scaled_train_features = (train_features - feature_mean) ./ feature_std;
    scaled_test_features = (test_features - feature_mean) ./ feature_std;
    scaled_validation_features = (validation_features - feature_mean) ./ feature_std;

    training_timer = tic;
    [network, train_record] = fitmlpregressor( ...
        scaled_train_features, train_targets, scaled_validation_features, validation_targets, ...
        hidden_layer_sizes, epochs, train_algorithm);
    training_seconds = toc(training_timer);

    evaluation_timer = tic;
    train_predictions = apply_model(scaled_train_features, network);

    if isempty(val_idx)
        validation_predictions = zeros(0, size(flat_targets, 2));
        validation_mse = NaN;
        validation_pixel_accuracy = NaN;
    else
        validation_predictions = apply_model(scaled_validation_features, network);
        validation_class_predictions = clip_predictions(validation_predictions);
        validation_mse = mean((validation_predictions(:) - validation_targets(:)) .^ 2);
        validation_pixel_accuracy = mean(validation_class_predictions(:) == uint8(validation_targets(:)));
    end

    if isempty(test_idx)
        test_predictions = zeros(0, size(flat_targets, 2));
        test_mse = NaN;
        test_pixel_accuracy = NaN;
        preview = buildpreview(false, map_size);
    else
        test_predictions = apply_model(scaled_test_features, network);
        test_class_predictions = clip_predictions(test_predictions);
        test_targets_uint8 = uint8(test_targets);
        test_residuals = test_predictions - test_targets;

        phantom_radius_mm = read_dataset_phantom_radius(dataset);
        target_map = reshape(test_targets_uint8(1, :), map_size, map_size);
        prediction_map = reshape(test_class_predictions(1, :), map_size, map_size);
        target_summary = analyzetissuemap(target_map, class_names, phantom_radius_mm);
        prediction_summary = analyzetissuemap(prediction_map, class_names, phantom_radius_mm);

        test_mse = mean(test_residuals(:) .^ 2);
        test_pixel_accuracy = mean(test_class_predictions(:) == test_targets_uint8(:));
        preview = buildpreview(true, map_size);
        preview.target = target_map;
        preview.prediction = prediction_map;
        preview.target_summary = target_summary;
        preview.prediction_summary = prediction_summary;
    end

    train_class_predictions = clip_predictions(train_predictions);
    train_targets_uint8 = uint8(train_targets);
    train_residuals = train_predictions - train_targets;
    evaluation_seconds = toc(evaluation_timer);
    phantom_radius_mm = read_dataset_phantom_radius(dataset);

    model = struct();
    model.model_type = 'mlpregressor';
    model.feature_mean = feature_mean;
    model.feature_std = feature_std;
    model.network = network;
    model.hidden_layer_sizes = hidden_layer_sizes;
    model.train_algorithm = train_algorithm;
    model.epochs = epochs;
    model.feature_count = size(features, 2);
    model.map_size = map_size;
    model.class_names = class_names;
    model.phantom_radius_mm = phantom_radius_mm;
    model.training_record = train_record;

    metrics = struct();
    metrics.dataset_source = 'matlab';
    metrics.model_type = 'mlpregressor';
    metrics.execution_mode = execution_mode;
    metrics.num_samples = sample_count;
    metrics.feature_count = size(features, 2);
    metrics.map_size = map_size;
    metrics.desired_output_size = desired_output_size;
    metrics.train_count = numel(train_idx);
    metrics.validation_count = numel(val_idx);
    metrics.test_count = numel(test_idx);
    metrics.train_mse = mean(train_residuals(:) .^ 2);
    metrics.validation_mse = validation_mse;
    metrics.test_mse = test_mse;
    metrics.train_pixel_accuracy = mean(train_class_predictions(:) == train_targets_uint8(:));
    metrics.validation_pixel_accuracy = validation_pixel_accuracy;
    metrics.pixel_accuracy = test_pixel_accuracy;
    metrics.hidden_layer_sizes = hidden_layer_sizes;
    metrics.train_algorithm = train_algorithm;
    metrics.epochs = epochs;
    metrics.best_epoch = read_training_record_field(train_record, 'best_epoch', NaN);
    metrics.best_validation_perf = read_training_record_field(train_record, 'best_vperf', NaN);
    metrics.dataset_generated_now = dataset_generated_now;
    metrics.dataset_access_seconds = dataset_access_seconds;
    metrics.dataset_generation_seconds = read_dataset_metadata_field(dataset, 'generation_seconds', NaN);
    metrics.dataset_seconds_per_sample = read_dataset_metadata_field(dataset, 'seconds_per_sample', NaN);
    metrics.forward_solve_count = read_dataset_metadata_field(dataset, 'forward_solve_count', NaN);
    metrics.training_seconds = training_seconds;
    metrics.evaluation_seconds = evaluation_seconds;
    metrics.total_runtime_seconds = toc(total_timer);
    metrics.class_names = class_names;
    metrics.preview_available = preview.available;
    metrics.preview_target_summary = preview.target_summary;
    metrics.preview_prediction_summary = preview.prediction_summary;

    save(fullfile(artifact_dir, 'tissuemappermodel.mat'), 'model', '-v7');
    save(fullfile(artifact_dir, 'tissuemappermetrics.mat'), 'metrics', '-v7');
    save(fullfile(artifact_dir, 'tissuemapperpreview.mat'), 'preview', '-v7');
    writemetricsreport(metrics, fullfile(artifact_dir, 'tissuemappermetrics.txt'));
    if preview.available
        try
            writepreviewfigure(preview, class_names, fullfile(artifact_dir, 'tissuemapperpreview.png'));
        catch err
            warning('traintissuemapper:PreviewExportFailed', ...
                'Preview image export skipped: %s', err.message);
        end
    end

    disp(metrics);
end

function [network, train_record] = fitmlpregressor(train_features, train_targets, validation_features, validation_targets, hidden_layer_sizes, epochs, train_algorithm)
    if exist('fitnet', 'file') ~= 2
        error('traintissuemapper:MissingDeepLearningToolbox', ...
            ['Training the MLP requires MATLAB Deep Learning Toolbox ', ...
             '(the toolbox that provides fitnet).']);
    end

    network = fitnet(hidden_layer_sizes, train_algorithm);
    network.name = 'tissuemappermlp';
    network.performFcn = 'mse';
    network.layers{end}.transferFcn = 'purelin';
    network.divideFcn = 'divideind';
    network.trainParam.epochs = epochs;
    network.trainParam.showWindow = false;
    network.trainParam.showCommandLine = false;
    network.trainParam.max_fail = 10;
    network.inputs{1}.processFcns = {};
    network.outputs{end}.processFcns = {};

    if isempty(validation_features)
        input_matrix = train_features';
        target_matrix = train_targets';
        network.divideParam.trainInd = 1:size(train_features, 1);
        network.divideParam.valInd = [];
        network.divideParam.testInd = [];
    else
        combined_features = [train_features; validation_features];
        combined_targets = [train_targets; validation_targets];
        input_matrix = combined_features';
        target_matrix = combined_targets';
        network.divideParam.trainInd = 1:size(train_features, 1);
        network.divideParam.valInd = size(train_features, 1) + (1:size(validation_features, 1));
        network.divideParam.testInd = [];
    end

    [network, train_record] = train(network, input_matrix, target_matrix);
end

function prediction = apply_model(X, network)
    if isempty(X)
        prediction = zeros(0, network.outputs{end}.size);
        return;
    end

    prediction = network(X')';
end

function clipped = clip_predictions(prediction)
    clipped = uint8(min(max(round(prediction), 0), 2));
end

function config = apply_training_config_defaults(config)
    if ~isfield(config, 'output_size') || isempty(config.output_size)
        config.output_size = 24;
    end

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

    if ~isfield(config, 'hidden_layer_sizes') || isempty(config.hidden_layer_sizes)
        config.hidden_layer_sizes = [512, 256, 128];
    end

    if ~isfield(config, 'epochs') || isempty(config.epochs)
        config.epochs = 300;
    end

    if ~isfield(config, 'train_algorithm') || isempty(config.train_algorithm)
        config.train_algorithm = 'trainscg';
    end

    if ~isfield(config, 'test_fraction') || isempty(config.test_fraction)
        config.test_fraction = 0.15;
    end

    if ~isfield(config, 'validation_fraction') || isempty(config.validation_fraction)
        config.validation_fraction = 0.15;
    end

    if ~isfield(config, 'execution_mode') || isempty(config.execution_mode)
        config.execution_mode = 'trainandtest';
    end

    validate_training_config(config);
end

function output_size = read_dataset_output_size(dataset)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, 'output_size')
        output_size = dataset.metadata.output_size;
        return;
    end

    if isfield(dataset, 'params') && isfield(dataset.params, 'output_size')
        output_size = dataset.params.output_size;
        return;
    end

    if isfield(dataset, 'targets')
        output_size = size(dataset.targets, 1);
        return;
    end

    error('traintissuemapper:DatasetResolutionUnknown', ...
        'Unable to determine the dataset target resolution.');
end

function phantom_radius_mm = read_dataset_phantom_radius(dataset)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, 'phantom_radius_mm')
        phantom_radius_mm = dataset.metadata.phantom_radius_mm;
        return;
    end

    if isfield(dataset, 'params') && isfield(dataset.params, 'phantom_radius')
        phantom_radius_mm = dataset.params.phantom_radius;
        return;
    end

    phantom_radius_mm = 35.0;
end

function num_electrodes = read_dataset_num_electrodes(dataset)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, 'num_electrodes')
        num_electrodes = dataset.metadata.num_electrodes;
        return;
    end

    if isfield(dataset, 'params') && isfield(dataset.params, 'num_electrodes')
        num_electrodes = dataset.params.num_electrodes;
        return;
    end

    num_electrodes = 8;
end

function drive_pattern = read_dataset_drive_pattern(dataset)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, 'drive_pattern')
        drive_pattern = dataset.metadata.drive_pattern;
        return;
    end

    if isfield(dataset, 'params') && isfield(dataset.params, 'drive_pattern')
        drive_pattern = dataset.params.drive_pattern;
        return;
    end

    drive_pattern = 'opposite';
end

function range_values = read_dataset_count_range(dataset, field_name, default_value)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, field_name)
        range_values = dataset.metadata.(field_name);
        return;
    end

    if isfield(dataset, 'params') && isfield(dataset.params, field_name)
        range_values = dataset.params.(field_name);
        return;
    end

    range_values = default_value;
end

function sample_count = read_dataset_sample_count(dataset)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, 'num_samples')
        sample_count = dataset.metadata.num_samples;
        return;
    end

    if isfield(dataset, 'features')
        sample_count = size(dataset.features, 1);
        return;
    end

    error('traintissuemapper:DatasetSampleCountUnknown', ...
        'Unable to determine the dataset sample count.');
end

function value = read_dataset_metadata_field(dataset, field_name, default_value)
    if isfield(dataset, 'metadata') && isfield(dataset.metadata, field_name)
        value = dataset.metadata.(field_name);
    else
        value = default_value;
    end
end

function value = read_training_record_field(train_record, field_name, default_value)
    if isfield(train_record, field_name)
        value = train_record.(field_name);
    else
        value = default_value;
    end
end

function [features, targets, class_names] = unpack_dataset(dataset)
    if ~isfield(dataset, 'features') || ~isfield(dataset, 'targets')
        error('traintissuemapper:InvalidDataset', ...
            'Dataset must contain features and targets variables.');
    end

    features = double(dataset.features);
    targets = dataset.targets;

    if ndims(targets) == 2
        sample_count = size(features, 1);
        map_size = round(sqrt(size(targets, 2)));
        if map_size * map_size ~= size(targets, 2)
            error('traintissuemapper:InvalidTargetShape', ...
                '2D targets must contain flattened square maps.');
        end
        targets = reshape(targets', map_size, map_size, sample_count);
    elseif ndims(targets) ~= 3
        error('traintissuemapper:InvalidTargetShape', ...
            'Targets must be HxWxN or NxP.');
    end

    if isfield(dataset, 'class_names')
        class_names = dataset.class_names;
    else
        class_names = {'healthy', 'benign', 'malignant'};
    end
end

function validate_training_config(config)
    valid_modes = {'trainandtest', 'trainonly'};
    if ~any(strcmpi(config.execution_mode, valid_modes))
        error('traintissuemapper:InvalidExecutionMode', ...
            'execution_mode must be ''trainandtest'' or ''trainonly''.');
    end

    if ~isnumeric(config.hidden_layer_sizes) || isempty(config.hidden_layer_sizes) || ...
            any(config.hidden_layer_sizes <= 0) || any(mod(config.hidden_layer_sizes, 1) ~= 0)
        error('traintissuemapper:InvalidHiddenLayers', ...
            'hidden_layer_sizes must be a vector of positive integers.');
    end

    if ~ischar(config.drive_pattern) && ~isstring(config.drive_pattern)
        error('traintissuemapper:InvalidDrivePattern', ...
            'drive_pattern must be ''opposite'', ''adjacent'', or ''hybrid''.');
    end

    if ~any(strcmpi(char(config.drive_pattern), {'opposite', 'adjacent', 'hybrid'}))
        error('traintissuemapper:InvalidDrivePattern', ...
            'drive_pattern must be ''opposite'', ''adjacent'', or ''hybrid''.');
    end

    if ~isnumeric(config.epochs) || ~isscalar(config.epochs) || config.epochs < 1 || mod(config.epochs, 1) ~= 0
        error('traintissuemapper:InvalidEpochs', ...
            'epochs must be a positive integer.');
    end

    validate_fraction(config.test_fraction, 'test_fraction');
    validate_fraction(config.validation_fraction, 'validation_fraction');
end

function validate_fraction(value, field_name)
    if ~isnumeric(value) || ~isscalar(value) || value < 0 || value >= 1
        error('traintissuemapper:InvalidFraction', ...
            '%s must be a numeric scalar in the range [0, 1).', field_name);
    end
end

function preview = buildpreview(is_available, map_size)
    if nargin < 2
        map_size = 0;
    end

    preview = struct();
    preview.available = is_available;
    preview.target = zeros(map_size, map_size, 'uint8');
    preview.prediction = zeros(map_size, map_size, 'uint8');
    preview.target_summary = emptyregionsummary(is_available);
    preview.prediction_summary = emptyregionsummary(is_available);
end

function summary = emptyregionsummary(is_available)
    summary = struct();
    summary.available = is_available;
    summary.region_count = 0;
    summary.benign_count = 0;
    summary.malignant_count = 0;
    summary.regions = struct([]);
end

function writemetricsreport(metrics, output_path)
    fid = fopen(output_path, 'w');
    if fid == -1
        error('traintissuemapper:MetricsWriteFailed', ...
            'Unable to open metrics report for writing: %s', output_path);
    end

    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'Dataset source: %s\n', metrics.dataset_source);
    fprintf(fid, 'Model type: %s\n', metrics.model_type);
    fprintf(fid, 'Execution mode: %s\n', metrics.execution_mode);
    fprintf(fid, 'Samples: %d\n', metrics.num_samples);
    fprintf(fid, 'Split sizes (train/val/test): %d / %d / %d\n', ...
        metrics.train_count, metrics.validation_count, metrics.test_count);
    fprintf(fid, 'Feature count: %d\n', metrics.feature_count);
    fprintf(fid, 'Map size: %d x %d\n', metrics.map_size, metrics.map_size);
    fprintf(fid, 'Train MSE: %.6f\n', metrics.train_mse);
    fprintf(fid, 'Validation MSE: %s\n', format_metric(metrics.validation_mse));
    fprintf(fid, 'Test MSE: %s\n', format_metric(metrics.test_mse));
    fprintf(fid, 'Train pixel accuracy: %.4f\n', metrics.train_pixel_accuracy);
    fprintf(fid, 'Validation pixel accuracy: %s\n', format_metric(metrics.validation_pixel_accuracy));
    fprintf(fid, 'Test pixel accuracy: %s\n', format_metric(metrics.pixel_accuracy));
    fprintf(fid, 'Hidden layers: %s\n', format_hidden_layers(metrics.hidden_layer_sizes));
    fprintf(fid, 'Training algorithm: %s\n', metrics.train_algorithm);
    fprintf(fid, 'Epochs: %d\n', metrics.epochs);
    fprintf(fid, 'Best epoch: %s\n', format_metric(metrics.best_epoch));
    fprintf(fid, 'Best validation performance: %s\n', format_metric(metrics.best_validation_perf));
    fprintf(fid, 'Dataset regenerated this run: %s\n', format_yes_no(metrics.dataset_generated_now));
    fprintf(fid, 'Dataset access time (s): %.6f\n', metrics.dataset_access_seconds);
    fprintf(fid, 'Dataset generation time (s): %s\n', format_metric(metrics.dataset_generation_seconds));
    fprintf(fid, 'Dataset seconds per sample: %s\n', format_metric(metrics.dataset_seconds_per_sample));
    fprintf(fid, 'Forward solve count: %s\n', format_metric(metrics.forward_solve_count));
    fprintf(fid, 'Training time (s): %.6f\n', metrics.training_seconds);
    fprintf(fid, 'Evaluation time (s): %.6f\n', metrics.evaluation_seconds);
    fprintf(fid, 'Total runtime (s): %.6f\n', metrics.total_runtime_seconds);
    fprintf(fid, 'Classes: %s, %s, %s\n', ...
        metrics.class_names{1}, metrics.class_names{2}, metrics.class_names{3});

    writeregionsummary(fid, 'Preview Ground-Truth Regions', metrics.preview_target_summary);
    writeregionsummary(fid, 'Preview Predicted Regions', metrics.preview_prediction_summary);
end

function writeregionsummary(fid, title_text, summary)
    fprintf(fid, '\n%s\n', title_text);

    if ~isfield(summary, 'available') || ~summary.available
        fprintf(fid, 'No preview sample available for this run.\n');
        return;
    end

    fprintf(fid, 'Total regions: %d\n', summary.region_count);
    fprintf(fid, 'Benign regions: %d\n', summary.benign_count);
    fprintf(fid, 'Malignant regions: %d\n', summary.malignant_count);

    if isempty(summary.regions)
        fprintf(fid, 'No non-healthy regions detected.\n');
        return;
    end

    for region_idx = 1:numel(summary.regions)
        region = summary.regions(region_idx);
        fprintf(fid, ['Region %d: %s, pixels=%d, area_mm2=%.2f, ', ...
            'centroid_mm=(%.2f, %.2f)\n'], ...
            region_idx, region.class_name, region.pixel_count, ...
            region.estimated_area_mm2, region.centroid_x_mm, region.centroid_y_mm);
    end
end

function text = format_hidden_layers(hidden_layer_sizes)
    text = sprintf('%d-', hidden_layer_sizes);
    text = text(1:end - 1);
end

function text = format_metric(value)
    if isnumeric(value) && isscalar(value) && isfinite(value)
        text = sprintf('%.6f', value);
    else
        text = 'n/a';
    end
end

function text = format_yes_no(flag)
    if flag
        text = 'yes';
    else
        text = 'no';
    end
end

function writepreviewfigure(preview, class_names, output_path)
    fig = figure('Visible', 'off', 'Color', 'w');
    cleaner = onCleanup(@() close(fig)); %#ok<NASGU>

    t = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile(t, 1);
    imagesc(ax1, preview.target, [0, 2]);
    axis(ax1, 'image');
    title(ax1, sprintf('Ground Truth (%d regions)', preview.target_summary.region_count));
    xlabel(ax1, 'x');
    ylabel(ax1, 'y');

    ax2 = nexttile(t, 2);
    imagesc(ax2, preview.prediction, [0, 2]);
    axis(ax2, 'image');
    title(ax2, sprintf('Prediction (%d regions)', preview.prediction_summary.region_count));
    xlabel(ax2, 'x');
    ylabel(ax2, 'y');

    colormap(fig, parula(3));
    cb = colorbar(ax2);
    cb.Ticks = [0, 1, 2];
    cb.TickLabels = class_names;

    exportgraphics(fig, output_path, 'Resolution', 150);
end

function ensure_folder(path_str)
    if ~isempty(path_str) && ~isfolder(path_str)
        mkdir(path_str);
    end
end
