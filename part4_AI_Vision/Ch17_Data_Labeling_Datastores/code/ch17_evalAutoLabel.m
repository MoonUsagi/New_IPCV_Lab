function [report, metrics] = ch17_evalAutoLabel(detResults, gtBoxes, options)
%CH17_EVALAUTOLABEL 評估自動標註的品質，並換算成**人工修正成本**。
%
%   [REPORT, METRICS] = CH17_EVALAUTOLABEL(DETRESULTS, GTBOXES) 把
%   CH17_AUTOLABEL 的輸出與已知的正確框比較。GTBOXES 是 cell 陣列，
%   每個元素是一張影像的 [x y w h] 矩陣。
%
%   REPORT 是 struct，除了 Precision／Recall／AP 之外，還有三個
%   **直接對應人工工時**的欄位：
%
%     NumToDelete - 要人工刪掉的誤框數
%     NumToDraw   - 要人工從頭畫的漏標數
%     MeanIoU     - 命中框的平均 IoU（框有多貼合）
%
%   名稱-值引數：
%     ClassName    - 類別名稱（預設 "object"）
%     IoUThreshold - 判定命中的門檻（預設 0.5）
%
%   **為什麼要分開算「刪」與「畫」**
%
%   precision 與 recall 是對稱的指標，但**人工修正的成本完全不對稱**：
%
%     刪掉一個誤框    -> 看一眼、按一次 Delete
%     從頭畫一個漏標  -> 要先**發現**它漏了，再對齊四個邊
%
%   「發現漏標」是最貴的一步：畫面上已經有框的時候，
%   人的注意力會被既有的框吸走，**漏標很容易被跳過**。
%
%   所以拿 VLM 做預標註時，**要優化 recall，不是 precision**——
%   寧可多給一堆要刪的框，也不要讓人去找漏掉的目標。
%   這和「上線的偵測器要 precision」剛好相反，
%   因為兩者的下游不同：一個下游是人，一個下游是產線決策。
%
%   實測（vehicles 20 張、提示詞 "car"、IoU 0.5）：
%
%     命中 22／GT 22、誤框 43、命中框平均 IoU 0.838
%     -> 要刪 43 個、要畫 **0** 個
%
%   換成提示詞 "vehicle"：precision 跳到 93.3%，
%   但 recall 掉到 63.6%——**要畫 8 個**。
%   43 次點擊 vs 8 次「找出漏掉的車再畫框」，
%   前者幾乎一定更快，而且更不容易出錯。
%
%   另見 CH17_AUTOLABEL, CH17_PROMPTSWEEP, EVALUATEOBJECTDETECTION.

arguments
    detResults table
    gtBoxes    cell
    options.ClassName    (1,1) string = "object"
    options.IoUThreshold (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
end

n = height(detResults);
if numel(gtBoxes) ~= n
    error("ch17_evalAutoLabel:sizeMismatch", ...
        "偵測結果有 %d 列，ground truth 有 %d 個——兩者必須一一對應。", ...
        n, numel(gtBoxes));
end

% --- 標準指標 ---------------------------------------------------------
% evaluateObjectDetection **不接受只有一個變數的 table**
% （會報 "Not enough table variables. groundTruthData must contain at
% least two variables"），但接受由同一個 table 做成的 boxLabelDatastore。
gtTbl = table(gtBoxes(:), VariableNames=options.ClassName);
blds  = boxLabelDatastore(gtTbl);
metrics = evaluateObjectDetection(detResults, blds, options.IoUThreshold, ...
    Verbose=false);

pr = metrics.ClassMetrics.Precision{1};
rc = metrics.ClassMetrics.Recall{1};

% --- 人工成本 ---------------------------------------------------------
nHit = 0; nFalse = 0; ious = [];
nGT = 0;
for k = 1:n
    b = detResults.Boxes{k};
    g = gtBoxes{k};
    nGT = nGT + size(g,1);

    if isempty(b)
        continue
    end
    if isempty(g)
        nFalse = nFalse + size(b,1);
        continue
    end

    ov   = bboxOverlapRatio(b, g);
    best = max(ov, [], 2);
    nHit    = nHit    + nnz(best >= options.IoUThreshold);
    nFalse  = nFalse  + nnz(best <  options.IoUThreshold);
    ious = [ious; best(best >= options.IoUThreshold)];  %#ok<AGROW>
end

report = struct( ...
    "Precision",   100*pr(end), ...
    "Recall",      100*rc(end), ...
    "AP",          metrics.ClassMetrics.APOverlapAvg(1), ...
    "NumBoxes",    sum(cellfun(@(x) size(x,1), detResults.Boxes)), ...
    "NumGT",       nGT, ...
    "NumHit",      nHit, ...
    "NumToDelete", nFalse, ...
    "NumToDraw",   nGT - nHit, ...
    "MeanIoU",     mean(ious));

if isempty(ious)
    report.MeanIoU = NaN;
end

if report.NumToDraw > 0
    warning("ch17_evalAutoLabel:missedObjects", ...
        "有 %d 個目標完全沒被偵測到，必須人工從頭畫。" + ...
        "**「找出漏標」比「刪掉誤框」貴得多**——" + ...
        "若這是預標註流程，考慮換一個 recall 更高的提示詞。", ...
        report.NumToDraw);
end
end
