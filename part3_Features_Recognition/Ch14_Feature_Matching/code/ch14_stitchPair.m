function [pano, info] = ch14_stitchPair(left, right, options)
%CH14_STITCHPAIR 拼接兩張有重疊的影像，並回報拼接品質。
%
%   [PANO, INFO] = CH14_STITCHPAIR(LEFT, RIGHT) 用 SIFT 特徵把 RIGHT
%   對位到 LEFT 的座標系，回傳拼接結果與品質報告。
%
%   INFO 欄位：
%     NumMatches    配對數
%     NumInliers    內點數
%     InlierPct     內點率
%     EstimatedTx   估到的水平平移量
%     Transform     估到的 tform 物件
%     Warning       若品質不足的提醒
%
%   名稱-值引數：
%     Detector       偵測器，預設 "SIFT"
%     TransformType  變換型別，預設 "projective"
%     MinInliers     最少內點數，低於此值發警告。預設 20
%
%   方向慣例（最容易出錯的地方）
%   ----------------------------
%   `estgeotform2d(movingPoints, fixedPoints)` 估的是
%   **把 moving 映射到 fixed** 的變換。
%
%   這裡要把 right 貼到 left 的座標系，所以：
%     moving = right 的點、fixed = left 的點
%
%   弄反的症狀是「拼接方向相反」或「影像被推到畫面外」。
%   判斷方法：**把估到的變換套回去，看能不能還原**——
%   本函式回報 EstimatedTx 就是為了讓你檢查這件事。
%
%   實測（第 14 章第 10 節）
%   ------------------------
%   從 peppers.png 切出第 1–320 欄與第 200–512 欄（重疊 121 欄）：
%
%     配對數                89
%     內點數                89（100%）
%     估計的 x 平移         198.94（真實 199）
%     平移誤差              0.06 像素
%     拼接結果 vs 原圖 PSNR  41.227 dB
%
%   PSNR 不是無限大，是因為 right 經過 imwarp 重新取樣（雙線性內插）
%   而產生的微小差異，**不是配對錯誤**。
%
%   重疊量是關鍵
%   ------------
%   重疊太少就沒有足夠的共同特徵。實務建議相鄰影像重疊 **30% 以上**；
%   本例的 121/320 = 38% 是舒適區。
%
%   範例：
%     Big = im2gray(imread("peppers.png"));
%     [pano, info] = ch14_stitchPair(Big(:,1:320), Big(:,200:512));
%     fprintf("平移 %.2f、內點 %d\n", info.EstimatedTx, info.NumInliers);
%
%   另見 ESTGEOTFORM2D, IMWARP, IMREF2D, CH14_MATCHANDVERIFY.

arguments
    left  {mustBeNumeric, mustBeNonempty}
    right {mustBeNumeric, mustBeNonempty}
    options.Detector      (1,1) string = "SIFT"
    options.TransformType (1,1) string = "projective"
    options.MinInliers    (1,1) double {mustBePositive} = 20
end

L = left;  if size(L,3) > 1, L = im2gray(L); end
Rg = right; if size(Rg,3) > 1, Rg = im2gray(Rg); end

pl = ch14_detect(options.Detector, L);
pr = ch14_detect(options.Detector, Rg);
[fl, vl] = extractFeatures(L, pl);
[fr, vr] = extractFeatures(Rg, pr);
pairs = matchFeatures(fl, fr, Unique=true);

if size(pairs,1) < 4
    error("ch14_stitchPair:tooFewMatches", ...
        "只找到 %d 組配對，無法估幾何變換。" + ...
        "最可能的原因是**兩張影像的重疊不足**——" + ...
        "建議重疊 30%% 以上。", size(pairs,1));
end

% moving = right 的點、fixed = left 的點 -> 估到的是 right -> left
[tf, inl] = estgeotform2d(vr(pairs(:,2)), vl(pairs(:,1)), ...
    options.TransformType, MaxNumTrials=3000);

warnMsg = "";
if nnz(inl) < options.MinInliers
    warnMsg = sprintf("內點只有 %d 組（建議 >= %d）。" + ...
        "拼接可能歪掉，請確認重疊量是否足夠。", ...
        nnz(inl), options.MinInliers);
    warning("ch14_stitchPair:lowInliers", "%s", warnMsg);
end

% 拼接畫布：以 left 為基準，寬度取兩張的合理範圍
outW = size(L,2) + size(Rg,2);
panoRef = imref2d([size(L,1), outW], [1 outW], [1 size(L,1)]);

warpedL = imwarp(L,  affinetform2d(eye(3)), OutputView=panoRef);
warpedR = imwarp(Rg, tf, OutputView=panoRef);

% 只在 left 沒有內容的地方填 right，避免覆蓋掉基準影像
fillMask = warpedR > 0 & warpedL == 0;
pano = warpedL;
pano(fillMask) = warpedR(fillMask);

% 裁掉右側全黑的部分
colHas = any(pano > 0, 1);
lastCol = find(colHas, 1, "last");
if ~isempty(lastCol)
    pano = pano(:, 1:lastCol);
end

info = struct( ...
    "NumMatches",  size(pairs,1), ...
    "NumInliers",  nnz(inl), ...
    "InlierPct",   100*mean(inl), ...
    "EstimatedTx", tf.A(1,3), ...
    "Transform",   tf, ...
    "Warning",     string(warnMsg));
end
