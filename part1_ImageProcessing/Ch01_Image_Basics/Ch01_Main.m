%[text] # 第 01 章　影像在 MATLAB 中的表示
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明影像在 MATLAB 中就是一個矩陣，並正確判讀它的尺寸與資料型別
%[text] 2. 在彩色、灰階、二值三種影像型態之間轉換，並知道每次轉換失去了什麼
%[text] 3. 依任務選擇適當的色彩空間（RGB／HSV／L\*a\*b\*／YCbCr）
%[text] 4. 避開整數型別運算溢位這個最常見的初學陷阱
%[text] 5. 用 `imageDatastore` 把單張影像的處理擴展到整個資料夾 \
%[text] ## 前置知識
%[text] 第 00 章（課程地圖與環境建置）。請確認已執行過 `ipcvSetup`。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="01", Verbose=false);
disp("環境檢查通過。")
%%
%[text] # 1. 概念：影像就是矩陣
%[text] MATLAB 沒有「影像型別」。一張影像就是一個數值陣列，維度的意義是
%[text] `列 (高) × 行 (寬) × 通道`。所有你會的矩陣操作，都能直接用在影像上——
%[text] 這是 MATLAB 做影像處理最大的優勢。
%[text:table]
%[text] | 影像型態 | 陣列維度 | 常見類別 | 數值意義 |
%[text] | --- | --- | --- | --- |
%[text] | 彩色 RGB | H × W × 3 | `uint8` | 每通道 0–255 的強度 |
%[text] | 灰階 | H × W | `uint8` | 0（黑）–255（白） |
%[text] | 二值 | H × W | `logical` | `false`／`true` |
%[text] | 索引 | H × W ＋ 色盤 | `uint8` + `double` | 索引值指向色盤的列 |
%[text:table]
%[text] 先讀一張彩色影像，直接把它當矩陣看：
RGB = imread("peppers.png");

fprintf("尺寸    : %s\n", mat2str(size(RGB)));
fprintf("類別    : %s\n", class(RGB));
fprintf("數值範圍: %d – %d\n", min(RGB(:)), max(RGB(:)));
%[text] 左上角 3×3 像素的紅色通道，就只是一個普通的矩陣：
disp(RGB(1:3, 1:3, 1))
%%
%[text] ## 1.1 顯示影像
%[text] `imshow` 是最常用的顯示函式。注意它會依資料型別決定顯示範圍：
%[text] `uint8` 用 0–255，`double` 預設用 0–1。這是新手最常踩到的顯示問題。
figure
imshow(RGB)
title("peppers.png — 384×512×3 uint8")
%%
%[text] # 2. 三種影像型態與轉換
%[text] ## 2.1 彩色轉灰階
%[text] `im2gray` 比 `rgb2gray` 更安全：輸入已經是灰階時它會原樣回傳，
%[text] 不會報錯。寫函式時一律用 `im2gray`。
gray = im2gray(RGB);

figure
imshowpair(RGB, gray, "montage")
title("彩色 (H×W×3) 　｜　灰階 (H×W)")
%[text] 轉灰階不是把三個通道平均，而是依人眼對綠色較敏感的加權：
%[text] $Y=0.2989R+0.5870G+0.1140B$
%%
%[text] ## 2.2 灰階轉二值
%[text] 二值化需要一個門檻。`graythresh` 用 Otsu 方法自動找出門檻，
%[text] 它會回傳 0–1 的正規化值。
coins = imread("coins.png");
level = graythresh(coins);
bw    = imbinarize(coins, level);

fprintf("Otsu 門檻（正規化）= %.4f，換算到 uint8 = %.0f\n", level, level*255);

figure
imshowpair(coins, bw, "montage")
title("灰階 　｜　二值（Otsu 自動門檻）")
%%
%[text] ## 2.3 手動門檻：觀察門檻的影響
%[text] 比較不同門檻的結果，可以理解 Otsu 幫你做了什麼決定。
%[text] 注意 `coins > 70` 這種寫法會直接產生 `logical` 陣列。
thresholds = [70 100 150];
tiled = cell(1, numel(thresholds));
for k = 1:numel(thresholds)
    tiled{k} = coins > thresholds(k);
end

figure
montage(tiled, Size=[1 3])
title("門檻 = 70 　｜　100 　｜　150")
%[text] 門檻太低會把背景雜訊算進前景，太高則會讓硬幣破碎。
%[text] Otsu 找的是讓前景與背景「類別間變異數最大」的那個門檻。
%%
%[text] # 3. 色彩通道與色彩空間
%[text] ## 3.1 拆解 RGB 通道
%[text] 只取某個通道得到的是**灰階**影像（該通道的強度），不是「紅色的影像」。
%[text] 要顯示成紅色，得把另外兩個通道歸零。
R = RGB(:,:,1);   % 灰階：紅色通道的強度

redOnly              = RGB;  redOnly(:,:,[2 3]) = 0;
greenOnly            = RGB;  greenOnly(:,:,[1 3]) = 0;
blueOnly             = RGB;  blueOnly(:,:,[1 2]) = 0;

figure
montage({RGB, redOnly, greenOnly, blueOnly}, Size=[2 2])
title("原圖 ｜ R 通道 ｜ G 通道 ｜ B 通道")
%%
%[text] ## 3.2 為什麼需要別的色彩空間
%[text] RGB 把「顏色」和「亮度」混在一起——同一個紅色在陰影下，三個通道的值
%[text] 全都變了。要依顏色做篩選，換到把色相與亮度分開的空間會容易得多。
%[text:table]
%[text] | 色彩空間 | 通道 | 什麼時候用 |
%[text] | --- | --- | --- |
%[text] | RGB | R, G, B | 顯示、儲存 |
%[text] | HSV | 色相, 飽和度, 明度 | 依顏色挑物件、對光線變化較穩健 |
%[text] | L\*a\*b\* | 亮度, a, b | 色差量測、只增強亮度不動顏色 |
%[text] | YCbCr | 亮度, 藍色差, 紅色差 | 影像／視訊壓縮、膚色偵測 |
%[text:table]
HSV = rgb2hsv(RGB);
H = HSV(:,:,1);   % 色相 0–1
S = HSV(:,:,2);   % 飽和度 0–1
V = HSV(:,:,3);   % 明度 0–1

figure
montage({RGB, H, S, V}, Size=[2 2])
title("原圖 ｜ 色相 H ｜ 飽和度 S ｜ 明度 V")
%%
%[text] ## 3.3 用色相挑出紅色的椒
%[text] 紅色的色相落在 0–1 的兩端（接近 0 或接近 1），所以條件要寫成「或」。
%[text] 再加上飽和度門檻，可以濾掉灰白色區域。
isRedHue   = (H < 0.05) | (H > 0.95);
isSaturated = S > 0.4;
redMask    = isRedHue & isSaturated;

figure
imshowpair(RGB, redMask, "montage")
title("原圖 　｜　紅色遮罩（色相 + 飽和度）")

fprintf("紅色像素佔比：%.1f%%" + "\n", 100 * nnz(redMask) / numel(redMask));
%[text] 這就是 **Color Thresholder** APP 背後在做的事。第 02 章會用 APP
%[text] 互動調出這組門檻，再讓 APP 產生等價的程式碼——那才是實務上的做法。
%%
%[text] ## 3.4 L\*a\*b\*：只動亮度、不動顏色
%[text] 要增強對比又不想讓顏色偏掉，標準做法是換到 L\*a\*b\*，只處理 L 通道。
%[text] 第 03 章會深入這個技巧，這裡先建立概念。
lab      = rgb2lab(RGB);
L        = lab(:,:,1);                       % 0–100
lab2     = lab;
lab2(:,:,1) = imadjust(L/100) * 100;         % 只拉伸亮度
enhanced = lab2rgb(lab2);

figure
imshowpair(RGB, enhanced, "montage")
title("原圖 　｜　只在 L 通道拉伸對比")
%%
%[text] # 4. 索引影像
%[text] 索引影像用「索引矩陣 + 色盤」表示，是早期為了節省空間的做法。
%[text] 現在仍會在 GIF、以及需要限制顏色數的場合遇到。
[Iind, cmap] = rgb2ind(RGB, 32);   % 減到 32 色

fprintf("索引矩陣類別：%s，尺寸 %s\n", class(Iind), mat2str(size(Iind)));
fprintf("色盤尺寸    ：%s\n", mat2str(size(cmap)));

figure
imshow(Iind, cmap)
title("索引影像（32 色）")
%[text] 顏色從 1600 萬色降到 32 色，檔案小很多，但在漸層區域會出現色帶。
%%
%[text] # 5. 資料型別：最常見的陷阱
%[text] 這是初學者最容易卡住的地方，值得花時間弄懂。
%[text] `uint8` 的範圍是 0–255。超過會被**截斷**，不會自動變成更大的型別。
a = uint8(200);
b = uint8(100);

fprintf("uint8(200) + uint8(100) = %d   <- 被截斷在 255，不是 300\n", a + b);
fprintf("uint8(100) - uint8(200) = %d   <- 被截斷在 0，不是 -100\n", b - a);
%[text] 這在影像上的後果是：兩張影像相加會讓亮區「燒掉」，相減會讓暗區「黑掉」，
%[text] 而且**沒有任何警告**。
%%
%[text] ## 5.1 正確做法：先轉 double
%[text] `im2double` 會同時做兩件事：轉型別，並把數值縮放到 0–1。
%[text] 這和 `double()` 不一樣——`double()` 只轉型別，數值仍是 0–255。
grayD = im2double(coins);    % 0–1  的 double
grayX = double(coins);       % 0–255 的 double

fprintf("im2double: 類別 %s，範圍 %.3f – %.3f\n", class(grayD), min(grayD(:)), max(grayD(:)));
fprintf("double   : 類別 %s，範圍 %.0f – %.0f\n",   class(grayX), min(grayX(:)), max(grayX(:)));
%[text] 把 `double()` 的結果丟給 `imshow`，畫面會整片白——因為 `imshow` 預期
%[text] `double` 影像的範圍是 0–1，而你給的是 0–255，全部都超過上限。
figure
tiledlayout(1,2)
nexttile; imshow(grayD); title("im2double（正確）")
nexttile; imshow(grayX); title("double（整片白）")
%%
%[text] ## 5.2 判別法則
%[text:table]
%[text] | 你想做什麼 | 用什麼 |
%[text] | --- | --- |
%[text] | 型別轉換且保持視覺一致 | `im2double` `im2uint8` `im2single` |
%[text] | 只轉型別、不縮放數值 | `double()` `single()` |
%[text] | 任何算術運算前 | 先 `im2double`，算完再 `im2uint8` |
%[text] | 不確定輸入是彩色還灰階 | `im2gray` |
%[text:table]
%%
%[text] # 6. 檔案 I/O 與中繼資料
%[text] `imfinfo` 不讀取像素，只讀檔頭，所以非常快。處理大量影像時，
%[text] 先用 `imfinfo` 篩選再決定要不要真的讀進來，可以省下大量時間。
info = imfinfo("peppers.png");

fprintf("格式      : %s\n",      info.Format);
fprintf("尺寸      : %d × %d\n", info.Width, info.Height);
fprintf("位元深度  : %d\n",      info.BitDepth);
fprintf("色彩型態  : %s\n",      info.ColorType);
fprintf("檔案大小  : %.0f KB\n", info.FileSize/1024);
%%
%[text] ## 6.1 寫出影像
%[text] 寫出時要注意格式與品質。PNG 無失真、JPEG 有失真但檔案小。
outDir = tempdir;
imwrite(RGB,        fullfile(outDir,"out_lossless.png"));
imwrite(RGB,        fullfile(outDir,"out_q90.jpg"), Quality=90);
imwrite(RGB,        fullfile(outDir,"out_q20.jpg"), Quality=20);
imwrite(Iind, cmap, fullfile(outDir,"out_indexed.png"));

files = ["out_lossless.png" "out_q90.jpg" "out_q20.jpg" "out_indexed.png"];
for f = files
    d = dir(fullfile(outDir, f));
    fprintf("%-18s %6.0f KB\n", f, d.bytes/1024);
end
%[text] JPEG 品質 20 的檔案小得多，但放大看會有明顯的區塊瑕疵。
%[text] **教材與量測用途一律用無失真格式**——壓縮瑕疵會污染後續的分析結果。
%%
%[text] # 7. 互動式檢視工具
%[text] 下面這些工具會開啟視窗，需要你動手操作。把 `interactive` 改成 `true`
%[text] 再執行這一節。
interactive = false;   % 改成 true 以開啟互動式視窗
%%
%[text] ## 7.1 Image Viewer
%[text] `imageViewer` 取代了舊的 `imtool`。它可以縮放、量測距離、
%[text] 查看像素值，並顯示比例尺（R2025a 起）。
if interactive
    imageViewer(RGB)
end
%%
%[text] ## 7.2 R2026a 新功能：ROI 標註與筆刷遮罩
%[text] R2026a 為 `Viewer` 物件加入了九種 ROI 標註形狀，以及一支筆刷工具。
%[text] 這讓「在影像上圈出區域 → 轉成遮罩 → 繼續處理」變成幾行程式碼的事。
%[text:table]
%[text] | 工具 | 用途 | 形狀 |
%[text] | --- | --- | --- |
%[text] | `uidraw` | 互動繪製 ROI | line, point, rectangle, circle, polygon, angle, polyline, freehand, ellipse |
%[text] | `uipaint` | 筆刷塗抹遮罩 | 自由塗抹 |
%[text] | `createMask` | 把 ROI 轉成二值遮罩 | — |
%[text:table]
if interactive
    v   = imageViewer(RGB);
    roi = uidraw(v, "circle");      % 在畫面上拖曳畫一個圓
    m   = createMask(roi);          % 轉成二值遮罩
    figure; imshow(m); title("由 ROI 產生的遮罩")
end
%[text] 筆刷工具的用法：畫完後按畫面上的接受圖示，函式才會回傳遮罩。
if interactive
    v2   = imageViewer(RGB);
    mask = uipaint(v2);             % 塗抹後按接受
    figure; imshow(labeloverlay(RGB, mask)); title("筆刷遮罩疊圖")
end
%[text] 這兩個工具在第 13 章（影像修復）和第 17 章（資料標註）會大量用到。
%%
%[text] # 8. 函式化與批次化
%[text] 五步驟工作流的第 ③ ④ 步。前面我們用一堆零散的 `fprintf` 看影像性質，
%[text] 現在把它收斂成一支函式。
%[text] 打開 `code/ch01_imageSummary.m` 看它的寫法，重點有三個：
%[text] - `arguments` 區塊做輸入驗證，錯誤訊息清楚
%[text] - 完整的 help 說明，含可執行的範例
%[text] - 回傳 `table` 而不是印出來，讓呼叫端決定怎麼用 \
s = ch01_imageSummary(RGB, "peppers");
disp(s)
%%
%[text] ## 8.1 用 imageDatastore 跑整個資料夾
%[text] `imageDatastore` 是 MATLAB 處理影像集合的標準做法。它**不會**把所有
%[text] 影像讀進記憶體，而是需要時才讀一張——資料集再大都不會爆記憶體。
imdataDir = fullfile(matlabroot, "toolbox", "images", "imdata");
ds = imageDatastore(imdataDir, FileExtensions=[".png" ".tif" ".jpg"]);

fprintf("資料夾中共有 %d 張影像\n", numel(ds.Files));
%[text] 取 8 張作示範。這裡用 `subset` 在整個清單上均勻取樣，
%[text] 而不是直接讀前 8 張——檔案通常照字母排序，前幾張往往來自同一組資料，
%[text] 看不出變化。
idx = round(linspace(1, numel(ds.Files), 8));
dsDemo = subset(ds, idx);

T = table;
while hasdata(dsDemo)
    [img, info] = read(dsDemo);
    [~, name]   = fileparts(info.Filename);
    T = [T; ch01_imageSummary(img, string(name))]; %#ok<AGROW>
end

disp(T)
%%
%[text] ## 8.2 從摘要表回答問題
%[text] 有了 table，就能用一般的資料分析手法回答問題，不需要再寫迴圈。
area      = T.Height .* T.Width;
[~, iBig] = max(area);

fprintf("彩色影像張數：%d / %d\n", nnz(T.Channels == 3), height(T));
fprintf("最大的一張  ：%s（%d × %d）\n", T.Name(iBig), T.Height(iBig), T.Width(iBig));
fprintf("記憶體總計  ：%.2f MB\n", sum(T.MemoryMB));

figure
bar(categorical(T.Name), T.MemoryMB)
ylabel("記憶體用量 (MB)")
title("各影像的記憶體佔用")
%[text] 這就是把「單張影像的實驗」變成「整個資料集的分析」的完整路徑：
%[text] 函式化 → datastore → 表格化 → 分析。後面每一章都會重複這個模式。
%%
%[text] # 9. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | `uint8` 算術溢位 | 相加後亮區變平、相減後暗區全黑 | 先 `im2double`，運算後再 `im2uint8` |
%[text] | `double()` 與 `im2double` 混用 | `imshow` 顯示整片白 | 需要縮放時一律用 `im2double` |
%[text] | 對灰階影像呼叫 `rgb2gray` | 報錯 | 改用 `im2gray` |
%[text] | 以為 `RGB(:,:,1)` 是「紅色影像」 | 顯示出來是灰階 | 那是紅色通道的強度；要顯示紅色需把其他通道歸零 |
%[text] | 在 RGB 空間依顏色篩選 | 光線一變就失效 | 換到 HSV，用色相 + 飽和度 |
%[text] | 用 JPEG 存教材或量測影像 | 分析結果被壓縮瑕疵污染 | 用 PNG 或 TIFF |
%[text] | 迴圈中把影像全部讀進 cell | 記憶體爆掉 | 用 `imageDatastore` |
%[text:table]
%%
%[text] # 10. R2026a 新功能小結
%[text:table]
%[text] | 功能 | 說明 | 版本 |
%[text] | --- | --- | --- |
%[text] | `imageViewer` 顯示像素資訊、標題、比例尺 | 取代舊的 `imtool` | R2025a |
%[text] | `uidraw` 九種 ROI 標註形狀 | 在 Viewer 上互動繪製並匯出 | R2026a |
%[text] | `uipaint` 筆刷遮罩 | 塗抹產生二值遮罩 | R2026a |
%[text] | `linkviewers` 多視圖相機同步 | 比較多張影像／體積 | R2026a |
%[text:table]
%[text] **注意**：舊教材中的 `imtool` 仍可執行，但官方已改推 Image Viewer。
%[text] 本課程一律使用 `imageViewer`。
%%
%[text] # 11. 本章小結
%[text] - 影像就是矩陣，維度是 `高 × 寬 × 通道`
%[text] - 每次型態轉換都會失去資訊：彩色→灰階失去顏色，灰階→二值失去層次
%[text] - 色彩空間的選擇取決於任務，不是習慣
%[text] - 整數型別溢位是最常見也最安靜的錯誤，算術前先轉 `double`
%[text] - 從單張到整個資料夾，走「函式化 → datastore → 表格化」這條路 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `imread` `imwrite` `imfinfo` | 影像讀寫與檔頭查詢 | `imfinfo` 不讀像素，很快 |
%[text] | `imshow` `imshowpair` `montage` `tiledlayout` | 顯示 | `imshowpair` 做前後對照 |
%[text] | `im2gray` `rgb2gray` | 彩色轉灰階 | 優先用 `im2gray` |
%[text] | `imbinarize` `graythresh` `otsuthresh` | 二值化 | `graythresh` 回傳 0–1 |
%[text] | `im2double` `im2uint8` `im2single` | 型別轉換＋數值縮放 | 與 `double()` 不同 |
%[text] | `rgb2hsv` `rgb2lab` `rgb2ycbcr` | 色彩空間轉換 | 各有對應的反向函式 |
%[text] | `rgb2ind` `ind2rgb` | 索引影像 | 需搭配色盤 |
%[text] | `imageViewer` | 互動檢視 | 取代 `imtool` |
%[text] | `uidraw` `uipaint` `createMask` | ROI 與遮罩 | R2026a 新增 |
%[text] | `imageDatastore` | 影像集合 | 延遲讀取，不佔記憶體 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 開啟 `exercise/Ch01_Exercise.m` 完成五題練習，解答在 `Ch01_Solution.m`。
%[text] 建議先自己寫過一遍再看解答。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] - [Image Types in the Toolbox](https://www.mathworks.com/help/images/image-types-in-the-toolbox.html)
%[text] - [Understanding Color Spaces and Color Space Conversion](https://www.mathworks.com/help/images/understanding-color-spaces-and-color-space-conversion.html)
%[text] - [Get Started with Image Viewer App](https://www.mathworks.com/help/images/get-started-with-image-viewer-app.html)
%[text] - **下一章**：第 02 章　互動式 APP 與五步驟工作流——把本章手寫的色彩篩選，改用 Color Thresholder 互動調出來 \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
