%% Asychronous Segment Detection during Apneas
function [Start_Asy, End_Asy] = Asynchronous_Segment_Apnea(dt,Abdomen_S1,Chest_S1,Start_Apnea_idx,End_Apnea_idx)
windowSize = round(0.05/dt); % Ensure window size is large enough for smooth signals
b = (1/windowSize)*ones(1,windowSize); a = 1;
AbFilt = filtfilt(b,a,Abdomen_S1); % filtfilt to eliminate phase shift of filtered signal
AbDiff = diff(AbFilt); % Derivative of filtered abdomial signal
ChFilt = filtfilt(b,a,Chest_S1); % filtfilt to eliminate phase shift of filtered signal
ChDiff = diff(ChFilt); % Derivative of filtered chest signal
AbDiff = filtfilt(b,a,AbDiff); % Filter derivative for additional noise removal
ChDiff = filtfilt(b,a,ChDiff); % Filter derivative for additional noise removal
AbDiff_s = diff(AbDiff); % Second derivative of abdominal signal
ChDiff_s = diff(ChDiff); % Second derivative of chest signal
% Create binary array with record of signal directions (1 for opposing, 0 for same)
for i=1:length(ChDiff)
    if (ChDiff(i)>0) && (AbDiff(i)<0) % Opposite directions of chest and abdomen signals
        Asyn_Sign(i) = 1;
    elseif (ChDiff(i)<0) && (AbDiff(i)>0) % Opposite directions of chest and abdomen signals
        Asyn_Sign(i) = 1;
    else % Same direction of chest and abdominal signals
        Asyn_Sign(i) = 0;
    end
end

Start_Asy = []; End_Asy = []; % Initialize variables
time_thres = 0.5; % Initial detection limit for asynchronous segments
while double(isempty(Start_Asy)) == 1 && time_thres >= 0.3 % Minimum length of asynchronous segments defined as 0.3 s
    Index_Sign = find(Asyn_Sign == 0); % Indices where derivatives are the same sign
    for i=2:length(Index_Sign) % Identify all segments of asynchrony
        % The idea here is to identify asynchronous segments as the gaps between synchronous segments
        asyn_start_i = Index_Sign(i-1)+1; % Starting index of possible asynchronous segment (1 is added as Index_Sign(i-1) will give index of no asynchrony)
        asyn_end_i = Index_Sign(i)-1; % Ending index of possible asynchrous segment (1 is subtracted as Index_Sign(i) will give index of no asynchrony)
        if (asyn_end_i-asyn_start_i+1) >= time_thres/dt && double(any(diff(sign(AbDiff(asyn_start_i:asyn_end_i))))) == 0 && double(any(diff(sign(ChDiff(asyn_start_i:asyn_end_i))))) == 0 % Ensure detected segment is longer than threshold and chest and abdominal signals remain the same sign
            Start_Indicies(i-1) = asyn_start_i; % Starting index of identified asynchronous segment which meets criteria
            End_Indicies(i-1) = asyn_end_i; % Ending index of identified asynchronous segment which meets criteria
        else
            Start_Indicies(i-1) = 0; % Placeholder value
            End_Indicies(i-1) = 0; % Placeholder value
        end
    end
    clear indicies
    indicies = find(Start_Indicies==0); % Identify for elimination of placeholder values
    Start_Indicies(indicies) = []; % Eliminate placeholder values
    % Eliminate repeating indicies and sort in ascending order
    clear br m1 d1
    [br,m1,~] = unique(Start_Indicies,'first'); 
    [~,d1] =sort(m1);
    Start_Indicies = br(d1);

    indicies = find(End_Indicies==0); % Identify for elimination of placeholder values
    End_Indicies(indicies) = []; % Eliminate placeholder values
    % Eliminate repeating indicies and sort in ascending order
    clear br m1 d1
    [br,m1,~] = unique(End_Indicies,'first'); 
    [~,d1] =sort(m1);
    End_Indicies = br(d1);
 
    % Intersection between asynchronous segments and apneas/breath holds
    counter = 1; % Initialize counter
    for n = 1:length(Start_Indicies)
        for i = 1:length(Start_Apnea_idx)
            if Start_Indicies(n) >= Start_Apnea_idx(i) && End_Indicies(n) <= End_Apnea_idx(i)
                Start_Asy(counter) = Start_Indicies(n);
                End_Asy(counter) = End_Indicies(n);
                counter = counter + 1;
            else
            end
        end
    end  
    time_thres = time_thres - 0.1; % Reduce time threshold if no asynchronous segment is detected
end
end