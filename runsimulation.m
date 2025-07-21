% run_simulation.m
clc; clear; close all;

% --- Step 1: Launch interactive phantom
disp('Launching tumor editor...');
gridsetup();  % Let the user configure tumor

disp('Close the GUI when done, then press any key to continue...');
pause;  % Wait for user to finish

% --- Step 2: Get tumor from workspace
if evalin('base', 'exist(''tumor'', ''var'')')
    tumor = evalin('base', 'tumor');
else
    error('Tumor struct not found. Did you run gridsetup and exit cleanly?');
end

% --- Step 3: Define electrodes (in mm)
fixed_el_pos = [-25, 20];    % Example: on left side
movable_el_pos = [0, 0];     % Example: center
current_uA = 100;            % 100 microamperes

% --- Step 4: Call solver
fprintf('Solving voltage field...\n');
Vdiff = solvevoltage(tumor, fixed_el_pos, movable_el_pos, current_uA);

% --- Step 5: Report result
fprintf('Voltage difference between electrodes: %.6f V\n', Vdiff);