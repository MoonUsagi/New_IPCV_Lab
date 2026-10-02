function [precisionPct, recallPct, details] = ch16_evalDetections(boxes, gtBoxes, options)
%CH16_EVALDETECTIONS 用 IoU 計算偵測的 precision 與 recall。
%
%   [P, R] = CH16_EVALDETECTIONS(BOXES, GTBOXES) 以 IoU >= 0.5 判定命中。
%   [P, R, DETAILS] = CH16_EVALDETECTIONS(___) 另外回傳 TP/FP/漏抓數。
%
%   名稱-值引數：
%     IoUThreshold  判定命中的 IoU 門檻，預設 0.5
%
%   為什麼 precision 與 recall 必須一起看
%   -------------------------------------
%   第 16 章第 6 節實測（4 個真實目標）：
%
%     輪次        偵測框    precision   recall
%     第 1 輪       509        0.8%     100.0%
%     第 2 輪         4      100.0%     100.0%
%
%   **第 1 輪的 recall 是完美的 100%。** 只看 recall 會以為偵測器很好——
%   它確實找到了全部四個目標，只是同時吐出 505 個錯的。
%
%   反過來只看 precision 也會被騙：一個只輸出「最有信心的那一個框」
%   的偵測器 precision 可能是 100%，但 recall 只有 25%。
%
%   > **偵測任務永遠要兩個數字一起報。**
%
%   關於 IoU 門檻的選擇
%   -------------------
%   0.5 是慣例（PASCAL VOC 的標準），但它相當寬鬆——
%   框只要蓋到一半就算對。COCO 的標準做法是對 0.5:0.05:0.95
%   多個門檻取平均（mAP），對定位精度的要求嚴格得多。
%
%   本函式預設 0.5，但**報告時一定要註明用的是哪個門檻**——
%   同一個偵測器在 0.5 與 0.75 下的分數可以差很多。
%
%   另見 BBOXOVERLAPRATIO, EVALUATEOBJECTDETECTION, CH16_SLIDINGWINDOW.

arguments
    boxes   {mustBeNumeric}
    gtBoxes {mustBeNumeric, mustBeNonempty}
    options.IoUThreshold (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
end

if isempty(boxes) || size(boxes,1) == 0
    precisionPct = 0;
    recallPct    = 0;
    details = struct("TP", 0, "FP", 0, "Missed", size(gtBoxes,1), ...
        "IoUThreshold", options.IoUThreshold);
    return
end

ov = bboxOverlapRatio(boxes, gtBoxes);

isTP  = any(ov >= options.IoUThreshold, 2);   % 這個偵測框命中了某個 GT
hitGT = any(ov >= options.IoUThreshold, 1);   % 這個 GT 被某個框命中

nTP = nnz(isTP);
nFP = size(boxes,1) - nTP;

precisionPct = 100 * nTP / size(boxes,1);
recallPct    = 100 * nnz(hitGT) / size(gtBoxes,1);

details = struct("TP", nTP, "FP", nFP, ...
    "Missed", nnz(~hitGT), "IoUThreshold", options.IoUThreshold);
end
