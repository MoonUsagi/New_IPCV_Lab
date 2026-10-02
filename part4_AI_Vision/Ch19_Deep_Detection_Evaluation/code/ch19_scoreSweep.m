function tbl = ch19_scoreSweep(detResults, gtBoxes, targetName, options)
%CH19_SCORESWEEP 掃描分數門檻，畫出 precision／recall 的取捨。
%
%   TBL = CH19_SCORESWEEP(DETRESULTS, GTBOXES, TARGETNAME) 對一串分數
%   門檻各評估一次，回傳每個門檻的框數、precision、recall、F1。
%
%   名稱-值引數：
%     Thresholds   - 分數門檻（預設 0:0.1:0.9）
%     IoUThreshold - 判定命中的 IoU（預設 0.5）
%
%   **這個函式每個門檻都呼叫一次 EVALUATEOBJECTDETECTION，
%   而不是自己寫配對。** 原因寫在 CH19_ERRORBREAKDOWN 的說明裡：
%   自己寫的配對與官方工具在同一批資料上會給出**不同的 recall**
%   （實測 46/46 vs 39/46），所以同一章裡的數字必須**全部來自同一個工具**，
%   否則表格之間會互相矛盾。
%
%   **分數門檻是三個主觀選擇裡最容易被忽略的一個。**
%
%   `evaluateObjectDetection` 算的 AP 是**整條 PR 曲線下的面積**，
%   它對分數門檻不敏感——因為它把所有門檻都考慮進去了。
%   但**你上線時只能選一個門檻**，而那個選擇決定了實際表現。
%
%   所以「AP 0.48」和「上線後的 precision」是兩回事：
%   AP 描述模型的**潛力**，門檻決定你**實際取到**哪一段。
%
%   > **這和第 15 章的條碼耐受度、第 16 章的硬負樣本是同一類問題：
%   > 一個總結性的數字藏住了一條你必須自己選點的曲線。**
%
%   怎麼選門檻？看下游：
%   - **預標註給人修**（第 17 章 §11）→ 選 recall 高的低門檻
%   - **自動化產線決策** → 選 precision 高的高門檻
%   - **沒有明確偏好** → 選 F1 最高的點，但要知道那只是一個預設值
%
%   另見 CH19_IOUSWEEP, CH19_CLASSMAPPING, CH19_ERRORBREAKDOWN.

arguments
    detResults table
    gtBoxes cell
    targetName (1,1) string
    options.Thresholds   (1,:) double {mustBeNonnegative} = 0:0.1:0.9
    options.IoUThreshold (1,1) double {mustBeInRange(options.IoUThreshold,0,1)} = 0.5
end

blds = boxLabelDatastore(table(gtBoxes(:), VariableNames=targetName));

th = options.Thresholds(:);
nBox = zeros(numel(th),1); prec = zeros(numel(th),1);
rec  = zeros(numel(th),1); f1   = zeros(numel(th),1);

for k = 1:numel(th)
    % 依門檻過濾，再交給官方評估工具
    dr = filterByScore(detResults, th(k), targetName);
    nBox(k) = sum(cellfun(@(x) size(x,1), dr.Boxes));

    if nBox(k) == 0
        prec(k) = NaN; rec(k) = 0; f1(k) = 0;
        continue
    end

    m = evaluateObjectDetection(dr, blds, options.IoUThreshold, Verbose=false);
    p = m.ClassMetrics.Precision{1};
    r = m.ClassMetrics.Recall{1};
    prec(k) = 100*p(end);
    rec(k)  = 100*r(end);
    f1(k)   = 2*prec(k)*rec(k) / max(prec(k)+rec(k), eps);
end

tbl = table(th, nBox, prec, rec, f1, ...
    VariableNames=["分數門檻" "框數" "precision" "recall" "F1"]);

[bestF1, iBest] = max(f1);
fprintf("\nF1 最高的門檻 = %.2f（F1 %.1f、precision %.1f%%、recall %.1f%%）\n", ...
    th(iBest), bestF1, prec(iBest), rec(iBest));
fprintf("**但這只是一個預設值——上線的門檻要由下游的成本決定。**\n");
end

% ========================================================================
function dr = filterByScore(detResults, th, targetName)
n = height(detResults);
Boxes = cell(n,1); Scores = cell(n,1); Labels = cell(n,1);
for i = 1:n
    b = detResults.Boxes{i};
    s = detResults.Scores{i};
    if isempty(b)
        Boxes{i} = zeros(0,4); Scores{i} = zeros(0,1);
        Labels{i} = categorical(strings(0,1), targetName);
        continue
    end
    keep = s >= th;
    Boxes{i}  = b(keep,:);
    Scores{i} = s(keep);
    Labels{i} = repmat(categorical(targetName, targetName), nnz(keep), 1);
end
dr = table(Boxes, Scores, Labels);
end
