function results = predicttissuemap(features, model_path)
    % Predict tissue maps and separate tumor regions from voltage features.

    if nargin < 2 || isempty(model_path)
        model_path = fullfile('artifacts', 'tissuemappermodel.mat');
    end

    model_data = load(model_path);
    if ~isfield(model_data, 'model')
        error('predicttissuemap:InvalidModelFile', ...
            'Model file must contain a ''model'' variable.');
    end

    model = model_data.model;

    if isvector(features)
        features = reshape(features, 1, []);
    end

    if ~isfield(model, 'phantom_radius_mm')
        model.phantom_radius_mm = 35.0;
    end

    if ~isfield(model, 'class_names')
        model.class_names = {'healthy', 'benign', 'malignant'};
    end

    if size(features, 2) ~= model.feature_count
        error('predicttissuemap:FeatureMismatch', ...
            'Expected %d feature values per sample, but received %d.', ...
            model.feature_count, size(features, 2));
    end

    features = double(features);
    [feature_mean, feature_std] = readmodelnormalization(model);
    scaled_features = (features - feature_mean) ./ feature_std;
    raw_scores = model.network(scaled_features')';
    class_predictions = uint8(min(max(round(raw_scores), 0), 2));

    sample_count = size(features, 1);
    results = repmat(struct( ...
        'class_map', [], ...
        'raw_scores', [], ...
        'summary', struct(), ...
        'benign_count', 0, ...
        'malignant_count', 0, ...
        'region_count', 0), sample_count, 1);

    for sample_idx = 1:sample_count
        class_map = reshape(class_predictions(sample_idx, :), model.map_size, model.map_size);
        raw_map = reshape(raw_scores(sample_idx, :), model.map_size, model.map_size);
        summary = analyzetissuemap(class_map, model.class_names, model.phantom_radius_mm);

        results(sample_idx).class_map = class_map;
        results(sample_idx).raw_scores = raw_map;
        results(sample_idx).summary = summary;
        results(sample_idx).benign_count = summary.benign_count;
        results(sample_idx).malignant_count = summary.malignant_count;
        results(sample_idx).region_count = summary.region_count;
    end
end

function [feature_mean, feature_std] = readmodelnormalization(model)
    if isfield(model, 'feature_mean') && isfield(model, 'feature_std')
        feature_mean = model.feature_mean;
        feature_std = model.feature_std;
        return;
    end

    if isfield(model, 'mu') && isfield(model, 'sigma')
        feature_mean = model.mu;
        feature_std = model.sigma;
        return;
    end

    error('predicttissuemap:MissingNormalizationStats', ...
        'Model must contain feature_mean/feature_std normalization values.');
end
