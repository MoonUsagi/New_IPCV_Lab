function degradeTbl = ch15_ocrDegradation(groundTruth, options)
%CH15_OCRDEGRADATION 掃四種劣化，量 OCR 的字元錯誤率曲線。
%
%   DEGRADETBL = CH15_OCRDEGRADATION(GROUNDTRUTH) 用合成文字影像
%   （內容即 GROUNDTRUTH，所以答案精確）測試字級、模糊、雜訊、旋轉
%   對 CER 的影響。
%
%   名稱-值引數：
%     FontSizes   字級掃描，預設 [10 14 18 24 32 48]
%     Sigmas      模糊掃描，預設 [0 0.5 1 1.5 2 3]
%     NoiseVars   雜訊變異數，預設 [0 0.001 0.005 0.01 0.03 0.06]
%     Angles      旋轉角度，預設 [0 1 2 5 10 20]
%     BaseFont    非字級掃描時用的字級，預設 28
%
%   本函式回答一個問題：**OCR 最怕什麼？**
%   ----------------------------------------
%   實測結果（第 15 章第 5 節）**與直覺相反**：
%
%     劣化          什麼時候開始出錯
%     字級          < 14 pt（10 pt 時 CER 0.1000）
%     模糊          sigma 2 -> 3 之間（**懸崖**：0.0000 直接跳到 1.0000）
%     雜訊          **從來沒出錯**（variance 0.06 時 CER 仍是 0.0000）
%     旋轉          **2 度就 CER 0.2667**
%
%   > **OCR 幾乎完全不怕雜訊，卻會被 2 度的傾斜毀掉。**
%
%   原因在 OCR 的流程：它先二值化，再把影像切成字元框。
%     · **雜訊**是高頻的，二值化時被門檻直接壓掉，字形結構完好
%     · **傾斜**讓同一行文字的字元框互相重疊，**切字階段就錯了**，
%       後面的辨識再準也沒用
%
%   實務優先順序因此是：
%     1. 確保文字是正的（機構固定，或在原始影像上校正一次）
%     2. 確保字夠大（至少 14 pt 等效；掃描建議 300 dpi 以上）
%     3. 對焦要準（sigma=3 就是懸崖）
%     4. **去雜訊優先度最低**——它幾乎不影響 OCR
%
%   第 4 點與一般影像處理的直覺相反。
%   **不要把力氣花在不影響結果的前處理上。**
%
%   關於旋轉那一列的非單調
%   ----------------------
%   實測 2° 的 CER（0.2667）比 5°（0.1000）還糟。這不是雜訊——
%   小角度時字元框「剛好」重疊得最嚴重；更大的角度反而讓 OCR
%   的版面分析改用不同的切法。
%   **所以不能只測兩三個角度就下結論**，要掃出整條曲線。
%
%   範例：
%     disp(ch15_ocrDegradation("ABCDEFG 0123456789 Hello World"))
%
%   另見 CH15_CER, CH15_MAKETEXTIMAGE, CH15_PREPROCESSCOMPARISON.

arguments
    groundTruth (1,1) string {mustBeNonzeroLengthText}
    options.FontSizes (1,:) double = [10 14 18 24 32 48]
    options.Sigmas    (1,:) double = [0 0.5 1 1.5 2 3]
    options.NoiseVars (1,:) double = [0 0.001 0.005 0.01 0.03 0.06]
    options.Angles    (1,:) double = [0 1 2 5 10 20]
    options.BaseFont  (1,1) double {mustBePositive} = 28
end

base = ch15_makeTextImage(groundTruth, options.BaseFont);

kinds  = strings(0);
levels = [];
cers   = [];
confs  = [];

% --- 字級 ---
for fs = options.FontSizes
    A = ch15_makeTextImage(groundTruth, fs);
    [c, cf] = scoreOne(A, groundTruth);
    kinds(end+1,1) = "FontSize"; levels(end+1,1) = fs;
    cers(end+1,1) = c; confs(end+1,1) = cf;
end

% --- 模糊 ---
for sg = options.Sigmas
    A = base;
    if sg > 0, A = imgaussfilt(A, sg); end
    [c, cf] = scoreOne(A, groundTruth);
    kinds(end+1,1) = "Blur"; levels(end+1,1) = sg;
    cers(end+1,1) = c; confs(end+1,1) = cf;
end

% --- 雜訊 ---
for v = options.NoiseVars
    A = base;
    if v > 0, A = imnoise(A, "gaussian", 0, v); end
    [c, cf] = scoreOne(A, groundTruth);
    kinds(end+1,1) = "Noise"; levels(end+1,1) = v;
    cers(end+1,1) = c; confs(end+1,1) = cf;
end

% --- 旋轉 ---
for ang = options.Angles
    A = base;
    if ang > 0, A = imrotate(A, ang, "bilinear", "crop"); end
    [c, cf] = scoreOne(A, groundTruth);
    kinds(end+1,1) = "Rotation"; levels(end+1,1) = ang;
    cers(end+1,1) = c; confs(end+1,1) = cf;
end

degradeTbl = table(kinds, levels, cers, confs, ...
    VariableNames=["Degradation" "Level" "CER" "MeanConfidence"]);

% --- 誰最致命 ---------------------------------------------------------
summary = groupsummary(degradeTbl, "Degradation", "max", "CER");
[~, worst] = max(summary.max_CER);
noiseRow = summary(summary.Degradation == "Noise", :);

if ~isempty(noiseRow) && noiseRow.max_CER == 0
    fprintf("注意：雜訊在測試範圍內**完全沒有造成錯誤**（CER 全為 0），\n");
    fprintf("      而 %s 的最大 CER 是 %.4f。\n", ...
        summary.Degradation(worst), summary.max_CER(worst));
    fprintf("      去雜訊對 OCR 的優先度遠低於校正傾斜與確保字級。\n");
end
end

% ========================================================================
function [c, cf] = scoreOne(A, gt)
t = ocr(A);
c = ch15_cer(ch15_cleanText(t.Text), gt);
cf = mean(t.WordConfidences, "omitnan");
if isempty(cf), cf = NaN; end
end
