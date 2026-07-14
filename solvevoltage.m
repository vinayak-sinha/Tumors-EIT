function Vdiff = solvevoltage(tumors, current_uA)
    % Solve the forward problem for one or more tumors.
    % Click two points: fixed electrode, then movable electrode.

    phantom_radius = 35;   % mm
    dx = 0.5;              % mm
    fat_sigma = 0.04;      % S/m
    tumor_sigma = 0.4;     % S/m
    current = current_uA * 1e-6;

    tumors = normalize_tumor_input(tumors);

    x = -phantom_radius:dx:phantom_radius;
    y = -phantom_radius:dx:phantom_radius;
    [X, Y] = meshgrid(x, y);
    [Ny, Nx] = size(X);
    N = Nx * Ny;
    idx = @(i, j) (j - 1) * Ny + i;

    sigma = fat_sigma * ones(size(X));
    tumor_mask = false(size(X));

    for tumor_idx = 1:numel(tumors)
        tumor = tumors(tumor_idx);
        tumor_mask = tumor_mask | ((X - tumor.x).^2 + (Y - tumor.y).^2 <= (tumor.r / 2)^2);
    end
    sigma(tumor_mask) = tumor_sigma;

    figure('Name', 'Click Fixed Electrode, then Movable Electrode');
    imagesc(x, y, sigma);
    axis equal tight;
    set(gca, 'YDir', 'normal');
    xlabel('x (mm)');
    ylabel('y (mm)');
    title(sprintf('Click Fixed Electrode, then Movable Electrode (%d tumor(s))', numel(tumors)));
    colorbar;
    [x_clicks, y_clicks] = ginput(2);
    fixed_el_pos = [x_clicks(1), y_clicks(1)];
    movable_el_pos = [x_clicks(2), y_clicks(2)];
    close(gcf);

    max_entries = Ny * Nx * 5;
    rows = zeros(1, max_entries);
    cols = zeros(1, max_entries);
    vals = zeros(1, max_entries);
    b = zeros(N, 1);
    k = 1;

    for i = 1:Ny
        for j = 1:Nx
            p = idx(i, j);
            s_center = 0;

            if j > 1
                s_left = sigma(i, j - 1);
                rows(k) = p;
                cols(k) = idx(i, j - 1);
                vals(k) = s_left;
                k = k + 1;
                s_center = s_center + s_left;
            else
                s_center = s_center + sigma(i, j);
            end

            if j < Nx
                s_right = sigma(i, j + 1);
                rows(k) = p;
                cols(k) = idx(i, j + 1);
                vals(k) = s_right;
                k = k + 1;
                s_center = s_center + s_right;
            else
                s_center = s_center + sigma(i, j);
            end

            if i > 1
                s_up = sigma(i - 1, j);
                rows(k) = p;
                cols(k) = idx(i - 1, j);
                vals(k) = s_up;
                k = k + 1;
                s_center = s_center + s_up;
            else
                s_center = s_center + sigma(i, j);
            end

            if i < Ny
                s_down = sigma(i + 1, j);
                rows(k) = p;
                cols(k) = idx(i + 1, j);
                vals(k) = s_down;
                k = k + 1;
                s_center = s_center + s_down;
            else
                s_center = s_center + sigma(i, j);
            end

            rows(k) = p;
            cols(k) = p;
            vals(k) = -s_center;
            k = k + 1;
        end
    end

    rows = rows(1:k - 1);
    cols = cols(1:k - 1);
    vals = vals(1:k - 1);
    A = sparse(rows, cols, vals, N, N);

    movable_idx = find_closest_index(X, Y, movable_el_pos);
    fixed_idx = find_closest_index(X, Y, fixed_el_pos);
    b(movable_idx) = current;
    b(fixed_idx) = -current;

    u = A \ b;
    U = reshape(u, Ny, Nx);

    V1 = U(movable_idx);
    V2 = U(fixed_idx);
    Vdiff = V2 - V1;
    fprintf('Voltage at fixed electrode: %.6f V\n', V2);
    fprintf('Voltage at movable electrode: %.6f V\n', V1);

    figure('Name', 'Voltage Field with Tumors');
    contour(x, y, U, 100, 'LineWidth', 1);
    axis equal tight;
    set(gca, 'YDir', 'normal');
    xlabel('x (mm)');
    ylabel('y (mm)');
    colorbar;
    title(sprintf('Voltage Field Contours with %d Tumor(s)', numel(tumors)));
    hold on;

    legend_handles = gobjects(0);
    legend_labels = {};

    legend_handles(end + 1) = plot(movable_el_pos(1), movable_el_pos(2), 'ro', 'MarkerSize', 10, 'LineWidth', 2); %#ok<AGROW>
    legend_labels{end + 1} = 'Movable Electrode'; %#ok<AGROW>

    legend_handles(end + 1) = plot(fixed_el_pos(1), fixed_el_pos(2), 'ko', 'MarkerSize', 10, 'LineWidth', 2); %#ok<AGROW>
    legend_labels{end + 1} = 'Fixed Electrode'; %#ok<AGROW>

    tumor_colors = {'b', 'm', 'g'};
    theta = linspace(0, 2 * pi, 200);
    for tumor_idx = 1:numel(tumors)
        tumor = tumors(tumor_idx);
        xt = tumor.r / 2 * cos(theta) + tumor.x;
        yt = tumor.r / 2 * sin(theta) + tumor.y;
        color = tumor_colors{min(tumor_idx, numel(tumor_colors))};
        legend_handles(end + 1) = plot(xt, yt, color, 'LineWidth', 2); %#ok<AGROW>
        legend_labels{end + 1} = sprintf('Tumor %d', tumor.id); %#ok<AGROW>
    end

    legend(legend_handles, legend_labels, 'Location', 'bestoutside');
end

function tumors = normalize_tumor_input(tumors)
    if isempty(tumors)
        error('solvevoltage:NoTumors', 'At least one tumor must be provided.');
    end

    if ~isstruct(tumors)
        error('solvevoltage:InvalidTumorInput', 'Tumor input must be a struct or struct array.');
    end

    if isfield(tumors, 'enabled')
        tumors = tumors([tumors.enabled]);
        if isempty(tumors)
            error('solvevoltage:NoEnabledTumors', 'At least one enabled tumor is required.');
        end
    end

    required_fields = {'x', 'y', 'r'};
    for field_idx = 1:numel(required_fields)
        if ~isfield(tumors, required_fields{field_idx})
            error('solvevoltage:MissingField', ...
                'Tumor input must include fields x, y, and r.');
        end
    end

    if ~isfield(tumors, 'id')
        for tumor_idx = 1:numel(tumors)
            tumors(tumor_idx).id = tumor_idx;
        end
    end
end

function ind = find_closest_index(X, Y, pt)
    dist2 = (X - pt(1)).^2 + (Y - pt(2)).^2;
    [~, linear_idx] = min(dist2(:));
    ind = linear_idx;
end
