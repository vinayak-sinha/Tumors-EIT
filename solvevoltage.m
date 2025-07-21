function Vdiff = solvevoltage(tumor, fixed_el_pos, movable_el_pos, current_uA)
    % SOLVE_VOLTAGE: Solves ∇·(σ∇u) = 0 using finite difference
    % for a circular phantom with adipose background and a tumor inclusion.
    %
    % Inputs:
    % - tumor: struct with fields x, y, r (center and diameter in mm)
    % - fixed_el_pos: [x, y] of fixed electrode in mm
    % - movable_el_pos: [x, y] of movable electrode in mm
    % - current_uA: injected current in microamperes
    % - freq_kHz: frequency in kilohertz (not used in DC model)
    %
    % Output:
    % - Vdiff: voltage difference in volts

    % ----- PARAMETERS -----
    phantom_radius = 35;     % mm
    dx = 1.0;                % mm spatial resolution
    fat_sigma = 0.04;        % S/m for adipose tissue
    tumor_sigma = 0.4;       % S/m for tumor
    current = current_uA * 1e-6;  % A

    % ----- SETUP GRID -----
    x = -phantom_radius:dx:phantom_radius;
    y = -phantom_radius:dx:phantom_radius;
    [X, Y] = meshgrid(x, y);
    [Ny, Nx] = size(X);
    N = Nx * Ny;

    % ----- BUILD CONDUCTIVITY MAP -----
    sigma = fat_sigma * ones(size(X));
    tumor_mask = (X - tumor.x).^2 + (Y - tumor.y).^2 <= (tumor.r / 2)^2;
    sigma(tumor_mask) = tumor_sigma;

    % ----- INDEXING FUNCTION -----
    idx = @(i,j) (j-1)*Ny + i;

    % ----- MATRIX ASSEMBLY -----
    rows = [];
    cols = [];
    vals = [];
    b = zeros(N, 1);

    k = 1;
    for i = 1:Ny
        for j = 1:Nx
            p = idx(i,j);
            s_center = 0;

            % --- Left (i,j-1) ---
            if j > 1
                s_left = sigma(i,j-1);
                rows(k) = p; cols(k) = idx(i,j-1); vals(k) = s_left; k = k + 1;
                s_center = s_center + s_left;
            else
                % Neumann BC: mirror left neighbor as self
                s_left = sigma(i,j);
                s_center = s_center + s_left;
            end

            % --- Right (i,j+1) ---
            if j < Nx
                s_right = sigma(i,j+1);
                rows(k) = p; cols(k) = idx(i,j+1); vals(k) = s_right; k = k + 1;
                s_center = s_center + s_right;
            else
                s_right = sigma(i,j);
                s_center = s_center + s_right;
            end

            % --- Top (i-1,j) ---
            if i > 1
                s_up = sigma(i-1,j);
                rows(k) = p; cols(k) = idx(i-1,j); vals(k) = s_up; k = k + 1;
                s_center = s_center + s_up;
            else
                s_up = sigma(i,j);
                s_center = s_center + s_up;
            end

            % --- Bottom (i+1,j) ---
            if i < Ny
                s_down = sigma(i+1,j);
                rows(k) = p; cols(k) = idx(i+1,j); vals(k) = s_down; k = k + 1;
                s_center = s_center + s_down;
            else
                s_down = sigma(i,j);
                s_center = s_center + s_down;
            end

            % --- Center (i,j) ---
            rows(k) = p; cols(k) = p; vals(k) = -s_center; k = k + 1;
        end
    end

    % Final sparse matrix
    rows = rows(1:k-1);
    cols = cols(1:k-1);
    vals = vals(1:k-1);
    A = sparse(rows, cols, vals, N, N);

    % ----- CURRENT INJECTION POINTS -----
    movable_idx = find_closest_index(X, Y, movable_el_pos);
    fixed_idx   = find_closest_index(X, Y, fixed_el_pos);
    b(movable_idx) =  current;
    b(fixed_idx)   = -current;

    % ----- SOLVE SYSTEM -----
    u = A \ b;
    U = reshape(u, Ny, Nx);

    % ----- READ VOLTAGE -----
    V1 = U(movable_idx);
    V2 = U(fixed_idx);
    Vdiff = V1 - V2;
end

function ind = find_closest_index(X, Y, pt)
    dist2 = (X - pt(1)).^2 + (Y - pt(2)).^2;
    [~, linear_idx] = min(dist2(:));
    ind = linear_idx;
end