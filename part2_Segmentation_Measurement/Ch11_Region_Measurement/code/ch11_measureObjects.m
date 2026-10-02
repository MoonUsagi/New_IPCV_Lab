function report = ch11_measureObjects(BW, options)
%CH11_MEASUREOBJECTS 產出可交付的物件量測報告。
%
%   REPORT = CH11_MEASUREOBJECTS(BW) 對二值遮罩做完整量測，回傳一個 struct：
%     Objects          每個物件一列的 table（像素單位，若有校正則含實際單位）
%     Summary          統計摘要 table
%     ExcludedCount    被排除的物件數
%     ExcludedReason   排除的理由
%     MMPerPixel       使用的校正係數（未校正時為 NaN）
%     CalibrationNote  校正的說明文字
%     MeasurementDef   使用的量測定義
%
%   名稱-值引數：
%     MMPerPixel       校正係數。給了才會產生實際單位的欄位。預設 NaN
%     CalibrationNote  校正的來歷說明。**有 MMPerPixel 就應該一起給**
%     ClearBorder      是否排除碰到影像邊界的物件，預設 true
%     MinArea          最小面積（像素），預設 0
%     DiameterProperty 用哪個屬性當「直徑」，預設 "EquivDiameter"
%
%   為什麼報告一定要含「被排除的樣本」
%   ----------------------------------
%   碰到影像邊界的物件是**被切斷**的，它的面積、周長、直徑全都被低估。
%   把它們納入統計會讓平均值偏低，而且**變異係數會被虛假地放大**——
%   那個變異不是物件真的大小不一，而是影像邊界隨機切掉了不同的比例。
%
%   第 08 章對 rice.png 的實測：排除 24 顆碰邊米粒後，平均面積從 170.1
%   上升到 185.2（+8.9%）。排除是正確的，但**必須在報告中說明**，
%   否則讀者無法判斷統計是否有偏。
%
%   為什麼要記錄量測定義
%   --------------------
%   同一枚硬幣用不同屬性量會得到不同的直徑（第 11 章第 6 節實測，
%   同一枚硬幣、同一個遮罩，差距達 2.5 像素）：
%
%     MajorAxisLength  58.745 像素   ← 擬合橢圓長軸，受離群邊界點影響，最大
%     EquivDiameter    57.470 像素   ← 同面積圓的直徑，最穩定
%     Perimeter/pi     56.604 像素   ← 由周長反推，**偏小 1.5%**
%     MinorAxisLength  56.253 像素   ← 擬合橢圓短軸，最小
%
%   注意 Perimeter/pi 的方向：直覺會認為階梯狀的邊界比平滑圓周**長**，
%   所以反推的直徑應該偏大。**實測相反。**
%   原因是 regionprops 的 Perimeter 並不是單純數邊界像素，
%   它會對邊界鏈做修正，結果略小於真實圓周
%   （實測 177.83，理論 pi*57.470 = 180.55，偏小 1.5%）。
%
%   若真的去數邊界像素，才會看到另一個方向的偏差：
%   nnz(bwperim(...)) = 161，比理論值**低估 10.8%**——
%   因為對角走一步的實際長度是 sqrt(2)，但只被數成 1 個像素。
%
%   **兩種周長都有系統偏差，方向還不一樣。**
%   沒有寫明用哪一個定義，別人拿同一張影像也量不出你的數字。
%
%   為什麼 CalibrationNote 不是可選的裝飾
%   -------------------------------------
%   校正係數是所有絕對數字的基礎。它是怎麼來的、用什麼參考物、
%   驗證誤差多少——這些資訊決定了讀者該信任你的數字到小數第幾位。
%   本函式在給了 MMPerPixel 卻沒給 CalibrationNote 時會發出警告。
%
%   這與第 10 章的「校正指紋」是同一個原則：
%   **任何從資料校正出來的常數，都要帶著它的來歷一起流動。**
%
%   範例：
%     I  = imread("coins.png");
%     bw = imclearborder(bwareaopen(imfill(imbinarize(I),"holes"), 100));
%
%     report = ch11_measureObjects(bw, MMPerPixel=0.367, ...
%         CalibrationNote="以 nickel 21.21 mm 校正，dime 驗證誤差 0.4%");
%
%     disp(report.Summary)
%     disp(report.Objects)
%
%   另見 REGIONPROPS, BWPROPFILT, IMCLEARBORDER, CALIPER.

arguments
    BW {mustBeA(BW, ["logical" "numeric"])}
    options.MMPerPixel       (1,1) double  = NaN
    options.CalibrationNote  (1,1) string  = ""
    options.ClearBorder      (1,1) logical = true
    options.MinArea          (1,1) double {mustBeNonnegative} = 0
    options.DiameterProperty (1,1) string ...
        {mustBeMember(options.DiameterProperty, ...
        ["EquivDiameter" "MajorAxisLength" "MinorAxisLength"])} = "EquivDiameter"
end

if ~islogical(BW)
    BW = logical(BW);
end

isCalibrated = ~isnan(options.MMPerPixel);

if isCalibrated && strlength(options.CalibrationNote) == 0
    warning("ch11_measureObjects:undocumentedCalibration", ...
        "給了 MMPerPixel 卻沒給 CalibrationNote。" + ...
        "校正係數是所有絕對數字的基礎----請說明它是用什麼參考物建立的、" + ...
        "以及驗證誤差多少。沒有這個資訊，報告的讀者無法判斷該信任到小數第幾位。");
end

% --- 排除不該納入統計的物件 -------------------------------------------
mask = BW;
countInitial = max(bwlabel(mask), [], "all");

excludedReasons = strings(0);
excludedCount = 0;

if options.MinArea > 0
    mask = bwareaopen(mask, options.MinArea);
    removed = countInitial - max(bwlabel(mask), [], "all");
    if removed > 0
        excludedCount = excludedCount + removed;
        excludedReasons(end+1) = sprintf("%d 個面積小於 %g 像素", removed, options.MinArea);
    end
end

if options.ClearBorder
    beforeBorder = max(bwlabel(mask), [], "all");
    mask = imclearborder(mask);
    removed = beforeBorder - max(bwlabel(mask), [], "all");
    if removed > 0
        excludedCount = excludedCount + removed;
        excludedReasons(end+1) = sprintf("%d 個位於影像邊界（尺寸被切斷，數值不可信）", removed);
    end
end

% --- 量測 --------------------------------------------------------------
objects = regionprops("table", mask, ...
    "Area", "Centroid", "EquivDiameter", "MajorAxisLength", "MinorAxisLength", ...
    "Perimeter", "Circularity", "Eccentricity", "Solidity");

if isempty(objects)
    report = struct( ...
        "Objects",         objects, ...
        "Summary",         table(), ...
        "ExcludedCount",   excludedCount, ...
        "ExcludedReason",  joinReasons(excludedReasons), ...
        "MMPerPixel",      options.MMPerPixel, ...
        "CalibrationNote", options.CalibrationNote, ...
        "MeasurementDef",  options.DiameterProperty);
    warning("ch11_measureObjects:noObjects", "排除之後沒有剩下任何物件。");
    return
end

diameterPx = objects.(options.DiameterProperty);

if isCalibrated
    objects.DiameterMM = diameterPx * options.MMPerPixel;
    objects.AreaMM2    = objects.Area * options.MMPerPixel^2;   % 面積是二次方
end

% --- 摘要（平均值一定要配離散程度）-----------------------------------
summaryRows = { ...
    "物件數",             height(objects),              "個"; ...
    "直徑 平均",          mean(diameterPx),             "px"; ...
    "直徑 標準差",        std(diameterPx),              "px"; ...
    "直徑 變異係數",      std(diameterPx)/mean(diameterPx), "--"; ...
    "直徑 最小",          min(diameterPx),              "px"; ...
    "直徑 最大",          max(diameterPx),              "px"; ...
    "面積 平均",          mean(objects.Area),           "px^2"; ...
    "圓形度 平均",        mean(objects.Circularity),    "--"};

if isCalibrated
    summaryRows = [summaryRows; { ...
        "直徑 平均",      mean(objects.DiameterMM),     "mm"; ...
        "直徑 標準差",    std(objects.DiameterMM),      "mm"; ...
        "面積 平均",      mean(objects.AreaMM2),        "mm^2"}];
end

summary = table( ...
    string(summaryRows(:,1)), ...
    cell2mat(summaryRows(:,2)), ...
    string(summaryRows(:,3)), ...
    VariableNames=["項目" "數值" "單位"]);

report = struct( ...
    "Objects",         objects, ...
    "Summary",         summary, ...
    "ExcludedCount",   excludedCount, ...
    "ExcludedReason",  joinReasons(excludedReasons), ...
    "MMPerPixel",      options.MMPerPixel, ...
    "CalibrationNote", options.CalibrationNote, ...
    "MeasurementDef",  options.DiameterProperty);
end

% ========================================================================
function s = joinReasons(reasons)
if isempty(reasons)
    s = "無排除";
else
    s = join(reasons, "；");
end
end
