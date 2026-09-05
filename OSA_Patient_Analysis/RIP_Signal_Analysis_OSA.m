%% Load data from .EDF file
[filename, filepath] = uigetfile('Select patient .EDF file',[],'*.EDF');
channels = ["Resp Chest","Resp Abdomen","Tid-Vol","SpO2","PR","C-Flow","Leak"];
[data, ann] = edfread([filepath filename], SelectedSignals=channels);
data.Properties.DimensionNames{1} = 'Time'; % Change column name to eliminate space
time_vec = seconds(data.Time); % Convert data to a double array
t_int = time_vec(2)-time_vec(1); % Interval between recording times
n_data = length(data.RespChest{1}); % Number of recording points within each interval
dt = t_int/(n_data); % Time step
t_initial = time_vec(1);
total_rec = size(data,1); % Number of rows in data matrix
t(1,:) = t_initial; % Recording start time
for i=2:total_rec*n_data
    t(i,:)=t(i-1,:)+dt; % Time vector for data
end
RespChest = vertcat(data.RespChest{:}); % Chest signal
RespAbdomen = vertcat(data.RespAbdomen{:}); % Abdominal signal
Tid_Vol_m = vertcat(data.Tid_Vol{:}); % Tidal volume signal (channel only active for CPAP portion)
SpO2 = vertcat(data.SpO2{:}); % Pulse oximetry signal
HR = vertcat(data.PR{:}); % Heart rate signal (Pulse rate)
C_Flow = vertcat(data.C_Flow{:}); % CPAP flow signal

%% Isolate analysis region and events
% Isolate events from annotations
Event_type = ann.Annotations; % Extract event type information 
Apnea_rows = find(contains(Event_type,caseInsensitivePattern('Apnea'))); % Rows in data table for each apnea
Hypopnea_rows = find(contains(Event_type,caseInsensitivePattern('Hypopnea'))); % Rows in data table for each hypopnea
Wake_rows = find(contains(Event_type,caseInsensitivePattern('Sleep stage W')));  % Rows in data table for each wake stage
N1_rows = find(contains(Event_type,caseInsensitivePattern('Sleep stage N1')) | contains(Event_type,caseInsensitivePattern('Sleep stage 1')));  % Rows in data table for each N1 stage
N2_rows = find(contains(Event_type,caseInsensitivePattern('Sleep stage N2')) | contains(Event_type,caseInsensitivePattern('Sleep stage 2')));  % Rows in data table for each N2 stage
N3_rows = find(contains(Event_type,caseInsensitivePattern('Sleep stage N3')) | contains(Event_type,caseInsensitivePattern('Sleep stage 3')));  % Rows in data table for each N3 stage
R_rows = find(contains(Event_type,caseInsensitivePattern('Sleep stage R')));  % Rows in data table for each R stage
Time_Events = seconds(ann.Onset);
Duration = seconds(ann.Duration);

% Extract wake stage times and indices
for i=1:length(Wake_rows) 
    Start_Wake(i) = Time_Events(Wake_rows(i));
    Start = find(abs(t - Start_Wake(i))<dt); Start_Wake_idx(i) = Start(1);
    Duration_Wake = Duration(Wake_rows(i));
    if double(isnan(Duration_Wake)) == 1
        End_Wake(i) = Start_Wake(i);
    else
        End_Wake(i) = Start_Wake(i) + Duration_Wake;
    end
    End = find(abs(t - End_Wake(i))<dt); End_Wake_idx(i) = End(1);
end

% Extract N1 stage times and indices
for i=1:length(N1_rows) 
    Start_N1(i) = Time_Events(N1_rows(i));
    Start = find(abs(t - Start_N1(i))<dt); Start_N1_idx(i) = Start(1);
    Duration_N1 = Duration(N1_rows(i));
    End_N1(i) = Start_N1(i) + Duration_N1;
    End = find(abs(t - End_N1(i))<dt); End_N1_idx(i) = End(1);
end

% Extract N2 stage times and indices
for i=1:length(N2_rows) 
    Start_N2(i) = Time_Events(N2_rows(i));
    Start = find(abs(t - Start_N2(i))<dt); Start_N2_idx(i) = Start(1);
    Duration_N2 = Duration(N2_rows(i));
    End_N2(i) = Start_N2(i) + Duration_N2;
    End = find(abs(t - End_N2(i))<dt); End_N2_idx(i) = End(1);
end

% Extract N3 stage times and indices
for i=1:length(N3_rows) 
    Start_N3(i) = Time_Events(N3_rows(i));
    Start = find(abs(t - Start_N3(i))<dt); Start_N3_idx(i) = Start(1);
    Duration_N3 = Duration(N3_rows(i));
    End_N3(i) = Start_N3(i) + Duration_N3;
    End = find(abs(t - End_N3(i))<dt); End_N3_idx(i) = End(1);
end

% Extract R stage times and indices
for i=1:length(R_rows) 
    Start_R(i) = Time_Events(R_rows(i));
    Start = find(abs(t - Start_R(i))<dt); Start_R_idx(i) = Start(1);
    Duration_R = Duration(R_rows(i));
    End_R(i) = Start_R(i) + Duration_R;
    End = find(abs(t - End_R(i))<dt); End_R_idx(i) = End(1);
end

% Extract apnea times and indicies
for i=1:length(Apnea_rows) 
    Start_Apnea(i) = Time_Events(Apnea_rows(i));
    Start = find(abs(t - Start_Apnea(i))<dt); Start_Apnea_idx(i) = Start(1);
    Duration_Apnea = Duration(Apnea_rows(i));
    End_Apnea(i) = Start_Apnea(i) + Duration_Apnea;
    End = find(abs(t - End_Apnea(i))<dt); End_Apnea_idx(i) = End(1);
end

% Extract hypopnea times and indicies
for i=1:length(Hypopnea_rows) 
    Start_Hypopnea(i) = Time_Events(Hypopnea_rows(i));
    Start = find(abs(t - Start_Hypopnea(i))<dt); Start_Hypopnea_idx(i) = Start(1);
    Duration_Hypopnea = Duration(Hypopnea_rows(i));
    if double(isnan(Duration_Hypopnea)) == 1
        End_Hypopnea(i) = Start_Hypopnea(i);
    else
        End_Hypopnea(i) = Start_Hypopnea(i) + Duration_Hypopnea;
    end
    End = find(abs(t - End_Hypopnea(i))<dt); End_Hypopnea_idx(i) = End(1);
end

%% Process signals and identify calibration regions
% Identify sample normal breathing region for drift threshold 
Start_NB_idx_cal = Start_Wake_idx(3); % Randomly select a wake segment near beginning of study
End_NB_idx_cal = End_Wake_idx(3); 
% Process whole signal to remove apnea drift 
[Chest_S1, Abdomen_S1] = Signal_Processing_Final(t, RespChest, RespAbdomen, Start_Apnea_idx, End_Apnea_idx, Start_NB_idx_cal, End_NB_idx_cal, dt);

% Isolate CPAP portion of study
if double(contains(filename,'OSA6')) == 1
    % OSA Patient 1 in paper
    Start_time_CPAP = 29346.5; Start_S1_CPAP = round(Start_time_CPAP/dt);
    End_time_CPAP =  29800; End_S1_CPAP = round(End_time_CPAP/dt);
elseif double(contains(filename,'OSA5')) == 1
    % OSA Patient 2 in paper
    Start_time_CPAP = 29005.4; Start_S1_CPAP = round(Start_time_CPAP/dt);
    End_time_CPAP =  29400; End_S1_CPAP = round(End_time_CPAP/dt);
else
    % OSA Patient 3 in paper
    OSA23_input = input('Which section do you want to analyze for this subject (1 or 2)?');
    if OSA23_input == 1
        Start_time_CPAP = 21417.4; Start_S1_CPAP = round(Start_time_CPAP/dt);
        End_time_CPAP =  21900; End_S1_CPAP = round(End_time_CPAP/dt);
    else
        Start_time_CPAP = 23983.9; Start_S1_CPAP = round(Start_time_CPAP/dt);
        End_time_CPAP =  24500; End_S1_CPAP = round(End_time_CPAP/dt);
    end
end
Abdomen_S1_CPAP = Abdomen_S1(Start_S1_CPAP:End_S1_CPAP);
Chest_S1_CPAP = Chest_S1(Start_S1_CPAP:End_S1_CPAP);
HR_CPAP = HR(Start_S1_CPAP:End_S1_CPAP);
SpO2_CPAP = SpO2(Start_S1_CPAP:End_S1_CPAP);
Tid_Vol_m_CPAP = Tid_Vol_m(Start_S1_CPAP:End_S1_CPAP);
C_Flow_CPAP = C_Flow(Start_S1_CPAP:End_S1_CPAP);
t_S1_CPAP = t(Start_S1_CPAP:End_S1_CPAP);

% Indentify normal breaths in actual analysis region and/or across whole study (exclude irregular breaths)
CPAP_cal = input('Do you want to use wake without CPAP to calibrate tidal volume? 0 = No, 1 = Yes:');
if CPAP_cal == 1
    % Identify normal breaths during wake segments across whole study (TV calibration)
    if double(contains(filename,'OSA6')) == 1
        CPAP_onset = 15979;
    elseif double(contains(filename,'OSA5')) == 1
        CPAP_onset = 16855;
    else
        CPAP_onset = 21087;
    end
    CPAP_onset_idx = find(abs(t-CPAP_onset)<dt); CPAP_onset_idx = CPAP_onset_idx(1);
    Wake_rows_CPAP = find(Start_Wake_idx < CPAP_onset_idx & End_Wake_idx < CPAP_onset_idx);
    Start_NB_idx_cal_CPAP = Start_Wake_idx(Wake_rows_CPAP);
    End_NB_idx_cal_CPAP = End_Wake_idx(Wake_rows_CPAP);
    [Start_Breath_NB_CPAP, End_Breath_NB_CPAP] = Eupnea_Detection_Patient_Wake(Start_NB_idx_cal_CPAP,End_NB_idx_cal_CPAP,dt,Abdomen_S1,Chest_S1);
    
    % Identify normal breaths during chosen sleep stage in analysis region (FRC calibration)
    NB_cal_CPAP = input('Which stage do you want to use to calibrate the FRC for the CPAP region? Wake = 0, N1 = 1, N2 = 2, N3 = 3, R = 4');
    if NB_cal_CPAP == 0
        Wake_rows_CPAP = find(Start_Wake_idx > Start_S1_CPAP & End_Wake_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_Wake_idx(Wake_rows_CPAP);
        End_NB_idx_cal_CPAP = End_Wake_idx(Wake_rows_CPAP);
    elseif NB_cal_CPAP == 1
        N1_rows_CPAP = find(Start_N1_idx > Start_S1_CPAP & End_N1_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N1_idx(N1_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N1_idx(N1_rows_CPAP);
    elseif NB_cal_CPAP == 2
        N2_rows_CPAP = find(Start_N2_idx > Start_S1_CPAP & End_N2_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N2_idx(N2_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N2_idx(N2_rows_CPAP);
    elseif NB_cal_CPAP == 3
        N3_rows_CPAP = find(Start_N3_idx > Start_S1_CPAP & End_N3_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N3_idx(N3_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N3_idx(N3_rows_CPAP);
    else
        R_rows_CPAP = find(Start_R_idx > Start_S1_CPAP & End_R_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_R_idx(R_rows_CPAP);
        End_NB_idx_cal_CPAP = End_R_idx(R_rows_CPAP);
    end
    [Start_Breath_FRC, ~] = Eupnea_Detection_Patient(Start_NB_idx_cal_CPAP,End_NB_idx_cal_CPAP,dt,Abdomen_S1_CPAP,Chest_S1_CPAP,Start_S1_CPAP,End_S1_CPAP);
else
    % Identify normal breaths during chosen sleep stage in analysis region (TV and FRC calibration)
    NB_cal_CPAP = input('Which stage do you want to use to calibrate the CPAP region? Wake = 0, N1 = 1, N2 = 2, N3 = 3, R = 4');
    if NB_cal_CPAP == 0
        Wake_rows_CPAP = find(Start_Wake_idx > Start_S1_CPAP & End_Wake_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_Wake_idx(Wake_rows_CPAP);
        End_NB_idx_cal_CPAP = End_Wake_idx(Wake_rows_CPAP);
    elseif NB_cal_CPAP == 1
        N1_rows_CPAP = find(Start_N1_idx > Start_S1_CPAP & End_N1_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N1_idx(N1_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N1_idx(N1_rows_CPAP);
    elseif NB_cal_CPAP == 2
        N2_rows_CPAP = find(Start_N2_idx > Start_S1_CPAP & End_N2_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N2_idx(N2_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N2_idx(N2_rows_CPAP);
    elseif NB_cal_CPAP == 3
        N3_rows_CPAP = find(Start_N3_idx > Start_S1_CPAP & End_N3_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_N3_idx(N3_rows_CPAP);
        End_NB_idx_cal_CPAP = End_N3_idx(N3_rows_CPAP);
    else
        R_rows_CPAP = find(Start_R_idx > Start_S1_CPAP & End_R_idx < End_S1_CPAP);
        Start_NB_idx_cal_CPAP = Start_R_idx(R_rows_CPAP);
        End_NB_idx_cal_CPAP = End_R_idx(R_rows_CPAP);
    end
    [Start_Breath_NB_CPAP, End_Breath_NB_CPAP] = Eupnea_Detection_Patient(Start_NB_idx_cal_CPAP,End_NB_idx_cal_CPAP,dt,Abdomen_S1_CPAP,Chest_S1_CPAP,Start_S1_CPAP,End_S1_CPAP);
end

% Identify asynchronous motion during apnea segments (across whole signal)
[Start_Asy, End_Asy] = Asynchronous_Segment_Apnea(dt,Abdomen_S1,Chest_S1,Start_Apnea_idx,End_Apnea_idx);

% Normalization of signals for calibration (for better problem conditioning and avoiding negative values)
epsilon = 0.05; % Bound signals in the range [epsilon, 1] 
abs_max_CPAP = max([max(Chest_S1_CPAP), max(Abdomen_S1_CPAP)]); % Maximum of signals in analysis region
abs_min_CPAP = min([min(Chest_S1_CPAP), min(Abdomen_S1_CPAP)]); % Minimum of signals in analysis region
A_n_CPAP = ((Abdomen_S1_CPAP - abs_min_CPAP)*(1-epsilon)/(abs_max_CPAP - abs_min_CPAP)) + epsilon;
C_n_CPAP = ((Chest_S1_CPAP - abs_min_CPAP)*(1-epsilon)/(abs_max_CPAP - abs_min_CPAP)) + epsilon;

if Start_time_CPAP == 23983.9 && double(contains(filename,'OSA-23')) == 1 % Problems with negative values in solver (for wake/apneas regions outside analysis segment)
    abs_max_CPAP = max([max(Chest_S1_CPAP), max(Abdomen_S1_CPAP), max(Chest_S1(Start_Asy)), max(Abdomen_S1(Start_Asy)), max(Chest_S1(End_Asy)), max(Abdomen_S1(End_Asy)), max(Chest_S1(Start_Breath_NB_CPAP)), max(Abdomen_S1(Start_Breath_NB_CPAP)), max(Chest_S1(End_Breath_NB_CPAP)), max(Abdomen_S1(End_Breath_NB_CPAP))]); % Maximum of signals in across all calibration regions
    abs_min_CPAP = min([min(Chest_S1_CPAP), min(Abdomen_S1_CPAP), min(Chest_S1(Start_Asy)), min(Abdomen_S1(Start_Asy)), min(Chest_S1(End_Asy)), min(Abdomen_S1(End_Asy)), min(Chest_S1(Start_Breath_NB_CPAP)), min(Abdomen_S1(Start_Breath_NB_CPAP)), min(Chest_S1(End_Breath_NB_CPAP)), min(Abdomen_S1(End_Breath_NB_CPAP))]); % Minimum of signals in across all calibration regions
    A_n_CPAP = ((Abdomen_S1_CPAP - abs_min_CPAP)*(1-epsilon)/(abs_max_CPAP - abs_min_CPAP)) + epsilon;
    C_n_CPAP = ((Chest_S1_CPAP - abs_min_CPAP)*(1-epsilon)/(abs_max_CPAP - abs_min_CPAP)) + epsilon;
else
end

% Calculate K (linear) from asynchronous segments during apneas
for n=1:length(Start_Asy) % Cycle through each identified asynchronous segment
    deluV_Chest(n) = Chest_S1(End_Asy(n))- Chest_S1(Start_Asy(n)); % Voltage change in thoracic signal during each asynchronous segment
    deluV_Abd(n) = Abdomen_S1(End_Asy(n))- Abdomen_S1(Start_Asy(n)); % Voltage change in abdominal signal during each asynchronous segment
    K_seg(n) = -deluV_Chest(n)/deluV_Abd(n); % K value for each asynchronous segment
end

% Remove any outliers in K_seg using median absolute deviation (MAD)
m = median(K_seg); mad_val = mad(K_seg,1);       
outliers = abs(K_seg - m) > 3*mad_val;
if double(isempty(outliers)) == 1
else
    outlier_idx = find(double(outliers) == 1);
    K_seg(outlier_idx) = [];
    Start_Asy(outlier_idx) = [];
    End_Asy(outlier_idx) = [];
end
K = mean(K_seg); % Adjusted K value

%% Load OSA patient demographics and reference volumes
[demo_file, demo_path] = uigetfile('*.xlsx','Select the Excel file with OSA patient demographics and lung volume references');
opts.DataRange = 'A4:T6';
Data = readtable([demo_path demo_file],opts,'Sheet','Demographics');
if double(contains(filename,'OSA6')) == 1
    data_idx = 1;
elseif double(contains(filename,'OSA5')) == 1
    data_idx = 2;
else
    data_idx = 3;
end
Subject_No = table2array(Data(data_idx,1)); Subject_Sex = table2array(Data(data_idx,2)); Subject_Age = table2array(Data(data_idx,3)); Subject_Height = table2array(Data(data_idx,4)); Subject_Weight = table2array(Data(data_idx,5));
Tid_Vol_mean = table2array(Data(data_idx,9)); Tid_Vol_lb = table2array(Data(data_idx,10)); Tid_Vol_ub = table2array(Data(data_idx,11));
FRC_mean = table2array(Data(data_idx,12)); FRC_lb = table2array(Data(data_idx,13)); FRC_ub = table2array(Data(data_idx,14));
TLC_mean = table2array(Data(data_idx,15)); TLC_lb = table2array(Data(data_idx,16)); TLC_ub = table2array(Data(data_idx,17));
RV_mean = table2array(Data(data_idx,18)); RV_lb = table2array(Data(data_idx,19)); RV_ub = table2array(Data(data_idx,20));
BMI = Subject_Weight/((Subject_Height/100)^2);

% Adjust reference volumes for patients with obesity (Paper: The Effects of Body Mass Index on Lung Volumes)
if BMI <= 25
    TV_factor_BMI = 1;
    FRC_factor_BMI = 1;
    TLC_factor_BMI = 1;
    RV_factor_BMI = 1;
elseif BMI > 25 && BMI <= 30
    TV_factor_BMI = 1;
    FRC_factor_BMI = 0.89;
    TLC_factor_BMI = 0.97;
    RV_factor_BMI = 0.97;
elseif BMI > 30 && BMI <= 35
    TV_factor_BMI = 1;
    FRC_factor_BMI = 0.78;
    TLC_factor_BMI = 0.93;
    RV_factor_BMI = 0.96;
elseif BMI > 35 && BMI <= 40
    TV_factor_BMI = 1;
    FRC_factor_BMI = 0.72;
    TLC_factor_BMI = 0.92;
    RV_factor_BMI = 0.95;
else
    TV_factor_BMI = 0.71; % (Paper: Load compensation in obese patients during quiet tidal breathing)
    FRC_factor_BMI = 0.67;
    TLC_factor_BMI = 0.88;
    RV_factor_BMI = 0.91;
end
TV_all = TV_factor_BMI*[Tid_Vol_lb Tid_Vol_mean Tid_Vol_ub];
FRC_all = FRC_factor_BMI*[FRC_lb FRC_mean, FRC_ub];
TLC_all = TLC_factor_BMI*[TLC_lb TLC_mean, TLC_ub];
RV_all = RV_factor_BMI*[RV_lb RV_mean, RV_ub];

% Adjust TV based on body position 
if BMI < 25
    TV_supine_factor = 0.92; 
else
    TV_supine_factor = 1.06; 
end

% Adjust TV based on sleep stage 
if CPAP_cal == 1
    % Wake segment used to calibrate TV (no affect of sleep stage required)
    TV_CPAP = TV_supine_factor*TV_all;
else
    % Analysis region used to calibrate TV (no affect of sleep stage required)
    if NB_cal_CPAP == 0 % Wake stage
        TV_slfactor_CPAP = 1;
    elseif NB_cal_CPAP == 1 % Sleep stage N1
        TV_slfactor_CPAP = 1;
    elseif NB_cal_CPAP == 2 % Sleep stage N2
        TV_slfactor_CPAP = 0.84;
    elseif NB_cal_CPAP == 3 % Sleep stage N3
        TV_slfactor_CPAP = 0.84; 
    else % Sleep stage R
        TV_slfactor_CPAP = 0.80; 
    end
    TV_CPAP = TV_supine_factor*TV_slfactor_CPAP*TV_all;
end

% Adjust FRC based on body position
if BMI < 25
    FRC_supine_factor = 0.77; 
else
    FRC_supine_factor = 1; 
end

% Adjust FRC based on CPAP level
CPAP_level = input('Enter the CPAP pressure (cm H2O):');
CPAP_factor = interp1([0, 5, 10, 15, 20],[1, 1.12, 1.27, 1.41, 1.54],CPAP_level); % Increase in FRC due to CPAP (Fixed CPAP at 10 cmH 2O May Replace Manual Titration in Moderate to Severe OSA Patients...)

% Adjust FRC based on sleep stage
if NB_cal_CPAP == 0 % Wake stage
    FRC_slfactor_CPAP = 1;
elseif NB_cal_CPAP == 1 % Sleep stage N1
    FRC_slfactor_CPAP = 1;
elseif NB_cal_CPAP == 2 % Sleep stage N2
    FRC_slfactor_CPAP = 0.89;
elseif NB_cal_CPAP == 3 % Sleep stage N3
    FRC_slfactor_CPAP = 0.89;
else % Sleep stage R
    FRC_slfactor_CPAP = 0.86;
end
% Cumulative adjustment
FRC_CPAP = FRC_supine_factor*FRC_slfactor_CPAP*CPAP_factor*FRC_all;

%% Run model calibration for analysis region
% Define filtering and miscellaneous parameters
counter_run = 1; % Initialize counter
Total_outcomes_CPAP = length(FRC_CPAP)*length(TV_CPAP);
frame_len = round(0.05/dt); % Time in seconds
frame_len = 2*round(frame_len/2) + 1; % Odd number window length for Savitsky-Golay filter

% Initialze output matrices
Msol_final_CPAP = zeros(length(Total_outcomes_CPAP),1); Ksol_final_CPAP = zeros(length(Total_outcomes_CPAP),1); nsol_final_CPAP = zeros(length(Total_outcomes_CPAP),1); k0sol_final_CPAP = zeros(length(Total_outcomes_CPAP),1);
Vol_final_CPAP = zeros(length(Abdomen_S1_CPAP),Total_outcomes_CPAP);
Vol_final_f_CPAP = zeros(length(Abdomen_S1_CPAP),Total_outcomes_CPAP);

% Use linear model as reference to avoid scaling issues in power models (with mean values)
w = 0.1; test = 1; equation_ref = 1;
Vol_max_ref = 0; Vol_min_ref = 0; % Initialize reference limits to run through function
mean_vals = 2; % Use mean volume references to estimate linear ratios 
FRC = FRC_CPAP(mean_vals);
Tid_Vol = TV_CPAP(mean_vals);
Insp_End = FRC + Tid_Vol;
Vmax = TLC_all(mean_vals);
Vmin = RV_all(mean_vals);
dV_apnea = 0.1*Tid_Vol; % Allowable tolerance for apnea
if CPAP_cal == 1
    sol = @(p) ResFunction_patient_Wake(p, ...
        Start_Breath_NB_CPAP, End_Breath_NB_CPAP, Start_Breath_FRC, ...
        Start_Asy, End_Asy, ...
        equation_ref, C_n_CPAP, A_n_CPAP, ...
        Tid_Vol, FRC, dV_apnea, ...
        Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP) ; sol = sol(1);
else
    sol = @(p) ResFunction_patient(p, ...
        Start_Breath_NB_CPAP, End_Breath_NB_CPAP, ...
        Start_Asy, End_Asy, ...
        equation_ref, C_n_CPAP, A_n_CPAP, ...
        Insp_End, FRC, dV_apnea, ...
        Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP) ; sol = sol(1);
end
Msol_ref = sol(1); Ksol_ref = sol(2); vert_shift_ref = sol(3); Vol_max_ref = sol(4); Vol_min_ref = sol(5); % Linear model parameters and reference ratios

% Model calibration using optimal equation (V = M*(C + K*A^n)), linear model used as backup
for i = 1:length(FRC_CPAP)
    for n = 1:length(TV_CPAP)
        FRC = FRC_CPAP(i);
        Tid_Vol = TV_CPAP(n);
        Insp_End = FRC + Tid_Vol;
        Vmax = TLC_all(i);
        Vmin = RV_all(i);
        dV_apnea = 0.1*Tid_Vol; % Allowable tolerance for apnea
        equation_final = 9; test = 0; % Include max/FRC and min/FRC ratio residuals
        p0 = [500 K 1.25; 500 K 1; 500 K 0.75; 500 K 0.5; 500 K 0.25; 500 K 0.1;
            1000 K 1.25; 1000 K 1; 1000 K 0.75; 1000 K 0.5; 1000 K 0.25; 1000 K 0.1;
            2000 K 1.25; 2000 K 1; 2000 K 0.75; 2000 K 0.5; 2000 K 0.25; 2000 K 0.1;
            3000 K 1.25; 3000 K 1; 3000 K 0.75; 3000 K 0.5; 3000 K 0.25; 3000 K 0.1];
        lb = [1e-8 1e-8 0.1]; ub = [Inf 5 2]; w = 0.1;
        if CPAP_cal == 1 % Calibrate TV using wake region
            resFun = @(p) ResFunction_patient_Wake(p, ...
                Start_Breath_NB_CPAP, End_Breath_NB_CPAP, Start_Breath_FRC, ...
                Start_Asy, End_Asy, ...
                equation_final, C_n_CPAP, A_n_CPAP, ...
                Tid_Vol, FRC, dV_apnea, ...
                Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP); 
        else % Calibrate TV using analysis region
            resFun = @(p) ResFunction_patient(p, ...
                Start_Breath_NB_CPAP, End_Breath_NB_CPAP, ...
                Start_Asy, End_Asy, ...
                equation_final, C_n_CPAP, A_n_CPAP, ...
                Insp_End, FRC, dV_apnea, ...
                Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP); 
        end
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
        Msol_final_CPAP(counter_run) = p_est(1); Ksol_final_CPAP(counter_run) = p_est(2); nsol_final_CPAP(counter_run) = p_est(3); % Original fitting parameters

        % Use linear model if predicted parameters are hitting either limit
        lb_test = find(abs(p_est - lb) < 1e-3);
        ub_test = find(abs(p_est - ub) < 1e-3);
        if double(isempty(lb_test)) == 0 || double(isempty(ub_test)) == 0
            equation_final = 10; test = 1; % Linear model comparison residuals not needed
            p0 = [Msol_ref Ksol_ref vert_shift_ref];
            lb = [1e-8 1e-8 -Inf]; ub = [Inf 5 Inf]; w = 0.1;
            if CPAP_cal == 1 % Calibrate TV using wake region
                resFun = @(p) ResFunction_patient_Wake(p, ...
                    Start_Breath_NB_CPAP, End_Breath_NB_CPAP, Start_Breath_FRC, ...
                    Start_Asy, End_Asy, ...
                    equation_final, C_n_CPAP, A_n_CPAP, ...
                    Tid_Vol, FRC, dV_apnea, ...
                    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP);
            else % Calibrate TV using analysis region
                resFun = @(p) ResFunction_patient(p, ...
                    Start_Breath_NB_CPAP, End_Breath_NB_CPAP, ...
                    Start_Asy, End_Asy, ...
                    equation_final, C_n_CPAP, A_n_CPAP, ...
                    Insp_End, FRC, dV_apnea, ...
                    Vmax, Vmin, w, K, Vol_max_ref, Vol_min_ref, test, Chest_S1, Abdomen_S1, epsilon, abs_max_CPAP, abs_min_CPAP);
            end
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
            Msol_final_CPAP(counter_run) = p_est(1); Ksol_final_CPAP(counter_run) = p_est(2); k0sol_final_CPAP(counter_run) = p_est(3); % Adjusted fitting parameters
            Vol_final_CPAP(:,counter_run) = (Msol_final_CPAP(counter_run).*(C_n_CPAP + Ksol_final_CPAP(counter_run)*A_n_CPAP) + k0sol_final_CPAP(counter_run)); % Direct volume result from calibration
        else
            Vol_final_CPAP(:,counter_run) = (Msol_final_CPAP(counter_run).*(C_n_CPAP + Ksol_final_CPAP(counter_run)*A_n_CPAP.^nsol_final_CPAP(counter_run))); % Direct volume result from calibration
        end
        
        % Filter volume using Savitsky-Golay filter to eliminate any noise
        Vol_final_f_CPAP(:,counter_run)= sgolayfilt(Vol_final_CPAP(:,counter_run), 3, frame_len);
        counter_run = counter_run + 1;
    end
end

%% Per-breath amplitude calculations
% Down sample results for faster processing
dt_s = 0.05; factor_ds = round(dt_s/dt);
Vol_final_f_CPAP_ds = Vol_final_f_CPAP(1:factor_ds:end,:); % Predicted lung volume
Tid_Vol_m_ds = Tid_Vol_m_CPAP(1:factor_ds:end); 
Chest_S1_CPAP_ds = Chest_S1_CPAP(1:factor_ds:end);
Abdomen_S1_CPAP_ds = Abdomen_S1_CPAP(1:factor_ds:end);
C_Flow_CPAP_ds = C_Flow_CPAP(1:factor_ds:end);
Leak_CPAP_ds = Leak_CPAP(1:factor_ds:end);
t_S1_CPAP_ds = t_S1_CPAP(1:factor_ds:end);
HR_CPAP_ds = HR_CPAP(1:factor_ds:end);
SpO2_CPAP_ds = SpO2_CPAP(1:factor_ds:end);

% Breath segmentation for calculation of per-breath amplitudes for model prediction
windowSize = round(1/dt_s);
b = (1/windowSize)*ones(1,windowSize); a = 1;
Vol_filt = filtfilt(b,a,Vol_final_f_CPAP_ds(:,1)); % Filter volume signals to avoid noise in derivative
Diff = diff(Vol_filt);
% Detection of starting inspiration points
for i=round(1/dt_s):round(length(Diff)-1/dt_s) % Detect breaths for 1 second after signal starts to 1 second before signal ends
if Diff(i) >= 0 %consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
    if double(all(Diff(round(i-0.3/dt_s):(i-1))<0)) == 1 && double(all(Diff(i+1:round(i+0.3/dt_s))>0)) == 1 % Starting point of breath: 0.3s prior has to have negative derivative and 0.3s after has to be positive (inflection point)
        Start_Breath_TV(i) = i; % Index of start of breath
    else 
        Start_Breath_TV(i) = 0; % Placeholder value
    end
else 
    Start_Breath_TV(i) = 0; % Placeholder value
end
end
indicies = find(Start_Breath_TV == 0); % Identify for elimination of placeholder values
Start_Breath_TV(indicies) = [];
clear br m1 d1
[br,m1] = unique(Start_Breath_TV,'first');
[~,d1] = sort(br);  
Start_Breath_TV = br(d1); % Indicies of starting inspiration points
% Detection of starting expiration points
for i=round(1/dt_s):round(length(Diff)-1/dt_s) % Find breaths for 1 second after signal starts to 1 second before signal ends
    if Diff(i) <= 0 % Consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
        if double(all(Diff(round(i-0.3/dt_s):(i-1))>0)) == 1 && double(all(Diff(i+1:round(i+0.3/dt_s))<0)) == 1 % Starting point of expiration: 0.3s prior has to have positive derivative and 0.3s after has to be negative (inflection point)
            Start_Exp_TV(i) = i; % Index of end of breath
        else
            Start_Exp_TV(i) = 0; % Placeholder value
        end
    else
        Start_Exp_TV(i) = 0; % Placeholder value
    end
end
indicies = find(Start_Exp_TV == 0); % Identify for elimination of placeholder values
Start_Exp_TV(indicies) = [];
clear br m1 d1
[br,m1] = unique(Start_Exp_TV,'first');
[~,d1] = sort(br);    
Start_Exp_TV = br(d1); % Indicies of starting expiration points
% Start breath segmentation with inspiration
if Start_Exp_TV(1) < Start_Breath_TV(1)
    Start_Exp_TV = Start_Exp_TV(2:end); 
else
end
% Ensure same length of vectors
if length(Start_Exp_TV) < length(Start_Breath_TV)
    Start_Breath_TV = Start_Breath_TV(1:length(Start_Exp_TV)); 
else
    Start_Exp_TV = Start_Exp_TV(1:length(Start_Breath_TV)); 
end
% Finalize segmentation with manual adjustment 
Break_Point = sort([Start_Breath_TV Start_Exp_TV]);
if double(contains(filename,'OSA6')) == 1
    exclude_time = [29424.9, 29426.3, 29428.1, 29429.2, 29431.5, 29432.2, 29435.2, 29436.2, 29587.2, 29588.5];
    include_time = [29437.1 29587.6 29588.1];
elseif double(contains(filename,'OSA5')) == 1
    exclude_time = [29302.9 29303.5 29392.2 29394];
    include_time = [];
else
    if OSA23_input == 1
        exclude_time = [21632.7 21633.8 21843.1 21844.3 21845.9 21846.7];
        include_time = [];
    else
        exclude_time = [24044.6 24381.8 24382.3];
        include_time = 24192.7;
    end
end
for i=1:length(exclude_time)
    idx_e = find(abs(t_S1_CPAP_ds - exclude_time(i))<dt_s); idx_e = idx_e(1);
    [~, remove_idx] = min(abs(Break_Point -idx_e));
    Break_Point(remove_idx) = [];
end
for i=1:length(include_time)
    idx_i = find(abs(t_S1_CPAP_ds - include_time(i))<dt_s); idx_i = idx_i(1);
    Break_Point = [Break_Point idx_i];
end
Break_Point = sort(Break_Point);
Break_Point = unique(Break_Point);
% Add repeating index for apnea to maintain consistency (each 'breath' has inspiration and expiration point)
if double(contains(filename,'OSA6')) == 1
    repeat = find(abs(t_S1_CPAP_ds-29421.6)<dt_s); repeat = repeat(1);
    Break_Point = sort([Break_Point repeat]);
elseif double(contains(filename,'OSA5')) == 1
else
    if OSA23_input == 1
    else
        repeat = find(abs(t_S1_CPAP_ds-24040.5)<dt_s); repeat = repeat(1);
        Break_Point = sort([Break_Point repeat]);
    end
end

% Breath segmentation for calculation of per-breath amplitudes from CPAP flow
C_Flow_CPAP_adj = C_Flow_CPAP_ds*10^3/60; % Convert to mL/s
% Filter CPAP flow and remove baseline drift
windowSize = round(0.5/dt_s); b = (1/windowSize)*ones(1,windowSize); a = 1;
C_Flow_filt = filtfilt(b,a,C_Flow_CPAP_adj(:,1));
C_Flow_p = C_Flow_filt - movmean(C_Flow_filt,round(30/dt_s));
% Detection of starting inspiration points
Diff = C_Flow_p;
for i=round(1/dt_s):round(length(Diff)-1/dt_s) % Find breaths for 1 second after signal starts to 1 second before signal ends
if Diff(i) >= 0 % Consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
    if double(all(Diff(round(i-dt_s/dt_s):(i-1))<0)) == 1 && double(all(Diff(i+1:round(i+dt_s/dt_s))>0)) == 1 % Starting point of breath: 0.3s prior has to have negative flowrate and 0.3s after has to be positive (inflection point)
        Start_Breath_CPAP(i) = i; % Index of start of breath
    else 
        Start_Breath_CPAP(i) = 0; % Placeholder value
    end
else 
    Start_Breath_CPAP(i) = 0; % Placeholder value
end
end
indicies = find(Start_Breath_CPAP == 0); % Identify for elimination of placeholder values
Start_Breath_CPAP(indicies) = [];
clear br m1 d1
[br,m1] = unique(Start_Breath_CPAP,'first');
[~,d1] = sort(br);  
Start_Breath_CPAP = br(d1); % Indices of starting inspiration point for CPAP flow
% Detection of starting expiration points
for i=round(1/dt_s):round(length(Diff)-1/dt_s) % Find breaths for 1 second after signal starts to 1 second before signal ends (0.5 seconds before and after a point needs to be used to determine if criteria of if statement is met)
    if Diff(i) <= 0 % Consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
        if double(all(Diff(round(i-dt_s/dt_s):(i-1))>0)) == 1 && double(all(Diff(i+1:round(i+dt_s/dt_s))<0)) == 1 % Starting point of expiration: 0.3s prior has to have positive flowrate and 0.3s after has to be negative (inflection point)
            Start_Exp_CPAP(i) = i; % Index of start of expiration
        else
            Start_Exp_CPAP(i) = 0; % Placeholder value
        end
    else
        Start_Exp_CPAP(i) = 0; % Placeholder value
    end
end
indicies = find(Start_Exp_CPAP == 0); % Identify for elimination of placeholder values
Start_Exp_CPAP(indicies) = [];
clear br m1 d1
[br,m1] = unique(Start_Exp_CPAP,'first');
[~,d1] = sort(br);    
Start_Exp_CPAP = br(d1); % Indicies of starting expiration points for CPAP flow
% Start breath segmentation with inspiration
if Start_Exp_CPAP(1) < Start_Breath_CPAP(1)
    Start_Exp_CPAP = Start_Exp_CPAP(2:end); 
else
end
% Ensure same lenght of vectors
if length(Start_Exp_CPAP) < length(Start_Breath_CPAP)
    Start_Breath_CPAP = Start_Breath_CPAP(1:length(Start_Exp_CPAP)); 
else
    Start_Exp_CPAP = Start_Exp_CPAP(1:length(Start_Breath_CPAP)); 
end
% Finalize segmentation of CPAP flow signal with manual adjustment 
Break_Point_CPAP = sort([Start_Breath_CPAP Start_Exp_CPAP]);
Break_Point_CPAP = Break_Point_CPAP([true diff(Break_Point_CPAP) > 10]); % Eliminate points with 10 elements of eachother (possible issues in automated segmentation)
if double(contains(filename,'OSA6')) == 1
    exclude_time = [29423.7 29424.9 29427 29428.9 29431.1 29434.8 29435.4 29589.1 29651.6 29652.3 29798.8];
    include_time = [29422.2 29437.1 29589];
elseif double(contains(filename,'OSA5')) == 1
    exclude_time = [29302.7 29304.7 29305.4 29306.2 29366.3 29367.1];
    include_time = [29296 29297];
else
    if OSA23_input == 1
        exclude_time = [21488 21489.1 21515.9 21517.3 21632.3 21633.7 21749.6];
        include_time = 21742.8;
    else
        exclude_time = [24041.8 24042.7 24195.9 24197.1 24197.6 24373.3 24374.8 24376 24378.6 24379.9];
        include_time = [24041.2 24045.6 24194.6];
    end
end
for i=1:length(exclude_time)
    idx_e = find(abs(t_S1_CPAP_ds - exclude_time(i))<dt_s); idx_e = idx_e(1);
    [~, remove_idx] = min(abs(Break_Point_CPAP -idx_e));
    Break_Point_CPAP(remove_idx) = [];
end
for i=1:length(include_time)
    idx_i = find(abs(t_S1_CPAP_ds - include_time(i))<dt_s); idx_i = idx_i(1);
    Break_Point_CPAP = [Break_Point_CPAP idx_i];
end
Break_Point_CPAP = sort(Break_Point_CPAP);
Break_Point_CPAP = unique(Break_Point_CPAP);
% Add repeating index for apnea to maintain consistency (each breath has inspiration and expiration point)
if double(contains(filename,'OSA6')) == 1
    repeat = find(abs(t_S1_CPAP_ds-29422.2)<dt_s); repeat = repeat(1);
    Break_Point_CPAP = sort([Break_Point_CPAP repeat]);
elseif double(contains(filename,'OSA5')) == 1
else
    if OSA23_input == 1
    else
        repeat = find(abs(t_S1_CPAP_ds-24041.2)<dt_s); repeat = repeat(1);
        Break_Point_CPAP = sort([Break_Point_CPAP repeat]);
    end
end

% Segmentation of Tidal Volume signal (SleepWorks output)
x = Tid_Vol_m_ds; dx = diff(x);                    
thr = 0.01*max(abs(dx));        
changeIdx = find(abs(dx) > thr);
Break_Point_TV = changeIdx + 1; 
Break_Point_TV = Break_Point_TV([true; diff(Break_Point_TV) > 10]);
if double(contains(filename,'OSA6')) == 1
    exclude_time = 29652.6;
    include_time = [29356.4 29527.8 29692.3 29715.8 29762.1 29780.9];
elseif double(contains(filename,'OSA5')) == 1
    exclude_time = [];
    include_time = [29187.4 29338.4];
else
end
for i=1:length(exclude_time)
    idx_e = find(abs(t_S1_CPAP_ds - exclude_time(i))<dt_s); idx_e = idx_e(1);
    [~, remove_idx] = min(abs(Break_Point_TV -idx_e));
    Break_Point_TV(remove_idx) = [];
end
for i=1:length(include_time)
    idx_i = find(abs(t_S1_CPAP_ds - include_time(i))<dt_s); idx_i = idx_i(1);
    Break_Point_TV = [Break_Point_TV; idx_i];
end
Break_Point_TV = sort(Break_Point_TV);

% Calculation of per-breath amplitude of expiration segments 
% Initialze output vectors
TV_model_Exp = zeros(length(Vol_final_f_CPAP_ds(:,1)),Total_outcomes_CPAP);
TV_meas_CPAP_Exp = zeros(length(Vol_final_f_CPAP_ds(:,1)),1);
TV_meas_TV_Exp = zeros(length(Vol_final_f_CPAP_ds(:,1)),1);
% Calulation using predicted volume and CPAP flow signal
for i=1:2:length(Break_Point)-2  
    TV_model_Exp(Break_Point(i):Break_Point(i+2),:) = ones(length(TV_model_Exp(Break_Point(i):Break_Point(i+2))),1).*abs(Vol_final_f_CPAP_ds(Break_Point(i+1),:) - Vol_final_f_CPAP_ds(Break_Point(i+2),:));
    Int_seg = C_Flow_p(Break_Point_CPAP(i+1):Break_Point_CPAP(i+2));
    t_seg_int = t_S1_CPAP_ds(Break_Point_CPAP(i+1):Break_Point_CPAP(i+2));
    TV_meas_CPAP_Exp(Break_Point(i):Break_Point(i+2),1) = ones(length(TV_model_Exp(Break_Point(i):Break_Point(i+2))),1).*abs(trapz(t_seg_int,Int_seg));
end
% Extraction from Tidal volume signal
if double(contains(filename,'OSA6')) == 1 || double(contains(filename,'OSA5')) == 1
    counter_TV = 2; % Tidal volume signal amplitude not correctly aligned with breath timing
    for i=1:2:length(Break_Point)-2
        TV_meas_TV_Exp(Break_Point(i):Break_Point(i+2)) = ones(length(TV_model_Exp(Break_Point(i):Break_Point(i+2))),1).*Tid_Vol_m_ds(Break_Point_TV(counter_TV));
        counter_TV = counter_TV + 1;
    end
else
end

% Calculation of per-breath amplitude of inspiration segments 
% Re-define manual segmentation for model results
if double(contains(filename,'OSA-23')) == 1
    Break_Point = sort([Start_Breath_TV Start_Exp_TV]);
    if OSA23_input == 1
        exclude_time = [21632.7 21633.8 21843.1 21844.3 21845.9 21846.7];
        include_time = [];
    else
        exclude_time = [24044.6 24381.8 24382.3];
        include_time = 24192.7;
    end
    for i=1:length(exclude_time)
        idx_e = find(abs(t_S1_CPAP_ds - exclude_time(i))<dt_s); idx_e = idx_e(1);
        [~, remove_idx] = min(abs(Break_Point -idx_e));
        Break_Point(remove_idx) = [];
    end
    for i=1:length(include_time)
        idx_i = find(abs(t_S1_CPAP_ds - include_time(i))<dt_s); idx_i = idx_i(1);
        Break_Point = [Break_Point idx_i];
    end
    Break_Point = sort(Break_Point);
    Break_Point = unique(Break_Point);
    % Add repeating index for apnea to maintain consistency (each breath has inspiration and expiration point)
    if OSA23_input == 1
    else
        repeat = find(abs(t_S1_CPAP_ds-24046.5)<dt_s); repeat = repeat(1);
        Break_Point = sort([Break_Point repeat]);
    end
    % Redefine manual segmentation for CPAP flow 
    Break_Point_CPAP = sort([Start_Breath_CPAP Start_Exp_CPAP]);
    Break_Point_CPAP = Break_Point_CPAP([true diff(Break_Point_CPAP) > 10]);
    if OSA23_input == 1
        exclude_time = [21488 21489.1 21515.9 21517.3 21632.3 21633.7 21749.6];
        include_time = 21742.8;
    else
        exclude_time = [24041.8 24042.7 24195.9 24197.1 24197.6 24373.3 24374.8 24376 24378.6 24379.9];
        include_time = [24041.2 24045.6 24194.6];
    end
    for i=1:length(exclude_time)
        idx_e = find(abs(t_S1_CPAP_ds - exclude_time(i))<dt_s); idx_e = idx_e(1);
        [~, remove_idx] = min(abs(Break_Point_CPAP -idx_e));
        Break_Point_CPAP(remove_idx) = [];
    end
    for i=1:length(include_time)
        idx_i = find(abs(t_S1_CPAP_ds - include_time(i))<dt_s); idx_i = idx_i(1);
        Break_Point_CPAP = [Break_Point_CPAP idx_i];
    end
    Break_Point_CPAP = sort(Break_Point_CPAP);
    Break_Point_CPAP = unique(Break_Point_CPAP);
    % Add repeating index for apnea to maintain consistency (each breath has inspiration and expiration point)
    if OSA23_input == 1
    else
        repeat = find(abs(t_S1_CPAP_ds-24045.6)<dt_s); repeat = repeat(1);
        Break_Point_CPAP = sort([Break_Point_CPAP repeat]);
    end
    % Initialze output vectors
    TV_model_Insp = zeros(length(Vol_final_f_CPAP_ds(:,1)),Total_outcomes_CPAP);
    TV_meas_CPAP_Insp = zeros(length(Vol_final_f_CPAP_ds(:,1)),1);
    % Calulation using predicted volume and CPAP flow signal
    for i=1:2:length(Break_Point)-2
        TV_model_Insp(Break_Point(i):Break_Point(i+2),:) = ones(length(TV_model_Insp(Break_Point(i):Break_Point(i+2))),1).*abs(Vol_final_f_CPAP_ds(Break_Point(i),:) - Vol_final_f_CPAP_ds(Break_Point(i+1),:));
        Int_seg = C_Flow_p(Break_Point_CPAP(i):Break_Point_CPAP(i+1));
        t_seg_int = t_S1_CPAP_ds(Break_Point_CPAP(i):Break_Point_CPAP(i+1));
        TV_meas_CPAP_Insp(Break_Point(i):Break_Point(i+2),1) = ones(length(TV_model_Insp(Break_Point(i):Break_Point(i+2))),1).*abs(trapz(t_seg_int,Int_seg));
    end
end

%% Absolute volume profiles to be input to oxygen mass transfer model
dt_a = t_S1_CPAP_ds(2) - t_S1_CPAP_ds(1);
tend_ss = 360; % Time to allow model to reach steady state
N_ss = round(tend_ss/dt_a);
br = 15/60; % Approximated normal breathing rate for steady state segment

% Add simulated normal breathing pattern (360 s) to beginning of volume profiles to allow oxygen model to reach steady state 
Vol_input_CPAP = zeros(N_ss + length(Vol_final_f_CPAP_ds),Total_outcomes_CPAP);
counter = 1;
for i = 1:length(FRC_CPAP)
    for n=1:length(TV_CPAP)
        Start_point = Vol_final_f_CPAP(1,counter);
        FRC = Start_point;
        clear t_ss Vi
        TV_steady = TV_CPAP(n);
        for k=1:N_ss
            t_ss(k) = (k-1)*dt_a;
            Vi(k) = 0.5*TV_steady*sin(2*pi*br*t_ss(k) - pi/2)+(FRC+0.5*TV_steady);
        end
        Vol_input_CPAP(:,counter) = [Vi'; Vol_final_f_CPAP_ds(:,counter)];
        counter = counter + 1;
    end
end
N_total_CPAP = N_ss + length(Vol_final_f_CPAP_ds);
t_input_CPAP = (0:N_total_CPAP-1)*dt_a; 

%% Run CPAP portion through oxygen mass transfer model
Age = Subject_Age; Height = Subject_Height; Weight = Subject_Weight;
BSA = 0.007184*(Weight^0.425)*(Height^0.725);
if double(contains(Subject_Sex,'M')) == 1
    load OSAParameters_Male.mat
    Qp = Qpi; Qs = Qsi;
    MRO2 = BSA*(138.1 - 11.49*log(Age) + 0.378*HRi)*(nV/60);
else
    load OSAParameters_Female.mat
    Qp = Qpi; Qs = Qsi;
    MRO2 = BSA*(138.1 - 17.04*log(Age) + 0.378*HRi)*(nV/60);
end
SpO2i = SpO2_CPAP_ds(1);

VD_equip = 0; % Dead space of equipment (Ignore due to flow and low possibility of rebreathing due to leak)
PIO2 = yO2*(PB-PH2O);

% Lookup table approximation for oxygenation
Cd_T = (linspace(0,2e-6,8000))';
S_T = SatO2_2(Cd_T,Beta_p);
CT_T = 4*CHb.*S_T + Cd_T;
F_Cd = griddedInterpolant(CT_T(:), Cd_T(:), 'linear', 'linear');

% Solving parameters
dt_O2i = 0.007;
t_Data = t_input_CPAP;
HR_Data = [HRi*ones(N_ss,1); HR_CPAP_ds];
SpO2_Data = [SpO2i*ones(N_ss,1); SpO2_CPAP_ds]/100;
s = floor(t_Data(end)/dt_O2i);
Total = Total_outcomes_CPAP;
SsaO2_all_CPAP = zeros(s,Total); Volume_all_CPAP = zeros(s,Total); SpO2_all_CPAP = zeros(s,Total);

for p = 1:Total
    V_Data = Vol_input_CPAP(:,p);
   
    % Solving parameters
    dzi = vpci*dt_O2i;
    k = floor(Lc/dzi);
    n_dti = floor(tcyclei/dt_O2i);
    a_dti = floor(tsai/dt_O2i);
    c_dti = floor(tsyscapi/dt_O2i);
    
    % Initialize variable vectors
    t_O2 = zeros(1,s);
    PAO2 = zeros(1,s);  CAO2 = zeros(1,s); PDO2 = zeros(1,s); 
    PpaO2 = zeros(1,s); CpaO2d = zeros(1,s); CpaO2T = zeros(1,s); SpaO2 = zeros(1,s);
    PpvO2 = zeros(1,s); CpvO2d = zeros(1,s); CpvO2T = zeros(1,s); SpvO2 = zeros(1,s);
    PsaO2 = zeros(1,s); CsaO2d = zeros(1,s); CsaO2T = zeros(1,s); SsaO2 = zeros(1,s);
    PsvO2 = zeros(1,s); CsvO2d = zeros(1,s); CsvO2T = zeros(1,s); SsvO2 = zeros(1,s);
    PcO2 = zeros(1,s); CcO2 = zeros(1,s);
    HR = zeros(1,s); Qp = zeros(1,s); Qs = zeros(1,s);
    CpcO2T = zeros(k+1,s); CpcO2d = zeros(k+1,s); SpcO2 = zeros(k+1,s); PpcO2 = zeros(k+1,s);
    z1 = zeros(k+1,1); vpc = zeros(1,s);
    dt_O2 = zeros(1,s); n_dt = zeros(1,s); a_dt = zeros(1,s); c_dt = zeros(1,s);
    tcycle = zeros(1,s); tsyscap = zeros(1,s); tsa = zeros(1,s);
    CpcO2T1 = zeros(k+1,1); CpcO2d1 = zeros(k+1,1);
    V = zeros(1,s); SpO2_m = zeros(1,s);

    % Initialize variables (t=0)
    syms Sat P
    eq = Sat == (1 + 23400./((P).^3 + 150*P)).^(-1);
    P_sol = solve(eq, P); % Use measured SpO2 to determine intial conditions of model
    SsaO2(1:a_dti+1) = ones(1,a_dti+1).*SpO2i/100;
    P_sol_all = double(subs(P_sol, Sat, SsaO2(1)));
    P_sol_val = P_sol_all(imag(P_sol_all)==0 & P_sol_all>0);
    PsaO2(1:a_dti+1) = ones(1,a_dti+1).*P_sol_val;
    CsaO2d(1:a_dti+1) = PsaO2(1:a_dti+1)./Beta_p;
    CsaO2T(1:a_dti+1) = 4*CHb*SsaO2(1:a_dti+1) +  CsaO2d(1:a_dti+1);
    
    PAO2(1) = PsaO2(1);
    PDO2(1) = PAO2(1);
    CAO2(1) = PAO2(1)*Beta_p;

    PpvO2(1) = PAO2(1);
    CpvO2d(1) = PpvO2(1)*Beta_p;
    SpvO2(1) = SatO2_2(CpvO2d(1),Beta_p);
    CpvO2T(1) = 4*CHb*SpvO2(1) + CpvO2d(1);

    CpaO2T(1:n_dti) = CpvO2T(1)-MRO2/Qsi; 
    CpaO2d(1:n_dti) = interp1(CT_T,Cd_T,CpaO2T(1)); 
    PpaO2(1:n_dti) = CpaO2d(1)/Beta_p; 
    SpaO2(1:n_dti) = SatO2_2(CpaO2d(1),Beta_p); 

    PsvO2(1:c_dti+1) = PpaO2(1);
    CsvO2T(1:c_dti+1) = CpaO2T(1);
    CsvO2d(1:c_dti+1) = CpaO2d(1);
    SsvO2(1:c_dti+1) = SpaO2(1);

    for n=2:k+1
        CpcO2T1(1) = CpaO2T(1);
        CpcO2d1(1) = CpaO2d(1);
        z1(n) = z1(n-1)+dzi;
        CpcO2T1(n) = CpcO2T1(n-1)+(k_l/Qpi)*(dzi/Lc)*(CAO2(1)-CpcO2d1(n-1));
        CpcO2d1(n) = F_Cd(CpcO2T1(n));
    end

    CpcO2T(:,1) = CpcO2T1;
    CpcO2d(:,1) = CpcO2d1;
    PpcO2(:,1) = CpcO2d(:,1)/Beta_p;
    SpcO2(:,1) = SatO2_2(CpcO2d(:,1),Beta_p);
    CcO2(1) = trapz(dzi,CpcO2d(:,1))./Lc; 
    PcO2(1) = CcO2(1)/Beta_p; 

    t_O2(1) = 0; V(1) = V_Data(1);
    HR(1) = HRi; Qp(1) = Qpi; Qs(1) = Qsi; vpc(1) = vpci;
    dt_O2(1) = dt_O2i;
    n_dt(1) = n_dti; c_dt(1) = c_dti; a_dt(1) = a_dti;
    tcycle(1) = tcyclei; tsa(1) = tsai; tsyscap(1) = tsyscapi;

    for i=2:s
        % Time
        t_O2(i) = t_O2(i-1)+dt_O2(i-1);
        if t_O2(i) >= t_Data(end)
            break;
        else
        end

        % Lung Volume
        V(i) = interp1(t_Data,V_Data,t_O2(i));
        if p == 1 || p == 4 || p == 7
            VD_anatom = 0.35*TV_CPAP(1); % Anatomical dead space is 35% of tidal volume
        elseif p == 2 || p == 5 || p == 8
            VD_anatom = 0.35*TV_CPAP(2); % Anatomical dead space is 35% of tidal volume
        else
            VD_anatom = 0.35*TV_CPAP(3); % Anatomical dead space is 35% of tidal volume
        end
        V(i) = max(V(i), 1.25*VD_anatom); % To prevent absolute alveolar volume from being <= 0

        % Heart Rate and Flow
        HR(i) = interp1(t_Data,HR_Data,t_O2(i));
        SpO2_m(i) = interp1(t_Data,SpO2_Data,t_O2(i));
        Qp(i) = HR(i)*SV/60;
        Qs(i) = HR(i)*SV/60;

        % Times
        tcycle(i) = Vsys/Qs(i);
        tsyscap(i) = Vsyscap/Qs(i);
        tsa(i) = Vsysa/Qs(i);
        dt_O2(i) = tcycle(i)*dt_O2i/tcyclei;
        n_dt(i) = floor(tcycle(i)/dt_O2(i));
        c_dt(i) = floor(tsyscap(i)/dt_O2(i));
        a_dt(i) = floor(tsa(i)/dt_O2(i));
        vpc(i) = Qp(i)/Aeff;

        % Calculate arterial oxygenation
        if double(contains(Subject_Sex,'M')) == 1
            MRO2 = BSA*(138.1 - 11.49*log(Age) + 0.378*HR(i-1))*(nV/60);
        else
            MRO2 = BSA*(138.1 - 17.04*log(Age) + 0.378*HR(i-1))*(nV/60);
        end
        CpaO2T(i+n_dt(i)-1) = CpvO2T(i-1)-MRO2/Qs(i-1);
        CpaO2d(i) = F_Cd(CpaO2T(i));
        PpaO2(i) = CpaO2d(i)/Beta_p;
        SpaO2(i) = SatO2_2(CpaO2d(i),Beta_p);

        % Pulmonary capillary oxygenation
        CpcO2T(1,i) = CpaO2T(i);
        CpcO2T(2:end,i) = CpcO2T(1:(end-1),i-1) + (k_l/Qp(i-1))*(dzi/Lc)*(CAO2(i-1)-CpcO2d(1:(end-1),i-1));
        CpcO2d(:,i) = F_Cd(CpcO2T(:,i));
        PpcO2(:,i) = CpcO2d(:,i)/Beta_p;
        SpcO2(:,i) = SatO2_2(CpcO2d(:,i),Beta_p);

        % Venous oxygenation
        CpvO2T(i) = CpcO2T(end,i);
        CpvO2d(i) = F_Cd(CpvO2T(i));
        PpvO2(i) = CpvO2d(i)/Beta_p;
        SpvO2(i) = SatO2_2(CpvO2d(i),Beta_p);

        % Systemic capillaries input
        CsaO2T(i+a_dt(i)) = CpvO2T(i);
        CsaO2d(i+a_dt(i)) = F_Cd(CsaO2T(i+a_dt(i)));
        PsaO2(i+a_dt(i)) = CsaO2d(i+a_dt(i))/Beta_p;
        SsaO2(i+a_dt(i)) = SatO2_2(CsaO2d(i+a_dt(i)),Beta_p);

        % Systemic capillaries output
        CsvO2T(i+c_dt(i)) = CsaO2T(i)-MRO2/Qs(i);
        CsvO2d(i+c_dt(i)) = F_Cd(CsvO2T(i+c_dt(i)));
        PsvO2(i+c_dt(i)) = CsvO2d(i+c_dt(i))/Beta_p;
        SsvO2(i+c_dt(i)) = SatO2_2(CsvO2d(i+c_dt(i)),Beta_p);

        % Alveolar oxygen partial pressure
        VD_total = VD_equip + VD_anatom;
        Alv_pars = [yO2, PB, PH2O, R, T, Beta_p, k_l, VD_equip, VD_anatom];
        CcO2(i) = trapz(dzi,CpcO2d(:,i))./Lc;
        PcO2(i) = CcO2(i)/Beta_p;
        PDO2(i) = DeadSpace_MassBalance_P(V(i),V(i-1),t_O2(i),t_O2(i-1),PDO2(i-1),PAO2(i-1),Alv_pars); % For compartment model of dead space
        PAO2(i) = Alv_MassBalance_VD_P(V(i),V(i-1),t_O2(i),t_O2(i-1),PcO2(i-1),PAO2(i-1),PDO2(i-1),Alv_pars); % For compartment model of dead space
        CAO2(i) = PAO2(i)*Beta_p;
    end
    S(p).SsaO2_all_CPAP = SsaO2;
    S(p).Volume_all_CPAP = V;
    S(p).SpO2_all_CPAP = SpO2_m;
    S(p).Time = t_O2;
end
