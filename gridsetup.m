function gridsetup()
    % Interactive phantom editor with support for up to three tumors.

    clf;
    f = figure('Name', 'Interactive Tumor Phantom', ...
               'NumberTitle', 'off', ...
               'Position', [120 120 980 640]);

    % Base phantom parameters
    grid_size = 35;
    spacing = 1;
    phantom_radius = 35;

    % UI input limits
    x_limits = [-phantom_radius, phantom_radius];
    y_limits = [-phantom_radius, phantom_radius];
    diameter_limits = [2, 30];

    tumors = repmat(struct('id', 1, 'enabled', false, 'x', 0, 'y', 0, 'r', 5), 1, 3);
    for tumor_idx = 1:numel(tumors)
        tumors(tumor_idx).id = tumor_idx;
    end
    tumors(1).enabled = true;

    ax = axes('Parent', f, 'Position', [0.35, 0.13, 0.61, 0.79]);

    control_left = 24;
    column_width = 70;
    gap = 10;
    base_y = 560;
    row_height = 108;
    input_width = 56;
    label_height = 18;
    edit_height = 24;

    tumor_colors = [
        0.85, 0.33, 0.10;
        0.00, 0.45, 0.74;
        0.47, 0.67, 0.19
    ];

    control_handles = repmat(struct('enabled', [], 'x', [], 'y', [], 'r', []), 1, numel(tumors));

    for tumor_idx = 1:numel(tumors)
        top_y = base_y - (tumor_idx - 1) * row_height;
        row_label = sprintf('Tumor %d', tumor_idx);

        uicontrol(f, 'Style', 'text', ...
                     'String', row_label, ...
                     'HorizontalAlignment', 'left', ...
                     'FontWeight', 'bold', ...
                     'Position', [control_left, top_y, 120, 20]);

        control_handles(tumor_idx).enabled = uicontrol( ...
            f, 'Style', 'checkbox', ...
            'String', 'Enabled', ...
            'Value', double(tumors(tumor_idx).enabled), ...
            'Position', [control_left + 118, top_y - 2, 90, 24], ...
            'Callback', @control_change_callback);

        label_y = top_y - 26;
        edit_y = top_y - 48;

        uicontrol(f, 'Style', 'text', ...
                     'String', 'X (mm)', ...
                     'Position', [control_left, label_y, column_width, label_height]);
        control_handles(tumor_idx).x = uicontrol( ...
            f, 'Style', 'edit', ...
            'String', num2str(tumors(tumor_idx).x), ...
            'Position', [control_left, edit_y, input_width, edit_height], ...
            'Callback', @control_change_callback);

        x2 = control_left + column_width + gap;
        uicontrol(f, 'Style', 'text', ...
                     'String', 'Y (mm)', ...
                     'Position', [x2, label_y, column_width, label_height]);
        control_handles(tumor_idx).y = uicontrol( ...
            f, 'Style', 'edit', ...
            'String', num2str(tumors(tumor_idx).y), ...
            'Position', [x2, edit_y, input_width, edit_height], ...
            'Callback', @control_change_callback);

        x3 = x2 + column_width + gap;
        uicontrol(f, 'Style', 'text', ...
                     'String', 'Diameter', ...
                     'Position', [x3, label_y, column_width, label_height]);
        control_handles(tumor_idx).r = uicontrol( ...
            f, 'Style', 'edit', ...
            'String', num2str(tumors(tumor_idx).r), ...
            'Position', [x3, edit_y, input_width, edit_height], ...
            'Callback', @control_change_callback);
    end

    uicontrol(f, 'Style', 'pushbutton', ...
                 'String', 'Update Phantom', ...
                 'Position', [control_left, 210, 230, 34], ...
                 'Callback', @update_button_callback);

    uicontrol(f, 'Style', 'text', ...
                 'String', 'Tip: enable 1-3 tumors, then click Update Phantom.', ...
                 'HorizontalAlignment', 'left', ...
                 'Position', [control_left, 174, 280, 20]);

    update_plot();

    function control_change_callback(~, ~)
        [parsed_tumors, is_valid] = read_tumors_from_controls(false);
        if ~is_valid
            return;
        end

        tumors = parsed_tumors;
        update_plot();
    end

    function update_button_callback(~, ~)
        [parsed_tumors, is_valid] = read_tumors_from_controls(true);
        if ~is_valid
            return;
        end

        tumors = parsed_tumors;
        update_plot();

        active_tumors = tumors([tumors.enabled]);
        if isempty(active_tumors)
            disp('No tumors enabled. Update the phantom to visualize an empty case.');
            return;
        end

        current_uA = 100;
        disp('Solving voltage field with updated phantom...');
        try
            Vdiff = solvevoltage(active_tumors, current_uA);
            fprintf('Voltage difference between electrodes: %.6f V\n', Vdiff);
        catch err
            disp(['Error in solvevoltage: ', err.message]);
        end
    end

    function [parsed_tumors, is_valid] = read_tumors_from_controls(show_error_dialog)
        parsed_tumors = tumors;
        is_valid = true;

        for idx = 1:numel(control_handles)
            enabled = logical(control_handles(idx).enabled.Value);
            x = str2double(control_handles(idx).x.String);
            y = str2double(control_handles(idx).y.String);
            r = str2double(control_handles(idx).r.String);

            if any(isnan([x, y, r]))
                if show_error_dialog
                    errordlg(sprintf('Tumor %d has invalid numeric input.', idx), 'Input Error');
                end
                is_valid = false;
                return;
            end

            parsed_tumors(idx).enabled = enabled;
            parsed_tumors(idx).x = clamp_value(x, x_limits);
            parsed_tumors(idx).y = clamp_value(y, y_limits);
            parsed_tumors(idx).r = clamp_value(r, diameter_limits);

            control_handles(idx).x.String = num2str(parsed_tumors(idx).x);
            control_handles(idx).y.String = num2str(parsed_tumors(idx).y);
            control_handles(idx).r.String = num2str(parsed_tumors(idx).r);
        end
    end

    function update_plot()
        cla(ax);
        hold(ax, 'on');
        axis(ax, 'equal');
        box(ax, 'on');
        set(ax, 'XLim', [-phantom_radius, phantom_radius], ...
                'YLim', [-phantom_radius, phantom_radius]);

        theta = linspace(0, 2 * pi, 200);
        plot(ax, phantom_radius * cos(theta), ...
                 phantom_radius * sin(theta), ...
                 'k', 'LineWidth', 1.2);

        [x_grid, y_grid] = meshgrid( ...
            linspace(-spacing * (grid_size - 1) / 2, spacing * (grid_size - 1) / 2, grid_size), ...
            linspace(-spacing * (grid_size - 1) / 2, spacing * (grid_size - 1) / 2, grid_size));
        plot(ax, x_grid(:), y_grid(:), 'k.', 'MarkerSize', 8);

        active_tumors = tumors([tumors.enabled]);
        for idx = 1:numel(active_tumors)
            tumor = active_tumors(idx);
            radius = tumor.r / 2;
            fill_color = 0.65 * tumor_colors(idx, :) + 0.35 * [1, 1, 1];
            rectangle(ax, ...
                'Position', [tumor.x - radius, tumor.y - radius, 2 * radius, 2 * radius], ...
                'Curvature', [1, 1], ...
                'FaceColor', fill_color, ...
                'EdgeColor', tumor_colors(idx, :), ...
                'LineWidth', 1.4);
            text(ax, tumor.x, tumor.y, sprintf('%d', tumor.id), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', ...
                'Color', tumor_colors(idx, :));
        end

        if isempty(active_tumors)
            title(ax, 'Tumor Phantom: no tumors enabled');
        else
            title(ax, sprintf('Tumor Phantom with %d active tumor(s)', numel(active_tumors)));
        end
    end
end

function value = clamp_value(value, limits)
    value = max(min(value, limits(2)), limits(1));
end
