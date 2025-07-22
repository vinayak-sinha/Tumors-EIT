function gridsetup()
    % Create figure
    clf;
    hold on;
    axis equal;
    box on;
    f = figure('Name', 'Interactive Tumor Phantom', ...
               'NumberTitle', 'off', ...
               'Position', [200 200 800 600]);

    % Base phantom parameters
    grid_size = 35;
    spacing = 1;
    phantom_radius = 35;

    % UI input limits
    xlim_slider = [-phantom_radius, phantom_radius];
    ylim_slider = [-phantom_radius, phantom_radius];
    rlim_slider = [2, 30];

    % Default tumor values
    tumor = struct('x', 0, 'y', 0, 'r', 5);

    % Create axes
    ax = axes('Parent', f, 'Position', [0.3, 0.15, 0.65, 0.75]);
    update_plot();

    % Input labels and boxes
    uicontrol(f, 'Style', 'text', 'String', 'X Position (mm)', ...
              'Position', [30 500 100 20]);
    ex = uicontrol(f, 'Style', 'edit', ...
              'String', num2str(tumor.x), ...
              'Position', [30 480 200 25]);

    uicontrol(f, 'Style', 'text', 'String', 'Y Position (mm)', ...
              'Position', [30 430 100 20]);
    ey = uicontrol(f, 'Style', 'edit', ...
              'String', num2str(tumor.y), ...
              'Position', [30 410 200 25]);

    uicontrol(f, 'Style', 'text', 'String', 'Diameter (mm)', ...
              'Position', [30 360 100 20]);
    er = uicontrol(f, 'Style', 'edit', ...
              'String', num2str(tumor.r), ...
              'Position', [30 340 200 25]);

    % Update button
    uicontrol(f, 'Style', 'pushbutton', 'String', 'Update Tumor', ...
              'Position', [30 290 200 30], ...
              'Callback', @update_button_callback);

    % Callback for Update Button
    function update_button_callback(~, ~)
        x = str2double(ex.String);
        y = str2double(ey.String);
        r = str2double(er.String);

        if any(isnan([x y r]))
            errordlg('Please enter valid numbers.', 'Input Error');
            return;
        end

        % Clamp values to limits
        tumor.x = max(min(x, xlim_slider(2)), xlim_slider(1));
        tumor.y = max(min(y, ylim_slider(2)), ylim_slider(1));
        tumor.r = max(min(r, rlim_slider(2)), rlim_slider(1));

        update_plot();

        % Make tumor struct available to run_simulation.m
        % assignin('base', 'tumor', tumor);

        current_uA = 100;  % Or let user choose later
        disp('Solving voltage field with updated tumor...');
        try
            Vdiff = solvevoltage(tumor, current_uA);
            fprintf('Voltage difference between electrodes: %.6f V\n', Vdiff);
        catch err
            disp(['Error in solve_voltage: ', err.message]);
        end
    end

    % Function to redraw the plot
    function update_plot()
        cla(ax); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on');
        set(ax, 'XLim', [-phantom_radius, phantom_radius], ...
                'YLim', [-phantom_radius, phantom_radius]);
        title(ax, sprintf('Tumor Center: (%.1f, %.1f), Diameter: %.1f mm', ...
                          tumor.x, tumor.y, tumor.r));

        % Draw circular phantom boundary
        theta = linspace(0, 2*pi, 200);
        plot(ax, phantom_radius*cos(theta), ...
                  phantom_radius*sin(theta), 'k', 'LineWidth', 1);

        % Draw grid points
        [x_grid, y_grid] = meshgrid( ...
            linspace(-spacing*(grid_size-1)/2, spacing*(grid_size-1)/2, grid_size), ...
            linspace(-spacing*(grid_size-1)/2, spacing*(grid_size-1)/2, grid_size));
        plot(ax, x_grid(:), y_grid(:), 'k.', 'MarkerSize', 10);

        % Draw tumor
        r = tumor.r / 2;
        rectangle(ax, 'Position', [tumor.x - r, tumor.y - r, 2*r, 2*r], ...
                  'Curvature', [1 1], ...
                  'FaceColor', [0.4 0.4 0.4], 'EdgeColor', 'none');
    end
end