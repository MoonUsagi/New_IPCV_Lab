%[text] # 第 05 章　練習解答
assert(exist("ch05_notchFilter","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
I = im2double(imread("cameraman.tif"));
[rows, cols] = size(I);
[xx, yy] = meshgrid(1:cols, 1:rows);
%%
%[text] # 解答 1：從頻譜反推影像內容
puzzle = cell(1,3);
puzzle{1} = 0.5 + 0.3*sin(2*pi*yy/8);
puzzle{2} = 0.5 + 0.3*sin(2*pi*xx/8) + 0.2*sin(2*pi*yy/32);
puzzle{3} = imresize(im2double(checkerboard(32,4,4) > 0.5), [rows cols]);

answers = [
    "頻譜只有**垂直**軸上一對亮點 → 影像沿垂直方向變化 → **水平條紋**，週期 8 像素"
    "垂直軸與水平軸**各有**一對亮點，且距離不同 → 兩組正交條紋疊加，" + ...
        "水平軸的點離中心較遠（週期 8）、垂直軸的較近（週期 32）"
    "頻譜是**規則的點陣列**（多組諧波）→ 方波狀的週期圖案 → **棋盤格**"];

figure
tiledlayout(2,3)
for k = 1:3
    nexttile; imshow(puzzle{k}); title("影像 " + k)
end
for k = 1:3
    nexttile; imshow(log(1+abs(fftshift(fft2(puzzle{k})))), []); title("頻譜 " + k)
end

for k = 1:3
    fprintf("影像 %d：%s\n\n", k, answers(k));
end
%[text] **關鍵推理**：
%[text] - **亮點的方向**告訴你條紋的走向（垂直於亮點連線）
%[text] - **亮點離中心的距離**告訴你頻率高低（越遠 = 週期越短）
%[text] - **多組諧波**（等距排列的一串點）代表波形不是純正弦，
%[text] 而是方波之類含高次諧波的訊號 \
%[text] 第 3 題的棋盤格是最好的例子：純正弦只有一對點，
%[text] 方波則會產生 3 倍、5 倍、7 倍頻的一整串諧波。
%%
%[text] # 解答 2：振鈴假影有多嚴重
D = sqrt((xx - cols/2 - 1).^2 + (yy - rows/2 - 1).^2);
Fshift = fftshift(fft2(I));
cutoff = 30;

filters = { ...
    "理想",        double(D <= cutoff); ...
    "巴特沃斯 n=2", 1 ./ (1 + (D/cutoff).^4); ...
    "高斯",        exp(-(D.^2)/(2*cutoff^2))};

profileRow = 130;      % 穿過攝影機外套與天空交界的一列
profiles = zeros(3, cols);
outs = cell(1,3);

for k = 1:3
    outs{k} = real(ifft2(ifftshift(Fshift .* filters{k,2})));
    profiles(k,:) = outs{k}(profileRow, :);
end

figure
montage(outs, Size=[1 3])
title("理想 ｜ 巴特沃斯 ｜ 高斯")

figure
plot(1:cols, profiles', LineWidth=1.2)
hold on; plot(1:cols, I(profileRow,:), "k:", LineWidth=1); hold off
legend("理想", "巴特沃斯 n=2", "高斯", "原圖", Location="best")
xlabel("行"); ylabel("亮度"); title("第 " + profileRow + " 列的剖面")
grid on
%[text] ## 量化振鈴
%[text] 振鈴的特徵是剖面上出現**來回振盪**。用二階差分的能量來量化——
%[text] 平滑的曲線二階差分小，振盪的曲線二階差分大。
fprintf("%-14s %16s %14s\n", "濾波器", "二階差分能量", "符號變化次數");
for k = 1:3
    d2 = diff(profiles(k,:), 2);
    signChanges = sum(abs(diff(sign(d2))) > 0);
    fprintf("%-14s %16.4f %14d\n", filters{k,1}, sum(d2.^2), signChanges);
end
%[text] 理想濾波器的二階差分能量明顯最高——那些震盪就是振鈴。
%[text] **為什麼會這樣**：頻域的矩形窗，轉回空間域是 sinc 函式
%[text] $\mathrm{sinc}(x)=\sin(\pi x)/(\pi x)$，它有無限延伸、交替正負的尾巴。
%[text] 用它去卷積影像，每個強邊緣都會被「敲」出一圈圈漣漪。
%[text] 高斯的傅立葉轉換仍是高斯——**沒有任何振盪尾巴**，所以不會振鈴。
%[text] 這是高斯在訊號處理中無所不在的根本原因。
%%
%[text] # 解答 3：自動 notch 濾波函式
%[text] 完整實作在 `code/ch05_notchFilter.m`。用四組不同的干擾驗證：
testCases = {[0.12 0.06] 0.25; [0.20 0.00] 0.30; [0.05 0.18] 0.20; [0.30 0.30] 0.15};

fprintf("%-16s %8s %10s %10s %14s\n", "干擾頻率", "振幅", "處理前", "處理後", "移除能量");
for k = 1:size(testCases,1)
    f = testCases{k,1};
    a = testCases{k,2};
    noisy = min(max(I + a*sin(2*pi*(xx*f(1) + yy*f(2))), 0), 1);

    [clean, info] = ch05_notchFilter(noisy);

    fprintf("%-16s %8.2f %9.2f %9.2f %13.2f%%" + "\n", mat2str(f), a, ...
        psnr(noisy,I), psnr(clean,I), 100*info.RemovedEnergyRatio);
end
%[text] 四組都有 10–13 dB 的改善，且**移除的能量都在 12% 以內**——
%[text] 這正是 notch 的價值：只動被污染的那幾個頻率。
%[text] ## 為什麼一定要成對
%[text] 示範只挖一側會發生什麼：
noisy = min(max(I + 0.25*sin(2*pi*(xx*0.12 + yy*0.06)), 0), 1);
F = fftshift(fft2(noisy));

cand = abs(F);
cand(D < 20) = 0;
[~, idx] = maxk(cand(:), 4);
[pr, pc] = ind2sub([rows cols], idx);

% 只挖第一個峰值（破壞共軛對稱）
Fbad = F;
dd = sqrt((xx - pc(1)).^2 + (yy - pr(1)).^2);
Fbad(dd < 8) = 0;
badResult = ifft2(ifftshift(Fbad));

fprintf("\n只挖一個峰值：虛部最大值 %.4f（應該要接近 0）\n", max(abs(imag(badResult(:)))));

goodResult = ch05_notchFilter(noisy);
Fgood = fftshift(fft2(goodResult));
fprintf("成對挖四個  ：PSNR %.2f dB\n", psnr(goodResult, I));

figure
montage({noisy, min(max(real(badResult),0),1), goodResult})
title("有條紋 ｜ 只挖一側（殘留條紋）｜ 成對挖（乾淨）")
%[text] 只挖一側時虛部不再是浮點誤差等級，而且條紋沒有被完全移除——
%[text] 因為被挖掉的那一半的「鏡像」還在，它自己就能合成出一個實數的正弦波。
%%
%[text] # 解答 4：小波階數怎麼選
noisy2 = imnoise(I, "gaussian", 0, 0.01);
levels = 1:6;
p = zeros(size(levels));
s = zeros(size(levels));

for k = levels
    Dn = wdenoise2(noisy2, k);      % 階數是位置引數
    p(k) = psnr(Dn, I);
    s(k) = ssim(Dn, I);
end

figure
yyaxis left;  plot(levels, p, "-o", LineWidth=1.5); ylabel("PSNR (dB)")
yyaxis right; plot(levels, s, "-s", LineWidth=1.5); ylabel("SSIM")
xlabel("分解階數"); title("小波去雜訊：階數的影響"); grid on

disp(table(levels', p', s', VariableNames=["階數" "PSNR" "SSIM"]))
%[text] **結果**：階數 1 明顯不足，2 到 3 快速改善，**3 階之後就飽和了**
%[text] （PSNR 在 25.30–25.33 之間游移，差異小於 0.05 dB）。
%[text] **為什麼會飽和**：每分解一階，近似影像的邊長就減半。
%[text] 256×256 的影像分解 3 階後，近似只剩約 38×38（主教材印過尺寸表）。
%[text] 再往下分解，處理的是一張比雜訊尺度還粗的縮圖——
%[text] **那個尺度上根本沒有雜訊可去**，所以沒有任何幫助。
%[text] **實務建議**：階數取 3–4 即可。再高只是浪費運算，不會更好。
%[text] 一個好用的估法：`floor(log2(min(size(I)))) - 4`。
fprintf("\n對 %d×%d 的影像，建議階數 = %d\n", rows, cols, floor(log2(min(rows,cols))) - 4);
%%
%[text] # 解答 5：哪個視角最適合？
%[text:table]
%[text] | 情境 | 建議 | 理由 |
%[text] | --- | --- | --- |
%[text] | 1. 固定的水平掃描線干擾 | **頻域（notch）** | 規律的週期性干擾在頻譜上是孤立亮點。空間域濾波器會把細節一起糊掉 |
%[text] | 2. 低光源的顆粒感 | **空間域** | 隨機、局部的雜訊，正是空間域濾波器的設計假設。用 NLM 或 Wiener |
%[text] | 3. 找出紋理特別粗糙的區域 | **小波**（或空間域的 `stdfilt`） | 需要同時知道「高頻」與「在哪裡」。傅立葉沒有位置資訊，做不到 |
%[text] | 4. 5000×5000 影像做 101×101 高斯模糊 | **頻域（卷積定理）** | 見下方運算量分析 |
%[text:table]
%[text] ## 第 4 題的運算量分析
N = 5000; K = 101;
spatialOps = N^2 * K^2;                    % 直接卷積
separableOps = N^2 * 2*K;                  % 利用高斯可分離
fftOps = 3 * (2 * N^2 * log2(N^2));        % 兩次 FFT + 一次 IFFT

fprintf("%d×%d 影像、%d×%d 核：\n", N, N, K, K);
fprintf("  直接卷積     %.2e 次運算\n", spatialOps);
fprintf("  可分離卷積   %.2e 次運算（快 %.0f 倍）\n", separableOps, spatialOps/separableOps);
fprintf("  FFT 做法     %.2e 次運算（比直接卷積快 %.0f 倍）\n", fftOps, spatialOps/fftOps);
%[text] **在這個尺寸下 FFT 確實比可分離卷積快**，但兩者差距只有約 1.4 倍，
%[text] 遠不如對「直接卷積」的 69 倍那麼戲劇化。
%[text] 交叉點在哪？可分離卷積約 $2KN^2$ 次運算，FFT 約 $12N^2\log_2 N$ 次。
%[text] 兩者相等時 $K = 6\log_2 N$：
for N = [512 2048 5000 10000]
    fprintf("  N=%-6d 時，核邊長超過 %.0f 才輪到 FFT 較快\n", N, 6*log2(N));
end
%[text] 也就是說，**核要相當大 FFT 才划得來**，而且這還沒算 FFT 的
%[text] 記憶體開銷與邊界（circular）處理的麻煩。
%[text] 這題真正的教訓：**不要背「大核就用 FFT」**。要看三件事——
%[text] 核有沒有可分離性、核到底多大、以及你能不能接受 circular 邊界。
%[text] FFT 的優勢在**不可分離的大核**上最明顯：任意形狀的匹配樣板、
%[text] 或從量測資料得到的點擴散函數（PSF）——那些核既大又無法分解。
%%
%[text] # 加分題：混合域去雜訊
bothProblems = min(max(I + 0.25*sin(2*pi*(xx*0.12 + yy*0.06)) + 0.1*randn(rows,cols), 0), 1);

approaches = { ...
    "不處理",              bothProblems; ...
    "只 notch",            ch05_notchFilter(bothProblems); ...
    "只去雜訊 (NLM)",      imnlmfilt(bothProblems); ...
    "先 notch 再去雜訊",   imnlmfilt(ch05_notchFilter(bothProblems)); ...
    "先去雜訊再 notch",    ch05_notchFilter(imnlmfilt(bothProblems))};

fprintf("%-22s %10s\n", "做法", "PSNR");
for k = 1:size(approaches,1)
    fprintf("%-22s %9.2f dB\n", approaches{k,1}, psnr(approaches{k,2}, I));
end

figure
montage(approaches(2:5,2)', Size=[2 2])
title("只 notch ｜ 只去雜訊 ｜ 先 notch 再去雜訊 ｜ 先去雜訊再 notch")
%[text] ## 順序為什麼有差
%[text] **先 notch 再去雜訊比較好**，高出約 1.3 dB。原因：
%[text] 去雜訊濾波器（NLM、高斯等）本質上是**平滑**，它會：
%[text] 1. 讓頻譜中的干擾峰值**變寬變矮**——原本集中在幾個像素的能量被抹開
%[text] 2. 峰值不再突出，`maxk` 就更難精準定位
%[text] 3. notch 半徑固定的情況下，挖不乾淨 \
%[text] 驗證這個解釋——比較去雜訊前後干擾峰值的振幅：
[~, infoBefore] = ch05_notchFilter(bothProblems);
[~, infoAfter]  = ch05_notchFilter(imnlmfilt(bothProblems));

fprintf("\n干擾峰值振幅（前兩個）：\n");
fprintf("  去雜訊前 %.0f, %.0f\n", infoBefore.PeakMagnitudes(1:2));
fprintf("  去雜訊後 %.0f, %.0f  <- 被削弱了\n", infoAfter.PeakMagnitudes(1:2));
%[text] **通用原則**：**先處理結構性的問題，再處理隨機性的問題**。
%[text] 結構性問題（週期干擾、幾何失真）有明確的特徵可以定位，
%[text] 一旦被隨機性處理（平滑、去雜訊）抹過，特徵就模糊了，更難精準處理。
%[text] 反過來則不會——notch 只動幾個頻率，幾乎不影響隨機雜訊的統計特性。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
