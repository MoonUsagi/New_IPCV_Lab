function [report, total] = ch23_pipelineProfile(source, options)
%CH23_PIPELINEPROFILE 逐幀管線的分段計時。
%
%   REPORT = CH23_PIPELINEPROFILE(SOURCE) 把一個典型的逐幀管線拆成
%   幾個階段分別計時，回傳依耗時排序的 table：
%     Stage        階段名稱
%     MsPerFrame   每幀毫秒數
%     Percent      佔總時間的百分比
%     MaxFPS       只做這一個階段時的理論上限 fps
%
%   [REPORT, TOTAL] = ... 另外回傳 struct，含 MsPerFrame、FPS、
%   FrameRate、RealTime（處理速度是否跟得上影片幀率）。
%
%   **為什麼要分段量，而不是只看總時間？**
%   因為最佳化只有在瓶頸上才有效。第 7 節量到讀檔只佔 6.1%——
%   把讀檔優化到零，整體也只快 6%。**先量，再改。**
%
%   名稱-值引數：
%     NumFrames  取樣幾幀，預設 100
%     Display    是否納入顯示階段（vision.VideoPlayer），預設 false
%     Write      是否納入寫檔階段（MPEG-4），預設 false
%     Repeats    每個階段重複幾輪取中位數，預設 1
%     HoistObjects  是否把 strel 提到迴圈外，預設 true。
%                   設成 false 會重現「天真寫法」——每一幀重新建構
%                   結構元素。第 7 節用這個開關示範**最佳化之後
%                   瓶頸會換位置**：天真版的形態學看起來最貴，
%                   提到迴圈外之後最貴的變成 regionprops。
%
%   **計時的誤差來源**：第一次呼叫某個函式會付出 JIT 編譯的代價。
%   本函式會先跑一幀熱身再開始計時；Repeats > 1 時取各輪的中位數，
%   避免單次的作業系統排程抖動主導結果。
%
%   範例：
%     report = ch23_pipelineProfile("visiontraffic.avi", NumFrames=200);
%     disp(report)
%
%   另見 CH23_BALLSEGMENTVIDEO, PROFILE, TIMEIT.

arguments
    source
    options.NumFrames    (1,1) double {mustBePositive} = 100
    options.Display      (1,1) logical = false
    options.Write        (1,1) logical = false
    options.Repeats      (1,1) double {mustBePositive} = 1
    options.HoistObjects (1,1) logical = true
end

if isa(source, "VideoReader")
    v = source;
else
    v = VideoReader(source);
end
n = min(v.NumFrames, options.NumFrames);

% 先把影格讀進記憶體，這樣「讀檔」才能當成獨立的一個階段量，
% 而不是和後面的處理混在一起。
frames = cell(1, n);
for k = 1:n
    frames{k} = read(v, k);
end

% 迴圈外建構——這本身就是第 7 節要示範的事。
se     = strel("disk", 5);
player = [];
writer = [];
if options.Display
    player = vision.VideoPlayer(Name="ch23 profile");
end
if options.Write
    outFile = fullfile(tempdir, "ch23_profile.mp4");
    writer  = VideoWriter(outFile, "MPEG-4");
    writer.FrameRate = v.FrameRate;
    open(writer);
end
cleanupObj = onCleanup(@() localCleanup(player, writer));

% ---- 熱身：把 JIT 編譯的代價付掉，不要算進去
localWarmup(frames{1}, se);

if options.HoistObjects
    morphName = "形態學";
else
    morphName = "形態學（strel 在迴圈內）";
end
stageNames = ["讀檔（解碼）" "轉灰階" "二值化" morphName "量測 regionprops" "標註 insertShape"];
if options.Display, stageNames(end+1) = "顯示 VideoPlayer"; end
if options.Write,   stageNames(end+1) = "寫檔 MPEG-4"; end

ms = nan(options.Repeats, numel(stageNames));

for rep = 1:options.Repeats
    col = 0;

    % ① 讀檔：重新建一個 reader，量真正的解碼成本
    v2 = VideoReader(v.Name);
    t = tic;
    for k = 1:n, raw = readFrame(v2); end %#ok<NASGU>
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ② 轉灰階
    grays = cell(1,n);
    t = tic;
    for k = 1:n, grays{k} = rgb2gray(frames{k}); end
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ③ 二值化
    bws = cell(1,n);
    t = tic;
    for k = 1:n, bws{k} = imbinarize(grays{k}); end
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ④ 形態學。HoistObjects=false 時在迴圈內重建 strel——
    %    這是最常見的寫法，也是最常見的浪費。
    t = tic;
    if options.HoistObjects
        for k = 1:n, bws{k} = imopen(bws{k}, se); end
    else
        for k = 1:n, bws{k} = imopen(bws{k}, strel("disk", 5)); end
    end
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ⑤ 量測
    t = tic;
    for k = 1:n, s = regionprops(bws{k}, "Area", "Centroid"); end %#ok<NASGU>
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ⑥ 標註
    t = tic;
    for k = 1:n
        out = insertShape(frames{k}, "rectangle", [10 10 50 50], Color="green"); %#ok<NASGU>
    end
    col = col + 1; ms(rep,col) = toc(t) / n * 1000;

    % ⑦ 顯示
    if options.Display
        t = tic;
        for k = 1:n, player(frames{k}); end
        col = col + 1; ms(rep,col) = toc(t) / n * 1000;
    end

    % ⑧ 寫檔
    if options.Write
        t = tic;
        for k = 1:n, writeVideo(writer, frames{k}); end
        col = col + 1; ms(rep,col) = toc(t) / n * 1000;
    end
end

MsPerFrame = median(ms, 1)';
Stage      = stageNames';
Percent    = MsPerFrame / sum(MsPerFrame) * 100;
MaxFPS     = 1000 ./ MsPerFrame;

report = table(Stage, MsPerFrame, Percent, MaxFPS);
report = sortrows(report, "MsPerFrame", "descend");

totalMs = sum(MsPerFrame);
total = struct( ...
    MsPerFrame   = totalMs, ...
    FPS          = 1000 / totalMs, ...
    FrameRate    = v.FrameRate, ...
    RealTime     = (1000 / totalMs) >= v.FrameRate, ...
    NumFrames    = n, ...
    HoistObjects = options.HoistObjects, ...
    Bottleneck   = stageNames(find(MsPerFrame == max(MsPerFrame), 1)));
end

% ========================================================================
function localWarmup(frame, se)
%LOCALWARMUP 先各跑一次，把第一次呼叫的編譯成本付掉。
g  = rgb2gray(frame);
bw = imopen(imbinarize(g), se);
s  = regionprops(bw, "Area", "Centroid"); %#ok<NASGU>
o  = insertShape(frame, "rectangle", [10 10 50 50], Color="green"); %#ok<NASGU>
end

% ------------------------------------------------------------------------
function localCleanup(player, writer)
if ~isempty(player), release(player); end
if ~isempty(writer) && isvalid(writer)
    try
        close(writer);
    catch
    end
end
end
