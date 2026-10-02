%[text] # 第 30 章　部署與系統整合
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[產業\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 判斷一支 MATLAB 函式**能不能產生 C 程式碼**，以及要改哪些地方
%[text] 2. 用 MATLAB Coder 產生 MEX 與 C 函式庫，並**驗證結果和 MATLAB 版一致**
%[text] 3. 知道固定大小／可變大小、以行為主／以列為主這些**介面契約**會在哪裡壞掉
%[text] 4. 匯出與匯入 ONNX 模型，並**用輸出而不是設定欄位**驗證轉換
%[text] 5. 估算 MATLAB ↔ Python、獨立執行檔、MEX 各自的**呼叫成本**
%[text] 6. 用 MATLAB Compiler 打包，並**避免 600 MB 的執行檔**
%[text] 7. 為一個產線場景選擇部署方式，並說出它最可能壞在哪裡
%[text] ## 前置知識
%[text] 第 29 章（`ch29_countGrains`、回歸測試）、第 20 章（深度學習網路）、
%[text] 第 23 章（逐幀處理的時間預算）。
%[text] ## 環境需求
%[text:table]
%[text] | 產品 | 用在 | 沒有時 |
%[text] | --- | --- | --- |
%[text] | MATLAB Coder | §2–§4 | 那幾節只顯示既有量測值 |
%[text] | GPU Coder + CUDA 工具鏈 | §5 | 只顯示檢查結果 |
%[text] | Deep Learning Toolbox + ONNX 轉換器支援包 | §6 | 略過 |
%[text] | Python 3.9–3.12（`pyenv`） | §7 | 略過 |
%[text] | MATLAB Compiler | §8 | 只顯示既有量測值 |
%[text] | Simulink、ROS Toolbox | §9 | 略過 |
%[text:table]
%[text] 所有建置產物都放在 `tempdir`，**不會寫進課程資料夾**；建置過一次之後會重用快取。
%[text] > ## **本章的一句話**
%[text] > **部署不是「把程式搬過去」，是和另一個系統簽一份介面契約——**
%[text] > **影像的大小、型別、記憶體排列、數值範圍、呼叫的頻率。**
%[text] > **契約的每一條都要驗證，因為違反它的時候通常不會報錯。**
assert(exist("ch30_countGrainsCG", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = imread("rice.png");
%%
%[text] # 1. 這一章的位置
%[text] 第 29 章把米粒計數做成了**有介面、有測試**的函式。這一章把它送出 MATLAB：
%[text:table]
%[text] | 目標 | 工具 | 對方需要什麼 | 本章 |
%[text] | --- | --- | --- | --- |
%[text] | 在 MATLAB 裡跑得更快 | MATLAB Coder → **MEX** | MATLAB | §3 |
%[text] | 嵌進 C／C++ 程式、PLC 閘道、嵌入式 | MATLAB Coder → **C 函式庫** | C 編譯器，**不需要 MATLAB** | §4 |
%[text] | NVIDIA GPU／Jetson | GPU Coder → CUDA | CUDA 工具鏈 | §5 |
%[text] | 別的深度學習框架 | **ONNX** 匯出／匯入 | ONNX Runtime、PyTorch… | §6 |
%[text] | Python 團隊 | `pyrun`／MATLAB Engine for Python | 兩邊都要裝 | §7 |
%[text] | 給不會 MATLAB 的人執行 | MATLAB Compiler → **exe** | **MATLAB Runtime**（免費、數 GB） | §8 |
%[text] | 系統模擬、硬體在環、ROS 機器人 | Simulink、ROS Toolbox | — | §9 |
%[text:table]
%[text] > **最大的分水嶺是「對方要不要裝 MATLAB Runtime」。**
%[text] > Coder 產生的 C 不需要；Compiler 產生的 exe 需要。
%[text] > 這決定了能不能上嵌入式、能不能過 IT 的軟體審查、授權怎麼算。
%%
%[text] # 2. Codegen 就緒：第 29 章的函式不能直接編
%[text] 把 `ch29_countGrains` 直接交給 `codegen`（在 `tempdir` 裡做，產物不進課程資料夾）：
coderOK = exist("codegen", "file") > 0 && license("test", "MATLAB_Coder");
if coderOK
    here = pwd;
    cd(tempdir);
    try
        codegen("ch29_countGrains", "-args", {zeros(256, 256, "uint8")});
        disp("（意外：codegen 成功了）")
    catch ME
        fprintf("codegen 失敗（%s）；原因見上方 codegen 印出的訊息\n", ME.identifier);
    end
    cd(here);
end
%[text] 本機的訊息（3.5 秒就失敗）：
%[text] ```
%[text] Code generation does not support function argument validation for
%[text] name-value arguments for entry-point functions.
%[text] Error in ==> ch29_countGrains Line: 1 Column: 19
%[text] ```
%[text] 這不是演算法的問題，是**介面**的問題——C 語言沒有名稱-值引數。
%[text] `ch30_countGrainsCG` 是改寫後的版本。**演算法一行沒改**，改的全是介面：
%[text:table]
%[text] | | `ch29_countGrains` | `ch30_countGrainsCG` | 為什麼 |
%[text] | --- | --- | --- | --- |
%[text] | 參數 | 名稱-值、有預設值 | **位置引數、全部必填** | C 沒有名稱-值與預設值 |
%[text] | 輸入驗證 | `arguments` + `mustBe…` | **`assert`** | MEX 保留 `assert` 的執行期檢查 |
%[text] | 輸入型別 | 任何數值、RGB 自動轉 | **只收 uint8 灰階** | 型別在編譯時固定 |
%[text] | 自動門檻 | `Threshold = NaN` | **`thresholdIn < 0`** | C 裡 `x == NAN` 永遠是 false，呼叫端很容易寫錯 |
%[text] | 輸出 | 一個 struct（含 Mask、Params） | **三個數值輸出** | 讓 C 介面保持簡單 |
%[text] | 錯誤 | 自訂錯誤 ID | `assert` 失敗 | C 沒有例外 |
%[text:table]
%[text] 兩者在 `rice.png` 上必須一致——這是第 29 章回歸測試的延伸：
r29 = ch29_countGrains(I);
[count, areas, threshold] = ch30_countGrainsCG(I, 15, 50, -1);
fprintf("ch29：%d 顆、平均面積 %.4f、門檻 %.4f\n", r29.Count, mean(r29.Areas), r29.Threshold);
fprintf("ch30：%d 顆、平均面積 %.4f、門檻 %.4f\n", count, mean(areas), threshold);
assert(count == r29.Count && isequal(sort(areas(:)), sort(r29.Areas(:))), ...
    "codegen 版和第 29 章的結果不一致。");
%[text] > **改寫介面時，第 29 章的回歸測試就是安全網。** 沒有它，你不會知道改寫有沒有改到行為。
%[text] ## 哪些函式支援 codegen
%[text] 本章用到的 `im2double`、`imopen`、`strel`、`graythresh`、`imbinarize`、
%[text] `bwareaopen`、`bwconncomp` 都支援 C 程式碼生成，但**常有限制**，而且
%[text] **「支援 C」不等於「支援 GPU」**：§5 的 GPU 版本就卡在 `bwconncomp` 的 `PixelIdxList`。
%[text] 每個函式文件頁最下方的 **Extended Capabilities** 會分別列出 C/C++ 與 GPU 的限制。
%[text] > R2026a 的 IPT／CVT 持續擴充了支援 C 與 CUDA 程式碼生成的函式；
%[text] > 動手改寫之前，**先查你的版本的文件頁**，不要憑印象——下一節有一個我自己憑印象猜錯的例子。
%%
%[text] # 3. MEX：先在 MATLAB 裡驗證產生的程式碼
%[text] MEX 是「編譯成 C、再包成 MATLAB 能呼叫的函式」。它的第一個用途**不是加速**，
%[text] 而是**在熟悉的環境裡驗證產生的程式碼行為正確**——之後才放心交出 C 函式庫。
%[text]
%[text] 下面這行第一次執行時要建置約 1 分鐘，之後重用 `tempdir` 裡的快取：
if coderOK
    mexInfo = ch30_buildMex(Kind="fixed");
    fprintf("MEX 建置：成功 %d｜快取 %d｜%.1f 秒｜行程內清除環境變數 %d\n", ...
        mexInfo.Success, mexInfo.Cached, mexInfo.Seconds, mexInfo.EnvWorkaround);
    if ~mexInfo.Success
        disp("建置失敗：" + mexInfo.Message)
    end
    mexOK = mexInfo.Success;
else
    disp("（沒有 MATLAB Coder，§3–§4 只顯示既有量測值）")
    mexOK = false;
end
%[text] 本機兩次建置分別是 56 與 72 秒。
%[text] > **如果看到「'xxx\_mex.bat' 不是內部或外部命令」**：這是環境變數
%[text] > `NoDefaultCurrentDirectoryInExePath` 造成的（某些終端機與安全工具會設）。
%[text] > 它讓 cmd 不在當前資料夾找批次檔，**連 `y = x + 1` 都編不過**，而 `mex hello.c` 卻正常。
%[text] > `ch30_buildMex` 只在 MATLAB 行程內把它清掉，不改系統設定。
%[text] ## 結果一致嗎
tMatlab = NaN; tMex = NaN;
if mexOK
    [cM, aM, tM] = ch30_countGrainsCG_mex(I, 15, 50, -1);
    fprintf("MATLAB：%d 顆、門檻 %.6f\n", count, threshold);
    fprintf("MEX   ：%d 顆、門檻 %.6f、面積最大差 %g\n", cM, tM, max(abs(areas - aM)));
    if ipcvFast()
        disp("（快速模式：略過計時，見下方既有量測值）")
    else
        tMatlab = timeit(@() ch30_countGrainsCG(I, 15, 50, -1), 3);
        tMex    = timeit(@() ch30_countGrainsCG_mex(I, 15, 50, -1), 3);
        fprintf("MATLAB %.2f ms｜MEX %.2f ms｜%.2f 倍\n", tMatlab*1e3, tMex*1e3, tMatlab/tMex);
    end
end
%[text] 本機實測：**結果完全一致**（面積最大差 0）。三次量 256×256：19.03 vs 10.41 ms（1.83 倍）、
%[text] 13.48 vs 8.28 ms（1.63 倍）、9.89 vs 7.83 ms（1.26 倍）。
%[text] > **大約 1.3–1.8 倍，不是 10 倍，而且每次量都不一樣。** `imopen`、`graythresh` 這些函式在 MATLAB 裡
%[text] > 本來就是編譯過的最佳化程式碼；MEX 省下的主要是**函式之間的 MATLAB 直譯開銷**。
%[text] > 迴圈多、純量運算多的程式碼才會有大幅加速。練習 2 量加速怎麼隨影像大小變化。
%[text] ## 我猜錯的一件事：結構元素的半徑
%[text] 我原本以為 `strel("disk", r)` 的半徑在 codegen 裡必須是**編譯時期常數**，
%[text] 準備在教材裡寫「`backgroundRadius` 在 C 介面裡看起來能改、其實不能」。量一次：
if mexOK
    for r = [5 10 15 25]
        [nM, ~, ~] = ch30_countGrainsCG(I, r, 50, -1);
        [nX, ~, ~] = ch30_countGrainsCG_mex(I, r, 50, -1);
        fprintf("半徑 %2d：MATLAB %d 顆｜MEX %d 顆\n", r, nM, nX);
    end
end
%[text] 四個半徑 MEX 都和 MATLAB 一致（半徑 5 是 90 顆，其餘 93 顆）。產生的 C 程式碼裡
%[text] 是 `strel_strel(backgroundRadius, …)`——**在執行時建立結構元素**。我的印象是錯的。
%[text] > **「codegen 不支援 X」要用這一版的 codegen 驗證，不要用印象。**
%[text] ## 固定大小：契約寫在編譯時
%[text] 建置時用 `-args {zeros(256,256,"uint8"), ...}` 告訴 codegen 輸入的樣子。
%[text] **這個例子就是契約**：
if mexOK
    tryCall("128×128 的影像", @() ch30_countGrainsCG_mex(I(1:128,1:128), 15, 50, -1));
    tryCall("double 影像",     @() ch30_countGrainsCG_mex(im2double(I), 15, 50, -1));
    tryCall("threshold = 2",   @() ch30_countGrainsCG_mex(I, 15, 50, 2));
end
%[text:table]
%[text] | 呼叫 | MEX 的反應 |
%[text] | --- | --- |
%[text] | 128×128 | **報錯**：expected \[256x256\] but found \[128x128\] |
%[text] | double | **報錯**：expected 'uint8' but found 'double' |
%[text] | `threshold = 2` | `assert` 失敗——**MEX 保留了 `assert` 的執行期檢查** |
%[text:table]
%[text] > MEX 會報錯是好事。**產生的 C 函式庫不會**——打開 `ch30_lib/ch30_countGrainsCG.c`，
%[text] > 五個 `assert` **一個都不在**：`coder.config("lib")` 預設不產生執行期檢查，
%[text] > 函式一開始就直接做 `image[i] / 255.0`。`thresholdIn = 2` 在 C 裡會安靜地執行（§4 實測）。
%[text] > **MEX 通過的檢查，不代表 C 呼叫端也受到保護。** §4 用一支真正的 C 程式示範另外兩種不報錯的錯。
%%
%[text] # 4. 可變大小與 C 函式庫
%[text] ## 可變大小
%[text] `coder.typeof(uint8(0), [4096 4096], [true true])` 表示「最大 4096×4096、兩維都可變」：
varOK = false;
if coderOK
    varInfo = ch30_buildMex(Kind="variable");
    fprintf("可變大小 MEX：成功 %d｜快取 %d｜%.1f 秒\n", varInfo.Success, varInfo.Cached, varInfo.Seconds);
    varOK = varInfo.Success;
end
if varOK
    small = I(1:128, 1:128);
    [cV, aV] = ch30_countGrainsCG_var_mex(small, 15, 50, -1);
    [cS, aS] = ch30_countGrainsCG(small, 15, 50, -1);
    fprintf("128×128：MATLAB %d 顆｜可變大小 MEX %d 顆｜面積一致 %d\n", cS, cV, isequal(aS, aV));
    [cV2, ~] = ch30_countGrainsCG_var_mex(I, 15, 50, -1);
    fprintf("256×256：可變大小 MEX %d 顆\n", cV2);
end
%[text] 本機：建置 56–64 秒，左上角 128×128 得到 31 顆（和 MATLAB 一致），
%[text] 256×256 每次 10.95 ms（固定大小是 10.41 ms，可變大小在速度上幾乎沒有代價）。
%[text] > 可變大小的代價主要在**記憶體**：產生的程式碼要動態配置，
%[text] > 對「不能用 malloc」的嵌入式目標就不行。那時要回到固定大小、或設上限。
%[text] ## C 函式庫：交給別人的東西長什麼樣
libOK = false;
if coderOK
    libInfo = ch30_buildMex(Kind="lib");
    fprintf("C 函式庫：成功 %d｜快取 %d｜%.1f 秒｜%d 個 .c 檔、共 %d 行\n", ...
        libInfo.Success, libInfo.Cached, libInfo.Seconds, libInfo.NumCFiles, libInfo.NumCLines);
    disp("介面：" + libInfo.Signature)
    libOK = libInfo.Success;
end
%[text] 本機：建置 64–74 秒，22 個 `.c`、24 個 `.h`、約 7734 行。介面是：
%[text] ```c
%[text] extern void ch30_countGrainsCG(const unsigned char image[65536],
%[text]                                double backgroundRadius, double minArea,
%[text]                                double thresholdIn, double *count,
%[text]                                emxArray_real_T *areas, double *threshold);
%[text] ```
%[text:table]
%[text] | 看到的 | 意思 | 會壞在哪 |
%[text] | --- | --- | --- |
%[text] | `image[65536]` | **大小寫死**（256×256），C 不檢查陣列長度 | 傳別的大小：**不報錯**（下面實測） |
%[text] | 沒有寬、高參數 | 維度只存在建置時的 `-args` 裡 | 呼叫端要從文件知道 |
%[text] | `image` 是**以行為主** | MATLAB 的記憶體排列 | C／OpenCV 的緩衝區以列為主，**函式看到轉置的影像**（下面實測） |
%[text] | `emxArray_real_T *areas` | 可變長度輸出，MATLAB Coder 的動態陣列型別 | 呼叫端要用 `emxInitArray_real_T`／`emxDestroyArray_real_T` 管理記憶體 |
%[text:table]
%[text] ## 交付包：產生的 C 並不是「只有 C」
%[text] 第一次直接在 codegen 的資料夾裡編一支 C 主程式，失敗在：
%[text] ```
%[text] rtwtypes.h(38): fatal error C1083: 'tmwtypes.h': No such file or directory
%[text] ```
%[text] **產生的程式碼依賴 MATLAB 安裝目錄裡的檔案。** 對方的電腦沒有 MATLAB，
%[text] 只把 codegen 資料夾複製過去就會漏。`packNGo` 依建置資訊把所有依賴收成一個 zip：
cprogOK = false;
if libOK
    cprog = ch30_buildCProgram();
    cprogOK = cprog.Success;
    if cprogOK
        fprintf("交付包 %.0f KB｜%d 個檔｜其中 %d 個 DLL｜包含 tmwtypes.h：%d\n", ...
            cprog.ZipKB, cprog.NumFiles, cprog.NumDLL, cprog.HasTmwtypes);
        disp("DLL：" + strjoin(cprog.DLLs(1:min(6, end)).', "、") + "…")
    else
        disp("C 程式建置失敗：" + cprog.Message)
    end
end
%[text] 本機：交付包 11.6 MB、94 個檔，**其中 20 個是 DLL**（libmwmorphop\_\*、libmwipp、TBB、boost…）。
%[text]
%[text] 原因：以「MATLAB 主機」為目標產生程式碼時，`imopen`、`graythresh` 等函式
%[text] 會呼叫 **MathWorks 預先編譯、針對主機最佳化的共用函式庫**
%[text]（22 個 `.c` 裡有 3 個——`graythresh.c`、`imdilate.c`、`imopen.c`——引用了 `libmw`）。
%[text] 所以這支「不需要 MATLAB 的 C 程式」**需要這 20 個 DLL 放在旁邊，而且只能在 Windows x64 上跑**。
%[text]
%[text] 把硬體目標改成 ARM（`cfg.HardwareImplementation.ProdHWDeviceType = "ARM Compatible->ARM Cortex-A"`）
%[text] 再產生一次，本機實測：**32 個 `.c`、17566 行，沒有任何檔案引用 `libmw`**——
%[text] 可攜的純 C，代價是程式碼多了 2.3 倍（最佳化函式庫的功能改成展開的 C）、建置 85 秒。
%[text] > **「Coder 產生的 C 不需要 MATLAB」只在你選對目標時成立。**
%[text] > 交付前用 `packNGo` 打包，並在**一台沒有 MATLAB 的乾淨機器上**編譯、執行一次。
%[text] ## 一支真正的 C 呼叫端
%[text] `ch30_buildCProgram` 在解壓後的交付包裡寫了一支 `grain_main.c`，只用包裡的檔案編譯。
%[text] 它**刻意像一般的 C 呼叫端**：直接把檔案的前 65536 個位元組當成 `image[65536]`。
%[text] 準備三個檔：以行為主（MATLAB 的排列）、以列為主（C／OpenCV 的排列）、512×512 的影像：
if cprogOK
    rawDir = fullfile(tempdir, "ch30_raw");
    if ~isfolder(rawDir), mkdir(rawDir); end
    It = I.';
    big = imresize(I, 2);
    rawFiles = [fullfile(rawDir, "colmajor.raw"), fullfile(rawDir, "rowmajor.raw"), fullfile(rawDir, "big512.raw")];
    rawData = {I(:), It(:), big(:)};
    for k = 1:3
        fid = fopen(rawFiles(k), "w");
        fwrite(fid, rawData{k}, "uint8");
        fclose(fid);
    end
    labels = ["以行為主 256×256", "以列為主 256×256", "以行為主 512×512"];
    cRunMs = zeros(1, 3);
    for k = 1:3
        t0 = tic;
        [status, out] = system(sprintf('"%s" "%s"', cprog.ExeFile, rawFiles(k)));
        cRunMs(k) = toc(t0) * 1e3;
        fprintf("%-16s → 結束碼 %d｜%s｜%.0f ms\n", labels(k), status, strtrim(out), cRunMs(k));
    end
    [status, out] = system(sprintf('"%s" "%s" 2', cprog.ExeFile, rawFiles(1)));
    fprintf("門檻 = 2（MEX 會被 assert 擋下）→ 結束碼 %d｜%s\n", status, strtrim(out));
    [~, aT, ~] = ch30_countGrainsCG(It, 15, 50, -1);
    fprintf("對照：MATLAB 上 I 的第一顆面積 %d，I.' 的第一顆面積 %d\n", areas(1), aT(1));
end
%[text] 本機實測：
%[text:table]
%[text] | 輸入檔 | 顆數 | 門檻 | 第一顆面積 | 報錯？ |
%[text] | --- | --- | --- | --- | --- |
%[text] | 以行為主 256×256 | 93 | 0.192157 | 138 | 否 |
%[text] | **以列為主** 256×256 | **93** | **0.192157** | **61** | **否** |
%[text] | **512×512**（262144 位元組） | **60** | 0.207843 | 558 | **否** |
%[text:table]
%[text] 三件事：
%[text] 1. **C 程式的結果和 MATLAB 完全一致**（93 顆、門檻 0.192157、第一顆 138）。
%[text]    整個程式執行一次約 90–200 ms（含行程啟動），**不需要 MATLAB Runtime**。
%[text] 2. **以列為主的緩衝區：顆數和門檻都一樣，只有第一顆的面積不同**（61 = MATLAB 上 `I.'` 的第一顆）。
%[text]    函式確實看到了轉置的影像，但**這支函式的主要輸出對轉置免疫**——
%[text]    `imopen` 的圓盤、Otsu、連通區域計數都不管方向。**只驗顆數的整合測試抓不到這個錯**（練習 3）。
%[text] 3. **512×512 的檔：60 顆、沒有任何錯誤**。函式讀了前 65536 個位元組——
%[text]    那是大圖**最左邊的 128 行**，每一行被切成上下兩半、交錯排成 256×256
%[text]    （在 MATLAB 裡 `reshape(big(1:65536), 256, 256)` 也得到 60 顆）。**C 的介面沒有辦法知道自己被騙了。**
%[text] > **固定大小與記憶體排列都是呼叫端的責任。** 交出 C 函式庫時，要附一個
%[text] > **會被轉置影響的測試向量**（例如每顆的質心，或一張不對稱的測試圖）。
%%
%[text] # 5. GPU Coder：正確，但慢
%[text] GPU Coder 把 MATLAB 程式碼轉成 CUDA。先檢查環境：
gpuOK = ~isempty(which("coder.checkGpuInstall")) && license("test", "GPU_Coder");
if gpuOK
    try
        g = gpuDevice;
        fprintf("GPU：%s｜%.2f GB｜Compute Capability %s\n", g.Name, g.TotalMemory/1e9, g.ComputeCapability);
        envCheck = coder.gpuEnvConfig("host");
        envCheck.BasicCodegen = 1;
        envCheck.Quiet = 1;
        disp(coder.checkGpuInstall(envCheck))
    catch ME
        gpuOK = false;
        disp("（GPU 環境無法使用：" + ME.message + "）")
    end
else
    disp("（沒有 GPU Coder，見下方既有量測值）")
end
%[text] 本機：NVIDIA T550 Laptop GPU（4 GB、CC 7.5）、CUDA 12.1。`gpu`、`cuda`、`hostcompiler`、
%[text] `basiccodegen` 通過；**cuDNN、TensorRT 沒有安裝**，所以深度學習網路的 GPU 碼生成本章沒有實測。
%[text] ## 第一關：C 能編的，GPU 不一定能
%[text] 把 `ch30_countGrainsCG` 交給 `coder.gpuConfig("mex")`，失敗在：
%[text] ```
%[text] Invalid structure field 'PixelIdxList'.
%[text] ```
%[text] **GPU 碼生成的 `bwconncomp` 不提供 `PixelIdxList`**。`ch30_countGrainsGPU` 改用 `bwlabel`
%[text] 再逐像素累加面積（在 MATLAB 裡結果和 `ch30_countGrainsCG` 完全相同）。
%[text] ## 第二關：建得出來，但比 MATLAB 慢
%[text] 下面只在**已經建置過**時執行（GPU 建置一次 3–6 分鐘）。
%[text] 要建置請先 `setenv("IPCV_CH30_GPU_BUILD", "1")`：
if gpuOK
    gpuInfo = ch30_buildGpuMex(Build=getenv("IPCV_CH30_GPU_BUILD") == "1");
    if gpuInfo.Success
        [cG, aG, tG] = ch30_countGrainsGPU_mex(I, 15, 50, -1);
        fprintf("GPU MEX：%d 顆、門檻 %.6f、面積與 MATLAB 一致 %d\n", cG, tG, isequal(aG, areas));
        t0 = tic; ch30_countGrainsGPU_mex(I, 15, 50, -1); tGpu = toc(t0);
        t0 = tic; ch30_countGrainsCG(I, 15, 50, -1); tCpu = toc(t0);
        fprintf("GPU MEX 一次 %.0f ms｜MATLAB 一次 %.0f ms\n", tGpu*1e3, tCpu*1e3);
        tryCall("半徑改成 10", @() ch30_countGrainsGPU_mex(I, 10, 50, -1));
    else
        disp("（沒有 GPU MEX 快取：" + gpuInfo.Message + "）")
    end
end
%[text] 本機實測（結果**每一種都和 MATLAB 完全一致**，差的只是時間）：
%[text:table]
%[text] | 版本 | 建置 | 256×256 每次 | 2048×2048 每次 |
%[text] | --- | --- | --- | --- |
%[text] | MATLAB（對照） | — | 11 ms | 443 ms |
%[text] | 前處理，**半徑寫死在程式碼**、固定大小 | 56 秒 | **約 1 ms** | — |
%[text] | 前處理，**半徑當參數**、固定大小 | 345 秒 | **102 秒** | — |
%[text] | 完整函式，半徑當參數、固定大小 | 339 秒 | 47–56 秒 | — |
%[text] | 完整函式，半徑可變、**可變大小** | 334 秒 | 50 秒 | — |
%[text] | 完整函式，**半徑用 `coder.Constant(15)`**、可變大小 | 174 秒 | **1.5 秒** | **12.3 秒** |
%[text:table]
%[text] 三件事：
%[text] 1. **執行期才知道的結構元素半徑，在 GPU 上讓前處理從 1 ms 變成 102 秒**（約 10 萬倍）。
%[text]    §3 在 CPU MEX 上量到同樣的寫法完全沒問題——**同一行程式碼，換一種 codegen 代價完全不同**。
%[text] 2. 用 `coder.Constant(15)` 把半徑固定之後，**呼叫時還是要傳 15**，傳 10 會報
%[text]    「Run-time value of constant argument … must be the same as value at code generation time」。
%[text]    這個「參數」其實已經不能改了——介面上要寫清楚，或乾脆拿掉。
%[text] 3. 即使半徑固定，完整函式仍比 MATLAB **慢 140 倍（256²）到 28 倍（2048²）**。
%[text]    建置時 GPU Coder 自己提出警告：「GPU code generation for Variable input sizes is not optimized」；
%[text]    函式裡還有**有資料相依的迴圈**（標記、面積累加）不能平行化。
%[text]    這兩個因素各佔多少，**我沒有再拆開驗證**。
%[text] > **GPU 不是「編了就快」。** 米粒計數這種「一次形態學 + 連通區域」的小管線，
%[text] > 資料搬移與序列化的部分就吃掉所有好處。GPU Coder 最適合的是**大量逐像素、無資料相依**
%[text] > 的運算，以及深度學習推論（需要 cuDNN／TensorRT）。
%[text] > **先量表中第二列那樣的「純逐像素段」能不能快，再決定哪一段放 GPU。**
%%
%[text] # 6. ONNX：和其他深度學習框架交換模型
%[text] ONNX 是深度學習模型的交換格式。R2026a 的路線：
%[text:table]
%[text] | 方向 | 函式 |
%[text] | --- | --- |
%[text] | MATLAB → ONNX | `exportONNXNetwork` |
%[text] | ONNX → MATLAB | `importNetworkFromONNX` |
%[text] | PyTorch → MATLAB | `importNetworkFromPyTorch`（需先用 `torch.jit.trace` 存檔） |
%[text] | MATLAB → TensorFlow | `exportNetworkToTensorFlow` |
%[text:table]
%[text] 拿第 20 章用過的 squeezenet 做一次匯出再匯入，**比較輸出**：
onnxOK = exist("exportONNXNetwork", "file") > 0 && exist("importNetworkFromONNX", "file") > 0;
if onnxOK
    onnx = ch30_onnxRoundTrip();
    fprintf("ONNX 檔 %.2f MB｜匯出 %.1f 秒｜匯入 %.1f 秒\n", ...
        onnx.FileMB, onnx.ExportSeconds, onnx.ImportSeconds);
    fprintf("輸入正規化：原本 %s → 匯入後 %s\n", ...
        onnx.OriginalNormalization, onnx.ImportedNormalization);
    fprintf("輸出：原本 %s %s → 匯入後 %s %s（需要轉置 %d）\n", ...
        onnx.OriginalDims, mat2str(onnx.OriginalSize), ...
        onnx.ImportedDims, mat2str(onnx.ImportedSize), onnx.NeededTranspose);
    fprintf("對齊後最大差 %g｜top-1 一致 %d/%d\n", ...
        onnx.MaxAbsDiff, onnx.Top1Agreement, onnx.NumImages);
    fprintf("匯入時自動產生的自訂層檔案：%d 個（%s）\n", numel(onnx.CustomLayerFiles), ...
        strjoin(onnx.CustomLayerFiles, "、"));
else
    disp("（沒有 ONNX 轉換器支援包，略過）")
end
%[text] ## 第一件事：看起來掉了，其實沒有
%[text] 原網路的輸入層正規化是 `zerocenter`（減掉 ImageNet 平均值 104–123），
%[text] 匯入後變成 `none`。**我原本以為正規化在轉換中遺失了**——
%[text] 如果是這樣，所有輸入都差了約 115，輸出會完全不同。
%[text]
%[text] 實測：**輸出最大差 0，top-1 8/8 一致。** 正規化被轉成網路裡的一個減法運算，沒有遺失。
%[text] > **看設定欄位下結論是錯的，比輸出才是對的。**
%[text] ## 第二件事：類別那一維換了位置
%[text] 原網路輸出是 `CB`（類別 × 批次，1000×8），匯入後是 **`UU`（沒有標籤）而且是 8×1000**。
%[text] 下游如果照原本的寫法取類別：
if onnxOK
    dX = dlarray(single(imresize(I, onnx.InputSize(1:2))) .* ones(1,1,3,2, "single"), "SSCB");
    yImp = extractdata(predict(onnx.ImportedNetwork, dX));
    [~, wrong] = max(yImp, [], 1);
    fprintf("2 張影像的批次，照原寫法 max(y,[],1) 得到 %d 個「類別」\n", numel(wrong));
end
%[text] > **不報錯，只是答案全錯。** 維度標籤 `U` 表示「不知道這一維是什麼」——
%[text] > 轉換器無法保證語意，這個責任回到你身上。練習 4 寫一個不會猜錯的 `safeTop1`。
%[text] ## 第三件事：匯入的網路不是自足的物件
%[text] `importNetworkFromONNX` 遇到 MATLAB 沒有對應內建層的運算時，會在**當前資料夾**
%[text] 產生一個自訂層套件（這裡是 `+ch30_net`）。第一版的 `ch30_onnxRoundTrip` 在 `tempdir` 裡匯入、
%[text] 離開後套件就不在路徑上，下一次 `predict` 失敗在：
%[text] ```
%[text] Method 'predict' is not defined for class 'ch30_net.Transpose_To_ReshapeLayer1000'
%[text] ```
%[text] > **把匯入的網路存成 .mat 交給別人，對方沒有那個套件資料夾就跑不起來。**
%[text] > 部署匯入的模型時，套件資料夾要**一起**放進專案（或打包）。
%[text] ## 沒有驗證的部分
%[text] - **PyTorch 匯入**：本機的 Python 沒有 `torch`，無法產生 TorchScript 檔，
%[text]   `importNetworkFromPyTorch` 沒有實測。
%[text] - **TensorFlow 匯出**：`exportNetworkToTensorFlow` 產生 Python 套件，
%[text]   需要 TensorFlow 才能驗證，本機沒有。
%[text] - **ONNX Runtime 推論**：本機沒有 `onnxruntime`，只驗證了 MATLAB 自己的來回。
%[text] > **真正的驗證是在目標框架裡跑同一組輸入、比輸出。** 只在 MATLAB 裡來回一次，
%[text] > 證明的是「MATLAB 讀得回自己寫的 ONNX」，不是「ONNX Runtime 的結果一樣」。
%%
%[text] # 7. MATLAB ↔ Python（與 OpenCV）
%[text] 兩個方向：
%[text] - **MATLAB 呼叫 Python**：`pyrun`、`pyrunfile`、`py.模組.函式`（本節）
%[text] - **Python 呼叫 MATLAB**：MATLAB Engine API for Python（需要對方裝 MATLAB），
%[text]   或用 MATLAB Compiler SDK 把函式包成 Python 套件（需要 MATLAB Runtime）
%[text]
%[text] 本節**不會改動 `pyenv` 的設定**（那是持久的偏好設定）。
pyInfo = ch30_pythonBridge();
if pyInfo.Available
    fprintf("Python %s｜執行模式 %s｜有 numpy %d\n", ...
        pyInfo.Version, pyInfo.ExecutionMode, pyInfo.HasNumpy);
    disp(pyInfo.TypeMap)
else
    disp("（這台機器沒有可用的 Python：" + pyInfo.Message + "）")
end
%[text] 本機：Python 3.10（MathWorks 附的獨立版本），**沒有 numpy**，執行模式 `OutOfProcess`。
%[text:table]
%[text] | MATLAB | 到 Python 變成 | 注意 |
%[text] | --- | --- | --- |
%[text] | double 純量 | `float` | |
%[text] | int32 純量 | `int` | |
%[text] | 向量、矩陣 | **`memoryview`** | 沒有 numpy 時不是 list，也不是陣列 |
%[text] | string、char | `str` | |
%[text] | logical | `bool` | |
%[text] | cell | **`tuple`** | 不是 list，不能改 |
%[text] | struct | `dict` | |
%[text:table]
%[text] ## 最重要的數字：一次呼叫的成本
if pyInfo.Available
    fprintf("逐次呼叫 %d 次：每次 %.1f ms\n", 300, pyInfo.PerCallMs);
    fprintf("同樣的 300 次在一個 pyrun 裡跑完：%.1f ms（快 %.0f 倍）\n", ...
        pyInfo.InsideMs, 300 * pyInfo.PerCallMs / pyInfo.InsideMs);
end
%[text] 本機兩次執行：每次呼叫 **14–16 ms** 與 **25–31 ms**（看機器當時的負載），
%[text] 而把 300 次迴圈放進**一個** `pyrun` 只要 24–31 ms——**和一次呼叫差不多**。
%[text]
%[text] 資料量呢？傳 1×1 是 26.2 ms，傳 1024×1024 的 double（8.4 MB）是 31.9 ms。
%[text] > **成本在跨邊界的次數，不在資料量，也不在運算。**
%[text] > `OutOfProcess` 模式下 Python 跑在另一個行程，每次呼叫都要跨行程通訊。
%[text] > **把迴圈搬到邊界的同一側**——每張影像呼叫一次 Python 做後處理，
%[text] > 30 fps 的串流每幀只有 33 ms，光是呼叫開銷就吃掉 42–93%。
%[text] ## 數值的坑
if pyInfo.Available
    big = pyrun("b_ = 2**53 + 1", "b_");
    fprintf("Python 的 2**53+1 → MATLAB 類別 %s\n", class(big));
    fprintf("  轉 double：%.0f（錯了 1）\n", double(big));
    fprintf("  轉 int64 ：%d（對）\n", int64(big));
    layout = pyrun("l_ = x_.tolist()", "l_", x_=[1 2 3; 4 5 6]);
    fprintf("[1 2 3; 4 5 6] 在 Python 端 tolist()：%s\n", string(py.builtins.str(layout)));
end
%[text] - Python 的整數回到 MATLAB 是 **`py.int` 物件**，不會自動變成數字；
%[text]   轉 `double` 在超過 $2^{53}$ 時**安靜地失去精度**，要用 `int64`。
%[text] - 矩陣的列與行順序**是對的**：MATLAB 傳出的 `memoryview` 帶著正確的形狀與步幅
%[text]   （`f_contiguous = True`）。**沒有 numpy 時我無法驗證 numpy 端的行為**——
%[text]   接到 numpy 之後，要用一個**不對稱**的矩陣再驗一次（練習 5）。
%[text] ## OpenCV
%[text] 本機**沒有安裝** Computer Vision Toolbox Interface for OpenCV in MATLAB，
%[text] Python 端也沒有 `cv2`，所以本章**沒有實測 OpenCV 互通**。要整合時的兩條路：
%[text:table]
%[text] | 路線 | 做法 | 要驗證的 |
%[text] | --- | --- | --- |
%[text] | OpenCV Interface 支援包 | 用 C++ 寫 MEX，呼叫 OpenCV | `cv::Mat` 是**以列為主、BGR**；支援包提供轉換函式 |
%[text] | 透過 Python | `pyrun` 呼叫 `cv2` | 需要 numpy；**BGR 與 RGB**、以列為主 |
%[text:table]
%[text] > OpenCV 的兩個契約——**BGR 通道順序**與**以列為主**——和 §4 的轉置、§9 的 ROS `bgr8`
%[text] > 是同一類問題。**§9 在 ROS 上實測了通道順序會怎麼錯。**
%%
%[text] # 8. MATLAB Compiler：獨立執行檔
%[text] MATLAB Compiler 把 MATLAB 程式打包成 exe，**執行時需要 MATLAB Runtime**
%[text]（免費、版本必須和打包的 MATLAB 一致、安裝檔數 GB）。
%[text]
%[text] 打包的是 `ch30_grainCLI`——命令列版的介面層：讀檔名、呼叫演算法、印結果、
%[text] 失敗時用**非零結束碼**讓呼叫端（排程器、閘道程式）知道。
compilerOK = ~isempty(which("compiler.build.standaloneApplication"));
if compilerOK
    exeInfo = ch30_buildStandalone();
    fprintf("exe %.2f MB｜建置 %.1f 秒（快取 %d）｜執行一次 %.1f 秒\n", ...
        exeInfo.ExeMB, exeInfo.BuildSeconds, exeInfo.Cached, exeInfo.RunSeconds);
    fprintf("輸出：%s\n", exeInfo.Output);
    fprintf("包進去的支援包：%d 個\n", numel(exeInfo.SupportPackages));
else
    disp("（沒有 MATLAB Compiler，見下方既有量測值）")
end
%[text] ## 第一個陷阱：619.8 MB
%[text] 第一次打包用了預設設定：
%[text:table]
%[text] | 選項 | exe 大小 | 建置時間 |
%[text] | --- | --- | --- |
%[text] | 預設（`SupportPackages` 自動偵測） | **619.8 MB** | 66.7 秒 |
%[text] | **`SupportPackages="none"`** | **1.45 MB** | 17–21 秒 |
%[text:table]
%[text] 自動偵測把 **Hyperspectral Imaging Library、Circle Detection 模型、Segment Anything Model**
%[text] 全部包了進去——一支只用 `imopen`、`imbinarize` 的程式，**大了 427 倍，全是沒用到的模型權重**。
%[text] 打包時還出現一個警告：Circle Detection 裡有一個「無法部署」的符號。
%[text] > **打包之後第一個要看的是 `includedSupportPackages.txt`**，不是 exe 能不能跑。
%[text] > 在建置腳本裡明確寫 `SupportPackages="none"`（或列出真正需要的支援包）。
%[text] > 風險是**漏包**：真的需要的支援包沒包進去，要到執行時才報錯——
%[text] > 所以建置之後要**在乾淨的機器上跑一次回歸測試**（加分題）。
%[text] ## 第二個陷阱：程式碼裡的檔名字串
%[text] 第一版 `ch30_grainCLI` 在沒有引數時預設讀內建影像，打包時出現：
%[text] ```
%[text] Warning: Excluded: …\toolbox\images\imdata\rice.png
%[text] Reason: Not supported in the MATLAB Runtime environment.
%[text] ```
%[text] **相依性分析把程式碼裡的檔名字串當成要打包的檔案。** 改成沒有引數時印用法、
%[text] 以結束碼 2 離開之後，警告消失。部署版的程式**不應該假設任何檔案在固定位置**。
%[text] ## 第三個陷阱：每次執行要 18–24 秒
%[text] 運算本身約 20 ms，其餘**全是 MATLAB Runtime 的啟動**。
%[text] > **「每張影像啟動一次 exe」在產線上不可行。** 替代做法：
%[text] > - exe **一次處理一整批**（第 29 章的 `ch29_runBatch`）
%[text] > - 讓程式**常駐**，透過檔案、TCP 或佇列接工作（§10）
%[text] > - **MATLAB Production Server**：Runtime 常駐在伺服器上，用 HTTP 呼叫
%[text] > - 用 Coder 產生不需要 Runtime 的 C（§4：整支 C 程式連行程啟動一次約 0.1–0.2 秒）
%[text] ## R2026a 的注意事項
%[text] R2026a 起，多個**訓練偵測器、估計參數**的函式**將移除 MATLAB Compiler 支援**。
%[text] 實務上的意思：
%[text] - 「讓使用者在打包好的 App 裡自己重新訓練偵測器」這種設計要重新檢查
%[text] - **訓練留在 MATLAB 裡**，部署的只有推論——`trainXXX` 產生模型存檔，部署程式只載入與 `detect`
%[text] - 需要在目標端推論時，考慮 Coder／GPU Coder 路線或 ONNX
%[text]
%[text] 確切受影響的函式清單請查 **R2026a 的 MATLAB Compiler 與 Computer Vision Toolbox 版本說明**；
%[text] 本章沒有逐一測試。
%%
%[text] # 9. Simulink 與 ROS
%[text] ## Simulink：同一支函式放進系統模型
%[text] Simulink 的 **MATLAB Function 區塊**可以直接呼叫 `ch30_countGrainsCG`——
%[text] **它走的是和 §3 一樣的 codegen**，所以 §2 的改寫在這裡直接派上用場。
%[text] 下面用程式建一個最小的模型：常數影像 → 計數 → 存到工作區。
%[text] 模型**不存檔**，跑完就關掉。
simulinkOK = exist("new_system", "file") > 0 && license("test", "SIMULINK");
if simulinkOK
    mdl = "ch30_demo_model";
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    t0 = tic;
    new_system(mdl);
    add_block("simulink/Sources/Constant", mdl + "/Image", ...
        Value="imgIn", OutDataTypeStr="uint8", SampleTime="1");
    add_block("simulink/User-Defined Functions/MATLAB Function", mdl + "/Count");
    blockConfig = get_param(mdl + "/Count", "MATLABFunctionConfiguration");
    blockConfig.FunctionScript = strjoin([
        "function n = countBlock(img)"
        "[n, ~, ~] = ch30_countGrainsCG(img, 15, 50, -1);"
        "end"], newline);
    add_block("simulink/Sinks/To Workspace", mdl + "/Out", ...
        VariableName="nOut", SaveFormat="Array");
    add_line(mdl, "Image/1", "Count/1");
    add_line(mdl, "Count/1", "Out/1");
    set_param(mdl, StopTime="2", SolverType="Fixed-step", Solver="FixedStepDiscrete");
    % 影像放在模型工作區，不依賴基底工作區
    modelWorkspace = get_param(mdl, "ModelWorkspace");
    modelWorkspace.assignin("imgIn", I);
    fprintf("建模型 %.1f 秒\n", toc(t0));
    % 模擬會在「當前資料夾」產生 slprj 快取，換到 tempdir 做，不留在課程資料夾
    here = pwd;
    cd(tempdir);
    t0 = tic; simOut = sim(mdl); tFirst = toc(t0);
    t0 = tic; simOut = sim(mdl); tSecond = toc(t0);
    cd(here);
    fprintf("第一次 sim %.1f 秒｜第二次 %.1f 秒｜每個時間步的顆數 %s\n", ...
        tFirst, tSecond, mat2str(simOut.nOut(:).'));
    close_system(mdl, 0);
else
    disp("（沒有 Simulink，略過）")
end
%[text] 本機：建模型 20.9 秒，**第一次模擬 29.7 秒、第二次 0.8 秒**，每個時間步都是 93 顆。
%[text] 第一次的 29 秒是**把 MATLAB Function 區塊編譯成 C**，之後重用。
%[text] > Simulink 的價值不在「跑一張影像」，而在把影像處理放進**完整的系統模型**：
%[text] > 相機的取像時序、機構的運動、控制器的反應時間，一起模擬。
%[text] > **硬體在環（HIL）**則是把其中一塊換成真的硬體（例如把產生的程式碼燒進控制器，
%[text] > 其他部分仍在 Simulink 裡模擬）。HIL 需要目標硬體，**本章沒有實測**。
%[text] > Computer Vision Toolbox 也提供 Simulink 區塊庫（`visionlib`），
%[text] > 串流影片的讀取、顯示、幾何轉換可以直接用區塊組起來。
%[text] ## ROS 2：影像訊息的編碼
%[text] 機器人系統用 ROS 傳影像。`sensor_msgs/Image` 的 `encoding` 欄位
%[text] 宣告資料的排列方式（`mono8`、`rgb8`、`bgr8`…）。**不需要啟動 ROS 網路**就能測訊息轉換：
rosOK = exist("ros2message", "file") > 0;
if rosOK
    msgMono = ros2message("sensor_msgs/Image");
    msgMono.encoding = 'mono8';
    msgMono = rosWriteImage(msgMono, I);
    fprintf("mono8：%d×%d、step %d、來回一致 %d\n", msgMono.height, msgMono.width, ...
        msgMono.step, isequal(rosReadImage(msgMono), I));

    RGB = imread("peppers.png");
    msgRGB = ros2message("sensor_msgs/Image");
    msgRGB.encoding = 'rgb8';
    msgRGB = rosWriteImage(msgRGB, RGB);
    fprintf("rgb8 ：來回一致 %d\n", isequal(rosReadImage(msgRGB), RGB));

    msgBGR = ros2message("sensor_msgs/Image");
    msgBGR.encoding = 'bgr8';
    msgBGR = rosWriteImage(msgBGR, RGB);
    back = rosReadImage(msgBGR);
    fprintf("bgr8 ：來回一致 %d｜等於「紅藍對調」的原圖 %d\n", ...
        isequal(back, RGB), isequal(back, RGB(:,:,[3 2 1])));
    fprintf("bgr8 訊息的第一個像素位元組 %s，原圖第一個像素 RGB %s\n", ...
        mat2str(double(msgBGR.data(1:3)).'), mat2str(double(squeeze(RGB(1,1,:))).'));
else
    disp("（沒有 ROS Toolbox，略過）")
end
%[text] 本機實測：
%[text:table]
%[text] | 編碼 | `rosWriteImage` → `rosReadImage` |
%[text] | --- | --- |
%[text] | `mono8` | 一致 |
%[text] | `rgb8` | 一致 |
%[text] | **`bgr8`** | **不一致：紅藍對調** |
%[text:table]
%[text] 原因從位元組看得出來：`rosWriteImage` 把 MATLAB 的 RGB **照原順序寫入**
%[text]（第一個像素是 R G B），但 `encoding` 說它是 BGR；
%[text] `rosReadImage` **相信 `encoding`**，把它當 BGR 轉回 RGB——於是紅藍對調。
%[text] > **寫入與讀取對 `encoding` 的處理不對稱。** 要發 `bgr8` 給 OpenCV 那一端的節點，
%[text] > 要**自己先** `RGB(:,:,[3 2 1])` 再寫入。
%[text] > 紅藍對調的影像**不會讓任何程式報錯**——偵測器照樣輸出框，只是準確率悄悄下降。
%%
%[text] # 10. 產線整合架構
%[text] ## 把本章的數字放在一起
%[text] 同一個演算法、同一張 256×256 影像，**不同的呼叫方式**：
latency = table( ...
    ["MATLAB 裡直接呼叫"; "MEX"; "純 C 程式（含行程啟動）"; "一次 Python 呼叫的開銷"; "獨立 exe（含 Runtime 啟動）"], ...
    [19.03; 10.41; 90; 25; 18200], ...
    VariableNames=["Method" "Milliseconds"]);
if ~isnan(tMatlab), latency.Milliseconds(1) = tMatlab * 1e3; end
if ~isnan(tMex),    latency.Milliseconds(2) = tMex * 1e3; end
if cprogOK,         latency.Milliseconds(3) = min(cRunMs); end
if pyInfo.Available, latency.Milliseconds(4) = pyInfo.PerCallMs; end
if compilerOK && exeInfo.Success, latency.Milliseconds(5) = exeInfo.RunSeconds * 1e3; end
latency.RelativeToMEX = latency.Milliseconds / latency.Milliseconds(2);
disp(latency)
%[text] （這次執行沒有量到的項目用本機既有量測值；純 C 程式取 §4 三次執行中最快的一次。）
%[text] > **演算法本身的差距不到 2 倍，呼叫方式的差距超過 1000 倍。**
%[text] > 選部署方式時，先算**每張影像的呼叫開銷**，再談演算法要不要最佳化。
%[text] ## 典型的產線架構
%[text] ```
%[text]  相機 ──取像──▶ 影像處理程式（常駐）──結果──▶ PLC（OK/NG、座標）
%[text]                   │                          │
%[text]                   ├──紀錄、影像──▶ 資料庫／MES（追溯）
%[text]                   └──心跳、錯誤──▶ 監控
%[text] ```
%[text:table]
%[text] | 介面 | 常見做法 | MATLAB 端 |
%[text] | --- | --- | --- |
%[text] | 相機 | GigE Vision、GenICam、USB | Image Acquisition Toolbox（第 23 章） |
%[text] | PLC | TCP/IP socket、OPC UA、Modbus | `tcpclient`、Industrial Communication Toolbox |
%[text] | 資料庫／MES | SQL、REST API | Database Toolbox、`webwrite` |
%[text] | 檔案交換 | 共用資料夾 + 完成旗標檔 | 第 29 章的 `ch29_runBatch` |
%[text:table]
%[text] 本章**沒有實測** PLC、OPC UA、資料庫的連線（需要對應的設備或伺服器）。
%[text] 下面是這些整合最常出事的地方，每一條都對應到本章或第 29 章的內容：
%[text:table]
%[text] | 原則 | 為什麼 | 對應 |
%[text] | --- | --- | --- |
%[text] | **處理程式常駐**，不要每張影像啟動一次 | Runtime 啟動 18–24 秒 | §8 |
%[text] | **失敗要送「NG／未知」，不是沒送** | PLC 等不到結果時的預設動作通常是「放行」 | 第 29 章 §5 的錯誤隔離 |
%[text] | 每筆結果帶**演算法版本與參數** | 三個月後才能追溯是哪一版判的 | 第 29 章的 `Params` 欄位 |
%[text] | 定時送**心跳** | 程式當掉和「一直沒有瑕疵」看起來一樣 | — |
%[text] | 每個呼叫設**逾時** | 取像卡住時不能讓整條線停下來等 | 第 23 章的時間預算 |
%[text] | 上線前用**真實的呼叫端**跑回歸測試 | 轉置、通道順序、大小錯誤都不會報錯 | §4、§9 |
%[text:table]
%[text] > 回到本章的一句話：**違反介面契約的時候，通常不會報錯。**
%[text] > 整合測試的目的就是在上線前，讓這些「不會報錯的錯」現形。
%%
%[text] # 11. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 本章 |
%[text] | --- | --- | --- |
%[text] | 進入點用了名稱-值引數 | codegen 直接失敗 | §2 |
%[text] | 用 NaN 當「自動」旗標 | C 呼叫端用 `== NAN` 檢查永遠是 false | §2、練習 1 |
%[text] | 以為 MEX 會快 10 倍 | 實測 1.3–2.1 倍——內建函式本來就是編譯過的 | §3、練習 2 |
%[text] | 以為 MEX 的 `assert` 也保護 C 呼叫端 | C 函式庫裡沒有 `assert`，`threshold = 2` 安靜地得到 0 顆 | §3、§4 |
%[text] | 只複製 codegen 資料夾給對方 | 缺 `tmwtypes.h` 與 20 個 DLL；要用 `packNGo` | §4 |
%[text] | 以為主機目標的 C 能搬到 ARM | 主機目標呼叫 MathWorks 預編譯函式庫；要改硬體目標 | §4 |
%[text] | 固定大小的 C 介面收到別的大小 | **不報錯**，讀到哪算哪 | §4 |
%[text] | GPU 碼生成用執行期的結構元素半徑 | 結果正確，但慢約 10 萬倍 | §5 |
%[text] | 以為 GPU 版一定比較快 | 米粒計數的 GPU MEX 比 MATLAB 慢 28–140 倍 | §5 |
%[text] | 匯入的 ONNX 網路單獨部署 | 缺自訂層套件，`predict` 失敗 | §6 |
%[text] | ROS `bgr8` 直接寫入 RGB | 紅藍對調，不報錯 | §9 |
%[text] | C／OpenCV 的以列為主緩衝區 | 函式看到轉置的影像；計數類的輸出**對轉置免疫，所以測不出來** | §4、練習 3 |
%[text] | `NoDefaultCurrentDirectoryInExePath` | 「'xxx\_mex.bat' 不是內部或外部命令」 | §3 |
%[text] | 看 ONNX 匯入後的設定欄位下結論 | 以為正規化掉了，其實沒有 | §6 |
%[text] | ONNX 匯入的輸出是 `UU` 且轉置 | `max(y,[],1)` 在錯的軸上取值，**不報錯** | §6、練習 4 |
%[text] | 在迴圈裡逐次呼叫 Python | 每次 14–16 ms，比運算本身貴幾百倍 | §7、練習 5 |
%[text] | Python 大整數轉 double | `2**70` 失去精度 | §7、練習 5 |
%[text] | Compiler 預設自動偵測支援包 | exe **619.8 MB**（應該 1.5 MB） | §8、加分題 |
%[text] | 每張影像啟動一次 exe | 每次 18 秒的 Runtime 啟動 | §8、§10 |
%[text] | 只在 MATLAB 裡驗證匯出的模型 | 證明的是「讀得回自己寫的檔」，不是目標框架的結果 | §6 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 練習在 `exercise/Ch30_Exercise.m`。
%%
%[text] # 13. 延伸閱讀
%[text] - `doc codegen` / `doc coder.typeof` / `doc coder.config` / `doc coder.rowMajor`
%[text] - 各函式文件頁的 **Extended Capabilities → C/C++ Code Generation**
%[text] - `doc coder.checkGpuInstall` / `doc gpucoder`
%[text] - `doc exportONNXNetwork` / `doc importNetworkFromONNX` / `doc importNetworkFromPyTorch`
%[text] - `doc pyenv` / `doc pyrun` / `doc pyrunfile`；MATLAB Engine API for Python
%[text] - `doc compiler.build.standaloneApplication` / `doc isdeployed`
%[text] - MATLAB Production Server（把演算法做成 HTTP 服務）
%[text] - `doc ros2message` / `doc rosReadImage`

% ========================================================================
% 本章用到的示範函式

function tryCall(label, fcn)
try
    fcn();
    fprintf("%-16s → 執行了\n", label);
catch ME
    fprintf("%-16s → 報錯：%s\n", label, extractBefore(string(ME.message) + newline, newline));
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
