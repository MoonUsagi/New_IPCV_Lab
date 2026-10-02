%[text] # 第 08 章　練習解答
assert(exist("ch08_evaluateSegmentation","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
countObjects = @(bw) max(bwlabel(bw), [], "all");
%%
%[text] # 解答 1：診斷分割失敗的原因
%[text] 四張影像，四種不同的病因。先用數據診斷：
problemImages = ["rice.png" "AT3_1m4_01.tif" "coloredChips.png" "tissue.png"];

fprintf("%-20s %8s %10s %12s %12s\n", "影像", "通道", "前景%", "空白列比例", "直方圖峰數");
for name = problemImages
    X  = imread(name);
    G  = im2gray(X);
    bw = imbinarize(G);
    if mean(bw,"all") > 0.5, bw = ~bw; end

    blankRows = mean(sum(bw, 2) == 0);
    counts    = imhist(G);
    numPeaks  = numel(findpeaks(smoothdata(counts, "movmean", 12), ...
                                MinPeakProminence=max(counts)*0.05));

    fprintf("%-20s %8d %9.1f%% %11.2f %12d\n", name, size(X,3), ...
        100*mean(bw,"all"), blankRows, numPeaks);
end
%[text] ## 診斷與對策
%[text:table]
%[text] | 影像 | 病因 | 對策 | 依據 |
%[text] | --- | --- | --- | --- |
%[text] | `rice.png` | 照明不均（左上亮右下暗） | **top-hat**（Ch.06）再全域門檻 | 直方圖單峰、物件密布全圖 |
%[text] | `AT3_1m4_01.tif` | 照明不均 **＋ 有大片空白區** | top-hat；**不要用自適應門檻** | 空白列比例高 |
%[text] | `coloredChips.png` | **關鍵資訊在顏色**，灰階分不開 | HSV 色相門檻 | 三通道；灰階直方圖峰不分離 |
%[text] | `tissue.png` | 亮度相近，差別在**紋理** | `entropyfilt` 再門檻化 | 三通道但顏色也分不開 |
%[text:table]
%[text] 動手驗證每一個對策：
fprintf("\n%-20s %-22s %s\n", "影像", "對策", "改善證據");

% rice：top-hat
riceRaw = imbinarize(imread("rice.png"));
riceFix = imbinarize(imtophat(imread("rice.png"), strel("disk", 15)));
fprintf("%-20s %-22s 計數 %d -> %d（正確約 95）\n", "rice.png", "top-hat", ...
    countObjects(bwareaopen(riceRaw,30)), countObjects(bwareaopen(riceFix,30)));

% cells：top-hat
cellsRaw = imbinarize(imread("AT3_1m4_01.tif"));
cellsFix = imbinarize(imtophat(imread("AT3_1m4_01.tif"), strel("disk", 25)));
fprintf("%-20s %-22s 前景 %.1f%% -> %.1f%%" + "\n", "AT3_1m4_01.tif", "top-hat", ...
    100*mean(cellsRaw,"all"), 100*mean(cellsFix,"all"));

% chips：HSV
chips = imread("coloredChips.png");
chipsGray = imbinarize(im2gray(chips));
hsvChips = rgb2hsv(chips);
chipsHSV = hsvChips(:,:,2) > 0.4;          % 用飽和度就能分開圓片與灰背景
fprintf("%-20s %-22s 灰階前景 %.1f%% -> 飽和度 %.1f%%（圓片約佔 40%%）\n", ...
    "coloredChips.png", "HSV 飽和度門檻", 100*mean(chipsGray,"all"), 100*mean(chipsHSV,"all"));

% tissue：紋理
tissueGray = im2double(im2gray(imread("tissue.png")));
tissueEnt  = entropyfilt(tissueGray, true(9));
fprintf("%-20s %-22s 熵範圍 %.2f–%.2f（可門檻化）\n", "tissue.png", "entropyfilt", ...
    min(tissueEnt,[],"all"), max(tissueEnt,[],"all"));

figure
montage({riceFix, cellsFix, chipsHSV, imbinarize(rescale(tissueEnt))}, Size=[2 2])
title("rice top-hat ｜ cells top-hat ｜ chips 飽和度 ｜ tissue 熵")
%[text] **四張影像，沒有一張是「換一個更好的演算法」解決的。**
%[text] 全部都是**換對特徵**或**先修正影像**——這是本章最重要的觀念。
%%
%[text] # 解答 2：ISODATA 的參數在做什麼
gantry = im2gray(imread("gantrycrane.png"));

sdValues = [0.02 0.05 0.10 0.20 0.50];
msValues = [0.05 0.20 0.50 1.00 2.00];
sdClusters = zeros(size(sdValues));
msClusters = zeros(size(msValues));

fprintf("%-24s %s\n", "MaxStandardDeviation", "最終群數");
for k = 1:numel(sdValues)
    [~, c] = imsegisodata(gantry, InitialNumClusters=8, ...
        MaxStandardDeviation=sdValues(k), MaxIterations=30);
    sdClusters(k) = numel(c);
    fprintf("%-24.2f %d\n", sdValues(k), sdClusters(k));
end

fprintf("\n%-24s %s\n", "MinClusterSeparation", "最終群數");
for k = 1:numel(msValues)
    [~, c] = imsegisodata(gantry, InitialNumClusters=8, ...
        MinClusterSeparation=msValues(k), MaxIterations=30);
    msClusters(k) = numel(c);
    fprintf("%-24.2f %d\n", msValues(k), msClusters(k));
end

figure
tiledlayout(1,2)
nexttile; plot(sdValues, sdClusters, "-o", LineWidth=1.5)
xlabel("MaxStandardDeviation"); ylabel("最終群數"); title("控制分裂"); grid on
nexttile; plot(msValues, msClusters, "-s", LineWidth=1.5)
xlabel("MinClusterSeparation"); ylabel("最終群數"); title("控制合併"); grid on
%[text] ## 兩個參數的角色
%[text:table]
%[text] | 參數 | 控制 | 調大的效果 | 為什麼 |
%[text] | --- | --- | --- | --- |
%[text] | `MaxStandardDeviation` | **分裂** | 群數**變少** | 容許群內變異更大 → 較少群需要分裂 |
%[text] | `MinClusterSeparation` | **合併** | 群數**變少** | 要求群間距離更大 → 較多群被判定太近而合併 |
%[text:table]
%[text] **兩個都是「調大 → 群數變少」，但機制相反**：
%[text] 一個是「不再分裂」，一個是「更多合併」。
%[text] 這就是 ISODATA 的核心——它在每次迭代都同時考慮這兩個動作，
%[text] 讓群數自己收斂到資料的真實結構。
%[text] 注意 `MaxStandardDeviation` 在 0.02–0.20 之間都是 8 群（沒有分裂也沒合併），
%[text] 到 0.50 才掉到 5 群。**參數常常有一大段「沒反應」的區間**——
%[text] 掃描時要掃得夠寬，才不會誤以為參數無效。
%%
%[text] # 解答 3：分割評估函式
%[text] 完整實作在 `code/ch08_evaluateSegmentation.m`。
hands = imread("hands1.jpg");
gt = logical(imread("hands1-mask.png"));
handsGray = im2gray(hands);
hsvHands = rgb2hsv(hands);

candidates = { ...
    "Otsu（灰階）",     imbinarize(handsGray); ...
    "自適應（灰階）",    imbinarize(handsGray, "adaptive", Sensitivity=0.5); ...
    "ISODATA（灰階）",  imsegisodata(handsGray) > 1; ...
    "k-means 彩色",    imsegkmeans(hands, 2) == 2; ...
    "HSV 膚色門檻",     hsvHands(:,:,1) < 0.10 & hsvHands(:,:,2) > 0.20 & hsvHands(:,:,3) > 0.20};

[results, agree] = ch08_evaluateSegmentation(candidates, gt);

fprintf("\n三個指標是否一致：%d\n", agree);
%[text] 函式主動發出了警告——**這就是它存在的理由**。
%[text] 算三個指標只要三行，但**注意到它們排名不一致、並且知道那代表什麼**，
%[text] 才是真正需要工程判斷的地方。
%[text] 把這個判斷寫進函式，下一個用它的人就不會漏掉。
%%
%[text] # 解答 4：找出 GrabCut 的 ROI 底線
spLabels = superpixels(hands, 800);
fgSeeds = false(size(gt)); fgSeeds(110:130, 150:190) = true;
bgSeeds = false(size(gt)); bgSeeds(10:25, 10:40) = true; bgSeeds(215:235, 280:315) = true;

% 從正解的質心往外擴張一系列 ROI
props = regionprops(gt, "Centroid");
cy = props(1).Centroid(2);
cx = props(1).Centroid(1);
scales = 0.35:0.1:1.25;

coverage = zeros(size(scales));
actualDice = zeros(size(scales));
upperBound = zeros(size(scales));

for k = 1:numel(scales)
    halfH = scales(k) * size(gt,1) / 2;
    halfW = scales(k) * size(gt,2) / 2;
    roi = false(size(gt));
    rows = max(1, round(cy-halfH)) : min(size(gt,1), round(cy+halfH));
    cols = max(1, round(cx-halfW)) : min(size(gt,2), round(cx+halfW));
    roi(rows, cols) = true;

    coverage(k)   = nnz(roi & gt) / nnz(gt);
    upperBound(k) = dice(roi & gt, gt);        % 理論上限：ROI 內的正解 vs 全部正解
    actualDice(k) = dice(grabcut(hands, spLabels, roi, fgSeeds, bgSeeds), gt);
end

figure
plot(100*coverage, actualDice, "-o", 100*coverage, upperBound, "--", LineWidth=1.5)
legend("實際 GrabCut Dice", "理論上限（ROI∩GT vs GT）", Location="southeast")
xlabel("ROI 涵蓋正解的比例 (%)"); ylabel("Dice")
title("ROI 就是硬天花板"); grid on

disp(table(round(100*coverage)', round(upperBound,3)', round(actualDice,3)', ...
    VariableNames=["涵蓋率%" "理論上限" "實際Dice"]))
%[text] **實際 Dice 緊貼著理論上限走**。這證明 ROI 不是「軟性的建議範圍」，
%[text] 而是**硬天花板**——ROI 外的像素被標記為「確定背景」，
%[text] 演算法連考慮它們的機會都沒有。
%[text] **實務教訓**：GrabCut 的 ROI 寧可畫大。多算幾秒鐘，
%[text] 遠比拿到一個永遠不可能正確的結果便宜。
%%
%[text] # 解答 5：分割 → 形態學 → 量測 的完整流程
rice = imread("rice.png");

% 步驟 1：分割（練習 1 的結論：top-hat + 全域門檻）
riceMask = imbinarize(imtophat(rice, strel("disk", 15)));

% 步驟 2：形態學清理（關掉閉運算——Ch.06 練習 3 的教訓）
[cleanMask, log] = ch06_cleanMask(riceMask, CloseRadius=0, MinArea=30, ClearBorder=false);
disp(log)

% 步驟 3：移除碰邊物件
finalMask = imclearborder(cleanMask);
removed = countObjects(cleanMask) - countObjects(finalMask);

fprintf("\n清理後 %d 顆，移除碰邊 %d 顆，剩 %d 顆\n", ...
    countObjects(cleanMask), removed, countObjects(finalMask));

% 步驟 4–5：量測
stats = regionprops("table", finalMask, ...
    "Area", "MajorAxisLength", "MinorAxisLength", "Eccentricity", "Circularity");
stats = sortrows(stats, "Area", "descend");

disp(head(stats, 5))

figure
tiledlayout(2,2)
nexttile; imshow(rice);       title("原圖")
nexttile; imshow(finalMask);  title(sprintf("最終遮罩：%d 顆", height(stats)))
nexttile; histogram(stats.Area, 20); xlabel("面積（像素）"); ylabel("顆數"); title("面積分布")
nexttile
scatter(stats.MajorAxisLength, stats.MinorAxisLength, 30, "filled")
xlabel("長軸"); ylabel("短軸"); title("形狀分布"); grid on; axis equal

% 步驟 6
cv = std(stats.Area) / mean(stats.Area);
fprintf("\n共 %d 顆米\n", height(stats));
fprintf("平均面積 %.1f 像素（標準差 %.1f）\n", mean(stats.Area), std(stats.Area));
fprintf("面積變異係數 %.3f\n", cv);
fprintf("平均長寬比 %.2f\n", mean(stats.MajorAxisLength ./ stats.MinorAxisLength));
%[text] ## 第 3 步移除碰邊物件，會讓統計偏向哪一邊？
%[text] **偏向「偏小」的一邊——但方向可能與你的直覺相反。**
%[text] 被移除的是**被影像邊界切斷**的米粒，它們的量測面積比真實面積小。
%[text] 移除它們**提高**了平均面積（因為去掉了一批被低估的樣本）。
before = regionprops("table", cleanMask, "Area");
fprintf("\n含碰邊米粒 平均面積 %.1f（%d 顆）\n", mean(before.Area), height(before));
fprintf("移除後     平均面積 %.1f（%d 顆）  <- 提高了 %.1f%%" + "\n", ...
    mean(stats.Area), height(stats), 100*(mean(stats.Area)/mean(before.Area) - 1));
%[text] **但這仍然是正確的做法**。含進被切斷的米粒會讓平均值偏低，
%[text] 而且**變異係數會被虛假地放大**——那個變異不是米粒真的大小不一，
%[text] 而是影像邊界隨機切掉了不同的比例。
%[text] 一個誠實的報告應該寫：「有效樣本 N 顆（另有 M 顆因位於影像邊界而排除）」。
%[text] 這是第 11 章量測章節的標準做法。
%%
%[text] # 加分題：用分水嶺數細胞
cells = imread("AT3_1m4_01.tif");

% 照明校正 + 分割
cellsFlat = imtophat(cells, strel("disk", 25));
cellsMask = bwareaopen(imfill(imbinarize(cellsFlat), "holes"), 50);

fprintf("分割後直接計數：%d 個（黏連的細胞被算成一個）\n\n", countObjects(cellsMask));

D = -bwdist(~cellsMask);
D(~cellsMask) = Inf;

depths = [1 2 3 4 5 6 8 10 14];
counts = zeros(size(depths));

fprintf("%-14s %s\n", "imhmin 深度", "細胞數");
for k = 1:numel(depths)
    L = watershed(imhmin(D, depths(k)));
    L(~cellsMask) = 0;
    counts(k) = max(L(:));
    fprintf("%-14d %d\n", depths(k), counts(k));
end

figure
plot(depths, counts, "-o", LineWidth=1.5)
xlabel("imhmin 深度"); ylabel("偵測到的細胞數")
title("找出計數穩定的平台區"); grid on
yline(19, "r--", LineWidth=1.5, Label="平台值 = 19")
%[text] ## 「找穩定平台」的技巧
%[text] 掃描結果分成三段：
%[text:table]
%[text] | 深度 | 計數 | 狀態 |
%[text] | --- | --- | --- |
%[text] | 1–3 | 41 → 21 | **過度分割**：距離轉換上的微小起伏都變成獨立區域 |
%[text] | **4–8** | **19（不變）** | **平台區** ← 正確答案 |
%[text] | 10–14 | 18 → 17 | **分割不足**：真正的細胞邊界也被抑制掉了 |
%[text:table]
%[text] 平台區的存在有物理意義：在這個範圍內，`imhmin` 已經抑制掉所有
%[text] **雜訊造成的假谷**，但還沒碰到**真實細胞之間的谷**。
%[text] **這個技巧在不知道正確答案時特別有價值**：
%[text] 掃一遍參數，找出結果**不隨參數變動**的那一段。
%[text] 如果掃遍參數都找不到平台，那通常代表**方法本身不適合**——
%[text] 就像第 02 章的顏色門檻，掃遍門檻也找不到正確答案。
[~, plateauIdx] = max(histcounts(counts, unique([counts numel(counts)])));
fprintf("\n平台值 = %d 個細胞\n", mode(counts));
fprintf("建議 imhmin 深度取平台區的中間值：%d\n", depths(find(counts == mode(counts), 1) + 1));

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
