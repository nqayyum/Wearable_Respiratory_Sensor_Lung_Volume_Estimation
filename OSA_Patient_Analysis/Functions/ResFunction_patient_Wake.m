%% Model calibration (lung volume prediction using RIP signals)
function resFun = ResFunction_patient_Wake(p, ...
    Start_Breath_NB, End_Breath_NB, Start_Breath_FRC, ...
    Start_Asy, End_Asy, ...
    equation, C_n, A_n, ...
    TV, FRC, dV_apnea, ...
    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max, abs_min)

resFun = [];

% Calibration points (FRC and end inspiration)
% FRC calibration uses analysis region while the remaining is on the whole signal
idx_FRC_all  = Start_Breath_FRC(:); % For FRC calibration
idx_TVs_all  = Start_Breath_NB(:); % For TV calibration
idx_TVe_all  = End_Breath_NB(:); % For TV calibration
idx_Apnea_s_all = Start_Asy(:); % For apnea calibration (starting point)
idx_Apnea_e_all = End_Asy(:); % For apnea calibration (ending point)

% Signal calibration and reference values
A_FRC = A_n(idx_FRC_all); C_FRC = C_n(idx_FRC_all);
% Apnea indicies are from whole signal so convert to same scale as analysis region
A_apnea_s = (Abdomen_S1(idx_Apnea_s_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon; C_apnea_s = (Chest_S1(idx_Apnea_s_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon;
A_apnea_e = (Abdomen_S1(idx_Apnea_e_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon; C_apnea_e = (Chest_S1(idx_Apnea_e_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon;
% TV indicies are from whole signal so convert to same scale as analysis region
A_TV_s = (Abdomen_S1(idx_TVs_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon; C_TV_s = (Chest_S1(idx_TVs_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon;
A_TV_e = (Abdomen_S1(idx_TVe_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon; C_TV_e = (Chest_S1(idx_TVe_all) - abs_min)*(1 - epsilon)/(abs_max - abs_min) + epsilon;

% Residual weights (equal weights for normal breathing and apneas)
NB_res = 2; scale_NB = sqrt(1/NB_res);
for i=1:length(Start_Asy) % Don't need to scale this portion as a ratio is being used
    C_n_Asy = abs(Chest_S1(End_Asy(i))-Chest_S1(Start_Asy(i)));
    A_n_Asy = abs(Abdomen_S1(End_Asy(i))-Abdomen_S1(Start_Asy(i)));
    mean_amp_change(i) = 0.5*(C_n_Asy + A_n_Asy);
end
weights_Asy = sqrt((mean_amp_change/sum(mean_amp_change)));

if equation == 1 % V = M*(C + K*A)
    % FRC and TV points
    X_TV_s  = C_TV_s  + K*A_TV_s;   % per-breath inspiration points for TV in signal units
    X_TV_e = C_TV_e + K*A_TV_e;     % per-breath expiration points for TV signal units

    M = TV/(mean(X_TV_e) - mean(X_TV_s));
    V_linear = M*(C_n + K*A_n);
    vert_shift = FRC - mean(V_linear(idx_FRC_all));
    max_FRC_ratio = abs(max(V_linear)/mean(V_linear(idx_FRC_all)));
    min_FRC_ratio = abs(min(V_linear)/mean(V_linear(idx_FRC_all)));
    resFun = [M, K, vert_shift, max_FRC_ratio, min_FRC_ratio];

elseif equation == 9
    % V = M*(C_n + K*A_n^n)
    % FRC and TV points
    X_FRC  = C_FRC  + p(2)*A_FRC.^p(3);      % per-breath FRC points in signal units
    X_TV = (C_TV_e + p(2)*A_TV_e.^p(3)) - (C_TV_s + p(2)*A_TV_s.^p(3));     % per-breath TV points in signal units

    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;
        p(1)*mean(X_TV) - TV];
    resFun = [resFun; r_NB];

    % Apnea calibration
    for n=1:length(Start_Asy)
        apnea_change(n) = p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n).^p(3)) - p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n).^p(3));
        % Only apply residual if actual change is greater than tolerance
        if abs(apnea_change(n)) > dV_apnea
            r_apnea = weights_Asy(n) * apnea_change(n);
        else
            r_apnea = 0;
        end
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + p(2)*A_n.^p(3));
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];
    % Did not include penalty term for K as added power affects overall chest and abdominal contribution

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end
else
    X_FRC  = p(1)*(C_FRC  + p(2)*A_FRC) + p(3);      % per-breath FRC points in signal units
    X_TV = (p(1)*(C_TV_e + p(2)*A_TV_e) + p(3)) - (p(1)*(C_TV_s + p(2)*A_TV_s) + p(3));     % per-breath TV points in signal units

    r_NB = scale_NB * [mean(X_FRC)  - FRC;
        mean(X_TV) - TV];
    resFun = [resFun; r_NB];

    % Apnea calibration
    for n=1:length(Start_Asy)
        apnea_change(n) = (p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n)) + p(3)) - (p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n)) + p(3));
        % Only apply residual if actual change is greater than tolerance
        if abs(apnea_change(n)) > dV_apnea
            r_apnea = weights_Asy(n) * apnea_change(n);
        else
            r_apnea = 0;
        end
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + p(2)*A_n) + p(3);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n));
        sqrt(w)*(p(2) - K)];
end
