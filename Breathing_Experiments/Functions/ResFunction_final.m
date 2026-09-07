%% Model calibration (lung volume prediction using RIP signals)
function resFun = ResFunction_final(p, ...
    Start_Breath_NB, End_Breath_NB, ...
    Start_Asy, End_Asy, ...
    equation, C_n, A_n, ...
    Insp_End, FRC, dV_apnea, ...
    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test)

resFun = []; % Initialize

% Calibration points (FRC and end inspiration)
idx_FRC_all  = Start_Breath_NB(:); % For FRC calibration
idx_Insp_all  = End_Breath_NB(:); % For TV calibration
idx_Apnea_s_all = Start_Asy(:); % For apnea calibration (starting point)
idx_Apnea_e_all = End_Asy(:); % For apnea calibration (ending point)

% Signal calibration and reference values
A_FRC = A_n(idx_FRC_all); C_FRC = C_n(idx_FRC_all); 
A_insp = A_n(idx_Insp_all); C_insp = C_n(idx_Insp_all); 
A_apnea_s = A_n(idx_Apnea_s_all); C_apnea_s = C_n(idx_Apnea_s_all);
A_apnea_e = A_n(idx_Apnea_e_all); C_apnea_e = C_n(idx_Apnea_e_all);
TV = Insp_End - FRC;

% Residual weights (equal weights for normal breathing and apneas)
NB_res = 2; scale_NB = sqrt(1/NB_res);
for i=1:length(Start_Asy)
    C_n_Asy = abs(C_n(End_Asy(i))-C_n(Start_Asy(i)));
    A_n_Asy = abs(A_n(End_Asy(i))-A_n(Start_Asy(i)));
    mean_amp_change(i) = 0.5*(C_n_Asy + A_n_Asy);
end
weights_Asy = sqrt((mean_amp_change/sum(mean_amp_change)));

if equation == 1 % V = M*(C + K*A)
    % FRC and TV points
    X_FRC  = C_FRC  + K*A_FRC;      % per-breath FRC points in signal units
    X_insp = C_insp + K*A_insp;     % per-breath FRC + TV points in signal units

    M = TV/(mean(X_insp) - mean(X_FRC));
    V_linear = M*(C_n + K*A_n);
    vert_shift = FRC - mean(V_linear(idx_FRC_all));
    max_FRC_ratio = abs(max(V_linear)/mean(V_linear(idx_FRC_all)));
    min_FRC_ratio = abs(min(V_linear)/mean(V_linear(idx_FRC_all)));
    resFun = [M, K, vert_shift, max_FRC_ratio, min_FRC_ratio];

elseif equation == 2 % V = M*(C + A)^n
    % FRC and TV points
    X_FRC  = (C_FRC  + A_FRC).^p(2);      % per-breath FRC points in signal units
    X_insp = (C_insp + A_insp).^p(2);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n) + A_apnea_e(n))^p(2) - p(1)*(C_apnea_s(n) + A_apnea_s(n))^p(2) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + A_n).^p(2);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 3 % V = M*(C + K*A)^n
    % FRC and TV points
    X_FRC  = (C_FRC  + p(2)*A_FRC).^p(3);      % per-breath FRC points in signal units
    X_insp = (C_insp + p(2)*A_insp).^p(3);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
 
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n))^p(3) - p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n))^p(3) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + p(2)*A_n).^p(3);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n));
        sqrt(w)*(p(2) - K)];

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 4 % V = M*(C^n + A^n)
    % FRC and TV points
    X_FRC  = C_FRC.^p(2)  + A_FRC.^p(2);      % per-breath FRC points in signal units
    X_insp = C_insp.^p(2) + A_insp.^p(2);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n)^p(2) + A_apnea_e(n)^p(2)) - p(1)*(C_apnea_s(n)^p(2) + A_apnea_s(n)^p(2)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n.^p(2) + A_n.^p(2));
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 5  % V = M*(C^n + A^m)
    % FRC and TV points
    X_FRC  = C_FRC.^p(2)  + A_FRC.^p(3);      % per-breath FRC points in signal units
    X_insp = C_insp.^p(2) + A_insp.^p(3);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n)^p(2) + A_apnea_e(n)^p(3)) - p(1)*(C_apnea_s(n)^p(2) + A_apnea_s(n)^p(3)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n.^p(2) + A_n.^p(3));
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 6 % V = M*(C^n + K*A^n)
    % FRC and TV points
    X_FRC  = C_FRC.^p(3)  + p(2)*A_FRC.^p(3);      % per-breath FRC points in signal units
    X_insp = C_insp.^p(3) + p(2)*A_insp.^p(3);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n)^p(3) + p(2)*A_apnea_e(n)^p(3)) - p(1)*(C_apnea_s(n)^p(3) + p(2)*A_apnea_s(n)^p(3)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n.^p(3) + p(2)*A_n.^p(3));
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];
    % Did not include penalty term for K as added powers affect balance of chest and abdominal signals

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 7 % V = M*(C + K*A + n*(C*A))
    % FRC and TV points
    X_FRC  = C_FRC  + p(2)*A_FRC + p(3)*C_FRC.*A_FRC;      % per-breath FRC points in signal units
    X_insp = C_insp  + p(2)*A_insp + p(3)*C_insp.*A_insp;  % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];

    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n) + p(3)*C_apnea_e(n)*A_apnea_e(n)) - p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n) + p(3)*C_apnea_s(n)*A_apnea_s(n)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + p(2)*A_n + p(3)*A_n.*C_n);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];
    % Did not include penalty term for K as added multiplicative term affects equation

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 8 % V = M*(C*A)^n + k0
    % FRC and TV points
    X_FRC  = p(1)*(C_FRC.*A_FRC).^p(2) + p(3);      % per-breath FRC points in signal units
    X_insp = p(1)*(C_insp.*A_insp).^p(2) + p(3);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [mean(X_FRC)  - FRC;      
        mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * ((p(1)*(C_apnea_e(n)*A_apnea_e(n)).^p(2) + p(3)) - (p(1)*(C_apnea_s(n)*A_apnea_s(n)).^p(2) + p(3)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n.*A_n).^p(2) + p(3);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n))];

    if test == 0 % Impose soft penalty on max and min ratio relative to tidal volume to prevent observed issues in model results
        max_FRC_ratio = abs(max(X_n)/mean(X_n(idx_FRC_all)));
        min_FRC_ratio = abs(min(X_n)/mean(X_n(idx_FRC_all)));
        resFun = [resFun;
            sqrt(w)*(max_FRC_ratio - Vol_max_ref);
            sqrt(w)*(min_FRC_ratio - Vol_min_ref)];
    else
    end

elseif equation == 9 % V = M*(C + K*A^n)
    % FRC and TV points
    X_FRC  = C_FRC  + p(2)*A_FRC.^p(3);      % per-breath FRC points in signal units
    X_insp = C_insp + p(2)*A_insp.^p(3);     % per-breath FRC + TV points in signal units

    r_NB = scale_NB * [p(1)*mean(X_FRC)  - FRC;      
        p(1)*mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * (p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n).^p(3)) - p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n).^p(3)) - dV_apnea);
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

elseif equation == 10 % V = M*(C + K*A) + k0
    X_FRC  = p(1)*(C_FRC  + p(2)*A_FRC) + p(3);      % per-breath FRC points in signal units
    X_insp = p(1)*(C_insp + p(2)*A_insp) + p(3);     % per-breath FRC + TV points in signal units
   
    r_NB = scale_NB * [mean(X_FRC)  - FRC;      
        mean(X_insp) - Insp_End];
    resFun = [resFun; r_NB];
    
    % Apnea calibration
    for n=1:length(Start_Asy)
        r_apnea = weights_Asy(n) * ((p(1)*(C_apnea_e(n) + p(2)*A_apnea_e(n)) + p(3)) - (p(1)*(C_apnea_s(n) + p(2)*A_apnea_s(n)) + p(3)) - dV_apnea);
        resFun = [resFun; r_apnea];
    end

    % Include penalty terms to keep volume within the range of TLC and RV and to constrain calibration parameters
    X_n = p(1)*(C_n + p(2)*A_n) + p(3);
    resFun = [resFun;
        sqrt(w)*max(0, max(X_n) - Vmax);
        sqrt(w)*max(0, Vmin - min(X_n));
        sqrt(w)*(p(2) - K)];
else
end
