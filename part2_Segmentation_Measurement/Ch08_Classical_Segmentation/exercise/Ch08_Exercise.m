%[text] # 第 08 章　練習
%[text] 傳統影像分割　｜　建議時間：60 分鐘
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1：診斷分割失敗的原因
%[text] 下面四張影像，用預設的 `imbinarize` 分割都會出問題，但**原因各不相同**。
%[text] 對每一張：診斷原因、選擇對策、驗證改善。
%[text] **要求**：
%[text] - 用數據診斷（直方圖、前景佔比、空白區域比例）
%[text] - 說明你選這個對策的理由
%[text] - 用一個數字證明改善了 \
%[text] **提示**：對策不外乎本章與前幾章學過的——
%[text] 校正照明（Ch.03/06）、換特徵（顏色／紋理）、換演算法、或先濾波（Ch.04）。
problemImages = ["rice.png" "AT3_1m4_01.tif" "coloredChips.png" "tissue.png"];

% TODO 逐張診斷


%%
%[text] # 練習 2：ISODATA 的參數在做什麼
%[text] 主教材只用了 `InitialNumClusters`。ISODATA 還有幾個參數控制分裂與合併。
%[text] **要求**：
%[text] 1. 對 `gantrycrane.png` 掃描 `MaxStandardDeviation`，看最終群數怎麼變
%[text] 2. 掃描 `MinClusterSeparation`，看最終群數怎麼變
%[text] 3. 用一句話說明這兩個參數各自控制「分裂」還是「合併」
%[text] 4. 畫出參數對最終群數的關係圖 \
%[text] **提示**：想想 ISODATA 的兩個動作——
%[text] 「一個群的變異數太大就分裂」、「兩個群太接近就合併」。

% TODO


%%
%[text] # 練習 3：寫一支分割評估函式
%[text] 寫一支 `ch08_evaluateSegmentation(candidates, groundTruth)` 函式。
%[text] **要求**：
%[text] - `candidates` 是一個 containers.Map 或 cell 陣列（名稱 → 遮罩）
%[text] - 自動處理「前景／背景反了」的情況
%[text] - 回傳一張 table，含 Dice、Jaccard、BFscore、前景佔比、
%[text]   以及**每個指標的排名**
%[text] - 若不同指標的排名不一致，發出警告提醒使用者
%[text] - 用 `arguments` 驗證，寫完整 help
%[text] - 放到本章的 `code/` 資料夾 \
%[text] 第 4 點是重點：本章已經證明 Dice 與 BFscore 會給出相反的排名，
%[text] 函式應該主動提醒，而不是讓使用者自己發現。

% TODO


%%
%[text] # 練習 4：找出 GrabCut 的 ROI 底線
%[text] 主教材示範 ROI 太小會封頂。**量化這個關係**。
%[text] **要求**：
%[text] 1. 產生一系列大小遞增的 ROI（從只涵蓋正解 30% 到 100%）
%[text] 2. 對每個 ROI 跑 GrabCut，記錄 Dice
%[text] 3. 畫出「ROI 涵蓋率 vs Dice」的曲線
%[text] 4. 在同一張圖上畫出「理論上限」——即 `dice(roi & gt, gt)` \
%[text] **預期**：實際 Dice 會貼著理論上限走。
%[text] 這證明了**ROI 就是硬天花板**，不是軟性的建議。

% TODO


%%
%[text] # 練習 5：分割 → 形態學 → 量測 的完整流程
%[text] 這題把 Ch.06、Ch.08 串起來，並預告 Ch.11。
%[text] 用 `rice.png`，做出一個**可交付**的米粒分析：
%[text] **要求**：
%[text] 1. 分割（選你在練習 1 認為最好的方法）
%[text] 2. 用 `ch06_cleanMask` 清理，並檢查 log 確認沒有哪一步殺掉太多物件
%[text] 3. 移除碰到影像邊界的米粒（它們的量測值不可信）
%[text] 4. 用 `regionprops` 取得面積、長軸、短軸、離心率
%[text] 5. 輸出一張 table，並畫出面積的直方圖
%[text] 6. 回報：幾顆米、平均面積、面積的變異係數 \
%[text] **思考**：第 3 步移除了幾顆？這會讓統計結果偏向哪一邊？

% TODO


%%
%[text] # 加分題：用分水嶺數細胞
%[text] `AT3_1m4_01.tif` 是螢光顯微鏡的細胞影像，細胞彼此有黏連。
%[text] 完成一個細胞計數流程。
%[text] **要求**：
%[text] - 處理照明不均（細胞影像常有邊緣較暗的問題）
%[text] - 分割出細胞區域
%[text] - 用分水嶺分開黏連的細胞
%[text] - 調 `imhmin` 的深度，找出計數穩定的區間 \
%[text] **提示**：`imhmin` 深度太小會過度分割（一個細胞裂成好幾個），
%[text] 太大會合併（幾個細胞算成一個）。找出中間那段**計數不隨參數變動**的區間——
%[text] 那通常就是正確答案所在。
%[text] **這個「找穩定區間」的技巧在實務上非常有用**：
%[text] 當你不知道正確答案時，參數掃描的**平台區**往往就是對的。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
