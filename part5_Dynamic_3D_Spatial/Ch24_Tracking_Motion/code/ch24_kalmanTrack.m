function [est, info] = ch24_kalmanTrack(tracks, options)
%CH24_KALMANTRACK 用 Kalman 濾波器把逐幀偵測的缺口補起來。
%
%   [EST, INFO] = CH24_KALMANTRACK(TRACKS) 吃第 23 章
%   CH23_BALLSEGMENTVIDEO 產生的 table（含 Frame／Found／X／Y），
%   回傳 EST table：
%     Frame     幀號
%     X, Y      Kalman 的估計位置（**每一幀都有值**）
%     Source    "init"／"correct"（有量測）／"predict"（盲飛）
%     Measured  這一幀是否有量測
%
%   INFO 含 NumPredicted、RejoinError、RejoinFrame、MotionModel、
%   MeanSpeedBefore、MeanSpeedAfter。
%
%   ## 追蹤和逐幀偵測的差別就在這裡
%   逐幀偵測沒有記憶：這一幀找不到就是 NaN，沒有別的辦法。
%   **Kalman 有一個運動模型**，所以它能在沒有量測的時候
%   繼續往前推——代價是誤差會累積。
%
%   **`RejoinError` 是本章最重要的一個數字**：物體重新出現的那一幀，
%   Kalman 在完全沒有量測的情況下「盲飛」了好幾幀之後，
%   預測的位置離真實位置差多遠。**它直接量出運動模型對不對。**
%
%   名稱-值引數：
%     MotionModel  "ConstantVelocity"（預設）或 "ConstantAcceleration"
%     MotionNoise  過程雜訊。CV 要 2 元素、**CA 要 3 元素**，
%                  預設分別是 [25 10] 與 [25 10 1]
%     MeasurementNoise  量測雜訊，預設 25
%     InitialError 初始估計誤差，CV 2 元素、CA 3 元素，
%                  預設 [1e5 1e5] 與 [1e5 1e5 1e5]
%
%   > **`ConstantAcceleration` 的向量長度是 3 不是 2。**
%   > 給錯會報「the InitialEstimateError must be a 3-element vector」——
%   > 訊息還算清楚，但在切換模型時非常容易忘記。
%
%   範例：
%     tr  = ch23_ballSegmentVideo("singleball.mp4");
%     [e, info] = ch24_kalmanTrack(tr, MotionModel="ConstantAcceleration");
%     fprintf("盲飛 %d 幀，重逢誤差 %.2f px\n", info.NumPredicted, info.RejoinError);
%
%   另見 CONFIGUREKALMANFILTER, CH23_BALLSEGMENTVIDEO, CH24_MULTITRACKER.

arguments
    tracks                          table
    options.MotionModel      (1,1) string {mustBeMember(options.MotionModel, ["ConstantVelocity" "ConstantAcceleration"])} = "ConstantVelocity"
    options.MotionNoise      (1,:) double = []
    options.MeasurementNoise (1,1) double {mustBePositive} = 25
    options.InitialError     (1,:) double = []
end

isCA = options.MotionModel == "ConstantAcceleration";

if isempty(options.MotionNoise)
    if isCA, options.MotionNoise = [25 10 1]; else, options.MotionNoise = [25 10]; end
end
if isempty(options.InitialError)
    if isCA, options.InitialError = [1 1 1]*1e5; else, options.InitialError = [1 1]*1e5; end
end

needed = 2 + isCA;
if numel(options.MotionNoise) ~= needed || numel(options.InitialError) ~= needed
    error("ipcv:ch24:vectorLength", ...
        "%s 需要 %d 元素的 MotionNoise 與 InitialError。", ...
        options.MotionModel, needed);
end

n = height(tracks);
Frame    = tracks.Frame;
X        = nan(n,1);
Y        = nan(n,1);
Source   = strings(n,1);
Measured = tracks.Found;

kf          = [];
nPredicted  = 0;
rejoinError = NaN;
rejoinFrame = NaN;
wasBlind    = false;

for k = 1:n
    if tracks.Found(k)
        z = [tracks.X(k) tracks.Y(k)];
        if isempty(kf)
            kf = configureKalmanFilter(options.MotionModel, z, ...
                options.InitialError, options.MotionNoise, ...
                options.MeasurementNoise);
            X(k) = z(1); Y(k) = z(2);
            Source(k) = "init";
        else
            p = predict(kf);
            % **重逢誤差要在 correct 之前量。** correct 之後的估計
            % 一定貼近量測（那是 Kalman 的工作），量不出模型好壞。
            if wasBlind && isnan(rejoinError)
                rejoinError = norm(p - z);
                rejoinFrame = tracks.Frame(k);
            end
            c = correct(kf, z);
            X(k) = c(1); Y(k) = c(2);
            Source(k) = "correct";
        end
        wasBlind = false;
    elseif ~isempty(kf)
        p = predict(kf);
        X(k) = p(1); Y(k) = p(2);
        Source(k) = "predict";
        nPredicted = nPredicted + 1;
        wasBlind = true;
    else
        Source(k) = "";                 % 還沒開始追
    end
end

est = table(Frame, X, Y, Source, Measured);

% 前後兩段可見區間的速度——**用來判斷等速假設成不成立**。
vis = find(tracks.Found);
gapAt = find(diff(vis) > 1, 1);
speedBefore = NaN; speedAfter = NaN;
if ~isempty(gapAt)
    seg1 = vis(1:gapAt);
    seg2 = vis(gapAt+1:end);
    if numel(seg1) > 1, speedBefore = median(abs(diff(tracks.X(seg1)))); end
    if numel(seg2) > 1, speedAfter  = median(abs(diff(tracks.X(seg2)))); end
end

info = struct( ...
    NumPredicted    = nPredicted, ...
    RejoinError     = rejoinError, ...
    RejoinFrame     = rejoinFrame, ...
    MotionModel     = options.MotionModel, ...
    MotionNoise     = options.MotionNoise, ...
    MeanSpeedBefore = speedBefore, ...
    MeanSpeedAfter  = speedAfter);
end
