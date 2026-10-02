function skewTbl = ch15_deskewEvaluation(groundTruth, options)
%CH15_DESKEWEVALUATION 評估自動傾斜校正的**實際效果**（一個誠實的負面結果）。
%
%   SKEWTBL = CH15_DESKEWEVALUATION(GROUNDTRUTH) 對一系列已知的傾斜角，
%   用霍夫變換估角度、轉回來，比較校正前後的 CER。
%
%   名稱-值引數：
%     Angles     要測的傾斜角，預設 [1 2 5 10 15 20]
%     BaseFont   字級，預設 28
%
%   結論先講：**角度估得很準，但校正多半讓結果更差。**
%   -------------------------------------------------
%   第 15 章第 6.1 節實測：
%
%     真實角度   估到的角度   CER(未校正)   CER(校正後)
%       1°        -1.40        0.0667      **0.9667**
%       2°        -1.60        0.2667      **0.1333**
%       5°        -4.60        0.1000        0.3000
%      10°        -9.20        0.3333        0.7667
%      20°       -19.00        1.0000        1.0000
%
%   角度估計的誤差都在 1 度以內（-1.40 vs 1、-9.20 vs 10、-19.00 vs 20），
%   **但六個角度中只有 2° 那一列校正後變好。**
%
%   為什麼會這樣
%   ------------
%   **重新取樣的代價大於對齊的收益。**
%
%   測試影像已經被 imrotate 轉過一次（雙線性內插 #1），
%   校正時又轉一次（內插 #2）。兩次內插把字形邊緣抹糊，
%   而 OCR 對字形邊緣非常敏感——損失超過了「把字轉正」的好處。
%
%   此外 imrotate 的 "crop" 模式會**裁掉**轉出畫面的部分，
%   有時剛好切掉字串的頭尾。
%
%   > **估對角度不等於修好問題。修正動作本身也有代價。**
%
%   實務上該怎麼做
%   --------------
%   **不要讓影像被轉兩次：**
%     1. 最好的做法：**用機構把待測物固定正**，根本不需要轉
%        （這就是產線 OCR 幾乎都配治具的原因）
%     2. 次好：在**原始拍攝**的影像上估角度並只轉一次
%     3. 若一定要轉，用 "loose" 而非 "crop" 以免裁掉內容，
%        並考慮先放大再轉以降低內插損失
%
%   本函式的角度估計方法
%   --------------------
%   對二值化後的文字做 Canny 邊緣，再用霍夫變換找主要方向。
%   Theta 限制在 ±30 度——文字行大致水平，超出這個範圍的峰值
%   通常來自字元內部的筆畫而非基線。
%
%   這個方法在文字行數少、或字元筆畫方向一致（例如全大寫）時
%   不可靠。真實系統通常改用投影剖面法（projection profile）：
%   把影像在不同角度下做水平投影，變異數最大的角度就是正的。
%
%   範例：
%     disp(ch15_deskewEvaluation("ABCDEFG 0123456789 Hello World"))
%
%   另見 CH15_PREPROCESSCOMPARISON, HOUGH, IMROTATE.

arguments
    groundTruth (1,1) string {mustBeNonzeroLengthText}
    options.Angles   (1,:) double = [1 2 5 10 15 20]
    options.BaseFont (1,1) double {mustBePositive} = 28
end

base = ch15_makeTextImage(groundTruth, options.BaseFont);

n = numel(options.Angles);
trueAng = options.Angles(:);
estAng  = zeros(n,1);
cerBefore = zeros(n,1);
cerAfter  = zeros(n,1);

for k = 1:n
    A = imrotate(base, trueAng(k), "bilinear", "crop");
    cerBefore(k) = ch15_cer(ch15_cleanText(ocr(A).Text), groundTruth);

    [B, estAng(k)] = deskewImage(A);
    cerAfter(k) = ch15_cer(ch15_cleanText(ocr(B).Text), groundTruth);
end

improved = cerAfter < cerBefore;

skewTbl = table(trueAng, estAng, cerBefore, cerAfter, improved, ...
    VariableNames=["TrueAngle" "EstimatedAngle" "CER_Before" ...
                   "CER_After" "Improved"]);

% --- 誠實回報 ---------------------------------------------------------
angErr = abs(abs(estAng) - trueAng);
fprintf("角度估計誤差：平均 %.2f 度、最大 %.2f 度\n", ...
    mean(angErr), max(angErr));
fprintf("校正後變好的比例：%d / %d\n", nnz(improved), n);

if nnz(improved) <= n/2
    fprintf("\n**角度估得準，但校正多半讓結果更差。**\n");
    fprintf("原因是重新取樣的代價：影像被轉了兩次（施加傾斜 + 校正），\n");
    fprintf("兩次雙線性內插把字形邊緣抹糊，損失超過對齊的收益。\n");
    fprintf("實務上應該在**原始影像**上只轉一次，或用機構固定方向。\n");
end
end

% ========================================================================
function [B, estAngle] = deskewImage(A)
%DESKEWIMAGE 用霍夫變換估文字基線傾角並轉回來。
G = im2gray(A);
bw = ~imbinarize(G);                  % 文字轉為白色前景
bw = bwareaopen(bw, 10);              % 去掉雜點

E = edge(bw, "canny");
% Theta 限制在 +-30 度：文字行大致水平，
% 超出這個範圍的峰值通常來自字元內部筆畫而非基線
[H, T, ~] = hough(E, Theta=-30:0.2:30);
Pk = houghpeaks(H, 20);

if isempty(Pk)
    estAngle = 0;
    B = A;
    return
end

estAngle = median(T(Pk(:,2)));
B = imrotate(A, -estAngle, "bilinear", "crop");
end
