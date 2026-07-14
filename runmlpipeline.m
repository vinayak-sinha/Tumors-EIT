function runmlpipeline()
    % Interactive launcher for dataset generation, training, testing, and prediction.

    action_items = { ...
        'Generate Dataset Only', ...
        'Train Only', ...
        'Train and Test', ...
        'Predict Existing Features'};
    action_keys = { ...
        'generatedataset', ...
        'trainonly', ...
        'trainandtest', ...
        'predict'};
    algorithm_items = {'trainscg', 'trainlm', 'trainrp'};
    drive_pattern_items = {'hybrid', 'adjacent', 'opposite'};

    fig = figure('Name', 'ML Pipeline Launcher', ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Position', [100, 60, 1180, 760], ...
                 'Color', [0.94, 0.94, 0.94]);

    controls = struct();
    labels = struct();

    create_heading('Pipeline Action', [30, 705, 210, 22]);
    labels.action = create_label('Action', [30, 676, 150, 18]);
    controls.action = uicontrol(fig, 'Style', 'popupmenu', ...
        'String', action_items, ...
        'Value', 3, ...
        'Position', [30, 648, 260, 28], ...
        'Callback', @actionchangecallback);

    create_heading('Dataset Settings', [30, 600, 210, 22]);
    labels.sample_count = create_label('Sample Count', [30, 572, 130, 18]);
    controls.sample_count = create_edit('2000', [30, 546, 95, 26]);
    labels.output_size = create_label('Output Size', [145, 572, 130, 18]);
    controls.output_size = create_edit('24', [145, 546, 95, 26]);
    labels.num_electrodes = create_label('Num Electrodes', [260, 572, 130, 18]);
    controls.num_electrodes = create_edit('8', [260, 546, 95, 26]);
    labels.drive_pattern = create_label('Drive Pattern', [375, 572, 130, 18]);
    controls.drive_pattern = uicontrol(fig, 'Style', 'popupmenu', ...
        'String', drive_pattern_items, ...
        'Value', 1, ...
        'Position', [375, 546, 120, 26]);

    labels.benign_min = create_label('Benign Min', [30, 518, 130, 18]);
    controls.benign_min = create_edit('0', [30, 492, 95, 26]);
    labels.benign_max = create_label('Benign Max', [145, 518, 130, 18]);
    controls.benign_max = create_edit('2', [145, 492, 95, 26]);
    labels.malignant_min = create_label('Malignant Min', [260, 518, 130, 18]);
    controls.malignant_min = create_edit('0', [260, 492, 95, 26]);
    labels.malignant_max = create_label('Malignant Max', [375, 518, 130, 18]);
    controls.malignant_max = create_edit('3', [375, 492, 95, 26]);

    labels.dataset_path = create_label('Dataset File', [30, 464, 180, 18]);
    controls.dataset_path = create_edit(fullfile('artifacts', 'syntheticeitdataset.mat'), [30, 438, 370, 26]);
    controls.dataset_browse = create_button('Browse...', [410, 438, 85, 26], @browsedatasetcallback);

    create_heading('Training Settings', [30, 385, 210, 22]);
    labels.hidden_layers = create_label('Hidden Layers', [30, 357, 130, 18]);
    controls.hidden_layers = create_edit('512, 256, 128', [30, 331, 150, 26]);
    labels.epochs = create_label('Epochs', [195, 357, 120, 18]);
    controls.epochs = create_edit('300', [195, 331, 70, 26]);
    labels.algorithm = create_label('Train Algorithm', [280, 357, 130, 18]);
    controls.algorithm = uicontrol(fig, 'Style', 'popupmenu', ...
        'String', algorithm_items, ...
        'Value', 1, ...
        'Position', [280, 331, 110, 26]);

    labels.validation_fraction = create_label('Validation Fraction', [30, 302, 130, 18]);
    controls.validation_fraction = create_edit('0.15', [30, 276, 95, 26]);
    labels.test_fraction = create_label('Test Fraction', [145, 302, 130, 18]);
    controls.test_fraction = create_edit('0.15', [145, 276, 95, 26]);

    labels.artifact_dir = create_label('Artifact Folder', [30, 248, 180, 18]);
    controls.artifact_dir = create_edit('artifacts', [30, 222, 370, 26]);
    controls.artifact_browse = create_button('Browse...', [410, 222, 85, 26], @browseartifactdircallback);

    create_heading('Prediction Settings', [30, 170, 220, 22]);
    labels.model_path = create_label('Model File', [30, 142, 180, 18]);
    controls.model_path = create_edit(fullfile('artifacts', 'tissuemappermodel.mat'), [30, 116, 370, 26]);
    controls.model_browse = create_button('Browse...', [410, 116, 85, 26], @browsemodelcallback);

    labels.feature_path = create_label('Feature File', [30, 88, 180, 18]);
    controls.feature_path = create_edit('', [30, 62, 370, 26]);
    controls.feature_browse = create_button('Browse...', [410, 62, 85, 26], @browsefeaturecallback);

    labels.prediction_output_path = create_label('Prediction Output File', [30, 34, 180, 18]);
    controls.prediction_output_path = create_edit(fullfile('artifacts', 'predictionresults.mat'), [30, 8, 370, 26]);
    controls.prediction_output_browse = create_button('Browse...', [410, 8, 85, 26], @browsepredictionoutputcallback);

    labels.prediction_preview_path = create_label('Prediction Preview Image', [520, 676, 190, 18]);
    controls.prediction_preview_path = create_edit(fullfile('artifacts', 'predictionpreview.png'), [520, 648, 370, 26]);
    controls.prediction_preview_browse = create_button('Browse...', [900, 648, 85, 26], @browsepreviewcallback);

    create_heading('Run', [520, 600, 100, 22]);
    controls.run_button = uicontrol(fig, 'Style', 'pushbutton', ...
        'String', 'Run Selected Action', ...
        'FontWeight', 'bold', ...
        'Position', [520, 560, 210, 40], ...
        'Callback', @runcallback);
    controls.high_accuracy_button = uicontrol(fig, 'Style', 'pushbutton', ...
        'String', 'Apply High-Accuracy Preset', ...
        'Position', [745, 560, 190, 40], ...
        'Callback', @applyhighaccuracypresetcallback);

    controls.help_text = uicontrol(fig, 'Style', 'text', ...
        'String', '', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', fig.Color, ...
        'Position', [520, 500, 560, 48]);

    create_heading('Status', [520, 455, 110, 22]);
    controls.status_box = uicontrol(fig, 'Style', 'listbox', ...
        'Position', [520, 105, 620, 350], ...
        'Max', 2, ...
        'Min', 0, ...
        'FontName', 'Courier', ...
        'String', {'Ready.'});

    controls.open_artifacts_button = create_button('Open Artifacts Folder', [520, 60, 170, 30], @openartifactfoldercallback);
    controls.close_button = create_button('Close', [710, 60, 90, 30], @(~, ~) close(fig));

    synccontrolvisibility();
    logstatus('Launcher ready. Choose an action, set the inputs, and click Run Selected Action.');

    function actionchangecallback(~, ~)
        synccontrolvisibility();
    end

    function synccontrolvisibility()
        action_key = currentactionkey();

        show_dataset_controls = ismember(action_key, {'generatedataset', 'trainonly', 'trainandtest'});
        show_training_controls = ismember(action_key, {'trainonly', 'trainandtest'});
        show_prediction_controls = strcmp(action_key, 'predict');
        show_test_fraction = strcmp(action_key, 'trainandtest');

        setgroupvisible({ ...
            labels.sample_count, controls.sample_count, ...
            labels.output_size, controls.output_size, ...
            labels.num_electrodes, controls.num_electrodes, ...
            labels.drive_pattern, controls.drive_pattern, ...
            labels.benign_min, controls.benign_min, ...
            labels.benign_max, controls.benign_max, ...
            labels.malignant_min, controls.malignant_min, ...
            labels.malignant_max, controls.malignant_max, ...
            labels.dataset_path, controls.dataset_path, controls.dataset_browse}, ...
            show_dataset_controls);

        setgroupvisible({ ...
            labels.hidden_layers, controls.hidden_layers, ...
            labels.epochs, controls.epochs, ...
            labels.algorithm, controls.algorithm, ...
            labels.validation_fraction, controls.validation_fraction, ...
            labels.artifact_dir, controls.artifact_dir, controls.artifact_browse}, ...
            show_training_controls);

        setgroupvisible({labels.test_fraction, controls.test_fraction}, show_training_controls && show_test_fraction);

        setgroupvisible({ ...
            labels.model_path, controls.model_path, controls.model_browse, ...
            labels.feature_path, controls.feature_path, controls.feature_browse, ...
            labels.prediction_output_path, controls.prediction_output_path, controls.prediction_output_browse, ...
            labels.prediction_preview_path, controls.prediction_preview_path, controls.prediction_preview_browse}, ...
            show_prediction_controls);

        if strcmp(action_key, 'generatedataset')
            controls.help_text.String = ['Creates or overwrites a dataset file using the dataset settings. ', ...
                'Only dataset inputs are required for this action.'];
        elseif strcmp(action_key, 'trainonly')
            controls.help_text.String = ['Trains and saves the model without a held-out test split. ', ...
                'Useful when you only want a model artifact and training metrics.'];
        elseif strcmp(action_key, 'trainandtest')
            controls.help_text.String = ['Trains the model, evaluates it on a test split, and writes preview artifacts. ', ...
                'Use this for the full training-and-testing workflow.'];
        else
            controls.help_text.String = ['Loads a saved model and a feature file, runs prediction, ', ...
                'and saves the prediction results to disk.'];
        end
    end

    function runcallback(~, ~)
        action_key = currentactionkey();

        try
            if strcmp(action_key, 'generatedataset')
                run_generatedataset();
            elseif strcmp(action_key, 'trainonly')
                run_training('trainonly');
            elseif strcmp(action_key, 'trainandtest')
                run_training('trainandtest');
            else
                run_prediction();
            end
        catch err
            logstatus(['ERROR: ', err.message]);
            errordlg(err.message, 'Pipeline Error');
        end
    end

    function applyhighaccuracypresetcallback(~, ~)
        controls.sample_count.String = '3000';
        controls.output_size.String = '24';
        controls.num_electrodes.String = '8';
        controls.drive_pattern.Value = 1;
        controls.hidden_layers.String = '512, 256, 128';
        controls.epochs.String = '300';
        controls.validation_fraction.String = '0.15';
        controls.test_fraction.String = '0.15';
        controls.algorithm.Value = 1;
        logstatus(['Applied high-accuracy preset: 3000 samples, hybrid drive pattern, ', ...
            '512-256-128 hidden layers, 300 epochs, and 15/15 validation/test splits.']);
    end

    function run_generatedataset()
        sample_count = readpositiveinteger(controls.sample_count, 'Sample Count');
        output_size = readpositiveinteger(controls.output_size, 'Output Size');
        num_electrodes = readelectrodecount(controls.num_electrodes);
        benign_count_range = readcountrange(controls.benign_min, controls.benign_max, 'Benign');
        malignant_count_range = readcountrange(controls.malignant_min, controls.malignant_max, 'Malignant');
        dataset_path = readrequiredpath(controls.dataset_path, 'Dataset File');

        config = struct();
        config.num_electrodes = num_electrodes;
        config.drive_pattern = readpopupstring(controls.drive_pattern);
        config.benign_count_range = benign_count_range;
        config.malignant_count_range = malignant_count_range;

        ensureparentfolder(dataset_path);

        logstatus(sprintf('Generating dataset: %d samples, %d x %d output, %d electrodes.', ...
            sample_count, output_size, output_size, num_electrodes));
        dataset = generatesyntheticdataset(sample_count, dataset_path, output_size, config);
        assignin('base', 'lastgenerateddataset', dataset);
        logstatus(['Dataset saved to ', dataset_path]);
    end

    function run_training(execution_mode)
        sample_count = readpositiveinteger(controls.sample_count, 'Sample Count');
        output_size = readpositiveinteger(controls.output_size, 'Output Size');
        num_electrodes = readelectrodecount(controls.num_electrodes);
        benign_count_range = readcountrange(controls.benign_min, controls.benign_max, 'Benign');
        malignant_count_range = readcountrange(controls.malignant_min, controls.malignant_max, 'Malignant');
        dataset_path = readrequiredpath(controls.dataset_path, 'Dataset File');
        artifact_dir = readrequiredpath(controls.artifact_dir, 'Artifact Folder');
        hidden_layer_sizes = readhiddenlayers(controls.hidden_layers);
        epochs = readpositiveinteger(controls.epochs, 'Epochs');
        validation_fraction = readfraction(controls.validation_fraction, 'Validation Fraction');

        if strcmp(execution_mode, 'trainandtest')
            test_fraction = readfraction(controls.test_fraction, 'Test Fraction');
        else
            test_fraction = 0.0;
        end

        train_algorithm = readpopupstring(controls.algorithm);

        config = struct();
        config.output_size = output_size;
        config.num_electrodes = num_electrodes;
        config.drive_pattern = readpopupstring(controls.drive_pattern);
        config.benign_count_range = benign_count_range;
        config.malignant_count_range = malignant_count_range;
        config.hidden_layer_sizes = hidden_layer_sizes;
        config.epochs = epochs;
        config.train_algorithm = train_algorithm;
        config.validation_fraction = validation_fraction;
        config.test_fraction = test_fraction;
        config.execution_mode = execution_mode;

        ensurefolder(artifact_dir);
        ensureparentfolder(dataset_path);

        logstatus(sprintf('Training model in %s mode.', execution_mode));
        logstatus(sprintf('Dataset: %s', dataset_path));
        logstatus(sprintf('Artifacts: %s', artifact_dir));

        metrics = traintissuemapper(sample_count, dataset_path, artifact_dir, config);
        assignin('base', 'lasttrainingmetrics', metrics);

        if strcmp(execution_mode, 'trainandtest')
            logstatus(sprintf('Training complete. Test pixel accuracy: %s', formatmetric(metrics.pixel_accuracy)));
        else
            logstatus('Training complete. Model and metrics were written without a held-out test split.');
        end
    end

    function run_prediction()
        model_path = readrequiredpath(controls.model_path, 'Model File');
        feature_path = readrequiredpath(controls.feature_path, 'Feature File');
        prediction_output_path = readrequiredpath(controls.prediction_output_path, 'Prediction Output File');
        preview_image_path = strtrim(controls.prediction_preview_path.String);

        [features, feature_source_name] = loadfeaturematrix(feature_path);

        logstatus(sprintf('Loaded features from %s', feature_path));
        logstatus(sprintf('Feature matrix size: %d sample(s) x %d feature(s).', size(features, 1), size(features, 2)));

        results = predicttissuemap(features, model_path);
        prediction_metadata = struct();
        prediction_metadata.feature_file = feature_path;
        prediction_metadata.feature_source_name = feature_source_name;
        prediction_metadata.model_file = model_path;

        ensureparentfolder(prediction_output_path);
        save(prediction_output_path, 'results', 'prediction_metadata', '-v7');
        assignin('base', 'lastpredictionresults', results);
        logstatus(['Prediction results saved to ', prediction_output_path]);

        if ~isempty(preview_image_path)
            ensureparentfolder(preview_image_path);
            writepredictionpreview(results, preview_image_path);
            logstatus(['Prediction preview image saved to ', preview_image_path]);
        end

        if ~isempty(results)
            logstatus(sprintf('First sample summary: %d total region(s), %d benign, %d malignant.', ...
                results(1).region_count, results(1).benign_count, results(1).malignant_count));
        end
    end

    function action_key = currentactionkey()
        action_key = action_keys{controls.action.Value};
    end

    function browsepath = currentfilepath(control_handle)
        browsepath = strtrim(control_handle.String);
        if isempty(browsepath)
            browsepath = pwd;
        end
    end

    function browsedatasetcallback(~, ~)
        initial_path = currentfilepath(controls.dataset_path);
        [file_name, folder_name] = uiputfile('*.mat', 'Choose Dataset File', initial_path);
        if isequal(file_name, 0)
            return;
        end
        controls.dataset_path.String = fullfile(folder_name, file_name);
    end

    function browseartifactdircallback(~, ~)
        initial_path = currentfilepath(controls.artifact_dir);
        selected_dir = uigetdir(initial_path, 'Choose Artifact Folder');
        if isequal(selected_dir, 0)
            return;
        end
        controls.artifact_dir.String = selected_dir;
    end

    function browsemodelcallback(~, ~)
        initial_path = currentfilepath(controls.model_path);
        [file_name, folder_name] = uigetfile('*.mat', 'Choose Model File', initial_path);
        if isequal(file_name, 0)
            return;
        end
        controls.model_path.String = fullfile(folder_name, file_name);
    end

    function browsefeaturecallback(~, ~)
        initial_path = currentfilepath(controls.feature_path);
        [file_name, folder_name] = uigetfile( ...
            {'*.mat;*.csv;*.txt', 'Feature Files (*.mat, *.csv, *.txt)'}, ...
            'Choose Feature File', initial_path);
        if isequal(file_name, 0)
            return;
        end
        controls.feature_path.String = fullfile(folder_name, file_name);
    end

    function browsepredictionoutputcallback(~, ~)
        initial_path = currentfilepath(controls.prediction_output_path);
        [file_name, folder_name] = uiputfile('*.mat', 'Choose Prediction Output File', initial_path);
        if isequal(file_name, 0)
            return;
        end
        controls.prediction_output_path.String = fullfile(folder_name, file_name);
    end

    function browsepreviewcallback(~, ~)
        initial_path = currentfilepath(controls.prediction_preview_path);
        [file_name, folder_name] = uiputfile('*.png', 'Choose Prediction Preview Image', initial_path);
        if isequal(file_name, 0)
            return;
        end
        controls.prediction_preview_path.String = fullfile(folder_name, file_name);
    end

    function openartifactfoldercallback(~, ~)
        artifact_dir = strtrim(controls.artifact_dir.String);
        if isempty(artifact_dir)
            artifact_dir = 'artifacts';
        end

        if ~isfolder(artifact_dir)
            errordlg('Artifact folder does not exist yet.', 'Folder Not Found');
            return;
        end

        try
            open(artifact_dir);
        catch err
            errordlg(err.message, 'Open Folder Error');
        end
    end

    function control_handle = create_edit(default_text, position)
        control_handle = uicontrol(fig, 'Style', 'edit', ...
            'String', default_text, ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', 'w', ...
            'Position', position);
    end

    function control_handle = create_button(button_text, position, callback_handle)
        control_handle = uicontrol(fig, 'Style', 'pushbutton', ...
            'String', button_text, ...
            'Position', position, ...
            'Callback', callback_handle);
    end

    function control_handle = create_label(label_text, position)
        control_handle = uicontrol(fig, 'Style', 'text', ...
            'String', label_text, ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', fig.Color, ...
            'Position', position);
    end

    function create_heading(label_text, position)
        uicontrol(fig, 'Style', 'text', ...
            'String', label_text, ...
            'FontWeight', 'bold', ...
            'FontSize', 11, ...
            'HorizontalAlignment', 'left', ...
            'BackgroundColor', fig.Color, ...
            'Position', position);
    end

    function setgroupvisible(handle_group, is_visible)
        if is_visible
            visible_value = 'on';
        else
            visible_value = 'off';
        end

        for handle_idx = 1:numel(handle_group)
            set(handle_group{handle_idx}, 'Visible', visible_value);
        end
    end

    function logstatus(message_text)
        current_messages = controls.status_box.String;
        if ischar(current_messages)
            current_messages = {current_messages};
        end

        timestamp = datestr(now, 'HH:MM:SS');
        current_messages{end + 1} = sprintf('[%s] %s', timestamp, message_text); %#ok<AGROW>
        controls.status_box.String = current_messages;
        controls.status_box.Value = numel(current_messages);
        drawnow;
    end
end

function value = readpositiveinteger(control_handle, label_text)
    value = str2double(strtrim(control_handle.String));
    if isnan(value) || value < 1 || mod(value, 1) ~= 0
        error('runmlpipeline:InvalidInteger', '%s must be a positive integer.', label_text);
    end
end

function value = readelectrodecount(control_handle)
    value = readpositiveinteger(control_handle, 'Num Electrodes');
    if value < 4 || mod(value, 2) ~= 0
        error('runmlpipeline:InvalidElectrodeCount', ...
            'Num Electrodes must be an even integer greater than or equal to 4.');
    end
end

function range_values = readcountrange(min_control, max_control, label_text)
    range_min = readnonnegativeinteger(min_control, [label_text, ' Min']);
    range_max = readnonnegativeinteger(max_control, [label_text, ' Max']);

    if range_min > range_max
        error('runmlpipeline:InvalidCountRange', ...
            '%s range must satisfy min <= max.', label_text);
    end

    range_values = [range_min, range_max];
end

function value = readnonnegativeinteger(control_handle, label_text)
    value = str2double(strtrim(control_handle.String));
    if isnan(value) || value < 0 || mod(value, 1) ~= 0
        error('runmlpipeline:InvalidNonnegativeInteger', ...
            '%s must be a nonnegative integer.', label_text);
    end
end

function value = readfraction(control_handle, label_text)
    value = str2double(strtrim(control_handle.String));
    if isnan(value) || value < 0 || value >= 1
        error('runmlpipeline:InvalidFraction', ...
            '%s must be a number in the range [0, 1).', label_text);
    end
end

function hidden_layer_sizes = readhiddenlayers(control_handle)
    text_value = strtrim(control_handle.String);
    tokens = regexp(text_value, '[,\s]+', 'split');
    tokens = tokens(~cellfun('isempty', tokens));

    if isempty(tokens)
        error('runmlpipeline:InvalidHiddenLayers', ...
            'Hidden Layers must contain one or more positive integers.');
    end

    hidden_layer_sizes = zeros(1, numel(tokens));
    for token_idx = 1:numel(tokens)
        hidden_layer_sizes(token_idx) = str2double(tokens{token_idx});
    end

    if any(isnan(hidden_layer_sizes)) || any(hidden_layer_sizes < 1) || ...
            any(mod(hidden_layer_sizes, 1) ~= 0)
        error('runmlpipeline:InvalidHiddenLayers', ...
            'Hidden Layers must contain only positive integers, for example "256, 128".');
    end
end

function path_value = readrequiredpath(control_handle, label_text)
    path_value = strtrim(control_handle.String);
    if isempty(path_value)
        error('runmlpipeline:MissingPath', '%s is required.', label_text);
    end
end

function selected_text = readpopupstring(control_handle)
    option_list = get(control_handle, 'String');
    selected_index = get(control_handle, 'Value');

    if iscell(option_list)
        selected_text = option_list{selected_index};
    else
        selected_text = deblank(option_list(selected_index, :));
    end
end

function ensureparentfolder(file_path)
    parent_folder = fileparts(file_path);
    if ~isempty(parent_folder) && ~isfolder(parent_folder)
        mkdir(parent_folder);
    end
end

function ensurefolder(folder_path)
    if ~isempty(folder_path) && ~isfolder(folder_path)
        mkdir(folder_path);
    end
end

function [features, source_name] = loadfeaturematrix(feature_path)
    [~, ~, extension] = fileparts(feature_path);
    extension = lower(extension);

    if strcmp(extension, '.mat')
        [features, source_name] = loadmatfeaturematrix(feature_path);
        return;
    end

    if exist('readmatrix', 'file') == 2
        features = readmatrix(feature_path);
    else
        features = dlmread(feature_path);
    end

    if ~isnumeric(features) || isempty(features)
        error('runmlpipeline:InvalidFeatureFile', ...
            'Feature file must contain a non-empty numeric matrix.');
    end

    if isvector(features)
        features = reshape(features, 1, []);
    end

    source_name = extension(2:end);
end

function [features, source_name] = loadmatfeaturematrix(feature_path)
    variable_info = whos('-file', feature_path);
    numeric_variable_names = {};

    for variable_idx = 1:numel(variable_info)
        info = variable_info(variable_idx);
        if ismember(info.class, {'double', 'single', 'uint8', 'uint16', 'int16', 'int32', 'uint32'})
            numeric_variable_names{end + 1} = info.name; %#ok<AGROW>
        end
    end

    if isempty(numeric_variable_names)
        error('runmlpipeline:NoNumericFeatureVariable', ...
            'The MAT file does not contain any numeric variables that can be used as features.');
    end

    if numel(numeric_variable_names) == 1
        source_name = numeric_variable_names{1};
    else
        [selection_idx, is_selected] = listdlg( ...
            'PromptString', 'Choose the feature variable to use:', ...
            'SelectionMode', 'single', ...
            'ListString', numeric_variable_names);
        if ~is_selected
            error('runmlpipeline:FeatureSelectionCancelled', ...
                'Feature variable selection was cancelled.');
        end
        source_name = numeric_variable_names{selection_idx};
    end

    loaded_data = load(feature_path, source_name);
    features = loaded_data.(source_name);

    if ~isnumeric(features) || isempty(features)
        error('runmlpipeline:InvalidFeatureVariable', ...
            'Selected feature variable must be a non-empty numeric matrix.');
    end

    if isvector(features)
        features = reshape(features, 1, []);
    end
end

function writepredictionpreview(results, output_path)
    if isempty(results)
        error('runmlpipeline:NoPredictionResults', ...
            'No prediction results were produced, so no preview image could be written.');
    end

    preview_result = results(1);

    fig = figure('Visible', 'off', 'Color', 'w');
    cleaner = onCleanup(@() close(fig)); %#ok<NASGU>

    imagesc(preview_result.class_map, [0, 2]);
    axis image;
    title(sprintf('Prediction Preview: %d region(s)', preview_result.region_count));
    xlabel('x');
    ylabel('y');
    colormap(parula(3));
    colorbar('Ticks', [0, 1, 2], ...
             'TickLabels', {'healthy', 'benign', 'malignant'});

    exportgraphics(fig, output_path, 'Resolution', 150);
end

function text = formatmetric(value)
    if isnumeric(value) && isscalar(value) && isfinite(value)
        text = sprintf('%.4f', value);
    else
        text = 'n/a';
    end
end
