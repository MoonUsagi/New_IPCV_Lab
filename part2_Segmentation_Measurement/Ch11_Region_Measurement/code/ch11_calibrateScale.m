function [mmPerPixel, calibration] = ch11_calibrateScale(mask, referenceSizeMM, options)
%CH11_CALIBRATESCALE 由已知尺寸的參考物建立 mm/pixel 校正係數。
%
%   MMPERPIXEL = CH11_CALIBRATESCALE(MASK, REFERENCESIZEMM) 在二值遮罩中
%   找出參考物，用它們的量測尺寸與已知的實際尺寸 REFERENCESIZEMM 算出
%   mm/pixel 換算係數。
%
%   [MMPERPIXEL, CALIBRATION] = CH11_CALIBRATESCALE(___) 另外回傳校正報告
%   struct：
%     MMPerPixel        校正係數
%     NumReferences     用了幾個參考物
%     MeanPixelSize     參考物的平均尺寸（像素）
%     StdPixelSize      參考物尺寸的標準差（像素）
%     RelativeScatter   標準差 / 平均值
%     ValidationError   若提供了 ValidateSizeMM，這裡是驗證誤差（%）
%     ValidationScatter 驗證物的相對散布。**這個值大就代表驗證集不純**，
%                       此時 ValidationError 不能當成校正誤差來讀
%     Fingerprint       校正條件的指紋（見下方說明）
%     Note              人類可讀的校正說明
%
%   名稱-值引數：
%     SelectBy         怎麼挑參考物："largest"（預設，取最大的 N 個）
%                      或 "roundest"（取圓形度最高的 N 個）
%     NumReferences    用幾個參考物，預設 0 表示自動（見下方）
%     SizeProperty     用哪個屬性當「尺寸」，預設 "EquivDiameter"
%     MaxScatter       參考物尺寸的相對散布上限，超過就警告。預設 0.05
%     ValidateSizeMM   第二個已知尺寸，用來**獨立驗證**校正。預設 NaN
%     ValidateSelectBy 驗證物的挑選方式："all"（預設，用全部剩餘物件）、
%                      "smallest" 或 "largest"。用全部的樣本數最多，
%                      驗證誤差最能反映校正本身的偏差
%
%   為什麼要用多個參考物平均
%   ------------------------
%   第 11 章對 coins.png 的實測（nickel 21.21 mm 當參考，dime 17.91 mm 驗證）：
%
%     用單一枚 nickel 校正   誤差 0.15% – 2.79%（平均 1.38%）
%     用六枚 nickel 平均     誤差 0.37%
%
%   最糟的單枚選擇會產生 2.79% 的誤差——而你事先不知道自己挑到的是哪一枚。
%   **平均能把誤差降到約四分之一。**
%
%   上面 0.15% – 2.79% 這個範圍是**固定拿四枚 dime 當驗證集**量出來的。
%   注意直接呼叫 NumReferences=1 不會重現這個數字（會得到 7.09%）：
%   因為那時剩下的 9 個物件同時含 nickel 與 dime，驗證集不純。
%   本函式會用 ValidationScatter 偵測並警告這種情況。
%
%   為什麼要檢查散布
%   ----------------
%   參考物之間的尺寸散布反映的是**分割的穩定性**，不是物件真的大小不一
%   （同一種硬幣的實際尺寸差異遠小於量測散布）。
%
%   實測：六枚 nickel 的直徑標準差是 0.994 像素 = 0.365 mm，
%   比校正的驗證誤差 0.067 mm **大了五倍**。
%   這代表在這個案例上，**隨機的量測散布主宰了誤差，而不是校正偏差**。
%   改善方向因此是提高影像解析度或改善分割，而不是換一個參考物。
%
%   散布過大（預設超過 5%）時本函式會警告——那通常意味著：
%     · 分割不穩定（門檻選得不好、照明不均）
%     · 挑到的「參考物」其實不是同一種東西
%     · 影像有透視變形（近的物件看起來比遠的大）
%
%   為什麼要有 Fingerprint
%   ----------------------
%   與第 10 章的 ch10_classifyWorm 同一個原則：
%   **任何從資料校正出來的常數，都要帶著它的來歷一起流動。**
%   校正係數綁定於「這張影像、這個分割、這個挑選規則」。
%   換了任何一項就該重新校正。
%
%   範例：
%     I  = imread("coins.png");
%     bw = imclearborder(bwareaopen(imfill(imbinarize(I),"holes"), 100));
%
%     [mmpp, cal] = ch11_calibrateScale(bw, 21.21, ...
%         NumReferences=6, ValidateSizeMM=17.91);
%
%     fprintf("%.6f mm/pixel，驗證誤差 %.2f%%\n", mmpp, cal.ValidationError);
%     disp(cal.Note)
%
%   另見 CH11_MEASUREOBJECTS, REGIONPROPS, BWPROPFILT.

arguments
    mask                     {mustBeA(mask, ["logical" "numeric"])}
    referenceSizeMM    (1,1) double {mustBePositive}
    options.SelectBy         (1,1) string ...
        {mustBeMember(options.SelectBy, ["largest" "roundest"])} = "largest"
    options.NumReferences    (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    options.SizeProperty     (1,1) string ...
        {mustBeMember(options.SizeProperty, ...
        ["EquivDiameter" "MajorAxisLength" "MinorAxisLength"])} = "EquivDiameter"
    options.MaxScatter       (1,1) double {mustBePositive}                   = 0.05
    options.ValidateSizeMM   (1,1) double                                    = NaN
    options.ValidateSelectBy (1,1) string ...
        {mustBeMember(options.ValidateSelectBy, ["all" "smallest" "largest"])} = "all"
end

if ~islogical(mask)
    mask = logical(mask);
end

stats = regionprops("table", mask, options.SizeProperty, "Circularity", "Area");
if isempty(stats)
    error("ch11_calibrateScale:noObjects", "遮罩中找不到任何物件。");
end

sizes = stats.(options.SizeProperty);

% --- 挑選參考物 --------------------------------------------------------
switch options.SelectBy
    case "largest"
        [sortedSizes, order] = sort(sizes, "descend");
    case "roundest"
        [~, order] = sort(stats.Circularity, "descend");
        sortedSizes = sizes(order);
end

n = options.NumReferences;
if n == 0
    % 自動：用尺寸的最大間隙把物件分群，取尺寸最大的那一群
    ascending = sort(sizes);
    if numel(ascending) >= 3
        [~, gapIdx] = max(diff(ascending));
        n = numel(ascending) - gapIdx;
    else
        n = numel(ascending);
    end
end
n = min(n, numel(sortedSizes));

referenceSizes = sortedSizes(1:n);

% --- 計算係數 ----------------------------------------------------------
meanPixelSize = mean(referenceSizes);
stdPixelSize  = std(referenceSizes);
scatter       = stdPixelSize / meanPixelSize;

mmPerPixel = referenceSizeMM / meanPixelSize;

if n == 1
    warning("ch11_calibrateScale:singleReference", ...
        "只用了一個參考物。實測顯示單一參考物的校正誤差可達 2.79%%，" + ...
        "而多個平均可降到 0.37%%。請盡量提供多個同尺寸的參考物。");
end

if scatter > options.MaxScatter
    warning("ch11_calibrateScale:highScatter", ...
        "參考物的尺寸相對散布 %.1f%% 超過門檻 %.1f%%。" + ...
        "這通常代表分割不穩定、挑到的物件不是同一種、或影像有透視變形。" + ...
        "校正係數仍會回傳，但請先確認分割品質。", ...
        100*scatter, 100*options.MaxScatter);
end

% --- 獨立驗證 ----------------------------------------------------------
validationError   = NaN;
validationScatter = NaN;
validationNote    = "未提供驗證尺寸";

if ~isnan(options.ValidateSizeMM)
    remaining = sortedSizes(n+1:end);
    if isempty(remaining)
        warning("ch11_calibrateScale:noValidationObjects", ...
            "所有物件都被當成參考物了，沒有剩下的可以做獨立驗證。" + ...
            "請減少 NumReferences。");
    else
        % 預設用**全部**剩餘物件做驗證。樣本越多，驗證誤差越能反映校正
        % 本身的偏差，而不是單一物件的量測散布。
        switch options.ValidateSelectBy
            case "all",      validationSizes = remaining;
            case "smallest", validationSizes = remaining(remaining <= median(remaining));
            case "largest",  validationSizes = remaining(remaining >= median(remaining));
        end
        if isempty(validationSizes)
            validationSizes = remaining;
        end

        % 驗證物必須是**同一種東西**，否則算出來的「誤差」反映的是驗證集
        % 被汙染，而不是校正偏差。實測：NumReferences=1 時，剩下的 9 個物件
        % 同時含 5 枚 nickel 與 4 枚 dime，拿它們的平均去對 dime 的 17.91 mm
        % 比較會得到 7.09% ——那不是校正誤差。
        validationScatter = std(validationSizes) / mean(validationSizes);
        if numel(validationSizes) > 1 && validationScatter > options.MaxScatter
            warning("ch11_calibrateScale:mixedValidationSet", ...
                "驗證物的尺寸散布 %.1f%% 超過門檻 %.1f%%，" + ...
                "代表它們**不是同一種物件**。此時算出的驗證誤差反映的是" + ...
                "驗證集被汙染，而不是校正偏差。請用 ValidateSelectBy 或 " + ...
                "NumReferences 把驗證集限縮到單一種類。", ...
                100*validationScatter, 100*options.MaxScatter);
        end

        predicted = mean(validationSizes) * mmPerPixel;
        validationError = 100 * abs(predicted/options.ValidateSizeMM - 1);
        validationNote = sprintf("以 %d 個物件驗證（散布 %.1f%%）：預測 %.3f mm、實際 %.3f mm、誤差 %.2f%%", ...
            numel(validationSizes), 100*validationScatter, predicted, ...
            options.ValidateSizeMM, validationError);
    end
end

fingerprint = sprintf("prop=%s|select=%s|n=%d|size=%.2fmm", ...
    options.SizeProperty, options.SelectBy, n, referenceSizeMM);

note = sprintf("以 %d 個參考物（%.3f mm）校正，平均 %.2f px、散布 %.1f%%。%s", ...
    n, referenceSizeMM, meanPixelSize, 100*scatter, validationNote);

calibration = struct( ...
    "MMPerPixel",      mmPerPixel, ...
    "NumReferences",   n, ...
    "MeanPixelSize",   meanPixelSize, ...
    "StdPixelSize",    stdPixelSize, ...
    "RelativeScatter", scatter, ...
    "ValidationError", validationError, ...
    "ValidationScatter", validationScatter, ...
    "Fingerprint",     string(fingerprint), ...
    "Note",            string(note));
end
