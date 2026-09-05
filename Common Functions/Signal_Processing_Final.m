function [Chest_S1, Abdomen_S1] = Signal_Processing_Final(t_S1, Chest_S1, Abdomen_S1, Start_Apnea_idx, End_Apnea_idx, Start_NB_idx_cal, End_NB_idx_cal, dt)
%% Process signals to remove apnea drift and adjust post-apnea segments
%%%%% Process chest signal %%%%%
for i = 1:length(Start_Apnea_idx)
    % Boundaries from apnea correction
    Start_Apnea_actual = Start_Apnea_idx(i);
    End_Apnea_actual = End_Apnea_idx(i);

    %%% Determine whether apnea needs to be detrended %%%
    % Find average amplitude change during initial normal breathing 
    NB_seg = Chest_S1(Start_NB_idx_cal:End_NB_idx_cal); % Normal breathing segment
    % Local maxima
    [~, max_idx] = findpeaks(NB_seg);   % Local maxima indicies
    max_loc = NB_seg(max_idx); % Local maxima
    avg_max_NB = mean(max_loc);
    % Local minima
    [~, min_idx] = findpeaks(-NB_seg);   % Local minima indicies
    min_loc = NB_seg(min_idx); % Local minima
    avg_min_NB = mean(min_loc);
    % Average tidal breathing amplitude
    Avg_amp_NB = abs(avg_max_NB - avg_min_NB);
    phys_drift_thresh = 0.1; % Set maximum physiological drift as 10% of tidal breathing (estimated from literature)
    Amp_thresh = Avg_amp_NB*phys_drift_thresh; % 'Allowable' drift during apnea
    Apnea_seg = Chest_S1(Start_Apnea_actual:End_Apnea_actual); % Apnea segment with refined boundaries refined boundaries  
    Apnea_mean = movmean(Apnea_seg, 5/dt); % Use moving baseline during apnea rather than raw signal in case subject is attempting to breathe
    Apnea_drift = max(Apnea_mean) - min(Apnea_mean);

    %%% Detrend apnea to remove baseline drift due to time constant in data acquistion %%%
    if Apnea_drift > Amp_thresh % Drift greater than physiological threshold
        clean_seg  = detrend(Apnea_seg,2); % Remove trend
        detrend_s = clean_seg(1); start_diff = Chest_S1(Start_Apnea_actual) - detrend_s; % Calculate vertical shift to match detrending apnea with existing signal to avoid discontinuity (Original value - new)
        clean_seg_shift = clean_seg + start_diff; % Shifted segment
        % Adjustment of raw signal to new apnea end following detrending
        seg_adjust_end = []; % Initialize
        for j = End_Apnea_actual:length(Chest_S1)-1 % Scan region following apnea end
            if (Chest_S1(j-1) < 0 && Chest_S1(j+1) > 0) || (Chest_S1(j-1) > 0 && Chest_S1(j+1) < 0) % Find first zero crossing after apnea
                seg_adjust_end = j;
                if (j - End_Apnea_actual) > 0.5/dt % Choose zero crossing after a certain time threshold
                    seg_adjust_end = j;
                    break;
                else
                end
            end
        end
        if double(isempty(seg_adjust_end)) == 1 % No zero crossing detected
            seg_adjust_end = End_Apnea_actual + 10/dt; % Arbitratily assign adjust segment as approximately two breaths following apnea end
        else
        end
        if seg_adjust_end > length(Chest_S1) % If apnea is close to the end of signal recording
            seg_adjust_end = length(Chest_S1);
        end

        seg_adjust = Chest_S1(End_Apnea_actual:seg_adjust_end); % From the raw chest signal
        % Applying smoothing function (cubic Hermite)
        start_new = clean_seg_shift(end); % Adjusted (after detrending and vertical shifting) end of apnea segment
        delta   = start_new - seg_adjust(1); % Difference between target apnea end and original apnea end
        t_seg_adjust = t_S1(End_Apnea_actual:seg_adjust_end);
        T = t_seg_adjust(end) - t_seg_adjust(1);
        T_n = (t_seg_adjust - t_seg_adjust(1)) / T; % Normalized time
        h00 =  2*T_n.^3 - 3*T_n.^2 + 1; % Hermite basis
        trend = delta*h00;  % Zero-slope Hermite with fixed end point of post-apnea segment
        seg_new = seg_adjust + trend; % Adjusted post-apnea segment
        Chest_S1 = [Chest_S1(1:Start_Apnea_actual-1); clean_seg_shift; seg_new(2:end); Chest_S1(seg_adjust_end + 1:end)]; % Reconstruct signal
    else
    end
end

%%%%% Process abdominal signal %%%%%
for i = 1:length(Start_Apnea_idx)
    % Boundaries from apnea correction
    Start_Apnea_actual = Start_Apnea_idx(i);
    End_Apnea_actual = End_Apnea_idx(i);

    %%% Determine whether apnea needs to be detrended %%%
    % Find average amplitude change during initial normal breathing (tidal volume)
    NB_seg = Abdomen_S1(Start_NB_idx_cal:End_NB_idx_cal);
    % Local maxima
    [~, max_idx] = findpeaks(NB_seg);   % Local maxima indicies
    max_loc = NB_seg(max_idx); % Local maxima
    avg_max_NB = mean(max_loc);
    % Local minima
    [~, min_idx] = findpeaks(-NB_seg);   % Local minima indicies
    min_loc = NB_seg(min_idx); % Local minima
    avg_min_NB = mean(min_loc);
    % Average tidal breathing amplitude
    Avg_amp_NB = abs(avg_max_NB - avg_min_NB);
    phys_drift_thresh = 0.1; % Set maximum physiological drift as 10% of tidal breathing
    Amp_thresh = Avg_amp_NB*phys_drift_thresh; % 'Allowable' drift during apnea
    Apnea_seg = Abdomen_S1(Start_Apnea_actual:End_Apnea_actual); % Use refined boundaries
    Apnea_mean = movmean(Apnea_seg, 5/dt); % Use moving baseline during apnea rather than raw signal in case subject is attempting to breathe
    Apnea_drift = max(Apnea_mean) - min(Apnea_mean);

    %%% Detrend apnea to remove baseline drift due to time constant in data acquistion %%%
    if Apnea_drift > Amp_thresh % Drift greater than physiological threshold
        Apnea_seg = Abdomen_S1(Start_Apnea_actual:End_Apnea_actual); % Use refined boundaries
        clean_seg  = detrend(Apnea_seg,2); % Remove trend
        detrend_s = clean_seg(1); start_diff = Abdomen_S1(Start_Apnea_actual) - detrend_s; % Calculate vertical shift to match detrending apnea with existing signal to avoid discontinuity (Original value - new)
        clean_seg_shift = clean_seg + start_diff; % Shifted segment
        % Adjustment of raw signal to new apnea end following detrending
        seg_adjust_end = []; % Initialize
        for j = End_Apnea_actual:length(Abdomen_S1)-1
            if (Abdomen_S1(j-1) < 0 && Abdomen_S1(j+1) > 0) || (Abdomen_S1(j-1) > 0 && Abdomen_S1(j+1) < 0) % Find first zero crossing after apnea
                seg_adjust_end = j;
                if (j - End_Apnea_actual) > 0.5/dt % Choose zero crossing after a certain time threshold
                    seg_adjust_end = j;
                    break;
                else
                end
            end
        end

        if double(isempty(seg_adjust_end)) == 1 % No zero crossing detected
            seg_adjust_end = End_Apnea_actual + 10/dt; % Arbitratily assign adjust segment as approximately two breaths following apnea end
        else
        end
        if seg_adjust_end > length(Abdomen_S1)
            seg_adjust_end = length(Abdomen_S1);
        end

        seg_adjust = Abdomen_S1(End_Apnea_actual:seg_adjust_end); % From raw abdominal signal
        % Applying smoothing function (cubic Hermite)
        start_new = clean_seg_shift(end); % Adjusted (after detrending and vertical shifting) end of apnea segment
        delta   = start_new - seg_adjust(1); % Difference between target apnea end and original apnea end
        t_seg_adjust = t_S1(End_Apnea_actual:seg_adjust_end);
        T = t_seg_adjust(end) - t_seg_adjust(1);
        T_n = (t_seg_adjust - t_seg_adjust(1)) / T; % Normalized time
        h00 =  2*T_n.^3 - 3*T_n.^2 + 1; % Hermite basis
        trend = delta*h00; % Zero-slope Hermite with fixed end point for post-apnea segment
        seg_new = seg_adjust + trend; % Adjusted post-apnea segment
        Abdomen_S1 = [Abdomen_S1(1:Start_Apnea_actual-1); clean_seg_shift; seg_new(2:end); Abdomen_S1(seg_adjust_end + 1:end)]; % Reconstruct signal
    else
    end
end
end