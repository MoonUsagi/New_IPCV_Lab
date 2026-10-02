%[text] # 第 30 章　練習解答
%[text] {"align":"left"}部署與系統整合　｜　MATLAB R2026b
%[text] > 這份解答的數字都是**本機**（Windows 11、MATLAB R2026a、MSVC 2019、NVIDIA T550）
%[text] > 實際跑出來的。你的機器上時間會不同，但**結論的方向**應該一樣。
%[text] > 需要 MATLAB Coder 的題目會重用 `tempdir/ch30_build` 的快取；第一次執行較久。
assert(exist("ch30_countGrainsCG", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = imread("rice.png");
coderOK = exist("codegen", "file") > 0 && license("test", "MATLAB_Coder");
%%
%[text] # 練習 1　哪些寫法擋住了 codegen
%[text] 三個小函式寫成**檔案**（codegen 的進入點不能是腳本裡的區域函式），放在 `tempdir`。
%[text] 為了快，只「產生程式碼」不編譯（`cfg.GenCodeOnly = true`）。
if coderOK
    exDir = fullfile(tempdir, "ch30_ex1");
    if ~isfolder(exDir), mkdir(exDir); end
    writelines([
        "function y = cgNameValue(x, options) %#codegen"
        "arguments"
        "    x (1,1) double"
        "    options.Scale (1,1) double = 1"
        "end"
        "y = x * options.Scale;"
        "end"], fullfile(exDir, "cgNameValue.m"));
    writelines([
        "function a = cgRegionTable(bw) %#codegen"
        "s = regionprops(""table"", bw, ""Area"");"
        "a = s.Area;"
        "end"], fullfile(exDir, "cgRegionTable.m"));
    writelines([
        "function a = cgRegionStruct(bw) %#codegen"
        "s = regionprops(bw, ""Area"");"
        "a = [s.Area];"
        "end"], fullfile(exDir, "cgRegionStruct.m"));
    writelines([
        "function cgPrintString(x) %#codegen"
        "fprintf(""%s\n"", ""value = "" + string(x));"
        "end"], fullfile(exDir, "cgPrintString.m"));
    writelines([
        "function cgPrintChar(x) %#codegen"
        "fprintf('value = %f\n', x);"
        "end"], fullfile(exDir, "cgPrintChar.m"));

    cases = {
        "cgNameValue",    {1}
        "cgRegionTable",  {false(64, 64)}
        "cgRegionStruct", {false(64, 64)}
        "cgPrintString",  {1}
        "cgPrintChar",    {1}
        };
    cfg = coder.config("lib");
    cfg.GenCodeOnly = true;
    cfg.GenerateReport = false;
    here = pwd;
    cd(exDir);
    result = strings(size(cases, 1), 1);
    seconds = zeros(size(cases, 1), 1);
    for k = 1:size(cases, 1)
        t0 = tic;
        try
            codegen("-config", cfg, cases{k, 1}, "-args", cases{k, 2}, "-d", "out_" + cases{k, 1});
            result(k) = "通過";
        catch ME
            % codegen 的 ME.message 常以空行開頭，真正的原因在後面幾行
            msgLines = strtrim(splitlines(string(ME.message)));
            msgLines = msgLines(strlength(msgLines) > 0 & ~startsWith(msgLines, "Error in") ...
                & ~startsWith(msgLines, "Code generation failed"));
            if isempty(msgLines), msgLines = "（見上方 codegen 的輸出）"; end
            result(k) = "失敗：" + msgLines(1);
        end
        seconds(k) = toc(t0);
    end
    cd(here);
    disp(table(string(cases(:, 1)), result, round(seconds, 1), ...
        VariableNames=["Function" "Result" "Seconds"]))
end
%[text] 本機的結果：
%[text:table]
%[text] | 函式 | 結果 | 原因 |
%[text] | --- | --- | --- |
%[text] | `cgNameValue` | **失敗** | 第 1 行第 14 欄：進入點不支援名稱-值引數 |
%[text] | `cgRegionTable` | **失敗** | 「Expected input number 1 … Instead its type was string」——`"table"` 語法不被接受 |
%[text] | `cgRegionStruct` | 通過 | struct 輸出版本可以 |
%[text] | `cgPrintString` | **通過** | 我原本以為 string 物件會擋住 codegen——**猜錯了** |
%[text] | `cgPrintChar` | 通過 | |
%[text:table]
%[text]
%[text] **第 3 小題：`threshold = NaN`**
try
    ch30_countGrainsCG(I, 15, 50, NaN);
    disp("NaN：執行了")
catch ME
    disp("NaN：" + ME.message)
end
%[text] MATLAB 版被 `assert(thresholdIn <= 1)` 擋下（`NaN <= 1` 是 false）。
%[text] 但主教材 §3 看到**產生的 C 函式庫裡沒有 `assert`**。C 端傳 NaN 會怎樣？
cprogOK = false;
if coderOK
    libInfo = ch30_buildMex(Kind="lib");
    if libInfo.Success
        cprog = ch30_buildCProgram();
        cprogOK = cprog.Success;
    end
end
if cprogOK
    rawDir = fullfile(tempdir, "ch30_raw");
    if ~isfolder(rawDir), mkdir(rawDir); end
    rawFile = fullfile(rawDir, "colmajor.raw");
    fid = fopen(rawFile, "w"); fwrite(fid, I(:), "uint8"); fclose(fid);
    for arg = ["-1" "0.3" "2" "nan"]
        [status, out] = system(sprintf('"%s" "%s" %s', cprog.ExeFile, rawFile, arg));
        fprintf("C 程式，門檻 %-4s → 結束碼 %d｜%s\n", arg, status, strtrim(out));
    end
end
%[text] 在 C 裡：`if (thresholdIn < 0.0)` 對 NaN 是 false，所以 NaN 被當成「使用者指定的門檻」
%[text] 往下傳——**沒有任何錯誤**，只是結果不對。這就是 `ch30_countGrainsCG` 選 `-1` 而不是 `NaN`
%[text] 當「自動」旗標的原因：
%[text] - `-1` 是一個普通的數字，C 呼叫端寫 `threshold = -1;` 不會出錯
%[text] - NaN 在 C 裡要用 `isnan()` 檢查，`x == NAN` **永遠是 false**
%[text] - 產生的 C 函式庫**沒有 `assert`**，擋不住的值會一路傳到最後
%[text]
%[text] **第 4 小題：codegen 進入點的介面規則**
%[text:table]
%[text] | 規則 | 理由 |
%[text] | --- | --- |
%[text] | 只用位置引數，不用名稱-值 | 進入點不支援名稱-值的 `arguments` 驗證 |
%[text] | 不要依賴 `arguments` 或 `assert` 保護 C 呼叫端 | C 函式庫預設不產生執行期檢查 |
%[text] | 「自動」「未設定」用普通數字表示（如 -1），不用 NaN | C 端很容易把 NaN 檢查寫錯 |
%[text] | 輸出用數值陣列或 struct，不用 table | 本機 `regionprops("table", …)` 產生程式碼失敗 |
%[text] | 不要憑印象排除寫法，**逐一 codegen 驗證** | 本機 `fprintf` 搭配 string 物件是可以的 |
%[text] | 進入點不做檔案 I/O、不畫圖 | 那是呼叫端（介面層）的事，見 `ch30_grainCLI` |
%[text:table]
%%
%[text] # 練習 2　MEX 的加速在哪裡成立
varOK = false;
if coderOK
    varInfo = ch30_buildMex(Kind="variable");
    varOK = varInfo.Success;
end
if varOK
    if ipcvFast()
        sizes = [256 512];
        disp("（快速模式：只量 256 與 512；完整結果見下方表格）")
    else
        sizes = [256 512 1024 2048];
    end
    tML = zeros(size(sizes)); tMX = zeros(size(sizes));
    same = false(size(sizes)); nGrains = zeros(size(sizes));
    for k = 1:numel(sizes)
        s = sizes(k);
        J = imresize(I, [s s]);
        r = round(15 * s / 256);
        m = 50 * (s / 256)^2;
        [c1, a1] = ch30_countGrainsCG(J, r, m, -1);
        [c2, a2] = ch30_countGrainsCG_var_mex(J, r, m, -1);
        same(k) = c1 == c2 && isequal(a1, a2);
        nGrains(k) = c1;
        tML(k) = timeit(@() ch30_countGrainsCG(J, r, m, -1), 3);
        tMX(k) = timeit(@() ch30_countGrainsCG_var_mex(J, r, m, -1), 3);
    end
    speed = table(sizes(:), nGrains(:), round(tML(:)*1e3, 2), round(tMX(:)*1e3, 2), ...
        round(tML(:)./tMX(:), 2), same(:), ...
        VariableNames=["Side" "Count" "MATLAB_ms" "MEX_ms" "Speedup" "Identical"]);
    disp(speed)
    figure;
    plot(sizes, tML ./ tMX, "o-", LineWidth=1.5);
    xlabel("影像邊長（像素）"); ylabel("MEX 加速倍數");
    title("MEX 加速 vs 影像大小"); grid on;
end
%[text] 本機（完整模式）：
%[text:table]
%[text] | 邊長 | 顆數 | MATLAB | MEX | 加速 | 結果一致 |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | 256 | 93 | 9.89 ms | 7.83 ms | 1.26 | 是 |
%[text] | 512 | 94 | 50.2 ms | 27.4 ms | 1.83 | 是 |
%[text] | 1024 | 94 | 232 ms | 146 ms | 1.59 | 是 |
%[text] | 2048 | 94 | 1916 ms | 936 ms | 2.05 | 是 |
%[text:table]
%[text] **我寫這題之前預測「加速會隨影像變大而變小」——數據推翻了它**：
%[text] 加速在 1.3–2.1 倍之間跳動，沒有單調的趨勢，而且和主教材 §3 同一個 256×256 量到的
%[text] 1.63–1.83 倍也對不上（這次 256 只有 1.26）。可以確定的只有兩件事：
%[text] - **每個大小的結果都完全一致**
%[text] - **加速一直在 2 倍上下，從來沒有接近 10 倍**
%[text]
%[text] 「編成 C 就會快 10 倍」的回答：對這支大量呼叫內建影像函式的程式**不成立**，
%[text] 它的時間主要花在本來就編譯過的 `imopen` 裡（2048² 時半徑 120 的圓盤）。
%[text] 迴圈多、純量運算多的程式才可能有大幅加速——**先量再說**，而且要**量不只一次**。
%%
%[text] # 練習 3　C 的呼叫端送來的影像是轉置的
[cA, aA, tA] = ch30_countGrainsCG(I, 15, 50, -1);
[cB, aB, tB] = ch30_countGrainsCG(I.', 15, 50, -1);
fprintf("I   ：%d 顆、門檻 %.6f、前五顆面積 %s\n", cA, tA, mat2str(aA(1:5)));
fprintf("I.' ：%d 顆、門檻 %.6f、前五顆面積 %s\n", cB, tB, mat2str(aB(1:5)));
fprintf("排序後的面積相同：%d｜**不排序**的面積相同：%d\n", ...
    isequal(sort(aA), sort(aB)), isequal(aA, aB));
%[text] **這個錯誤很難被發現**：顆數、門檻、面積的分布全部一樣。
%[text] 圓盤結構元素、Otsu、連通區域計數都**不管方向**。唯一不同的是**面積的順序**——
%[text] 連通區域依記憶體順序編號，轉置之後編號順序改變。
%[text] > 主教材 §2 的 `assert` 用了 `sort(areas)` 比較——**排序正好把這個訊號藏起來了。**
%[text]
%[text] 加一個會被轉置影響的輸出——每顆的質心：
rA = ch29_countGrains(I);
rB = ch29_countGrains(I.');
sA = regionprops(rA.Mask, "Centroid");
sB = regionprops(rB.Mask, "Centroid");
cenA = sortrows(vertcat(sA.Centroid));
cenB = sortrows(vertcat(sB.Centroid));
fprintf("質心集合相同：%d｜把 I.' 的質心 (x,y) 對調後相同：%d\n", ...
    isequal(round(cenA, 6), round(cenB, 6)), ...
    isequal(round(cenA, 6), round(sortrows(cenB(:, [2 1])), 6)));
%[text] 質心**抓得到**轉置（x、y 對調）。
%[text]
%[text] **第 4 小題：以列為主的程式碼。** MATLAB Coder 的設定物件有 `RowMajor` 屬性：
if coderOK
    cfgLib = coder.config("lib");
    fprintf("coder.config(""lib"") 有 RowMajor 屬性：%d，預設值 %d\n", ...
        isprop(cfgLib, "RowMajor"), cfgLib.RowMajor);
end
%[text] 設成 `true` 時產生的程式碼**以列為主**存取陣列，C 呼叫端可以直接傳自己的緩衝區
%[text]（也可以在函式裡用 `coder.rowMajor` 指定）。**本章沒有實測**這個選項產生的程式碼與效能；
%[text] 用之前要和練習 2 一樣，比對結果、量時間。
%[text]
%[text] **第 5 小題：抓得到轉置錯誤的整合測試**
%[text] - 比**不排序**的輸出（面積向量的順序、第一顆的面積），或比質心
%[text] - 測試圖要**對主對角線不對稱**：例如只有右上角有米粒的影像——轉置後米粒跑到左下角
%[text] （只有左上角或右下角有米粒的圖**沒用**，轉置後位置不變）
%[text] - 主教材 §4 的 C 程式印出 `first_area`：以行為主 138、以列為主 61——**一個數字就抓到了**
%%
%[text] # 練習 4　ONNX 匯入之後，類別在哪一維
onnxOK = exist("exportONNXNetwork", "file") > 0 && exist("importNetworkFromONNX", "file") > 0;
if onnxOK
    onnx = ch30_onnxRoundTrip();
    net = imagePretrainedNetwork("squeezenet");
    inSize = onnx.InputSize(1:2);
    names = ["peppers.png" "football.jpg" "coins.png" "cameraman.tif" ...
             "onion.png" "saturn.png" "pears.png" "kobi.png"];
    X = zeros([inSize 3 numel(names)], "single");
    for k = 1:numel(names)
        J = imread(names(k));
        if size(J, 3) == 1, J = repmat(J, 1, 1, 3); end
        X(:,:,:,k) = single(imresize(J, inSize));
    end
    for n = [1 8]
        dX = dlarray(X(:,:,:,1:n), "SSCB");
        y1 = predict(net, dX);
        y2 = predict(onnx.ImportedNetwork, dX);
        [~, c1] = max(extractdata(y1));
        [~, c2] = max(extractdata(y2));
        fprintf("批次 %d：原網路 %s %s → max(y) 得 %d 個值｜匯入 %s %s → max(y) 得 %d 個值\n", ...
            n, string(dims(y1)), mat2str(size(y1)), numel(c1), ...
            string(dims(y2)), mat2str(size(y2)), numel(c2));
        top1 = safeTop1(net, dX, 1000);
        top2 = safeTop1(onnx.ImportedNetwork, dX, 1000);
        fprintf("        safeTop1 一致：%d\n", isequal(top1, top2));
    end
    try
        safeTop1Values(rand(1000, 1000), "UU", 1000);
    catch ME
        disp("1000×1000 的 UU 輸出 → " + ME.message)
    end
end
%[text] **第 4 小題：只用 1 張影像的測試抓得到嗎？**
%[text] 批次 1 時匯入網路的輸出是 1×1000，`max(y)` 不指定維度時會沿著**第一個長度不是 1 的維度**
%[text] 取最大值——剛好是類別那一維，**答案是對的**。批次 8 時才會在錯的軸上取值。
%[text] > **只用 1 張影像測試，這個錯誤會被 `max` 的預設行為掩蓋。**
%[text] > 測試的批次大小要**大於 1**，而且**不等於類別數**。
%%
%[text] # 練習 5　跨 Python 邊界的成本
pyReady = false;
try
    pe = pyenv;
    pyReady = strlength(string(pe.Version)) > 0;
    if pyReady, pyrun("z_ = 0"); end
catch
    pyReady = false;
end
if pyReady
    sideList = [1 100 512 1024];
    sendMs = zeros(size(sideList));
    for k = 1:numel(sideList)
        A = rand(sideList(k));
        pyrun("n_ = 0", "n_", x_=A);                     % 熱身
        t0 = tic;
        for j = 1:5
            pyrun("n_ = 0", "n_", x_=A);
        end
        sendMs(k) = toc(t0) / 5 * 1000;
    end
    disp(table(sideList(:), round(sideList(:).^2 * 8 / 1e6, 2), round(sendMs(:), 1), ...
        VariableNames=["Side" "MB" "Milliseconds"]))

    layout = pyrun("l_ = x_.tolist(); s_ = (x_.shape, x_.f_contiguous)", ["l_" "s_"], x_=[1 2 3; 4 5 6]);
    fprintf("[1 2 3; 4 5 6] → tolist() = %s\n", string(py.builtins.str(layout)));

    big = pyrun("b_ = 2**53 + 1", "b_");
    fprintf("2**53+1：double %.0f｜int64 %d\n", double(big), int64(big));
else
    disp("（這台機器沒有可用的 Python，略過）")
end
%[text] 本機兩次：1×1 是 24.3／26.2 ms，1024×1024（8.4 MB）是 26.9／31.9 ms——
%[text] **資料量大了 100 萬倍，時間只多 11–22%**。
%[text] **成本幾乎全在呼叫次數。** 矩陣的列與行順序是對的（`[[1,2,3],[4,5,6]]`）。
%[text] `2**53 + 1` 轉 double 得到 9007199254740992（**差 1**），轉 int64 才是 9007199254740993。
%[text]
%[text] **建議**：不要每張影像呼叫一次 Python。把一整批影像（或一整段處理）一次交給 Python，
%[text] 或把 Python 端做成常駐服務、用批次介面溝通。整數型的 ID、時間戳記用 `int64` 接。
%%
%[text] # 練習 6　替四個場景選部署方式
%[text] 用本章與練習 2 的數字。
if varOK && numel(tML) >= 4
    t2048 = tML(4) * 1e3;
else
    t2048 = NaN;
end
if ~isnan(t2048)
    fprintf("本機 2048×2048：MATLAB %.0f ms、MEX %.0f ms（場景 A 的預算 200 ms）\n", t2048, tMX(4)*1e3);
end
exeStart = 18.2; perImage = 0.02; nNight = 5e4;
fprintf("場景 B：每張啟動一次 exe → %.1f 天｜一次啟動處理整批 → %.0f 分鐘\n", ...
    nNight * exeStart / 86400, (exeStart + nNight * perImage) / 60);
%[text:table]
%[text] | 場景 | 選擇 | 理由 | 最可能壞在哪 |
%[text] | --- | --- | --- | --- |
%[text] | A　AOI 產線 | **常駐程式**（Compiler exe 常駐，或 C 函式庫嵌進閘道程式） | Runtime 只啟動一次；每張只剩演算法時間 | **演算法本身就超時**：本機 2048² 的 MATLAB 1916 ms、MEX 936 ms，是預算的 5–10 倍——**換部署方式救不了**，要縮小影像、只處理 ROI 或改演算法；失敗時要送 NG |
%[text] | B　夜間批次 | **Compiler exe，一次處理整批**（第 29 章 `ch29_runBatch`） | 每張啟動一次要 10 天以上；整批一次約 17 分鐘 | exe 的大小（`SupportPackages`）；一個壞檔停掉整批 |
%[text] | C　嵌入式相機 | **MATLAB Coder，ARM 目標** | 主教材 §4：ARM 目標產生可攜純 C（沒有 libmw DLL） | 固定大小／上限；以列為主的相機緩衝區；C 端沒有 `assert` |
%[text] | D　Python 團隊 | **Compiler SDK 的 Python 套件**，或 **Production Server** 的 HTTP 介面 | 對方不用裝 MATLAB（但要 Runtime 或伺服器） | 每次呼叫的開銷（練習 5）；numpy 的以列為主 |
%[text:table]
%[text] > 場景 B、C、D 的主要風險都在**邊界**：啟動成本、記憶體排列、沒有檢查的輸入、失敗時送了什麼。
%[text] > 場景 A 是反例：**先用第 23 章的方法算時間預算**，演算法本身超時的時候，
%[text] > 討論用哪一種部署方式都是在錯的問題上花時間。
%%
%[text] # 加分題　多出來的 618 MB 是誰帶進來的
%[text] 用自動偵測打包要約 1 分鐘、需要約 1 GB 暫存空間。預設不執行；
%[text] 要執行時先 `setenv("IPCV_CH30_BIG_BUILD", "1")`。
if ~isempty(which("compiler.build.standaloneApplication"))
    [files, products] = matlab.codetools.requiredFilesAndProducts("ch30_grainCLI.m");
    fprintf("ch30_grainCLI 實際依賴的產品：\n");
    disp(string({products.Name}).')
    if getenv("IPCV_CH30_BIG_BUILD") == "1"
        big = ch30_buildStandalone(SupportPackages="autodetect");
        fprintf("自動偵測：exe %.1f MB、建置 %.1f 秒\n", big.ExeMB, big.BuildSeconds);
        disp(big.SupportPackages)
    else
        disp("（略過自動偵測打包；本機結果：619.8 MB、66.7 秒，包進 Hyperspectral、Circle Detection、SAM）")
    end
end
%[text] **兩份清單的差別**：`requiredFilesAndProducts` 只列出 MATLAB 與 Image Processing Toolbox
%[text]（程式碼真正呼叫到的產品），自動偵測卻包進了三個**完全沒用到**的支援包。
%[text]
%[text] **我沒有找到確切的原因。** 可以確定的只有：
%[text] - `ch30_grainCLI` 與 `ch30_countGrainsCG` 沒有呼叫任何支援包的函式
%[text] - 被包進去的三個都是 **Image Processing Toolbox 的支援包**
%[text] - 但**不是**所有 IPT 支援包都被包進去：本機也裝了 Segment Anything Model **2** 與
%[text]   Optical Design and Simulation Library，它們都沒有出現
%[text] 所以「用到 IPT 就把 IPT 的支援包全包進去」這個最直覺的解釋**不成立**。
%[text] 確切的判斷規則我不知道；要追下去，可以在一台只裝其中一個支援包的機器上打包比較。
%[text]
%[text] **建置腳本裡的設定**：明確寫 `SupportPackages="none"`，或列出需要的支援包名稱。
%[text] 風險是**漏包**——真的需要的支援包沒進去，要到執行時才報錯。
%[text] 抓這個風險的方法：**打包之後，在一台乾淨的機器（只裝 MATLAB Runtime）上跑回歸測試**，
%[text] 而不是在開發機上跑——開發機上什麼都找得到。

% ========================================================================
% 解答用到的函式

function top1 = safeTop1(net, dX, numClasses)
%SAFETOP1 依維度標籤或大小找出類別那一維，再取 top-1。
y = predict(net, dX);
top1 = safeTop1Values(extractdata(y), string(dims(y)), numClasses);
end

function top1 = safeTop1Values(y, labels, numClasses)
cDim = strfind(labels, "C");
if isempty(cDim)
    hits = find(size(y, 1:2) == numClasses);
    if numel(hits) ~= 1
        error("ipcv:ch30:ambiguousClassDim", ...
            "無法判斷類別維度：輸出大小 %s、標籤 %s。", mat2str(size(y)), labels);
    end
    cDim = hits;
end
[~, top1] = max(y, [], cDim);
top1 = top1(:).';
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
