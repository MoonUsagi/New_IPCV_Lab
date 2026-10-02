%[text] # 第 30 章　練習
%[text] {"align":"left"}部署與系統整合　｜　MATLAB R2026b
%[text] 解答在 `Ch30_Solution.m`。**建議先自己做完再看。**
%[text] 六題練習 + 一題加分題。
%[text] > 練習 2、3 會用到 MATLAB Coder 的建置產物。第一次執行 `ch30_buildMex`
%[text] > 每種要 40–75 秒；之後會重用 `tempdir/ch30_build` 裡的快取。
assert(exist("ch30_countGrainsCG", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 練習 1　哪些寫法擋住了 codegen
%[text] 主教材 §2 說 `ch29_countGrains` 不能直接當 codegen 的進入點。
%[text] 1. 對 `ch29_countGrains` 執行 `codegen`，讀錯誤訊息。**它抱怨的是哪一行？**
%[text] 2. 寫三個小函式，各只含一種寫法，逐一 codegen，記錄能不能過：
%[text]    - A：名稱-值引數（`options.X = 1` 的 `arguments` 區塊）
%[text]    - B：回傳 `regionprops(bw, "Area")` 的**table** 版本（`regionprops("table", ...)`）
%[text]    - C：`fprintf` 印出一個 string
%[text] 3. 對 `ch30_countGrainsCG` 呼叫一次 `threshold = NaN`。**會發生什麼？**
%[text]    為什麼 `ch30_countGrainsCG` 用 `-1` 表示「自動門檻」而不是 `NaN`？
%[text]    （提示：想想 C 的呼叫端怎麼檢查 NaN。）
%[text] 4. 把你學到的規則整理成一張「codegen 進入點的介面規則」表。

% 你的程式碼：

%%
%[text] # 練習 2　MEX 的加速在哪裡成立
%[text] 主教材 §3 在 256×256 的 `rice.png` 上量到 MEX 快 1.3–1.8 倍。
%[text] 1. 用 `ch30_buildMex(Kind="variable")` 建可變大小的 MEX。
%[text] 2. 把 `rice.png` 用 `imresize` 放大成 256、512、1024、2048 邊長，
%[text]    **背景半徑與最小面積也按比例放大**，量 MATLAB 版與 MEX 版的時間（`timeit`）。
%[text] 3. 畫出「加速倍數 vs 影像邊長」。**加速是變大還是變小？為什麼？**
%[text] 4. 每個大小都比對兩版的顆數與面積。**有沒有任何一個不一致？**
%[text] 5. 如果老闆說「編成 C 就會快 10 倍」，你會怎麼回答？

% 你的程式碼：

%%
%[text] # 練習 3　C 的呼叫端送來的影像是轉置的
%[text] MATLAB 的陣列是**以行為主**（column-major），C／C++／OpenCV／Python 的影像緩衝區
%[text] 通常是**以列為主**（row-major）。呼叫端把 `unsigned char buf[H*W]` 直接傳進
%[text] 產生的 C 函式，**函式看到的是轉置的影像**。
%[text] 1. 用 `ch30_countGrainsCG` 模擬：比較 `I` 與 `I.'` 的顆數、面積（排序後）、門檻。
%[text] 2. **這個錯誤會被發現嗎？** 為什麼這支函式對轉置「免疫」？
%[text] 3. 加一個會被轉置影響的輸出（例如每顆的質心），再比一次。
%[text] 4. 找出產生的 C 程式碼裡處理這件事的地方：`coder.config("lib")` 有沒有
%[text]    讓產生的程式碼改用以列為主的選項？（`doc coder.rowMajor`）
%[text] 5. 寫一個**能抓到轉置錯誤**的整合測試：它要用什麼樣的測試影像？

% 你的程式碼：

%%
%[text] # 練習 4　ONNX 匯入之後，類別在哪一維
%[text] 主教材 §6 量到匯出再匯入的 squeezenet 輸出維度從 `CB` 變成 `UU`，而且轉置了。
%[text] 1. 分別用 **1 張**與 **8 張**影像做批次，記錄兩個網路的輸出大小與 `dims`，
%[text]    並用常見的寫法 `[~, cls] = max(y)`（**不指定維度**）取類別。哪一種批次大小會出錯？
%[text] 2. 寫一個 `top1 = safeTop1(net, X)`：
%[text]    - 輸出有 `C` 標籤時，在 `C` 那一維取最大值
%[text]    - 輸出是 `UU` 時，**用「哪一維的大小等於類別數」判斷**
%[text]    - 兩維大小一樣（例如 1000 張影像、1000 類）時**報錯**，不要猜
%[text] 3. 用你的函式確認兩個網路的 top-1 完全一致。
%[text] 4. 如果你的測試只用 1 張影像，**它抓得到這個轉置問題嗎？** 為什麼？

% 你的程式碼：

%%
%[text] # 練習 5　跨 Python 邊界的成本
%[text] 主教材 §7 量到一次 `pyrun` 呼叫 14–31 毫秒。
%[text] 1. 量傳送不同大小的 double 矩陣到 Python（`pyrun("n_ = 0", "n_", x_=A)`，Python 端什麼都不做，只量傳送）的時間：
%[text]    1×1、100×100、512×512、1024×1024。**成本主要跟次數還是資料量有關？**
%[text] 2. 在沒有 numpy 的環境，MATLAB 矩陣到 Python 變成 `memoryview`。
%[text]    傳一個 2×3 的矩陣 `[1 2 3; 4 5 6]`，在 Python 端 `tolist()`。
%[text]    **列與行的順序對嗎？**
%[text] 3. 一個 Python 函式回傳 `2**53 + 1`。轉成 MATLAB `double` 之後是多少？
%[text]    轉成 `int64` 呢？
%[text] 4. 根據結果，給「每張影像都呼叫一次 Python 做後處理」的設計一個建議。

% 你的程式碼：

%%
%[text] # 練習 6　替四個場景選部署方式
%[text] 用本章量到的數字（不是直覺）為下面四個場景各選一條路，說明理由與風險：
%[text:table]
%[text] | 場景 | 條件 |
%[text] | --- | --- |
%[text] | A　AOI 產線 | 每 200 ms 一張 2048×2048 影像，Windows 工業電腦，結果送 PLC |
%[text] | B　夜間批次 | 每天晚上處理 5 萬張，時間不限，IT 只允許排程執行 exe |
%[text] | C　嵌入式相機 | ARM 處理器，沒有作業系統等級的 MATLAB Runtime |
%[text] | D　Python 團隊 | 對方的服務用 Python 寫，想用你的演算法 |
%[text:table]
%[text] 1. 每個場景：選哪一條（MEX／C 函式庫／獨立執行檔／Production Server／ONNX／Python 呼叫）？
%[text] 2. 用本章的數字算：**場景 A 的 200 ms 預算夠不夠？** 場景 B 每張啟動一次 exe 要多久？
%[text] 3. 每個選擇**最可能壞在哪裡**？（提示：§4 的固定大小、練習 3 的轉置、§8 的 Runtime 啟動）

% 你的程式碼：

%%
%[text] # 加分題　多出來的 618 MB 是誰帶進來的
%[text] 主教材 §8 量到預設打包的 exe 有 619.8 MB。
%[text] 1. 用 `ch30_buildStandalone(SupportPackages="autodetect")` 打包一次
%[text] （**約 1 分鐘、需要約 1 GB 暫存空間**），讀 `includedSupportPackages.txt`。
%[text] 2. 用 `matlab.codetools.requiredFilesAndProducts("ch30_grainCLI.m")` 看程式實際依賴的產品。
%[text]    **兩份清單差在哪裡？**
%[text] 3. 你能找到讓自動偵測帶進某個支援包的原因嗎？
%[text] 4. 在團隊的建置腳本裡，你會把 `SupportPackages` 設成什麼？
%[text]    **設成 `"none"` 的風險是什麼？** 怎麼在建置流程裡抓到這個風險？

% 你的程式碼：

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
