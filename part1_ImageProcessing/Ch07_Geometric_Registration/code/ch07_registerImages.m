function [registered, tform, report] = ch07_registerImages(moving, fixed, options)
%CH07_REGISTERIMAGES 穩健的兩階段影像配準，會自我驗證結果。
%
%   REGISTERED = CH07_REGISTERIMAGES(MOVING, FIXED) 把 MOVING 對齊到 FIXED。
%   採用官方建議的兩階段策略：先用 imregcorr 取得粗略轉換，
%   再用 imregtform 精修。
%
%   [REGISTERED, TFORM, REPORT] = CH07_REGISTERIMAGES(___) 另外回傳轉換物件
%   與診斷 struct：
%     Stage              最終採用的階段："refined"、"coarse" 或 "none"
%     SimilarityBefore   配準前的相似度
%     SimilarityCoarse   imregcorr 之後的相似度
%     SimilarityRefined  imregtform 之後的相似度
%     Warning            若有降級，說明原因
%
%   名稱-值引數：
%     TransformType  "translation" / "rigid" / "similarity"（預設）/ "affine"
%                    注意 imregcorr 只支援前三種；選 "affine" 時粗配準階段
%                    會改用 "similarity"
%     Modality       "monomodal"（預設）或 "multimodal"
%     RadiusScale    InitialRadius 的縮小倍數，預設 3.5。多模態配準用預設值
%                    常會發散，調小可改善
%     MaxIterations  最佳化迭代上限，預設 300
%
%   為什麼需要自我驗證
%   ------------------
%   強度式配準是局部最佳化，起點不好就會陷在局部極值——而且它**不會報錯**，
%   只會回傳一個錯誤的轉換。第 07 章實測：對一個旋轉 23 度的影像，
%   imregtform 單獨使用只回復出 1.8 度，但整個流程「看起來」跑得很順利。
%
%   本函式在每一階段後都量測相似度。若精修階段反而變差，就退回粗配準的
%   結果並發出警告；若兩階段都比配準前差，就回傳單位轉換（等於不動）。
%   **寧可回傳「我沒做到」，也不要回傳一個錯的轉換。**
%
%   自我驗證的能力到哪裡
%   --------------------
%   相似度指標用的是正規化互相關，它能可靠地偵測「精修比粗配準更差」這種
%   退化。但它**無法判斷多模態配準是否正確**。第 07 章實測：
%
%     完全不相關的兩張影像，配準後相關 0.2114
%     真實的多模態影像對，正確配準後相關 0.1537
%
%   胡亂配準的分數比正確配準還高。原因是互相關假設兩張影像的亮度有線性
%   對應關係，而多模態影像根本不滿足這個前提。
%
%   因此本函式的處理是：
%     · monomodal：套用 MinSimilarity 絕對門檻，低於門檻就警告
%     · multimodal：**不套用絕對門檻**，改為提示「需人工確認」
%
%   這是刻意的設計。與其給一個假的保證，不如明白告訴使用者
%   「這個情況我驗證不了，請自己看 imshowpair」。
%
%   範例：
%     fixed  = im2double(imread("cameraman.tif"));
%     moving = imwarp(fixed, simtform2d(0.85, 23, [15 -10]), ...
%                     OutputView=imref2d(size(fixed)));
%
%     [reg, tf, rpt] = ch07_registerImages(moving, fixed);
%     fprintf("採用 %s 階段的結果\n", rpt.Stage);
%     fprintf("PSNR %.2f -> %.2f dB\n", psnr(moving,fixed), psnr(reg,fixed));
%     imshowpair(fixed, reg)
%
%   另見 IMREGCORR, IMREGTFORM, IMREGCONFIG, IMWARP.

arguments
    moving {mustBeNumeric, mustBeNonempty}
    fixed  {mustBeNumeric, mustBeNonempty}
    options.TransformType (1,1) string ...
        {mustBeMember(options.TransformType, ["translation" "rigid" "similarity" "affine"])} = "similarity"
    options.Modality (1,1) string ...
        {mustBeMember(options.Modality, ["monomodal" "multimodal"])} = "monomodal"
    options.RadiusScale   (1,1) double {mustBePositive} = 3.5
    options.MaxIterations (1,1) double {mustBePositive, mustBeInteger} = 300
    options.MinSimilarity (1,1) double {mustBeInRange(options.MinSimilarity, -1, 1)} = 0.4
end

movingGray = im2double(im2gray(moving));
fixedGray  = im2double(im2gray(fixed));
Rfixed     = imref2d(size(fixedGray));

similarity = @(A) localSimilarity(A, fixedGray);

simBefore = similarity(resizeToMatch(movingGray, fixedGray));

% --- 階段 1：相位相關粗配準 -------------------------------------------
% imregcorr 不支援 affine，該情況退而求其次用 similarity 當粗配準
coarseType = options.TransformType;
if coarseType == "affine"
    coarseType = "similarity";
end

tformCoarse  = imregcorr(movingGray, fixedGray, coarseType);
coarseResult = imwarp(movingGray, tformCoarse, OutputView=Rfixed);
simCoarse    = similarity(coarseResult);

% --- 階段 2：強度式精修 -----------------------------------------------
[optimizer, metric] = imregconfig(options.Modality);
optimizer.MaximumIterations = options.MaxIterations;
if isprop(optimizer, "InitialRadius")
    optimizer.InitialRadius = optimizer.InitialRadius / options.RadiusScale;
end

simRefined    = -Inf;
tformRefined  = tformCoarse;
refinedResult = coarseResult;
warningMsg    = "";

try
    % 暫時關掉發散警告——我們用相似度自己判斷成敗
    w = warning("off", "images:regmex:registrationFailedException");
    cleanupWarn = onCleanup(@() warning(w));

    tformRefined  = imregtform(movingGray, fixedGray, options.TransformType, ...
        optimizer, metric, InitialTransformation=tformCoarse);
    refinedResult = imwarp(movingGray, tformRefined, OutputView=Rfixed);
    simRefined    = similarity(refinedResult);
catch ME
    warningMsg = "精修階段擲出例外：" + string(ME.message);
end

% --- 決策：採用哪一個結果 ---------------------------------------------
if simRefined >= simCoarse && simRefined >= simBefore
    stage      = "refined";
    tform      = tformRefined;
    registered = refinedResult;

elseif simCoarse >= simBefore
    stage      = "coarse";
    tform      = tformCoarse;
    registered = coarseResult;
    warningMsg = sprintf("精修反而變差（%.4f -> %.4f），已退回 imregcorr 的結果。", ...
        simCoarse, simRefined);
    warning("ch07_registerImages:refinementWorse", "%s", warningMsg);

else
    stage      = "none";
    tform      = simtform2d(1, 0, [0 0]);
    registered = resizeToMatch(movingGray, fixedGray);
    warningMsg = sprintf("兩個階段都沒有改善（配準前 %.4f、粗配準 %.4f、精修 %.4f）。" + ...
        "已回傳未配準的影像。請檢查兩張影像是否真的有對應關係。", ...
        simBefore, simCoarse, simRefined);
    warning("ch07_registerImages:noImprovement", "%s", warningMsg);
end

% --- 絕對品質把關 ------------------------------------------------------
finalSimilarity = similarity(registered);

if options.Modality == "monomodal"
    if finalSimilarity < options.MinSimilarity
        % 用 + 串接字串。方括號配雙引號會得到 string 陣列，sprintf 會拒絕。
        extra = sprintf("配準後相似度只有 %.4f，低於門檻 %.2f。" + ...
            "兩張影像可能沒有真正的對應關係，或需要更複雜的轉換模型。", ...
            finalSimilarity, options.MinSimilarity);
        warning("ch07_registerImages:lowSimilarity", "%s", extra);
        warningMsg = strtrim(warningMsg + " " + extra);
    end
else
    % 多模態：互相關無法判斷正確性，不做絕對門檻，只提示
    warningMsg = strtrim(warningMsg + ...
        " 多模態配準無法用互相關自動驗證，請用 imshowpair 人工確認結果。");
end

report = struct( ...
    "Stage",             stage, ...
    "FinalSimilarity",   finalSimilarity, ...
    "SimilarityBefore",  simBefore, ...
    "SimilarityCoarse",  simCoarse, ...
    "SimilarityRefined", simRefined, ...
    "Warning",           warningMsg);
end

% ========================================================================
function s = localSimilarity(A, B)
%LOCALSIMILARITY 正規化互相關。夠靈敏到能偵測明顯的配準失敗。
a = A(:) - mean(A(:));
b = B(:) - mean(B(:));
denom = norm(a) * norm(b);
if denom == 0
    s = 0;
else
    s = (a' * b) / denom;
end
end

% ------------------------------------------------------------------------
function out = resizeToMatch(A, B)
if isequal(size(A), size(B))
    out = A;
else
    out = imresize(A, size(B));
end
end
