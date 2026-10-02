function [f50, f20, mtf, freq] = ch12_measureMTF(E, options)
%CH12_MEASUREMTF 用斜邊法（ISO 12233）量測 MTF。
%
%   F50 = CH12_MEASUREMTF(E) 回傳 MTF 降到 0.5 的空間頻率，
%   單位是 cycles/pixel（0.5 = Nyquist 極限）。
%
%   [F50, F20, MTF, FREQ] = CH12_MEASUREMTF(E) 另外回傳 MTF=0.2 的頻率，
%   以及完整的 MTF 曲線與對應頻率軸。
%
%   名稱-值引數：
%     SuperSample  超取樣間距（像素），預設 0.25
%     Window       是否對 LSF 加 Hann 窗，預設 true
%
%   流程（與 esfrChart/measureSharpness 內部相同）
%   ---------------------------------------------
%     1. 對每一列求邊緣位置的**質心**（次像素精度）
%     2. 依各列的質心把所有列對齊，疊合成一條**超取樣**的 ESF
%     3. 微分 ESF 得到 LSF（線擴散函數）
%     4. 對 LSF 做 FFT，取絕對值並正規化，得到 MTF
%     5. 內插找出 MTF 穿過 0.5 與 0.2 的頻率
%
%   **有效範圍：MTF50 約 0.05–0.25 cycles/pixel**
%   ---------------------------------------------
%   第 12 章第 8.1 節用已知模糊量的合成斜邊驗證過本函式
%   （ch12_makeSlantedEdge，感測器 sigma=0.6）：
%
%     額外模糊 sigma   實測 f50   理論 f50   實測/理論
%          0            0.2845     0.3123      0.911
%          0.5          0.2335     0.2400      0.973
%          1            0.1578     0.1607      0.982
%          2            0.0941     0.0897      1.048
%          3            0.0671     0.0612      1.095
%
%   **中間段吻合到 2–5%，但兩端各偏約 9–10%，而且方向相反：**
%
%   · **最銳利端偏低。** 第 3 步用有限差分求 LSF，而差分本身是低通濾波器
%     （其轉換函數為 sinc），頻率越高壓得越多。當 f50 接近 Nyquist 時，
%     被壓掉的量就不能忽略。
%
%   · **最模糊端偏高。** 此時 LSF 很寬，Hann 窗會截掉它的尾部，
%     等效於讓 LSF 變窄 → MTF 變高。設 Window=false 可以避免這一項，
%     但代價是頻譜洩漏會讓曲線變得毛躁。
%
%   換句話說，本函式**不是**通用的精密量測工具，
%   而是一個「在中間段可信、兩端有已知偏差」的教學實作。
%   要做可追溯的鏡頭驗收，請用真實 eSFR 圖卡 + ESFRCHART。
%
%   > 這支函式最重要的價值不是它的數字，而是**它的數字被驗證過**。
%   > 一支沒有用已知答案對照過的量測程式，產生的結果無法判斷可信度。
%
%   範例：
%     E = ch12_makeSlantedEdge(256, 256, 5, 0.6);
%     [f50, f20, mtf, freq] = ch12_measureMTF(E);
%
%     figure
%     plot(freq, mtf, LineWidth=1.6)
%     yline(0.5, "--"); xline(f50, "--");
%     xlabel("空間頻率 (cycles/pixel)"); ylabel("MTF")
%     title(sprintf("MTF50 = %.4f cycles/pixel", f50))
%
%   另見 CH12_MAKESLANTEDEDGE, ESFRCHART, MEASURESHARPNESS.

arguments
    E {mustBeNumeric, mustBeNonempty}
    options.SuperSample (1,1) double {mustBePositive} = 0.25
    options.Window      (1,1) logical                 = true
end

E = im2double(E);
if size(E,3) > 1
    E = im2gray(E);
end

[h, w] = size(E);
if h < 16 || w < 16
    error("ch12_measureMTF:tooSmall", ...
        "影像太小（%dx%d）。斜邊法需要足夠的列數來累積超取樣剖面。", h, w);
end

% --- 1. 每一列的邊緣質心（次像素）----------------------------------
centroid = nan(h, 1);
for r = 1:h
    d = abs(diff(E(r,:)));
    total = sum(d);
    if total > 0
        centroid(r) = sum(d .* (1.5:w-0.5)) / total;
    end
end

valid = isfinite(centroid);
if nnz(valid) < 8
    error("ch12_measureMTF:noEdge", ...
        "只有 %d 列找得到邊緣。請確認影像中真的有一條貫穿的邊。", nnz(valid));
end

% 邊緣是否真的傾斜？完全垂直的邊無法超取樣
spread = max(centroid(valid)) - min(centroid(valid));
if spread < 1
    warning("ch12_measureMTF:edgeNotSlanted", ...
        "邊緣質心在各列之間只移動了 %.2f 像素，幾乎是垂直的。" + ...
        "斜邊法靠各列落在不同次像素位置來超取樣——" + ...
        "邊不夠斜時，結果會被像素格點限制而偏低。", spread);
end

% --- 2. 對齊疊合成超取樣 ESF ----------------------------------------
gridX = -20 : options.SuperSample : 20;
acc = zeros(size(gridX));
cnt = zeros(size(gridX));
for r = 1:h
    if ~valid(r), continue; end
    xr = (1:w) - centroid(r);
    vals = interp1(xr, E(r,:), gridX, "linear", NaN);
    ok = isfinite(vals);
    acc(ok) = acc(ok) + vals(ok);
    cnt(ok) = cnt(ok) + 1;
end

keep = cnt > 0;
esf  = acc(keep) ./ cnt(keep);
gx   = gridX(keep);

if numel(esf) < 16
    error("ch12_measureMTF:esfTooShort", ...
        "疊合後的 ESF 只有 %d 點，不足以做頻譜分析。", numel(esf));
end

% --- 3. 微分得 LSF ---------------------------------------------------
lsf = diff(esf);

% 去掉兩端的直流偏移（邊緣外應該是平的）
nEnd = max(3, round(numel(lsf)*0.05));
lsf  = lsf - mean(lsf([1:nEnd, end-nEnd+1:end]));

if options.Window
    lsf = lsf .* hann(numel(lsf))';
end

% --- 4. FFT 得 MTF ---------------------------------------------------
M = abs(fft(lsf));
if M(1) == 0
    error("ch12_measureMTF:zeroDC", "LSF 的直流項為零，無法正規化 MTF。");
end
M = M / M(1);

dx   = gx(2) - gx(1);                        % 超取樣間距（像素）
n    = numel(M);
freq = (0:n-1) / (n*dx);                     % cycles/pixel
half = 1:floor(n/2);
mtf  = M(half);
freq = freq(half);

% --- 5. 找 0.5 與 0.2 的穿越點 --------------------------------------
f50 = firstCrossing(freq, mtf, 0.5);
f20 = firstCrossing(freq, mtf, 0.2);
end

% ========================================================================
function fc = firstCrossing(freq, mtf, level)
%FIRSTCROSSING 線性內插找出 MTF 第一次降到 LEVEL 的頻率。
%
%   一定要取**第一次**穿越。MTF 曲線在高頻可能因雜訊而來回擺動，
%   取最後一次或取最小值都會得到偏高的假結果。

idx = find(mtf < level, 1, "first");

if isempty(idx)
    fc = NaN;                % 整條曲線都在 level 以上：影像比量測範圍還銳利
    return
end
if idx == 1
    fc = NaN;                % 第一點就低於 level：完全解析不出來
    return
end

fc = interp1(mtf([idx-1 idx]), freq([idx-1 idx]), level);
end
