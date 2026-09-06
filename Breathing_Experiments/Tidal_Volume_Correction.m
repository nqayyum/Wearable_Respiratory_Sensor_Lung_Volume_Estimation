%% Determine tidal volume correction factor for breathing experiments
%% Load data and segmentation of inspiratory and expiratory segments
% Load flow data
[flow_file, flow_path] = uigetfile('*.edf','Select the .edf file with the flow data');
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

% Normal breathing start and end times for measured flow
if Subject == 1
    if Trial == 1
        Start_time_NB = 33;
        End_time_NB = 87;
    else
        Start_time_NB = 4;
        End_time_NB = 48;
    end
elseif Subject == 2
    if Trial == 1
        Start_time_NB = 5;
        End_time_NB = 43;
    else
        Start_time_NB = 13;
        End_time_NB = 36;
    end
elseif Subject == 3
    Start_time_NB = 29;
    End_time_NB = 139;
else
    Start_time_NB = 7;
    End_time_NB =  130;
end
Start_time_NB_idx = find(abs(t_flow - Start_time_NB)<dt_flow);
Start_time_NB_idx = Start_time_NB_idx(1);
End_time_NB_idx = find(abs(t_flow - End_time_NB)<dt_flow);
End_time_NB_idx = End_time_NB_idx(1);

% Detect starting inspiration points
for i=round(1/dt_flow):round(length(Flow_SPIRO)-1/dt_flow) % Find breaths for 1 second after signal starts to 1 second before signal ends 
if Flow_SPIRO(i) >= 0  % Consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
    if double(all(Flow_SPIRO(round(i-0.5/dt_flow):(i-1))<0)) == 1 && double(all(Flow_SPIRO(i+1:round(i+0.5/dt_flow))>0)) == 1 % Starting point of breath: 0.5s prior has to have negative flow and 0.5s after has to be positive (inflection point)
        Start_Insp_BP(i) = i; % Index of start of breath
    else 
        Start_Insp_BP(i) = 0; % Placeholder value
    end
else 
    Start_Insp_BP(i) = 0; % Placeholder value
end
end
indicies = find(Start_Insp_BP == 0); % Identify for elimination of placeholder values
Start_Insp_BP(indicies) = [];
clear br m1 d1
[br,m1,~] = unique(Start_Insp_BP,'first'); % Elimination of any repeating indicies
[~,d1] =sort(m1);
Start_Insp_BP = br(d1); % Indices for starting inspiration points

% Detect starting expiration points
for i=round(1/dt_flow):round(length(Flow_SPIRO)-1/dt_flow) % Find breaths for 1 second after signal starts to 1 second before signal ends 
    if Flow_SPIRO(i) <= 0 %consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
        if double(all(Flow_SPIRO(round(i-0.5/dt_flow):(i-1))>0)) == 1 && double(all(Flow_SPIRO(i+1:round(i+0.5/dt_flow))<0)) == 1 % Starting point of expiration: 0.5s prior has to have positive flow and 0.5s after has to be negative (inflection point)
            Start_Exp_BP(i) = i; % Index of start of expiration
        else
            Start_Exp_BP(i) = 0; % Placeholder value
        end
    else
        Start_Exp_BP(i) = 0; % Placeholder value
    end
end
indicies = find(Start_Exp_BP == 0); % Identify for elimination of placeholder values
Start_Exp_BP(indicies) = [];
clear br m1 d1
[br,m1,~] = unique(Start_Exp_BP,'first'); % Elimination of any repeating indicies
[~,d1] =sort(m1);
Start_Exp_BP = br(d1); % Indices for starting expiration points

% Cumulative breath break points
Break_Pt_Win = [Start_Insp_BP Start_Exp_BP];
Break_Pt_Win = sort(Break_Pt_Win);

% Consider break points only within normal breathing region at the start of the study
BP_reduced = Break_Pt_Win(find(Break_Pt_Win > Start_time_NB_idx)); % Find all break points after the start of the window
Break_Pt_Win = BP_reduced(find(BP_reduced < End_time_NB_idx)); % Only keep breaths that fall within the window (eliminate all breaths that start after the end of the window)

%% Run section ONLY IF there are missing points in automated selection
% Additional manual selection of break points to include (in case of errors in automated segmentation)
fig = figure; ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on');
h1 = plot(ax, t_flow, Flow_SPIRO, 'LineWidth', 1.5);
hold on
scatter(t_flow(Break_Pt_Win),Flow_SPIRO(Break_Pt_Win))
title(ax,'Use toolbar to zoom/pan. Press "Select Points" to record clicks.'); xlabel(ax,'x'); ylabel(ax,'y');
set(h1, 'PickableParts','none', 'HitTest','off');
selectedPoints = [];
assignin('base','selectedPoints',selectedPoints);
uicontrol('Style','pushbutton','String','Select Points',...
          'Units','normalized','Position',[0.01 0.01 0.15 0.05],...
          'Callback', @(src,evt) activateSelectionMode(fig, ax));

disp('Use toolbar zoom/pan. Press "Select Points" to record points.');

% Add selected points
selectedPoints_Break_Inc = selectedPoints;
pts = size(selectedPoints_Break_Inc);
pts = pts(1);
for i=1:pts
    sP_Break_idx = find(abs(t_flow-selectedPoints_Break_Inc(i,1))<dt_flow);
    sP_Break_Inc(i) = sP_Break_idx(1);
end

Break_Pt_Win = [Break_Pt_Win sP_Break_Inc];
Break_Pt_Win = sort(Break_Pt_Win);

%% Run section ONLY IF there are extra points in automated selection
% Additional manual selection of break points to exclude (in case of errors in automated segmentation)
fig = figure; ax = axes('Parent',fig); hold(ax,'on'); grid(ax,'on');
h1 = plot(ax, t_flow, Flow_SPIRO, 'LineWidth', 1.5);
hold on
scatter(t_flow(Break_Pt_Win),Flow_SPIRO(Break_Pt_Win))
title(ax,'Use toolbar to zoom/pan. Press "Select Points" to record clicks.'); xlabel(ax,'x'); ylabel(ax,'y');
set(h1, 'PickableParts','none', 'HitTest','off');
selectedPoints = [];
assignin('base','selectedPoints',selectedPoints);
uicontrol('Style','pushbutton','String','Select Points',...
          'Units','normalized','Position',[0.01 0.01 0.15 0.05],...
          'Callback', @(src,evt) activateSelectionMode(fig, ax));

disp('Use toolbar zoom/pan. Press "Select Points" to record points.');

% Remove selected points
selectedPoints_Break_Exc = selectedPoints;
pts = size(selectedPoints_Break_Exc);
pts = pts(1);
idx = [];
for i=1:pts
    sP_Break_Exc_idx = find(abs(t_flow-selectedPoints_Break_Exc(i,1))<dt_flow);
    sP_Break_Exc(i) = sP_Break_Exc_idx(1);
    [~, idx_add] = min(abs(Break_Pt_Win - sP_Break_Exc(i)));
    idx = [idx idx_add];
end
Break_Pt_Win(idx) = [];

%% Calculate tidal volume
if Flow_SPIRO(Break_Pt_Win(1) + 0.5/dt_flow) > 0 && Flow_SPIRO(Break_Pt_Win(end) + 0.5/dt_flow) < 0 && mod(length(Break_Pt_Win), 2) == 0 % (first break point is for starting inspiration, last break point is for starting expiration, and each starting inspiration point is associated with a starting expiration point)
    no_breaths = length(Break_Pt_Win)/2;
    Tid_Vol_Actual = zeros(1,no_breaths); % Initialize 
    % Integrate only inspiratory segments
    for i = 1:no_breaths
        start_breath_idx = 2*i - 1;
        Tid_Vol_Actual(i) = trapz(t_flow(Break_Pt_Win(start_breath_idx):Break_Pt_Win(start_breath_idx + 1)), Flow_SPIRO(Break_Pt_Win(start_breath_idx):Break_Pt_Win(start_breath_idx + 1)));
    end
else
    error('Re-check break points')
end

%% Run AFTER determining tidal volume for each subject using above code
% Load expected tidal volume from patient demographics file
[demo_file, demo_path] = uigetfile('*.xlsx','Select the Excel file with subject demographics and lung volume references');
opts = detectImportOptions([demo_path demo_file]);
Data = readtable([demo_path demo_file]);
Subject_No = table2array(Data(:,1));
Tid_Vol_data = table2array(Data(:,9));
FRC_data = table2array(Data(:,10));
TLC_data = table2array(Data(:,11));
RV_data = table2array(Data(:,12));

% Expected normal tidal volumes
data_idx = find(Subject_No == 1);
Tid_Vol_exp_S1 = Tid_Vol_data(data_idx);
data_idx = find(Subject_No == 2);
Tid_Vol_exp_S2 = Tid_Vol_data(data_idx);
data_idx = find(Subject_No == 3);
Tid_Vol_exp_S3 = Tid_Vol_data(data_idx);
data_idx = find(Subject_No == 4);
Tid_Vol_exp_S4 = Tid_Vol_data(data_idx);

%% Load measured tidal volumes from .mat file (results of running first section for all subjects)
[TV_file, TV_path] = uigetfile('*.mat', 'Select file with extracted tidal volume data from measured flow signals (results from running preceding code)'); 
load([TV_path TV_file]);

% S1_1 is the variable assigned to the vector with tidal volume results for Subject 1, Trial 1 and so on
% Combine data for subjects with two trials (1 and 2)
S1 = [S1_1 S1_2];
S2 = [S2_1 S2_2];

% Calculate expected tidal volume increase for each subject
Ratio_S1 = mean(S1)*1000/Tid_Vol_exp_S1;
Ratio_S1_1 = mean(S1_1)*1000/Tid_Vol_exp_S1;
Ratio_S1_2 = mean(S1_2)*1000/Tid_Vol_exp_S1;
Ratio_S2 = mean(S2)*1000/Tid_Vol_exp_S2;
Ratio_S2_1 = mean(S2_1)*1000/Tid_Vol_exp_S2;
Ratio_S2_2 = mean(S2_2)*1000/Tid_Vol_exp_S2;
Ratio_S3 = mean(S3)*1000/Tid_Vol_exp_S3;
Ratio_S4 = mean(S4)*1000/Tid_Vol_exp_S4;

Overall_mean = mean([Ratio_S1 Ratio_S2 Ratio_S3 Ratio_S4]);
Overall_std = std([Ratio_S1 Ratio_S2 Ratio_S3 Ratio_S4]);
Overall_lb = Overall_mean - Overall_std;
Overall_ub = Overall_mean + Overall_std;



