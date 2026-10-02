%[text] # 第 02 章　練習
%[text] 互動式 APP 與五步驟工作流　｜　建議時間：50 分鐘
assert(exist("ch02_findChips","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);   % 含隨機成分的練習，固定種子才能對照結果
%%
%[text] # 練習 1：走完五步驟（換一種顏色）
%[text] 對 `coloredChips.png` 中的**綠色**圓片，走完完整的五步驟：
%[text] 1. 開 Color Thresholder 調出綠色的門檻（把 `interactive` 改 true）
%[text] 2. 記下三個通道的門檻值
%[text] 3. 用 `ch02_findChips` 的參數重現同樣的結果
%[text] 4. 用第 6 節的方法建立變異資料集，批次跑
%[text] 5. 評估：綠色比紅色穩健還是脆弱？為什麼？ \
%[text] **提示**：綠色的色相不跨越 0／1 邊界，所以 `HueRange` 的 lo 會小於 hi。
%[text] 先自己數一數原圖有幾個綠色圓片，那是你的正確答案。
RGB = imread("coloredChips.png");
interactive = false;

if interactive
    colorThresholder(RGB)
end

% TODO 用你調出來的門檻呼叫 ch02_findChips，顯示結果並計數


%%
%[text] # 練習 2：替函式加一個參數
%[text] `ch02_findChips` 目前只能設定**最小**面積。實務上常常也需要設定
%[text] **最大**面積——例如兩個物件黏在一起時，面積會異常大，應該排除。
%[text] 修改 `code/ch02_findChips.m`，加入 `MaxArea` 參數（預設 `Inf`）。
%[text] **要求**：
%[text] - 在 `arguments` 區塊加入宣告與驗證
%[text] - 更新 help 說明，包含可執行的範例
%[text] - 驗證：設 `MaxArea=1700` 時，紅色圓片應該會少幾個 \
%[text] **提示**：`bwareafilt(BW, [lo hi])` 可以一次指定範圍。

% TODO 改完後在這裡驗證


%%
%[text] # 練習 3：診斷雜訊為什麼讓計數變少
%[text] 主教材發現加雜訊那張只抓到 5 個（正確是 6）。
%[text] 把清理流程拆成五個階段，找出**是哪一個階段弄丟的**。
%[text] **要求**：印出每個階段的連通區域數，並用 `regionprops` 看被濾掉的
%[text] 那個區域的屬性，說明它為什麼不合格。
%[text] **預期**：你會發現不是「雜訊產生假物件」，而是雜訊讓某個區域的
%[text] 某個屬性掉到門檻以下。
noisy = imnoise(RGB, "gaussian", 0, 0.002);

% TODO 逐階段拆解並診斷


%%
%[text] # 練習 4：寫一支評分函式
%[text] 寫一支 `ch02_scoreParams(ds, expected, ...)` 函式，回傳一組參數在
%[text] 整個資料集上的**正確率**（計數等於 expected 的影像比例）。
%[text] **要求**：
%[text] - 接受並轉傳 `ch02_findChips` 的所有選項
%[text] - 回傳 0–1 的分數，以及每張影像的明細 table
%[text] - 放到本章的 `code/` 資料夾 \
%[text] 有了這支函式，你就能用迴圈掃參數，找出最穩健的設定——
%[text] 這是通往第 18 章「超參數掃描」的第一步。

% TODO


%%
%[text] # 練習 5：判斷該用哪個工具
%[text] 下面四個情境，各該用哪一個 APP 或做法？寫下你的理由。
%[text] 1. 拿到 500 張產線照片，想先快速看過有沒有明顯異常
%[text] 2. 要從 X 光片中分割出骨骼，顏色資訊沒有用
%[text] 3. 已經有二值遮罩，想知道該用哪個屬性才能把好壞品分開
%[text] 4. 演算法已經定案，要每天自動處理當天的 10000 張影像 \
%[text] **提示**：第 4 題的答案不是 APP。

% TODO 寫下你的答案（用註解即可）


%%
%[text] # 加分題：平行化批次處理
%[text] `ch02_batchCount` 是逐張循序處理。資料量大時，用
%[text] `parfor` 或 `tall` 可以顯著加速。
%[text] **要求**：
%[text] - 寫一個平行版本，比較 100 張影像時的耗時
%[text] - 注意：`imageDatastore` 在 `parfor` 中不能直接共用，要用
%[text]   `partition` 切分，或改用 `readall` 後平行處理 \
%[text] **陷阱預告**：平行化不一定比較快。影像小、處理快的時候，
%[text] 啟動 worker 與傳資料的成本會超過節省的時間。記得實測。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
