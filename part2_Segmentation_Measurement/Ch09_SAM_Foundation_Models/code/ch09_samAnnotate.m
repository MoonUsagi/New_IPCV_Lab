function [labels, report] = ch09_samAnnotate(I, clickPoints, options)
%CH09_SAMANNOTATE 用 SAM 把使用者的點擊轉成標註遮罩。
%
%   LABELS = CH09_SAMANNOTATE(I, CLICKPOINTS) 對每個點擊位置產生一個物件
%   遮罩，合併成一張標籤矩陣。CLICKPOINTS 是 P×2 的 [x y] 座標。
%
%   [LABELS, REPORT] = CH09_SAMANNOTATE(___) 另外回傳診斷 table，
%   記錄每個點的信心分數、面積、以及**是否被剔除與原因**。
%
%   名稱-值引數：
%     ModelName       SAM 變體，預設 "sam2-small"。開發階段建議 "sam2-tiny"
%     MinScore        信心分數門檻，預設 0.7
%     MaxAreaFraction 遮罩面積佔全圖的上限，預設 0.3。超過視為誤選到背景
%     MinArea         遮罩面積下限（像素），預設 20
%     Verbose         是否列印進度，預設 true
%
%   為什麼需要面積上限
%   ------------------
%   這是本函式最重要的設計。第 09 章實測：點在背景上時，SAM 會回傳
%   佔全圖 75% 的遮罩，而且**信心分數比正確的物件還高**：
%
%     點在圓片上   遮罩   421 像素   信心 0.9604
%     點在背景上   遮罩 38057 像素   信心 0.9819  ← 分數更高
%
%   SAM 沒有做錯——它忠實地回答了「你指的那個東西是什麼」，
%   而背景確實是一個連貫的區域。但對標註流程來說這是廢資料。
%   **光靠信心分數擋不住這個錯誤，必須用面積。**
%
%   效能考量
%   --------
%   embeddings 只計算一次，之後每個點只跑解碼器。第 09 章實測：
%   embeddings 5.54 秒，每個點 0.296 秒。若每個點都重算 embeddings，
%   4 個點就會慢 3.5 倍。
%
%   範例：
%     I = imresize(imread("coloredChips.png"), 0.5);
%
%     % 模擬使用者點了四個圓片，其中一個點歪了落在背景
%     clicks = [148 88; 100 40; 205 62; 230 100];
%
%     [L, report] = ch09_samAnnotate(I, clicks);
%     disp(report)
%     imshow(labeloverlay(I, L))
%
%   另見 SEGMENTANYTHINGMODEL, EXTRACTEMBEDDINGS,
%   SEGMENTOBJECTSFROMEMBEDDINGS, LABELOVERLAY.

arguments
    I                   {mustBeNumeric, mustBeNonempty}
    clickPoints  (:,2)  double {mustBeNonempty}
    options.ModelName       (1,1) string  = "sam2-small"
    options.MinScore        (1,1) double {mustBeInRange(options.MinScore, 0, 1)} = 0.7
    options.MaxAreaFraction (1,1) double {mustBeInRange(options.MaxAreaFraction, 0, 1)} = 0.3
    options.MinArea         (1,1) double {mustBeNonnegative} = 20
    options.Verbose         (1,1) logical = true
end

if exist("segmentAnythingModel", "file") ~= 2
    error("ch09_samAnnotate:noSAM", ...
        "找不到 segmentAnythingModel。請安裝「Image Processing Toolbox " + ...
        "Model for Segment Anything Model 2」支援包。");
end

[h, w, ~] = size(I);

% ForegroundPoints 是 [x y]：x 對應行（寬）、y 對應列（高）。
% 超出範圍時 SAM 會擲出 insufficientPrompts，錯誤訊息不會提到座標，
% 所以在這裡先擋下來並給出有用的訊息。
outOfRange = clickPoints(:,1) < 1 | clickPoints(:,1) > w | ...
             clickPoints(:,2) < 1 | clickPoints(:,2) > h;
if any(outOfRange)
    bad = find(outOfRange);
    error("ch09_samAnnotate:pointOutOfRange", ...
        "第 %s 個點超出影像範圍。座標是 [x y]，需滿足 x ≤ %d 且 y ≤ %d。", ...
        join(string(bad'), ", "), w, h);
end

model = segmentAnythingModel(options.ModelName);   % 位置引數，不是名稱-值對

if options.Verbose
    fprintf("計算 embeddings（模型 %s）...\n", options.ModelName);
end
tEmbed = tic;
embeddings = extractEmbeddings(model, I);
embedTime = toc(tEmbed);

n          = size(clickPoints, 1);
Point      = strings(n,1);
Score      = zeros(n,1);
Area       = zeros(n,1);
AreaPct    = zeros(n,1);
Accepted   = false(n,1);
Reason     = strings(n,1);
Seconds    = zeros(n,1);

labels = zeros(h, w, "uint16");
nextLabel = 0;

for k = 1:n
    tk = tic;
    [mask, score] = segmentObjectsFromEmbeddings(model, embeddings, size(I), ...
        ForegroundPoints=clickPoints(k,:));
    Seconds(k) = toc(tk);

    area     = nnz(mask);
    areaFrac = area / (h*w);

    Point(k)   = mat2str(clickPoints(k,:));
    Score(k)   = score;
    Area(k)    = area;
    AreaPct(k) = 100 * areaFrac;

    if score < options.MinScore
        Reason(k) = sprintf("信心不足（< %.2f）", options.MinScore);
    elseif areaFrac > options.MaxAreaFraction
        Reason(k) = sprintf("面積過大（> %.0f%%），可能點到背景", ...
            100*options.MaxAreaFraction);
    elseif area < options.MinArea
        Reason(k) = sprintf("面積過小（< %d 像素）", options.MinArea);
    else
        Accepted(k) = true;
        Reason(k)   = "接受";
        nextLabel   = nextLabel + 1;
        % 後來的遮罩不覆蓋先前已標註的像素，避免重疊互相吃掉
        labels(mask & labels == 0) = nextLabel;
    end
end

report = table(Point, Score, Area, AreaPct, Seconds, Accepted, Reason);

if options.Verbose
    fprintf("\nembeddings %.2f 秒，%d 個點共 %.2f 秒（平均 %.3f 秒）\n", ...
        embedTime, n, sum(Seconds), mean(Seconds));
    fprintf("接受 %d 個，剔除 %d 個\n\n", nnz(Accepted), nnz(~Accepted));
    disp(report)

    rejected = report(~report.Accepted, :);
    if ~isempty(rejected)
        fprintf("剔除原因：\n");
        for k = 1:height(rejected)
            fprintf("  %s  %s\n", rejected.Point(k), rejected.Reason(k));
        end
    end
end
end
