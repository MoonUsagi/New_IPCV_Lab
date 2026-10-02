%[text] # 第 09 章　基礎模型分割：SAM 與 SAM 2
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明「提示式分割」與前一章所有方法的根本差異
%[text] 2. 用 SAM 2 做全自動分割與點／框提示分割
%[text] 3. 理解 embeddings 的架構，並知道它為什麼讓互動式分割變得可行
%[text] 4. 依情境選擇模型變體，在速度與品質之間取捨
%[text] 5. **判斷什麼時候該用 SAM、什麼時候傳統方法更好** \
%[text] ## 前置知識
%[text] 第 08 章（傳統分割與評估指標）。本章是它的對照組。
%[text] ## 環境需求
%[text] 本章需要 **Image Processing Toolbox Model for Segment Anything Model 2**
%[text] 支援包與 Deep Learning Toolbox。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="09", Verbose=false);

hasSAM = exist("imsegsam", "file") == 2;
if ~hasSAM
    warning("ch09:noSAM", ...
        "找不到 imsegsam。請從附加功能安裝 " + ...
        "「Image Processing Toolbox Model for Segment Anything Model 2」。" + ...
        "本章的程式碼仍可閱讀，但無法執行。");
end
%[text] ## 執行時間的預期
%[text] SAM 是大型深度學習模型，**很慢**。本教材在 NVIDIA T550 Laptop GPU
%[text] （3.5 GB 可用）上的實測：全自動分割一張 196×259 的小圖，
%[text] 預設的 `sam2-large` 要 **110 秒**。
%[text] 因此本章：
%[text] - 示範影像一律縮小
%[text] - 全自動分割用較小的模型變體
%[text] - 耗時的段落會在快速模式下跳過（顯示實測結果） \
disp("環境檢查完成。")
%%
%[text] # 1. 第四種範式
%[text] 第 08 章的所有方法都要你先回答一個問題：**「要用什麼特徵？」**
%[text] - 門檻式：用亮度？用色相？門檻設多少？
%[text] - 區域式：相似度怎麼定義？
%[text] - 邊界式：初始輪廓畫在哪？ \
%[text] SAM（Segment Anything Model）不問這些。它問的是：
%[text] **「這看起來像一個獨立的物件嗎？」**
%[text] 這個「物件性」（objectness）的概念是從**上千萬張標註影像**學來的，
%[text] 不需要你為每張影像重新定義。
%[text:table]
%[text] | | 傳統方法（第 08 章） | SAM（本章） |
%[text] | --- | --- | --- |
%[text] | 你要提供 | 特徵選擇 + 參數 | **一個點，或什麼都不用** |
%[text] | 換一張影像 | 通常要重調參數 | 通常直接可用 |
%[text] | 速度 | 毫秒級 | **秒到分鐘級** |
%[text] | 可解釋 | 完全可解釋 | 黑盒 |
%[text] | 硬體 | CPU 即可 | 建議 GPU |
%[text] | 失敗模式 | 可預測、可診斷 | 難以預測 |
%[text:table]
%[text] **這不是「新的取代舊的」**。它們的成本結構完全不同，
%[text] 適用的場合也不同——第 7 節會給出決策準則。
%%
%[text] # 2. R2026a 的重要變更：預設模型改了
%[text] R2026a 起，`segmentAnythingModel` 與 `imsegsam` 的**預設模型
%[text] 從 SAM 1 改成 `"sam2-large"`**。
%[text] 這代表兩件事：
%[text] 1. 舊程式碼的**行為會改變**（結果不同、速度不同）
%[text] 2. 需要安裝 **SAM 2 支援包**，只裝舊的 SAM 支援包會失敗 \
if hasSAM
    model = segmentAnythingModel;      % 不給引數 = 用預設
    fprintf("預設模型：%s\n", model.ModelName);
end
%[text] 可用的變體（**注意是位置引數，不是名稱-值對**）：
%[text:table]
%[text] | 變體 | 說明 |
%[text] | --- | --- |
%[text] | `"sam2-large"` | R2026a 預設，品質最好、最慢 |
%[text] | `"sam2-baseplus"` | 中等 |
%[text] | `"sam2-small"` | 較快 |
%[text] | `"sam2-tiny"` | 最快 |
%[text] | `"sam-base"` | 初代 SAM，相容舊程式用 |
%[text:table]
%[text] 建立方式：`segmentAnythingModel("sam2-tiny")`。
%[text] 寫成 `segmentAnythingModel(ModelName="sam2-tiny")` 會報
%[text] 「Too many input arguments」。
%%
%[text] # 3. 全自動分割
%[text] `imsegsam` 在影像上灑一個點陣列，對每個點都問一次
%[text] 「這裡有物件嗎」，再把重複的結果合併。完全不需要參數。
I = imresize(imread("coloredChips.png"), 0.5);
fprintf("示範影像尺寸：%s\n", mat2str(size(I)));

figure
imshow(I)
title("待分割影像")
%%
%[text] ## 3.1 執行全自動分割
if hasSAM && ~ipcvFast()
    t0 = tic;
    [masks, scores] = imsegsam(I, ModelName="sam2-tiny", Verbose=false);
    elapsed = toc(t0);

    fprintf("sam2-tiny 耗時 %.1f 秒，切出 %d 個區域\n", elapsed, masks.NumObjects);
    fprintf("信心分數範圍 %.3f – %.3f\n", min(scores), max(scores));

    L = labelmatrix(masks);

    figure
    montage({I, label2rgb(L, "jet", "k", "shuffle")}, Size=[1 2])
    title(sprintf("原圖 ｜ SAM 2 全自動分割（%d 個區域）", masks.NumObjects))
else
    disp("（快速模式或未安裝 SAM：略過全自動分割）")
    disp("實測結果：sam2-tiny 30.0 秒，切出 28 個區域")
end
%[text] **注意 `imsegsam` 的輸出型別**：它回傳的是一個
%[text] **`bwconncomp` 格式的 struct**（欄位為 `Connectivity`、`ImageSize`、
%[text] `NumObjects`、`PixelIdxList`），不是標籤矩陣。
%[text] 要得到標籤矩陣請用 `labelmatrix(masks)`。
%%
%[text] ## 3.2 模型變體的取捨
%[text] 同一張影像、同一組參數，五個變體的實測結果
%[text] （NVIDIA T550 Laptop GPU，權重已快取）：
%[text:table]
%[text] | 變體 | 耗時 | 找到的區域數 |
%[text] | --- | --- | --- |
%[text] | `sam2-tiny` | **30.0 秒** | 28 |
%[text] | `sam2-small` | 34.6 秒 | 28 |
%[text] | `sam2-baseplus` | 59.6 秒 | 28 |
%[text] | `sam2-large`（預設） | **110.8 秒** | 31 |
%[text] | `sam-base`（初代 SAM） | 59.8 秒 | 36 |
%[text:table]
%[text] **三個值得注意的地方**：
%[text] 1. **預設的 `sam2-large` 比 `sam2-tiny` 慢 3.7 倍，
%[text] 但只多找到 3 個區域**。教學、探索、原型階段用 tiny 就好
%[text] 2. tiny／small／baseplus 在這張圖上找到**完全相同**的 28 個區域——
%[text] 模型大小的差異要在**困難影像**上才看得出來
%[text] 3. 初代 `sam-base` 找到 36 個，**比 SAM 2 多**——但那不是「更好」，
%[text] 而是**切得更碎**（把一個物件拆成多塊）。數量多不等於品質好 \
%[text] **實務建議**：先用 `sam2-tiny` 確認流程可行，最後再換大模型跑正式結果。
%%
%[text] # 4. 提示式分割：SAM 真正的價值
%[text] 全自動分割會把影像裡**所有東西**都切出來，包含你不要的。
%[text] **提示式分割**讓你指定要哪一個——這才是 SAM 最常用的模式。
%[text] ## 4.1 架構：embeddings 算一次，提示可以無限次
%[text] SAM 分成兩半：
%[text] 1. **編碼器**（encoder）：把影像轉成 embeddings。**慢，但只需算一次**
%[text] 2. **解碼器**（decoder）：吃 embeddings ＋ 提示，輸出遮罩。**很快** \
%[text] 這個切分正是互動式分割可行的原因：使用者在畫面上點來點去時，
%[text] 每一次點擊只需要跑解碼器。
if hasSAM
    samModel = segmentAnythingModel("sam2-small");

    t1 = tic;
    embeddings = extractEmbeddings(samModel, I);
    tEmbeddings = toc(t1);

    fprintf("extractEmbeddings 耗時 %.2f 秒（輸出類別 %s）\n", ...
        tEmbeddings, class(embeddings));
end
%%
%[text] ## 4.2 點提示
%[text] `ForegroundPoints` 是 **P×2 的 [x y] 座標**——注意是 **x 在前**，
%[text] 與 MATLAB 慣用的 [列 行] 相反。座標超出影像範圍會報
%[text] `images:sam:insufficientPrompts`，錯誤訊息不會告訴你是座標的問題。
if hasSAM
    [h, w, ~] = size(I);
    fprintf("影像 高 %d、寬 %d → 有效範圍 x ≤ %d，y ≤ %d\n\n", h, w, w, h);

    prompts = [148  88;    % 落在一個圓片上
               230 100;    % 落在背景上
                90 130];   % 落在背景上

    promptMasks = cell(size(prompts,1), 1);

    fprintf("%-14s %10s %12s %10s\n", "點 [x y]", "秒數", "遮罩像素", "信心分數");
    for k = 1:size(prompts,1)
        tk = tic;
        [promptMasks{k}, score] = segmentObjectsFromEmbeddings( ...
            samModel, embeddings, size(I), ForegroundPoints=prompts(k,:));
        fprintf("%-14s %10.3f %12d %10.4f\n", mat2str(prompts(k,:)), toc(tk), ...
            nnz(promptMasks{k}), score);
    end

    figure
    tiledlayout(1, 4)
    nexttile
    imshow(I); hold on
    plot(prompts(:,1), prompts(:,2), "r*", MarkerSize=12, LineWidth=2); hold off
    title("提示點位置")
    for k = 1:3
        nexttile; imshow(promptMasks{k}); title(sprintf("點 %d", k))
    end
end
%[text] **看遮罩像素數就知道 SAM 理解了什麼**：
%[text] 第一個點落在圓片上，回傳約 420 像素——**一個圓片**。
%[text] 後兩個點落在背景上，回傳約 38000 像素（佔全圖 75%）——**整片背景**。
%[text] SAM 沒有做錯，它忠實地回答了「你點的那個東西是什麼」。
%[text] **這就是提示式分割的特性**：它不知道你的意圖，只知道你指的位置。
%[text] 指錯地方，它會很有信心地給你錯的答案（注意背景那兩個點的信心分數
%[text] 反而**更高**，0.98–0.99）。
%[text] **信心分數高不代表結果是你要的。**
%%
%[text] ## 4.3 框提示
%[text] 框提示通常比點提示更明確——它同時給了位置與大致範圍。
if hasSAM
    boxPrompt = [130 70 40 40];      % [x y 寬 高]

    tBox = tic;
    [boxMask, boxScore] = segmentObjectsFromEmbeddings( ...
        samModel, embeddings, size(I), BoundingBox=boxPrompt);

    fprintf("框提示耗時 %.3f 秒，遮罩 %d 像素，信心 %.4f\n", ...
        toc(tBox), nnz(boxMask), boxScore);

    figure
    tiledlayout(1,2)
    nexttile
    imshow(I); hold on
    rectangle(Position=boxPrompt, EdgeColor="r", LineWidth=2); hold off
    title("框提示")
    nexttile; imshow(labeloverlay(I, boxMask)); title("分割結果")
end
%%
%[text] ## 4.4 用背景點修正結果
%[text] 分割結果不滿意時，可以加上 `BackgroundPoints` 告訴 SAM
%[text] 「這裡**不是**我要的」。這就是互動式修正的基礎。
if hasSAM
    [maskBefore, scoreBefore] = segmentObjectsFromEmbeddings( ...
        samModel, embeddings, size(I), ForegroundPoints=[148 88]);

    [maskAfter, scoreAfter] = segmentObjectsFromEmbeddings( ...
        samModel, embeddings, size(I), ...
        ForegroundPoints=[148 88], BackgroundPoints=[100 60; 200 150]);

    fprintf("只給前景點     遮罩 %d 像素，信心 %.4f\n", nnz(maskBefore), scoreBefore);
    fprintf("加上背景點     遮罩 %d 像素，信心 %.4f\n", nnz(maskAfter), scoreAfter);

    figure
    montage({labeloverlay(I, maskBefore), labeloverlay(I, maskAfter)})
    title("只給前景點 ｜ 加上背景點")
end
%%
%[text] ## 4.5 多重遮罩：讓 SAM 給你選項
%[text] 一個點是有歧義的——你點在車輪上，是要車輪、還是整台車？
%[text] `ReturnMultiMask=true` 會回傳**三個不同層級**的遮罩讓你挑。
if hasSAM
    [multiMasks, multiScores] = segmentObjectsFromEmbeddings( ...
        samModel, embeddings, size(I), ...
        ForegroundPoints=[148 88], ReturnMultiMask=true);

    fprintf("回傳 %d 個遮罩，尺寸 %s\n", size(multiMasks,3), mat2str(size(multiMasks)));
    for k = 1:size(multiMasks,3)
        fprintf("  遮罩 %d：%6d 像素，信心 %.4f\n", k, nnz(multiMasks(:,:,k)), multiScores(k));
    end

    [~, bestIdx] = max(multiScores);
    fprintf("  分數最高的是第 %d 個（%.4f）\n", bestIdx, multiScores(bestIdx));

    figure
    montage({multiMasks(:,:,1), multiMasks(:,:,2), multiMasks(:,:,3)}, Size=[1 3])
    title("三個候選遮罩（代表三種層級，順序不固定）")
end
%[text] 三個候選代表三種**層級的解讀**：這個物件、物件的一部分、
%[text] 物件所在的整片區域。
%[text] **注意：它們的順序不保證依分數排列。** 不同的提示點會得到不同的順序，
%[text] 所以**不要假設第一個就是最好的**——要用 `max(scores)` 挑。
%[text] **這是處理歧義的正確方式**：與其猜使用者要什麼，
%[text] 不如把選項攤開來讓他選。Image Segmenter 的 SAM 工具就是這樣運作的。
%%
%[text] # 5. embeddings 共用能省多少時間
%[text] 這是本章的架構重點。量化它：
if hasSAM && ~ipcvFast()
    testPoints = [148 88; 230 100; 90 130; 120 60];

    tShared = tic;
    for k = 1:size(testPoints,1)
        segmentObjectsFromEmbeddings(samModel, embeddings, size(I), ...
            ForegroundPoints=testPoints(k,:));
    end
    sharedPromptTime = toc(tShared);

    totalShared = tEmbeddings + sharedPromptTime;
    totalNaive  = 4 * tEmbeddings + sharedPromptTime;

    fprintf("extractEmbeddings（一次）      %.2f 秒\n", tEmbeddings);
    fprintf("4 次提示                       %.2f 秒（平均每次 %.3f 秒）\n", ...
        sharedPromptTime, sharedPromptTime/4);
    fprintf("─────────────────────────────────────\n");
    fprintf("共用 embeddings 總計            %.2f 秒\n", totalShared);
    fprintf("每次都重算 embeddings 要        %.2f 秒（慢 %.1f 倍）\n", ...
        totalNaive, totalNaive/totalShared);
else
    disp("（快速模式：略過計時。實測 embeddings 5.54 秒、每次提示 0.296 秒，")
    disp("  共用比重算快 3.5 倍）")
end
%[text] **設計上的啟示**：任何要做多次分割的流程，
%[text] 都應該**先 `extractEmbeddings` 再重複呼叫 `segmentObjectsFromEmbeddings`**。
%[text] 用 `imsegsam` 或反覆建立模型物件，會浪費大量時間在重算同樣的東西。
%%
%[text] # 6. 與傳統方法的正面比較
%[text] 用第 08 章那組有標準答案的影像，讓 SAM 與傳統方法直接對決。
hands = imread("hands1.jpg");
handsGT = logical(imread("hands1-mask.png"));
handsGray = im2gray(hands);
hsvHands = rgb2hsv(hands);

classicalResults = { ...
    "Otsu（灰階）",    imbinarize(handsGray); ...
    "ISODATA（灰階）", imsegisodata(handsGray) > 1; ...
    "HSV 膚色門檻",    hsvHands(:,:,1) < 0.10 & hsvHands(:,:,2) > 0.20 & hsvHands(:,:,3) > 0.20};

if hasSAM
    handsSmall = imresize(hands, 0.7);
    samHands = segmentAnythingModel("sam2-small");
    handsEmb = extractEmbeddings(samHands, handsSmall);

    % 在手掌中央給一個提示點
    gtProps = regionprops(handsGT, "Centroid");
    centroidFull = gtProps(1).Centroid;
    centroidSmall = round(centroidFull * 0.7);

    samMaskSmall = segmentObjectsFromEmbeddings(samHands, handsEmb, size(handsSmall), ...
        ForegroundPoints=centroidSmall);
    samMask = imresize(samMaskSmall, size(handsGT), "nearest");

    classicalResults(end+1,:) = {"SAM 2（一個點）", samMask};
end

[results, agree] = ch08_evaluateSegmentation(classicalResults, handsGT);
%%
%[text] ## 6.1 讀懂這個比較
%[text] SAM 用**一個點**就在三個指標上全部奪冠。
%[text] 而它擊敗的 HSV 門檻，是第 08 章花了整整一節、試了六種方法才找出來的。
%[text] **但最值得注意的不是 Dice，是 BF score**：
%[text:table]
%[text] | 方法 | Dice | BFscore |
%[text] | --- | --- | --- |
%[text] | **SAM 2（一個點）** | **0.9731** | **0.9988** |
%[text] | HSV 膚色門檻 | 0.9441 | 0.7383 |
%[text] | ISODATA（灰階） | 0.9050 | 0.7716 |
%[text:table]
%[text] Dice 的差距只有 3 個百分點，**BF score 的差距卻高達 26 個百分點**。
%[text] 回想第 08 章：BF score 量的是**邊界貼合程度**。
%[text] 這告訴我們 SAM 真正的優勢在哪裡——
%[text] 傳統門檻法能大致框對**範圍**，但邊界總是鋸齒、有破洞、被雜訊影響；
%[text] SAM 產生的是**乾淨、連續、貼合真實輪廓**的邊界。
%[text] 這也解釋了為什麼 SAM 在**資料標註**上特別有價值（第 17 章）：
%[text] 標註品質的關鍵就是邊界精準度。
%[text] **不過這個比較對兩邊都不完全公平**：
%[text:table]
%[text] | | 傳統方法 | SAM |
%[text] | --- | --- | --- |
%[text] | 開發成本 | 高——要試特徵、調參數 | **極低——點一下** |
%[text] | 執行成本 | **毫秒** | 秒級，且要 GPU |
%[text] | 換影像 | 常要重調 | 通常直接可用 |
%[text] | 換**同一批**影像 | 調好一次就一勞永逸 | **每張都要付一次執行成本** |
%[text:table]
%[text] 這就是關鍵：**傳統方法把成本付在開發期，SAM 把成本付在執行期**。
%[text] 產線上每天要處理十萬張影像時，一次調參數的成本會被攤平到近乎零，
%[text] 而 SAM 的執行成本會乘以十萬倍。
%%
%[text] # 7. 什麼時候該用 SAM
%[text:table]
%[text] | 情境 | 建議 | 理由 |
%[text] | --- | --- | --- |
%[text] | **資料標註** | **SAM** | 最大的應用場景。人工點一下取代逐像素描邊，第 17 章詳述 |
%[text] | 探索階段、不知道該用什麼方法 | SAM | 先看看影像裡「有哪些東西」 |
%[text] | 物件種類多、形狀不規則 | SAM | 傳統方法要為每一類調一套參數 |
%[text] | 一次性分析、影像不多 | SAM | 省下調參數的時間 |
%[text] | **產線即時檢測** | **傳統方法** | 毫秒 vs 秒，差距三個數量級 |
%[text] | **物件特徵明確且固定**（顏色／亮度） | **傳統方法** | 更快、更可解釋、不需 GPU |
%[text] | 需要向稽核說明演算法原理 | 傳統方法 | SAM 是黑盒 |
%[text] | 沒有 GPU | 傳統方法 | SAM 在 CPU 上慢到不可用 |
%[text] | 要精確的邊界 | 看情況 | 兩者都可能需要後處理 |
%[text:table]
%[text] **最務實的組合**：用 SAM 做**標註**，用標註訓練一個小模型或調出傳統
%[text] 參數，在產線上跑快的那一個。這正是第 17 章到第 22 章的主線。
%%
%[text] # 8. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | `segmentAnythingModel(ModelName="...")` | Too many input arguments | 是**位置引數**：`segmentAnythingModel("sam2-tiny")` |
%[text] | 以為 `imsegsam` 回傳標籤矩陣 | `max(L(:))` 報「invalid data type」 | 回傳 `bwconncomp` struct，用 `labelmatrix()` 轉換 |
%[text] | `ForegroundPoints` 給 [列 行] | `insufficientPrompts` 錯誤 | 是 **[x y]**，x 是行、y 是列 |
%[text] | 提示點超出影像範圍 | 同上，訊息不會提到座標 | 先檢查 x ≤ 寬、y ≤ 高 |
%[text] | 每次分割都重建模型／重算 embeddings | 慢 3.5 倍以上 | embeddings 算一次，重複用 |
%[text] | 用預設 `sam2-large` 做開發 | 每次等 110 秒 | 開發用 `sam2-tiny`，最後才換大模型 |
%[text] | 以為信心分數高就是對的 | 背景的信心分數常比物件還高 | 信心分數只反映「這是不是一個完整的東西」 |
%[text] | 只裝舊的 SAM 支援包 | R2026a 預設要 SAM 2 | 裝 **Model for Segment Anything Model 2** |
%[text] | 把 SAM 放進即時產線 | 秒級延遲 | 用 SAM 標註，用快的模型上線 |
%[text:table]
%%
%[text] # 9. 本章小結
%[text] - SAM 是**第四種分割範式**：不問特徵，問「這像不像一個物件」
%[text] - R2026a 的預設模型改為 `sam2-large`，**舊程式行為會變**
%[text] - 架構是 **encoder（慢，算一次）＋ decoder（快，可無限次）**，
%[text] 這是互動式分割可行的原因
%[text] - **`sam2-large` 比 `sam2-tiny` 慢 3.7 倍，只多找到 3 個區域**——
%[text] 開發階段用小模型
%[text] - **信心分數高不代表是你要的東西**——背景的分數常常更高
%[text] - SAM 最大的優勢在**邊界品質**：對同一組影像，Dice 只贏 3 個百分點，
%[text] **BF score 卻贏了 26 個百分點**。這正是它適合做標註的原因
%[text] - 傳統方法把成本付在**開發期**，SAM 付在**執行期**。
%[text] 產線上跑十萬張時，這個差異會被放大十萬倍 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `segmentAnythingModel` | 建立 SAM 物件 | 模型名稱是**位置引數** |
%[text] | `imsegsam` | 全自動分割 | 回傳 **`bwconncomp` struct** |
%[text] | `extractEmbeddings` | 編碼影像 | 慢，但**只需算一次** |
%[text] | `segmentObjectsFromEmbeddings` | 依提示分割 | 快；`ForegroundPoints` 是 **[x y]** |
%[text] | `labelmatrix` | struct → 標籤矩陣 | 搭配 `imsegsam` |
%[text] | `labeloverlay` `insertObjectMask` | 結果視覺化 | |
%[text] | `medicalSegmentAnythingModel` | 醫療影像版 SAM | 需 Medical Imaging Toolbox |
%[text:table]
%%
%[text] # 10. 練習
%[text] 開啟 `exercise/Ch09_Exercise.m`，完成四題。解答在 `Ch09_Solution.m`。
%%
%[text] # 11. 延伸閱讀與下一章
%[text] - [Get Started with Segment Anything Model](https://www.mathworks.com/help/images/segment-anything-model.html)
%[text] - [Automatically Segment Image Using SAM](https://www.mathworks.com/help/images/automatically-segment-image-using-sam.html)
%[text] - **下一章**：第 10 章　邊緣、直線與圓形偵測——回到傳統方法，但會看到 R2026a 把深度學習帶進了圓偵測 \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
