%[text] # 第 29 章　練習
%[text] {"align":"left"}從腳本到應用程式　｜　MATLAB R2026b
%[text] 解答在 `Ch29_Solution.m`。**建議先自己做完再看。**
%[text] 六題練習 + 一題加分題。
assert(exist("ch29_countGrains", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1　三種宣告方式，擋得住什麼
%[text] 主教材 §3 量到 `(1,1) double` 會把 `true`、`"0.5"` 安靜轉型。
%[text] 1. 寫三個只有 `arguments` 區塊的小函式：
%[text]    - A：`t (1,1) double`
%[text]    - B：`t (1,1) {mustBeNumeric}`
%[text]    - C：`t (1,1) {mustBeA(t, "double")}`
%[text] 2. 對下面每個值，記錄三個函式是「執行」還是「擋下」：
%[text]    `0.5`、`"0.5"`、`true`、`int8(1)`、`single(0.5)`、`[]`、`NaN`、`'0.5'`
%[text] 3. **哪一種最嚴格？** 它有沒有擋掉你其實想接受的值？
%[text] 4. **三種都讓 `NaN` 通過。** 什麼時候這是你要的，什麼時候不是？
%[text]    寫一個會擋 NaN 的版本。
%[text] 5. 根據結果，為 `ch29_countGrains` 的三個參數各選一種宣告方式，說明理由。

% 你的程式碼：

%%
%[text] # 練習 2　你的設定 struct 經得起 JSON 嗎
%[text] 1. 寫一個 `jsonRoundTripReport(s)`：把 struct 做 `jsonencode` → `jsondecode`，
%[text]    逐欄回報型別、大小、`isequal` 是否成立。
%[text] 2. 用主教材 §4 的欄位測一次，確認你的函式和主教材的表一致。
%[text] 3. 加三個主教材沒測的欄位：**巢狀 struct**、**struct 陣列**、**datetime**。
%[text]    讀回來各變成什麼？
%[text] 4. 用 `ch29_saveConfig`／`ch29_loadConfig` 做一次來回，
%[text]    **確認 NaN 的 Threshold 讀回來仍然是 NaN**。
%[text] 5. 手動編輯 JSON，把 `"MinArea"` 改成 `"minArea"`（小寫）。
%[text]    `ch29_loadConfig` 怎麼處理？**這個處理對嗎？**

% 你的程式碼：

%%
%[text] # 練習 3　空的 catch 有多危險
%[text] 1. 建一個資料夾，放 20 張 `rice.png` 的複本，其中第 4、9、15 張換成壞檔。
%[text] 2. 寫一個「常見」的批次迴圈：
%[text]    ```matlab
%[text]    for k = 1:numel(files)
%[text]        try
%[text]            r = ch29_countGrains(imread(files(k)));
%[text]            counts(end+1) = r.Count;
%[text]        catch
%[text]        end
%[text]    end
%[text]    ```
%[text] 3. 跑完之後看 `counts`：**你看得出有檔沒處理嗎？**
%[text] 4. 改用 `ch29_runBatch`。它告訴了你什麼？
%[text] 5. 空的 catch 版本還有一個更隱蔽的問題：`counts` 的第 k 個值
%[text]    **不一定對應第 k 個檔**。說明為什麼，並舉出它會造成什麼錯誤的結論。

% 你的程式碼：

%%
%[text] # 練習 4　容許誤差要從資料來
%[text] `tCountGrains` 對平均面積用 `RelTol=0.01`。**這個 1% 是怎麼決定的？**
%[text] 1. 對 `rice.png` 做一組「你認為無害」的擾動：
%[text]    JPEG 品質 95／90／80／70／50、轉成 single、加 σ=1／2／4 的高斯雜訊、
%[text]    放大 2 倍再縮回。
%[text] 2. 每一種都算顆數與平均面積，和原圖比。
%[text] 3. **平均面積的變化落在什麼範圍？** 1% 夠嗎？太鬆嗎？
%[text] 4. 哪幾種擾動讓**顆數**變了？顆數的測試該用精確相等還是允許 ±1？
%[text] 5. 「放大再縮回」算無害嗎？**你的容許誤差應該抓到它還是放過它？**
%[text] 6. 寫下你的決定和依據——**這段文字應該放在測試檔的註解裡**。

% 你的程式碼：

%%
%[text] # 練習 5　用 profile 找熱點，用 timeit 確認
%[text] 1. 對 30 張影像跑 `ch29_countGrains`，開著 `profile`。找出最花時間的三個函式。
%[text] 2. 其中一個是 `strel>MakeDiskStrel`。**它為什麼每張都要重做？**
%[text] 3. 改寫：讓批次處理時結構元素只建一次（提示：傳進去，或用 `persistent`）。
%[text] 4. **用 `timeit` 或 `tic/toc`（不開 profile）量**改寫前後的差距。
%[text] 5. profile 裡 `MakeDiskStrel` 佔的比例，和你量到的實際加速一致嗎？
%[text]    **不一致的話，相信哪一個？**
%[text] 6. 用 `persistent` 快取有什麼風險？（提示：`BackgroundRadius` 改了呢？）

% 你的程式碼：

%%
%[text] # 練習 6　改寫你自己的腳本
%[text] 1. 挑一段你自己寫過、「在命令列跑得好好的」影像處理腳本。
%[text] 2. 改寫成函式：參數變成名稱-值引數，**用練習 1 的結論選宣告方式**。
%[text] 3. 寫至少一個回歸測試、一個介面測試、一個性質測試。
%[text] 4. **先跑、看過結果、再把基準值寫進測試**——不要先填數字。
%[text] 5. 故意改一行演算法，確認回歸測試會失敗。
%[text] 6. 把參數放進 JSON 設定檔，用 `ch29_loadConfig` 的方式讀。

% 你的程式碼：

%%
%[text] # 加分題　參數化測試
%[text] `tCountGrains` 只測了 `rice.png`。**同一套測試跑在很多張影像上。**
%[text] 1. 用 `properties (TestParameter)` 定義一組影像與它們的基準顆數，
%[text]    例如 `rice.png`、旋轉 90 度的 `rice.png`、`coins.png`。
%[text] 2. 基準值怎麼來？**先跑一次、目視檢查疊圖、再寫進去**。
%[text] 3. 旋轉 90 度的 rice 顆數應該和原圖一樣嗎？**量了再說。**
%[text] 4. `coins.png` 用同一組預設參數會得到合理的結果嗎？
%[text]    **如果不合理，這個測試該怎麼寫？**
%[text]    （提示：測試不只能驗證「對」，也能記錄「已知在這種輸入上不適用」。）

% 你的程式碼：

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
