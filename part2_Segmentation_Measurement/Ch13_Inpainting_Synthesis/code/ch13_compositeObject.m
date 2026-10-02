function [report, info] = ch13_compositeObject(fg, bg, mask, options)
%CH13_COMPOSITEOBJECT 比較 imblend 的各種混合模式，量化接縫與內部保真。
%
%   REPORT = CH13_COMPOSITEOBJECT(FG, BG, MASK) 對每個混合模式各做一次，
%   回傳含接縫梯度與內部保真 PSNR 的 table（依接縫由小到大排序）。
%
%   [REPORT, INFO] = CH13_COMPOSITEOBJECT(___) 另外回傳 struct：
%     BackgroundBaseline  純背景在接縫帶的梯度（理想下限）
%     HardPasteSeam       完全不混合時的接縫梯度（上限）
%     BestSeam            接縫最小的模式
%     BestFidelity        內部保真最高的模式
%     Recommendation      依用途的建議
%     Note                人類可讀的結論
%
%   名稱-值引數：
%     Modes       要比較的模式，預設全部八種
%     SeamWidth   接縫帶寬度，預設 3
%     ErodeWidth  保真度計算時遮罩內縮量，預設 8
%
%   為什麼要同時量兩件事
%   --------------------
%   混合有兩個互相衝突的目標：
%     1. **接縫不明顯**——邊界的梯度要接近純背景的水準
%     2. **物件不變形**——遮罩內部要還是原來那個物件
%
%   第 13 章第 6.1、7 節實測（peppers 貼到 saturn，接縫帶 2900 像素）：
%
%     Mode                  接縫梯度   內部保真PSNR
%     Poisson                0.15218      19.542
%     PoissonMixGradients    0.16570      13.296
%     Overlay                0.26816      14.515
%     Average                0.28586      17.183
%     Max                    0.28966      12.869
%     Min                    0.32180      16.089
%     Guided                 0.33765         Inf
%     Alpha (預設)            0.36967      21.630
%     (硬貼)                  0.50274         Inf
%     (純背景基準線)           0.10522          --
%
%   **兩欄說的是相反的故事。** Poisson 的接縫最好（把 0.503 降到 0.152，
%   接近純背景的 0.105），但內部保真只有 19.5 dB——物件被染色了。
%   Guided 的保真度是 Inf（像素完全相同），接縫卻是 0.338。
%
%   原因在演算法：**Poisson 混合只保留前景的梯度，不保留絕對值。**
%   邊界值取自背景，所以物件顏色會被背景拉走。
%
%   注意 Average 的接縫（0.28586）與 Alpha 在 ForegroundOpacity=0.5 時
%   **完全相同**——Average 就是 50% 的 alpha 混合。
%
%   選擇建議
%   --------
%     給人看的合成圖              -> Poisson（接縫最不明顯）
%     訓練資料（要保留物件外觀）   -> Guided 或高 opacity 的 Alpha
%     需要一個連續旋鈕            -> Alpha + ForegroundOpacity
%
%   **用 Poisson 產生訓練資料是個真實的風險**：物件顏色會隨背景改變，
%   而真實場景裡不會。模型會學到不存在的相關性。
%
%   範例：
%     [rep, info] = ch13_compositeObject(fg, bg, mask);
%     disp(rep)
%     disp(info.Recommendation)
%
%   另見 IMBLEND, CH13_SEAMANDFIDELITY, INSERTOBJECTINIMAGE.

arguments
    fg   {mustBeNumeric, mustBeNonempty}
    bg   {mustBeNumeric, mustBeNonempty}
    mask {mustBeA(mask, ["logical" "numeric"])}
    options.Modes (1,:) string = ["Alpha" "Guided" "Poisson" ...
        "PoissonMixGradients" "Max" "Min" "Average" "Overlay"]
    options.SeamWidth  (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ErodeWidth (1,1) double {mustBePositive, mustBeInteger} = 8
end

if ~islogical(mask), mask = logical(mask); end
if ~isequal(size(fg, [1 2]), size(bg, [1 2]))
    error("ch13_compositeObject:sizeMismatch", ...
        "前景 %s 與背景 %s 的尺寸不同。請先 imresize。", ...
        mat2str(size(fg,[1 2])), mat2str(size(bg,[1 2])));
end

n = numel(options.Modes);
modeNames = strings(n,1);
seamVals  = zeros(n,1);
fidVals   = zeros(n,1);
timeVals  = zeros(n,1);
ok        = true(n,1);

for k = 1:n
    m = options.Modes(k);
    modeNames(k) = m;
    try
        t = tic;
        B = imblend(fg, bg, mask, Mode=m);
        timeVals(k) = toc(t);
        [seamVals(k), fidVals(k)] = ch13_seamAndFidelity(B, fg, bg, mask, ...
            SeamWidth=options.SeamWidth, ErodeWidth=options.ErodeWidth);
    catch ME
        ok(k) = false;
        warning("ch13_compositeObject:modeFailed", ...
            "Mode=""%s"" 失敗：%s", m, ME.message);
    end
end

modeNames = modeNames(ok);
seamVals  = seamVals(ok);
fidVals   = fidVals(ok);
timeVals  = timeVals(ok);

report = table(modeNames, seamVals, fidVals, timeVals, ...
    VariableNames=["Mode" "SeamGradient" "InteriorPSNR" "Seconds"]);
report = sortrows(report, "SeamGradient");

% --- 兩個參考值 -------------------------------------------------------
seamBand = imdilate(bwperim(mask), strel("disk", options.SeamWidth));

Gb = im2double(bg);
if size(Gb,3) > 1, Gb = im2gray(Gb); end
GbMag = imgradient(Gb);
bgBaseline = mean(GbMag(seamBand));

hard = bg;
for c = 1:size(bg,3)
    ch = hard(:,:,c);
    fc = fg(:,:,c);
    ch(mask) = fc(mask);
    hard(:,:,c) = ch;
end
Gh = im2double(hard);
if size(Gh,3) > 1, Gh = im2gray(Gh); end
GhMag = imgradient(Gh);
hardSeam = mean(GhMag(seamBand));

% --- 優勝者與建議 -----------------------------------------------------
[~, iSeam] = min(report.SeamGradient);
[~, iFid]  = max(report.InteriorPSNR);

bestSeam = report.Mode(iSeam);
bestFid  = report.Mode(iFid);

note = sprintf("接縫最小：%s（%.5f，純背景基準 %.5f、硬貼 %.5f）。" + ...
    "內部保真最高：%s（%.3f dB）。", ...
    bestSeam, report.SeamGradient(iSeam), bgBaseline, hardSeam, ...
    bestFid, report.InteriorPSNR(iFid));

if bestSeam ~= bestFid
    note = note + " **兩者不是同一個模式——這是必然的取捨，不是可以兩全的。**";
end

recommendation = "給人看的合成圖 -> " + bestSeam + "（接縫最不明顯）；" + ...
    "產生訓練資料 -> " + bestFid + "（物件外觀不被改變）。";

% 若使用者選的是 Poisson 系列，提醒訓練資料的風險
if any(contains(report.Mode, "Poisson"))
    pIdx = find(contains(report.Mode, "Poisson"), 1);
    if isfinite(report.InteriorPSNR(pIdx))
        recommendation = recommendation + sprintf( ...
            " 注意 %s 的內部保真只有 %.1f dB：它只保留梯度不保留絕對值，" + ...
            "物件顏色會被背景拉走。用它產生訓練資料會讓模型學到" + ...
            "真實場景不存在的相關性。", ...
            report.Mode(pIdx), report.InteriorPSNR(pIdx));
    end
end

info = struct( ...
    "BackgroundBaseline", bgBaseline, ...
    "HardPasteSeam",      hardSeam, ...
    "BestSeam",           bestSeam, ...
    "BestFidelity",       bestFid, ...
    "SeamBandPixels",     nnz(seamBand), ...
    "Recommendation",     string(recommendation), ...
    "Note",               string(note));
end
