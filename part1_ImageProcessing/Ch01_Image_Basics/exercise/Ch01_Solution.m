%[text] # 第 01 章　練習解答
%[text] 解答不只給答案，也說明**為什麼這樣寫**。
%[text] 如果你的寫法和解答不同但結果正確，那很好——請比較兩者的可讀性與可重用性。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 解答 1：判讀影像型態
I1 = imread("hands1.jpg");

sz     = size(I1);
nChan  = size(I1, 3);      % 用 size(I,3) 而不是 sz(3)：灰階影像的 sz 只有兩個元素
cls    = class(I1);

if nChan == 3
    kind = "彩色 RGB";
elseif islogical(I1)
    kind = "二值";
else
    kind = "灰階";
end

fprintf("尺寸：%s\n類別：%s\n通道：%d\n型態：%s\n", mat2str(sz), cls, nChan, kind);
%[text] **關鍵點**：用 `size(I,3)` 取通道數，而不是 `sz(3)`。
%[text] 灰階影像的 `size` 只回傳兩個元素，寫 `sz(3)` 會直接報索引超出範圍。
%[text] `size(I,3)` 對灰階影像會回傳 1，這是安全的寫法。
%[text] 另外注意判斷順序：先看通道數，再看 `islogical`。
%[text] 二值影像也是單通道，如果先判斷「單通道就是灰階」就會漏掉二值。
%%
%[text] # 解答 2：門檻的影響
I2 = imread("rice.png");

bwFixed    = I2 > 128;
bwOtsu     = imbinarize(I2, graythresh(I2));
bwAdaptive = imbinarize(I2, "adaptive", Sensitivity=0.45);

figure
montage({bwFixed, bwOtsu, bwAdaptive}, Size=[1 3])
title("固定門檻 128 　｜　Otsu 全域 　｜　自適應")

fprintf("固定門檻 前景佔比：%.1f%%" + "\n", 100*nnz(bwFixed)/numel(bwFixed));
fprintf("Otsu     前景佔比：%.1f%%" + "\n", 100*nnz(bwOtsu)/numel(bwOtsu));
fprintf("自適應   前景佔比：%.1f%%" + "\n", 100*nnz(bwAdaptive)/numel(bwAdaptive));
%[text] **為什麼全域門檻會失敗**：`rice.png` 的照明由左上往右下遞減。
%[text] 全域門檻只有一個數字，無法同時適應亮區和暗區——把門檻調到能抓到
%[text] 右下角的米粒，左上角的背景就會被誤判為前景。
%[text] 自適應門檻為每個像素依鄰域亮度計算一個門檻，因此能跟著照明變化。
%[text] `Sensitivity` 越大，判定為前景的傾向越強。
%[text] **這不是唯一解法**。第 06 章會用 top-hat 形態學先把背景照明校正掉，
%[text] 再用單一全域門檻——那個做法通常更穩定，也更容易解釋給客戶聽。
%%
%[text] # 解答 3：在 HSV 空間挑顏色
I3  = imread("peppers.png");
HSV = rgb2hsv(I3);
H = HSV(:,:,1);  S = HSV(:,:,2);  V = HSV(:,:,3);

yellowMask = (H > 0.10) & (H < 0.20) & (S > 0.4) & (V > 0.3);

figure
montage({I3, yellowMask})
title("原圖 　｜　黃色遮罩")

fprintf("黃色像素佔比：%.1f%%" + "\n", 100*nnz(yellowMask)/numel(yellowMask));
%[text] **三個條件各自的作用**：
%[text] - 色相 `H` 決定「是什麼顏色」
%[text] - 飽和度 `S` 排除灰白色。低飽和度時色相幾乎是隨機的，必須濾掉
%[text] - 明度 `V` 排除過暗的陰影區。暗處的色相同樣不可靠 \
%[text] 只用色相是最常見的錯誤——白色區域的色相可能是任意值，會大量誤判。
%[text] 把遮罩疊回原圖檢查，比只看黑白遮罩容易發現問題：
figure
imshow(labeloverlay(I3, yellowMask, Colormap=[1 0 0], Transparency=0.6))
title("遮罩疊回原圖檢查")
%%
%[text] # 解答 4：修正溢位 bug
A = imread("cameraman.tif");
B = imread("rice.png");
B = imresize(B, size(A));

blended = (A + B) / 2;                                   % 錯誤版本

% 修正版：先轉成 double 做運算，最後再轉回 uint8
blendedFixed = im2uint8( (im2double(A) + im2double(B)) / 2 );

figure
montage({blended, blendedFixed})
title("錯誤（先溢位再除）　｜　正確（先轉 double）")
%[text] **問題在哪**：`A + B` 是 `uint8` 加法。任何超過 255 的和都會被
%[text] **先截斷到 255**，然後才除以 2。所以所有原本該落在 128 以上的像素
%[text] 全部塌到 127–128 附近，亮部細節整片消失。
%[text] 驗證一下：
a = uint8(200); b = uint8(180);
fprintf("uint8: (200+180)/2 = %d   <- 先截斷成 255 再除\n", (a+b)/2);
fprintf("double: (200+180)/2 = %.0f  <- 正確答案\n", (double(a)+double(b))/2);
%[text] **另一種寫法**是用 `imlincomb`，它在內部以高精度運算，一行解決：
blendedLincomb = imlincomb(0.5, A, 0.5, B);
fprintf("imlincomb 與手動修正版是否一致：%d\n", isequal(blendedLincomb, blendedFixed));
%[text] 實務上處理影像的線性組合，優先用 `imlincomb`——它不會溢位，
%[text] 而且比先轉 double 再轉回來更省記憶體。
%%
%[text] # 解答 5：統計整個資料夾
imdataDir = fullfile(matlabroot, "toolbox", "images", "imdata");
ds = imageDatastore(imdataDir, FileExtensions=[".png" ".tif" ".jpg"]);

T = table;
reset(ds);
while hasdata(ds)
    [img, info] = read(ds);
    [~, name]   = fileparts(info.Filename);
    T = [T; ch01_imageSummary(img, string(name))]; %#ok<AGROW>
end

summaryByKind = groupsummary(T, "Kind");
disp(summaryByKind)

fprintf("\n共 %d 張影像\n", height(T));
fprintf("記憶體總計：%.1f MB\n", sum(T.MemoryMB));

figure
pie(categorical(T.Kind))
title("影像型態分布")
%[text] **為什麼用 table + groupsummary**：把「累積結果」和「分析結果」分開，
%[text] 迴圈裡只負責累積，分析交給 `groupsummary`。
%[text] 這樣做的好處是同一張 T 可以回答很多問題，不必為每個問題重跑一次迴圈。
%[text] **效能提醒**：`T = [T; ...]` 每次都會重新配置記憶體。
%[text] 98 張影像沒問題，但資料集上萬張時要改成先配置再填入，
%[text] 或收集成 cell array 最後一次 `vertcat`。第 29 章會談這類最佳化。
%%
%[text] # 加分題解答：myColorMask
%[text] 完整函式放在 `code/myColorMask.m`。這裡示範用法。
%[text] 重點在於它處理了「色相跨越 0／1 邊界」這個容易漏掉的情況——
%[text] 紅色的色相同時分布在接近 0 和接近 1 的兩端。
I3 = imread("peppers.png");

redMask    = myColorMask(I3, [0.95 0.05], 0.4);   % 跨越邊界
yellowMask = myColorMask(I3, [0.10 0.20], 0.4);   % 一般情況

figure
montage({I3, redMask, yellowMask}, Size=[1 3])
title("原圖 　｜　紅色（跨邊界）　｜　黃色")

fprintf("紅色佔比：%.1f%%　黃色佔比：%.1f%%" + "\n", ...
    100*nnz(redMask)/numel(redMask), 100*nnz(yellowMask)/numel(yellowMask));

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
