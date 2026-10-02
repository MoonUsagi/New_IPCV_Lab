function matchTbl = ch14_matchAndVerify(I, tfTrue, options)
%CH14_MATCHANDVERIFY 跑完整的偵測-描述-比對-剔除流程，量測**可比對性**。
%
%   MATCHTBL = CH14_MATCHANDVERIFY(I, TFTRUE) 對 I 套用已知變換 TFTRUE，
%   然後對多個偵測器各跑一次完整流程，回傳配對數、內點數、內點率與耗時。
%
%   名稱-值引數：
%     Detectors    要測的偵測器，預設七種
%     TransformType estgeotform2d 的變換型別，預設 "similarity"
%     MaxNumTrials  MSAC 的最大迭代，預設 2000
%
%   這個函式存在的理由
%   ------------------
%   CH14_DETECTORREPEATABILITY 量的是「位置能不能被再次偵測到」，
%   本函式量的是「**描述子能不能把它們配起來**」。
%
%   **這兩件事的排序完全不同**，而這是第 14 章最重要的發現。
%   實測（cameraman.tif、縮放 0.8 + 旋轉 30°）：
%
%     偵測器   重複性   配對數   內點數   內點率    秒數
%     SIFT     58.5%      72      72   100.0%   0.481
%     SURF     52.2%      23      13    56.5%   0.022
%     ORB      69.3%     159     143    89.9%   0.091
%     KAZE     75.7%      37      31    83.8%   0.090
%     BRISK    91.6%       7       6    85.7%   0.245
%     Harris   74.1%       6       6   100.0%   0.063
%     FAST     87.5%       5       4    80.0%   0.058
%
%   **BRISK 的重複性最高（91.6%），配對數卻最少（7 個）。**
%   **SIFT 的重複性只有 58.5%，卻配到 72 組而且 100% 都是內點。**
%
%   原因：重複性由**偵測器**決定，可比對性由**描述子**決定。
%   BRISK 找得到同樣的位置，但它的二元描述子在這個變換下區辨力不足，
%   matchFeatures 無法唯一決定配對，候選就被丟掉了。
%
%   > **只量重複性會選到 BRISK 或 FAST，然後在真實任務上只拿到 5–7 組配對。**
%
%   實務選擇：
%     要最可靠的配對 -> SIFT（72 組、100% 內點），代價是最慢
%     要多且快       -> ORB（143 內點、0.091 秒，比 SIFT 快 5.3 倍）
%
%   為什麼內點率不能單獨看
%   ----------------------
%   Harris 的內點率是 100%，看起來完美——但它只有 **6 組**配對。
%   6 組配對估出來的相似變換極度脆弱：只要有一組是巧合的錯配，
%   結果就會歪掉，而 MSAC 在樣本這麼少時無法可靠地識別它。
%   **配對數與內點率要一起看，而且配對數有下限**（相似變換至少要 2 組，
%   實務上建議 20 組以上）。
%
%   範例：
%     I = im2gray(imread("cameraman.tif"));
%     disp(ch14_matchAndVerify(I, simtform2d(0.8, 30, [0 0])))
%
%   另見 CH14_DETECTORREPEATABILITY, MATCHFEATURES, ESTGEOTFORM2D.

arguments
    I      {mustBeNumeric, mustBeNonempty}
    tfTrue
    options.Detectors (1,:) string = ["SIFT" "SURF" "ORB" "KAZE" ...
                                      "BRISK" "Harris" "FAST"]
    options.TransformType (1,1) string = "similarity"
    options.MaxNumTrials  (1,1) double {mustBePositive} = 2000
end

if size(I,3) > 1, I = im2gray(I); end
R = imref2d(size(I));
J = imwarp(I, tfTrue, OutputView=R);

nd = numel(options.Detectors);
nPts1 = zeros(nd,1); nPts2 = zeros(nd,1);
nMatch = zeros(nd,1); nInlier = zeros(nd,1);
rate = nan(nd,1); secs = zeros(nd,1);

minNeeded = 4;      % 相似變換數學上要 2 組，但少於 4 組估出來毫無意義

for di = 1:nd
    d = options.Detectors(di);
    t = tic;
    p1 = ch14_detect(d, I);
    p2 = ch14_detect(d, J);
    % 用 validPoints（第二輸出），不能用 p1/p2——
    % SIFT 的描述子比關鍵點多，其他偵測器會丟掉邊界點
    [f1, v1] = extractFeatures(I, p1);
    [f2, v2] = extractFeatures(J, p2);
    pairs = matchFeatures(f1, f2, Unique=true);
    secs(di) = toc(t);

    nPts1(di) = p1.Count;
    nPts2(di) = p2.Count;
    nMatch(di) = size(pairs,1);

    if size(pairs,1) < minNeeded
        continue                        % 留 NaN
    end

    [~, inl] = estgeotform2d(v2(pairs(:,2)), v1(pairs(:,1)), ...
        options.TransformType, MaxNumTrials=options.MaxNumTrials);
    nInlier(di) = nnz(inl);
    rate(di) = 100 * mean(inl);
end

matchTbl = table(nPts1, nPts2, nMatch, nInlier, rate, secs, ...
    VariableNames=["Points1" "Points2" "Matches" "Inliers" ...
                   "InlierPct" "Seconds"], ...
    RowNames=options.Detectors);

% 配對數太少的偵測器要提醒——內點率 100% 也救不了
tooFew = nMatch < 20 & nMatch >= minNeeded;
if any(tooFew)
    warning("ch14_matchAndVerify:tooFewMatches", ...
        "%s 的配對數少於 20 組。即使內點率很高，" + ...
        "這麼少的樣本估出來的變換極度脆弱——" + ...
        "一組巧合的錯配就會讓結果歪掉，而 MSAC 無法可靠識別它。" + ...
        "**配對數與內點率必須一起看。**", ...
        join(string(options.Detectors(tooFew)), "、"));
end
end
