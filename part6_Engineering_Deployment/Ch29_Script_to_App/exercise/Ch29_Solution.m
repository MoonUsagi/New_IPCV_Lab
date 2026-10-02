%[text] # 第 29 章　練習解答
%[text] {"align":"left"}從腳本到應用程式　｜　MATLAB R2026b
%[text] > 這一章的練習有一個共同主題：**「看起來正常」不等於「是對的」**。
%[text] > 空的 catch 跑出 17 個看起來正常的結果、`(1,1) double` 安靜地接受 `true`、
%[text] > `profile` 讓小函式看起來貴 50 倍。
assert(exist("ch29_countGrains", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
rice = imread("rice.png");
%%
%[text] # 解答 1　三種宣告方式
testValues = {0.5, "0.5", true, int8(1), single(0.5), [], NaN, '0.5'};
Value = strings(numel(testValues),1);
A_double = strings(numel(testValues),1);
B_numeric = strings(numel(testValues),1);
C_mustBeA = strings(numel(testValues),1);
D_noNaN = strings(numel(testValues),1);
for i = 1:numel(testValues)
    v = testValues{i};
    Value(i) = string(class(v)) + " " + mat2str(v);
    A_double(i)  = localTry(@() declA(v));
    B_numeric(i) = localTry(@() declB(v));
    C_mustBeA(i) = localTry(@() declC(v));
    D_noNaN(i)   = localTry(@() declD(v));
end
disp(table(Value, A_double, B_numeric, C_mustBeA, D_noNaN))
%[text] ## 量到的結果
%[text:table]
%[text] | 值 | A `(1,1) double` | B `{mustBeNumeric}` | C `{mustBeA(t,"double")}` |
%[text] | --- | --- | --- | --- |
%[text] | `0.5` | 執行 | 執行 | 執行 |
%[text] | `"0.5"` | **執行（轉型）** | 擋下 | 擋下 |
%[text] | `true` | **執行（轉成 1）** | 擋下 | 擋下 |
%[text] | `int8(1)` | 執行 | 執行 | 擋下 |
%[text] | `single(0.5)` | 執行 | 執行 | **擋下** |
%[text] | `[]` | 擋下 | 擋下 | 擋下 |
%[text] | `NaN` | 執行 | 執行 | 執行 |
%[text] | `'0.5'` | 擋下 | 擋下 | 擋下 |
%[text:table]
%[text] **第 3 小題：C 最嚴格，而且太嚴格了**——它擋掉 `single(0.5)`，
%[text] 而一個門檻參數用 single 傳進來完全合理。
%[text] **B（`mustBeNumeric`）是參數最好的預設**：擋掉 string 與 logical
%[text]（最常見的兩種誤用），接受所有數值型別。
%[text] **第 4 小題：三種都讓 NaN 通過。** `Threshold` 用 NaN 表示「自動」，
%[text] 所以這裡是要的；但 `MinArea = NaN` 會讓 `bwareaopen` 做什麼？
%[text] **那就不是你要的**。D 欄是加了 `mustBeNonNan`（本解答的自寫驗證）的版本。
%[text] **第 5 小題：**
%[text:table]
%[text] | 參數 | 宣告 | 理由 |
%[text] | --- | --- | --- |
%[text] | `BackgroundRadius` | `(1,1) {mustBeNumeric, mustBeInteger, mustBePositive}` | 必須是正整數 |
%[text] | `MinArea` | `(1,1) {mustBeNumeric, mustBeNonnegative}` | `mustBeNonnegative` 本身就擋 NaN |
%[text] | `Threshold` | `(1,1) {mustBeFloat}` + 函式內檢查範圍 | 要允許 NaN |
%[text:table]
%[text] 這就是 `ch29_countGrains` 現在的寫法。
%%
%[text] # 解答 2　你的設定 struct 經得起 JSON 嗎
s = struct();
s.Channels = [1 2 3];
s.Nested   = struct(Sigma=2, Size=[5 5]);
s.People   = struct(Name={"A" "B"}, Age={30 40});   % struct 陣列（刻意用 cell 展開）
s.When     = datetime(2026, 9, 24, 12, 0, 0);
s.Threshold = NaN;
disp(jsonRoundTripReport(s))
%[text:table]
%[text] | 欄位 | 讀回來 |
%[text] | --- | --- |
%[text] | 巢狀 struct | struct，**但裡面的 `[5 5]` 變成 2×1** |
%[text] | struct 陣列（1×2） | **2×1** 的 struct 陣列 |
%[text] | `datetime` | **char**（ISO 格式字串）——**型別完全丟失** |
%[text:table]
%[text] 注意 `s.People` 那一行：**`struct(Name={"A" "B"}, ...)` 會建出 1×2 的 struct 陣列**，
%[text] 這是主教材 §10 陷阱表裡的一條。這裡是刻意的，但在寫設定檔時通常是意外。
cfgFile = fullfile(tempdir, "ch29_ex2.json");
ch29_saveConfig(struct(BackgroundRadius=15, MinArea=50, Threshold=NaN, ...
    InputFolder="images", FilePattern="*.png"), cfgFile);
c = ch29_loadConfig(cfgFile);
fprintf("\nch29_saveConfig/loadConfig 來回之後 Threshold = %g，isnan = %d\n", ...
    c.Threshold, isnan(c.Threshold));

lowerFile = fullfile(tempdir, "ch29_lower.json");
fid = fopen(lowerFile, "w"); fprintf(fid, '{"minArea": 80}'); fclose(fid);
try
    ch29_loadConfig(lowerFile);
catch ME
    fprintf("小寫的 minArea：%s\n", ME.message);
end
%[text] **第 5 小題：`minArea` 被當成不認得的欄位擋下，並且提示「是不是 MinArea？」。**
%[text] **這個處理是對的**——而且比「不分大小寫自動接受」好。
%[text] JSON 本身是大小寫敏感的，其他讀這個檔的程式（Python、JavaScript）
%[text] 會把 `minArea` 和 `MinArea` 當成兩個不同的鍵。
%[text] **擋下來並給提示**，讓使用者修正設定檔本身，而不是讓 MATLAB 默默容忍。
%%
%[text] # 解答 3　空的 catch 有多危險
exDir = fullfile(tempdir, "ch29_ex3");
if isfolder(exDir), rmdir(exDir, "s"); end
mkdir(exDir);
for k = 1:20
    name = fullfile(exDir, sprintf("%02d.png", k));
    if ismember(k, [4 9 15])
        fid = fopen(name, "w"); fwrite(fid, "x"); fclose(fid);
    else
        imwrite(rice, name);
    end
end
f = dir(fullfile(exDir, "*.png"));
names = string(fullfile({f.folder}, {f.name}));

counts = [];
for k = 1:numel(names)
    try
        r = ch29_countGrains(imread(names(k)));
        counts(end+1) = r.Count; %#ok<AGROW>
    catch
    end
end
fprintf("空的 catch：%d 個結果（共 %d 個檔），平均 %.1f 顆，全部都是 %s\n", ...
    numel(counts), numel(names), mean(counts), mat2str(unique(counts)));

[res, fail] = ch29_runBatch(names, struct(BackgroundRadius=15, MinArea=50, Threshold=NaN), Quiet=true);
[~, failNames, failExt] = fileparts(fail.File);
fprintf("ch29_runBatch：%d 成功、%d 失敗：%s\n", height(res), height(fail), ...
    strjoin(failNames + failExt, "、"));
%[text] **第 3 小題：看不出來。** 17 個結果、每個都是 93 顆——一切看起來都很正常。
%[text] 你得**知道應該有 20 個**，而且記得去數，才會發現。
%[text] **第 5 小題：更隱蔽的問題——索引錯位。**
%[text] `counts(end+1)` 只在成功時才增長，所以第 4 個檔失敗之後，
%[text] **`counts(4)` 其實是第 5 個檔的結果**，之後全部往前移一格。
%[text] 如果之後有人寫 `table(names', counts')`（長度不合會報錯，但如果剛好
%[text] 截掉或補齊……），或者用 `counts(k)` 去對 `names(k)`，
%[text] **每一個結果都會被標到錯的檔案上**。
%[text] > 這和第 23 章「只記錄有偵測到的幀，幀號就對不上」是完全同一件事：
%[text] > **失敗的項目也要佔一列**，要嘛記成 NaN，要嘛記到另一張失敗清單。
%%
%[text] # 解答 4　容許誤差要從資料來
base = ch29_countGrains(rice);
baseArea = mean(base.Areas);
perturbed = {};
labels = strings(0,1);
for q = [95 90 80 70 50]
    fn = fullfile(tempdir, "ch29_q.jpg");
    imwrite(rice, fn, Quality=q);
    perturbed{end+1} = imread(fn); %#ok<SAGROW>
    labels(end+1,1) = "JPEG q" + q; %#ok<SAGROW>
end
perturbed{end+1} = single(im2double(rice)); labels(end+1,1) = "single";
for sigma = [1 2 4]
    perturbed{end+1} = imnoise(rice, "gaussian", 0, (sigma/255)^2); %#ok<SAGROW>
    labels(end+1,1) = "雜訊 σ=" + sigma; %#ok<SAGROW>
end
perturbed{end+1} = imresize(imresize(rice, 2, "bilinear"), 0.5, "bilinear");
labels(end+1,1) = "放大再縮回";

CountDelta = zeros(numel(perturbed),1);
AreaDeltaPct = zeros(numel(perturbed),1);
for k = 1:numel(perturbed)
    r = ch29_countGrains(perturbed{k});
    CountDelta(k) = r.Count - base.Count;
    AreaDeltaPct(k) = (mean(r.Areas)/baseArea - 1) * 100;
end
disp(table(labels, CountDelta, AreaDeltaPct, ...
    VariableNames=["擾動" "顆數變化" "平均面積變化%"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 擾動 | 顆數 | 平均面積 |
%[text] | --- | --- | --- |
%[text] | JPEG q95 – q70 | 0 | −0.27% – +0.18% |
%[text] | **JPEG q50** | **+1** | −0.47% |
%[text] | single | 0 | +0.27% |
%[text] | 雜訊 σ = 1–4 | 0 | −0.31% – −0.20% |
%[text] | **放大再縮回** | **−1** | **+1.67%** |
%[text:table]
%[text] **第 3 小題：「無害」擾動的平均面積變化全部在 ±0.5% 以內，**
%[text] **所以 1% 有兩倍的餘裕，不會誤報。**
%[text] **第 4 小題：顆數在 JPEG q50 時變了 1。**
%[text] 但回歸測試跑的是**同一個輸入檔**、測的是**程式改動**，不是輸入的擾動。
%[text] 同一個檔、同一段程式，顆數應該**精確相等**——
%[text] 允許 ±1 會讓「米粒黏在一起被算成一顆」這種真正的回歸溜過去。
%[text] **第 5 小題：「放大再縮回」不是無害的**——雙線性內插做了兩次，
%[text] 影像確實被模糊了，米粒邊緣變寬，平均面積 +1.67%。
%[text] **1% 的容許誤差正好抓到它**，這是對的。
%[text] **第 6 小題：寫進測試註解的那段話**
%[text] > 平均面積的容許誤差 1%：rice.png 在 JPEG q50–q95、single、
%[text] > σ≤4 雜訊下的變化為 −0.47%～+0.27%，1% 有兩倍餘裕；
%[text] > 雙線性放大再縮回（+1.67%）會被抓到，那是真正的影像改變。
%[text] > 顆數用精確相等，因為回歸測試的輸入檔是固定的。
%%
%[text] # 解答 5　用 profile 找熱點，用 timeit 確認
batch = repmat({rice}, 1, 30);
profile on
for k = 1:30, ch29_countGrains(batch{k}); end
profile off
p = profile("info");
ft = p.FunctionTable;
[~, order] = sort([ft.TotalTime], "descend");
total = ft(order(1)).TotalTime;
fprintf("profile 前幾名：\n");
shown = 0;
for k = order
    nm = string(ft(k).FunctionName);
    if contains(nm, ["Ch29_Solution" "run" ">@"]), continue; end
    fprintf("  %-32s %.3f s\n", nm, ft(k).TotalTime);
    shown = shown + 1; if shown == 6, break; end
end
diskIdx = find(string({ft.FunctionName}) == "strel>MakeDiskStrel", 1);
countIdx = find(string({ft.FunctionName}) == "ch29_countGrains", 1);
if ~isempty(diskIdx) && ~isempty(countIdx)
    fprintf("MakeDiskStrel 佔 ch29_countGrains 的 %.1f%%（profile 的說法）\n", ...
        ft(diskIdx).TotalTime / ft(countIdx).TotalTime * 100);
end

t0 = tic; for k = 1:30, ch29_countGrains(batch{k}); end; tEach = toc(t0)/30;
se = strel("disk", 15);
t0 = tic;
for k = 1:30
    g = im2double(batch{k});
    c = g - imopen(g, se);
    bwconncomp(bwareaopen(imbinarize(c, graythresh(c)), 50));
end
tShared = toc(t0)/30;
fprintf("\n實際量測（不開 profile）：每次建構 %.1f ms/張，共用 strel %.1f ms/張，快 %.2f 倍（省 %.0f%%）\n", ...
    tEach*1000, tShared*1000, tEach/tShared, (1 - tShared/tEach)*100);
%[text] ## 第 5 小題：**我預期 profile 會誇大，這次沒有**
%[text:table]
%[text] | 來源 | 預測／量到的加速 |
%[text] | --- | --- |
%[text] | profile：`MakeDiskStrel` 佔 26.8% → 去掉它 | **1.37 倍** |
%[text] | 實測，第一次執行 | 1.35 倍 |
%[text] | 實測，第二次執行 | **1.93 倍** |
%[text:table]
%[text] 我原本寫的是「profile 會誇大小函式，所以比例對不上」——主教材 §8 確實量到
%[text] 小函式迴圈被放大 51.6 倍。**但在這個例子上，profile 的預測和第一次實測幾乎一樣**，
%[text] 反而是**兩次實測之間的差距（1.35 vs 1.93）比 profile 的誤差還大**。
%[text] > **所以真正的結論是：**
%[text] > profile 的誇大程度取決於「熱點裡有多少次小函式呼叫」，不是固定的；
%[text] > 而**單次的 tic-toc 本身就有很大的變異**（第 23 章量到 24–62%）。
%[text] > 要知道「真的值多少」，**要重複量**，不是換一個工具量一次。
%[text] > profile 用來找「哪裡可疑」，重複的 `timeit` 用來確認「值多少」。
%[text] **第 6 小題：`persistent` 快取的風險**
%[text] 快取的 strel 是用**第一次**的 `BackgroundRadius` 建的。
%[text] 之後傳不同的半徑進來，如果快取沒有檢查半徑，**就會安靜地用錯的結構元素**。
%[text] 正確的快取要把參數當成 key：
%[text] ```matlab
%[text] persistent cachedRadius cachedSE
%[text] if isempty(cachedSE) || cachedRadius ~= radius
%[text]     cachedSE = strel("disk", radius);  cachedRadius = radius;
%[text] end
%[text] ```
%[text] 更簡單的做法是**讓批次函式建一次、傳進去**——沒有隱藏狀態，也好測試。
%%
%[text] # 解答 6　改寫你自己的腳本
%[text] 沒有標準答案。檢查清單：
%[text:table]
%[text] | 項目 | 做到了嗎 |
%[text] | --- | --- |
%[text] | 參數是名稱-值引數，宣告用 `mustBeNumeric` 而不是 `double` | |
%[text] | 錯的輸入會報錯，而且訊息指得出問題 | |
%[text] | 回傳一個 struct，裡面記錄了參數 | |
%[text] | 回歸測試的基準值是**跑出來、看過、才寫進去**的 | |
%[text] | 改一行演算法，回歸測試會失敗 | |
%[text] | 容許誤差有依據（練習 4 的方法），寫在測試註解裡 | |
%[text] | 設定檔拼錯欄位會報錯 | |
%[text:table]
%%
%[text] # 加分題解答　參數化測試
paramDir = fullfile(tempdir, "ch29_param_tests");
if isfolder(paramDir), rmdir(paramDir, "s"); end
mkdir(paramDir);
writeParamTest(paramDir);
addpath(paramDir);
cleanupPath = onCleanup(@() rmpath(paramDir));
paramResults = runtests(fullfile(paramDir, "tManyImages.m"));
paramTable = table(paramResults);
disp(paramTable(:, ["Name" "Passed" "Incomplete"]))

fprintf("\n實際顆數：\n");
fprintf("  rice.png          %d\n", ch29_countGrains(rice).Count);
fprintf("  rice 旋轉 90 度    %d\n", ch29_countGrains(imrotate(rice, 90)).Count);
coinsResult = ch29_countGrains(imread("coins.png"));
fprintf("  coins.png         %d（平均面積 %.0f）\n", coinsResult.Count, mean(coinsResult.Areas));
%[text] **第 3 小題：旋轉 90 度的顆數和原圖完全一樣**（93）。
%[text] 90 度旋轉是像素的重新排列，沒有內插，所以結果應該一樣——**量了之後確實一樣**。
%[text] **第 4 小題：`coins.png` 用米粒的參數**——`BackgroundRadius=15` 對
%[text] 直徑 50–60 像素的硬幣太小，背景估計會吃掉硬幣本身。
%[text] 上面量到的顆數是這組參數的行為，**不是「硬幣有幾個」**（這張圖有 10 個硬幣）。
%[text] 參數化測試裡對它的處理是 `assumeFail`：
%[text] > **記錄「已知在這種輸入上不適用」**，測試顯示為 Incomplete 而不是 Passed。
%[text] > 這比刪掉這個案例好——它是文件，告訴下一個人這支函式的適用範圍，
%[text] > 而且哪天有人調好了參數，把 `assumeFail` 拿掉就會開始檢查。

% ========================================================================
% 本解答用到的本地函式

function out = localTry(f)
try
    f();
    out = "執行";
catch
    out = "擋下";
end
end

function declA(t)
arguments, t (1,1) double, end
end
function declB(t)
arguments, t (1,1) {mustBeNumeric}, end
end
function declC(t)
arguments, t (1,1) {mustBeA(t, "double")}, end
end
function declD(t)
arguments, t (1,1) {mustBeNumeric, mustBeNonNanLocal}, end
end
function mustBeNonNanLocal(x)
if any(isnan(x), "all")
    error("ipcv:ch29:nan", "不能是 NaN。");
end
end

% ------------------------------------------------------------------------
function report = jsonRoundTripReport(s)
%JSONROUNDTRIPREPORT 逐欄回報 jsonencode → jsondecode 之後改了什麼。
back = jsondecode(jsonencode(s));
fn = string(fieldnames(s));
Field = fn;
Before = strings(numel(fn),1); After = strings(numel(fn),1); Same = false(numel(fn),1);
for k = 1:numel(fn)
    a = {s.(fn(k))};  b = {back.(fn(k))};
    Before(k) = string(class(a{1})) + " " + mat2str(size(a{1})) + " ×" + numel(s);
    After(k)  = string(class(b{1})) + " " + mat2str(size(b{1})) + " ×" + numel(back);
    Same(k)   = isequal(a, b);
end
report = table(Field, Before, After, Same);
end

% ------------------------------------------------------------------------
function writeParamTest(folder)
%WRITEPARAMTEST 寫出一個參數化測試類別（示範 TestParameter 的寫法）。
lines = [
    "classdef tManyImages < matlab.unittest.TestCase"
    "    properties (TestParameter)"
    "        imageCase = struct( ..."
    "            rice      = {{""rice.png"", 0, 93}}, ..."
    "            riceRot90 = {{""rice.png"", 90, 93}}, ..."
    "            coins     = {{""coins.png"", 0, NaN}});"
    "    end"
    "    methods (Test)"
    "        function countMatchesBaseline(tc, imageCase)"
    "            [file, angle, expected] = imageCase{:};"
    "            if isnan(expected)"
    "                tc.assumeFail(""已知：米粒的預設參數不適用於 "" + file);"
    "            end"
    "            img = imrotate(imread(file), angle);"
    "            tc.verifyEqual(ch29_countGrains(img).Count, expected);"
    "        end"
    "    end"
    "end"
    ];
fid = fopen(fullfile(folder, "tManyImages.m"), "w", "n", "UTF-8");
fprintf(fid, "%s" + newline, lines);
fclose(fid);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
