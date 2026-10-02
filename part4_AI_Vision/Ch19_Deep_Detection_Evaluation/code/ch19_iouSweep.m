function [tbl, ious] = ch19_iouSweep(detResults, gtBoxes, targetName, options)
%CH19_IOUSWEEP 掃描 IoU 門檻，並看命中框的 IoU 分布。
%
%   [TBL, IOUS] = CH19_IOUSWEEP(DETRESULTS, GTBOXES, TARGETNAME) 對一串
%   IoU 門檻各評估一次，同時回傳每個偵測框對最近 GT 的 IoU（IOUS），
%   讓你能看**分布**而不只是幾個門檻上的值。
%
%   名稱-值引數：
%     Thresholds - 要掃描的門檻（預設 [0.3 0.5 0.6 0.75 0.9]）
%
%   **IoU 門檻決定「多接近才算對」，而它常常被當成一個慣例照抄。**
%
%   實測（40 張車輛影像、YOLOX、car+truck+bus 對應）：
%
%     IoU 門檻    AP      precision   recall
%       0.30    0.4827      20.5%     84.8%
%       0.50    0.4827      20.5%     84.8%
%       0.60    0.4827      20.5%     84.8%
%       0.75    0.4740      20.0%     82.6%
%       **0.90  0.0307       5.8%     23.9%**
%
%   **0.30 到 0.60 完全平坦，0.75 掉一點點，0.90 直接崩潰。**
%
%   為什麼會平坦然後懸崖？看 IoU 的分布就懂了：
%
%     所有框對最近 GT 的 IoU：中位數 **0.010**、只有 36% 達到 0.5
%     命中框（IoU>=0.5）的平均 IoU：**0.871**
%
%   **分布是雙峰的**：框要嘛幾乎完美（平均 0.871），
%   要嘛根本不在目標上（中位數 0.010，那些是誤判）。
%   中間地帶幾乎是空的，所以門檻在 0.3–0.6 之間移動不影響任何配對。
%
%   > **這個雙峰結構是「分數對 IoU 門檻不敏感」的原因，
%   > 而它是這個模型 + 這批資料的性質，不是通則。**
%   > 框位置比較鬆的模型會得到一條平滑下降的曲線，
%   > 那時候門檻選 0.5 還是 0.75 就會有很大差別。
%
%   **所以報告 mAP 時一定要寫清楚門檻。**
%   COCO 的慣例是 mAP@[0.5:0.05:0.95]（十個門檻的平均），
%   Pascal VOC 是 mAP@0.5。兩者不能互相比較。
%
%   另見 CH19_CLASSMAPPING, CH19_SCORESWEEP.

arguments
    detResults table
    gtBoxes cell
    targetName (1,1) string
    options.Thresholds (1,:) double {mustBeInRange(options.Thresholds,0,1)} = ...
        [0.3 0.5 0.6 0.75 0.9]
end

blds = boxLabelDatastore(table(gtBoxes(:), VariableNames=targetName));

th = options.Thresholds(:);
ap = zeros(numel(th),1); prec = zeros(numel(th),1); rec = zeros(numel(th),1);
for k = 1:numel(th)
    m = evaluateObjectDetection(detResults, blds, th(k), Verbose=false);
    p = m.ClassMetrics.Precision{1};
    r = m.ClassMetrics.Recall{1};
    ap(k) = m.ClassMetrics.APOverlapAvg(1);
    prec(k) = 100*p(end);
    rec(k) = 100*r(end);
end

tbl = table(th, ap, prec, rec, ...
    VariableNames=["IoU門檻" "AP" "precision" "recall"]);

% 每個偵測框對最近 GT 的 IoU
ious = [];
for k = 1:height(detResults)
    b = detResults.Boxes{k};
    g = gtBoxes{k};
    if isempty(b) || isempty(g), continue, end
    ious = [ious; max(bboxOverlapRatio(b, g), [], 2)]; %#ok<AGROW>
end

if ~isempty(ious)
    hit = ious(ious >= 0.5);
    fprintf("\n所有框對最近 GT 的 IoU：中位數 %.3f、>=0.5 的比例 %.0f%%\n", ...
        median(ious), 100*mean(ious >= 0.5));
    if ~isempty(hit)
        fprintf("命中框的平均 IoU = %.3f", mean(hit));
        if median(ious) < 0.1 && mean(hit) > 0.7
            fprintf("　<- **雙峰分布**：框不是幾乎完美，就是完全不在目標上");
        end
        fprintf("\n");
    end
end
end
