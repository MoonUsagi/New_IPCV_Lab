%[text] # 第 08 章　傳統影像分割
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：4 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 依影像特性選擇適當的分割策略，而不是每次都用 Otsu
%[text] 2. 說明門檻式、區域式、邊界式三種範式的差異
%[text] 3. 用分水嶺分離黏在一起的物件
%[text] 4. **用量化指標比較分割結果**，而不是靠肉眼
%[text] 5. 判斷分割失敗的原因，並知道下一步該試什麼 \
%[text] ## 前置知識
%[text] 第 01 章（二值化）、第 03 章（直方圖）、第 06 章（形態學清理）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="08", Verbose=false);
rng(0);
disp("環境檢查通過。")
%%
%[text] # 1. 分割要解決什麼問題
%[text] **分割**是把影像切成有意義的區域——「哪些像素屬於同一個東西」。
%[text] 它是所有後續分析的地基：沒有分割，就無法量測、計數、辨識。
%[text] 傳統分割有三種範式，它們回答同一個問題的不同角度：
%[text:table]
%[text] | 範式 | 核心問題 | 代表方法 | 本章節次 |
%[text] | --- | --- | --- | --- |
%[text] | **門檻式** | 這個像素的**值**屬於哪一類？ | Otsu、自適應、ISODATA | 2–4 |
%[text] | **區域式** | 這個像素跟**鄰居**像不像？ | 區域成長、分水嶺、超像素 | 6–8 |
%[text] | **邊界式** | 區域的**邊界**在哪裡？ | 主動輪廓、快速行進法 | 7 |
%[text:table]
%[text] 第 09 章會加上第四種範式：**基礎模型**（SAM），
%[text] 它不問「值」也不問「鄰居」，而是問「這看起來像一個物件嗎」。
%%
%[text] # 2. 全域門檻
%[text] ## 2.1 Otsu 方法
%[text] Otsu 的想法很漂亮：在所有可能的門檻中，找出讓**前景與背景的
%[text] 類別間變異數最大**的那一個。等價於讓兩類內部最「純」。
I = imread("coins.png");

level = graythresh(I);
bwOtsu = imbinarize(I, level);

fprintf("Otsu 門檻（正規化）%.4f，換算 uint8 = %.0f\n", level, level*255);
fprintf("前景佔比 %.1f%%" + "\n", 100*mean(bwOtsu, "all"));

figure
tiledlayout(1,3)
nexttile; imshow(I);      title("原圖")
nexttile
imhist(I); hold on
xline(level*255, "r--", LineWidth=2); hold off
title("直方圖與 Otsu 門檻")
nexttile; imshow(bwOtsu); title("Otsu 二值化")
%[text] `coins.png` 的直方圖是清楚的**雙峰**——這是 Otsu 最理想的情況。
%[text] 兩個峰分別對應背景與硬幣，門檻自然落在谷底。
%%
%[text] ## 2.2 多階門檻
%[text] 影像不一定只有兩類。`multithresh` 把 Otsu 推廣到多個門檻。
gantry = im2gray(imread("gantrycrane.png"));

figure
tiledlayout(2,3)
nexttile; imshow(gantry); title("原圖")
nexttile; imhist(gantry); title("直方圖（多個峰）")

for n = [1 2 3 4]
    thresh = multithresh(gantry, n);
    seg = imquantize(gantry, thresh);
    nexttile
    imshow(label2rgb(seg))
    title(sprintf("%d 個門檻 → %d 類", n, n+1))
end
%[text] 門檻數要怎麼選？**看直方圖有幾個峰**，或者用下一節的 ISODATA
%[text] 讓演算法自己決定。
%%
%[text] # 3. ISODATA：讓演算法決定類別數
%[text] `imsegisodata` 是 **R2024b 新增**的分割函式。
%[text] 它的特點是**自動決定最終的類別數**——你給一個初始值，
%[text] 它會在迭代中依統計特性**分裂**過大的群、**合併**過近的群。
%[text] 這解決了 k-means 最大的痛點：**你必須事先知道 k 是多少**。
[Liso, centers] = imsegisodata(I);

fprintf("預設 InitialNumClusters=5，最終收斂到 %d 群\n", numel(centers));
fprintf("群中心：%s\n\n", mat2str(centers'));

fprintf("%-26s %s\n", "初始群數", "最終群數");
for k = [2 3 5 8 12]
    [~, c] = imsegisodata(I, InitialNumClusters=k);
    fprintf("%-26d %d\n", k, numel(c));
end
%[text] 從 2、3、5 出發都收斂到 **2 群**——這就是 ISODATA 的價值：
%[text] 對初始值不敏感，它會自己找到資料真正的結構。
%[text] 初始值給 8 或 12 時可能停在較多群（受 `MaxIterations` 限制），
%[text] 這時可以調大迭代次數或 `MinClusterSeparation`。
figure
montage({I, label2rgb(Liso), imsegkmeans(I, 2)==2}, Size=[1 3])
title("原圖 ｜ ISODATA（自動 2 群）｜ k-means k=2（人工指定）")
%%
%[text] ## 3.1 ISODATA vs k-means
%[text:table]
%[text] | | `imsegkmeans` | `imsegisodata` |
%[text] | --- | --- | --- |
%[text] | 類別數 | **必須指定** | **自動決定** |
%[text] | 對初始值敏感 | 是（k 錯了結果就錯） | 較不敏感 |
%[text] | 速度 | 快 | 較慢（要迭代分裂合併） |
%[text] | 可控性 | 高 | 用 `MaxStandardDeviation` 等間接控制 |
%[text] | 起始版本 | 舊 | **R2024b** |
%[text:table]
%[text] **實務建議**：已知類別數（例如「良品／不良品」兩類）用 k-means；
%[text] 探索階段、不確定影像有幾種材質時用 ISODATA。
%%
%[text] # 4. 自適應門檻與它的失敗
%[text] 第 03 章與第 06 章都處理過「照明不均」。自適應門檻是第三種解法：
%[text] 為每個像素依**鄰域**亮度計算一個門檻。
rice = imread("rice.png");

figure
montage({rice, imbinarize(rice), imbinarize(rice, "adaptive", Sensitivity=0.45)}, Size=[1 3])
title("rice.png ｜ 全域 Otsu（右下漏掉）｜ 自適應（抓到了）")
%%
%[text] ## 4.1 但自適應門檻不是萬用的
%[text] 換一張影像，同樣的方法會**災難性地失敗**。
cells = imread("AT3_1m4_01.tif");
hands = imread("hands1.jpg");
handsGray = im2gray(hands);

testImages = {"coins.png", I; "rice.png", rice; ...
              "AT3_1m4_01.tif", cells; "hands1.jpg", handsGray};

fprintf("%-18s %12s %12s %14s\n", "影像", "Otsu 前景", "自適應前景", "兩者 Dice");
for k = 1:size(testImages,1)
    X = testImages{k,2};
    o = normalizeForeground(imbinarize(X));
    a = normalizeForeground(imbinarize(X, "adaptive", Sensitivity=0.45));
    fprintf("%-18s %11.1f%% %11.1f%% %14.3f\n", testImages{k,1}, ...
        100*mean(o,"all"), 100*mean(a,"all"), dice(o, a));
end
%[text] `AT3_1m4_01.tif` 上兩種方法的 Dice 只有 **0.2**——幾乎沒有交集。
%[text] **為什麼自適應門檻會失敗**：它的假設是「每個鄰域內都同時有前景與背景」。
%[text] 當某個鄰域**整片都是背景**時，它仍然會硬切出一半當前景——
%[text] 於是平坦區域被切出大量雜訊。
figure
montage({cells, imbinarize(cells), imbinarize(cells,"adaptive",Sensitivity=0.45)}, Size=[1 3])
title("細胞影像 ｜ 全域 Otsu ｜ 自適應（平坦區被切出雜訊）")
%[text] **判斷法則**：
%[text:table]
%[text] | 影像特性 | 用 |
%[text] | --- | --- |
%[text] | 照明均勻、直方圖雙峰 | **全域 Otsu** |
%[text] | 照明不均，但**物件密布全圖** | 自適應門檻 |
%[text] | 照明不均，且**有大片空白區域** | **先校正照明**（第 06 章 top-hat），再全域門檻 |
%[text:table]
%%
%[text] # 5. 用對的特徵：色彩分割
%[text] 前面都在灰階上做。但有些任務的關鍵資訊在**顏色**裡——
%[text] 轉成灰階就等於把答案丟掉了。
%[text] 用一組有**真實標準答案**的影像來證明這件事：
gt = logical(imread("hands1-mask.png"));

figure
montage({hands, gt})
title("hands1.jpg ｜ 標準答案遮罩（人工標註）")

fprintf("標準答案：前景佔 %.1f%%" + "\n", 100*mean(gt, "all"));
%%
%[text] ## 5.1 六種方法的量化比較
hsv = rgb2hsv(hands);
skinMask = hsv(:,:,1) < 0.10 & hsv(:,:,2) > 0.20 & hsv(:,:,3) > 0.20;

candidates = { ...
    "Otsu（灰階）",      imbinarize(handsGray); ...
    "自適應（灰階）",     imbinarize(handsGray, "adaptive", Sensitivity=0.5); ...
    "ISODATA（灰階）",   imsegisodata(handsGray) > 1; ...
    "k-means 灰階 k=2",  imsegkmeans(handsGray, 2) == 2; ...
    "k-means 彩色 k=2",  imsegkmeans(hands, 2) == 2; ...
    "HSV 膚色門檻",      skinMask};

fprintf("%-20s %9s %9s %9s %9s\n", "方法", "Dice", "Jaccard", "BFscore", "前景%");
scores = zeros(size(candidates,1), 3);
masks = cell(size(candidates,1), 1);

for k = 1:size(candidates,1)
    bw = normalizeForeground(candidates{k,2});
    masks{k} = bw;
    scores(k,:) = [dice(bw, gt), jaccard(bw, gt), bfscore(bw, gt)];
    fprintf("%-20s %9.4f %9.4f %9.4f %8.1f%%" + "\n", candidates{k,1}, scores(k,:), ...
        100*mean(bw, "all"));
end

figure
montage([masks; {gt}]', Size=[2 4])
title("六種方法的結果 ＋ 標準答案（右下）")
%%
%[text] ## 5.2 讀懂這張表
%[text] **1. 用對特徵比選對演算法重要。**
%[text] HSV 膚色門檻的 Dice 是 **0.944**，遠勝所有灰階方法（0.87–0.91）。
%[text] 它用的是最簡單的方法（固定門檻），但用在**正確的特徵**（顏色）上。
%[text] **2. 自適應門檻在這裡完全崩潰**（Dice 0.007）。
%[text] 手掌區域大片均勻，正是第 4.1 節說的失敗情境。
%[text] **3. k-means 用彩色反而比灰階差**（0.867 vs 0.899）。
%[text] 因為它把 RGB 三個通道平等看待，背景的顏色變化也被當成有意義的資訊。
%[text] **用顏色**不等於**用對顏色**——HSV 的色相把「膚色」這個概念表達得更精準。
%[text] **4. 最重要的觀察：Dice 最高的方法，BF score 最低。**
[~, bestDice] = max(scores(:,1));
[~, bestBF]   = max(scores(:,3));

fprintf("Dice 最高    ：%s（%.4f），但 BFscore 只有 %.4f\n", ...
    candidates{bestDice,1}, scores(bestDice,1), scores(bestDice,3));
fprintf("BFscore 最高 ：%s（%.4f），Dice 是 %.4f\n", ...
    candidates{bestBF,1}, scores(bestBF,3), scores(bestBF,1));
%[text] 這不是矛盾，是**兩個指標在量不同的東西**：
%[text:table]
%[text] | 指標 | 量什麼 | 對什麼敏感 |
%[text] | --- | --- | --- |
%[text] | **Dice** / **Jaccard** | 區域**重疊**程度 | 面積對不對 |
%[text] | **BF score** | **邊界**的貼合程度 | 輪廓準不準 |
%[text:table]
%[text] HSV 門檻把手掌的**範圍**抓得很準（Dice 高），但邊緣鋸齒、有小孔洞
%[text] （BF score 低）。ISODATA 的範圍稍差，但邊界比較平滑。
%[text] **該用哪個指標，取決於你的下游任務**：
%[text] - 要**計數**或量**面積** → 看 Dice / Jaccard
%[text] - 要量**周長**、做**輪廓比對**、或當**訓練標註** → 看 BF score
%[text] - 論文或報告 → **兩個都報** \
%[text] 這是第 03 章「選錯指標會得到相反結論」的又一個例子。
%%
%[text] # 6. 分水嶺：分開黏在一起的物件
%[text] 門檻式分割有一個根本限制：**它只看像素的值，不看形狀**。
%[text] 兩個物件碰在一起，門檻分割會把它們當成一個。
bwCoins = bwareaopen(imfill(imbinarize(I), "holes"), 100);
fprintf("coins.png 分割後計數：%d 個（實際 10 枚）\n", max(bwlabel(bwCoins), [], "all"));
%[text] 這張圖的硬幣沒有相碰，所以沒問題。人工把它們黏起來製造問題：
bwStuck = imclose(bwCoins, strel("disk", 8));
fprintf("人工黏合後計數：%d 個  <- 錯了\n", max(bwlabel(bwStuck), [], "all"));

figure
montage({bwCoins, bwStuck})
title("原始（10 個獨立）｜ 黏合後（變成 3 塊）")
%%
%[text] ## 6.1 距離轉換 + 分水嶺
%[text] 這是第 06 章練習 2 的正式版。三個步驟：
%[text] 1. **距離轉換**：算每個前景像素離背景多遠。物件中心最遠，交界處較近
%[text] 2. **取負號**：讓中心變成「谷底」，交界變成「山脊」
%[text] 3. **分水嶺**：從每個谷底「灌水」，水線相遇處就是分割線 \
D = -bwdist(~bwStuck);
D(~bwStuck) = Inf;

fprintf("%-16s %s\n", "imhmin 深度", "分割出的物件數");
for h = [0 1 2 4 6]
    if h == 0
        Dx = D;
    else
        Dx = imhmin(D, h);
    end
    L = watershed(Dx);
    L(~bwStuck) = 0;
    fprintf("%-16d %d\n", h, max(L(:)));
end

L = watershed(imhmin(D, 2));
L(~bwStuck) = 0;

figure
tiledlayout(2,2)
nexttile; imshow(bwStuck);          title("黏合的遮罩")
nexttile; imshow(mat2gray(-D));     title("距離轉換（亮＝離背景遠）")
nexttile; imshow(label2rgb(L));     title(sprintf("分水嶺結果：%d 個", max(L(:))))
nexttile
imshow(I); hold on
visboundaries(L > 0, Color="r", LineWidth=0.5); hold off
title("分割線疊回原圖")
%[text] **全部還原成 10 個**，而且對 `imhmin` 的深度不敏感（1 到 6 都對）。
%[text] `imhmin` 的作用是**抑制淺的谷**，避免距離轉換上的微小起伏
%[text] 造成過度分割。沒有它的話，每個小突起都會變成一個獨立區域。
%%
%[text] # 7. 互動式與邊界式分割
%[text] ## 7.1 主動輪廓
%[text] 主動輪廓（active contour，又稱 snake）從一條初始曲線出發，
%[text] 讓它在影像梯度的「牽引」下收縮或擴張，直到貼合物件邊界。
%[text] 它是**邊界式**範式的代表：直接求邊界，不先分類像素。
seedMask = false(size(handsGray));
seedMask(60:180, 100:240) = true;      % 一個粗略的初始框

iterationCounts = [50 200 500];
acResults = cell(1, numel(iterationCounts));
for k = 1:numel(iterationCounts)
    acResults{k} = activecontour(handsGray, seedMask, iterationCounts(k));
end

figure
montage([{seedMask}, acResults], Size=[1 4])
title("初始遮罩 ｜ 50 次迭代 ｜ 200 次 ｜ 500 次")

fprintf("%-12s %9s\n", "迭代次數", "與正解的 Dice");
fprintf("%-12s %9.4f\n", "初始遮罩", dice(seedMask, gt));
for k = 1:numel(iterationCounts)
    fprintf("%-12d %9.4f\n", iterationCounts(k), dice(acResults{k}, gt));
end
%[text] **主動輪廓的關鍵是初始遮罩**。給得太離譜，它會收斂到錯的地方；
%[text] 給得好，它能貼合複雜的輪廓。
%[text] 所以它常和其他方法**搭配**使用：先用門檻得到粗略結果，再用主動輪廓精修。
%%
%[text] ## 7.2 互動式分割（GrabCut / Lazy Snapping）
%[text] 這兩個方法讓使用者**標示少量的前景／背景**，演算法自動補完。
%[text] 它們是第 02 章「APP 探索」精神的延伸，也是第 09 章 SAM 的前身。
foregroundSeeds = false(size(handsGray));
foregroundSeeds(110:130, 150:190) = true;   % 標示「這裡是手」

backgroundSeeds = false(size(handsGray));
backgroundSeeds(10:25, 10:40) = true;       % 標示「這裡是背景」
backgroundSeeds(215:235, 280:315) = true;

spLabels = superpixels(hands, 800);

lsResult = lazysnapping(hands, spLabels, foregroundSeeds, backgroundSeeds);
fprintf("Lazy Snapping  Dice %.4f\n", dice(lsResult, gt));
%[text] 只標了三個小方塊，Dice 就達到 0.97——這是**互動式分割的價值**：
%[text] 用極少的人工輸入換取大幅的品質提升。
%%
%[text] ## 7.3 GrabCut 的 ROI 是硬約束
%[text] `grabcut` 多了一個 `roi` 引數，用來限定搜尋範圍。
%[text] 這個引數有個**容易致命的性質**：**ROI 之外一律視為「確定背景」**，
%[text] 演算法永遠不可能把它們判為前景。
%[text] 換句話說，**ROI 一畫錯，你的最高可能分數就被封頂了**。
%[text] 示範一下。先看正解的範圍有多大：
bbox = regionprops(gt, "BoundingBox");
fprintf("正解的 bounding box：x %.0f–%.0f，y %.0f–%.0f（影像是 %d×%d）\n", ...
    bbox(1).BoundingBox(1), bbox(1).BoundingBox(1) + bbox(1).BoundingBox(3), ...
    bbox(1).BoundingBox(2), bbox(1).BoundingBox(2) + bbox(1).BoundingBox(4), ...
    size(gt,1), size(gt,2));
%[text] 手掌幾乎橫跨整張影像。現在比較三種 ROI：
roiOptions = { ...
    "偏小的 ROI",  makeBox(size(gt), [ 40 200], [ 80 260]); ...
    "貼合正解",    makeBox(size(gt), [  1 240], [  1 240]); ...
    "整張影像",    true(size(gt))};

gcResults = cell(size(roiOptions,1), 1);

fprintf("\n%-14s %16s %12s\n", "ROI", "涵蓋正解比例", "GrabCut Dice");
for k = 1:size(roiOptions,1)
    roi = roiOptions{k,2};
    gcResults{k} = grabcut(hands, spLabels, roi, foregroundSeeds, backgroundSeeds);
    fprintf("%-14s %15.1f%% %12.4f\n", roiOptions{k,1}, ...
        100*nnz(roi & gt)/nnz(gt), dice(gcResults{k}, gt));
end

figure
montage([gcResults; {lsResult}; {gt}]', Size=[2 3])
title("GrabCut：小 ROI ｜ 貼合 ｜ 全圖　　Lazy Snapping ｜ 標準答案")
%[text] **偏小的 ROI 只涵蓋了正解的 63.8%，Dice 就掉到 0.26。**
%[text] 那 36% 被排除在外的手掌像素，無論演算法多聰明都救不回來。
%[text] **這是使用 GrabCut 時最常見的錯誤**，而且它在視覺上很有欺騙性——
%[text] 結果看起來「分割出了某個東西」，只是那個東西不完整。
%[text:table]
%[text] | | `grabcut` | `lazysnapping` |
%[text] | --- | --- | --- |
%[text] | 需要 ROI | **是（硬約束）** | 否 |
%[text] | 本例最佳 Dice | 0.77（全圖 ROI） | **0.97** |
%[text] | 適合 | 物件範圍明確、想限縮運算範圍 | 物件可能散布全圖 |
%[text] | 風險 | **ROI 畫太小就封頂了** | 種子點標得不好會擴散錯誤 |
%[text:table]
%[text] **實務建議**：不確定物件範圍時，寧可把 ROI 開大（或用整張影像），
%[text] 或者直接改用 `lazysnapping`。運算多花的時間，遠比重做一次便宜。
%[text] **互動式分割的 APP 版本**是 Image Segmenter（第 02 章介紹過）。
%[text] R2026a 起它還內建了 SAM 工具，那是第 09 章的主題。
%%
%[text] # 8. 超像素：分割的前處理
%[text] `superpixels` 把影像切成幾百個**顏色與位置都相近**的小區塊。
%[text] 它本身不是分割結果，而是**把像素級問題降維成區塊級問題**——
%[text] 上面的 GrabCut 與 Lazy Snapping 都是在超像素上運作的。
requested = [100 500 2000];
spResults = cell(1, numel(requested));

fprintf("%-14s %s\n", "要求數量", "實得數量");
for k = 1:numel(requested)
    [Lsp, N] = superpixels(hands, requested(k));
    spResults{k} = imoverlay(hands, boundarymask(Lsp), "cyan");
    fprintf("%-14d %d\n", requested(k), N);
end

figure
montage(spResults, Size=[1 3])
title("超像素 100 ｜ 500 ｜ 2000")
%[text] 注意實得數量與要求的**不完全相同**——演算法會為了讓區塊大小均勻
%[text] 而微調。這是正常的，不是 bug。
%[text] **為什麼要用超像素**：一張 240×320 的影像有 76800 個像素，
%[text] 但只有幾百個超像素。在超像素上做圖論最佳化（GrabCut 的核心）
%[text] 快了兩個數量級，而且結果的邊界天然地貼合影像的邊緣。
%%
%[text] # 9. 紋理分割
%[text] 有些區域的**亮度與顏色都相同**，只有**紋理**不同。
%[text] 這時要先把紋理轉換成可以門檻化的「特徵影像」。
%[text] 第 04 章的三個局部統計濾波器正是為此而生。
%[text] **注意 `im2gray`**：`tissue.png` 是彩色影像。
%[text] `entropyfilt` 等函式會對三個通道各自計算，得到 3D 結果——
%[text] 之後 `imbinarize` 也會回傳 3D 邏輯陣列，`imshow` 就會報錯
%[text] （「If input is logical, it must be two-dimensional」）。
%[text] 紋理是**亮度的空間變化**，本來就該在灰階上算。
texture = im2double(im2gray(imread("tissue.png")));
texture = imresize(texture, 0.5);

features = { ...
    "局部熵",     entropyfilt(texture, true(9)); ...
    "局部標準差", stdfilt(texture, ones(9)); ...
    "局部範圍",   rangefilt(texture, ones(9))};

figure
tiledlayout(2,4)
nexttile; imshow(texture); title("原圖")
for k = 1:3
    nexttile; imshow(mat2gray(features{k,2})); title(features{k,1})
end
nexttile; imshow(imbinarize(texture)); title("直接對原圖門檻化")
for k = 1:3
    nexttile
    imshow(imbinarize(rescale(features{k,2})))
    title(features{k,1} + " → 門檻化")
end
%[text] 直接對原圖門檻化得到的是「亮暗」的分界，
%[text] 對紋理特徵門檻化得到的才是「粗細」的分界——**完全不同的東西**。
%[text] 紋理特徵的鄰域大小（上面用 9×9）要**與紋理的尺度相符**：
%[text] 太小抓不到紋理的重複性，太大會把不同區域混在一起。
%%
%[text] # 10. 分割方法決策指南
%[text:table]
%[text] | 影像特性 | 首選方法 | 備註 |
%[text] | --- | --- | --- |
%[text] | 直方圖雙峰、照明均勻 | `imbinarize`（Otsu） | 最簡單，優先嘗試 |
%[text] | 多種材質、不知道幾類 | **`imsegisodata`** | R2024b 新增，自動決定類別數 |
%[text] | 已知類別數 | `imsegkmeans` | 比 ISODATA 快 |
%[text] | 照明不均、物件密布 | 自適應門檻 | **有大片空白區時會失敗** |
%[text] | 照明不均、有空白區 | 先 top-hat（第 06 章）再全域門檻 | 最穩健 |
%[text] | 關鍵資訊在顏色 | HSV／Lab 門檻 或 Color Thresholder | **用對特徵比選對演算法重要** |
%[text] | 物件黏在一起 | 距離轉換 + `imhmin` + `watershed` | 記得抑制淺谷 |
%[text] | 只有紋理不同 | `entropyfilt`／`stdfilt` 再門檻化 | 鄰域大小要配合紋理尺度 |
%[text] | 邊界要很精準 | `activecontour` | 需要好的初始遮罩 |
%[text] | 可以接受少量人工標示 | `grabcut`／`lazysnapping` | 極少輸入換取大幅品質提升 |
%[text] | 物件種類多且不規則 | **SAM 2**（第 09 章） | 零樣本，不需調參數 |
%[text:table]
%%
%[text] # 11. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 什麼影像都用 Otsu | 照明不均時右下角整片漏掉 | 先看直方圖是不是雙峰 |
%[text] | 濫用自適應門檻 | 平坦區域被切出大量雜訊 | 有大片空白區時改用 top-hat + 全域門檻 |
%[text] | 把彩色影像轉灰階再分割 | 把答案丟掉了 | 關鍵在顏色時用 HSV／Lab |
%[text] | 以為「用顏色」就好 | k-means 彩色反而比灰階差 | 要用**對的**顏色表示法 |
%[text] | 分水嶺不做 `imhmin` | 嚴重過度分割 | 一定要抑制淺谷 |
%[text] | 只看一個指標 | Dice 與 BF score 可能排名相反 | 依下游任務選指標，報告時兩個都給 |
%[text] | 只用肉眼判斷分割好壞 | 無法交付、無法比較 | 有標準答案就算 Dice／Jaccard／BFscore |
%[text] | 紋理特徵的鄰域隨便設 | 抓不到紋理或把區域混在一起 | 鄰域大小要與紋理尺度相符 |
%[text] | **GrabCut 的 ROI 畫太小** | 結果看起來有分割到東西，但物件不完整 | ROI 外是**確定背景**，永遠救不回來。寧可開大，或改用 `lazysnapping` |
%[text] | 忘記把彩色影像轉灰階就算紋理特徵 | `imshow` 報錯「must be two-dimensional」 | 紋理是亮度的空間變化，先 `im2gray` |
%[text:table]
%%
%[text] # 12. 本章小結
%[text] - 分割有三種範式：看**值**（門檻）、看**鄰居**（區域）、看**邊界**
%[text] - `imsegisodata`（R2024b）**自動決定類別數**，解決 k-means 要指定 k 的痛點
%[text] - 自適應門檻的假設是「每個鄰域都有前景與背景」，**有空白區時會崩潰**
%[text] - **用對特徵比選對演算法重要**：HSV 膚色門檻（最簡單的方法）
%[text] 在正確的特徵上勝過所有灰階方法
%[text] - **Dice 與 BF score 可能給出相反的排名**——一個量面積、一個量邊界
%[text] - 物件黏在一起就用距離轉換 + 分水嶺，記得 `imhmin`
%[text] - **GrabCut 的 `roi` 是硬約束**。實測：ROI 只涵蓋正解 63.8% 時
%[text] Dice 從 0.77 掉到 0.26——被封頂的分數，演算法再聰明也拿不回來 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `imbinarize` `graythresh` `otsuthresh` | 全域／自適應門檻 | `"adaptive"` 是位置引數 |
%[text] | `multithresh` `imquantize` | 多階門檻 | |
%[text] | **`imsegisodata`** | ISODATA 分割 | **R2024b 新增**，自動決定類別數 |
%[text] | `imsegkmeans` | k-means 分割 | 必須指定 k |
%[text] | `bwdist` `imhmin` `watershed` | 分水嶺三部曲 | 缺 `imhmin` 會過度分割 |
%[text] | `activecontour` | 主動輪廓 | 需要初始遮罩 |
%[text] | `grabcut` `lazysnapping` | 互動式分割 | 在超像素上運作 |
%[text] | `superpixels` `boundarymask` | 超像素 | 降維成區塊級問題 |
%[text] | `imsegfmm` `gradientweight` | 快速行進法 | 邊界式 |
%[text] | `entropyfilt` `stdfilt` `rangefilt` | 紋理特徵 | 鄰域配合紋理尺度 |
%[text] | `dice` `jaccard` `bfscore` | 分割品質指標 | **量不同的東西** |
%[text] | `label2rgb` `visboundaries` `imoverlay` | 結果視覺化 | |
%[text:table]
%%
%[text] # 13. 練習
%[text] 開啟 `exercise/Ch08_Exercise.m`，完成五題。解答在 `Ch08_Solution.m`。
%%
%[text] # 14. 延伸閱讀與下一章
%[text] - [Image Segmentation](https://www.mathworks.com/help/images/image-segmentation.html)
%[text] - [Marker-Controlled Watershed Segmentation](https://www.mathworks.com/help/images/marker-controlled-watershed-segmentation.html)
%[text] - **下一章**：第 09 章　基礎模型分割（SAM 與 SAM 2）——本章所有方法都需要你先想清楚「用什麼特徵、調什麼門檻」。下一章的方法**什麼都不用調** \

function roi = makeBox(sz, rowRange, colRange)
%MAKEBOX 產生一個矩形遮罩，範圍會自動夾在影像邊界內。
roi = false(sz);
r = max(1, rowRange(1)) : min(sz(1), rowRange(2));
c = max(1, colRange(1)) : min(sz(2), colRange(2));
roi(r, c) = true;
end

function bw = normalizeForeground(bw)
%NORMALIZEFOREGROUND 讓前景成為少數派，方便與標準答案比較。
%   分割函式對「哪一類是前景」沒有共識，比較之前要統一。
if ~islogical(bw)
    bw = logical(bw);
end
if mean(bw, "all") > 0.5
    bw = ~bw;
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
