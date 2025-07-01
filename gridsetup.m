function interactive_tumor_phantom()
    % Create figure
    clf; % Clear the current figure
    hold on; % Retain current plot when adding new plots
    axis equal; % Set equal scaling for both axes
    box on; % Enable the box around the axes
    f = figure('Name', 'Interactive Tumor Phantom', ...
               'NumberTitle', 'off', ...
               'Position', [200 200 800 600]);

    % Base phantom parameters
    grid_size = 7;
    spacing = 5;
    phantom_radius = 35;

    % UI slider limits
    xlim_slider = [-phantom_radius, phantom_radius];
    ylim_slider = [-phantom_radius, phantom_radius];
    rlim_slider = [2, 15];  % Radius from 2 mm to 15 mm

    % Default tumor values
    tumor = struct('x', 0, 'y', 0, 'r', 5);

    % Create axes
    ax = axes('Parent', f, 'Position', [0.3, 0.15, 0.65, 0.75]);
    update_plot();

    % --- Sliders ---
    % X position
    uicontrol(f, 'Style', 'text', 'String', 'X Position', ...
              'Position', [30 500 100 20]);
    sx = uicontrol(f, 'Style', 'slider', ...
              'Min', xlim_slider(1), 'Max', xlim_slider(2), ...
              'Value', tumor.x, ...
              'Position', [30 480 200 20], ...
              'Callback', @(src, ~) update_value('x', src.Value));

    % Y position
    uicontrol(f, 'Style', 'text', 'String', 'Y Position', ...
              'Position', [30 430 100 20]);
    sy = uicontrol(f, 'Style', 'slider', ...
              'Min', ylim_slider(1), 'Max', ylim_slider(2), ...
              'Value', tumor.y, ...
              'Position', [30 410 200 20], ...
              'Callback', @(src, ~) update_value('y', src.Value));

    % Radius
    uicontrol(f, 'Style', 'text', 'String', 'Diameter (mm)', ...
              'Position', [30 360 100 20]);
    sr = uicontrol(f, 'Style', 'slider', ...
              'Min', rlim_slider(1), 'Max', rlim_slider(2), ...
              'Value', tumor.r, ...
              'Position', [30 340 200 20], ...
              'Callback', @(src, ~) update_value('r', src.Value));

    % --- Nested function to update values and redraw ---
    function update_value(field, val)
        tumor.(field) = val;
        update_plot();
    end

    % --- Nested function to update the plot ---
    function update_plot()
        cla(ax); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on');
        set(ax, 'XLim', [-phantom_radius, phantom_radius], ...
                'YLim', [-phantom_radius, phantom_radius]);
        title(ax, sprintf('Tumor Center: (%.1f, %.1f), Diameter: %.1f mm', ...
                          tumor.x, tumor.y, tumor.r));

        % Draw boundary
        theta = linspace(0, 2*pi, 200);
        plot(ax, phantom_radius*cos(theta), ...
                  phantom_radius*sin(theta), 'k', 'LineWidth', 1);

        % Grid points
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