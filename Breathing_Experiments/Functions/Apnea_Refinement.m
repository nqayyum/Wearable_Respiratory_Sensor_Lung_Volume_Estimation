function [Start_Apnea_idx, End_Apnea_idx] = Apnea_Refinement(Chest_S1, Start_Apnea_idx, End_Apnea_idx, dt, thresh_i, thresh_f)
%% Refine apnea boundaries for breathing experiments (automated)
for i = 1:length(Start_Apnea_idx)
    Start_Apnea_actual = Start_Apnea_idx(i);
    End_Apnea_actual = End_Apnea_idx(i);
    Apnea_seg = Chest_S1(Start_Apnea_actual:End_Apnea_actual); % Use annotations as a base for apnea detection
    Apnea_diff = diff(Apnea_seg);
    % Filter derivative to eliminate noise
    windowSize = round(0.05/dt); b = (1/windowSize)*ones(1,windowSize); a = 1;
    Apnea_diff_f = filtfilt(b,a,Apnea_diff);
    % Use absolute value of derivative for initial refinement of apnea boundaries
    Apnea_thres = zeros(1,length(Apnea_diff_f)); % Initialize mask for apnea detection
    for n = 1:length(Apnea_diff_f)
        if abs(Apnea_diff_f(n)) < thresh_i*max(abs(Apnea_diff_f))
            Apnea_thres(n) = 1;
        else
            Apnea_thres(n) = 0;
        end
    end
    % Find longest segment with absolute derivative below the threshold
    mask = (Apnea_thres == 1); d = diff([0 mask 0]);
    runStarts = find(d == 1); runEnds = find(d == -1) - 1;
    runLengths = runEnds - runStarts + 1;
    [~, idx] = max(runLengths);
    longestStart = runStarts(idx);
    longestEnd   = runEnds(idx);
    diff_idx = longestEnd - longestStart + 1;
    time_thres = round(5/dt); % Determined based on test subject data
    if diff_idx < time_thres % Use recorded apnea boundaries if detected segment is less than time threshold
        Start_Apnea_actual = Start_Apnea_idx(i) + round(5/dt); % Apnea start originally estimated earlier than recorded annotation to account for possible delay
        End_Apnea_actual = End_Apnea_idx(i) - round(5/dt); % Apnea end originally estimated later than recorded annotation to account for possible error in apnea length
    else % Adjust boundaries of detected apnea segment
        Start_Apnea_actual = Start_Apnea_actual + longestStart - 1;
        End_Apnea_actual = Start_Apnea_actual + longestEnd - longestStart;
        if End_Apnea_actual > length(Chest_S1)
            End_Apnea_actual = length(Chest_S1); % Avoid indexing errors in code
        else
        end

        % Further refine apnea boundaries using same derivative method
        Apnea_seg = Chest_S1(Start_Apnea_actual:End_Apnea_actual); % Refined apnea segment
        Apnea_diff = diff(Apnea_seg);
        % Filter derivative to eliminate noise
        windowSize = round(0.05/dt); b = (1/windowSize)*ones(1,windowSize); a = 1;
        Apnea_diff_f = filtfilt(b,a,Apnea_diff);
        % Use absolute value of derivative for final refinement of apnea boundaries
        Apnea_thres = zeros(1,length(Apnea_diff_f)); % Initial mask for apnea detection
        for n = 1:length(Apnea_diff_f)
            if abs(Apnea_diff_f(n)) < thresh_f*max(abs(Apnea_diff_f))
                Apnea_thres(n) = 1;
            else
                Apnea_thres(n) = 0;
            end
        end
        % Find longest segment with absolute derivative below the threshold
        mask = (Apnea_thres == 1); d = diff([0 mask 0]);
        runStarts = find(d == 1); runEnds = find(d == -1) - 1;
        runLengths = runEnds - runStarts + 1;
        [~, idx] = max(runLengths);
        longestStart = runStarts(idx);
        longestEnd   = runEnds(idx);
        diff_idx = longestEnd - longestStart + 1;
        if diff_idx > time_thres % Adjust boundaries of detected apnea segment if detected segment is longer than time threshold
            Start_Apnea_actual = Start_Apnea_actual + longestStart - 1;
            End_Apnea_actual = Start_Apnea_actual + longestEnd - longestStart;
        else % Use boundaries from initial boundary refinement
        end
    end

    % Update refined starting and ending boundaries of apneas
    Start_Apnea_idx(i) = Start_Apnea_actual;
    End_Apnea_idx(i) = End_Apnea_actual;
end
end