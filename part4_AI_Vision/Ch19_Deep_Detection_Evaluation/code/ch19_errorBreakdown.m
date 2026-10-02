function [tbl, info] = ch19_errorBreakdown(detResults, gtBoxes, options)
%CH19_ERRORBREAKDOWN 把偵測誤差拆成「定位不準／重複框／背景誤判／漏標」。
%
%   [TBL, INFO] = CH19_ERRORBREAKDOWN(DETRESULTS, GTBOXES) 逐張把每個
%   偵測框歸類，回傳各類誤差的數量與佔比。
%
%   分類規則（依分數由高到低走訪每個框）：
%     命中       IoU >= HitIoU 且該 GT 還沒被配對
%     重複框     IoU >= HitIoU 但那個 GT 已經被更高分的框配走
%     定位不準   LocIoU <= IoU < HitIoU（有碰到目標，但框歪了）
%     背景誤判   IoU < LocIoU（完全不在任何目標上）
%   另外統計沒有被任何框配到的 GT（漏標）。
%
%   名稱-值引數：
%     HitIoU - 判定命中的門檻（預設 0.5）
%     LocIoU - 「有碰到」的下限（預設 0.1）
%
%   **為什麼要拆**
%
%   `precision 20.5%` 只告訴你「八成的框是錯的」，
%   但**不同的錯要用完全不同的方法修**：
%
%   | 誤差型態 | 怎麼修 |
%   |---|---|
%   | 背景誤判 | 提高分數門檻、加硬負樣本（第 16 章 §7） |
%   | 定位不準 | 調錨框／輸入尺寸、加邊界框回歸的權重 |
%   | 重複框 | 調 NMS 的 `OverlapThreshold` |
%   | 漏標 | 降低分數門檻、檢查目標尺寸、**檢查類別對應**（§3） |
%
%   **拿錯誤的藥治錯誤的病是偵測任務最常見的浪費。**
%   有人看到 precision 低就去調 NMS，但若誤差幾乎都是背景誤判，
%   調 NMS 一點用都沒有。
%
%   R2026a **沒有** `detectionErrorAnalysis` 這類函式
%   （`exist` 回傳 0），所以這個分解要自己寫。
%
%   > 這是第 17 章加分題「誤差來源分解」的同一個手法：
%   > 把一個總結數字拆成可以分別行動的部分。
%
%   ============================================================
%   **重要：本函式的「命中／漏標」不會等於 EVALUATEOBJECTDETECTION 的
%   recall，不要把兩邊的數字放進同一張表。**
%
%   實測（40 張車輛影像、YOLOX、car+truck+bus、IoU 0.5）：
%
%     本函式的貪婪配對        46 / 46 個 GT 被配到（recall 100%）
%     evaluateObjectDetection recall **84.78%**（= 39 / 46）
%
%   差了 7 個目標。逐張比對後找到 4 張不一致的影像，
%   其中一張（GT = [102 69 27 19]）的偵測框是：
%
%     框1 分數 0.573  IoU 0.024
%     框2 分數 0.519  **IoU 0.859**   <- 明顯命中
%     框3 分數 0.319  IoU 0.016
%     框4 分數 0.289  IoU 0
%     框5 分數 0.261  **IoU 0.951**   <- 更明顯
%
%   **有兩個框的 IoU 遠超過 0.5，但官方的 `ImageMetrics.APOverlapAvg`
%   對這張影像回報 0。**
%
%   官方的配對規則沒有完整文件化，所以本課程**不猜它的內部邏輯**。
%   能確定的是：兩種都合理的配對實作，在同一批資料上會給出
%   不同的 recall。
%
%   實務上的處理方式：
%   1. **同一份報告裡的數字全部用同一個工具算**（本章其餘各節
%      一律用 `evaluateObjectDetection`）
%   2. 本函式只用來**看誤判的組成比例**，不要拿它的 recall 當結論
%   3. 跨團隊比較分數前，先確認雙方用的是同一套評估程式碼
%
%   > **這正是本章的主題本身**：一個 mAP 數字取決於一連串的定義，
%   > 而「配對規則」是其中最少被寫出來的一個。
%   ============================================================
%
%   另見 CH19_SCORESWEEP, CH19_IOUSWEEP.

arguments
    detResults table
    gtBoxes cell
    options.HitIoU (1,1) double {mustBeInRange(options.HitIoU,0,1)} = 0.5
    options.LocIoU (1,1) double {mustBeInRange(options.LocIoU,0,1)} = 0.1
end

nHit = 0; nDup = 0; nLoc = 0; nBg = 0; nMiss = 0; nGT = 0;

for i = 1:height(detResults)
    b = detResults.Boxes{i};
    s = detResults.Scores{i};
    g = gtBoxes{i};
    nGT = nGT + size(g,1);

    if isempty(g)
        nBg = nBg + size(b,1);
        continue
    end
    if isempty(b)
        nMiss = nMiss + size(g,1);
        continue
    end

    % 依分數由高到低處理，這樣「重複框」的定義才有意義
    [~, ord] = sort(s, "descend");
    b = b(ord,:);
    ov = bboxOverlapRatio(b, g);
    used = false(1, size(g,1));

    for r = 1:size(b,1)
        [bestOv, j] = max(ov(r,:));
        if bestOv >= options.HitIoU
            if used(j)
                nDup = nDup + 1;
            else
                nHit = nHit + 1;
                used(j) = true;
            end
        elseif bestOv >= options.LocIoU
            nLoc = nLoc + 1;
        else
            nBg = nBg + 1;
        end
    end
    nMiss = nMiss + nnz(~used);
end

nFP = nDup + nLoc + nBg;
kind = ["命中(本函式配對)"; "重複框"; "定位不準"; "背景誤判"; "漏標(本函式配對)"];
count = [nHit; nDup; nLoc; nBg; nMiss];
pctOfFP = [NaN; 100*nDup/max(nFP,1); 100*nLoc/max(nFP,1); 100*nBg/max(nFP,1); NaN];

tbl = table(kind, count, pctOfFP, ...
    VariableNames=["型態" "數量" "佔誤判比例"]);

info = struct("NumHit", nHit, "NumDup", nDup, "NumLoc", nLoc, ...
    "NumBg", nBg, "NumMiss", nMiss, "NumFP", nFP, "NumGT", nGT);

if nFP > 0
    [~, iMax] = max([nDup nLoc nBg]);
    kinds = ["重複框" "定位不準" "背景誤判"];
    fixes = ["調 NMS 的 OverlapThreshold" ...
             "調錨框／輸入尺寸，或檢查目標尺寸分布" ...
             "提高分數門檻或加硬負樣本"];
    fprintf("\n**最主要的誤判型態是「%s」（佔 %.0f%%）→ %s。**\n", ...
        kinds(iMax), 100*max([nDup nLoc nBg])/nFP, fixes(iMax));
end
end
