%% Load chest and abdominal data and annotations
[data_file, data_path] = uigetfile('*.mat','Select the .mat file with the chest and abdominal data');
load([data_path data_file]) % Data should be saved as t_S1, Chest_S1_r, Abdomen_S1_r
Start_time = t_S1(1); End_time = t_S1(end); dt = t_S1(2) - t_S1(1);
Subject = input('Which subject are you analyzing data for (1, 2, 3, or 4)?');
[edf_file, edf_path] = uigetfile('*.edf','Select the .edf file with annotations for the data');
[~, ann] = edfread([edf_path edf_file]);
if Subject == 1 || Subject == 2
    Trial = input('Are you analyzing Trial 1 or 2?');
    if Trial == 1
        ann.Annotations(70) = "breath hold"; % Original error in recording breath hold
    else
        ann.Annotations(150) = "NORMAL BREATHING"; % Original error in recording time of normal breathing
        newTime = seconds(2026.2);
        ann(newTime, :) = ann(1,:);   % Creates row with correct variable types
        ann(newTime, :) = {"breath hold", seconds(17.5)};  % Overwrite with actual values
        ann = sortrows(ann);
    end
else
end

%% Isolate events from annotations file 
Event_type = ann.Annotations; % Extract event type information 
NB_rows = find(contains(Event_type,caseInsensitivePattern('Normal')) | contains(Event_type,caseInsensitivePattern('normal'))); % Rows in data table for each normal breathing segment
Apnea_rows = find(contains(Event_type,caseInsensitivePattern('Hold')) | contains(Event_type,caseInsensitivePattern('Hol')) | contains(Event_type,caseInsensitivePattern('apnea')) | contains(Event_type,caseInsensitivePattern('mueler')) | contains(Event_type,caseInsensitivePattern('muler')) | contains(Event_type,caseInsensitivePattern('manuler'))); % Rows in data table for each breath hold/muller maneuver
IC_FVC_rows = find(contains(Event_type,caseInsensitivePattern('IC')) | contains(Event_type,caseInsensitivePattern('FVC')) | contains(Event_type,caseInsensitivePattern('FCC'))); % Rows in data table for each IC/FVC maneuver
Time_Events = seconds(ann.Onset);
Duration = seconds(ann.Duration);

% Extract normal breathing times 
for i=1:length(NB_rows) % Identify start and end times for normal breathing
    Start_NB(i) = Time_Events(NB_rows(i)) - 4; % Account for possible delay in recording annotation
    Duration_NB = sscanf(Event_type(NB_rows(i)), '%f'); % Extract time of normal breathing
    if double(isempty(Duration_NB)) == 1
        Duration_NB = 10;
    elseif Duration_NB < 5 % Duration was recorded in minutes
        Duration_NB = Duration_NB*60; % Conversion to seconds
    else
    end
    End_NB(i) = Start_NB(i) + Duration_NB;
end

% Extract IC_FVC_times
for i=1:length(IC_FVC_rows) % Identify start times for IC_FVC
    Start_IC_FVC(i) = Time_Events(IC_FVC_rows(i)) - 4; % Account for possible delay in recording annotation
end

% Extract breath hold times
for i=1:length(Apnea_rows) % Identify start and end times for apneas
    Start_Apnea(i) = Time_Events(Apnea_rows(i)) - 5; % Account for possible delay in recording annotation
    Duration_Apnea = sscanf(Event_type(Apnea_rows(i)), '%f'); % Extract time of apnea
    if double(isempty(Duration_Apnea)) == 1 || double(isnan(Duration(Apnea_rows(i)))) == 1
        Duration_Apnea = 10;
    else
        Duration_Apnea = Duration(Apnea_rows(i));
    end
    End_Apnea(i) = Start_Apnea(i) + Duration_Apnea + 10; % Set end of apnea as 5 seconds past annotated end to account for possible error in recording
end

% Identify normal breathing region (exclude events outside of selected analysis region)
Include_NB_idx = find(Start_NB > Start_time & Start_NB < End_time);
Start_NB = Start_NB(Include_NB_idx); Start_NB(1) = Start_NB(1) + 10; % Exclude first new breaths to allow subject stabilize breathing
End_NB = End_NB(Include_NB_idx);
Include_IC_FVC_idx = find(Start_IC_FVC > Start_time & Start_IC_FVC < End_time);
Start_IC_FVC = Start_IC_FVC(Include_IC_FVC_idx);
Start_IC_FVC_idx = find(abs(t_S1 - Start_IC_FVC(1)) < dt); Start_IC_FVC_idx = Start_IC_FVC_idx(1); % First IC_FVC maneuver
End_NB(1) = Start_IC_FVC(1) - 5; % End first normal breathing segment before first IC/FVC maneuver

for i = 1:length(Start_NB) % Identify starting and ending indicies of normal breathing
    idx_detects = find(abs(t_S1 - Start_NB(i))<dt);
    idx_detecte = find(abs(t_S1 - End_NB(i))<dt);
    Start_NB_idx(i) = idx_detects(1);
    End_NB_idx(i) = idx_detecte(1);
end
Start_NB_idx_cal = Start_NB_idx(1); End_NB_idx_cal = End_NB_idx(1); % Only consider first normal breathing region for calibration

% Identify apnea regions (exclude events outside of selected analysis region)
Include_Apnea_idx = find(Start_Apnea > Start_time & Start_Apnea < End_time);
Start_Apnea = Start_Apnea(Include_Apnea_idx);
End_Apnea = End_Apnea(Include_Apnea_idx);
for i = 1:length(Start_Apnea) % Identify starting and ending indicies of apneas
    idx_detects = find(abs(t_S1 - Start_Apnea(i))<dt);
    idx_detecte = find(abs(t_S1 - End_Apnea(i))<dt);
    Start_Apnea_idx(i) = idx_detects(1);
    if double(isempty(idx_detecte)) == 1 % Avoid errors in indexing for apnea at the end of recording
        End_Apnea_idx(i) = length(Chest_S1_r);
    else
        End_Apnea_idx(i) = idx_detecte(1);
    end
end

%% Signal processing and additional pre-analysis
% Apnea boundary refinement
if Subject == 1
    if Trial == 1
        Apnea_thresh_p = 0.3; Apnea_thresh_s = 0.6; % Thresholds for automated boundary refinement
    else
        Apnea_thresh_p = 0.2; Apnea_thresh_s = 0.6; % Thresholds for automated boundary refinement
    end
else 
    Apnea_thresh_p = 0.5; Apnea_thresh_s = 0.6; % Thresholds for automated boundary refinement
end
[Start_Apnea_idx, End_Apnea_idx] = Apnea_Refinement(Chest_S1_r, Start_Apnea_idx, End_Apnea_idx,dt,Apnea_thresh_p,Apnea_thresh_s);

% Visualize adjusted boundary points from automated refinement
figure
fig = plot(t_S1,Chest_S1_r);
hold on
scatter(t_S1(Start_Apnea_idx),Chest_S1_r(Start_Apnea_idx),'b')
hold on
scatter(t_S1(End_Apnea_idx),Chest_S1_r(End_Apnea_idx),'r')
hold on
plot(t_S1,Abdomen_S1_r,'r')
set(fig, 'HitTest','on', 'PickableParts','visible');
zoom on
datacursormode on
pause

% Further manual adjustment of boundaries  if necessary
Adjust_apnea = input('Do you want to adjust any of the apnea starting or ending points? (0 = No, 1 = Yes)');
while Adjust_apnea == 1
    Apnea_no = input('Which apnea would you like to adjust?');
    Point_loc = input('Do you want to adjust the starting or ending point? (0 = Start, 1 = End)');
    if Point_loc == 0
        Time_adjust = input('Enter the time for the actual starting point');
        loc_actual = find(abs(t_S1 - Time_adjust)<dt); loc_actual = loc_actual(1);
        Start_Apnea_idx(Apnea_no) = loc_actual;
    else
        Time_adjust = input('Enter the time for the actual ending point');
        loc_actual = find(abs(t_S1 - Time_adjust)<dt); loc_actual = loc_actual(1);
        End_Apnea_idx(Apnea_no) = loc_actual;
    end
    Adjust_apnea = input('Do you want to adjust any of the apnea starting or ending points? (0 = No, 1 = Yes)');
end

% Process signals (detrend apneas, adjust post-apnea segments)
signals = input('Do you want to use the raw signals for calibration (=0) or processed signals (=1)?');
if signals == 0
    Chest_S1 = Chest_S1_r; Abdomen_S1 = Abdomen_S1_r;
else
    [Chest_S1, Abdomen_S1] = Signal_Processing_Final(t_S1, Chest_S1_r, Abdomen_S1_r, Start_Apnea_idx, End_Apnea_idx, Start_NB_idx_cal, End_NB_idx_cal, dt);
end

% Detect normal breaths for calibration (exlcude irregular breaths in normal breathing region)
[Start_Breath_NB, End_Breath_NB] = Eupnea_Detection_Final(Start_NB_idx_cal,End_NB_idx_cal,dt,Abdomen_S1,Chest_S1);

% Detect apnea asynchronous segments for calibration
[Start_Asy, End_Asy] = Asynchronous_Segment_Apnea(dt,Abdomen_S1,Chest_S1,Start_Apnea_idx,End_Apnea_idx);

% Normalization of signals for calibration (for better problem conditioning and avoiding negative values)
epsilon = 0.05; % Bound signals in the range [epsilon, 1] (Observed issues in calibrating Equation 9 with C_n and A_n greater than 1)
abs_max = max([max(Chest_S1), max(Abdomen_S1)]);
abs_min = min([min(Chest_S1), min(Abdomen_S1)]);
A_n = ((Abdomen_S1 - abs_min)*(1-epsilon)/(abs_max - abs_min)) + epsilon;
C_n = ((Chest_S1 - abs_min)*(1-epsilon)/(abs_max - abs_min)) + epsilon;

% Calculate K (classic linear model) from asynchronous segments during apneas
for n=1:length(Start_Asy) % Cycle through each identified asynchronous segment
    deluV_Chest(n) = C_n(End_Asy(n))- C_n(Start_Asy(n)); % Voltage change in thoracic signal during each asynchronous segment
    deluV_Abd(n) = A_n(End_Asy(n))- A_n(Start_Asy(n)); % Voltage change in abdominal signal during each asynchronous segment
    K_seg(n) = -deluV_Chest(n)/deluV_Abd(n); % K value for each asynchronous segment
end
K = mean(K_seg);

%% Load subject demographics and reference volumes
[demo_file, demo_path] = uigetfile('*.xlsx','Select the Excel file with subject demographics and lung volume references');
opts = detectImportOptions([demo_path demo_file]);
opts.DataRange = 'A4:T7';
Data = readtable([demo_path demo_file],opts,'Sheet','Demographics');
Subject_No = table2array(Data(:,1)); Subject_Sex = table2array(Data(:,2)); Subject_Age = table2array(Data(:,3)); Subject_Height = table2array(Data(:,4)); Subject_Weight = table2array(Data(:,5));
Tid_Vol_mean = table2array(Data(:,9)); Tid_Vol_lb = table2array(Data(:,10)); Tid_Vol_ub = table2array(Data(:,11));
FRC_mean = table2array(Data(:,12)); FRC_lb = table2array(Data(:,13)); FRC_ub = table2array(Data(:,14));
TLC_mean = table2array(Data(:,15)); TLC_lb = table2array(Data(:,16)); TLC_ub = table2array(Data(:,17));
RV_mean = table2array(Data(:,18)); RV_lb = table2array(Data(:,19)); RV_ub = table2array(Data(:,20));

% Extract subject data
data_idx = find(Subject_No == Subject);
FRC = FRC_mean(data_idx);
TLC = TLC_mean(data_idx);
RV = RV_mean(data_idx);
Tid_Vol = Tid_Vol_mean(data_idx);

% Additonal calibration data (tidal volume increase factors)
[TV_file, TV_path] = uigetfile('*.mat','Select the .mat file with tidal volume increase factors');
load([TV_path TV_file]) % Data calculated using Tidal_Volume_Correction.m
Inc_method = input('Do you want to use the same increase factor for all subjects (= 0) or individual values (= 1)?');
if Inc_method == 0
    Inc_val = input('Do you want to want to use the mean increase factor (= 0) for calibration, the upper and lower bounds (= 1), or all 3 (= 2)?');
    if Inc_val == 0
        Inc_factor = Overall_mean; % Mean increase factor for tidal volume
    elseif Inc_val == 1
        Inc_factor = [Overall_lb, Overall_ub]; % Lower and upper bounds for increase factor of tidal volume
    else
        Inc_factor = [Overall_lb, Overall_mean, Overall_ub];
    end
else
    if Subject == 1
        if Trial == 1
            Inc_factor = Ratio_S1_1;
        else
            Inc_factor = Ratio_S1_2;
        end
    elseif Subject == 2
        if Trial == 1
            Inc_factor = Ratio_S2_1;
        else
            Inc_factor = Ratio_S2_2;
        end
    elseif Subject == 3
        Inc_factor = Ratio_S3;
    else
        Inc_factor = Ratio_S4;
    end
end
Tid_Vol = Tid_Vol.*Inc_factor;
Insp_End = FRC + Tid_Vol;
Vmax = TLC;
Vmin = RV;
dV_apnea = 0;

%% Optimial equation determination (for each equation using mean values of reference volumes)
% Performed using data of Subjects 1 and 2 only

% Derivative and filtering parameters
half_window_time = 0.05; % Time in seconds
half_window = round(half_window_time/dt);
half_window_length = half_window*dt;
frame_len = round(0.05/dt); % Time in seconds
frame_len = 2*round(frame_len/2) + 1; % Odd number window length for Savitsky-Golay filter

equation = input('Which equation do you want to use (1-10)? If multiple inputs, enter in brackets [].');

% Use linear model as reference to avoid scaling issues in power models
w = 0.1; test = 1; equation_ref = 1;
Vol_max_ref = 0; Vol_min_ref = 0; % Initialize reference limits to run through function
sol = @(p) ResFunction_final(p, ...
    Start_Breath_NB, End_Breath_NB, ...
    Start_Asy, End_Asy, ...
    equation_ref, C_n, A_n, ...
    Insp_End, FRC, dV_apnea, ...
    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test) ; sol = sol(1);
Msol_ref = sol(1); Ksol_ref = sol(2); vert_shift_ref = sol(3); Vol_max_ref = sol(4); Vol_min_ref = sol(5);

% Calibrate model equation parameters
for m=1:length(equation)
    if double(any(ismember(equation(m),1))) == 1 
        % V = M*(C + K*A)
        w = 0.1;
        sol = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test); sol = sol(1);

        Msol_1 = sol(1); Ksol_1 = sol(2); vert_shift = sol(3); % Calibrated parameters

        % Direct volume result from calibration 
        Vol_1(:,1) = (Msol_1.*(C_n + Ksol_1.*A_n) + vert_shift)/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_1)-half_window)-1
            Flow_r_1(p,1) = (Vol_1(p+half_window,1) - Vol_1(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_1 = [Flow_r_1(1)*ones(half_window,1); Flow_r_1];

        % Instantaneous derivative of filtered volume signal
        Vol_f_1 = sgolayfilt(Vol_1(:,1), 3, frame_len);
        Flow_f_1 = diff(Vol_f_1(:,1))/dt;

        % Cumuluative flow data
        Flow_1 = [Flow_f_1 Flow_r_1];
        Flow_1_mean = mean(Flow_1,2);
        S.Flow_1_mean = Flow_1_mean;

    elseif double(any(ismember(equation(m),2))) == 1
        % Equation 2 V = M*(C + A)^n
        p0 = [500 1.25; 500 1; 500 0.75; 500 0.5; 500 0.25; 500 0.1;
              1000 1.25; 1000 1; 1000 0.75; 1000 0.5; 1000 0.25; 1000 0.1;
              2000 1.25; 2000 1; 2000 0.75; 2000 0.5; 2000 0.25; 2000 0.1;
              3000 1.25; 3000 1; 3000 0.75; 3000 0.5; 3000 0.25; 3000 0.1];
        lb = [1e-8 0.1]; ub = [Inf 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k) = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_2 = p_est(1); nsol_2 = p_est(2); % Original calibrated parameters
        
        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0 % At least one parameter is hitting the lower/upper bound
            % Adjust lower bound and re-run model fitting
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_2 = p_est(1); nsol_2 = p_est(2); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0 
                % Adjust lower bound and re-run model fitting
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_2 = p_est(1); nsol_2 = p_est(2); % Adjusted fitting parameters
            else
            end
        else
        end

        % Direct volume result from calibration
        Vol_2(:,1) = (Msol_2.*(C_n + A_n).^nsol_2)/1000; % Volume in liters
        
        % Central difference derivative
        for p = half_window+1:round(length(Vol_2)-half_window)-1
            Flow_r_2(p,1) = (Vol_2(p+half_window,1) - Vol_2(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_2 = [Flow_r_2(1)*ones(half_window,1); Flow_r_2];

        % Instantaneous derivative from filtered volume signal
        Vol_f_2 = sgolayfilt(Vol_2(:,1), 3, frame_len);
        Flow_f_2 = diff(Vol_f_2(:,1))/dt;

        % Cumuluative flow data
        Flow_2 = [Flow_f_2 Flow_r_2];
        Flow_2_mean = mean(Flow_2,2);
        S.Flow_2_mean = Flow_2_mean;
    
    elseif double(any(ismember(equation(m),3))) == 1
        % Equation 3 V = M*(C + K*A)^n
        p0 = [500 K 1.25; 500 K 1; 500 K 0.75; 500 K 0.5; 500 K 0.25; 500 K 0.1;
              1000 K 1.25; 1000 K 1; 1000 K 0.75; 1000 K 0.5; 1000 K 0.25; 1000 K 0.1;
              2000 K 1.25; 2000 K 1; 2000 K 0.75; 2000 K 0.5; 2000 K 0.25; 2000 K 0.1;
              3000 K 1.25; 3000 K 1; 3000 K 0.75; 3000 K 0.5; 3000 K 0.25; 3000 K 0.1;];
        lb = [1e-8 1e-8 0.1]; ub = [Inf 5 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);

        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_3 = p_est(1); Ksol_3 = p_est(2); nsol_3 = p_est(3); % Original calibrated parameters
        
        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_3 = p_est(1); Ksol_3 = p_est(2); nsol_3 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_3 = p_est(1); Ksol_3 = p_est(2); nsol_3 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end
        
        % Direct volume result from calibration
        Vol_3(:,1) = (Msol_3.*(C_n + Ksol_3*A_n).^nsol_3)/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_3)-half_window)-1
            Flow_r_3(p,1) = (Vol_3(p+half_window,1) - Vol_3(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_3 = [Flow_r_3(1)*ones(half_window,1); Flow_r_3];

        % Instantaneous derivative from filtered volume signal
        Vol_f_3 = sgolayfilt(Vol_3(:,1), 3, frame_len);
        Flow_f_3 = diff(Vol_f_3(:,1))/dt;

        % Cumuluative flow data
        Flow_3 = [Flow_f_3 Flow_r_3];
        Flow_3_mean = mean(Flow_3,2);
        S.Flow_3_mean = Flow_3_mean;

    elseif double(any(ismember(equation(m),4))) == 1
        % Equation 4 V = M*(C^n + A^n)
        p0 = [500 1.25; 500 1; 500 0.75; 500 0.5; 500 0.25; 500 0.1;
              1000 1.25; 1000 1; 1000 0.75; 1000 0.5; 1000 0.25; 1000 0.1;
              2000 1.25; 2000 1; 2000 0.75; 2000 0.5; 2000 0.25; 2000 0.1;
              3000 1.25; 3000 1; 3000 0.75; 3000 0.5; 3000 0.25; 3000 0.1];
        lb = [1e-8 0.1]; ub = [Inf 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);

        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_4 = p_est(1); nsol_4 = p_est(2); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_4 = p_est(1); nsol_4 = p_est(2); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_4 = p_est(1); nsol_4 = p_est(2); % Adjusted fitting parameters
            else
            end
        else
        end
        
        % Direct volume result from calibration
        Vol_4(:,1) = (Msol_4.*(C_n.^nsol_4 + A_n.^nsol_4))/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_4)-half_window)-1
            Flow_r_4(p,1) = (Vol_4(p+half_window,1) - Vol_4(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_4 = [Flow_r_4(1)*ones(half_window,1); Flow_r_4];

        % Instantaneous derivative from filtered volume signal
        Vol_f_4 = sgolayfilt(Vol_4(:,1), 3, frame_len);
        Flow_f_4 = diff(Vol_f_4(:,1))/dt;

        % Cumuluative flow data
        Flow_4 = [Flow_f_4 Flow_r_4];
        Flow_4_mean = mean(Flow_4,2);
        S.Flow_4_mean = Flow_4_mean;

    elseif double(any(ismember(equation(m),5))) == 1
        % Equation 5 V = M*(C^n + A^m)
         p0 = [500 1.25 1.25; 500 1 1; 500 0.75 0.75; 500 0.5 0.5; 500 0.25 0.25; 500 0.1 0.1;
              1000 1.25 1.25; 1000 1 1; 1000 0.75 0.75; 1000 0.5 0.5; 1000 0.25 0.25; 1000 0.1 0.1;
              2000 1.25 1.25; 2000 1 1; 2000 0.75 0.75; 2000 0.5 0.5; 2000 0.25 0.25; 2000 0.1 0.1;
              3000 1.25 1.25; 3000 1 1; 3000 0.75 0.75; 3000 0.5 0.5; 3000 0.25 0.25; 3000 0.1 0.1];
        lb = [1e-8 0.1 0.1]; ub = [Inf 2 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);

        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_5 = p_est(1); nsol_5 = p_est(2); msol_5 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_5 = p_est(1); nsol_5 = p_est(2); msol_5 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_5 = p_est(1); nsol_5 = p_est(2); msol_5 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end
        
        % Direct volume result from calibration
        Vol_5(:,1) = (Msol_5.*(C_n.^nsol_5 + A_n.^msol_5))/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_5)-half_window)-1
            Flow_r_5(p,1) = (Vol_5(p+half_window,1) - Vol_5(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_5 = [Flow_r_5(1)*ones(half_window,1); Flow_r_5];

        % Instantaneous derivative of filtered volume signal
        Vol_f_5 = sgolayfilt(Vol_5(:,1), 3, frame_len);
        Flow_f_5 = diff(Vol_f_5(:,1))/dt;

        % Cumuluative flow data
        Flow_5 = [Flow_f_5 Flow_r_5];
        Flow_5_mean = mean(Flow_5,2);
        S.Flow_5_mean = Flow_5_mean;

    elseif double(any(ismember(equation(m),6))) == 1
        % Equation 6 V = M*(C^n + K*A^n)
        p0 = [500 K 1.25; 500 K 1; 500 K 0.75; 500 K 0.5; 500 K 0.25; 500 K 0.1;
              1000 K 1.25; 1000 K 1; 1000 K 0.75; 1000 K 0.5; 1000 K 0.25; 1000 K 0.1;
              2000 K 1.25; 2000 K 1; 2000 K 0.75; 2000 K 0.5; 2000 K 0.25; 2000 K 0.1;
              3000 K 1.25; 3000 K 1; 3000 K 0.75; 3000 K 0.5; 3000 K 0.25; 3000 K 0.1];
        lb = [1e-8 1e-8 0.1]; ub = [Inf 5 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end
        
        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_6 = p_est(1); Ksol_6 = p_est(2); nsol_6 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_6 = p_est(1); Ksol_6 = p_est(2); nsol_6 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_6 = p_est(1); Ksol_6 = p_est(2); nsol_6 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end
        
        % Direct volume result from calibration
        Vol_6(:,1) = (Msol_6.*(C_n.^nsol_6 + Ksol_6*A_n.^nsol_6))/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_6)-half_window)-1
            Flow_r_6(p,1) = (Vol_6(p+half_window,1) - Vol_6(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_6 = [Flow_r_6(1)*ones(half_window,1); Flow_r_6];

        % Instantaneous derivative of filtered signal
        Vol_f_6 = sgolayfilt(Vol_6(:,1), 3, frame_len);
        Flow_f_6 = diff(Vol_f_6(:,1))/dt;

        % Cumuluative flow data
        Flow_6 = [Flow_f_6 Flow_r_6];
        Flow_6_mean = mean(Flow_6,2);
        S.Flow_6_mean = Flow_6_mean;

    elseif double(any(ismember(equation(m),7))) == 1
        % Equation 7 V = M*(C + k2*A + k3*(C*A))
        p0 = [500 1.25 1.25; 500 1 1; 500 0.75 0.75; 500 0.5 0.5; 500 0.25 0.25; 500 0.1 0.1;
              1000 1.25 1.25; 1000 1 1; 1000 0.75 0.75; 1000 0.5 0.5; 1000 0.25 0.25; 1000 0.1 0.1;
              2000 1.25 1.25; 2000 1 1; 2000 0.75 0.75; 2000 0.5 0.5; 2000 0.25 0.25; 2000 0.1 0.1;
              3000 1.25 1.25; 3000 1 1; 3000 0.75 0.75; 3000 0.5 0.5; 3000 0.25 0.25; 3000 0.1 0.1];
        lb = [1e-8 1e-8 1e-8]; ub = [Inf 5 5]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_7 = p_est(1); Ksol_7 = p_est(2); nsol_7 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_7 = p_est(1); Ksol_7 = p_est(2); nsol_7 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_7 = p_est(1); Ksol_7 = p_est(2); nsol_7 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end

        % Direct volume result from calibration
        Vol_7(:,1) = (Msol_7.*(C_n + Ksol_7*A_n + nsol_7*C_n.*A_n))/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_7)-half_window)-1
            Flow_r_7(p,1) = (Vol_7(p+half_window,1) - Vol_7(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_7 = [Flow_r_7(1)*ones(half_window,1); Flow_r_7];

        % Instantaneous derivative of filtered volume signal
        Vol_f_7 = sgolayfilt(Vol_7(:,1), 3, frame_len);
        Flow_f_7 = diff(Vol_f_7(:,1))/dt;

        % Cumuluative flow data
        Flow_7 = [Flow_f_7 Flow_r_7];
        Flow_7_mean = mean(Flow_7,2);
        S.Flow_7_mean = Flow_7_mean;

    elseif double(any(ismember(equation(m),8))) == 1
        % Equation 8 V = M*(C*A)^n + k0
        p0 = [500 1.25 500; 500 1 500; 500 0.75 500; 500 0.5 500; 500 0.25 500; 500 0.1 500;
              1000 1.25 1000; 1000 1 1000; 1000 0.75 1000; 1000 0.5 1000; 1000 0.25 1000; 1000 0.1 1000;
              2000 1.25 2000; 2000 1 2000; 2000 0.75 2000; 2000 0.5 2000; 2000 0.25 2000; 2000 0.1 2000;
              3000 1.25 3000; 3000 1 3000; 3000 0.75 3000; 3000 0.5 3000; 3000 0.25 3000; 3000 0.1 3000];
        lb = [1e-8 0.1 -Inf]; ub = [Inf 2 Inf]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_8 = p_est(1); nsol_8 = p_est(2); k0sol_8 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_8 = p_est(1); nsol_8 = p_est(2); k0sol_8 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_8 = p_est(1); nsol_8 = p_est(2); k0sol_8 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end

        % Direct volume result from calibration
        Vol_8(:,1) = (Msol_8.*(C_n.*A_n).^nsol_8 + k0sol_8)/1000;
        
        % Central difference derivative
        for p = half_window+1:round(length(Vol_8)-half_window)-1
            Flow_r_8(p,1) = (Vol_8(p+half_window,1) - Vol_8(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_8 = [Flow_r_8(1)*ones(half_window,1); Flow_r_8];

        % Instantaneous derivatve of filtered volume signal
        Vol_f_8 = sgolayfilt(Vol_8(:,1), 3, frame_len);
        Flow_f_8 = diff(Vol_f_8(:,1))/dt;

        % Cumuluative flow data
        Flow_8 = [Flow_f_8 Flow_r_8];
        Flow_8_mean = mean(Flow_8,2);
        S.Flow_8_mean = Flow_8_mean;

    elseif double(any(ismember(equation(m),9))) == 1
        % Equation 9 V = M*(C + K*A^n)
        p0 = [500 K 1.25; 500 K 1; 500 K 0.75; 500 K 0.5; 500 K 0.25; 500 K 0.1;
              1000 K 1.25; 1000 K 1; 1000 K 0.75; 1000 K 0.5; 1000 K 0.25; 1000 K 0.1;
              2000 K 1.25; 2000 K 1; 2000 K 0.75; 2000 K 0.5; 2000 K 0.25; 2000 K 0.1;
              3000 K 1.25; 3000 K 1; 3000 K 0.75; 3000 K 0.5; 3000 K 0.25; 3000 K 0.1];
        lb = [1e-8 1e-8 0.1]; ub = [Inf 5 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_9 = p_est(1); Ksol_9 = p_est(2); nsol_9 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_9 = p_est(1); Ksol_9 = p_est(2); nsol_9 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_9 = p_est(1); Ksol_9 = p_est(2); nsol_9 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end
        
        % Direct volume result from calibration
        Vol_9(:,1) = (Msol_9.*(C_n + Ksol_9*A_n.^nsol_9))/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_9)-half_window)-1
            Flow_r_9(p,1) = (Vol_9(p+half_window,1) - Vol_9(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_9 = [Flow_r_9(1)*ones(half_window,1); Flow_r_9];

        % Instantaneous derivative of filtered volume signal
        Vol_f_9 = sgolayfilt(Vol_9(:,1), 3, frame_len);
        Flow_f_9 = diff(Vol_f_9(:,1))/dt;

        % Cumuluative flow data
        Flow_9 = [Flow_f_9 Flow_r_9];
        Flow_9_mean = mean(Flow_9,2);
        S.Flow_9_mean = Flow_9_mean;
    
    elseif double(any(ismember(equation(m),10))) == 1
        % Equation V = M*(C_n + K*A_n) + k0
        p0 = [Msol_ref Ksol_ref vert_shift_ref];
        lb = [1e-8 1e-8 -Inf]; ub = [Inf 5 Inf]; w = 0.1;
         resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation(m), C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_10 = p_est(1); Ksol_10 = p_est(2); k0sol_10 = p_est(3); % Original fitting parameters

        % Adjust bounds if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            if double(isempty(lb_test)) == 0
                for l = 1:length(lb_test)
                    lb(lb_test(l)) = -Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_10 = p_est(1); Ksol_10 = p_est(2); k0sol_10 = p_est(3); % Adjusted fitting parameters
            else
            end
            if double(isempty(ub_test)) == 0
                for l = 1:length(ub_test)
                    ub(ub_test(l)) = Inf;
                end
                parfor k = 1:nRuns
                    [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                    allP(k,:) = p_temp;
                    allres(k)   = resNorm;
                end
                % Select best AFTER the parfor
                [resvalue, idx] = min(allres);
                p_est = allP(idx,:);
                Msol_10 = p_est(1); Ksol_10 = p_est(2); k0sol_10 = p_est(3); % Adjusted fitting parameters
            else
            end
        else
        end

        % Direct volume result from calibration
        Vol_10(:,1) = (Msol_10.*(C_n + Ksol_10*A_n) + k0sol_10)/1000;

        % Central difference derivative
        for p = half_window+1:round(length(Vol_10)-half_window)-1
            Flow_r_10(p,1) = (Vol_10(p+half_window,1) - Vol_10(p-half_window,1))/(2*half_window_length);
        end
        Flow_r_10 = [Flow_r_10(1)*ones(half_window,1); Flow_r_10];

        % Instantaneous derivative of filtered signal
        Vol_f_10 = sgolayfilt(Vol_10(:,1), 3, frame_len);
        Flow_f_10 = diff(Vol_f_10(:,1))/dt;

        % Cumuluative flow data
        Flow_10 = [Flow_f_10 Flow_r_10];
        Flow_10_mean = mean(Flow_10,2);
        S.Flow_10_mean = Flow_10_mean;
    elseif double(any(ismember(equation(m),11))) == 1
    end
end

%% Load corresponding flow data
[flow_file flow_path] = uigetfile('*.edf','Select the .edf file with the flow data');
[data_flow, ~] = edfread([flow_path flow_file]);
data_flow.Properties.DimensionNames{1} = 'Time'; % Change column name to eliminate space
time_vec_flow = seconds(data_flow.Time); % Convert data to a double array
t_int_flow = time_vec_flow(2) - time_vec_flow(1); % Interval between recording times
n_data_flow = length(data_flow.Airflow{1}); % Number of recording points within each interval for thoracic and abdominal signals (same recording frequency)
dt_flow = t_int_flow/(n_data_flow); % Time step
t_initial_flow = time_vec_flow(1);
total_rec_flow = size(data_flow,1); % Number of rows in data matrix
t_flow(1,:) = t_initial_flow; % Recording start time
for i=2:total_rec_flow*n_data_flow
    t_flow(i,:) = t_flow(i-1,:) + dt_flow; % Time vector for airflow transducer signal
end
Flow_SPIRO = vertcat(data_flow.Airflow{:}); % Airflow 

%% Signal alignment (chest/abdominal signals and airflow were collected using separate data acquistion units)
for n = 1:length(equation)
    clear Flow
    eqn_no = equation(n);
    var_name = ['Flow_' char(string(eqn_no)) '_mean'];
    Flow = S.(var_name);

    % Adjust airflow transducer signal to match chest/abdominal sampling frequency
    t_flow_map = t_flow(1):dt:t_flow(end); t_flow_map = t_flow_map(:); 
    Flow_SPIRO_map = interp1(t_flow,Flow_SPIRO,t_flow_map,'linear','extrap'); % Map flow onto resampled time
    
    % Determine shift using signal correlation
    corr_seg = 1:Start_IC_FVC_idx;
    delay = finddelay(Flow_SPIRO_map(corr_seg),Flow(corr_seg));
    time_shift_idx = abs(delay);
    time_shift = delay*dt;

    % Align signals using identified delay
    if time_shift > 0
        Flow_shift = Flow(time_shift_idx:end);
        RC_shift = Chest_S1(time_shift_idx:end-1);
        AB_shift = Abdomen_S1(time_shift_idx:end-1);
    else
        Flow_shift = [zeros(time_shift_idx,1); Flow];
        RC_shift = [zeros(time_shift_idx,1); Chest_S1(1:end-1)];
        AB_shift = [zeros(time_shift_idx,1); Abdomen_S1(1:end-1)];
    end

    % Ensure equal length of signals
    if length(Flow_shift) > length(Flow_SPIRO_map)
        study_end = length(Flow_SPIRO_map);
        Flow_cut = Flow_shift(1:study_end);
        RC_cut = RC_shift(1:study_end);
        AB_cut = AB_shift(1:study_end);
        Flow_SPIRO_cut = Flow_SPIRO_map;
        t_flow_cut = t_flow_map;
    else
        study_end = length(Flow_shift);
        Flow_SPIRO_cut = Flow_SPIRO_map(1:study_end);
        t_flow_cut = t_flow_map(1:study_end);
        Flow_cut = Flow_shift;
        RC_cut = RC_shift;
        AB_cut = AB_shift;
    end
    Flow_final = Flow_cut; RC_final = RC_cut; AB_final = AB_cut;

    % Adjust comparison boundaries to account for subject adjustment to airflow transducer at beginning of study
    if Subject == 1
        if Trial == 1
            time_adj = 30;
        else
            time_adj = 4.2;
        end
    elseif Subject == 2
        if Trial == 1
            time_adj = 5;
        else
            time_adj = 16.13;
        end
    end
    new_start = round(time_adj/dt);
    t_flow_adj = t_flow_cut(new_start:end);
    Flow_SPIRO_adj = Flow_SPIRO_cut(new_start:end);
    Flow_final_adj = Flow_final(new_start:end); 
    RC = RC_final(new_start:end);
    AB = AB_final(new_start:end);

    % Volume conversion for additional analysis (process measured and modeled signal the same way for consistency)
    Twin = 30; Nwin = round(Twin/dt);
    Flow_meas = Flow_SPIRO_adj - movmean(Flow_SPIRO_adj,Nwin);
    Flow_model = Flow_final_adj - movmean(Flow_final_adj,Nwin);
    V_meas = cumtrapz(Flow_meas)*dt;
    V_model = cumtrapz(Flow_model)*dt;
    
    % Moving amplitude changes for equation scoring
    winSec = round(5/dt); 
    win_len = 2*round(winSec/2) + 1; % Odd number window length 
    h = (win_len-1)/2;
    N = length(V_model);
    clear A_model A_meas Error_vol t_win
    for k = 1:N
        idx = max(1, k-h) : min(N, k+h);

        % Amplitudes and volume change error
        A_model(k) = max(V_model(idx)) - min(V_model(idx));
        A_meas(k) = max(V_meas(idx)) - min(V_meas(idx));
        Error_vol(k) = A_meas(k) - A_model(k);

        % window center time
        t_win(k) = mean(t_flow_adj(idx));
    end
    Final(n).Equation = eqn_no; Final(n).Time = t_flow_adj; Final(n).Flow = Flow_final_adj; Final(n).Vol_meas = V_meas; Final(n).Vol_model = V_model; Final(n).t_win = t_win; Final(n).A_meas = A_meas; Final(n).A_model = A_model; 
end
Final = orderfields(Final, {'Equation','Time','Flow','Vol_meas','Vol_model','t_win','A_meas','A_model'});

%% Normalized Analysis
% Adjust original normal breathing indices to account for signal alignment
Start_NB_idxr = Start_Breath_NB - sign(delay)*time_shift_idx - new_start;
End_NB_idxr = End_Breath_NB - sign(delay)*time_shift_idx - new_start;

% Normalize amplitude vectors by normal breathing amplitude
for i=1:length(Final)
    clear A_amp_model A_amp_meas
    A_vector_model = Final(i).A_model;
    A_vector_meas = Final(i).A_meas;
    for j=1:length(Start_NB_idxr)
        A_amp_model(j) = mean(A_vector_model(Start_NB_idxr(j):End_NB_idxr(j)));
        A_amp_meas(j) = mean(A_vector_meas(Start_NB_idxr(j):End_NB_idxr(j)));
    end
    A_amp_model_mean = mean(A_amp_model);
    A_amp_meas_mean = mean(A_amp_meas);
    Amp(i).Model_Norm = A_vector_model/A_amp_model_mean;
    Amp(i).Meas_Norm = A_vector_meas/A_amp_meas_mean;
end

% RMS using normalized and raw signals
for i=1:length(Final)
    residuals = Final(i).A_meas - Final(i).A_model;
    residuals_norm = Amp(i).Meas_Norm - Amp(i).Model_Norm;
    RMSE(i) = sqrt(sum(residuals.^2)*(1/length(residuals)));
    RMSE_norm(i) = sqrt(sum(residuals_norm.^2)*(1/length(residuals_norm)));
    Error_max_norm(i) = max(abs(residuals_norm));
end

% Equation scores calculated in Data_Analysis.m

%% Final analysis after selecting equation (Equation 9 chosen as optimal)
% Run lower bound, mean, and upper bound combinations of reference volumes
FRC_all = [FRC_lb(data_idx) FRC_mean(data_idx), FRC_ub(data_idx)];
TLC_all = [TLC_lb(data_idx) TLC_mean(data_idx), TLC_ub(data_idx)];
RV_all = [RV_lb(data_idx) RV_mean(data_idx), RV_ub(data_idx)];
TV_method = input('Are you running all combinations of tidal volume (1) or just the mean (0)?');
if TV_method == 1
    Tid_Vol_all = [Tid_Vol_lb(data_idx) Tid_Vol_mean(data_idx), Tid_Vol_ub(data_idx)];
else
    Tid_Vol_all = Tid_Vol_mean(data_idx);
end

% Run each with lower bound, mean, and upper bound of increase factor
if Inc_method == 0
    Inc_factor_all = [Overall_lb, Overall_mean, Overall_ub];
else
    Inc_factor_all = Inc_factor;
end
counter_run = 1; % Initialize counter
Total_outcomes = length(FRC_all)*length(Inc_factor_all);
% Initialze output matrices
Msol_final = zeros(length(Total_outcomes),1); Ksol_final = zeros(length(Total_outcomes),1); nsol_final = zeros(length(Total_outcomes),1); k0sol_final = zeros(length(Total_outcomes),1);
Vol_final = zeros(length(Abdomen_S1),Total_outcomes);
Vol_final_f = zeros(length(Abdomen_S1),Total_outcomes);
Flow_calc_final_f = zeros(length(Abdomen_S1)-1,Total_outcomes);
Flow_calc_final_r = zeros(length(Abdomen_S1)-1,Total_outcomes);
Flow_calc_final_mean = zeros(length(Abdomen_S1)-1,Total_outcomes);
equation_used = zeros(length(Total_outcomes));

% Define derivative and filtering parameters
half_window_time = 0.05; % Time in seconds
half_window = round(half_window_time/dt);
half_window_length = half_window*dt; % Window length for derivate calculation
frame_len = round(0.05/dt); % Time in seconds
frame_len = 2*round(frame_len/2) + 1; % Odd number window length for Savitsky-Golay filter

% Use linear model as reference to avoid scaling issues in power models
w = 0.1; test = 1; equation_ref = 1;
Vol_max_ref = 0; Vol_min_ref = 0; % Initialize reference limits to run through function
sol = @(p) ResFunction_final(p, ...
    Start_Breath_NB, End_Breath_NB, ...
    Start_Asy, End_Asy, ...
    equation_ref, C_n, A_n, ...
    Insp_End, FRC, dV_apnea, ...
    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test) ; sol = sol(1);
Msol_ref = sol(1); Ksol_ref = sol(2); vert_shift_ref = sol(3); Vol_max_ref = sol(4); Vol_min_ref = sol(5);

for i = 1:length(FRC_all)
    for n = 1:length(Inc_factor_all)
        FRC = FRC_all(i);
        if TV_method == 1
            Tid_Vol = Tid_Vol_all(i).*Inc_factor_all(n);
        else
            Tid_Vol = Tid_Vol_all*Inc_factor_all(n);
        end
        Insp_End = FRC + Tid_Vol;
        Vmax = TLC_all(i);
        Vmin = RV_all(i);
        
        % Calibration using selected model
        % Equation 9 V = M*(C + K*A^n)
        equation_final = 9; test = 0; % Include max/FRC and min/FRC ratio residuals
        p0 = [500 K 1.25; 500 K 1; 500 K 0.75; 500 K 0.5; 500 K 0.25; 500 K 0.1;
            1000 K 1.25; 1000 K 1; 1000 K 0.75; 1000 K 0.5; 1000 K 0.25; 1000 K 0.1;
            2000 K 1.25; 2000 K 1; 2000 K 0.75; 2000 K 0.5; 2000 K 0.25; 2000 K 0.1;
            3000 K 1.25; 3000 K 1; 3000 K 0.75; 3000 K 0.5; 3000 K 0.25; 3000 K 0.1];
        lb = [1e-8 1e-8 0.1]; ub = [Inf 5 2]; w = 0.1;
        resFun = @(p) ResFunction_final(p, ...
            Start_Breath_NB, End_Breath_NB, ...
            Start_Asy, End_Asy, ...
            equation_final, C_n, A_n, ...
            Insp_End, FRC, dV_apnea, ...
            Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
        opts = optimoptions('lsqnonlin', ...
            'Display','iter', ...
            'TolFun',1e-12, ...
            'TolX',1e-12, ...
            'MaxIter',2000);
        
        % Fitting results
        nRuns = size(p0,1); pars = size(p0,2);
        allP = zeros(nRuns, pars);
        allres = zeros(nRuns, 1);

        parfor k = 1:nRuns
            [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
            allP(k,:) = p_temp;
            allres(k)   = resNorm;
        end

        % Select best AFTER the parfor
        [resvalue, idx] = min(allres);
        p_est = allP(idx,:);
        Msol_final(counter_run) = p_est(1); Ksol_final(counter_run) = p_est(2); nsol_final(counter_run) = p_est(3); % Original fitting parameters

        % Use linear model if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            equation_final = 10; test = 1; % Linear model comparison residuals not needed
            equation_used(counter_run) = equation_final;
            p0 = [Msol_ref Ksol_ref vert_shift_ref];
            lb = [1e-8 1e-8 -Inf]; ub = [Inf 5 Inf]; w = 0.1;
            resFun = @(p) ResFunction_final(p, ...
                Start_Breath_NB, End_Breath_NB, ...
                Start_Asy, End_Asy, ...
                equation_final, C_n, A_n, ...
                Insp_End, FRC, dV_apnea, ...
                Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test);
            opts = optimoptions('lsqnonlin', ...
                'Display','iter', ...
                'TolFun',1e-12, ...
                'TolX',1e-12, ...
                'MaxIter',2000);

            % Fitting results
            nRuns = size(p0,1); pars = size(p0,2);
            allP = zeros(nRuns, pars);
            allres = zeros(nRuns, 1);

            parfor k = 1:nRuns
                [p_temp, resNorm] = lsqnonlin(resFun, p0(k,:), lb, ub, opts);
                allP(k,:) = p_temp;
                allres(k)   = resNorm;
            end

            % Select best AFTER the parfor
            [resvalue, idx] = min(allres);
            p_est = allP(idx,:);
            Msol_final(counter_run) = p_est(1); Ksol_final(counter_run) = p_est(2); k0sol_final(counter_run) = p_est(3); % Adjusted fitting parameters
            Vol_final(:,counter_run) = (Msol_final(counter_run).*(C_n + Ksol_final(counter_run)*A_n) + k0sol_final(counter_run))/1000; % Direct volume result from calibration
        else
            equation_used(counter_run) = equation_final;
            Vol_final(:,counter_run) = (Msol_final(counter_run).*(C_n + Ksol_final(counter_run)*A_n.^nsol_final(counter_run)))/1000; % Direct volume results from calibration
        end
        
        % Central difference derivative
        for p = half_window+1:round(length(Vol_final(:,counter_run))-half_window)-1
            Flow_calc_final_r(p,counter_run) = (Vol_final(p+half_window,counter_run) - Vol_final(p-half_window,counter_run))/(2*half_window_length);
        end
        Flow_calc_final_r(1:half_window,counter_run) = Flow_calc_final_r(half_window+1,counter_run);

        % Instantaneous filtered derivative
        Vol_final_f = sgolayfilt(Vol_final(:,counter_run), 3, frame_len);
        Flow_calc_final_f(:,counter_run) = diff(Vol_final(:,counter_run))/dt;

        % Cumuluative flow data
        Flow_calc_final_cum = [Flow_calc_final_f(:,counter_run) Flow_calc_final_r(:,counter_run)];
        Flow_calc_final_mean(:,counter_run) = mean(Flow_calc_final_cum,2);

        counter_run = counter_run + 1;
    end
end
Flow_overall_mean = mean(Flow_calc_final_mean,2); % Mean of all outcomes

% Align predicted and measured flow signals
t_S1 = t_S1 - t_S1(1);
Flow = Flow_overall_mean;
t_flow_map = t_flow(1):dt:t_flow(end); t_flow_map = t_flow_map'; % Ensure measured and modeled signals are at the same sampling frequency
Flow_SPIRO_map = interp1(t_flow,Flow_SPIRO,t_flow_map,'linear','extrap'); 

% Determine delay between measured and modeled signals using correlation
if Subject == 3
    e_corr = 165; % Time point for correlation segment end
    tf_e = find(abs(t_flow_map - e_corr)<dt); tf_e = tf_e(1);
    corr_seg_SPIRO = 1:tf_e;

    e_corr = 280; % Time point for correlation segment end
    tf_e = find(abs(t_S1 - e_corr)<dt); tf_e = tf_e(1);
    corr_seg = 1:tf_e;
    delay = finddelay(Flow_SPIRO_map(corr_seg_SPIRO),Flow(corr_seg));
else
    corr_seg = 1:Start_IC_FVC_idx;
    delay = finddelay(Flow_SPIRO_map(corr_seg),Flow(corr_seg));
end
time_shift_idx = abs(delay);
time_shift = delay*dt;

Flow = Flow_calc_final_mean; Volume_fit = Vol_final(2:end,:);

% Overlay signals using calculated time delay
if time_shift > 0
    Flow_shift = Flow(time_shift_idx:end,:);
    Volume_fit_shift = Volume_fit(time_shift_idx:end,:);
else
    Flow_shift = [zeros(time_shift_idx,Total_outcomes); Flow];
    Volume_fit_shift = [zeros(time_shift_idx,Total_outcomes); Volume_fit];
end

% Ensure signals are same length
if length(Flow_shift) > length(Flow_SPIRO_map)
    study_end = length(Flow_SPIRO_map);
    Flow_cut = Flow_shift(1:study_end,:);
    Volume_fit_cut = Volume_fit_shift(1:study_end,:);
    Flow_SPIRO_cut = Flow_SPIRO_map;
    t_flow_cut = t_flow_map;
else
    study_end = length(Flow_shift);
    Flow_SPIRO_cut = Flow_SPIRO_map(1:study_end);
    t_flow_cut = t_flow_map(1:study_end);
    Flow_cut = Flow_shift;
    Volume_fit_cut = Volume_fit_shift;
end
Flow_final = Flow_cut; Volume_fit_final = Volume_fit_cut; 

% Adjust comparison boundaries to account for subject adjustment to airflow transducer at beginning of study
if Subject == 1
    if Trial == 1
        time_adj = 30;
    else
        time_adj = 4.2;
    end
elseif Subject == 2
    if Trial == 1
        time_adj = 5;
    else
        time_adj = 14.7; 
    end
elseif Subject == 3
    time_adj = 30;
else
    time_adj = 14.127;
end
new_start = round(time_adj/dt);
t_flow_adj = t_flow_cut(new_start:end);
Flow_SPIRO_adj = Flow_SPIRO_cut(new_start:end);
Flow_final_adj = Flow_final(new_start:end,:);
Volume_fit_final_adj = Volume_fit_final(new_start:end,:);

% Find first starting inspiration point to avoid kinks in dissolved oxygen
[~, locs] = findpeaks(-Volume_fit_final_adj(:,1),'MinPeakDistance', round(1.5/dt));
final_start = []; loc_counter = 1;
while double(isempty(final_start)) == 1
    loc_ext = locs(loc_counter) + round(0.5/dt);
    if Volume_fit_final_adj(loc_ext) > Volume_fit_final_adj(locs(loc_counter)) % Location detected is inspiration point
        final_start = locs(loc_counter);
    else
    end
    loc_counter = loc_counter + 1;
end

t_flow_adj = t_flow_adj(final_start:end);
Flow_SPIRO_adj = Flow_SPIRO_adj(final_start:end);
Flow_final_adj = Flow_final_adj(final_start:end,:);
Volume_fit_final_adj = Volume_fit_final_adj(final_start:end,:);

% Flow integration to obtain volume profiles
counter_run = 1;
Twin = 30; Nwin = round(Twin/dt);
Volume_final_adj = zeros(size(Flow_final_adj));
for i = 1:length(FRC_all)
    for n = 1:length(Inc_factor_all)
        FRC = FRC_all(i);
        Flow_model = Flow_final_adj(:,counter_run) - movmean(Flow_final_adj(:,counter_run),Nwin);
        Volume_final_adj(:,counter_run) = cumtrapz(Flow_model)*dt;
        Vol_int_FRC = mean(Volume_final_adj(Start_NB_idxr,counter_run));
        vert_shift(counter_run) = FRC/1000 - Vol_int_FRC;
        counter_run = counter_run + 1;
    end
end
Flow_meas = Flow_SPIRO_adj - movmean(Flow_SPIRO_adj,Nwin);
Vol_meas_adj = cumtrapz(Flow_meas)*dt;

%% Volume inputs for oxygen mass transfer model
tend_ss = 360; % Time to allow model to reach steady state
N_ss = round(tend_ss/dt);
br = 15/60; % Approximated normal breathing rate for steady state segment

% Volume input using measured flow signal
% Adjust normal breathing region indices to account for signal alignment for the estimation of TV for steady state portion
Start_NB_idxr = Start_Breath_NB - sign(delay)*time_shift_idx - new_start - final_start;
End_NB_idxr = End_Breath_NB - sign(delay)*time_shift_idx - new_start - final_start;
TV_meas_mean = mean(Vol_meas_adj(End_NB_idxr) - Vol_meas_adj(Start_NB_idxr));
FRC_unadjusted = mean(Vol_meas_adj(Start_NB_idxr)); % Raw mean starting inspiration point to determine vertical shift to FRC

% Volume input using model
Vol_input_model = zeros(N_ss + length(Volume_final_adj),Total_outcomes);
for i = 1:length(FRC_all)
        Start_point = 1000*(Volume_final_adj(1,i) + vert_shift(i));
        FRC = Start_point;
        TV = TV_meas_mean*1000;
        clear t_ss Vi
        for k=1:N_ss
            t_ss(k) = (k-1)*dt;
            Vi(k) = 0.5*TV*sin(2*pi*br*t_ss(k) - pi/2)+(FRC+0.5*TV);
        end
        Vol_input_model(:,i) = [Vi'; (Volume_final_adj(:,i) + vert_shift(i))*1000];
end
N_total = N_ss + length(Volume_final_adj);
t_input = (0:N_total-1)*dt; 


% Volume input using measured data
Vol_input_meas = zeros(N_ss + length(Vol_meas_adj),length(FRC_all));
for i = 1:length(FRC_all)
    vert_shift_meas = FRC_all(i)/1000 - FRC_unadjusted;
    Start_point = 1000*(Vol_meas_adj(1) + vert_shift_meas);
    FRC = Start_point;
    TV = TV_meas_mean*1000;
    clear t_ss Vi
    for k=1:N_ss
        t_ss(k) = (k-1)*dt;
        Vi(k) = 0.5*TV*sin(2*pi*br*t_ss(k) - pi/2)+(FRC+0.5*TV);
    end
    Vol_input_meas(:,i) = [Vi'; (Vol_meas_adj + vert_shift_meas)*1000];
end

%% Oxygen mass transfer model run
% Load model parameters
Age = Subject_Age(data_idx); Height = Subject_Height(data_idx); Weight = Subject_Weight(data_idx);
BSA = 0.007184*(Weight^0.425)*(Height^0.725);
if double(contains(Subject_Sex(data_idx),'M')) == 1
    load OSAParameters_Male.mat
    Qp = Qpi; Qs = Qsi;
    MRO2 = BSA*(138.1 - 11.49*log(Age) + 0.378*HRi)*(nV/60);
else
    load OSAParameters_Female.mat
    Qp = Qpi; Qs = Qsi;
    MRO2 = BSA*(138.1 - 17.04*log(Age) + 0.378*HRi)*(nV/60);
end

VD_spiro = 93 + 45; % Sum of flow head and bacterial filter dead space
VD_anatom = 0.35*Tid_Vol_all; % Anatomical dead space is 35% of tidal volume
VD_total = VD_spiro + VD_anatom;
Alv_pars = [yO2, PB, PH2O, R, T, Beta_p, k_l, VD_spiro, VD_anatom];
PIO2 = yO2*(PB-PH2O);

% Lookup table approximation for oxygenation
Cd_T = (linspace(0,2e-6,8000))';
S_T = SatO2_2(Cd_T,Beta_p);
CT_T = 4*CHb.*S_T + Cd_T;

% Solving parameters
dt_O2 = 0.01;
t_Data = t_input;
s = floor(t_Data(end)/dt_O2);
Total = Total_outcomes + length(FRC_all);
CsaO2d_all = zeros(s,Total); Volume_all = zeros(s,Total);
F_Cd = griddedInterpolant(CT_T(:), Cd_T(:), 'linear', 'linear');

for p = 1:Total
    if p <= Total_outcomes
        p_idx = p;
        V_Data = Vol_input_model(:,p_idx);
    else
        p_idx = p - Total_outcomes;
        V_Data = Vol_input_meas(:,p_idx);
    end

    % Solving parameters
    dz = vpci*dt_O2;
    k = floor(Lc/dz);
    n_dt = floor(tcyclei/dt_O2);
    a_dt = floor(tsai/dt_O2);
    c_dt = floor(tsyscapi/dt_O2);
    
    % Initialize variable vectors
    t_O2 = zeros(1,s); PDO2 = zeros(1,s); 
    PAO2 = zeros(1,s);  CAO2 = zeros(1,s);
    PpaO2 = zeros(1,s); CpaO2d = zeros(1,s); CpaO2T = zeros(1,s); SpaO2 = zeros(1,s);
    PpvO2 = zeros(1,s); CpvO2d = zeros(1,s); CpvO2T = zeros(1,s); SpvO2 = zeros(1,s);
    PsaO2 = zeros(1,s); CsaO2d = zeros(1,s); CsaO2T = zeros(1,s); SsaO2 = zeros(1,s);
    PsvO2 = zeros(1,s); CsvO2d = zeros(1,s); CsvO2T = zeros(1,s); SsvO2 = zeros(1,s);
    PcO2 = zeros(1,s); CcO2 = zeros(1,s);
    CpcO2T = zeros(k+1,s); CpcO2d = zeros(k+1,s); SpcO2 = zeros(k+1,s); PpcO2 = zeros(k+1,s);
    z = zeros(k+1,1);
    CpcO2T1 = zeros(k+1,1); CpcO2d1 = zeros(k+1,1);
    V = zeros(1,s);

    % Initialize variables (t=0)
    PDO2(1) = PAO2i; 
    PAO2(1) = PAO2i;
    CAO2(1) = PAO2(1)*Beta_p;

    PpvO2(1) = PAO2i;
    CpvO2d(1) = PpvO2(1)*Beta_p;
    SpvO2(1) = SatO2_2(CpvO2d(1),Beta_p);
    CpvO2T(1) = 4*CHb*SpvO2(1) + CpvO2d(1);

    CpaO2T(1:n_dt) = CpvO2T(1)-MRO2/Qs;
    CpaO2d(1:n_dt) = F_Cd(CpaO2T(1));
    PpaO2(1:n_dt) = CpaO2d(1)/Beta_p;
    SpaO2(1:n_dt) = SatO2_2(CpaO2d(1),Beta_p);

    PsaO2(1:a_dt+1) = PpvO2(1);
    CsaO2d(1:a_dt+1) = PsaO2(1)*Beta_p;
    SsaO2(1:a_dt+1) = SatO2_2(CsaO2d(1),Beta_p);
    CsaO2T(1:a_dt+1) = 4*CHb*SsaO2(1) + CsaO2d(1);

    PsvO2(1:c_dt+1) = PpaO2(1);
    CsvO2d(1:c_dt+1) = CpaO2d(1);
    SsvO2(1:c_dt+1) = SpaO2(1);
    CsvO2T(1:c_dt+1) = CpaO2T(1);

    for n=2:k+1
        CpcO2T1(1) = CpaO2T(1);
        CpcO2d1(1) = CpaO2d(1);
        z(n) = z(n-1)+dz;
        CpcO2T1(n) = CpcO2T1(n-1)+(k_l/Qp)*(dz/Lc)*(CAO2(1)-CpcO2d1(n-1));
        CpcO2d1(n) = F_Cd(CpcO2T1(n));
    end

    CpcO2T(:,1) = CpcO2T1;
    CpcO2d(:,1) = CpcO2d1;
    SpcO2(:,1) = SatO2_2(CpcO2d(:,1),Beta_p);

    CcO2(1) = trapz(z(:,1),CpcO2d(:,1))./Lc;
    PcO2(1) = CcO2(1)/Beta_p;

    t_O2(1) = 0; V(1) = V_Data(1);

    for i=2:s
        %Time
        t_O2(i) = (i-1)*dt_O2;

        %Lung Volume
        V(i) = interp1(t_Data,V_Data,t_O2(i));
        V(i) = max(V(i), 1.25*VD_anatom); % To prevent absolute alveolar volume from being <= 0

        %Calculate arterial oxygenation
        CpaO2T(i+n_dt-1) = CpvO2T(i-1)-MRO2/Qs;
        CpaO2d(i) = F_Cd(CpaO2T(i));
        PpaO2(i) = CpaO2d(i)/Beta_p;
        SpaO2(i) = SatO2_2(CpaO2d(i),Beta_p);

        % Pulmonary capillary oxygenation
        CpcO2T(1,i) = CpaO2T(i);
        CpcO2T(2:end,i) = CpcO2T(1:(end-1),i-1) + (k_l/Qp)*(dz/Lc)*(CAO2(i-1)-CpcO2d(1:(end-1),i-1));
        CpcO2d(:,i) = F_Cd(CpcO2T(:,i));
        PpcO2(:,i) = CpcO2d(:,i)/Beta_p;
        SpcO2(:,i) = SatO2_2(CpcO2d(:,i),Beta_p);

        % Venous oxygenation
        CpvO2T(i) = CpcO2T(end,i);
        CpvO2d(i) = F_Cd(CpvO2T(i));
        PpvO2(i) = CpvO2d(i)/Beta_p;
        SpvO2(i) = SatO2_2(CpvO2d(i),Beta_p);

        % Systemic capillaries input
        CsaO2T(i+a_dt) = CpvO2T(i);
        CsaO2d(i) = F_Cd(CsaO2T(i));
        PsaO2(i) = CsaO2d(i)/Beta_p;
        SsaO2(i) = SatO2_2(CsaO2d(i),Beta_p);

        % Systemic capillaries output
        CsvO2T(i+c_dt) = CsaO2T(i)-MRO2/Qs;
        CsvO2d(i) = F_Cd(CsvO2T(i));
        PsvO2(i) = CsvO2d(i)/Beta_p;
        SsvO2(i) = SatO2_2(CsvO2d(i),Beta_p);

        % Alveolar oxygen partial pressure
        CcO2(i) = trapz(z(:,1),CpcO2d(:,i))./Lc;
        PcO2(i) = CcO2(i)/Beta_p;
        PDO2(i) = DeadSpace_MassBalance(V(i),V(i-1),dt_O2,PDO2(i-1),PAO2(i-1),Alv_pars); % For compartment model of dead space
        PAO2(i) = Alv_MassBalance_VD(V(i),V(i-1),dt_O2,PcO2(i-1),PAO2(i-1),PDO2(i-1),Alv_pars); % For compartment model of dead space
        CAO2(i) = PAO2(i)*Beta_p;
    end
    CsaO2d_all(:,p) = CsaO2d;
    Volume_all(:,p) = V;
end

