function preTbl = ch15_preprocessComparison(groundTruth, options)
%CH15_PREPROCESSCOMPARISON 比較 OCR 前處理方法，**強制在會失敗的輸入上測**。
%
%   PRETBL = CH15_PREPROCESSCOMPARISON(GROUNDTRUTH) 對四種**真的會造成
%   錯誤**的劣化，各試五種前處理，回傳 CER 表格。
%
%   名稱-值引數：
%     BaseFont   基準字級，預設 28
%
%   為什麼要「強制在會失敗的輸入上測」
%   ----------------------------------
%   這是本函式存在的主要理由，也是一個真實踩過的坑。
%
%   第一版的實驗用「模糊 sigma=1.5」當劣化條件，然後比較五種前處理。
%   結果五種方法**全部得到 CER = 0.0000**——因為 sigma=1.5 的影像
%   本來就能被完美辨識。那個實驗無法區分任何方法。
%
%   > **要比較「修復方法」，輸入必須真的壞掉。**
%   > 這與第 12 章「設計對照實驗時要確認你的困難案例真的困難」、
%   > 第 10 章練習 4 是同一個教訓。
%
%   本函式因此**先驗證每個劣化條件的基準 CER 大於 0**，
%   不滿足就發警告——避免再次做出無法區分的實驗。
%
%   實測結果（第 15 章第 6 節）
%   ---------------------------
%     劣化情況          無      imbinarize  放大2倍  放大2倍+bin  imsharpen
%     小字 FontSize=10  0.1000   0.1667     **0.0000**  0.0333    0.0667
%     重度模糊 sigma=3  1.0000   1.0000      1.0000     1.0000    1.0000
%     傾斜 2 度         0.2667   0.3667     **1.2333**  0.3000    0.3667
%     傾斜 10 度        0.3333   0.3333      0.8333     0.8333    0.3000
%
%   三個結論：
%
%   **① 放大 2 倍完美修好小字（0.1000 -> 0.0000），
%   卻把 2 度傾斜弄得更糟（0.2667 -> 1.2333）。**
%   放大會同時放大傾斜造成的字元重疊。
%   （CER 可以大於 1：輸出比參考字串長時，編輯距離會超過參考長度。）
%
%   **② 重度模糊 sigma=3 沒有任何前處理救得回來**（全部 1.0000）。
%   資訊已經消失了。
%
%   **③ imbinarize 在每一種情況下都沒有幫助，甚至更糟。**
%   因為 ocr 內部本來就會二值化，而且它的方法更適合文字——
%   自己先做等於用較差的方法搶先做了一次。
%
%   > **沒有「OCR 前處理標準流程」這種東西。**
%   > 要先知道你的影像是**哪一種**壞，才知道該用哪一種前處理。
%
%   範例：
%     disp(ch15_preprocessComparison("ABCDEFG 0123456789 Hello World"))
%
%   另見 CH15_OCRDEGRADATION, CH15_DESKEWEVALUATION, CH15_CER.

arguments
    groundTruth (1,1) string {mustBeNonzeroLengthText}
    options.BaseFont (1,1) double {mustBePositive} = 28
end

fs = options.BaseFont;
caseNames = ["SmallFont10"; "HeavyBlur3"; "Skew2deg"; "Skew10deg"];
caseImgs = { ...
    ch15_makeTextImage(groundTruth, 10), ...
    imgaussfilt(ch15_makeTextImage(groundTruth, fs), 3), ...
    imrotate(ch15_makeTextImage(groundTruth, fs), 2,  "bilinear", "crop"), ...
    imrotate(ch15_makeTextImage(groundTruth, fs), 10, "bilinear", "crop")};

methodNames = ["None" "Binarize" "Upscale2x" "Upscale2xBinarize" "Sharpen"];

nC = numel(caseNames);
nM = numel(methodNames);
vals = zeros(nC, nM);

for c = 1:nC
    for m = 1:nM
        B = applyPreprocess(caseImgs{c}, methodNames(m));
        vals(c,m) = ch15_cer(ch15_cleanText(ocr(B).Text), groundTruth);
    end
end

preTbl = array2table(vals, VariableNames=methodNames, RowNames=caseNames);

% --- 檢查實驗設計是否有效 ------------------------------------------
baselineIdx = find(methodNames == "None", 1);
useless = vals(:, baselineIdx) == 0;
if any(useless)
    warning("ch15_preprocessComparison:degradationTooMild", ...
        "%s 的基準 CER 已經是 0——這些劣化條件**本來就不會失敗**，" + ...
        "在它們上面比較前處理方法無法區分任何差異。" + ...
        "請加大劣化強度。", join(caseNames(useless), "、"));
end

% --- 有沒有方法在所有情況都好 --------------------------------------
better = vals < vals(:, baselineIdx);
alwaysBetter = all(better, 1);
if any(alwaysBetter)
    fprintf("在所有劣化情況下都優於「不處理」的方法：%s\n", ...
        join(methodNames(alwaysBetter), "、"));
else
    fprintf("**沒有任何前處理方法在所有劣化情況下都有幫助。**\n");
    fprintf("這正是重點：前處理必須對症下藥，沒有萬用流程。\n");
end
end

% ========================================================================
function B = applyPreprocess(A, method)
switch method
    case "None"
        B = A;
    case "Binarize"
        B = imbinarize(im2gray(A));
    case "Upscale2x"
        B = imresize(A, 2);
    case "Upscale2xBinarize"
        B = imbinarize(im2gray(imresize(A, 2)));
    case "Sharpen"
        B = imsharpen(A);
end
end
