function tbl = ch19_classMapping(raw, gtBoxes, mappings, targetName, options)
%CH19_CLASSMAPPING 掃描不同的類別對應方式，量它對分數的影響。
%
%   TBL = CH19_CLASSMAPPING(RAW, GTBOXES, MAPPINGS, TARGETNAME) 對每一種
%   對應方式做一次完整評估。MAPPINGS 是 cell 陣列，每格是
%   {名稱, 類別字串陣列}。
%
%   名稱-值引數：
%     IoUThreshold - 評估的 IoU 門檻（預設 0.5）
%
%   **這個掃描回答的問題是「分數有多少是我自己決定的」。**
%
%   偵測任務的評估流程裡有三個你以為是客觀、其實是主觀的選擇：
%   1. **類別怎麼對應**（本函式）
%   2. **IoU 門檻設多少**（CH19_IOUSWEEP）
%   3. **分數門檻設多少**（CH19_SCORESWEEP）
%
%   三個都會大幅改變數字，而論文與產品規格書常常只報一個 mAP。
%
%   > **報告偵測效能時，這三個選擇必須一起寫出來。**
%   > 只給「mAP = 0.48」是沒有意義的。
%
%   另見 CH19_MAPCLASSES, CH19_IOUSWEEP, CH19_SCORESWEEP.

arguments
    raw table
    gtBoxes cell
    mappings cell
    targetName (1,1) string
    options.IoUThreshold (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
end

blds = boxLabelDatastore(table(gtBoxes(:), VariableNames=targetName));

n = size(mappings, 1);
name = strings(n,1); nBox = zeros(n,1);
prec = zeros(n,1); rec = zeros(n,1); ap = zeros(n,1);

for k = 1:n
    dr = ch19_mapClasses(raw, mappings{k,2}, targetName);
    m = evaluateObjectDetection(dr, blds, options.IoUThreshold, Verbose=false);
    p = m.ClassMetrics.Precision{1};
    r = m.ClassMetrics.Recall{1};

    name(k) = mappings{k,1};
    nBox(k) = sum(cellfun(@(x) size(x,1), dr.Boxes));
    prec(k) = 100*p(end);
    rec(k)  = 100*r(end);
    ap(k)   = m.ClassMetrics.APOverlapAvg(1);
end

tbl = table(name, nBox, prec, rec, ap, ...
    VariableNames=["對應方式" "框數" "precision" "recall" "AP"]);

spread = max(ap) - min(ap);
if spread > 0.05
    [~, iB] = max(ap); [~, iW] = min(ap);
    fprintf("\n**只是換一個類別對應方式，AP 就從 %.4f 變成 %.4f" + ...
        "（相對提升 %.0f%%）——模型完全沒有改變。**\n", ...
        ap(iW), ap(iB), 100*(ap(iB)-ap(iW))/ap(iW));
    fprintf("最差：%s　最好：%s\n", name(iW), name(iB));
    fprintf("**這代表「分數」有很大一部分是你自己定義出來的。**\n");
end
end
