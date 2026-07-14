# Tumors-EIT

MATLAB project for simulating electrical impedance tomography (EIT) tissue phantoms and training a multilayer perceptron (MLP) surrogate to map voltage measurements back to healthy, benign, and malignant tissue regions.

## What This Project Does

- Builds an interactive forward simulation of a circular tissue phantom with up to three tumors.
- Solves the voltage response of that phantom using a grid-based conductivity model.
- Generates synthetic EIT datasets from many randomized phantoms.
- Trains a neural-network surrogate on those synthetic measurements.
- Predicts tissue-class maps and connected tumor-region summaries from saved feature data.

## Repository Layout

- `runsimulation.m`
  One-command launcher for the interactive phantom simulation.
- `gridsetup.m`
  Interactive phantom editor for tumor count, location, and diameter.
- `solvevoltage.m`
  Forward solver that computes conductivity maps and electrode voltage differences.
- `runmlpipeline.m`
  One-command launcher for the machine-learning workflow UI.
- `generatesyntheticdataset.m`
  Builds synthetic datasets of voltage features and tissue maps.
- `traintissuemapper.m`
  Trains the MLP and writes model, metrics, and preview artifacts.
- `predicttissuemap.m`
  Loads a trained model and predicts tissue maps from feature vectors.
- `analyzetissuemap.m`
  Extracts connected benign and malignant region summaries from predicted maps.

## Requirements

- MATLAB
- Deep Learning Toolbox
  Required for MLP training because `traintissuemapper` uses `fitnet`.

Without Deep Learning Toolbox:

- The forward simulation still works.
- Dataset generation still works.
- The training step does not work.

## Quick Start

### Forward Simulation

Run this in the MATLAB Command Window:

```matlab
runsimulation
```

What happens:

- The phantom editor opens.
- You can enable up to three tumors.
- You can set each tumor's `x`, `y`, and diameter.
- The phantom preview updates in the UI.
- The voltage-solver figure opens only when you click `Update Phantom`.

### ML Pipeline

Run this in the MATLAB Command Window:

```matlab
runmlpipeline
```

The launcher supports four actions:

- `Generate Dataset Only`
- `Train Only`
- `Train and Test`
- `Predict Existing Features`

The UI asks only for the inputs needed for the selected action and supports:

- text entry for numeric settings
- dropdowns for action type, drive pattern, and training algorithm
- file pickers for dataset, model, feature, and output files
- folder pickers for artifact output

## Recommended ML Workflow

For the easiest full run:

1. Launch `runmlpipeline`.
2. Choose `Train and Test`.
3. Click `Apply High-Accuracy Preset`.
4. Keep `Drive Pattern` set to `hybrid`.
5. Click `Run Selected Action`.

The high-accuracy preset currently uses:

- `3000` samples
- output size `24`
- `8` electrodes
- `hybrid` drive pattern
- hidden layers `512, 256, 128`
- `300` epochs
- validation fraction `0.15`
- test fraction `0.15`
- training algorithm `trainscg`

## Dataset Generation

You can generate a dataset directly without the UI:

```matlab
cfg = struct();
cfg.num_electrodes = 8;
cfg.drive_pattern = 'hybrid';
cfg.benign_count_range = [0 2];
cfg.malignant_count_range = [0 3];

dataset = generatesyntheticdataset(2000, fullfile('artifacts', 'syntheticeitdataset.mat'), 24, cfg);
```

Key configurable dataset settings:

- `num_electrodes`
- `drive_pattern`
  Allowed values: `opposite`, `adjacent`, `hybrid`
- `benign_count_range`
- `malignant_count_range`
- `output_size`
- `num_samples`

## Training

You can also train directly:

```matlab
cfg = struct();
cfg.output_size = 24;
cfg.num_electrodes = 8;
cfg.drive_pattern = 'hybrid';
cfg.benign_count_range = [0 2];
cfg.malignant_count_range = [0 3];
cfg.hidden_layer_sizes = [512 256 128];
cfg.epochs = 300;
cfg.train_algorithm = 'trainscg';
cfg.validation_fraction = 0.15;
cfg.test_fraction = 0.15;
cfg.execution_mode = 'trainandtest';

metrics = traintissuemapper(2000, fullfile('artifacts', 'syntheticeitdataset.mat'), 'artifacts', cfg);
```

Supported execution modes:

- `trainonly`
- `trainandtest`

Important behavior:

- If the dataset file already exists but its sample count, output size, electrode count, drive pattern, or tumor-count ranges do not match the requested settings, the dataset is regenerated automatically.

## Prediction

Prediction can run from the UI or directly:

```matlab
loaded = load(fullfile('artifacts', 'syntheticeitdataset.mat'), 'features');
results = predicttissuemap(loaded.features(1:5, :), fullfile('artifacts', 'tissuemappermodel.mat'));
```

Prediction output includes:

- `class_map`
- `raw_scores`
- `summary`
- `benign_count`
- `malignant_count`
- `region_count`

## Prediction Feature Files

The UI prediction path accepts:

- `.mat`
- `.csv`
- `.txt`

Feature-file expectations:

- The data must be numeric.
- The shape must be `N x feature_count`.
- If a `.mat` file contains multiple numeric variables, the UI prompts you to choose which one to use.

## Saved Artifacts

Training writes these files to `artifacts/`:

- `syntheticeitdataset.mat`
- `tissuemappermodel.mat`
- `tissuemappermetrics.mat`
- `tissuemappermetrics.txt`
- `tissuemapperpreview.mat`
- `tissuemapperpreview.png`

The metrics report includes:

- dataset generation time
- seconds per sample
- forward solve count
- training time
- evaluation time
- total runtime
- train / validation / test performance
- preview region summaries

## Notes On Accuracy

The current code improves accuracy mainly through:

- richer drive patterns via `hybrid`
- larger default training networks
- more epochs
- larger training datasets
- adjustable validation and test fractions

Pixel accuracy is useful, but it does not fully capture tumor-detection quality. A future improvement would be to add lesion-level metrics such as region-count error, centroid error, and benign/malignant detection accuracy.

## Current Limitations

- Training depends on MATLAB Deep Learning Toolbox.
- The project has not been fully runtime-verified from this environment because local MATLAB CLI startup is failing here.
- The MLP is trained on synthetic data, so performance depends heavily on how realistic the phantom generator is.

## Research Context

The repository also contains several local PDF references used during project development. Those papers are not required to run the code, but they provide context for conductivity assumptions, EIT modeling choices, and related reconstruction strategies.
