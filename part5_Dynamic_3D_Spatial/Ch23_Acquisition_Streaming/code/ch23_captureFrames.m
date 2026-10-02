function [frames, info] = ch23_captureFrames(numFrames, options)
%CH23_CAPTUREFRAMES 從相機擷取影格，沒有相機時自動退回影片檔。
%
%   [FRAMES, INFO] = CH23_CAPTUREFRAMES(N) 從第一台 webcam 擷取 N 張影格。
%   FRAMES 是 1xN cell。INFO 是 struct，欄位為：
%     Source      "webcam" 或 "file"（退回時）
%     Device      裝置名稱或檔名
%     Resolution  "寬x高"
%     Latency     1xN 每張的取像耗時（秒）
%     FirstMs     第一張的毫秒數
%     MedianMs    第二張之後的中位數毫秒數
%     WarmupRatio FirstMs / MedianMs
%
%   **這支函式存在的理由是可重現性。** 教材必須在沒有相機的機器上
%   也能跑完，否則自動驗證與手冊建置都會斷掉。退回時 INFO.Source
%   會是 "file"，呼叫者（和讀者）看得出數字不是真的相機量出來的。
%
%   名稱-值引數：
%     DeviceIndex  webcamlist 的索引，預設 1
%     Resolution   解析度字串（如 "640x480"）；""  表示用預設值
%     Fallback     沒有相機時用的影片檔，預設 "visiontraffic.avi"
%     Warmup       擷取前先丟掉幾張，預設 0
%
%   **第一張一定比較慢。** 本機量到第一張 228.7 毫秒、之後中位數
%   31.9 毫秒——差 7.2 倍。原因是驅動程式要協商格式、配置緩衝區、
%   相機要完成自動曝光與白平衡。**計時前要先丟掉幾張**
%   （Warmup=3），否則你量到的是開機成本不是穩態成本。
%
%   範例：
%     [F, info] = ch23_captureFrames(10, Warmup=3);
%     fprintf("%s：第一張 %.1f ms，之後 %.1f ms\n", ...
%         info.Source, info.FirstMs, info.MedianMs);
%
%   另見 WEBCAM, WEBCAMLIST, IPCAM, VIDEOINPUT, CH23_BALLSEGMENTVIDEO.

arguments
    numFrames          (1,1) double {mustBePositive}
    options.DeviceIndex (1,1) double {mustBePositive} = 1
    options.Resolution  (1,1) string = ""
    options.Fallback    (1,1) string = "visiontraffic.avi"
    options.Warmup      (1,1) double {mustBeNonnegative} = 0
end

frames  = cell(1, numFrames);
latency = nan(1, numFrames);

cam = [];
try
    list = webcamlist;
    if isempty(list) || options.DeviceIndex > numel(list)
        error("ipcv:ch23:noCamera", "找不到編號 %d 的相機。", options.DeviceIndex);
    end
    cam = webcam(options.DeviceIndex);
    if strlength(options.Resolution) > 0
        cam.Resolution = options.Resolution;
    end

    for k = 1:options.Warmup
        snapshot(cam);
    end
    for k = 1:numFrames
        t = tic;
        frames{k} = snapshot(cam);
        latency(k) = toc(t);
    end

    info = struct( ...
        Source     = "webcam", ...
        Device     = string(cam.Name), ...
        Resolution = string(cam.Resolution), ...
        Latency    = latency);
    clear cam

catch ME
    % ---- 退回影片檔。**要印出來**，不能安靜地換掉資料來源：
    %      讀者必須知道接下來看到的數字不是相機量的。
    if ~isempty(cam), clear cam; end
    fprintf("⚠ 無法使用相機（%s），改用影片檔 %s。\n", ...
        localShortMsg(ME.message), options.Fallback);

    v = VideoReader(options.Fallback);
    n = min(numFrames, v.NumFrames);
    for k = 1:n
        t = tic;
        frames{k} = read(v, k);
        latency(k) = toc(t);
    end
    for k = (n+1):numFrames
        frames{k}  = frames{mod(k-1, n) + 1};
        latency(k) = median(latency(1:n), "omitnan");
    end

    info = struct( ...
        Source     = "file", ...
        Device     = options.Fallback, ...
        Resolution = sprintf("%dx%d", v.Width, v.Height), ...
        Latency    = latency);
end

info.FirstMs = latency(1) * 1000;
if numFrames > 1
    info.MedianMs = median(latency(2:end)) * 1000;
else
    info.MedianMs = info.FirstMs;
end
info.WarmupRatio = info.FirstMs / info.MedianMs;
end

% ========================================================================
function s = localShortMsg(msg)
%LOCALSHORTMSG 取錯誤訊息的第一行，最多 60 個字元。
s = string(msg);
s = extractBefore(s + newline, newline);
if strlength(s) > 60
    s = extractBefore(s, 60) + "...";
end
end
