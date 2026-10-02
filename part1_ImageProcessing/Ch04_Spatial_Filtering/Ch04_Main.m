%[text] # 第 04 章　空間域濾波與雜訊處理
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明卷積如何運作，並正確處理邊界
%[text] 2. 依**雜訊類型**選擇濾波器，而不是每次都用高斯
%[text] 3. 說明保邊濾波與一般平滑濾波的差別，並用數字證明
%[text] 4. 在品質與速度之間做出有依據的取捨
%[text] 5. 用 PSNR／SSIM 量化去雜訊效果，而不是靠肉眼 \
%[text] ## 前置知識
%[text] 第 01 章（資料型別）、第 03 章（點運算——本章是它的對照組）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="04", Verbose=false);
rng(0);      % 本章大量使用 imnoise，固定種子確保數字可重現
disp("環境檢查通過。")
%%
%[text] # 1. 從點運算到鄰域運算
%[text] 第 03 章的點運算，輸出像素只看**同一位置**的輸入像素。
%[text] 這讓它無法處理雜訊——因為雜訊的定義就是「這個像素跟它的鄰居不一致」，
%[text] 只看單一像素根本分辨不出哪個值是雜訊。
%[text] **鄰域運算**看的是周圍一小塊區域：
%[text] $g(x,y)=\sum_{i,j} w(i,j)\,f(x+i,\,y+j)$
%[text] 這個加權求和就是**卷積**，權重矩陣 $w$ 稱為**核**（kernel）或濾波器。
%[text:table]
%[text] | | 點運算（第 03 章） | 鄰域運算（本章） |
%[text] | --- | --- | --- |
%[text] | 輸出取決於 | 同位置單一像素 | 周圍區域 |
%[text] | 能處理 | 亮度、對比、曝光 | 雜訊、模糊、銳化、邊緣 |
%[text] | 可化簡成查表 | 是（256 次運算） | 否（每個像素都要算） |
%[text] | 速度 | 極快 | 較慢，與核大小成正比 |
%[text:table]
%%
%[text] # 2. 卷積怎麼運作
%[text] ## 2.1 手動算一次
%[text] 先用一個小矩陣看清楚每一步。3×3 的均值核就是九個 1/9：
A = [10 10 10 10 10
     10 10 90 10 10
     10 10 10 10 10
     10 10 10 10 10
     10 10 10 10 10];

kernel = ones(3,3) / 9;
B = imfilter(A, kernel, "replicate");

disp("原始矩陣（中間有一個突出值 90）：")
disp(A)
disp("3×3 均值濾波後：")
disp(round(B, 1))
%[text] 那個 90 被「攤平」到周圍九個位置，每個分到 $(90-10)/9\approx8.9$。
%[text] 中心從 90 掉到 $10+8.9=18.9$。
%[text] **這就是平滑濾波的本質**：把突出的值分散給鄰居。
%[text] 它能壓制雜訊，但同樣也會把**真正的細節**一起攤平——
%[text] 濾波器分不出哪個突出值是雜訊、哪個是眼睛。
%%
%[text] ## 2.2 邊界怎麼辦
%[text] 影像邊緣的像素沒有完整的鄰居。`imfilter` 提供四種處理方式，
%[text] 選錯會在影像四周產生假的暗框或亮框。
I = im2double(imread("cameraman.tif"));
k = fspecial("average", 25);        % 用大核放大邊界效應

options = ["symmetric" "replicate" "circular"];
outs = {imfilter(I, k, 0)};          % 預設：補 0
titles = "補 0（預設）";

for o = options
    outs{end+1} = imfilter(I, k, o); %#ok<SAGROW>
    titles(end+1) = o;               %#ok<SAGROW>
end

figure
montage(outs, Size=[1 4])
title(strjoin(titles, " ｜ "))
%[text:table]
%[text] | 選項 | 做法 | 後果 |
%[text] | --- | --- | --- |
%[text] | `0`（預設） | 邊界外補 0 | **四周出現黑框**，最常見的錯誤 |
%[text] | `"replicate"` | 複製最邊緣的像素 | 安全的通用選擇 |
%[text] | `"symmetric"` | 鏡射 | 自然，適合有紋理的影像 |
%[text] | `"circular"` | 環繞（與 FFT 一致） | 除非在做頻域運算，否則別用 |
%[text:table]
%[text] **實務建議**：一律明確寫出 `"replicate"` 或 `"symmetric"`。
%[text] 預設補 0 幾乎永遠不是你要的——量化一下黑框有多嚴重：
border = false(size(I));
border([1:12, end-11:end], :) = true;
border(:, [1:12, end-11:end]) = true;

fprintf("邊界區域平均亮度：\n");
fprintf("  原圖        %.4f\n", mean(I(border)));
fprintf("  補 0        %.4f  <- 明顯變暗\n", mean(outs{1}(border)));
fprintf("  replicate   %.4f\n", mean(outs{2}(border)));
%%
%[text] ## 2.3 常用的核
%[text] `fspecial` 直接給你常用的核，不必自己刻。
kernels = ["average" "gaussian" "laplacian" "log" "sobel" "prewitt"];

figure
tiledlayout(2, 3)
for name = kernels
    nexttile
    h = fspecial(name);
    imagesc(h); axis image off; colorbar
    title(name + "  " + mat2str(size(h)))
end
%[text:table]
%[text] | 核 | 用途 | 特性 |
%[text] | --- | --- | --- |
%[text] | `average` | 平滑 | 權重相同，會產生方向性假影 |
%[text] | `gaussian` | 平滑 | 中心權重高，效果自然，**平滑的首選** |
%[text] | `laplacian` | 邊緣／銳化 | 二階微分，對雜訊極敏感 |
%[text] | `log` | 邊緣 | 先高斯平滑再 Laplacian，較穩健 |
%[text] | `sobel` `prewitt` | 邊緣 | 一階微分，有方向性（第 10 章詳述） |
%[text:table]
%[text] 高斯核的兩個關鍵性質：**可分離**（2D 可拆成兩次 1D，運算量大幅下降）
%[text] 與**旋轉對稱**（不會偏袒任何方向）。這是它成為預設選擇的原因。
%[text] ## 2.4 一個常見的誤解
%[text] 很多人以為 `imgaussfilt` 比 `imfilter` 加高斯核快，因為「它有做可分離最佳化」。
%[text] 實測看看：
sigma = 3;
hg = fspecial("gaussian", 2*ceil(3*sigma)+1, sigma);
if ipcvFast()
    disp("（快速模式：略過效能量測，實測結論見下方說明）")
else
    Ibig = imresize(I, 4);      % 1024×1024，放大差距

    fprintf("%-12s %14s %12s\n", "影像尺寸", "imgaussfilt", "imfilter");
    for pair = {"256×256", I; "1024×1024", Ibig}'
        t1 = timeit(@() imgaussfilt(pair{2}, sigma)) * 1000;
        t2 = timeit(@() imfilter(pair{2}, hg, "replicate")) * 1000;
        fprintf("%-12s %12.2f ms %10.2f ms\n", pair{1}, t1, t2);
    end
end
%[text] **`imfilter` 比較快**。原因是 `imfilter` 本身就會偵測核是否可分離並自動最佳化，
%[text] 而 `imgaussfilt` 每次呼叫都要**重新建構核**並做引數驗證，多了固定開銷。
%[text] 那為什麼還要用 `imgaussfilt`？因為它讓你**只指定 sigma**，
%[text] 核的大小由它依 sigma 正確決定。自己用 `fspecial` 時很容易把核開得太小
%[text] （常見錯誤：`fspecial("gaussian", 3, 3)`——sigma=3 卻只用 3×3 的核，
%[text] 高斯尾巴被硬切掉，結果根本不是高斯平滑）。
%[text] **結論**：一般情況用 `imgaussfilt`（不會出錯）；
%[text] 在迴圈裡用固定 sigma 處理大量影像時，先 `fspecial` 建好核再用 `imfilter`。
%[text] 這是「先求正確，有需要再求快」的典型例子。
%%
%[text] # 3. 雜訊有很多種
%[text] 「去雜訊」這句話沒有意義——**要先知道是哪一種雜訊**。
%[text] 不同來源的雜訊有完全不同的統計特性，需要不同的濾波器。
noiseTypes = ["gaussian" "salt & pepper" "speckle"];
noisy = cell(1, numel(noiseTypes));

noisy{1} = imnoise(I, "gaussian", 0, 0.01);
noisy{2} = imnoise(I, "salt & pepper", 0.05);
noisy{3} = imnoise(I, "speckle", 0.04);

figure
montage([{I}, noisy], Size=[1 4])
title("原圖 ｜ 高斯 ｜ 椒鹽 ｜ 斑點")

figure
tiledlayout(1, 3)
for k = 1:3
    nexttile
    histogram(noisy{k}(:) - I(:), 100)
    title(noiseTypes(k) + " 的雜訊分布")
    xlabel("與原圖的差值")
end
%[text:table]
%[text] | 雜訊 | 來源 | 特性 | 分布長相 |
%[text] | --- | --- | --- | --- |
%[text] | **高斯** | 感測器熱雜訊、電路雜訊 | 每個像素加一個常態分布的值 | 鐘形，集中在 0 |
%[text] | **椒鹽** | 傳輸錯誤、壞點 | 少數像素變成全黑或全白 | 兩端各一根柱子 |
%[text] | **斑點** | 超音波、雷達、雷射 | 乘性雜訊，亮處雜訊也大 | 與亮度相關 |
%[text:table]
%[text] **關鍵差異**：高斯與斑點是「每個像素都被輕微污染」，
%[text] 椒鹽是「少數像素被完全破壞、其餘完好」。
%[text] 這個差異決定了該用什麼濾波器。
%%
%[text] # 4. 濾波器 × 雜訊類型 效果矩陣
%[text] 這是本章的核心。與其背誦「中值濾波適合椒鹽雜訊」，不如自己跑一次。
filters = { ...
    "不處理",     @(J) J; ...
    "均值 5×5",   @(J) imfilter(J, fspecial("average",5), "replicate"); ...
    "高斯 σ=1.5", @(J) imgaussfilt(J, 1.5); ...
    "中值 3×3",   @(J) medfilt2(J, [3 3]); ...
    "中值 5×5",   @(J) medfilt2(J, [5 5]); ...
    "Wiener 5×5", @(J) wiener2(J, [5 5]); ...
    "雙邊",       @(J) imbilatfilt(J); ...
    "NLM",        @(J) imnlmfilt(J)};

fprintf("%-12s", "濾波器＼雜訊");
fprintf("%20s", "高斯", "椒鹽", "斑點");
fprintf("\n%s\n", string(repmat('-', 1, 72)));

psnrMatrix = zeros(size(filters,1), 3);

for f = 1:size(filters,1)
    fprintf("%-12s", filters{f,1});
    for n = 1:3
        out = filters{f,2}(noisy{n});
        psnrMatrix(f,n) = psnr(out, I);
        fprintf("   %6.2f dB / %.3f", psnrMatrix(f,n), ssim(out, I));
    end
    fprintf("\n");
end
%%
%[text] ## 4.1 讀懂這張表
%[text] 找出每種雜訊的最佳濾波器：
for n = 1:3
    [best, idx] = max(psnrMatrix(2:end, n));
    fprintf("%-8s 最佳：%-12s (%.2f dB，比不處理進步 %.2f dB)\n", ...
        noiseTypes(n), filters{idx+1,1}, best, best - psnrMatrix(1,n));
end
%[text] **三個一定要記住的結論**：
%[text] 1. **椒鹽雜訊用中值濾波**。中值 3×3 比高斯好 3.7 dB。
%[text] 原因是中值取的是排序後的中間值，極端值（全黑或全白）
%[text] 排在兩端，根本不會被選中——它們被**完全排除**，而不是被平均進去
%[text] 2. **高斯雜訊不要用中值**。中值 3×3 的 SSIM 只有 0.529，
%[text] 比高斯濾波的 0.688 差很多。因為高斯雜訊每個像素都被污染，
%[text] 取中值選到的仍然是被污染的值
%[text] 3. **NLM 對高斯／斑點雜訊最強**（28.09 dB），但它有代價——見第 6 節 \
%%
%[text] ## 4.2 一個反直覺的結果
%[text] 注意表中「雙邊濾波 × 椒鹽雜訊」那一格：
bilateralOnSP = imbilatfilt(noisy{2});

fprintf("椒鹽雜訊 不處理    PSNR %.2f dB\n", psnr(noisy{2}, I));
fprintf("椒鹽雜訊 雙邊濾波  PSNR %.2f dB  <- 比不處理還糟\n", psnr(bilateralOnSP, I));

figure
montage({noisy{2}, bilateralOnSP, medfilt2(noisy{2},[3 3])})
title("椒鹽雜訊 ｜ 雙邊濾波（幾乎沒效果）｜ 中值濾波（乾淨）")
%[text] **為什麼**：雙邊濾波的原理是「只平均那些**亮度相近**的鄰居」，
%[text] 藉此保住邊緣。但椒鹽雜訊點的亮度與所有鄰居都差很遠，
%[text] 雙邊濾波因此判定「這是邊緣，要保留」——**它認真地把雜訊保護了起來**。
%[text] 這是很好的一課：**濾波器的設計假設決定了它的適用範圍**。
%[text] 雙邊濾波假設「亮度差異大 = 結構」，這個假設碰上椒鹽雜訊就崩潰了。
%[text] 用之前一定要問：**我的資料符合這個濾波器的假設嗎？**
%%
%[text] # 5. 保邊濾波
%[text] 平滑濾波的根本問題是它**分不出雜訊與邊緣**——兩者都是「劇烈變化」。
%[text] 保邊濾波用各種方式加入「哪些變化該保留」的判斷。
J = noisy{1};        % 高斯雜訊

edgePreserving = { ...
    "均值 5×5",     imfilter(J, fspecial("average",5), "replicate"); ...
    "高斯 σ=1.5",   imgaussfilt(J, 1.5); ...
    "雙邊",         imbilatfilt(J); ...
    "導引",         imguidedfilter(J); ...
    "非等向擴散",   imdiffusefilt(J); ...
    "NLM",          imnlmfilt(J)};

figure
montage(edgePreserving(:,2)', Size=[2 3])
title("均值 ｜ 高斯 ｜ 雙邊 ｜ 導引 ｜ 非等向擴散 ｜ NLM")
%%
%[text] ## 5.1 用數字證明「保邊」
%[text] 「保邊」不能只用看的。定義一個可量測的指標：
%[text] 取原圖梯度最強的前 10% 像素當作「邊緣」，
%[text] 比較濾波後這些位置還保有多少梯度強度。
gradOriginal = imgradient(I);
edgeMask = gradOriginal > prctile(gradOriginal(:), 90);

fprintf("%-14s %14s %10s %10s\n", "濾波器", "邊緣梯度保留", "PSNR", "SSIM");
for k = 1:size(edgePreserving,1)
    out       = edgePreserving{k,2};
    gradOut   = imgradient(out);      % MATLAB 不能對函式回傳值直接索引，先存成變數
    retention = 100 * mean(gradOut(edgeMask)) / mean(gradOriginal(edgeMask));
    fprintf("%-14s %13.1f%% %10.2f %10.3f\n", ...
        edgePreserving{k,1}, retention, psnr(out, I), ssim(out, I));
end
%[text] 分界非常清楚：
%[text] - **平滑濾波**（均值、高斯）只保留約 **37–41%** 的邊緣梯度
%[text] - **保邊濾波**保留 **87–97%** \
%[text] 這不是模糊的感覺，是可以寫進報告的數字。
%%
%[text] ## 5.2 三種保邊濾波的原理
%[text:table]
%[text] | 濾波器 | 「該保留什麼」的判斷依據 | 適合 | 注意 |
%[text] | --- | --- | --- | --- |
%[text] | **雙邊** `imbilatfilt` | 亮度相近的鄰居才平均 | 一般影像去雜訊 | 碰上椒鹽雜訊會失效（見 4.2） |
%[text] | **導引** `imguidedfilter` | 用另一張「導引影像」決定結構 | 需要跨影像對齊（深度圖精修、去霧） | 導引影像要與目標對齊 |
%[text] | **非等向擴散** `imdiffusefilt` | 沿邊緣方向擴散，不跨越邊緣 | 醫療影像 | 迭代法，較慢，要調迭代次數 |
%[text] | **NLM** `imnlmfilt` | 找整張影像中**相似的區塊**來平均 | 品質優先 | 最慢，見第 6 節 |
%[text:table]
%%
%[text] # 6. 品質與速度的取捨
%[text] 在實驗室可以只看品質，在產線上不行。把速度也量出來：
timing = { ...
    "高斯 σ=1.5",   @() imgaussfilt(J, 1.5); ...
    "中值 3×3",     @() medfilt2(J, [3 3]); ...
    "Wiener 5×5",   @() wiener2(J, [5 5]); ...
    "雙邊",         @() imbilatfilt(J); ...
    "導引",         @() imguidedfilter(J); ...
    "非等向擴散",   @() imdiffusefilt(J); ...
    "NLM",          @() imnlmfilt(J)};

baseline = psnr(J, I);

if ipcvFast()
    disp("（快速模式：略過效能量測。實測 NLM 比高斯濾波慢約 50 倍）")
else
    fprintf("%-14s %10s %10s %14s\n", "濾波器", "毫秒", "PSNR", "每 dB 成本(ms)");
    results = table;

    for k = 1:size(timing,1)
        t   = timeit(timing{k,2}) * 1000;
        out = timing{k,2}();
        p   = psnr(out, I);
        fprintf("%-14s %10.1f %10.2f %14.1f\n", timing{k,1}, t, p, t / (p - baseline));
        results = [results; table(string(timing{k,1}), t, p, ...
            VariableNames=["Filter" "Milliseconds" "PSNR"])]; %#ok<AGROW>
    end

    figure
    scatter(results.Milliseconds, results.PSNR, 80, "filled")
    text(results.Milliseconds, results.PSNR, "  " + results.Filter, VerticalAlignment="middle")
    xlabel("處理時間 (毫秒)"); ylabel("PSNR (dB)")
    title("品質 vs 速度")
    set(gca, XScale="log"); grid on
end
%[text] NLM 的品質最好，但比高斯濾波慢約 **50 倍**。
%[text] 值不值得取決於你的情境：
%[text] - **離線分析、醫療影像**：慢一點沒關係，品質優先 → NLM
%[text] - **產線即時檢測（每秒數十張）**：高斯或中值，夠用就好
%[text] - **不確定**：先用高斯建立基準，有需要再升級 \
%[text] 注意圖的橫軸是對數座標——如果用線性座標，NLM 會把其他全部擠在左邊，
%[text] 看不出差異。**畫圖時選對座標軸尺度，和選對指標一樣重要。**
%%
%[text] # 7. 自訂核與滑動視窗
%[text] 當 `fspecial` 沒有你要的核時，自己寫。
%[text] ## 7.1 自訂核
motionBlur = fspecial("motion", 15, 45);      % 15 像素、45 度的運動模糊
customEdge = [-1 -1 -1; -1 8 -1; -1 -1 -1];   % 8-鄰域 Laplacian

figure
montage({I, imfilter(I, motionBlur, "replicate"), ...
         mat2gray(imfilter(I, customEdge, "replicate"))})
title("原圖 ｜ 運動模糊核 ｜ 自訂 Laplacian 邊緣核")
%%
%[text] ## 7.2 非線性的滑動視窗運算
%[text] 卷積是**線性**運算。若你要做的不是加權求和（例如取最大值、
%[text] 算區域標準差），就需要 `nlfilter` 或專用函式。
localStd   = stdfilt(I, ones(9));      % 專用函式，快
localRange = rangefilt(I, ones(9));
localEnt   = entropyfilt(I, ones(9));

figure
montage({I, mat2gray(localStd), mat2gray(localRange), mat2gray(localEnt)}, Size=[1 4])
title("原圖 ｜ 局部標準差 ｜ 局部範圍 ｜ 局部熵")
%[text] 這三個是**紋理特徵**——平坦區域數值低，紋理豐富的區域數值高。
%[text] 第 08 章會用它們做紋理分割。
%[text] `nlfilter` 可以套用任意函式，但**非常慢**（逐像素呼叫你的函式）。
%[text] 有專用函式就用專用函式：
if ipcvFast()
    disp("（快速模式：略過。實測 stdfilt 全圖約 1.3 ms，")
    disp("  nlfilter 換算全圖約 24000 ms——慢了約 19000 倍）")
else
    tSpecial = timeit(@() stdfilt(I, ones(9)));
    Ismall   = imresize(I, 0.25);           % nlfilter 太慢，用小圖示範
    tGeneric = timeit(@() nlfilter(Ismall, [9 9], @(x) std(x(:))));

    fprintf("stdfilt 全圖      : %.1f 毫秒\n", tSpecial*1000);
    fprintf("nlfilter 1/16 大小: %.1f 毫秒（換算全圖約 %.0f 毫秒）\n", ...
        tGeneric*1000, tGeneric*1000*16);
end
%%
%[text] # 8. 銳化
%[text] 銳化是平滑的反向操作：**把影像減去它的模糊版本**，
%[text] 得到的差就是細節，再把細節加回去。這叫 **unsharp masking**。
sharpened = imsharpen(I, Radius=2, Amount=1.5);

% 手動實作，看清楚原理
blurred = imgaussfilt(I, 2);
detail  = I - blurred;
manual  = I + 1.5 * detail;

figure
montage({I, mat2gray(detail), sharpened, manual}, Size=[2 2])
title("原圖 ｜ 細節層（I − 模糊）｜ imsharpen ｜ 手動實作")

fprintf("imsharpen 與手動實作的最大差異：%.4f\n", max(abs(sharpened(:) - manual(:))));
%[text] **銳化的代價**：它同時放大細節與雜訊。
%[text] 對有雜訊的影像銳化，結果會慘不忍睹：
fprintf("\n對乾淨影像銳化    PSNR %.2f dB\n", psnr(imsharpen(I), I));
fprintf("對有雜訊影像銳化  PSNR %.2f dB  <- 雜訊被一起放大\n", psnr(imsharpen(J), I));
fprintf("先去雜訊再銳化    PSNR %.2f dB\n", psnr(imsharpen(imnlmfilt(J)), I));
%[text] **順序很重要：先去雜訊，再銳化。** 反過來做會把雜訊放大到救不回來。
%%
%[text] # 9. 評估：PSNR 與 SSIM
%[text] 本章一直在用 PSNR 與 SSIM。它們是**全參考**指標——需要乾淨的原圖當參考。
%[text:table]
%[text] | 指標 | 量什麼 | 範圍 | 注意 |
%[text] | --- | --- | --- | --- |
%[text] | **PSNR** | 逐像素誤差（基於 MSE） | dB，越高越好 | 與人眼感受不一定一致 |
%[text] | **SSIM** | 結構相似度（亮度、對比、結構） | 0–1，越高越好 | 較接近人眼判斷 |
%[text:table]
%[text] 兩者不一定一致。本章的表中就有例子：
fprintf("中值 3×3 處理高斯雜訊：PSNR %.2f dB（不錯）但 SSIM %.3f（很差）\n", ...
    psnr(medfilt2(J,[3 3]), I), ssim(medfilt2(J,[3 3]), I));
fprintf("高斯 σ=1.5 處理高斯雜訊：PSNR %.2f dB（較低）但 SSIM %.3f（較好）\n", ...
    psnr(imgaussfilt(J,1.5), I), ssim(imgaussfilt(J,1.5), I));
%[text] **PSNR 說中值比較好，SSIM 說高斯比較好。** 為什麼？
%[text] 中值濾波會產生「階梯狀」的區塊假影——逐像素誤差不大（PSNR 高），
%[text] 但破壞了局部結構（SSIM 低）。
%[text] **實務建議**：兩個都報。只報一個，讀的人無從判斷你是不是挑了對自己有利的。
%[text] 沒有乾淨原圖可參考時，要用**無參考**指標（`niqe`、`brisque`、`piqe`），
%[text] 那是第 12 章的主題。
%%
%[text] # 10. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 沒指定邊界處理方式 | 影像四周出現黑框 | 一律明寫 `"replicate"` 或 `"symmetric"` |
%[text] | 不看雜訊類型就用高斯濾波 | 椒鹽雜訊怎麼濾都在 | 先看雜訊分布，椒鹽用中值 |
%[text] | 對椒鹽雜訊用雙邊濾波 | 比不處理還糟 | 雙邊把雜訊當邊緣保護了 |
%[text] | 先銳化再去雜訊 | 雜訊被放大到救不回來 | **先去雜訊，再銳化** |
%[text] | 用 `nlfilter` 做標準差／範圍 | 慢好幾十倍 | 用 `stdfilt` `rangefilt` `entropyfilt` |
%[text] | 只報 PSNR | 可能掩蓋結構破壞 | PSNR 與 SSIM 一起報 |
%[text] | 核越大越好 | 影像糊成一片 | 核大小要配合雜訊尺度與物件尺寸 |
%[text] | 用線性座標畫「品質 vs 速度」 | 快的濾波器全擠在一起看不出差異 | 時間軸用對數座標 |
%[text] | `fspecial("gaussian", 3, 3)` | sigma=3 卻只給 3×3 的核，高斯尾巴被切掉 | 核邊長至少 `2*ceil(3*sigma)+1`，或直接用 `imgaussfilt` |
%[text:table]
%%
%[text] # 11. 本章小結
%[text] - 鄰域運算能處理點運算做不到的事：雜訊、模糊、銳化
%[text] - **先判斷雜訊類型，再選濾波器**。椒鹽用中值，高斯用 Wiener／NLM
%[text] - 平滑濾波只保留約 40% 的邊緣梯度，保邊濾波保留 87–97%
%[text] - 每個濾波器都有它的**設計假設**。雙邊濾波碰上椒鹽雜訊會把雜訊當邊緣保護
%[text] - 品質與速度要一起看。NLM 品質最好但慢 50 倍
%[text] - 先去雜訊再銳化，順序反了救不回來 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `imfilter` | 通用卷積 | **記得指定邊界處理** |
%[text] | `fspecial` | 產生常用核 | average／gaussian／laplacian／log／sobel |
%[text] | `imgaussfilt` | 高斯平滑 | 比 `imfilter` + 高斯核快，首選 |
%[text] | `medfilt2` `ordfilt2` | 中值／順序統計濾波 | **椒鹽雜訊首選** |
%[text] | `wiener2` | 自適應 Wiener | 高斯雜訊表現好 |
%[text] | `imbilatfilt` | 雙邊濾波 | 保邊，但不適合椒鹽雜訊 |
%[text] | `imguidedfilter` | 導引濾波 | 需要導引影像 |
%[text] | `imdiffusefilt` | 非等向擴散 | 醫療影像常用 |
%[text] | `imnlmfilt` | 非局部均值 | 品質最好，最慢 |
%[text] | `imsharpen` | 銳化 | Radius 與 Amount |
%[text] | `imnoise` | 加入雜訊（測試用） | gaussian／salt \& pepper／speckle |
%[text] | `stdfilt` `rangefilt` `entropyfilt` | 局部紋理統計 | 比 `nlfilter` 快得多 |
%[text] | `psnr` `ssim` `immse` | 全參考品質指標 | 兩個都要報 |
%[text] | `timeit` | 可靠的計時 | 比 `tic/toc` 準，會自動重複取樣 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 開啟 `exercise/Ch04_Exercise.m`，完成五題。解答在 `Ch04_Solution.m`。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] - [Noise Removal](https://www.mathworks.com/help/images/noise-removal.html)
%[text] - [What Is Image Filtering in the Spatial Domain?](https://www.mathworks.com/help/images/what-is-image-filtering-in-the-spatial-domain.html)
%[text] - **下一章**：第 05 章　頻域處理與小波分析——有些雜訊（例如週期性條紋）在空間域幾乎無法處理，換到頻域卻一眼就能看見並移除 \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
