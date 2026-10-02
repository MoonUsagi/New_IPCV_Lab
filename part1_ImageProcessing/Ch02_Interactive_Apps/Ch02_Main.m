%[text] # 第 02 章　互動式 APP 與五步驟工作流
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明「五步驟工作流」每一步在做什麼，以及為什麼不該跳過任何一步
%[text] 2. 用 Color Thresholder 互動調出門檻，並匯出成程式碼
%[text] 3. 把 APP 產生的程式碼重構成有參數、有驗證、可重用的函式
%[text] 4. 用 `imageDatastore` 把單張影像的處理擴展到整個資料集
%[text] 5. 判斷你的方法在換一批影像後還能不能用 \
%[text] ## 前置知識
%[text] 第 01 章（影像在 MATLAB 中的表示），特別是 HSV 色彩空間那一節。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="02", Verbose=false);
disp("環境檢查通過。")
%%
%[text] # 1. 為什麼要有工作流
%[text] 多數人學影像處理是這樣的：查到一個函式、複製範例、改幾個數字、跑出一張圖，
%[text] 然後就結束了。問題在於，這樣得到的東西**沒辦法用**——
%[text] 換一張影像就失效，換一個人就看不懂，要放進產線更是無從談起。
%[text] 本課程用同一條路徑處理每一個問題：
%[text:table]
%[text] | 步驟 | 做什麼 | 產出 | 為什麼需要 |
%[text] | --- | --- | --- | --- |
%[text] | ① 互動探索 | 用 APP 調參數 | 一組可接受的參數 | 比盲猜數字快十倍 |
%[text] | ② 產生程式碼 | APP 的「產生函式」 | 能重現結果的程式碼 | 讓結果可重複，不靠手動操作 |
%[text] | ③ 函式化 | 加參數、驗證、說明 | 可重用的函式 | 別人（和三個月後的你）看得懂 |
%[text] | ④ 批次化 | 套用到整個資料集 | 可跑全資料的流程 | 一張圖能跑不代表一千張都能跑 |
%[text] | ⑤ 評估 | 量化好壞 | 可信的結論 | 不知道準不準，就不敢交出去 |
%[text:table]
%[text] **最常被跳過的是 ③ 和 ⑤**。跳過 ③，程式碼三個月後沒人敢動；
%[text] 跳過 ⑤，你不知道自己的方法什麼時候會失效。
%[text] 本章用一個具體任務走完五步：**從彩色圓片影像中找出紅色圓片並計數**。
RGB = imread("coloredChips.png");

figure
imshow(RGB)
title("coloredChips.png — 本章的任務影像")
%%
%[text] # 2. 五個核心 APP
%[text] 這五個 APP 涵蓋了影像處理最常見的工作。它們都能匯出程式碼，
%[text] 所以「用 APP」不是偷懶，而是**用最快的方式產生正確的程式碼**。
%[text:table]
%[text] | APP | 解決什麼問題 | 匯出什麼 |
%[text] | --- | --- | --- |
%[text] | **Image Browser** | 瀏覽整個資料夾，快速看過所有影像 | 匯出成 `imageDatastore` |
%[text] | **Color Thresholder** | 依顏色分割，調色相／飽和度門檻 | 產生 `createMask` 函式 |
%[text] | **Image Segmenter** | 灰階分割：門檻、區域成長、主動輪廓、SAM | 產生分割函式 |
%[text] | **Image Region Analyzer** | 分析二值影像的連通區域並依屬性篩選 | 產生篩選函式 |
%[text] | **Image Batch Processor** | 把一支函式套用到整個資料夾 | 產生批次處理程式碼 |
%[text:table]
%[text] 開啟方式：在「APP」頁籤的 Image Processing and Computer Vision 群組，
%[text] 或直接在命令列輸入名稱。
%[text] 下面這些指令會開啟視窗，需要動手操作。把 `interactive` 改成 `true`
%[text] 再執行。本章其餘部分即使不開 APP 也能完整執行。
interactive = false;   % 改成 true 以開啟 APP
%%
%[text] # 3. 步驟 ①：用 Color Thresholder 探索
%[text] **操作步驟**
%[text] 1. 執行下方指令開啟 APP
%[text] 2. 選擇色彩空間：對「依顏色挑物件」的任務，選 **HSV**
%[text] 3. 拖曳三個通道的滑桿，直到只剩紅色圓片
%[text] 4. 先調色相（決定顏色），再調飽和度（排除灰白），最後調明度（排除陰影）
%[text] 5. 滿意後按 **匯出 > 產生函式** \
%[text] **調參數的順序很重要**。很多人一開始就三個一起亂調，結果怎麼調都不對。
%[text] 先把飽和度和明度放到最寬，只調色相看出顏色範圍，再收緊另外兩個。
if interactive
    colorThresholder(RGB)
end
%[text] 紅色是最麻煩的顏色，因為它的色相同時分布在 0 附近和 1 附近
%[text] （色相是環狀的）。APP 會自動處理，但你要知道為什麼產生的程式碼裡
%[text] 那一行用的是 `|` 而不是 `&`。
%%
%[text] # 4. 步驟 ②：看看 APP 產生了什麼
%[text] `code/ch02_createMask_generated.m` 是 APP 匯出的結果，**原封不動**，
%[text] 只改了函式名稱。先執行看看它能不能用：
[BWgen, maskedRGB] = ch02_createMask_generated(RGB);

figure
montage({RGB, BWgen, maskedRGB})
title("原圖 　｜　APP 產生的遮罩 　｜　套用遮罩後")

fprintf("遮罩像素數：%d（佔 %.1f%%）\n", nnz(BWgen), 100*nnz(BWgen)/numel(BWgen));
%[text] 結果看起來不錯。但打開那支函式看一眼，就會發現它**不能直接拿去用**：
%[text:table]
%[text] | 問題 | 具體表現 |
%[text] | --- | --- |
%[text] | 門檻全部寫死 | `channel1Min = 0.900;` 沒有任何一個能從外面調 |
%[text] | 命名沒有意義 | `channel1` 是色相還是飽和度？要回去看 `rgb2hsv` 才知道 |
%[text] | 沒有輸入驗證 | 丟灰階影像進去會在 `I(:,:,2)` 那行壞掉，訊息看不懂 |
%[text] | 沒有說明 | 三個月後你不會記得這組門檻是給紅色還是橘色的 |
%[text] | 只做了一半 | 遮罩有雜點、有破洞，還不能拿來計數 |
%[text:table]
%[text] **這不是 APP 的缺點**。APP 的工作是幫你快速找到參數，
%[text] 把程式碼整理成可維護的樣子是你的工作。這就是第 ③ 步。
%%
%[text] # 5. 步驟 ③：重構成可重用的函式
%[text] `code/ch02_findChips.m` 是重構後的版本。它把工作明確分成三段：
%[text] **產生遮罩 → 清理遮罩 → 量測**，每一段都能單獨理解與測試。
[stats, mask] = ch02_findChips(RGB);

fprintf("找到 %d 個紅色圓片\n\n", height(stats));
disp(stats)
%%
%[text] ## 5.1 清理做了什麼
%[text] 原始遮罩到可用遮罩之間有四個步驟，每一步解決一個具體問題。
%[text] 把它們拆開看：
HSV = rgb2hsv(RGB);
raw = ((HSV(:,:,1)>=0.90) | (HSV(:,:,1)<=0.04)) & HSV(:,:,2)>=0.45 & HSV(:,:,3)>=0.30;

step1 = imopen(raw, strel("disk",4));        % 斷開細連結、去毛邊
step2 = imfill(step1, "holes");              % 補內部破洞
step3 = bwareaopen(step2, 500);              % 濾掉小雜點
step4 = bwpropfilt(step3, "Circularity", [0.9 Inf]);   % 只留夠圓的

figure
montage({raw, step1, step2, step3, step4}, Size=[1 5])
title("原始 ｜ 開運算 ｜ 補洞 ｜ 去雜點 ｜ 圓形度篩選")

counts = [maxLabel(raw) maxLabel(step1) maxLabel(step2) maxLabel(step3) maxLabel(step4)];
fprintf("各階段連通區域數：%s\n", mat2str(counts));
%[text] 形態學運算（`imopen`、`imfill`）是第 06 章的主題，這裡先當工具用。
%[text] 重點是理解**為什麼需要清理**：APP 給你的是「符合顏色條件的像素」，
%[text] 而你要的是「物件」。這兩者之間永遠有一段距離。
%%
%[text] ## 5.2 參數化帶來什麼
%[text] 重構後換顏色只要改一個引數，不必再開一次 APP、不必再產生一支新函式。
colors = ["紅" "黃" "綠" "藍"];
hueRanges = {[0.95 0.04], [0.12 0.20], [0.36 0.48], [0.55 0.68]};
masks = cell(1, numel(colors));

for k = 1:numel(colors)
    [s, m] = ch02_findChips(RGB, HueRange=hueRanges{k}, MinCircularity=0.8);
    masks{k} = m;
    fprintf("%s色：%d 個\n", colors(k), height(s));
end

figure
montage(masks, Size=[1 4])
title("紅 ｜ 黃 ｜ 綠 ｜ 藍")
%[text] 注意紅色這次抓到 **7 個**，比前面多一個——因為這裡把 `MinCircularity`
%[text] 放寬到 0.8，前面那個圓形度 0.86 的區域就通過了。
%[text] 哪一個才對？**要看你的定義**：如果部分被遮住的圓片也要算，7 是對的；
%[text] 如果只算完整可見的，6 是對的。這種定義問題沒有標準答案，
%[text] 但必須在動手之前跟提出需求的人講清楚。
%[text] 這幾組色相範圍是查色相直方圖估出來的，沒有經過 APP 微調。
%[text] 實務上每一種顏色都該回到 Color Thresholder 調一次——
%[text] 這正是工作流的價值：**參數用 APP 找，結構用程式碼固定下來**。
%%
%[text] # 6. 步驟 ④：批次化
%[text] 一張影像能跑，不代表一千張都能跑。要驗證這件事，得先有一批影像。
%[text] 這裡用單張影像合成一個小資料集——旋轉、調亮度、加雜訊，
%[text] 模擬產線上會遇到的變異。
%[text] **固定亂數種子**：下面會用 `imnoise` 加雜訊，那是隨機的。
%[text] 不固定種子的話，教材每次執行的數字都不一樣，你就無法對照本文的說明，
%[text] 也無法判斷「結果變了」是因為改了程式碼還是因為隨機。
%[text] 任何含隨機成分的教材與實驗，都應該在開頭固定種子。
rng(0);

dataDir = fullfile(tempdir, "ch02_chips_dataset");
if isfolder(dataDir)
    rmdir(dataDir, "s");
end
mkdir(dataDir);

%[text] 檔名刻意用 `gamma06`／`gamma15` 而不是「亮」「暗」——因為
%[text] `imadjust` 的 gamma **小於 1 是變亮、大於 1 是變暗**，和直覺相反，
%[text] 是很常見的錯誤來源。
variants = struct( ...
    "name", {"01_original" "02_rotated" "03_gamma06" "04_gamma15" "05_noisy" "06_blurred"}, ...
    "fcn",  {@(I) I, ...
             @(I) imrotate(I, 15, "crop"), ...
             @(I) imadjust(I, [], [], 0.6), ...   % gamma < 1 -> 變亮
             @(I) imadjust(I, [], [], 1.5), ...   % gamma > 1 -> 變暗
             @(I) imnoise(I, "gaussian", 0, 0.002), ...
             @(I) imgaussfilt(I, 2)});

for k = 1:numel(variants)
    imwrite(variants(k).fcn(RGB), fullfile(dataDir, variants(k).name + ".png"));
end

fprintf("已建立 %d 張測試影像於：\n%s\n", numel(variants), dataDir);
%%
%[text] ## 6.1 用 imageDatastore 讀取
%[text] `imageDatastore` 是 MATLAB 處理影像集合的標準做法。它**延遲讀取**——
%[text] 建立時不會把影像讀進記憶體，需要時才讀一張。
ds = imageDatastore(dataDir);

fprintf("資料集共 %d 張影像\n", numel(ds.Files));

figure
montage(ds, Size=[2 3])
title("合成測試資料集")
%%
%[text] ## 6.2 跑整批
%[text] `code/ch02_batchCount.m` 把 `ch02_findChips` 套用到整個 datastore，
%[text] 回傳每張影像一列的彙總表。
T = ch02_batchCount(ds);
disp(T)
%%
%[text] # 7. 步驟 ⑤：評估——你的方法穩不穩？
%[text] 這才是關鍵的一步。正確答案是 **6 個紅色圓片**（從原圖數出來的）。
%[text] 看看哪幾種變異會讓方法失效：
expected = 6;
T.Error = T.Count - expected;

disp(T(:, ["Name" "Count" "Error" "MeanCircularity"]))

figure
bar(categorical(T.Name), T.Count)
yline(expected, "r--", LineWidth=2, Label="正確答案 = 6")
ylabel("偵測到的圓片數")
title("方法對各種影像變異的穩健性")
%%
%[text] 六張裡只有三張正確。旋轉和模糊沒問題，但**兩種亮度變化和雜訊都失敗了**，
%[text] 而且失敗的方向不一樣：變亮少抓、變暗**多抓**。
%%
%[text] ## 7.1 診斷：不要猜，去看數字
%[text] 直覺會說「變暗所以明度門檻 `MinValue=0.30` 把圓片濾掉了」。
%[text] 這個直覺聽起來很合理——而且是**錯的**。動手查證：
variantFiles = ["01_original" "02_rotated" "03_gamma06" "04_gamma15" "05_noisy" "06_blurred"];
diagTable = table;

for k = 1:numel(variantFiles)
    I   = imread(fullfile(dataDir, variantFiles(k) + ".png"));
    hsvK = rgb2hsv(I);
    inHue = (hsvK(:,:,1) >= 0.90) | (hsvK(:,:,1) <= 0.04);

    diagTable = [diagTable; table(variantFiles(k), ...
        mean(im2double(im2gray(I)), "all"), ...
        nnz(inHue), ...
        nnz(hsvK(:,:,2) >= 0.45), ...
        nnz(hsvK(:,:,3) >= 0.30), ...
        nnz(inHue & hsvK(:,:,2) >= 0.45 & hsvK(:,:,3) >= 0.30), ...
        VariableNames=["Name" "平均亮度" "色相符合" "飽和符合" "明度符合" "三者交集"])]; %#ok<AGROW>
end

disp(diagTable)
%[text] 看「明度符合」那一欄——六張影像幾乎一模一樣（都在 20 萬像素上下）。
%[text] **明度門檻根本不是原因。**
%[text] 真正在變的是「色相符合」：變亮時從 16491 掉到 10754，變暗時升到 18265。
%%
%[text] ## 7.2 為什麼亮度會改變色相
%[text] 第 01 章說 HSV 把顏色和亮度分開，所以調亮度不該影響色相。那是對的——
%[text] **前提是你做的是線性亮度調整**。
%[text] 但 `imadjust` 的 gamma 校正是**逐通道的非線性運算**：
%[text] $R'=R^{\gamma},\;G'=G^{\gamma},\;B'=B^{\gamma}$
%[text] 三個通道各自做冪次運算，它們之間的**比例**就變了。而色相正是由
%[text] R、G、B 的相對比例決定的。所以 gamma 校正一定會改變色相與飽和度。
%[text] 驗證一下——取原圖中一個紅色圓片的像素，看它的色相怎麼跑：
sampleRow = round(297); sampleCol = round(176);   % 第 5.1 節找到的一個紅色圓片質心
px = squeeze(RGB(sampleRow, sampleCol, :));

for g = [0.6 1.0 1.5]
    pxAdj = im2double(px).^g;
    hsvPx = rgb2hsv(reshape(pxAdj, 1, 1, 3));
    fprintf("gamma=%.1f  RGB=(%.2f %.2f %.2f)  ->  色相 %.4f  飽和 %.3f\n", ...
        g, pxAdj(1), pxAdj(2), pxAdj(3), hsvPx(1), hsvPx(2));
end
%[text] 同一個像素，色相與飽和度都跟著 gamma 移動了。門檻是固定的，顏色卻在動——
%[text] 這就是失敗的根本原因。
%%
%[text] ## 7.3 試著修：調參數救得回來嗎
%[text] 變暗那張多抓了 3 個（把橘色圓片誤判成紅色）。
%[text] 直覺是收緊色相範圍。掃一遍看看：
darkImg = imread(fullfile(dataDir, "04_gamma15.png"));

fprintf("變暗影像，收緊色相上界：\n");
for hi = [0.040 0.030 0.020 0.015 0.010]
    s = ch02_findChips(darkImg, HueRange=[0.92 hi]);
    fprintf("  HueRange=[0.92 %.3f]  ->  %d 個%s\n", hi, height(s), ...
        ternaryStr(height(s) == expected, "   <- 正確", ""));
end
%[text] **從 9 直接掉到 5，中間沒有 6。** 不存在一個門檻能得到正確答案——
%[text] 因為在變暗的影像裡，某些橘色圓片的色相已經比某些紅色圓片**更接近紅色**。
%[text] 這兩群在色相軸上不再可分，任何單一門檻都切不開。
%%
%[text] ## 7.4 試著修：先做色彩正規化呢
%[text] 另一個直覺是「分割前先把亮度拉回標準」。也試試看：
normalized = transform(ds, @(I) imadjust(I, stretchlim(I), []));

reset(normalized);
normCounts = zeros(numel(ds.Files), 1);
for k = 1:numel(ds.Files)
    I = read(normalized);
    normCounts(k) = height(ch02_findChips(I));
end

disp(table(T.Name, T.Count, normCounts, ...
    VariableNames=["Name" "原始" "正規化後"]))

fprintf("原始正確張數    ：%d / %d\n", nnz(T.Count == expected), height(T));
fprintf("正規化後正確張數：%d / %d   <- 反而更差\n", nnz(normCounts == expected), height(T));
%[text] 逐通道拉伸讓每個通道各自伸展到滿刻度，通道之間的比例被改得更厲害，
%[text] 色相偏移反而更大。**看似合理的修正讓結果更糟**，這種事在影像處理裡很常見。
%%
%[text] ## 7.5 結論：認識方法的適用邊界
%[text] 這個方法的適用邊界是：**照明受控**。在照明穩定的條件下它又快又準又好解釋；
%[text] 一旦照明會變，固定的顏色門檻就守不住，而且**沒有辦法靠調參數補救**。
%[text] 這不是失敗，這是**知道自己方法的邊界**——而這正是第 ⑤ 步的全部意義。
%[text] 面對這個限制，實務上有三條路：
%[text:table]
%[text] | 做法 | 說明 | 本課程哪裡談 |
%[text] | --- | --- | --- |
%[text] | **控制照明** | 固定光源、加遮光罩、定期用色卡校正。這是 AOI 產線的標準答案，也是最便宜的一條 | 第 12 章（色卡與相機特性） |
%[text] | **為每種條件建一組參數** | 白天／夜間、A 線／B 線各一組。可行但維護成本高 | 第 29 章（參數與設定管理） |
%[text] | **改用對照明較穩健的方法** | 深度學習模型見過各種照明，泛化能力比固定門檻好得多 | 第 19、22 章 |
%[text:table]
%[text] 很多人以為「產線上光源要固定」是老師傅的迷信。不是——
%[text] 你剛剛親眼看到，光一變，再怎麼調參數都救不回來。
%[text] **控制輸入永遠比補救輸出便宜。**
%%
%[text] # 8. 其他 APP
%[text] ## 8.1 Image Region Analyzer
%[text] 前面我們用程式碼做 `bwpropfilt` 篩選。同樣的事可以先在 APP 裡互動探索：
%[text] 載入二值影像，看到所有區域的屬性表，拖曳滑桿即時看篩選結果，
%[text] 滿意後匯出成函式。
if interactive
    imageRegionAnalyzer(mask)
end
%[text] 這個 APP 特別適合**還不知道該用哪個屬性篩選**的時候——
%[text] 它會把面積、圓形度、離心率等所有屬性都算給你，讓你直接看哪個分得開。
%[text] 區域屬性與量測是第 11 章的主題。
%%
%[text] ## 8.2 Image Batch Processor
%[text] 我們用 `ch02_batchCount` 手寫批次處理。Image Batch Processor 提供
%[text] 圖形化的做法：選資料夾、選一支處理函式、按執行，還能平行處理。
if interactive
    imageBatchProcessor
end
%[text:table]
%[text] | 場合 | 建議 |
%[text] | --- | --- |
%[text] | 探索階段、要看每張結果 | 用 Image Batch Processor |
%[text] | 要納入自動化流程、要接 CI | 手寫 datastore 迴圈 |
%[text] | 資料量大、要平行處理 | 兩者皆可，APP 較快上手 |
%[text:table]
%%
%[text] ## 8.3 Image Segmenter 與 R2026a 的 SAM 工具
%[text] Image Segmenter 處理的是**灰階**分割（門檻、區域成長、主動輪廓）。
%[text] R2026a 起它內建了 **Segment Anything Model** 工具——
%[text] 點一下物件就能得到遮罩，不需要調任何門檻。
if interactive
    imageSegmenter(im2gray(RGB))
end
%[text] SAM 改變了「分割」這件事的預設做法：以前要花時間調門檻，
%[text] 現在很多情況下點幾下就好。但它不是萬能的——
%[text] 顏色一致的物件（例如本章的圓片）用門檻反而更快更穩，也不需要 GPU。
%[text] 什麼時候該用哪一種，是第 09 章的主題。
%%
%[text] # 9. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 直接用 APP 產生的程式碼上線 | 換一張影像就失效，沒人敢改 | 一定要做第 ③ 步重構 |
%[text] | 三個通道門檻一起亂調 | 怎麼調都不對 | 先調色相，再收緊飽和度與明度 |
%[text] | 只用一張影像驗證 | 產線上才發現不能用 | 第 ④ ⑤ 步：批次跑、量化評估 |
%[text] | 以為遮罩就是結果 | 計數多了或少了 | 遮罩要清理（開運算、補洞、去雜點）才是物件 |
%[text] | 在 RGB 空間調顏色門檻 | 光線一變就失效 | 用 HSV，色相與亮度分開 |
%[text] | 忘記紅色跨越色相邊界 | 只抓到一半的紅色 | 條件用 `\|` 不是 `&` |
%[text] | 批次處理時一張壞圖中斷全部 | 跑到一半掛掉 | 在迴圈裡 `try/catch`，記錄失敗繼續跑 |
%[text] | 以為 `imadjust` gamma 越大越亮 | 方向弄反，測試結論整個顛倒 | gamma \< 1 變亮、\> 1 變暗 |
%[text] | 以為 HSV 的色相不受亮度影響 | 調亮度後顏色分割莫名失效 | 只有**線性**亮度調整才不影響色相；gamma 是逐通道非線性運算，一定會改變色相 |
%[text] | 失敗了就猜著調參數 | 越調越亂，浪費一整天 | 先量化診斷（本章用各條件的符合像素數），確認瓶頸在哪再動手 |
%[text:table]
%%
%[text] # 10. 本章小結
%[text] - APP 的價值在於**快速找到參數**，不是產生最終程式碼
%[text] - 第 ③ 步重構是把「能跑」變成「能用」的關鍵，最常被跳過
%[text] - `imageDatastore` 讓你的方法從一張影像擴展到整個資料集
%[text] - 第 ⑤ 步評估告訴你方法的**適用邊界**——這是能不能交付的分水嶺
%[text] - 失敗要先**量化診斷**再動手。本章的直覺（明度門檻太嚴）是錯的，
%[text] 查了數字才發現真正在變的是色相
%[text] - 有些限制**調參數救不回來**。顏色門檻碰上照明變化就是這種情況——
%[text] 這時正確的做法是控制輸入（固定光源），而不是繼續調演算法 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式／APP | 用途 |
%[text] | --- | --- |
%[text] | `colorThresholder` | 依顏色互動分割，可匯出函式 |
%[text] | `imageSegmenter` | 灰階分割，R2026a 內建 SAM 工具 |
%[text] | `imageRegionAnalyzer` | 二值區域屬性分析與篩選 |
%[text] | `imageBatchProcessor` | 圖形化批次處理 |
%[text] | `imageBrowser` | 瀏覽資料夾，匯出 datastore |
%[text] | `imageDatastore` | 影像集合，延遲讀取 |
%[text] | `imopen` `imfill` `bwareaopen` | 遮罩清理 |
%[text] | `bwpropfilt` `regionprops` | 依屬性篩選與量測 |
%[text] | `montage` | 並排顯示多張影像或整個 datastore |
%[text:table]
%[text] ## 本章函式
%[text:table]
%[text] | 檔案 | 角色 |
%[text] | --- | --- |
%[text] | `code/ch02_createMask_generated.m` | 步驟 ②：APP 原始輸出，刻意不整理 |
%[text] | `code/ch02_findChips.m` | 步驟 ③：重構後的可重用函式 |
%[text] | `code/ch02_batchCount.m` | 步驟 ④：批次處理與彙總 |
%[text:table]
%%
%[text] # 11. 練習
%[text] 開啟 `exercise/Ch02_Exercise.m`，完成五題。解答在 `Ch02_Solution.m`。
%%
%[text] # 12. 延伸閱讀與下一章
%[text] - [Color Thresholder 說明](https://www.mathworks.com/help/images/image-segmentation-using-the-color-thresholder-app.html)
%[text] - [Image Batch Processor 說明](https://www.mathworks.com/help/images/batch-processing-using-the-image-batch-processor-app.html)
%[text] - **下一章**：第 03 章　點運算、直方圖與影像增強——當影像本身的品質就不好時，先把它修好再分割 \

function n = maxLabel(bw)
%MAXLABEL 回傳二值影像中的連通區域數。
n = max(bwlabel(bw), [], "all");
end

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
