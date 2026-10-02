function report = ch26_fitCompare(options)
%CH26_FITCOMPARE 比較 MSAC（pcfitplane）與最小平方的平面擬合。
%
%   REPORT = CH26_FITCOMPARE() 產生一個**已知法向量**的合成平面，
%   分別用 `pcfitplane`（MSAC）與直接 SVD 最小平方擬合，
%   回傳 table：
%     Method        方法
%     OutlierPct    離群點比例
%     MeanErrorDeg  法向量角度誤差的平均
%     StdErrorDeg   **重複執行的標準差**
%     Deterministic 是否為確定性方法
%
%   ## 這支函式要回答的問題
%   **`pcfitplane` 比最小平方好嗎？** 答案是「看有沒有離群點」——**還要看 MATLAB 版本**。
%
%   本機實測（3000 點、雜訊 σ=0.01、無離群點）：
%   | 方法 | R2026a | R2026b |
%   |---|---|---|
%   | `pcfitplane`（MSAC，門檻 0.05） | **1.033° ± 0.656** | **0.028° ± 0.030** |
%   | SVD 最小平方 | 0.018°（確定性） | 0.018°（確定性） |
%   | MSAC + 內點精修 | 0.028° | 0.018° |
%
%   R2026a 的 `pcfitplane` 只從隨機取樣的最小集合找共識集，**不做最終的最小平方精修**，
%   所以在乾淨資料上比最小平方差 58 倍，而且每次答案不同。
%   **R2026b 起它會用內點再做一次 SVD 擬合**，差距縮到約 1.5 倍。
%
%   > MSAC 負責找「誰是內點」，最小平方負責「算得準」。
%   > 第三種方法 "MSAC + refit" 就是把這兩步分開手動做；R2026b 的 `pcfitplane` 已經內建。
%
%   名稱-值引數：
%     NumPoints    點數，預設 3000
%     NoiseSigma   高斯雜訊標準差，預設 0.01
%     OutlierPcts  要測試的離群點比例，預設 [0 0.1 0.3]
%     MaxDistance  MSAC 的內點門檻，預設 0.05
%     NumRepeats   每個設定重複幾次（量 MSAC 的變異），預設 10
%     Seed         亂數種子，預設 0
%
%   另見 PCFITPLANE, PCFITSPHERE, PCFITCYLINDER, SVD.

arguments
    options.NumPoints   (1,1) double {mustBePositive} = 3000
    options.NoiseSigma  (1,1) double {mustBeNonnegative} = 0.01
    options.OutlierPcts (1,:) double = [0 0.1 0.3]
    options.MaxDistance (1,1) double {mustBePositive} = 0.05
    options.NumRepeats  (1,1) double {mustBePositive} = 10
    options.Seed        (1,1) double = 0
end

rng(options.Seed);

% 已知的平面：z = 0.3x - 0.2y + 0.5，也就是 0.3x - 0.2y - z + 0.5 = 0
trueNormal = [0.3 -0.2 -1];
trueNormal = trueNormal / norm(trueNormal);

Method        = strings(0,1);
OutlierPct    = zeros(0,1);
MeanErrorDeg  = zeros(0,1);
StdErrorDeg   = zeros(0,1);
Deterministic = false(0,1);

for op = options.OutlierPcts
    cloud = localMakePlane(options.NumPoints, options.NoiseSigma, op, trueNormal);

    % ---- ① MSAC（pcfitplane）：隨機，所以要重複
    errMSAC  = zeros(options.NumRepeats,1);
    errRefit = zeros(options.NumRepeats,1);
    for r = 1:options.NumRepeats
        [model, inlierIdx] = pcfitplane(cloud, options.MaxDistance);
        errMSAC(r) = localAngle(model.Normal, trueNormal);

        % ---- ③ MSAC 找內點 + 最小平方精修
        P = cloud.Location(inlierIdx, :);
        errRefit(r) = localAngle(localFitLS(P), trueNormal);
    end

    % ---- ② 直接最小平方（確定性，跑一次就夠）
    errLS = localAngle(localFitLS(cloud.Location), trueNormal);

    Method(end+1,1)        = "MSAC (pcfitplane)";  %#ok<AGROW>
    OutlierPct(end+1,1)    = op*100;               %#ok<AGROW>
    MeanErrorDeg(end+1,1)  = mean(errMSAC);        %#ok<AGROW>
    StdErrorDeg(end+1,1)   = std(errMSAC);         %#ok<AGROW>
    Deterministic(end+1,1) = false;                %#ok<AGROW>

    Method(end+1,1)        = "最小平方 (SVD)";      %#ok<AGROW>
    OutlierPct(end+1,1)    = op*100;               %#ok<AGROW>
    MeanErrorDeg(end+1,1)  = errLS;                %#ok<AGROW>
    StdErrorDeg(end+1,1)   = 0;                    %#ok<AGROW>
    Deterministic(end+1,1) = true;                 %#ok<AGROW>

    Method(end+1,1)        = "MSAC + 內點精修";     %#ok<AGROW>
    OutlierPct(end+1,1)    = op*100;               %#ok<AGROW>
    MeanErrorDeg(end+1,1)  = mean(errRefit);       %#ok<AGROW>
    StdErrorDeg(end+1,1)   = std(errRefit);        %#ok<AGROW>
    Deterministic(end+1,1) = false;                %#ok<AGROW>
end

report = table(Method, OutlierPct, MeanErrorDeg, StdErrorDeg, Deterministic);
report = sortrows(report, ["OutlierPct" "MeanErrorDeg"]);
end

% ========================================================================
function cloud = localMakePlane(n, sigma, outlierPct, trueNormal) %#ok<INUSD>
%LOCALMAKEPLANE 產生一個已知平面 + 雜訊 + 均勻分布的離群點。
P = [rand(n,1)*2-1, rand(n,1)*2-1, zeros(n,1)];
P(:,3) = 0.3*P(:,1) - 0.2*P(:,2) + 0.5;
P = P + randn(n,3) * sigma;

nOut = round(n * outlierPct);
if nOut > 0
    % 離群點填滿整個包圍盒，不是貼著平面——這是**最容易**的情況。
    % 真實的離群點常常是「另一個平面」，那難得多（見練習 3）。
    outliers = [rand(nOut,1)*2-1, rand(nOut,1)*2-1, rand(nOut,1)*4-1.5];
    P = [P; outliers];
end
cloud = pointCloud(P);
end

% ------------------------------------------------------------------------
function n = localFitLS(P)
%LOCALFITLS 最小平方平面擬合：對去中心化的點做 SVD，取最小奇異值的方向。
%   **這是確定性的**——同樣的輸入永遠給同樣的答案。
P = double(P);
Q = P - mean(P, 1);
[~, ~, V] = svd(Q, 0);
n = V(:,3)';
end

% ------------------------------------------------------------------------
function deg = localAngle(n1, n2)
%LOCALANGLE 兩個法向量的夾角（度）。**取絕對值**，因為法向量的正負號沒有意義。
n1 = double(n1) / norm(double(n1));
n2 = double(n2) / norm(double(n2));
deg = acosd(min(1, abs(dot(n1, n2))));
end
