function [centers, radii, info] = ch10_autoCircles(I, options)
%CH10_AUTOCIRCLES 自動推算半徑範圍後再用霍夫變換偵測圓。
%
%   [CENTERS, RADII] = CH10_AUTOCIRCLES(I) 先用門檻與形態學取得粗略的物件
%   遮罩，從中估計圓的尺寸分布，據此自動設定 RadiusRange，再呼叫
%   imfindcircles。**使用者不需要事先知道半徑。**
%
%   [CENTERS, RADII, INFO] = CH10_AUTOCIRCLES(___) 另外回傳診斷 struct：
%     EstimatedRadii    從遮罩估出的半徑樣本
%     RadiusBands       實際搜尋的半徑區間（可能多段）
%     DetectionsPerBand 每個區間找到幾個圓
%     Multimodal        尺寸分布是否為多峰
%
%   名稱-值引數：
%     Sensitivity   傳給 imfindcircles，預設 0.92
%     MinArea       估計尺寸時忽略小於此面積的區域，預設 50
%     BandPadding   半徑區間往外放寬的比例，預設 0.25
%     MaxBands      最多分幾段搜尋，預設 3
%     Polarity      "bright"（預設）或 "dark"，圓比背景亮還暗
%
%   為什麼要分段搜尋
%   ----------------
%   霍夫圓偵測的累加器會隨半徑範圍變寬而變得嘈雜，假峰值跟著變多。
%   第 10 章實測（coins.png，正解 10 枚）：
%
%     RadiusRange [20 30] → 10（正確）
%     RadiusRange [5 50]  → 14（誤偵測）
%
%   所以當尺寸分布是多峰時（影像中有大小不同的圓），與其開一個很寬的範圍，
%   不如針對每一群各搜尋一次再合併。
%
%   這支函式補上了什麼、又補不上什麼
%   --------------------------------
%   補上了「不必人工給半徑」這一點——這是 imfindcircles 最大的痛點。
%   但它**仍然依賴一次前置的門檻分割**：若物件與背景的對比不足、
%   或圓彼此重疊而無法用門檻分開，尺寸估計就會失準，整條路就斷了。
%
%   `imfindcirclesYOLO`（R2026a）不需要這個前置步驟——模型直接從影像
%   辨認圓形，不經過門檻。這是它真正的優勢所在，代價是慢 5–12 倍、
%   需要支援包，而且無法解釋。
%
%   範例：
%     [gx, gy] = meshgrid(1:500, 1:400);
%     specs = [80 90 15; 200 100 28; 350 110 45; 120 280 22; 280 300 35];
%     I = zeros(400,500,"uint8") + 30;
%     for k = 1:size(specs,1)
%         I((gx-specs(k,1)).^2 + (gy-specs(k,2)).^2 < specs(k,3)^2) = 200;
%     end
%
%     [c, r, info] = ch10_autoCircles(I);
%     fprintf("找到 %d 個圓，搜尋了 %d 段\n", numel(r), size(info.RadiusBands,1));
%     imshow(I); viscircles(c, r);
%
%   另見 IMFINDCIRCLES, IMFINDCIRCLESYOLO, REGIONPROPS.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.Sensitivity (1,1) double {mustBeInRange(options.Sensitivity, 0, 1)} = 0.92
    options.MinArea     (1,1) double {mustBeNonnegative}                        = 50
    options.BandPadding (1,1) double {mustBeNonnegative}                        = 0.25
    options.MaxBands    (1,1) double {mustBePositive, mustBeInteger}            = 3
    options.Polarity    (1,1) string ...
        {mustBeMember(options.Polarity, ["bright" "dark"])} = "bright"
end

G = im2gray(I);

% --- 步驟 1：粗略分割，估計物件尺寸 -----------------------------------
mask = imbinarize(G);
if options.Polarity == "dark"
    mask = ~mask;
end
if mean(mask, "all") > 0.5      % 前景應為少數派
    mask = ~mask;
end

mask = imfill(mask, "holes");
mask = bwareaopen(mask, options.MinArea);

stats = regionprops("table", mask, "EquivDiameter", "Circularity");

if isempty(stats)
    centers = zeros(0,2);
    radii   = zeros(0,1);
    info    = struct("EstimatedRadii", [], "RadiusBands", zeros(0,2), ...
                     "DetectionsPerBand", [], "Multimodal", false);
    warning("ch10_autoCircles:noObjects", ...
        "前置分割找不到任何物件，無法估計半徑範圍。" + ...
        "請檢查 Polarity 設定，或改用 imfindcirclesYOLO。");
    return
end

% 只用夠圓的區域來估半徑，避免被雜訊或黏連物件拉偏
roundEnough = stats.Circularity > 0.6;
if any(roundEnough)
    stats = stats(roundEnough, :);
end

estimatedRadii = stats.EquivDiameter / 2;

% --- 步驟 2：判斷尺寸分布是不是多峰 -----------------------------------
[bands, isMultimodal] = deriveBands(estimatedRadii, options.BandPadding, options.MaxBands);

% --- 步驟 3：逐段搜尋再合併 -------------------------------------------
centers = zeros(0,2);
radii   = zeros(0,1);
perBand = zeros(size(bands,1), 1);

warnState = warning("off", "images:imfindcircles:warnForSmallRadius");
cleanupWarn = onCleanup(@() warning(warnState));

for k = 1:size(bands,1)
    [c, r] = imfindcircles(G, bands(k,:), ...
        Sensitivity = options.Sensitivity, ...
        ObjectPolarity = options.Polarity);
    perBand(k) = numel(r);
    centers = [centers; c];   %#ok<AGROW>
    radii   = [radii;   r];   %#ok<AGROW>
end

% 不同區間可能重複偵測到同一個圓，合併距離過近的結果
[centers, radii] = mergeOverlapping(centers, radii);

info = struct( ...
    "EstimatedRadii",    estimatedRadii, ...
    "RadiusBands",       bands, ...
    "DetectionsPerBand", perBand, ...
    "Multimodal",        isMultimodal);
end

% ========================================================================
function [bands, isMultimodal] = deriveBands(radii, padding, maxBands)
%DERIVEBANDS 從半徑樣本推出要搜尋的區間，必要時分成多段。

radii = sort(radii(:));
isMultimodal = false;

if numel(radii) < 3
    bands = padBand([min(radii) max(radii)], padding);
    return
end

% 用相鄰樣本的間距找出明顯的斷層。間距超過整體全距的 25% 就視為分群。
gaps   = diff(radii);
spread = max(radii) - min(radii);

if spread <= 0
    bands = padBand([radii(1) radii(1)], padding);
    return
end

splitAt = find(gaps > 0.25 * spread);

if isempty(splitAt)
    bands = padBand([min(radii) max(radii)], padding);
    return
end

isMultimodal = true;

% 太多群時只保留間距最大的幾個切點
if numel(splitAt) > maxBands - 1
    [~, order] = sort(gaps(splitAt), "descend");
    splitAt = sort(splitAt(order(1:maxBands-1)));
end

edgesIdx = [0; splitAt(:); numel(radii)];
bands = zeros(numel(edgesIdx)-1, 2);
for k = 1:size(bands,1)
    group = radii(edgesIdx(k)+1 : edgesIdx(k+1));
    bands(k,:) = padBand([min(group) max(group)], padding);
end
end

% ------------------------------------------------------------------------
function b = padBand(range, padding)
%PADBAND 把區間往外放寬，並確保下界至少為 5（imfindcircles 的建議下限）。
lo = range(1) * (1 - padding);
hi = range(2) * (1 + padding);
b  = [max(5, floor(lo)), max(6, ceil(hi))];
end

% ------------------------------------------------------------------------
function [centers, radii] = mergeOverlapping(centers, radii)
%MERGEOVERLAPPING 合併圓心距離小於半徑一半的重複偵測，保留半徑較大者。
if isempty(radii)
    return
end

[radii, order] = sort(radii, "descend");
centers = centers(order, :);

keep = true(numel(radii), 1);
for k = 1:numel(radii)
    if ~keep(k), continue, end
    for j = k+1:numel(radii)
        if ~keep(j), continue, end
        if norm(centers(k,:) - centers(j,:)) < 0.5 * radii(k)
            keep(j) = false;
        end
    end
end

centers = centers(keep, :);
radii   = radii(keep);
end
