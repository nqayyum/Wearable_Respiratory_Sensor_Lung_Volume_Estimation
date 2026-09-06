%% Detection of periods of eupnea (normal breathing) for volume model calibration
function [Start_Breath_NB, End_Breath_NB] = Eupnea_Detection_Patient(Start_NB_idx,End_NB_idx,dt,Abdomen_S1,Chest_S1,Start_idx,End_idx)

%%%% Breath Detection %%%%
% Identify indices for start of each breath (inspiration)
windowSize = round(1/dt);  % Ensure window size is large enough for smooth signals
b = (1/windowSize)*ones(1,windowSize); a = 1;
% Start inspiration using abdominal signal
AbFilt_br = filtfilt(b,a,Abdomen_S1); % filtfilt to eliminate phase shift of filtered signal
AbDiff_br = diff(AbFilt_br); % Derivative of filtered signal
for i=round(1/dt):round(length(AbDiff_br)-1/dt) % Find breaths for 1 second after signal starts to 1 second before signal ends
    if AbDiff_br(i) >= 0 % Consider "inflection point" to be >=0 as the change in derivative can happen between 2 data points
        if double(all(AbDiff_br(round(i-0.3/dt):(i-1))<0)) == 1 && double(all(AbDiff_br(i+1:round(i+0.3/dt))>0)) == 1 % Starting point of breath (inspiration): 0.3s prior has to have negative derivative and 0.3s after has to be positive (inflection point)
            Start_Breath_all(i) = i; % Index of start of breath
        else
            Start_Breath_all(i) = 0; % Placeholder value
        end
    else
        Start_Breath_all(i) = 0; % Placeholder value
    end
end
indicies = find(Start_Breath_all == 0); % Identify for elimination of placeholder values
Start_Breath_all(indicies) = []; % Eliminate paceholder values
% Elimination of any repeating indicies and sorting in ascending order
clear br m1 d1
[br,m1,~] = unique(Start_Breath_all,'first');
[~,d1] =sort(m1);
Start_Breath_all = br(d1); % Indicies for starting inspiration points

% Identify indicies for the start of expiration of each breath
for i=round(1/dt):round(length(AbDiff_br)-1/dt) % Find breaths for 1 second after signal starts to 1 second before signal ends 
    if AbDiff_br(i) <= 0 % Consider "inflection point" to be <=0 as the change in derivative can happen between 2 data points
        if double(all(AbDiff_br(round(i-0.3/dt):(i-1))>0)) == 1 && double(all(AbDiff_br(i+1:round(i+0.3/dt))<0)) == 1 % Starting point of expiration: 0.3s prior has to have positive derivative and 0.3s after has to be negative (inflection point)
            Start_Exp_all(i) = i; % Index of start of expiration
        else
            Start_Exp_all(i) = 0; % Placeholder value
        end
    else
        Start_Exp_all(i) = 0; % Placeholder value
    end
end
indicies = find(Start_Exp_all == 0); % Identify for elimination of placeholder values
Start_Exp_all(indicies) = []; % Eliminate placeholder values
% Elimination of any repeating indicies and sorting in ascending order
clear br m1 d1
[br,m1,~] = unique(Start_Exp_all,'first');
[~,d1] =sort(m1);
Start_Exp_all = br(d1); % Indicies for starting expiration points

% Ensure that first inflection point detected is for the start of a breath (inspiration)
if Start_Exp_all(1) < Start_Breath_all(1)
    Start_Exp_all = Start_Exp_all(2:end);
else
end

%%%% Normal Breath Identification and Segmentation for Calibration %%%%
% Find detected start inspiratory and expiratory points within window
counter = 1; Overall_Insp = []; Overall_Exp = []; % Initialize
Start_NB_idx = Start_NB_idx - Start_idx; End_NB_idx = End_NB_idx - Start_idx; % Analysis region is small segmetn but indices are from whole study 
for n=1:length(Start_NB_idx)
    Start_Win_W = Start_NB_idx(n); % Starting index for normal breathing window (can be multiple windows)
    End_Win_W = End_NB_idx(n); % Ending index for normal breathing window (can be multiple windows)
    Start_Insp_NB = Start_Breath_all(find(Start_Breath_all > Start_Win_W & Start_Breath_all < End_Win_W)); % Find all starting inspiration points in window
    Start_Exp_NB = Start_Exp_all(find(Start_Exp_all > Start_Win_W & Start_Exp_all < End_Win_W)); % Find all starting expiration points in window

    % Skip to next window if no breaths identified in current window or there is error with window segmentation
    if double(isempty(Start_Insp_NB)) == 1 || double(isempty(Start_Exp_NB)) == 1 || Start_NB_idx(n) == End_NB_idx(n)
        continue;
    else
    end

    % Start breath sequence with inspiration
    if Start_Insp_NB(1) > Start_Exp_NB(1)
        Start_Exp_NB = Start_Exp_NB(2:end);
    else
    end

    % Ensure that each breath has a starting inspiration and expiration point with no extra indices
    if length(Start_Insp_NB) > length(Start_Exp_NB)
        Start_Insp_NB = Start_Insp_NB(1:length(Start_Exp_NB));
    else
        Start_Exp_NB = Start_Exp_NB(1:length(Start_Insp_NB));
    end

    Overall_Insp = [Overall_Insp Start_Insp_NB]; Overall_Exp = [Overall_Exp Start_Exp_NB]; % Compile detected inspiratory and expiratory points across all windows 
    %%%% Outlier Removal %%%%%
    for i=1:length(Start_Insp_NB) % Cycle through each identified breath
        % Inspiratory Segments
        s = Start_Insp_NB(i); e = Start_Exp_NB(i);
        if s < e
            Breath_Start_Ab(counter) = Abdomen_S1(s); % Starting inspiration point abdomen
            Breath_Start_Ch(counter) = Chest_S1(s); % Starting inspiration point chest
            Breath_Ab_Insp = Abdomen_S1(s:e); % Abominal signal values for inspiratory segment of breath
            Breath_Ch_Insp = Chest_S1(s:e); % Chest signal values for inspiratory segment of breath
            Breath_Amp_Ab_Insp(counter) = Breath_Ab_Insp(end)-Breath_Ab_Insp(1); % Abdominal amplitude of the breath inspiratory phase
            Breath_Amp_Ch_Insp(counter) = Breath_Ch_Insp(end)-Breath_Ch_Insp(1); % Chest amplitude of the breath inspiratory phase
        else % Inspiratory and expiratory points are not for target segment/same breath (skip)
            Breath_Start_Ab(counter) = 0; % Placeholder
            Breath_Start_Ch(counter) = 0; % Placeholder
            Breath_Amp_Ab_Insp(counter) = 0; % Placeholder
            Breath_Amp_Ch_Insp(counter) = 0; % Placeholder
        end
        % Expiratory Segments
        if i ~= length(Start_Insp_NB)
            s = Start_Exp_NB(i); e = Start_Insp_NB(i+1);
            if s < e
                Breath_Ab_Exp = Abdomen_S1(s:e); % Abominal signal values for expiratory segment of breath
                Breath_Ch_Exp = Chest_S1(s:e); % Chest signal values for expiratory segment of breath
                Breath_Amp_Ab_Exp(counter) = Breath_Ab_Exp(end)-Breath_Ab_Exp(1); % Abdominal amplitude of the breath expiratory segment
                Breath_Amp_Ch_Exp(counter) = Breath_Ch_Exp(end)-Breath_Ch_Exp(1); % Chest amplitude of the breath expiratory segment
            else % Inspiratory and expiratory points are not for target segment(skip)
                Breath_Amp_Ab_Exp(counter) = 0; % Placeholder
                Breath_Amp_Ch_Exp(counter) = 0; % Placeholder
            end
        else
            Next_breath = find(Start_Breath_all > Start_Exp_NB(i)); Next_breath = Start_Breath_all(Next_breath(1)); % Start of next breath outside of marked normal breathing region
            Breath_Ab_Exp = Abdomen_S1(Start_Exp_NB(i):Next_breath); % Abominal signal values for expiratory segment of breath
            Breath_Ch_Exp = Chest_S1(Start_Exp_NB(i):Next_breath); % Chest signal values for expiratory segment of breath
            Breath_Amp_Ab_Exp(counter) = Breath_Ab_Exp(end)-Breath_Ab_Exp(1); % Abdominal amplitude of breath expiratory segment
            Breath_Amp_Ch_Exp(counter) = Breath_Ch_Exp(end)-Breath_Ch_Exp(1); % Chest amplitude of breath expiratory segment
        end
    counter = counter + 1;
    end
end

% Elimiate all placeholder values and associated breaths segments
idx_exclude = find(Breath_Start_Ab == 0);
Breath_Start_Ab(idx_exclude) = [];
Breath_Start_Ch(idx_exclude) = [];
Breath_Amp_Ab_Insp(idx_exclude) = [];
Breath_Amp_Ch_Insp(idx_exclude) = [];
Breath_Amp_Ab_Exp(idx_exclude) = [];
Breath_Amp_Ch_Exp(idx_exclude) = [];
Overall_Insp(idx_exclude) = []; Overall_Exp(idx_exclude) = [];

idx_exclude = find(Breath_Amp_Ab_Exp == 0);
Breath_Start_Ab(idx_exclude) = [];
Breath_Start_Ch(idx_exclude) = [];
Breath_Amp_Ab_Insp(idx_exclude) = [];
Breath_Amp_Ch_Insp(idx_exclude) = [];
Breath_Amp_Ab_Exp(idx_exclude) = [];
Breath_Amp_Ch_Exp(idx_exclude) = [];
Overall_Insp(idx_exclude) = []; Overall_Exp(idx_exclude) = [];

% Remove irregular breaths from normal breathing segment using percentiles
Start_idx_f = []; per_range = [25 75]; % Start with interquartile range
factor = 5; % Set extension factor for range
% Primary outlier removal only using inspiratory segment and breath starting point
while length(Start_idx_f) < 5 % Minimum of 5 identified normal breaths
    per_amp_Ab_Insp = prctile(Breath_Amp_Ab_Insp,per_range); % IQR of abdominal signal amplitude during normal breaths (inspiration)
    per_amp_Ch_Insp = prctile(Breath_Amp_Ch_Insp,per_range); % IQR of chest signal amplitude during normal breaths (inspiration)
    per_s_Ab = prctile(Breath_Start_Ab,per_range); % IQR of starting point of abdominal signal during normal breaths
    per_s_Ch = prctile(Breath_Start_Ch,per_range); % IQR of starting point of chest signal during normal breaths

    keep_idx_Ab_amp_Insp_p = find(Breath_Amp_Ab_Insp >= per_amp_Ab_Insp(1) & Breath_Amp_Ab_Insp <= per_amp_Ab_Insp(2));
    keep_idx_Ch_amp_Insp_p = find(Breath_Amp_Ch_Insp >= per_amp_Ch_Insp(1) & Breath_Amp_Ch_Insp <= per_amp_Ch_Insp(2));
    keep_idx_Ab_s_p = find(Breath_Start_Ab >= per_s_Ab(1) & Breath_Start_Ab <= per_s_Ab(2));
    keep_idx_Ch_s_p = find(Breath_Start_Ch >= per_s_Ch(1) & Breath_Start_Ch <= per_s_Ch(2));
    Start_idx_f = intersect(intersect(intersect(keep_idx_Ab_amp_Insp_p, keep_idx_Ch_amp_Insp_p), keep_idx_Ab_s_p), keep_idx_Ch_s_p); % Breaths with values within IQR of all 4 parameters
    per_range = [per_range(1)-factor, per_range(2)+factor]; % Extend range
end

% Secondary outlier removal using expiratory segments
Start_idx_NB = []; per_range = [25 75]; factor = 5;
while length(Start_idx_NB) < 5 % Minimum of 5 identified normal breaths
    per_amp_Ab_Exp = prctile(Breath_Amp_Ab_Exp,per_range); % IQR of abdominal signal amplitude during normal breaths (expiration)
    per_amp_Ch_Exp = prctile(Breath_Amp_Ch_Exp,per_range); % IQR of chest signal amplitude during normal breaths (expiration)
    keep_idx_Ab_amp_Exp = find(Breath_Amp_Ab_Exp >= per_amp_Ab_Exp(1) & Breath_Amp_Ab_Exp <= per_amp_Ab_Exp(2));
    keep_idx_Ch_amp_Exp = find(Breath_Amp_Ch_Exp >= per_amp_Ch_Exp(1) & Breath_Amp_Ch_Exp <= per_amp_Ch_Exp(2));
    Start_idx_NB = intersect(intersect(Start_idx_f,keep_idx_Ab_amp_Exp),keep_idx_Ch_amp_Exp); % Filtered breaths with values within IQR of both parameters
    per_range = [per_range(1)-factor, per_range(2)+factor];
end

Start_Breath_NB = Overall_Insp(Start_idx_NB);
End_Breath_NB = Overall_Exp(Start_idx_NB);
end
