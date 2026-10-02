%[text] # 第 04 章　練習
%[text] 空間域濾波與雜訊處理　｜　建議時間：50 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1：從雜訊反推濾波器
%[text] 下面產生三張影像，但**不告訴你各是什麼雜訊**。
%[text] 你的任務：先**診斷**是哪一種雜訊，再選對應的濾波器處理。
%[text] **要求**：
%[text] - 用數據診斷（提示：畫 `mystery{k} - I` 的直方圖）
%[text] - 說出你的判斷依據，不要用猜的
%[text] - 處理後用 PSNR 與 SSIM 驗證你選對了 \
%[text] **不要偷看**下面產生雜訊的那幾行。
I = im2double(imread("cameraman.tif"));
mystery = cell(1,3);
mystery{1} = imnoise(I, "salt & pepper", 0.03);
mystery{2} = imnoise(I, "gaussian", 0, 0.008);
mystery{3} = imnoise(I, "speckle", 0.05);
mystery = mystery(randperm(3));      % 打亂順序

% TODO 診斷與處理


%%
%[text] # 練習 2：核大小怎麼選
%[text] 對高斯雜訊影像，掃描高斯濾波的 sigma 從 0.5 到 5。
%[text] **要求**：
%[text] 1. 畫出 sigma 對 PSNR 與 SSIM 的曲線（兩條線，雙 y 軸）
%[text] 2. 找出各自的最佳 sigma——**它們會是同一個值嗎？**
%[text] 3. 解釋為什麼超過某個 sigma 之後品質開始下降 \
%[text] **提示**：`yyaxis left` 與 `yyaxis right` 可以畫雙 y 軸。
noisy = imnoise(I, "gaussian", 0, 0.01);

% TODO


%%
%[text] # 練習 3：驗證雙邊濾波的失效
%[text] 主教材說雙邊濾波對椒鹽雜訊失效，因為它把雜訊點當成邊緣保護起來。
%[text] **證明這個解釋是對的**。
%[text] **要求**：
%[text] - 找出椒鹽雜訊點的位置（提示：值等於 0 或 1 的像素）
%[text] - 比較這些位置在濾波前後的值，計算「被保留」的比例
%[text] - 對照中值濾波在同樣位置的表現
%[text] - 用一句話說明兩者的差別 \
%[text] **預期**：雙邊濾波會保留絕大多數雜訊點的原值，中值濾波幾乎全部修正。
sp = imnoise(I, "salt & pepper", 0.05);

% TODO


%%
%[text] # 練習 4：寫一支自動去雜訊函式
%[text] 寫一支 `ch04_autoDenoise(I)` 函式，它會**自動判斷雜訊類型**並選用
%[text] 適當的濾波器。
%[text] **要求**：
%[text] - 判斷依據要寫在註解裡，並且可解釋
%[text]   （提示：椒鹽雜訊的特徵是有異常多的像素剛好等於 0 或 1）
%[text] - 回傳去雜訊後的影像，以及一個說明「判斷成什麼雜訊、用了什麼濾波器」的 struct
%[text] - 用 `arguments` 做驗證，寫完整 help
%[text] - 放到本章的 `code/` 資料夾 \
%[text] **驗證**：對練習 1 的三張影像測試，看它判斷得對不對。

% TODO


%%
%[text] # 練習 5：先濾波再分割，有幫助嗎？
%[text] 第 03 章練習 5 發現「增強」讓分割**變差**。這次換成「濾波」再試一次。
%[text] 用第 02 章的資料集（含雜訊那張），測試先做以下處理再分割：
%[text] 不處理／高斯 σ=1／中值 3×3／NLM
%[text] **要求**：用 `ch02_scoreParams` 比較四者的正確率，並解釋結果。
%[text] **思考**：第 02 章的六張變異影像裡，只有一張是雜訊問題。
%[text] 濾波應該只能修好那一張——其他張會不會反而被弄壞？

% TODO


%%
%[text] # 加分題：自己實作中值濾波
%[text] 不使用 `medfilt2` 或 `ordfilt2`，自己實作 3×3 中值濾波。
%[text] **步驟提示**：
%[text] 1. 用 `padarray` 做邊界補值
%[text] 2. 用 `im2col`（`"sliding"` 模式）把每個 3×3 鄰域攤成一行
%[text] 3. 對每一行取 `median`
%[text] 4. `reshape` 回原尺寸 \
%[text] **驗證**：與 `medfilt2` 的結果比較，差異應該極小。
%[text] **延伸思考**：`im2col` 會把整張影像展開成一個 9×N 的大矩陣。
%[text] 對 1024×1024 的影像，這個矩陣要多少記憶體？
%[text] 這解釋了為什麼實務上要用內建函式——它們是逐區塊處理的。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
