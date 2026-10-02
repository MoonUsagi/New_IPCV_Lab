%[text] # 第 29 章　從腳本到應用程式
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[產業\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 把一段腳本改寫成**介面清楚、輸入有檢查**的函式
%[text] 2. 知道 `arguments` 區塊的類別宣告是**轉型不是檢查**，以及怎麼補
%[text] 3. 讀寫 JSON 設定檔而**不被它悄悄改掉型別**
%[text] 4. 寫一個**一個壞檔不會停掉整批**、而且留下紀錄的批次程式
%[text] 5. 用 `matlab.unittest` 寫回歸測試，並知道**基準值代表什麼、不代表什麼**
%[text] 6. 做一個「很薄」的 App，並知道為什麼要這樣做
%[text] ## 前置知識
%[text] 第 6 章（形態學）、第 8 章（Otsu）、第 11 章（區域量測）、
%[text] 第 23 章（單幀函式與逐幀驅動的分工）。
%[text] ## 環境需求
%[text] MATLAB + Image Processing Toolbox。`matlab.unittest` 與 `matlab.uitest`
%[text] 是 MATLAB 內建的，不需要額外的工具箱。
%[text] > ## **本章的一句話**
%[text] > **工程化不是加功能，是把「只有寫的人知道」的東西寫下來、並且讓電腦檢查。**
%[text] > 參數的合法範圍、設定檔的欄位、演算法的預期行為——
%[text] > 腳本裡這些都只存在作者的腦袋裡。
assert(exist("ch29_countGrains", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
chapterDir = fileparts(which("ch29_countGrains"));
chapterDir = fileparts(chapterDir);             % code 的上一層
%%
%[text] # 1. 這一章的位置
%[text] 前 28 章寫的都是**給自己跑的程式**。這一章處理的是：
%[text] 當別人要用、要改、要在三個月後重跑的時候，**會壞在哪裡**。
%[text:table]
%[text] | 腳本的樣子 | 三個月後的問題 |
%[text] | --- | --- |
%[text] | 參數寫死在第 12 行 | 沒人知道 15 這個數字是怎麼來的 |
%[text] | 假設輸入是灰階 uint8 | 有人丟一張 RGB 進來，結果全錯但不報錯 |
%[text] | 第 37 個檔壞了就停 | 前 36 個的結果全部丟失 |
%[text] | 「上次跑出來是 93 顆」 | 改了一行程式之後，沒人知道結果有沒有變 |
%[text:table]
%[text] 本章的範例是一個米粒計數程式——在命令列跑得好好的那種。
%%
%[text] # 2. 從腳本到函式
%[text] 原本的腳本長這樣：
%[text] ```matlab
%[text] I = imread("rice.png");
%[text] bg = imopen(I, strel("disk", 15));
%[text] J = I - bg;
%[text] bw = imbinarize(J);
%[text] bw = bwareaopen(bw, 50);
%[text] cc = bwconncomp(bw);
%[text] cc.NumObjects
%[text] ```
%[text] 改寫成 `ch29_countGrains` 之後：
result = ch29_countGrains(imread("rice.png"));
fprintf("顆數 %d，平均面積 %.1f，門檻 %.4f\n", ...
    result.Count, mean(result.Areas), result.Threshold);
disp(result.Params)
%[text] **演算法一行都沒改。** 改的是：
%[text:table]
%[text] | | 腳本 | 函式 |
%[text] | --- | --- | --- |
%[text] | 參數 | 寫死 | 名稱-值引數，有預設值與驗證 |
%[text] | 輸入 | 假設灰階 uint8 | RGB 自動轉換，二值影像**明確拒絕** |
%[text] | 輸出 | 散落在工作區 | 一個 struct |
%[text] | 可重現性 | 不知道用了什麼參數 | **`Params` 欄位記錄下來** |
%[text:table]
%[text] > 注意原腳本 `I - bg` 是 **uint8 減法**：負值會被截成 0。
%[text] > 函式裡先 `im2double` 再減——在這張圖上結果剛好一樣，
%[text] > 但對背景比前景亮的影像，uint8 版本會安靜地丟掉資訊。
%%
%[text] # 3. `arguments` 區塊：類別宣告是轉型，不是檢查
%[text] 很多人以為寫了 `t (1,1) double` 就保證 `t` 是一個 double。量一次：
x = rand(64);
testValues = {"0.5", true, int8(1), single(0.5), "abc", '0.5'};
fprintf("%-10s %-8s  %s\n", "類別", "值", "t (1,1) double {mustBeInRange(t,0,1)} 的反應");
for i = 1:numel(testValues)
    v = testValues{i};
    try
        y = coerceDemo(x, v);
        msg = sprintf("**執行了**，x > t 的比例 %.3f", mean(y(:)));
    catch ME
        msg = "報錯：" + extractBefore(string(ME.message) + newline, newline);
    end
    fprintf("%-10s %-8s  %s\n", class(v), mat2str(v), msg);
end
fprintf("（對照：x > 0.5 的比例 %.3f）\n", mean(x(:) > 0.5));
%[text:table]
%[text] | 傳入 | 結果 |
%[text] | --- | --- |
%[text] | `"0.5"`（string） | **自動轉成 0.5，照常執行** |
%[text] | `true` | **轉成 1，安靜地回傳全 false** |
%[text] | `int8(1)` | 轉成 1，全 false |
%[text] | `"abc"` | 轉成 NaN，報「必須介於 0 到 1」——**訊息指錯了問題** |
%[text] | `'0.5'`（char） | 報「必須是純量」（char 是 1×3） |
%[text:table]
%[text] > ## **`(1,1) double` 的意思是「轉成 1×1 的 double」，不是「必須是」。**
%[text] > 要真的擋住錯的型別，要**不寫類別**、改用驗證函式：
%[text] > `{mustBeNumeric, mustBeFloat}`，logical 另外寫一個檢查。
%[text] > `ch29_countGrains` 就是這樣寫的：
try
    ch29_countGrains(imread("rice.png"), MinArea=true);
catch ME
    fprintf("MinArea=true → %s\n", ME.message);
end
try
    ch29_countGrains(imread("rice.png"), MinArea="50");
catch ME
    fprintf("MinArea=""50"" → %s\n", ME.message);
end
%[text] ## 驗證的成本
if ipcvFast()
    disp("（快速模式：略過計時，見下方既有量測值）")
else
    N = 2e5;
    t0 = tic; for k = 1:N, noCheckDemo(x, 0.5); end; tNo  = toc(t0)/N;
    t0 = tic; for k = 1:N, coerceDemo(x, 0.5);  end; tArg = toc(t0)/N;
    t0 = tic; for k = 1:N, parserDemo(x, 0.5);  end; tIP  = toc(t0)/N;
    fprintf("每次呼叫：無驗證 %.2f μs｜arguments %.2f μs｜inputParser %.2f μs\n", ...
        tNo*1e6, tArg*1e6, tIP*1e6);
end
%[text] 某次執行：**無驗證 5.09 μs、`arguments` 5.75 μs、`inputParser` 103.8 μs**。
%[text] `arguments` 只多 0.66 μs——**對任何處理影像的函式都可以忽略**。
%[text] `inputParser` 貴 20 倍，而且錯誤訊息比較差
%[text]（「It must satisfy the function: @(v)isscalar(v)&&v>=0&&v<=1」）。
%[text] **新程式一律用 `arguments`。**
%%
%[text] # 4. 設定檔：JSON 不是無損的
%[text] 參數多了就要放進設定檔。JSON 是最常見的選擇，但**來回轉換會改東西**：
cfg = struct();
cfg.Channels = [1 2 3];  cfg.Tags = ["a" "b"];  cfg.Threshold = NaN;
cfg.Limit = Inf;         cfg.Gain = single(0.1); cfg.Level = int32(7);
cfg.Kernel = [1 2; 3 4]; cfg.Flag = true;
back = jsondecode(jsonencode(cfg));
fn = string(fieldnames(cfg));
Field = fn; Before = strings(numel(fn),1); After = strings(numel(fn),1); Same = false(numel(fn),1);
for k = 1:numel(fn)
    a = cfg.(fn(k)); b = back.(fn(k));
    Before(k) = string(class(a)) + " " + mat2str(size(a));
    After(k)  = string(class(b)) + " " + mat2str(size(b));
    Same(k)   = isequal(a, b);
end
disp(table(Field, Before, After, Same))
fprintf("jsonencode 的內容：%s\n", jsonencode(cfg));
%[text:table]
%[text] | 原本 | 讀回來 |
%[text] | --- | --- |
%[text] | 列向量 `[1 2 3]` | **行向量 3×1**（方向資訊遺失） |
%[text] | string 陣列 | **cell 2×1** |
%[text] | **`NaN`、`Inf`** | **`null` → `[]`** |
%[text] | `single(0.1)` | double 0.1（**值也變了**：0.1000000015 → 0.1） |
%[text] | `int32(7)` | double 7 |
%[text:table]
%[text] > ## **最危險的是 NaN → []。**
%[text] > `ch29_countGrains` 用 `Threshold = NaN` 表示「自動門檻」。
%[text] > 存檔、讀回來變成 `[]`，傳進去就報「必須是 1×1」——
%[text] > **一個在記憶體裡完全正常的設定，存檔之後就不能用了。**
%[text] `ch29_saveConfig`／`ch29_loadConfig` 的做法：
%[text] 1. NaN／Inf 存成字串 `"NaN"`／`"Inf"`
%[text] 2. 讀回來時**依照欄位規格**修正型別與方向——只有程式知道每個欄位應該是什麼
%[text] 3. **不認得的欄位報錯**，並猜使用者想打什麼
cfgFile = fullfile(tempdir, "ch29_demo.json");
ch29_saveConfig(struct(BackgroundRadius=15, MinArea=50, Threshold=NaN, ...
    InputFolder="images", FilePattern="*.png"), cfgFile);
loaded = ch29_loadConfig(cfgFile);
fprintf("\n讀回來的 Threshold：%g（isnan = %d）\n", loaded.Threshold, isnan(loaded.Threshold));
typoFile = fullfile(tempdir, "ch29_typo.json");
fid = fopen(typoFile, "w"); fprintf(fid, '{"MinAera": 80, "Treshold": 0.3}'); fclose(fid);
try
    ch29_loadConfig(typoFile);
catch ME
    fprintf("%s\n", ME.message);
end
%[text] **拼錯的欄位如果被安靜地忽略，使用者以為改了參數，其實用的是預設值。**
%[text] 這是設定檔最常見、也最難發現的錯誤。
%%
%[text] # 5. 批次處理：一個壞檔不能停掉整批
batchDir = fullfile(tempdir, "ch29_batch");
if isfolder(batchDir), rmdir(batchDir, "s"); end
mkdir(batchDir);
imwrite(imread("rice.png"), fullfile(batchDir, "01_rice.png"));
imwrite(imrotate(imread("rice.png"), 90), fullfile(batchDir, "02_rice_rot.png"));
fid = fopen(fullfile(batchDir, "03_broken.png"), "w"); fwrite(fid, "not a png"); fclose(fid);
imwrite(imread("rice.png") > 100, fullfile(batchDir, "04_binary.png"));
imwrite(imresize(imread("rice.png"), 0.5), fullfile(batchDir, "05_rice_small.png"));

files = dir(fullfile(batchDir, "*.png"));
names = string(fullfile({files.folder}, {files.name}));
logFile = fullfile(batchDir, "run.log");
[batchResults, batchFailures] = ch29_runBatch(names, loaded, LogFile=logFile, Quiet=true);
disp(batchResults(:, ["File" "Count" "MeanArea"]))
disp(batchFailures(:, ["File" "Identifier"]))
fprintf("紀錄檔：\n%s\n", fileread(logFile));
%[text] **五個檔，兩個壞的**（一個不是 PNG、一個已經是二值影像），
%[text] 另外三個照常處理完，失敗的原因記在表格與紀錄檔裡。
%[text:table]
%[text] | 寫法 | 第 3 個檔壞掉時 |
%[text] | --- | --- |
%[text] | 腳本的 `for` 迴圈 | 報錯停止，**前兩個結果丟失**，後兩個沒跑 |
%[text] | `try ... catch, end`（空的 catch） | 跑完了，**但你不知道有兩個沒處理** |
%[text] | **`ch29_runBatch`** | 跑完，**失敗的列在 `failures`，紀錄檔寫明原因** |
%[text:table]
%[text] > 空的 `catch` 比沒有 `try` 更糟。沒有 `try` 至少會停下來讓你看到。
%[text] 注意 `05_rice_small.png`（縮小一半）的顆數——同樣的 `MinArea=50`
%[text] 在小圖上會把米粒濾掉。**參數是和影像尺度綁在一起的**，
%[text] 這和第 23 章「降解析度要把 MinArea 跟著縮 $D^2$」是同一件事。
%%
%[text] # 6. 測試：讓電腦記住「應該是什麼」
testDir = fullfile(chapterDir, "tests");
unitResults = runtests(testDir, Name=["tCountGrains*" "tConfigAndBatch*"]);
unitTable = table(unitResults);          % 不能寫 table(x)(:, ...)——對回傳值直接索引是語法錯誤
disp(unitTable(:, ["Name" "Passed" "Duration"]))
fprintf("單元測試 %d 個，全部通過：%s，總耗時 %.2f 秒\n", numel(unitResults), ...
    string(all([unitResults.Passed])), sum([unitResults.Duration]));
%[text] `tests/` 裡有三類測試：
%[text:table]
%[text] | 類型 | 防什麼 | 例子 |
%[text] | --- | --- | --- |
%[text] | **回歸測試** | 改了程式，結果悄悄變了 | rice.png 必須是 93 顆 |
%[text] | **介面測試** | 壞的輸入被安靜接受 | 傳 `true` 當參數必須報錯 |
%[text] | **性質測試** | 結果違反常識 | `MinArea` 越大，顆數不能變多 |
%[text:table]
%[text] ## 回歸測試的基準值代表什麼
%[text] > **我第一版在測試裡寫了 83 顆、平均面積 201.1——是還沒跑就先填的數字。**
%[text] > 實際是 **93 與 189.2**。測試第一次執行就失敗了，這正是它的用途。
%[text] 跑出 93 之後，我把遮罩疊回原圖看過：沒有明顯漏抓，
%[text] 但**有 2 個區塊面積超過中位數 2 倍**（很可能是兩顆黏在一起），
%[text] 上緣也有幾顆被裁切的米粒沒被算進去。所以：
%[text] > **基準值是「這個演算法現在的行為」，不是「真實的米粒數」。**
%[text] > 回歸測試保護的是「沒有人不小心改變行為」，它不保證行為是對的。
%[text] > 要驗證正確性，需要**有人工標註的真值**——那是另一種測試。
%[text] ## 比什麼：顆數，而不是整張遮罩
riceGray = imread("rice.png");
rUint8  = ch29_countGrains(riceGray);
rSingle = ch29_countGrains(single(im2double(riceGray)));
jpgFile = fullfile(tempdir, "ch29_rice_q90.jpg");
imwrite(riceGray, jpgFile, Quality=90);
rJpeg = ch29_countGrains(imread(jpgFile));
fprintf("uint8 輸入：%d 顆\n", rUint8.Count);
fprintf("single 輸入：%d 顆，遮罩和 uint8 版差 %d 像素\n", rSingle.Count, nnz(rSingle.Mask ~= rUint8.Mask));
fprintf("JPEG q90：   %d 顆，遮罩和原版差 %d 像素\n", rJpeg.Count, nnz(rJpeg.Mask ~= rUint8.Mask));
%[text] **顆數完全一樣，遮罩卻差了 50 與 197 個像素。**
%[text] 如果回歸測試寫成「遮罩必須逐像素相同」，這兩個無害的改動都會讓測試失敗。
%[text] > **測試太敏感，大家就會開始忽略測試失敗——那比沒有測試更糟。**
%[text] > 比較你真正在意的量（顆數、平均面積），給一個**有根據**的容許誤差
%[text] >（`tCountGrains` 對平均面積用 `RelTol=0.01`）。
%[text] ## 它抓得到真正的改變嗎？
bgVariants = { "原版：imopen + strel(""disk"",15)",   @(g) imopen(g, strel("disk",15));
               "「更精確」：strel(""disk"",15,0)",      @(g) imopen(g, strel("disk",15,0));
               "改用 imgaussfilt 估背景",             @(g) imgaussfilt(g, 15);
               "改用 medfilt2 估背景",                @(g) medfilt2(g, [31 31]) };
riceD = im2double(riceGray);
Variant = strings(4,1); Count = zeros(4,1); MeanArea = zeros(4,1); PassesTest = false(4,1);
for k = 1:4
    c = riceD - bgVariants{k,2}(riceD);
    m = bwareaopen(imbinarize(c, graythresh(c)), 50);
    cc = bwconncomp(m);
    a = cellfun(@numel, cc.PixelIdxList);
    Variant(k) = bgVariants{k,1};
    Count(k) = cc.NumObjects;
    MeanArea(k) = mean(a);
    PassesTest(k) = Count(k) == 93 && abs(MeanArea(k)/189.2151 - 1) <= 0.01;
end
disp(table(Variant, Count, MeanArea, PassesTest))
%[text:table]
%[text] | 重構 | 顆數 | 平均面積 | 回歸測試 |
%[text] | --- | --- | --- | --- |
%[text] | 「更精確」的 disk（N=0） | 93 | 189.2 | ✅ 通過——結果真的沒變 |
%[text] | 改用 `imgaussfilt` 估背景 | **94** | **178.8（−5.5%）** | ❌ **抓到** |
%[text] | 改用 `medfilt2` 估背景 | **96** | 184.4 | ❌ **抓到** |
%[text:table]
%[text] 「更精確」那一版結果完全一樣，**但慢 5.6 倍**（90 vs 16 ms）——
%[text] 回歸測試不會告訴你這件事，**效能要另外測**。
%%
%[text] # 7. App：做得很薄
if ipcvFast()
    disp("（快速模式：略過介面測試，約需 16 秒）")
else
    uiResults = runtests(testDir, Name="tGrainAppUI*");
    uiTable = table(uiResults);
    disp(uiTable(:, ["Name" "Passed" "Duration"]))
    fprintf("介面測試 %d 個，平均每個 %.1f 秒\n", numel(uiResults), mean([uiResults.Duration]));
    fprintf("單元測試平均每個 %.3f 秒——**慢 %.0f 倍**\n", ...
        mean([unitResults.Duration]), mean([uiResults.Duration])/mean([unitResults.Duration]));
end
%[text] 某次執行：**介面測試每個約 8 秒，單元測試每個約 0.1–0.3 秒——慢 27–61 倍**（兩次執行）。
%[text] 這就是 `ch29_GrainApp` 刻意做得很薄的原因：
%[text:table]
%[text] | 放在 App 裡 | 放在函式裡 |
%[text] | --- | --- |
%[text] | 元件的建立與排版 | 演算法 |
%[text] | 把欄位值組成 config（`currentConfig`） | 參數驗證 |
%[text] | 把 table 顯示出來 | 錯誤處理、紀錄檔 |
%[text:table]
%[text] > **邏輯放在 callback 裡，就只能用最慢、最脆弱的方式測它。**
%[text] > 放在函式裡，16 個單元測試幾秒就跑完；介面只需要測
%[text] > 「按鈕有沒有接到邏輯」這一件事。
app = ch29_GrainApp(Visible=false, Folder=batchDir);
cfgFromUI = app.currentConfig();
fprintf("\nApp 組出來的 config：Radius=%g MinArea=%g Threshold=%g Folder=%s\n", ...
    cfgFromUI.BackgroundRadius, cfgFromUI.MinArea, cfgFromUI.Threshold, cfgFromUI.InputFolder);
app.run();
fprintf("App 執行完：%s\n", app.StatusLabel.Text);
delete(app);
%[text] **App Designer 還是程式化的 `uifigure`？**
%[text] R2026a 以前，App Designer 只能存成二進位的 `.mlapp`（zip 檔），`git diff` 看不到改了什麼，
%[text] 這是當時選擇程式化 `uifigure` 的主要理由。
%[text] **R2026b 起，App Designer 可以存成純文字**（程式碼 `.m` ＋ 版面設定 `.xml`），
%[text] MATLAB Compiler 也能直接打包這種格式——**版本控制不再是理由**。
%[text]
%[text] 真正重要的理由和檔案格式無關：**把邏輯留在 `ch29_countGrains`，App 只做「讀介面 → 呼叫函式 → 顯示結果」**。
%[text] 上面量到介面測試比單元測試慢 27–61 倍；邏輯寫進 callback，就只能用最慢的方式測它。
%[text] 不論用 App Designer 還是程式化 `uifigure`，這個分工都一樣。
%[text] > R2026b 另外新增 `matlab.unittest.fixtures.UIFigureFixture`，測試結束時自動關掉 UI figure。
%[text] > App Designer 純文字格式與這個 fixture **本章沒有實測**（App Designer 是互動式編輯器，無法在 `-batch` 驗證）。
%%
%[text] # 8. 效能剖析：`profile` 自己也有成本
pipeline = @() regionprops(imopen(imbinarize(imgaussfilt(riceGray, 2)), ...
    strel("disk", 3)), "Area", "Centroid");
pipeline();
t0 = tic; for k = 1:20, pipeline(); end; tPlain = toc(t0)/20;
profile on
t0 = tic; for k = 1:20, pipeline(); end; tProf = toc(t0)/20;
profile off
pinfo = profile("info");
ft = pinfo.FunctionTable;
[~, order] = sort([ft.TotalTime], "descend");
fprintf("不開 profile %.2f ms｜開 profile %.2f ms（%.2f 倍）\n", ...
    tPlain*1000, tProf*1000, tProf/tPlain);
fprintf("\n最花時間的函式：\n");
shown = 0;
for k = order
    nm = string(ft(k).FunctionName);
    if contains(nm, ["Ch29_Main" "run" ">@"]), continue; end
    fprintf("  %-32s %.3f s（%d 次）\n", nm, ft(k).TotalTime, ft(k).NumCalls);
    shown = shown + 1;
    if shown == 6, break; end
end
%[text] **`profile` 找到的熱點裡有 `strel>MakeDiskStrel`**——
%[text] 每一次呼叫都重新建構結構元素。這正是第 23 章 §7.1 用手動計時找到的同一件事。
%[text] > **但 `profile` 會扭曲相對耗時。** 某次執行它讓這條管線慢 1.95 倍，
%[text] > 而一個呼叫 10 萬次小函式的迴圈**慢了 51.6 倍**——
%[text] > 每次函式呼叫都要記帳，所以**小函式在 profile 裡看起來特別貴**。
%[text] > 用 `profile` 找「哪裡可疑」，用 `timeit` 量「真的有多慢」。
%%
%[text] # 9. 目錄與版本控制
%[text] 這套課程本身就是一個例子：
%[text] ```
%[text] ChNN_Topic/
%[text] ├── ChNN_Main.m        ← 教材（純文字 Live Code，git diff 看得懂）
%[text] ├── code/              ← 可重用的函式
%[text] ├── tests/             ← matlab.unittest 測試
%[text] ├── data/datalist.json ← 資料來源與限制的說明
%[text] └── exercise/
%[text] build/verifyChapters.m ← 每一章都能從頭跑完（等於 CI）
%[text] ```
%[text:table]
%[text] | 原則 | 為什麼 |
%[text] | --- | --- |
%[text] | **純文字格式**（Live Script 用 `.m` 而不是 `.mlx`；R2026b 的 App Designer 也可以存純文字） | git 看得懂差異，code review 才有可能 |
%[text] | **設定檔進版本控制，資料不進** | 資料太大，而且常有權限問題；用 `datalist.json` 說明從哪來 |
%[text] | **基準值改了，commit 訊息要寫理由** | 半年後才看得懂為什麼 93 變成 94 |
%[text] | **能從頭跑完**（`verifyChapters`） | 「在我的電腦上可以」不算數 |
%[text:table]
%%
%[text] # 10. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | 以為 `(1,1) double` 會擋錯的型別 | `true`、`"0.5"` 被安靜轉型 | 不寫類別，用 `mustBeNumeric`／`mustBeFloat` |
%[text] | `struct(Name=Value)` 的值是 cell | **得到一個 struct 陣列** | 先建空 struct 再逐欄指定 |
%[text] | JSON 存 NaN／Inf | 讀回來變 `[]` | 存成字串，讀回時轉換 |
%[text] | JSON 存向量 | 方向遺失（都變成行向量） | 讀回時依欄位規格修正 |
%[text] | 忽略不認得的設定欄位 | 拼錯的參數安靜地用預設值 | **報錯，並猜使用者想打什麼** |
%[text] | 空的 `catch` | 整批「成功」，但有檔沒處理 | 記錄每一個失敗 |
%[text] | 回歸測試比整張遮罩 | 無害的改動也失敗 | 比你在意的量，給有根據的容許誤差 |
%[text] | 還沒跑就先填基準值 | 測試一開始就錯 | **先跑、看過、再鎖** |
%[text] | 把基準值當成真值 | 以為「測試通過 = 結果正確」 | 回歸測試只保護行為不變 |
%[text] | 邏輯寫在 callback 裡 | 只能用慢 30–60 倍的介面測試 | App 做薄，邏輯放函式 |
%[text] | 用 `profile` 的數字比較快慢 | 小函式被誇大 50 倍 | 用 `timeit` 確認 |
%[text] | uint8 減法 | 負值截成 0，**不報錯** | 先 `im2double` |
%[text:table]
%%
%[text] # 11. 練習
%[text] 練習在 `exercise/Ch29_Exercise.m`。
%%
%[text] # 12. 延伸閱讀
%[text] - `doc arguments` / `doc mustBeFloat` / `doc mustBeA`
%[text] - `doc jsonencode` / `doc jsondecode`
%[text] - `doc matlab.unittest.TestCase` / `doc runtests`
%[text] - `doc matlab.uitest.TestCase`（`press`、`type`、`choose`）
%[text] - `doc uifigure` / `doc uigridlayout`
%[text] - `doc profile` / `doc timeit`
%[text] - 第 30 章：把這個函式編譯成獨立程式，或產生 C 程式碼

% ========================================================================
% 本章用到的示範函式

function y = noCheckDemo(x, t)
y = x > t;
end

function y = coerceDemo(x, t)
arguments
    x (:,:) {mustBeNumeric}
    t (1,1) double {mustBeInRange(t, 0, 1)}
end
y = x > t;
end

function y = parserDemo(x, t)
p = inputParser;
p.addRequired("x", @isnumeric);
p.addRequired("t", @(v) isscalar(v) && v >= 0 && v <= 1);
p.parse(x, t);
y = x > t;
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
