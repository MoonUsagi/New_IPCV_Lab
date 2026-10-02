function [report, detail] = ch13_inpaintCompare(I, mask, options)
%CH13_INPAINTCOMPARE 用正確答案比較三種修復方法，並**同時**回報兩類指標。
%
%   REPORT = CH13_INPAINTCOMPARE(I, MASK) 把 I 的 MASK 區域挖掉再修復，
%   以 I 本身為 ground truth，回傳比較 table。
%
%   [REPORT, DETAIL] = CH13_INPAINTCOMPARE(___) 另外回傳 struct：
%     Table            含紋理指標的完整 table
%     ReferenceEnergy  原圖在洞內的梯度能量（正確答案）
%     BestByPSNR       PSNR 最高的方法
%     BestByTexture    能量比最接近 1 的方法
%     Agree            兩個判準是否給出同一個答案
%     Note             人類可讀的結論
%
%   名稱-值引數：
%     PatchSize    inpaintExemplar 的補丁大小，預設 [9 9]（函式預設值）
%     FillOrder    inpaintExemplar 的填補順序，預設 "gradient"
%     Smoothing    inpaintCoherent 的 SmoothingFactor，預設 2
%     Radius       inpaintCoherent 的 Radius，預設 5
%
%   為什麼要**同時**回報兩類指標
%   ----------------------------
%   PSNR 與 SSIM 都偏好模糊（第 12 章第 3 節）。單看它們會選錯方法。
%
%   第 13 章第 4 節實測（peppers.png、90x90 的洞）：
%
%     方法               PSNR     SSIM     能量比
%     inpaintExemplar   12.981   0.3285   1.340
%     inpaintCoherent   16.135   0.5593   0.784
%     regionfill        16.503   0.5502   0.322
%
%   **PSNR 的第一名是 regionfill——而它的紋理只有原圖的 32%。**
%   它把洞填成一塊平滑色斑，逐像素誤差小，但人眼一看就知道被改過。
%
%   反過來只看紋理會選到 inpaintExemplar，而它的紋理**超出 34%**
%   （補丁接縫製造的假梯度），PSNR 也是最差的。
%
%   兩個一起看，才會選到 inpaintCoherent：PSNR 只差第一名 0.37 dB，
%   紋理比 0.784 是三者最接近 1 的。
%
%   本函式因此在兩個判準**不一致**時主動發出警告——
%   那代表「哪個方法比較好」這個問題還沒有答案，需要人來決定
%   要優先保住哪一項。
%
%   為什麼 regionfill 也要納入比較
%   ------------------------------
%   它是三者中最簡單的（解拉普拉斯方程做平滑內插），常被當成
%   「不夠好的舊方法」而跳過。但它在 PSNR 上贏了兩個專門的演算法，
%   而且是很好的**下限基準**：一個複雜方法若連 regionfill 都贏不了，
%   那它在這個任務上就沒有價值。
%
%   範例：
%     I = imread("peppers.png");
%     m = false(size(I,1), size(I,2)); m(120:209, 200:289) = true;
%
%     [rep, det] = ch13_inpaintCompare(I, m);
%     disp(rep)
%     disp(det.Note)
%
%   另見 CH13_HOLEMETRICS, CH13_GRADENERGY, INPAINTEXEMPLAR,
%   INPAINTCOHERENT, REGIONFILL.

arguments
    I    {mustBeNumeric, mustBeNonempty}
    mask {mustBeA(mask, ["logical" "numeric"])}
    options.PatchSize (1,2) double {mustBePositive, mustBeInteger} = [9 9]
    options.FillOrder (1,1) string ...
        {mustBeMember(options.FillOrder, ["gradient" "tensor"])} = "gradient"
    options.Smoothing (1,1) double {mustBePositive} = 2
    options.Radius    (1,1) double {mustBePositive, mustBeInteger} = 5
end

if ~islogical(mask), mask = logical(mask); end
if ~any(mask(:))
    error("ch13_inpaintCompare:emptyMask", "遮罩是空的，沒有東西要修復。");
end

holeFraction = nnz(mask) / numel(mask);
if holeFraction > 0.5
    warning("ch13_inpaintCompare:hugeHole", ...
        "遮罩占了影像的 %.1f%%。修復演算法靠的是**洞外**的資訊，" + ...
        "洞太大時三個方法都會失敗，比較結果沒有意義。", 100*holeFraction);
end

% --- 執行三種方法 ------------------------------------------------------
names = ["inpaintExemplar"; "inpaintCoherent"; "regionfill"];
results = cell(3,1);
times   = zeros(3,1);

t = tic;
results{1} = inpaintExemplar(I, mask, ...
    PatchSize=options.PatchSize, FillOrder=options.FillOrder);
times(1) = toc(t);

t = tic;
results{2} = inpaintCoherent(I, mask, ...
    SmoothingFactor=options.Smoothing, Radius=options.Radius);
times(2) = toc(t);

t = tic;
J = I;
for c = 1:size(I,3)
    J(:,:,c) = regionfill(I(:,:,c), mask);
end
results{3} = J;
times(3) = toc(t);

% --- 兩類指標 ---------------------------------------------------------
refEnergy = ch13_gradEnergy(I, mask);
refStd    = localStd(I, mask);

psnrVals = zeros(3,1); ssimVals = zeros(3,1);
energy   = zeros(3,1); stdVals  = zeros(3,1);
for k = 1:3
    [psnrVals(k), ssimVals(k)] = ch13_holeMetrics(I, results{k}, mask);
    energy(k) = ch13_gradEnergy(results{k}, mask);
    stdVals(k) = localStd(results{k}, mask);
end

energyRatio = energy / refEnergy;
stdRatio    = stdVals / refStd;

report = table(names, psnrVals, ssimVals, times, ...
    VariableNames=["Method" "PSNR" "SSIM" "Seconds"]);

fullTable = table(names, psnrVals, ssimVals, energy, energyRatio, ...
    stdRatio, times, ...
    VariableNames=["Method" "PSNR" "SSIM" "GradientEnergy" ...
                   "EnergyRatio" "StdRatio" "Seconds"]);

% --- 兩個判準各自的優勝者 --------------------------------------------
[~, iPSNR] = max(psnrVals);
[~, iTex]  = min(abs(energyRatio - 1));     % 越接近 1 越好，不是越大越好
agree = (iPSNR == iTex);

if agree
    note = sprintf("兩個判準一致：%s 同時在 PSNR（%.3f dB）與紋理" + ...
        "（能量比 %.3f）上最好。", names(iPSNR), psnrVals(iPSNR), energyRatio(iTex));
else
    note = sprintf("**兩個判準不一致。** PSNR 選 %s（%.3f dB，但能量比 %.3f）；" + ...
        "紋理選 %s（能量比 %.3f，PSNR %.3f dB）。" + ...
        "請依用途決定：要像素精確就選前者，要外觀自然就選後者。", ...
        names(iPSNR), psnrVals(iPSNR), energyRatio(iPSNR), ...
        names(iTex), energyRatio(iTex), psnrVals(iTex));

    warning("ch13_inpaintCompare:criteriaDisagree", ...
        "PSNR 與紋理指標選出不同的方法（%s vs %s）。" + ...
        "PSNR 偏好模糊（第 12 章第 3 節），所以它常會選到" + ...
        "平滑但沒有紋理的結果。**不要只看 PSNR 就下結論。**", ...
        names(iPSNR), names(iTex));
end

% 額外檢查：有沒有方法的紋理嚴重偏離
tooSmooth = energyRatio < 0.5;
tooRough  = energyRatio > 1.5;
if any(tooSmooth)
    note = note + sprintf(" 注意 %s 的紋理只有原圖的 %.0f%%，" + ...
        "是平滑色斑。", join(names(tooSmooth), "、"), 100*min(energyRatio));
end
if any(tooRough)
    note = note + sprintf(" 注意 %s 的紋理超出 %.0f%%，" + ...
        "多出來的是補丁接縫產生的假梯度。", ...
        join(names(tooRough), "、"), 100*(max(energyRatio)-1));
end

detail = struct( ...
    "Table",           fullTable, ...
    "ReferenceEnergy", refEnergy, ...
    "ReferenceStd",    refStd, ...
    "BestByPSNR",      names(iPSNR), ...
    "BestByTexture",   names(iTex), ...
    "Agree",           agree, ...
    "HoleFraction",    holeFraction, ...
    "Note",            string(note));
end

% ========================================================================
function s = localStd(I, mask)
%LOCALSTD 洞內的平均局部標準差（7x7 鄰域），第二個紋理指標。
%
%   與梯度能量互相佐證。兩個指標都指向同一個結論時，
%   對「紋理夠不夠」的判斷才比較可靠。
G = im2double(I);
if size(G,3) > 1, G = im2gray(G); end
L = stdfilt(G, true(7));
s = mean(L(mask));
end
