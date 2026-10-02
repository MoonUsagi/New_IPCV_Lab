%[text] # 第 01 章　練習
%[text] 影像在 MATLAB 中的表示　｜　建議時間：40 分鐘
%[text] 每一題都有 `% TODO` 標記的地方要你填。填完後執行該節，
%[text] 對照題目說明的預期結果。解答在 `Ch01_Solution.m`，
%[text] **請先自己寫過一遍再看**。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 練習 1：判讀影像型態
%[text] 讀入 `hands1.jpg`，回答三個問題：尺寸多少、資料類別是什麼、
%[text] 屬於彩色／灰階／二值哪一種。
%[text] **要求**：不要用 `ch01_imageSummary`，自己用 `size`、`class` 寫。
%[text] **預期**：能正確說出通道數，並據此判斷型態。
I1 = imread("hands1.jpg");

% TODO 印出尺寸、類別、通道數，並判斷影像型態


%%
%[text] # 練習 2：門檻的影響
%[text] 對 `rice.png` 做二值化，比較三種做法：
%[text] 1. 固定門檻 128
%[text] 2. `graythresh` 的 Otsu 全域門檻
%[text] 3. `imbinarize` 的自適應門檻——注意 `"adaptive"` 是**位置引數**，
%[text] 不是名稱-值對，寫成 `imbinarize(I, "adaptive", Sensitivity=0.45)`
%[text] 把三個結果用 `montage` 並排顯示。
%[text] **預期**：`rice.png` 的背景亮度不均勻（左上亮、右下暗）。
%[text] 固定門檻和 Otsu 都會在暗處漏掉米粒，自適應門檻則能抓到大部分。
%[text] 這個現象是第 06 章（形態學）和第 08 章（分割）的起點。
I2 = imread("rice.png");

% TODO 產生三種二值化結果並比較


%%
%[text] # 練習 3：在 HSV 空間挑顏色
%[text] 用 `peppers.png`，挑出**黃色**的椒。
%[text] **提示**：黃色的色相大約在 0.10–0.20 之間。記得同時用飽和度過濾，
%[text] 否則白色與灰色區域也會被選進來。
%[text] **預期**：遮罩應該蓋住右上角那幾顆黃椒，佔比約 5–10%。
I3 = imread("peppers.png");

% TODO 轉到 HSV，建立黃色遮罩，顯示結果並印出佔比


%%
%[text] # 練習 4：找出並修正溢位 bug
%[text] 下面這段程式想把兩張影像平均後顯示，但結果不對。
%[text] 執行看看，找出問題並修正。
%[text] **提示**：問題出在型別，而且 MATLAB **不會**給你任何警告。
A = imread("cameraman.tif");
B = imread("rice.png");
B = imresize(B, size(A));

blended = (A + B) / 2;      % <- 這一行有問題

figure
imshow(blended)
title("平均後（結果不對）")

% TODO 寫出修正版，變數命名為 blendedFixed，並與上面的結果並排比較


%%
%[text] # 練習 5：統計整個資料夾
%[text] 用 `imageDatastore` 掃描 MATLAB 內建的影像資料夾，統計其中
%[text] 彩色、灰階、二值影像各有幾張。
%[text] **要求**：用 `ch01_imageSummary` 累積成 table，再用 `groupsummary`
%[text] 或邏輯索引統計，不要寫巢狀 if-else。
%[text] **提示**：資料夾有 98 張影像，全部讀完要一點時間。先用 `subset`
%[text] 取 20 張測試，確認程式正確後再跑全部。
imdataDir = fullfile(matlabroot, "toolbox", "images", "imdata");

% TODO 建立 datastore、累積摘要表、統計各型態張數


%%
%[text] # 加分題：寫一支你自己的工具函式
%[text] 寫一支 `myColorMask(I, hueRange, minSat)` 函式，輸入彩色影像、
%[text] 色相範圍與最低飽和度，回傳二值遮罩。
%[text] **要求**：
%[text] - 用 `arguments` 區塊做輸入驗證
%[text] - 支援跨越 0／1 邊界的色相範圍（例如紅色的 `[0.95 0.05]`）
%[text] - 寫完整的 help 說明，含可執行範例
%[text] - 放到本章的 `code/` 資料夾 \
%[text] 這支函式在第 08 章（傳統分割）還會用到。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
