%[text] # 第 10 章　邊緣、直線與圓形偵測
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明各種邊緣算子的差異，並依雜訊水準選擇
%[text] 2. 調校 Canny 的雙門檻，並理解它為什麼比單門檻穩健
%[text] 3. 用霍夫變換偵測直線與圓，並知道它的參數有多敏感
%[text] 4. 使用 R2026a 新增的深度學習圓偵測，並說出它的取捨
%[text] 5. **看出「更新 API」可能悄悄改變你的結果** \
%[text] ## 前置知識
%[text] 第 04 章（濾波與雜訊）、第 06 章（形態學、骨架）。
%[text] ## 環境需求
%[text] 第 7 節需要 **Image Processing Toolbox Model for Circle Detection** 支援包。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="10", Verbose=false);
hasYOLOCircles = exist("imfindcirclesYOLO", "file") == 2;
rng(0);
disp("環境檢查通過。")
%%
%[text] # 1. 邊緣就是梯度
%[text] **邊緣**是影像中亮度快速變化的位置。用數學語言說，就是**梯度大**的地方。
%[text] $\nabla f=\left[\frac{\partial f}{\partial x},\ \frac{\partial f}{\partial y}\right]$
%[text] 所有邊緣算子的原理都一樣：**用一個核去近似微分**（第 04 章的鄰域運算），
%[text] 差別只在核怎麼設計、以及之後怎麼判斷「多大算大」。
I = im2double(imread("circuit.tif"));

[Gmag, Gdir] = imgradient(I);

figure
tiledlayout(2,2)
nexttile; imshow(I);                title("原圖")
nexttile; imshow(Gmag, []);         title("梯度幅值（邊緣強度）")
nexttile; imshow(Gdir, []);         colormap(gca, hsv); colorbar
title("梯度方向（-180° 到 180°）")
nexttile; imshow(Gmag > 0.15);      title("對梯度幅值取門檻")
%[text] 最後一張就是最原始的邊緣偵測：**算梯度、取門檻**。
%[text] 它的問題是邊緣很粗、有斷點、而且門檻很難選——
%[text] 接下來幾節就是在解決這三個問題。
%%
%[text] # 2. 邊緣算子比較
%[text] `edge` 提供多種算子。先看它們在**乾淨影像**上的表現：
methods = ["Sobel" "Prewitt" "Roberts" "log" "Canny"];
cleanEdges = cell(1, numel(methods));

for k = 1:numel(methods)
    cleanEdges{k} = edge(I, methods(k));
end

figure
montage([{I}, cleanEdges], Size=[2 3])
title("原圖 ｜ " + strjoin(methods, " ｜ "))

fprintf("%-10s %12s\n", "算子", "邊緣像素數");
for k = 1:numel(methods)
    fprintf("%-10s %12d\n", methods(k), nnz(cleanEdges{k}));
end
%[text:table]
%[text] | 算子 | 核大小 | 特性 |
%[text] | --- | --- | --- |
%[text] | `Roberts` | 2×2 | 最小、最快，對雜訊**最敏感** |
%[text] | `Prewitt` | 3×3 | 均勻加權 |
%[text] | `Sobel` | 3×3 | 中心列加權較重，**比 Prewitt 稍平滑** |
%[text] | `log` | 可調 | 先高斯平滑再取二階微分，能偵測到細微邊緣 |
%[text] | `Canny` | 可調 | **多階段**：平滑 → 梯度 → 非極大值抑制 → 雙門檻連接 |
%[text:table]
%%
%[text] ## 2.1 有雜訊時差異才顯現
%[text] 乾淨影像上各算子看起來差不多。加入雜訊，高下立判：
Inoisy = imnoise(I, "gaussian", 0, 0.005);
noisyEdges = cell(1, numel(methods));
for k = 1:numel(methods)
    noisyEdges{k} = edge(Inoisy, methods(k));
end

figure
montage([{Inoisy}, noisyEdges], Size=[2 3])
title("有雜訊 ｜ " + strjoin(methods, " ｜ "))

%[text] ## 2.2 一個會騙人的比較方式
%[text] 直接數邊緣像素，會得到違反直覺的結果：
fprintf("\n%-10s %12s %12s %10s\n", "算子", "乾淨（自動門檻）", "雜訊（自動門檻）", "倍數");
for k = 1:numel(methods)
    fprintf("%-10s %12d %12d %9.1fx\n", methods(k), ...
        nnz(cleanEdges{k}), nnz(noisyEdges{k}), ...
        nnz(noisyEdges{k})/max(nnz(cleanEdges{k}),1));
end
%[text] 看起來 `Roberts` 的邊緣**變少了**，好像它最抗雜訊？**完全相反。**
%[text] 問題在於 `edge` 沒有指定門檻時會**依影像自動算一個**。
%[text] 雜訊讓梯度整體變大，自動門檻跟著被拉高：
fprintf("\n%-10s %26s %26s\n", "算子", "乾淨影像的自動門檻", "雜訊影像的自動門檻");
for k = 1:numel(methods)
    [~, tClean] = edge(I, methods(k));
    [~, tNoisy] = edge(Inoisy, methods(k));
    fprintf("%-10s %26s %26s\n", methods(k), ...
        mat2str(round(tClean,4)), mat2str(round(tNoisy,4)));
end
%[text] `Roberts` 的門檻從 0.081 跳到 0.187——**翻了 2.3 倍**。
%[text] 它為了壓住雜訊，把大量**真實的邊緣也一起丟掉了**。
%[text] 邊緣數變少不是因為它抗雜訊，而是因為它**幾乎什麼都不敢留**。
%%
%[text] ## 2.3 用固定門檻做公平比較
%[text] 要比較算子本身的抗雜訊能力，必須**固定門檻**，
%[text] 把「自動門檻的補償」這個變因排除掉：
fprintf("%-10s %12s %12s %10s\n", "算子", "乾淨邊緣", "雜訊邊緣", "增加倍數");
for k = 1:numel(methods)
    [cleanEdge, fixedThresh] = edge(I, methods(k));
    noisyFixed = edge(Inoisy, methods(k), fixedThresh);
    fprintf("%-10s %12d %12d %9.1fx\n", methods(k), ...
        nnz(cleanEdge), nnz(noisyFixed), nnz(noisyFixed)/nnz(cleanEdge));
end
%[text] 現在結果符合理論：
%[text] - **`Roberts` 增加 8.8 倍，最差。** 2×2 的核沒有任何平滑效果，
%[text] 每個雜訊點都被當成邊緣
%[text] - `Sobel`（2.4×）與 `Prewitt`（2.1×）居中，3×3 的核有一點平滑
%[text] - **`log` 與 `Canny` 只增加 1.1–1.2 倍**，因為它們的第一步就是高斯平滑 \
%[text] **這一節的教訓比算子本身重要**：
%[text] **比較兩個方法時，要確認你沒有同時改變別的東西。**
%[text] 自動門檻是個好功能，但它會**適應**輸入——
%[text] 而「會適應」正是做對照實驗時必須控制掉的變因。
%[text] 這和第 03 章「選錯指標」、第 08 章「Dice vs BFscore」是同一類錯誤。
%[text] **實務建議**：預設用 `Canny`。它幾乎總是最穩健的選擇，
%[text] 而且只有兩個直觀的參數。
%%
%[text] # 3. Canny 的雙門檻
%[text] Canny 最聰明的設計是**遲滯門檻**（hysteresis thresholding）：
%[text] 1. 梯度 > **高門檻** 的像素，**確定是邊緣**
%[text] 2. 梯度 < **低門檻** 的像素，**確定不是**
%[text] 3. 介於兩者之間的，**只有當它與確定的邊緣相連時才算** \
%[text] 這解決了單門檻的兩難：門檻低則雜訊多，門檻高則邊緣斷裂。
%[text] 遲滯門檻讓**強邊緣去「拉」它周圍的弱邊緣**。
[autoEdge, autoThresh] = edge(I, "Canny");
fprintf("自動選出的門檻：低 %.4f，高 %.4f（比例 %.2f）\n", ...
    autoThresh(1), autoThresh(2), autoThresh(1)/autoThresh(2));

thresholdSets = {autoThresh, [0.02 0.05], [0.05 0.15], [0.10 0.25]};
cannyResults = cell(1, numel(thresholdSets));
for k = 1:numel(thresholdSets)
    cannyResults{k} = edge(I, "Canny", thresholdSets{k});
end

figure
montage(cannyResults, Size=[2 2])
title("自動 ｜ [0.02 0.05] ｜ [0.05 0.15] ｜ [0.10 0.25]")

fprintf("\n%-18s %12s\n", "門檻", "邊緣像素數");
for k = 1:numel(thresholdSets)
    fprintf("%-18s %12d\n", mat2str(round(thresholdSets{k},3)), nnz(cannyResults{k}));
end
%[text] **只給一個數字時**，`edge(I,"Canny",t)` 會把 `t` 當**高門檻**，
%[text] 自動用 `0.4*t` 當低門檻。
%[text] **調參順序**：先調高門檻讓主要邊緣出現，再調低門檻補斷點。
%%
%[text] # 4. 霍夫變換：從邊緣點到幾何形狀
%[text] 邊緣偵測給的是一堆**孤立的點**。霍夫變換把它們組織成**幾何形狀**。
%[text] 核心想法：把「影像空間中的一個點」對應到「參數空間中的一條曲線」。
%[text] 影像中**共線的點**，在參數空間中的曲線會**交於一點**——
%[text] 找參數空間的峰值，就找到了直線。
%[text] 直線用**極座標**參數化（避免垂直線的斜率無限大）：
%[text] $\rho=x\cos\theta+y\sin\theta$
edgeMap = edge(I, "Canny");
[H, theta, rho] = hough(edgeMap);

figure
imshow(imadjust(mat2gray(H)), XData=theta, YData=rho, InitialMagnification="fit")
axis on, axis normal, hold on
colormap(gca, hot)
xlabel("\theta (度)"); ylabel("\rho (像素)")
title("霍夫參數空間（亮點 = 影像中的直線）")

peaks = houghpeaks(H, 8, Threshold=0.3*max(H(:)));
plot(theta(peaks(:,2)), rho(peaks(:,1)), "cs", MarkerSize=12, LineWidth=2);
hold off

fprintf("找到 %d 個峰值\n", size(peaks,1));
%%
%[text] ## 4.1 把峰值變回直線
lines = houghlines(edgeMap, theta, rho, peaks, FillGap=8, MinLength=30);

figure
imshow(I), hold on
for k = 1:numel(lines)
    xy = [lines(k).point1; lines(k).point2];
    plot(xy(:,1), xy(:,2), LineWidth=2, Color="g")
    plot(xy(1,1), xy(1,2), "yo", MarkerSize=6, LineWidth=2)
    plot(xy(2,1), xy(2,2), "ro", MarkerSize=6, LineWidth=2)
end
hold off
title(sprintf("偵測到 %d 條線段", numel(lines)))

lengths = arrayfun(@(l) norm(l.point2 - l.point1), lines);
fprintf("線段長度：中位 %.1f，範圍 %.1f – %.1f\n", ...
    median(lengths), min(lengths), max(lengths));
%[text:table]
%[text] | 參數 | 作用 | 調太小 | 調太大 |
%[text] | --- | --- | --- | --- |
%[text] | `houghpeaks` 的 `Threshold` | 峰值要多高才算 | 假線段多 | 漏掉真線段 |
%[text] | `houghpeaks` 的 `NHoodSize` | 峰值之間的最小間隔 | 同一條線被重複偵測 | 相鄰的平行線被合併 |
%[text] | `FillGap` | 多大的斷口要接起來 | 一條線被切成好幾段 | 不同線被錯接 |
%[text] | `MinLength` | 短於此的線段丟棄 | 雜訊碎片被當成線 | 真的短線被丟掉 |
%[text:table]
%%
%[text] # 5. 霍夫圓偵測（傳統方法）
%[text] `imfindcircles` 是霍夫變換的圓形版本。它有一個關鍵限制：
%[text] **你必須事先給定半徑範圍**。
coins = imread("coins.png");

[centers, radii] = imfindcircles(coins, [20 30], Sensitivity=0.92);
fprintf("RadiusRange=[20 30]：找到 %d 個圓（正解 10 枚硬幣）\n", numel(radii));
fprintf("半徑範圍 %.1f – %.1f\n", min(radii), max(radii));

figure
imshow(coins), hold on
viscircles(centers, radii, Color="b");
hold off
title(sprintf("imfindcircles 偵測到 %d 個圓", numel(radii)))
%%
%[text] ## 5.1 半徑範圍有多敏感
%[text] 這是傳統圓偵測最大的痛點。掃一遍看看：
radiusRanges = {[10 20], [15 25], [20 30], [25 35], [10 40], [5 50]};

fprintf("%-16s %10s %s\n", "RadiusRange", "找到", "結果");
for k = 1:numel(radiusRanges)
    warnState = warning("off", "images:imfindcircles:warnForSmallRadius");
    [~, r] = imfindcircles(coins, radiusRanges{k}, Sensitivity=0.92);
    warning(warnState);

    verdict = "正確";
    if numel(r) < 10
        verdict = "漏偵測";
    elseif numel(r) > 10
        verdict = "誤偵測";
    end
    fprintf("%-16s %10d %s\n", mat2str(radiusRanges{k}), numel(r), verdict);
end
%[text] 只有 `[20 30]`、`[25 35]`、`[10 40]` 三組給出正確的 10 個。
%[text] 範圍太窄會漏、太寬會誤判——**而你事先根本不知道該給多少**。
%[text] 相較之下，`Sensitivity` 就溫和得多：
fprintf("\n%-16s %10s\n", "Sensitivity", "找到");
for s = [0.80 0.85 0.90 0.92 0.95 0.98]
    [~, r] = imfindcircles(coins, [20 30], Sensitivity=s);
    fprintf("%-16.2f %10d\n", s, numel(r));
end
%[text] 0.85 以上都穩定在 10——這是第 08 章教過的**平台區**。
%[text] **結論**：`Sensitivity` 好調，`RadiusRange` 難調。
%%
%[text] # 6. 傳統方法碰到多尺寸圓
%[text] 真正的麻煩在於**同一張影像中圓的大小不一**時。
%[text] 造一張這樣的影像來測試：
[gx, gy] = meshgrid(1:500, 1:400);
circleSpecs = [ 80  90 15
               200 100 28
               350 110 45
               120 280 22
               280 300 35
               420 290 12];

synthetic = zeros(400, 500, "uint8") + 30;
for k = 1:size(circleSpecs,1)
    inside = (gx - circleSpecs(k,1)).^2 + (gy - circleSpecs(k,2)).^2 < circleSpecs(k,3)^2;
    synthetic(inside) = 200;
end
synthetic = imnoise(synthetic, "gaussian", 0, 0.002);

fprintf("合成影像：6 個圓，半徑 %s\n", mat2str(sort(circleSpecs(:,3))'));

figure
imshow(synthetic)
title("多尺寸圓（半徑 12 到 45）")
%%
%[text] ## 6.1 傳統方法必須分段搜尋
fprintf("\n%-20s %10s\n", "RadiusRange", "找到（正解 6）");
for rr = {[10 25], [25 50], [10 50]}
    [~, r] = imfindcircles(synthetic, rr{1}, Sensitivity=0.92);
    fprintf("%-20s %10d\n", mat2str(rr{1}), numel(r));
end
%[text] 窄範圍各自只抓到一半——`[10 25]` 找到小圓、`[25 50]` 找到大圓。
%[text] 這次寬範圍 `[10 50]` 湊巧全中，但那是運氣：
%[text] **霍夫圓偵測的累加器會隨半徑範圍變寬而變得嘈雜**，
%[text] 範圍一寬，假峰值就跟著變多。
%[text] 實務上的做法是**分段搜尋再合併**——但那需要你知道有哪幾種尺寸。
%%
%[text] # 7. R2026a：深度學習圓偵測
%[text] `imfindcirclesYOLO` 用 YOLOX 物件偵測器找圓。
%[text] 它**不需要半徑範圍**——模型自己知道圓長什麼樣子。
if hasYOLOCircles
    [yoloCenters, yoloRadii, yoloScores] = imfindcirclesYOLO(synthetic);

    fprintf("imfindcirclesYOLO 找到 %d 個圓\n\n", numel(yoloRadii));
    [sortedRadii, order] = sort(yoloRadii);
    fprintf("偵測半徑 %s\n", mat2str(round(sortedRadii', 1)));
    fprintf("真實半徑 %s\n", mat2str(sort(circleSpecs(:,3))'));
    fprintf("信心分數 %s\n", mat2str(round(yoloScores(order)', 3)));

    figure
    imshow(synthetic), hold on
    viscircles(yoloCenters, yoloRadii, Color="g");
    hold off
    title(sprintf("imfindcirclesYOLO：%d 個圓，零參數", numel(yoloRadii)))
else
    disp("未安裝 Image Processing Toolbox Model for Circle Detection，略過本節。")
    disp("實測結果：找到全部 6 個圓，半徑 [11.8 15 21.9 27.9 35 44.9]")
    disp("          真實半徑 [12 15 22 28 35 45]——誤差不到 1 像素")
end
%[text] **半徑估計誤差不到 1 像素，而且完全沒給任何參數。**
%%
%[text] ## 7.1 速度：注意第一次呼叫
if hasYOLOCircles && ~ipcvFast()
    % 第一次呼叫包含模型載入，必須先暖機才能量到真實的每張耗時
    imfindcirclesYOLO(coins);

    n = 3;
    tYolo = tic;
    for k = 1:n, imfindcirclesYOLO(coins); end
    tYolo = toc(tYolo) / n;

    tHough = tic;
    for k = 1:n, imfindcircles(coins, [20 30], Sensitivity=0.92); end
    tHough = toc(tHough) / n;

    fprintf("穩態速度（模型已載入）：\n");
    fprintf("  imfindcirclesYOLO %.3f 秒/張\n", tYolo);
    fprintf("  imfindcircles     %.3f 秒/張\n", tHough);
    fprintf("  倍率              %.1f 倍\n", tYolo/tHough);
else
    disp("（快速模式：略過計時）")
    disp("實測：imfindcirclesYOLO 0.354 秒/張、imfindcircles 0.031 秒/張，約 11.6 倍")
end
%[text] **一個很容易誤導人的陷阱**：第一次呼叫 `imfindcirclesYOLO` 要花
%[text] **25 秒以上**，因為它要載入模型權重。若你用 `tic/toc` 量第一次呼叫，
%[text] 會得到「比傳統方法慢 800 倍」的錯誤結論。
%[text] **暖機之後真正的每張成本落在 0.1–0.35 秒**，約為傳統方法的
%[text] 5 到 12 倍（不同次執行會有波動，但都在一個數量級之內）——
%[text] 這才是拿來做決策的數字。
%[text] 這個「第一次呼叫要暖機」的性質，**所有深度學習函式都有**。
%[text] 量測效能時務必先暖機。
%%
%[text] ## 7.2 兩種骨幹網路
if hasYOLOCircles && ~ipcvFast()
    fprintf("%-14s %10s %10s %14s\n", "Method", "秒數", "找到", "平均信心");
    for m = ["yolox-tiny" "yolox-small"]
        imfindcirclesYOLO(coins, Method=m);                    % 暖機
        t = tic;
        [~, r, s] = imfindcirclesYOLO(coins, Method=m);
        fprintf("%-14s %10.3f %10d %14.3f\n", m, toc(t), numel(r), mean(s));
    end
else
    disp("（略過）實測：yolox-tiny 0.053 秒／信心 0.973，yolox-small 0.181 秒／信心 0.996")
end
%[text] 兩者在這張圖上都找到 10 個圓。`yolox-small` 慢 3 倍，
%[text] 換到的是**較高的信心分數**——在困難影像上這個差距才會轉化為準確度。
%%
%[text] ## 7.3 兩種方法怎麼選
%[text:table]
%[text] | | `imfindcircles`（霍夫） | `imfindcirclesYOLO`（R2026a） |
%[text] | --- | --- | --- |
%[text] | 需要指定半徑 | **是，而且很敏感** | **否** |
%[text] | 多尺寸圓 | 要分段搜尋 | **直接支援** |
%[text] | 速度 | **約 0.02–0.03 秒/張** | 約 0.1–0.35 秒/張（**首次呼叫 25 秒**） |
%[text] | 需要 GPU | 否 | 建議 |
%[text] | 需要支援包 | 否 | **是** |
%[text] | 可解釋 | **完全可解釋** | 黑盒 |
%[text] | 部分遮擋的圓 | 表現不錯（霍夫的強項） | 視訓練資料而定 |
%[text:table]
%[text] **決策準則**：
%[text] - 圓的尺寸**已知且固定**（產線上的同一種零件）→ **霍夫**，快 5–12 倍
%[text] - 尺寸**未知或變化大** → **YOLO**，省下調參數的時間
%[text] - 沒有 GPU 或不能裝支援包 → 霍夫
%[text] - 要向稽核解釋演算法 → 霍夫 \
%[text] 這和第 09 章 SAM 的結論是同一個模式：
%[text] **傳統方法把成本付在開發期，深度學習付在執行期。**
%%
%[text] # 8. 綜合專題：線蟲活性判定
%[text] 這個專題來自原版教材，用**骨架 + 霍夫直線**判斷線蟲是死是活：
%[text] 活的線蟲會蜷曲，骨架化後得到的是**短線段**；
%[text] 死的線蟲伸直，得到**長線段**。比較線段長度的中位數就能分類。
worms = imread("worms.tif");
wormsBinary = createBinaryWorms(worms);

figure
montage({im2uint8(mat2gray(worms)), im2uint8(wormsBinary)})
title("原始線蟲影像 ｜ 分割後的二值影像")

fprintf("分割出 %d 個區域，前景佔 %.1f%%" + "\n", ...
    max(bwlabel(wormsBinary), [], "all"), 100*mean(wormsBinary, "all"));
%%
%[text] ## 8.1 骨架化與長度量測
bw1 = logical(imread("wormsBW1.png"));
bw2 = logical(imread("wormsBW2.png"));

figure
montage({bw1, bw2})
title("樣本 1 ｜ 樣本 2")

[len1, lines1] = ch10_wormLength(bw1);
[len2, lines2] = ch10_wormLength(bw2);

fprintf("樣本 1：偵測 %d 條線段，中位長度 %.1f\n", numel(lines1), len1);
fprintf("樣本 2：偵測 %d 條線段，中位長度 %.1f\n", numel(lines2), len2);
%%
%[text] ## 8.2 一個真實的相容性陷阱
%[text] 原版教材用 `bwmorph(worms,"skel",Inf)` 做骨架化。
%[text] 第 06 章說過，R2026a 建議改用 `bwskel`——它較穩定也支援 3D。
%[text] 那就換掉吧。**但換了之後，結果變了**：
legacyResults = zeros(2,2);
modernResults = zeros(2,2);
samples = {bw1, bw2};

warnState = warning("off", "all");
for k = 1:2
    [legacyResults(k,1), L] = ch10_wormLength(samples{k}, SkeletonMethod="bwmorph");
    legacyResults(k,2) = numel(L);
    [modernResults(k,1), L] = ch10_wormLength(samples{k}, SkeletonMethod="bwskel");
    modernResults(k,2) = numel(L);
end
warning(warnState);

fprintf("%-10s %14s %12s %14s %12s\n", "樣本", "舊版中位長度", "舊版線段數", "新版中位長度", "新版線段數");
for k = 1:2
    fprintf("樣本 %-4d %14.1f %12d %14.1f %12d\n", k, ...
        legacyResults(k,1), legacyResults(k,2), modernResults(k,1), modernResults(k,2));
end

legacyThreshold = 58;    % 原版教材寫死的判斷門檻
fprintf("\n原版教材的判斷門檻：%d\n", legacyThreshold);
fprintf("%-10s %16s %16s\n", "樣本", "舊版判定", "新版判定");
for k = 1:2
    fprintf("樣本 %-4d %16s %16s\n", k, ...
        classifyByLength(legacyResults(k,1), legacyThreshold), ...
        classifyByLength(modernResults(k,1), legacyThreshold));
end
%[text] **樣本 2 的判定反了。**
%[text] 舊版骨架化得到中位長度 46.6（< 58，判為「蜷曲」），
%[text] 新版得到 58.7（> 58，判為「伸直」）——**同一張影像，相反的結論**。
%[text] ## 為什麼會這樣
%[text] `bwskel` 與 `bwmorph(...,"skel",Inf)` 用的是**不同的細化演算法**。
%[text] `bwskel` 產生的骨架分支較少、較平滑，於是霍夫變換偵測到的線段
%[text] 從 13 條掉到 5 條——**樣本變少了，中位數自然跟著跳動**。
%[text] ## 這一節真正的教訓
%[text] **那個門檻 58 不是一個物理常數，它是「舊版骨架化 + 霍夫參數」
%[text] 這整條管線的產物。** 管線裡任何一環變了，門檻就失效。
%[text] 這件事有三個層面的意義：
%[text] 1. **升級 API 不是無痛的**。第 00 章的 `findLegacyAPI` 能告訴你
%[text] 哪裡用了舊函式，但**不能告訴你換掉之後結果會不會變**
%[text] 2. **任何寫死的門檻都應該附帶「它是怎麼得到的」**。
%[text] 沒有這個資訊，後人不知道什麼時候該重新校正
%[text] 3. **改完要重跑驗證**。這正是本課程每章都有 `verifyChapters` 的原因 \
%[text] 正確的做法是：換了骨架化方法後，**用已知答案的樣本重新校正門檻**。
newThreshold = mean(modernResults(:,1));
fprintf("\n依新版結果重新校正的門檻：%.1f\n", newThreshold);
fprintf("%-10s %16s\n", "樣本", "重新校正後");
for k = 1:2
    fprintf("樣本 %-4d %16s\n", k, classifyByLength(modernResults(k,1), newThreshold));
end
%%
%[text] # 9. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 有雜訊時用 `Roberts` | 邊緣圖全是雜點 | 預設用 `Canny`，它會先平滑 |
%[text] | Canny 只給一個門檻卻以為是低門檻 | 結果比預期少很多 | 單一數值是**高門檻**，低門檻自動取 `0.4×` |
%[text] | `imfindcircles` 的半徑範圍靠猜 | 漏偵測或誤偵測 | 先用 `regionprops` 估尺寸，或改用 YOLO 版 |
%[text] | 半徑範圍開很寬想一網打盡 | 累加器變嘈雜，假圓變多 | 分段搜尋再合併 |
%[text] | 用第一次呼叫的時間評估深度學習函式 | 得到「慢 800 倍」的錯誤結論 | **先暖機再計時** |
%[text] | `houghpeaks` 的 `NHoodSize` 太小 | 同一條線被偵測成好幾條 | 加大鄰域，或事後合併 |
%[text] | 更新 API 後沿用舊的門檻 | **結果悄悄變錯** | 換演算法就要**重新校正門檻並重跑驗證** |
%[text:table]
%%
%[text] # 10. 本章小結
%[text] - 所有邊緣算子都是「用核近似微分」，差別在核設計與門檻策略
%[text] - **Canny 的遲滯雙門檻**讓強邊緣去拉弱邊緣，這是它最穩健的原因
%[text] - 霍夫變換把孤立的邊緣點組織成幾何形狀
%[text] - `imfindcircles` 的 **`RadiusRange` 很敏感、`Sensitivity` 有平台區**
%[text] - **`imfindcirclesYOLO`（R2026a）不需要半徑範圍**，
%[text] 多尺寸圓的半徑誤差不到 1 像素，代價是慢 12 倍且需要支援包
%[text] - **量測深度學習函式的速度前一定要暖機**——首次呼叫含模型載入
%[text] - **更新 API 可能悄悄改變結果**。線蟲專題裡，換成 `bwskel` 讓
%[text] 分類結論反轉——因為那個門檻是舊管線的產物 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `edge` | 邊緣偵測 | Sobel／Prewitt／Roberts／log／Canny |
%[text] | `imgradient` `imgradientxy` | 梯度幅值與方向 | |
%[text] | `hough` `houghpeaks` `houghlines` | 霍夫直線 | 四個參數都要調 |
%[text] | `imfindcircles` | 霍夫圓 | **必須給 `RadiusRange`** |
%[text] | **`imfindcirclesYOLO`** | 深度學習圓偵測 | **R2026a 新增**，零參數 |
%[text] | `viscircles` `circles2mask` | 圓的視覺化與轉遮罩 | |
%[text] | `bwskel` | 骨架化 | 取代 `bwmorph(...,"skel",Inf)`，**結果不同** |
%[text:table]
%%
%[text] # 11. 練習
%[text] 開啟 `exercise/Ch10_Exercise.m`，完成五題。解答在 `Ch10_Solution.m`。
%%
%[text] # 12. 延伸閱讀與下一章
%[text] - [Edge Detection](https://www.mathworks.com/help/images/edge-detection.html)
%[text] - [Detect Circular Objects Using YOLOX Detector](https://www.mathworks.com/help/images/ref/imfindcirclesyolo.html)
%[text] - **下一章**：第 11 章　區域分析、物件量測與空間校正——把分割與偵測的結果變成**有單位的數字** \

function label = classifyByLength(medianLength, threshold)
%CLASSIFYBYLENGTH 依中位線段長度判定線蟲狀態。
if medianLength > threshold
    label = "伸直（長線段）";
else
    label = "蜷曲（短線段）";
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
