%[text] # 第 05 章　頻域處理與小波分析
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 讀懂影像的頻譜圖，說出哪個區域代表什麼
%[text] 2. 設計頻域濾波器，並知道為什麼不能用「理想」濾波器
%[text] 3. **移除週期性條紋雜訊**——空間域幾乎做不到的事
%[text] 4. 用小波做多尺度分解，理解它與傅立葉的根本差異
%[text] 5. 判斷一個問題該用空間域、頻域，還是小波 \
%[text] ## 前置知識
%[text] 第 04 章（空間域濾波）。本章是它的對照組：同樣是處理雜訊與細節，
%[text] 但換一個完全不同的視角。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="05", Verbose=false);
rng(0);
disp("環境檢查通過。")
%%
%[text] # 1. 換一個視角看影像
%[text] 前四章我們都在**空間域**工作：影像是一個 $M\times N$ 的矩陣，
%[text] 每個位置存一個亮度值。
%[text] **頻域**提供另一種描述：把影像看成許多不同頻率的正弦波疊加而成。
%[text] 低頻對應大範圍的緩慢變化（整體明暗、大塊區域），
%[text] 高頻對應劇烈變化（邊緣、細節、雜訊）。
%[text] 這兩種描述**完全等價**——傅立葉轉換可以無損地來回轉換。
%[text] 換視角的價值在於：**有些在空間域很難處理的問題，在頻域一眼就能看見。**
%[text] 本章第 4 節的週期性條紋就是最好的例子。
I = im2double(imread("cameraman.tif"));

F = fft2(I);
Fshift = fftshift(F);              % 把零頻移到中心，方便觀看
magnitude = log(1 + abs(Fshift));  % 取對數，否則中心亮點會蓋過一切

figure
tiledlayout(1,2)
nexttile; imshow(I); title("空間域")
nexttile; imshow(magnitude, []); title("頻域（對數振幅頻譜）")
%[text] **為什麼要取對數**：頻譜的動態範圍極大，直流分量（中心那點）通常比
%[text] 其他頻率大好幾個數量級。不取對數的話，整張圖只會看到中心一個白點。
fprintf("中心（直流）分量：%.0f\n", abs(Fshift(end/2+1, end/2+1)));
fprintf("平均振幅        ：%.0f\n", mean(abs(Fshift), "all"));
fprintf("相差            ：%.0f 倍\n", abs(Fshift(end/2+1, end/2+1))/mean(abs(Fshift),"all"));
%%
%[text] ## 1.1 頻譜怎麼讀
%[text:table]
%[text] | 頻譜位置 | 對應影像中的 |
%[text] | --- | --- |
%[text] | 中心（低頻） | 整體亮度、大塊平坦區域 |
%[text] | 外圍（高頻） | 邊緣、細節、雜訊 |
%[text] | 水平方向的亮線 | 影像中的**垂直**結構 |
%[text] | 垂直方向的亮線 | 影像中的**水平**結構 |
%[text] | 孤立的亮點 | **週期性圖案**（條紋、網點） |
%[text:table]
%[text] 方向會轉 90 度是初學者最容易搞混的地方。用一張人造影像確認：
[rows, cols] = size(I);
[xx, yy] = meshgrid(1:cols, 1:rows);

vertStripes  = 0.5 + 0.5*sin(2*pi*xx/16);   % 垂直條紋（沿水平方向變化）
horizStripes = 0.5 + 0.5*sin(2*pi*yy/16);   % 水平條紋

figure
tiledlayout(2,2)
nexttile; imshow(vertStripes);  title("垂直條紋")
nexttile; imshow(log(1+abs(fftshift(fft2(vertStripes)))), []); title("頻譜：亮點在水平軸上")
nexttile; imshow(horizStripes); title("水平條紋")
nexttile; imshow(log(1+abs(fftshift(fft2(horizStripes)))), []); title("頻譜：亮點在垂直軸上")
%[text] 記法：**頻譜上的亮點方向，垂直於影像中條紋的走向**。
%[text] 因為「垂直條紋」是沿著**水平方向**在變化，變化方向才是頻率的方向。
%%
%[text] # 2. 頻域濾波
%[text] 頻域濾波的做法極為直觀：
%[text] 1. `fft2` 轉到頻域
%[text] 2. 乘上一個遮罩（保留想要的頻率、壓掉不想要的）
%[text] 3. `ifft2` 轉回空間域 \
%[text] ## 2.1 低通與高通
D = sqrt((xx - cols/2 - 1).^2 + (yy - rows/2 - 1).^2);   % 每點到中心的距離
cutoff = 30;

lowpassMask  = D <= cutoff;
highpassMask = D >  cutoff;

lowpassed  = real(ifft2(ifftshift(Fshift .* lowpassMask)));
highpassed = real(ifft2(ifftshift(Fshift .* highpassMask)));

figure
montage({I, lowpassed, mat2gray(highpassed)}, Size=[1 3])
title("原圖 ｜ 低通（只留低頻）｜ 高通（只留高頻）")
%[text] 低通結果是模糊的——保留了整體結構，丟掉了細節。
%[text] 高通結果只剩邊緣——這其實就是一種邊緣偵測（第 10 章會用別的方法做）。
%%
%[text] ## 2.2 為什麼不能用「理想」濾波器
%[text] 上面那個非 0 即 1 的遮罩叫**理想濾波器**。它有一個嚴重的問題：
%[text] 在截止頻率處是**突然切斷**的，這會在空間域產生**振鈴假影**（ringing）。
cutoffs = [10 30 60];
ideal = cell(1, numel(cutoffs));
for k = 1:numel(cutoffs)
    ideal{k} = real(ifft2(ifftshift(Fshift .* (D <= cutoffs(k)))));
end

figure
montage(ideal, Size=[1 3])
title("理想低通 截止 = 10 ｜ 30 ｜ 60（注意邊緣附近的波紋）")
%[text] 那些一圈一圈的波紋就是振鈴。它的成因是：頻域的**矩形**函式，
%[text] 轉回空間域會變成 **sinc** 函式——而 sinc 有無限延伸的振盪尾巴。
%[text] 解法是讓濾波器的過渡**平滑**。高斯與巴特沃斯是兩個常用選擇：
gaussianLP   = exp(-(D.^2) / (2*cutoff^2));
butterworthLP = 1 ./ (1 + (D/cutoff).^(2*2));      % n=2 階

comparison = { ...
    real(ifft2(ifftshift(Fshift .* (D <= cutoff)))), ...
    real(ifft2(ifftshift(Fshift .* butterworthLP))), ...
    real(ifft2(ifftshift(Fshift .* gaussianLP)))};

figure
montage(comparison, Size=[1 3])
title("理想（有振鈴）｜ 巴特沃斯 n=2 ｜ 高斯（最平滑）")

figure
plot(0:100, [double((0:100) <= cutoff); ...
             1./(1+((0:100)/cutoff).^4); ...
             exp(-((0:100).^2)/(2*cutoff^2))]', LineWidth=1.5)
legend("理想", "巴特沃斯 n=2", "高斯", Location="northeast")
xlabel("與中心的距離"); ylabel("保留比例"); title("三種低通濾波器的頻率響應")
grid on
%[text] **實務建議**：需要頻域低通時用**高斯**——它在空間域也是高斯，
%[text] 沒有任何振盪尾巴，不會產生振鈴。
%%
%[text] # 3. 卷積定理：兩個世界是同一件事
%[text] **空間域的卷積 = 頻域的相乘**。這不只是理論，它有實際用途：
%[text] 大核的卷積在頻域算會快得多。
%[text] 驗證一下：
h = fspecial("gaussian", 31, 5);

spatialResult = imfilter(I, h, "circular");     % 用 circular 才與 FFT 一致

hPadded = zeros(size(I));
hPadded(1:size(h,1), 1:size(h,2)) = h;
hPadded = circshift(hPadded, -floor(size(h)/2));   % 把核的中心移到原點
freqResult = real(ifft2(fft2(I) .* fft2(hPadded)));

figure
montage({spatialResult, freqResult, mat2gray(abs(spatialResult - freqResult))})
title("空間域卷積 ｜ 頻域相乘 ｜ 兩者差異")

fprintf("兩種做法的最大差異：%.2e（浮點誤差等級）\n", ...
    max(abs(spatialResult(:) - freqResult(:))));
%[text] **注意那個 `"circular"`**。FFT 隱含假設影像是週期性重複的，
%[text] 所以只有 `"circular"` 邊界條件才會與頻域做法完全一致。
%[text] 用 `"replicate"` 會在邊界產生差異——這是比較兩種做法時最常見的困惑來源。
%%
%[text] # 4. 殺手級應用：移除週期性雜訊
%[text] 這是頻域處理**真正不可取代**的場合。
%[text] 週期性雜訊來自掃描器的機械震動、螢幕翻拍的摩爾紋、
%[text] 感測器的電源干擾——在空間域它遍布整張影像，無從下手；
%[text] 在頻域它只是**幾個孤立的亮點**。
stripes = 0.25 * sin(2*pi*(xx*0.12 + yy*0.06));    % 斜向條紋干擾
Inoisy  = min(max(I + stripes, 0), 1);

Fnoisy = fftshift(fft2(Inoisy));

figure
tiledlayout(2,2)
nexttile; imshow(I);      title("原圖")
nexttile; imshow(log(1+abs(Fshift)), []);  title("原圖頻譜")
nexttile; imshow(Inoisy); title(sprintf("加入條紋（PSNR %.2f dB）", psnr(Inoisy, I)))
nexttile; imshow(log(1+abs(Fnoisy)), []);  title("頻譜：多出四個亮點")
%%
%[text] ## 4.1 先看空間域的方法有多無力
fprintf("加入條紋後      PSNR %.2f dB\n", psnr(Inoisy, I));
fprintf("高斯濾波 σ=2    PSNR %.2f dB\n", psnr(imgaussfilt(Inoisy, 2), I));
fprintf("中值濾波 5×5    PSNR %.2f dB\n", psnr(medfilt2(Inoisy, [5 5]), I));
fprintf("NLM             PSNR %.2f dB\n", psnr(imnlmfilt(Inoisy), I));

figure
montage({Inoisy, imgaussfilt(Inoisy,2), medfilt2(Inoisy,[5 5])})
title("有條紋 ｜ 高斯濾波 ｜ 中值濾波 —— 條紋都還在")
%[text] 空間域濾波器全都失敗。它們的設計假設是「雜訊是局部的、隨機的」，
%[text] 而週期性條紋是**全域的、有結構的**——假設不成立。
%[text] 要壓掉條紋，必須把影像糊到細節也一起消失。
%%
%[text] ## 4.2 Notch 濾波：精準狙擊
%[text] 在頻域，條紋只佔幾個像素。把它們挖掉，其餘頻率完全不動。
%[text] 先自動找出那些峰值——排除中心低頻區域後取最大的幾個點：
centerRow = floor(rows/2) + 1;
centerCol = floor(cols/2) + 1;

searchMask = D >= 20;                 % 排除中心低頻
candidates = abs(Fnoisy);
candidates(~searchMask) = 0;

[~, peakIdx] = maxk(candidates(:), 4);
[peakRows, peakCols] = ind2sub([rows cols], peakIdx);

fprintf("找到的干擾峰值：\n");
for k = 1:numel(peakRows)
    fprintf("  (%3d, %3d)  距中心 %.1f  振幅 %.0f\n", ...
        peakRows(k), peakCols(k), hypot(peakRows(k)-centerRow, peakCols(k)-centerCol), ...
        abs(Fnoisy(peakRows(k), peakCols(k))));
end
%[text] 四個峰值成兩對對稱分布——**實數影像的頻譜必定共軛對稱**，
%[text] 所以干擾一定成對出現。挖的時候要成對挖，否則結果會有虛部。
notchRadius = 8;
Fclean = Fnoisy;

for k = 1:numel(peakRows)
    dist = sqrt((xx - peakCols(k)).^2 + (yy - peakRows(k)).^2);
    Fclean(dist < notchRadius) = 0;
end

restored = real(ifft2(ifftshift(Fclean)));
restored = min(max(restored, 0), 1);

figure
tiledlayout(2,2)
nexttile; imshow(Inoisy);   title("有條紋")
nexttile; imshow(log(1+abs(Fnoisy)), []);  title("頻譜（四個亮點）")
nexttile; imshow(restored); title(sprintf("Notch 濾波後（PSNR %.2f dB）", psnr(restored, I)))
nexttile; imshow(log(1+abs(Fclean)), []);  title("挖掉亮點後的頻譜")
%%
%[text] ## 4.3 比較
methods = ["加入條紋（未處理）" "高斯 σ=2" "中值 5×5" "NLM" "Notch 濾波"];
values  = [psnr(Inoisy, I), psnr(imgaussfilt(Inoisy,2), I), ...
           psnr(medfilt2(Inoisy,[5 5]), I), psnr(imnlmfilt(Inoisy), I), ...
           psnr(restored, I)];

figure
barh(categorical(methods, methods), values)
xlabel("PSNR (dB)"); title("週期性條紋：頻域完勝空間域")
grid on

for k = 1:numel(methods)
    fprintf("%-22s %.2f dB\n", methods(k), values(k));
end
%[text] Notch 濾波比最好的空間域方法高出 **5 dB 以上**，
%[text] 而且**細節完全保留**——因為它只動了那幾個被污染的頻率。
%[text] **這就是換視角的價值**：同一個問題，換個座標系就從「幾乎無解」
%[text] 變成「精準可解」。
%%
%[text] # 5. 小波：傅立葉解決不了的問題
%[text] 傅立葉轉換有一個根本限制：它告訴你影像**有哪些頻率**，
%[text] 但**完全不告訴你這些頻率出現在哪裡**。
%[text] 每一個傅立葉係數都是整張影像的加總——它是**全域**的。
%[text] 對於「左半邊平滑、右半邊有紋理」這種影像，傅立葉只會說
%[text] 「這張圖有高頻」，卻無法說出高頻集中在右半邊。
%[text] **小波轉換同時保留頻率與位置資訊**。這是它與傅立葉的根本差異。
halfSmooth = I;
halfSmooth(:, 1:cols/2) = imgaussfilt(I(:, 1:cols/2), 5);   % 左半邊糊掉

figure
tiledlayout(1,2)
nexttile; imshow(halfSmooth); title("左半平滑、右半銳利")
nexttile; imshow(log(1+abs(fftshift(fft2(halfSmooth)))), []); title("頻譜看不出「左」「右」")
%%
%[text] ## 5.1 多尺度分解
%[text] 小波把影像分解成一個**近似**（低頻）與三個**細節**（水平、垂直、對角）。
%[text] 然後對近似再分解一次，如此重複——這就是「多尺度」。
[c, s] = wavedec2(I, 3, "sym4");

fprintf("原影像     %d 像素\n", numel(I));
fprintf("3 階分解係數 %d 個\n", numel(c));
fprintf("各階尺寸表：\n");
disp(s)

% 取出第 1 階的三個細節方向
[H1, V1, Dg1] = detcoef2("all", c, s, 1);
A3 = appcoef2(c, s, "sym4", 3);

figure
tiledlayout(2,2)
nexttile; imshow(mat2gray(A3));  title("第 3 階近似（最粗尺度）")
nexttile; imshow(mat2gray(H1));  title("第 1 階 水平細節")
nexttile; imshow(mat2gray(V1));  title("第 1 階 垂直細節")
nexttile; imshow(mat2gray(Dg1)); title("第 1 階 對角細節")
%[text] 注意三個細節子帶各自**只對某個方向的邊緣有反應**——
%[text] 水平細節裡看得到攝影機的水平邊緣，垂直細節裡看得到三腳架的直線。
%[text] 而且每個係數都對應影像中的一個**位置**，這是傅立葉做不到的。
%%
%[text] ## 5.2 用小波看「左右不同」
[c2, s2] = wavedec2(halfSmooth, 2, "sym4");
[H2, V2, D2] = detcoef2("all", c2, s2, 1);
detailEnergy = abs(H2) + abs(V2) + abs(D2);

figure
tiledlayout(1,2)
nexttile; imshow(halfSmooth); title("左半平滑、右半銳利")
nexttile; imshow(mat2gray(detailEnergy)); title("小波細節能量：左邊暗、右邊亮")

leftHalf  = detailEnergy(:, 1:floor(end/2));
rightHalf = detailEnergy(:, floor(end/2)+1:end);
fprintf("左半細節能量 %.4f\n", mean(leftHalf, "all"));
fprintf("右半細節能量 %.4f  <- 是左半的 %.1f 倍\n", ...
    mean(rightHalf, "all"), mean(rightHalf,"all")/mean(leftHalf,"all"));
%[text] 小波清楚地告訴我們「高頻在右邊」。
%[text] 這個「頻率 + 位置」的能力，是小波在影像壓縮（JPEG 2000）、
%[text] 去雜訊、與多尺度分析上的基礎。
%%
%[text] # 6. 小波去雜訊
%[text] 原理很直觀：雜訊在小波域是**遍布所有係數的小值**，
%[text] 真實結構則是**少數幾個大值**。把小的係數歸零（軟門檻），
%[text] 就能去掉雜訊而保留結構。
noisy = imnoise(I, "gaussian", 0, 0.01);

fprintf("%-12s %10s %10s\n", "方法", "PSNR", "SSIM");
fprintf("%-12s %10.2f %10.3f\n", "未處理", psnr(noisy,I), ssim(noisy,I));

waveletResults = {};
for w = ["sym4" "db4" "coif3"]
    D = wdenoise2(noisy, Wavelet=w);
    waveletResults{end+1} = D; %#ok<SAGROW>
    fprintf("%-12s %10.2f %10.3f\n", "小波 " + w, psnr(D,I), ssim(D,I));
end

fprintf("%-12s %10.2f %10.3f\n", "wiener2", psnr(wiener2(noisy,[5 5]),I), ssim(wiener2(noisy,[5 5]),I));
fprintf("%-12s %10.2f %10.3f\n", "NLM",     psnr(imnlmfilt(noisy),I),     ssim(imnlmfilt(noisy),I));

figure
montage({noisy, waveletResults{1}, wiener2(noisy,[5 5]), imnlmfilt(noisy)}, Size=[1 4])
title("有雜訊 ｜ 小波 sym4 ｜ Wiener ｜ NLM")
%[text] **小波在這個例子上不是最好的**（NLM 較高），但它有兩個優勢：
%[text] 1. **速度**比 NLM 快得多
%[text] 2. 對**非平穩**的雜訊（不同區域雜訊強度不同）表現較好，
%[text] 因為它的門檻是逐尺度、逐區域決定的 \
%[text] 換不同的小波基（sym4／db4／coif3）差異很小——
%[text] **不要花太多時間在挑小波基上**，尺度數與門檻策略的影響大得多。
%%
%[text] # 7. Wavelet Image Analyzer
%[text] MATLAB 提供互動式的小波分析 APP，可以即時調整小波基、
%[text] 分解階數與門檻，並匯出程式碼——又是第 02 章的五步驟工作流。
interactive = false;    % 改成 true 以開啟 APP

if interactive
    waveletImageAnalyzer(I)
end
%[text] APP 的價值在於**快速比較**：同時看到不同階數的分解結果，
%[text] 立刻知道該用幾階。用程式碼一個一個試會慢得多。
%%
%[text] # 8. 三種視角該怎麼選
%[text:table]
%[text] | 問題 | 空間域（第 04 章） | 頻域（本章） | 小波（本章） |
%[text] | --- | --- | --- | --- |
%[text] | 隨機雜訊 | **首選**，簡單直接 | 可行但沒有優勢 | 好，尤其非平穩雜訊 |
%[text] | 椒鹽雜訊 | **中值濾波** | 不適合 | 不適合 |
%[text] | **週期性條紋** | 幾乎無解 | **唯一解** | 可行但較麻煩 |
%[text] | 大核卷積 | 慢 | **快**（卷積定理） | — |
%[text] | 多尺度分析 | 要自己做影像金字塔 | 不行（無位置資訊） | **天生適合** |
%[text] | 影像壓縮 | — | JPEG（DCT） | JPEG 2000 |
%[text] | 需要可解釋性 | **最好**，每一步都直觀 | 中等 | 較抽象 |
%[text:table]
%[text] **決策順序**：先試空間域（簡單、快、好解釋）。
%[text] 看到規律性的干擾圖案，立刻去看頻譜。
%[text] 需要同時知道「什麼頻率」與「在哪裡」，才用小波。
%%
%[text] # 9. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 忘記 `fftshift` | 頻譜的四個角落是低頻，看不懂 | 顯示前一律 `fftshift` |
%[text] | 沒取對數就顯示頻譜 | 只看到中心一個白點 | `log(1 + abs(F))` |
%[text] | 用理想（矩形）濾波器 | 邊緣出現一圈圈振鈴 | 用高斯或巴特沃斯 |
%[text] | Notch 只挖一個峰值 | 結果有虛部、影像不對 | 頻譜共軛對稱，**必須成對挖** |
%[text] | `ifft2` 後直接用 | 有微小虛部造成後續錯誤 | 加 `real()` |
%[text] | 比較空間域與頻域卷積時用 `"replicate"` | 邊界對不上，以為算錯 | FFT 對應的是 `"circular"` |
%[text] | 花時間挑小波基 | 投資報酬率極低 | 差異通常 < 0.1 dB；先調階數與門檻 |
%[text] | 以為傅立葉能定位 | 找不出「高頻在哪裡」 | 那是小波的工作 |
%[text:table]
%%
%[text] # 10. 本章小結
%[text] - 頻域與空間域是**同一張影像的兩種等價描述**，換視角是為了讓問題變簡單
%[text] - 頻譜上的亮點方向，**垂直於**影像中條紋的走向
%[text] - 理想濾波器會產生振鈴，實務上用高斯
%[text] - **週期性雜訊是頻域不可取代的場合**——本章實測比最好的空間域方法高 5 dB
%[text] - 傅立葉告訴你有哪些頻率，**小波還告訴你它們在哪裡**
%[text] - 決策順序：空間域 → 看到規律干擾就看頻譜 → 需要定位才用小波 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `fft2` `ifft2` | 二維傅立葉轉換 | `ifft2` 後記得 `real()` |
%[text] | `fftshift` `ifftshift` | 零頻移到中心／移回去 | 顯示與濾波都需要 |
%[text] | `abs` `angle` | 振幅與相位 | 顯示振幅要取 `log` |
%[text] | `wavedec2` `waverec2` | 小波分解／重建 | |
%[text] | `appcoef2` `detcoef2` | 取出近似／細節係數 | |
%[text] | `wdenoise2` | 小波去雜訊 | 一行搞定，預設值就不錯 |
%[text] | `waveletImageAnalyzer` | 互動式小波分析 APP | 可匯出程式碼 |
%[text] | `dwt2` `idwt2` | 單階小波轉換 | 教學用，實務用 `wavedec2` |
%[text:table]
%%
%[text] # 11. 練習
%[text] 開啟 `exercise/Ch05_Exercise.m`，完成五題。解答在 `Ch05_Solution.m`。
%%
%[text] # 12. 延伸閱讀與下一章
%[text] - [Fourier Transform](https://www.mathworks.com/help/images/fourier-transform.html)
%[text] - [Wavelet Image Analyzer](https://www.mathworks.com/help/wavelet/ref/waveletimageanalyzer-app.html)
%[text] - **下一章**：第 06 章　形態學影像處理——處理**二值影像的形狀**，是分割之後最常用的一組工具 \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
