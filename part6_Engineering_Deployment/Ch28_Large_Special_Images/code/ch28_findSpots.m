function [centroids, report] = ch28_findSpots(bim, options)
%CH28_FINDSPOTS 在一張分塊的大影像上找亮斑，處理「跨越塊邊界」的目標。
%
%   [CENTROIDS, REPORT] = CH28_FINDSPOTS(BIM) 對 blockedImage 的每一塊
%   做平滑 + 門檻 + regionprops，把每塊找到的質心換算回**整張影像的座標**，
%   合併後回傳 N×2 的 [x y]。
%
%   REPORT 含 NumRaw（合併前的偵測數）、NumKept、Seconds。
%
%   ## 分塊偵測的兩個陷阱
%   **① 目標跨越塊邊界會被切成兩半。** 沒有 BorderSize 時，
%   一個剛好壓在邊界上的亮斑在左右兩塊各被找到「半個」，
%   質心各偏向自己那一側——**一個目標變成兩個錯位的偵測**。
%
%   **② 加了 BorderSize 之後，同一個目標會被相鄰的塊各找到一次。**
%   因為每一塊都看得到鄰居的邊緣。邊界問題修好了，
%   **卻換來重複計數**。
%
%   正確的做法是 `KeepCoreOnly=true`：每塊只保留**質心落在自己核心區**
%   （`block.Start` 到 `block.End`，不含 border）的偵測。
%   這樣每個目標恰好屬於一塊。
%
%   > 這和第 24 章「一個物體被偵測成兩個區塊」、
%   > 第 26 章「逐一移除找平面」是同一類問題：
%   > **把問題切開的那條線，本身就會製造錯誤。**
%
%   名稱-值引數：
%     BorderSize    預設 0
%     KeepCoreOnly  預設 false
%     Threshold     平滑後的門檻，預設 170
%     Sigma         平滑的 σ，預設 8
%
%   另見 BLOCKEDIMAGE, APPLY, CH28_MAKELARGEIMAGE.

arguments
    bim
    options.BorderSize   (1,1) double {mustBeNonnegative} = 0
    options.KeepCoreOnly (1,1) logical = false
    options.Threshold    (1,1) double = 170
    options.Sigma        (1,1) double {mustBePositive} = 8
end

% **apply 的輸出不能是 cell**——只接受數值、logical、
% scalar struct 或 categorical。每塊偵測到的數量不固定，
% 所以這裡用固定大小的數值陣列（最多 MaxPerBlock 個，其餘補 NaN）。
maxPerBlock = 32;
fcn = @(b) localDetect(b, options, maxPerBlock);

t0 = tic;
out = gather(apply(bim, fcn, BorderSize=[options.BorderSize options.BorderSize]));
seconds = toc(t0);

% out 是把每塊的 maxPerBlock×2 結果**按塊的位置拼起來**的大陣列：
% 第 1、3、5…欄是各塊的 x，第 2、4、6…欄是各塊的 y。
% **直接 reshape(out, [], 2) 會把不同塊的 x 與 y 交錯弄錯**——
% 不會報錯，只會給出一堆落在奇怪位置的點。
xs = out(:, 1:2:end);
ys = out(:, 2:2:end);
raw = [xs(:) ys(:)];
raw = raw(all(isfinite(raw), 2), :);

centroids = raw;
report = struct( ...
    NumRaw       = size(raw,1), ...
    NumKept      = size(centroids,1), ...
    Seconds      = seconds, ...
    BorderSize   = options.BorderSize, ...
    KeepCoreOnly = options.KeepCoreOnly);
end

% ========================================================================
function result = localDetect(block, options, maxPerBlock)
data = double(block.Data);
g = imgaussfilt(data, options.Sigma);
stats = regionprops(g > options.Threshold, "Centroid");

result = nan(maxPerBlock, 2);
if isempty(stats)
    return
end
c = reshape([stats.Centroid], 2, [])';     % 區塊內座標 [x y]

% **設了 BorderSize 之後，block.Start／End 是「含邊界」的範圍。**
% 本機實測：100×100 的塊、BorderSize=10，第 [2 2] 塊的核心是 101–200，
% 但 Start=[91 91]、End=[210 210]，而 Data(1,1) 正好對應 Start。
% 所以換算成整張座標只要加 Start−1；**核心區要自己算成 Start+b 到 End−b**。
% 我第一版以為 Start 是核心的起點而多減了一次 b，
% 結果每個偵測都系統性地偏了 b·√2（64 → 91.8 像素）。
b = double(block.BorderSize);
start = double(block.Start);
stop  = double(block.End);
c(:,1) = c(:,1) + start(2) - 1;
c(:,2) = c(:,2) + start(1) - 1;

if options.KeepCoreOnly
    coreLo = start + b;
    coreHi = stop  - b;
    inCore = c(:,1) >= coreLo(2) - 0.5 & c(:,1) < coreHi(2) + 0.5 & ...
             c(:,2) >= coreLo(1) - 0.5 & c(:,2) < coreHi(1) + 0.5;
    c = c(inCore, :);
end

k = min(size(c,1), maxPerBlock);
result(1:k, :) = c(1:k, :);
end
