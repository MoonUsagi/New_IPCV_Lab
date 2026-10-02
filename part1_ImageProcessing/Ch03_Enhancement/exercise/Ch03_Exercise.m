%[text] # 第 03 章　練習
%[text] 點運算、直方圖與影像增強　｜　建議時間：45 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 練習 1：先診斷，再開藥
%[text] 下面四張影像各有不同的問題。**先看直方圖判斷問題是什麼**，
%[text] 再選一種增強手法處理，並說明為什麼選它。
%[text] **要求**：用 `tiledlayout` 把每張影像的「原圖 / 直方圖 / 處理後」並排。
%[text] **同時回答**：這四張裡有沒有**救不回來**的（資訊已被截斷）？
%[text] 用數據回答，不要憑印象——提示：檢查貼在 0 與 255 兩端的像素比例。
imgs = ["pout.tif" "tire.tif" "moon.tif" "AT3_1m4_01.tif"];

% TODO 逐張診斷並處理


%%
%[text] # 練習 2：製造一張救不回來的影像
%[text] 把 `pout.tif` 處理成「過曝截斷」的樣子（大量像素被壓到 255），
%[text] 然後試著用任何方法救回來。
%[text] **要求**：
%[text] - 印出被截斷的像素佔比
%[text] - 嘗試至少兩種增強手法
%[text] - 用數字說明為什麼救不回來（提示：比較原圖與「救回來」的影像的熵） \
%[text] 這題的目的是讓你有底氣跟人說「這要重拍」。

% TODO


%%
%[text] # 練習 3：找出 imflatfield 的 sigma
%[text] 主教材用 `imflatfield(rice, 30)` 校正光場。
%[text] 掃描 sigma 從 5 到 100，找出：
%[text] 1. sigma 太小時會發生什麼（提示：看米粒本身有沒有被削掉）
%[text] 2. sigma 太大時會發生什麼
%[text] 3. 以「二值化後的連通區域數接近 95」為準，最佳 sigma 大約是多少 \
%[text] **要求**：畫出 sigma 對連通區域數的曲線。
rice = imread("rice.png");

% TODO


%%
%[text] # 練習 4：為彩色影像寫一支安全的增強函式
%[text] 寫一支 `ch03_enhanceColor(RGB, method, ...)` 函式，它**保證不會讓顏色偏掉**。
%[text] **要求**：
%[text] - `method` 可選 `"stretch"`、`"histeq"`、`"clahe"`
%[text] - 內部一律轉到 L\*a\*b\*，只處理 L 通道
%[text] - 用 `arguments` 做驗證，並在 help 裡說明為什麼不能逐通道處理
%[text] - 回傳增強後影像，以及一個包含色相偏移量的診斷 struct
%[text] - 放到本章的 `code/` 資料夾 \
%[text] **驗證**：對 `coloredChips.png` 執行三種方法，色相偏移都應該明顯小於
%[text] 逐通道 histeq 的 9.9 度。

% TODO


%%
%[text] # 練習 5：增強會不會讓分割變好？
%[text] 這是一個貫穿性的問題。用第 02 章的 `ch02_findChips`，測試：
%[text] **先增強再分割，會不會比直接分割準？**
%[text] **要求**：
%[text] 1. 用第 02 章的方法建立 6 張變異影像（記得 `rng(0)`）
%[text] 2. 分別測試：不處理／`imadjust`／`imflatfield`／Lab-CLAHE 四種前處理
%[text] 3. 用 `ch02_scoreParams` 比較四者的正確率
%[text] 4. 寫下你的結論 \
%[text] **預告**：結果可能會讓你意外。想一想第 02 章第 7.5 節的結論
%[text] ——增強是點運算，它能修正**照明**，但能不能修正**色相偏移**？

% TODO


%%
%[text] # 加分題：自己實作直方圖等化
%[text] 不使用 `histeq`，自己用累積分布函式（CDF）實作直方圖等化。
%[text] **步驟提示**：
%[text] 1. 用 `imhist` 取得直方圖
%[text] 2. 算累積和並正規化到 0–1
%[text] 3. 用這張 CDF 當查表，把每個像素值映射到新值 \
%[text] **驗證**：你的結果應該與 `histeq(I)` 幾乎完全相同
%[text] （可能有 ±1 的捨入差異）。
%[text] 做完這題，你就真正理解「點運算就是查表」這句話了。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
