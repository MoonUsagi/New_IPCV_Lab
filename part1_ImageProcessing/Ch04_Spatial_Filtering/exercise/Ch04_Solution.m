%[text] # 第 04 章　練習解答
assert(exist("ch04_autoDenoise","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = im2double(imread("cameraman.tif"));
%%
%[text] # 解答 1：從雜訊反推濾波器
rng(0);
mystery = cell(1,3);
mystery{1} = imnoise(I, "salt & pepper", 0.03);
mystery{2} = imnoise(I, "gaussian", 0, 0.008);
mystery{3} = imnoise(I, "speckle", 0.05);
mystery = mystery(randperm(3));
%[text] ## 診斷：看雜訊的分布
figure
tiledlayout(2,3)
for k = 1:3
    nexttile; imshow(mystery{k}); title("影像 " + k)
end
for k = 1:3
    nexttile
    histogram(mystery{k}(:) - I(:), 100)
    title("影像 " + k + " 的雜訊分布"); xlabel("與原圖差值")
end
%[text] ## 用數字診斷，不要只看圖
fprintf("%-8s %14s %12s %14s\n", "影像", "孤立極值%", "雜訊σ", "亮度相關性");
for k = 1:3
    X = mystery{k};

    % 特徵 1：孤立極值比 —— 椒鹽雜訊的指紋
    isolated = mean(((X==0)|(X==1)) & abs(X - medfilt2(X,[3 3])) > 0.3, "all");

    % 特徵 2：整體雜訊強度
    M = [1 -2 1; -2 4 -2; 1 -2 1];
    sigma = sqrt(pi/2)/(6*(size(X,2)-2)*(size(X,1)-2)) * sum(abs(conv2(X,M,"valid")),"all");

    % 特徵 3：雜訊大小與亮度的相關性 —— 斑點雜訊是乘性的
    resid = abs(X - I);
    corrWithBrightness = corr(I(:), resid(:));

    fprintf("影像 %d  %13.2f%% %12.4f %14.3f\n", k, 100*isolated, sigma, corrWithBrightness);
end
%[text] **判斷依據**：
%[text:table]
%[text] | 特徵 | 高斯 | 椒鹽 | 斑點 |
%[text] | --- | --- | --- | --- |
%[text] | 孤立極值比 | 低（< 0.5%） | **高（> 0.5%）** | 低 |
%[text] | 雜訊分布直方圖 | 鐘形，集中在 0 | **兩端各一根柱子** | 鐘形但較寬 |
%[text] | 與亮度的相關性 | 接近 0 | 接近 0 | **明顯為正** |
%[text:table]
%[text] 第三個特徵是區分高斯與斑點的關鍵：斑點雜訊是**乘性**的
%[text] （$g = f + n\cdot f$），所以亮的地方雜訊也大，殘差與亮度呈正相關。
%[text] 高斯雜訊是**加性**的，與亮度無關。
%%
%[text] ## 對症下藥
names = ["高斯" "椒鹽" "斑點"];
for k = 1:3
    X = mystery{k};
    isolated = mean(((X==0)|(X==1)) & abs(X - medfilt2(X,[3 3])) > 0.3, "all");

    if isolated > 0.005
        guess = "椒鹽";  J = medfilt2(X, [3 3]);        fname = "medfilt2 3×3";
    else
        resid = abs(X - I);
        if corr(I(:), resid(:)) > 0.15
            guess = "斑點";  J = imnlmfilt(X);          fname = "imnlmfilt";
        else
            guess = "高斯";  J = wiener2(X, [5 5]);     fname = "wiener2 5×5";
        end
    end

    fprintf("影像 %d 判定為 %s，用 %-12s  PSNR %.2f -> %.2f dB\n", ...
        k, guess, fname, psnr(X, I), psnr(J, I));
end
%[text] **注意**：實務上你沒有乾淨的原圖可以算殘差，所以「與亮度的相關性」
%[text] 這一招用不了。真實情況下要靠**知道雜訊的來源**——
%[text] 超音波與雷達是斑點、感測器熱雜訊是高斯、傳輸錯誤是椒鹽。
%[text] 這就是為什麼「了解你的成像系統」比會用濾波器更重要。
%%
%[text] # 解答 2：核大小怎麼選
noisy = imnoise(I, "gaussian", 0, 0.01);
sigmas = 0.5:0.25:5;
p = zeros(size(sigmas));
s = zeros(size(sigmas));

for k = 1:numel(sigmas)
    J = imgaussfilt(noisy, sigmas(k));
    p(k) = psnr(J, I);
    s(k) = ssim(J, I);
end

figure
yyaxis left
plot(sigmas, p, "-o", LineWidth=1.5); ylabel("PSNR (dB)")
yyaxis right
plot(sigmas, s, "-s", LineWidth=1.5); ylabel("SSIM")
xlabel("高斯 sigma"); title("濾波強度對品質的影響"); grid on

[~, iP] = max(p);
[~, iS] = max(s);
fprintf("PSNR 最佳 sigma = %.2f (%.2f dB)\n", sigmas(iP), p(iP));
fprintf("SSIM 最佳 sigma = %.2f (%.3f)\n",    sigmas(iS), s(iS));
%[text] **兩個指標的最佳值不一定相同**。
%[text] **為什麼超過某個 sigma 後品質下降**：這是一個典型的取捨曲線。
%[text] sigma 太小 → 雜訊沒濾乾淨，誤差主要來自**雜訊**；
%[text] sigma 太大 → 影像糊掉，誤差主要來自**失去的細節**。
%[text] 最佳點就是這兩種誤差的總和最小的地方。
%[text] 把兩種誤差分開看，會更清楚：
noiseErr  = zeros(size(sigmas));
detailErr = zeros(size(sigmas));
for k = 1:numel(sigmas)
    cleanBlur = imgaussfilt(I, sigmas(k));       % 對乾淨影像做同樣的模糊
    noisyBlur = imgaussfilt(noisy, sigmas(k));
    detailErr(k) = immse(cleanBlur, I);          % 純粹因模糊失去的細節
    noiseErr(k)  = immse(noisyBlur, cleanBlur);  % 殘留的雜訊
end

figure
plot(sigmas, detailErr, "-o", sigmas, noiseErr, "-s", ...
     sigmas, detailErr + noiseErr, "-k", LineWidth=1.5)
legend("失去的細節", "殘留的雜訊", "總誤差", Location="north")
xlabel("sigma"); ylabel("MSE"); title("兩種誤差的消長"); grid on
%[text] 這張圖是影像處理裡最重要的觀念之一：**幾乎所有參數都是在兩種
%[text] 相反的誤差之間找平衡點**。認出這個模式，你就知道該往哪個方向調。
%%
%[text] # 解答 3：驗證雙邊濾波的失效
sp = imnoise(I, "salt & pepper", 0.05);
noisePixels = (sp == 0) | (sp == 1);
noisePixels = noisePixels & abs(sp - medfilt2(sp,[3 3])) > 0.3;   % 真正的雜訊點

fprintf("雜訊點數量：%d（佔 %.2f%%）\n", nnz(noisePixels), 100*mean(noisePixels,"all"));

bilateral = imbilatfilt(sp);
median3   = medfilt2(sp, [3 3]);

% 「被保留」= 濾波後的值仍然很接近雜訊值，而不是被修正回鄰居的水準
stillNoisy = @(J) mean(abs(J(noisePixels) - sp(noisePixels)) < 0.1);

fprintf("\n雜訊點在濾波後仍保持原值的比例：\n");
fprintf("  雙邊濾波  %.1f%%  <- 幾乎全部被當成邊緣保護起來\n", 100*stillNoisy(bilateral));
fprintf("  中值濾波  %.1f%%  <- 幾乎全部被修正\n",             100*stillNoisy(median3));

figure
tiledlayout(1,3)
nexttile; imshow(sp);        title("椒鹽雜訊")
nexttile; imshow(bilateral); title(sprintf("雙邊（保留 %.0f%% 雜訊）", 100*stillNoisy(bilateral)))
nexttile; imshow(median3);   title(sprintf("中值（保留 %.0f%% 雜訊）", 100*stillNoisy(median3)))
%[text] **一句話的差別**：
%[text] 雙邊濾波問「這個鄰居跟我像不像？不像就不要平均」——
%[text] 雜訊點跟所有鄰居都不像，所以它孤零零地被保留下來；
%[text] 中值濾波問「把鄰居排序後中間那個是多少？」——
%[text] 雜訊點排在最前或最後，**永遠不會是中間那個**。
%[text] 這就是為什麼**排序**類的濾波器對脈衝雜訊有天然的免疫力。
%%
%[text] # 解答 4：自動去雜訊函式
%[text] 完整實作在 `code/ch04_autoDenoise.m`。對練習 1 的三張影像測試：
rng(0);
testCases = {"椒鹽", imnoise(I,"salt & pepper",0.03); ...
             "高斯", imnoise(I,"gaussian",0,0.008); ...
             "斑點", imnoise(I,"speckle",0.05); ...
             "乾淨", I};

fprintf("%-8s %-16s %-14s %10s %10s\n", "實際", "判定", "使用濾波器", "處理前", "處理後");
for k = 1:size(testCases,1)
    [J, r] = ch04_autoDenoise(testCases{k,2});
    fprintf("%-8s %-16s %-14s %9.2f %9.2f\n", testCases{k,1}, r.NoiseType, r.Filter, ...
        psnr(testCases{k,2}, I), psnr(J, I));
end
%[text] 四張都判定正確。注意「乾淨」那張被判定為 `none` 並**原樣回傳**——
%[text] 這是刻意的設計。對乾淨影像做去雜訊只會損失細節，沒有任何好處。
%[text] ## 判斷依據的演進
%[text] 第一版的判斷是「數有多少像素等於 0 或 1」。這個做法**失敗了**：
rng(0);
gaussNoisy = imnoise(I, "gaussian", 0, 0.008);
fprintf("\n高斯雜訊影像：\n");
fprintf("  等於極值的像素     %.2f%%  <- 看起來像椒鹽雜訊！\n", ...
    100*mean((gaussNoisy==0)|(gaussNoisy==1), "all"));
fprintf("  其中孤立的（真雜訊） %.2f%%  <- 其實不是\n", ...
    100*mean(((gaussNoisy==0)|(gaussNoisy==1)) & ...
             abs(gaussNoisy - medfilt2(gaussNoisy,[3 3])) > 0.3, "all"));
%[text] 原因是 `imnoise` 會把結果**裁切**到 [0,1]。cameraman 的大衣很暗、
%[text] 天空很亮，加上高斯雜訊後大量像素被裁到極值——看起來就像椒鹽雜訊。
%[text] 加上「必須明顯偏離局部中值」這個條件後才分得開。
%[text] **這個過程本身就是本題的重點**：你的第一個判斷依據通常是錯的，
%[text] 要用反例去測試它，才會知道它在哪裡失效。
%%
%[text] # 解答 5：先濾波再分割，有幫助嗎？
rng(0);
chips = imread("coloredChips.png");
dataDir = fullfile(tempdir, "ch04_sol_dataset");
if isfolder(dataDir), rmdir(dataDir, "s"); end
mkdir(dataDir);

variants = struct( ...
    "name", {"01_original" "02_rotated" "03_gamma06" "04_gamma15" "05_noisy" "06_blurred"}, ...
    "fcn",  {@(X) X, @(X) imrotate(X,15,"crop"), @(X) imadjust(X,[],[],0.6), ...
             @(X) imadjust(X,[],[],1.5), @(X) imnoise(X,"gaussian",0,0.002), ...
             @(X) imgaussfilt(X,2)});
for k = 1:numel(variants)
    imwrite(variants(k).fcn(chips), fullfile(dataDir, variants(k).name + ".png"));
end

base = imageDatastore(dataDir);
methods = { ...
    "不處理",       @(X) X; ...
    "高斯 σ=1",     @(X) imgaussfilt(X, 1); ...
    "NLM",          @(X) imnlmfilt(X); ...
    "autoDenoise",  @(X) ch04_autoDenoise(X)};

fprintf("%-14s %-22s %s\n", "前處理", "各張計數", "正確數");
for k = 1:size(methods,1)
    ds = transform(base, methods{k,2});
    reset(ds);
    c = zeros(6,1);
    for j = 1:6
        c(j) = height(ch02_findChips(read(ds)));
    end
    fprintf("%-14s %-22s %d/6\n", methods{k,1}, mat2str(c'), nnz(c == 6));
end
%[text] ## 結論：**針對性處理**才有用
%[text:table]
%[text] | 前處理 | 正確數 | 發生了什麼 |
%[text] | --- | --- | --- |
%[text] | 不處理 | 3/6 | 基準 |
%[text] | 高斯 σ=1 | 2/6 | 修好了雜訊那張，卻把模糊那張弄得更糟 |
%[text] | NLM | 2/6 | 同上，而且把旋轉那張也弄壞了 |
%[text] | **autoDenoise** | **4/6** | **只處理真的有雜訊的那張，其餘原樣放行** |
%[text:table]
%[text] 這是第 03 章練習 5 的延續，但結論更完整：
%[text] - 第 03 章：**增強**（點運算）修不好色相偏移，而且引入新失真 → 全部變差
%[text] - 第 04 章：**濾波**（鄰域運算）能修好雜訊，但一律套用會傷到沒問題的影像 \
%[text] 六張影像裡只有一張是雜訊問題。一律濾波等於「為了救一張，犧牲另外五張」。
%[text] `autoDenoise` 之所以贏，不是因為它的濾波器比較好，
%[text] 而是因為它**知道什麼時候不該動手**。
%[text] **前處理不是免費的。動手之前先問：這張影像真的有這個問題嗎？**
%%
%[text] # 加分題：自己實作中值濾波
Ismall = imresize(I, 0.5);      % 縮小以避免 im2col 佔用過多記憶體

padded = padarray(Ismall, [1 1], "replicate");
cols   = im2col(padded, [3 3], "sliding");      % 每一行是一個 3×3 鄰域
medVec = median(cols, 1);
myMedian = reshape(medVec, size(Ismall));

builtin = medfilt2(Ismall, [3 3]);

figure
montage({Ismall, myMedian, builtin})
title("原圖 ｜ 自己實作 ｜ medfilt2")

d = abs(myMedian - builtin);
fprintf("與 medfilt2 的最大差異：%.2e\n", max(d(:)));
fprintf("完全相同的像素比例  ：%.1f%%" + "\n", 100*mean(d(:) < 1e-10));
%[text] 差異集中在**邊界**——`medfilt2` 預設在影像外補 0，
%[text] 而我們用了 `"replicate"`。中間區域完全一致。
%[text] ## 記憶體的代價
h = 1024; w = 1024;
bytesPerElement = 8;                       % double
colsMatrix = 9 * h * w * bytesPerElement;

fprintf("\n1024×1024 影像用 im2col 展開：\n");
fprintf("  矩陣尺寸 9 × %d = %d 個元素\n", h*w, 9*h*w);
fprintf("  記憶體   %.0f MB（原影像只有 %.0f MB）\n", ...
    colsMatrix/1024^2, h*w*bytesPerElement/1024^2);
fprintf("  放大了   %d 倍\n", 9);
%[text] **這就是為什麼要用內建函式**。`medfilt2` 是逐區塊處理的，
%[text] 記憶體用量與影像大小同階；`im2col` 一次展開整張影像，
%[text] 記憶體會放大到核的元素個數倍。
%[text] 5×5 的核會放大 25 倍，7×7 放大 49 倍——很快就會爆掉。
%[text] **自己實作是為了理解原理，不是為了取代內建函式。**

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
