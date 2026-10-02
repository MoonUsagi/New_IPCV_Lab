function [results, agree] = ch08_evaluateSegmentation(candidates, groundTruth, options)
%CH08_EVALUATESEGMENTATION 用多個指標比較分割結果，並提醒排名不一致。
%
%   RESULTS = CH08_EVALUATESEGMENTATION(CANDIDATES, GROUNDTRUTH) 對每個候選
%   遮罩計算 Dice、Jaccard 與 BF score，回傳一張依 Dice 排序的 table。
%
%   CANDIDATES 是 N×2 的 cell 陣列：第一欄是方法名稱，第二欄是二值遮罩。
%
%   [RESULTS, AGREE] = CH08_EVALUATESEGMENTATION(___) 另外回傳一個邏輯值，
%   表示三個指標是否給出**相同的最佳方法**。若不一致，函式會發出警告。
%
%   名稱-值引數：
%     NormalizeForeground  是否自動把前景調整為少數派，預設 true。
%                          分割函式對「哪一類是前景」沒有共識，比較前要統一
%     Verbose              是否列印結果表，預設 true
%
%   為什麼要主動提醒排名不一致
%   --------------------------
%   Dice／Jaccard 量的是**區域重疊**，BF score 量的是**邊界貼合**。
%   兩者可以給出相反的排名——第 08 章對 hands1.jpg 的實測：
%
%     HSV 膚色門檻   Dice 0.9441（最高）  BFscore 0.7383（最低）
%     ISODATA 灰階   Dice 0.9050          BFscore 0.7716（最高）
%
%   若使用者只看 Dice 就選了 HSV，而下游任務其實是量周長或當訓練標註，
%   那就選錯了。這支函式的價值不在算指標（三行就能算完），
%   **而在於它會主動指出「這裡有個需要你決定的取捨」**。
%
%   怎麼選指標
%   ----------
%     計數、量面積          → Dice / Jaccard
%     量周長、輪廓比對、標註 → BF score
%     論文或交付報告        → 兩個都報
%
%   範例：
%     gt = logical(imread("hands1-mask.png"));
%     I  = imread("hands1.jpg");
%     G  = im2gray(I);
%     hsv = rgb2hsv(I);
%
%     candidates = { ...
%         "Otsu",     imbinarize(G); ...
%         "ISODATA",  imsegisodata(G) > 1; ...
%         "HSV 膚色", hsv(:,:,1) < 0.10 & hsv(:,:,2) > 0.20};
%
%     [r, agree] = ch08_evaluateSegmentation(candidates, gt);
%     if ~agree
%         disp("指標排名不一致，請依下游任務選擇。")
%     end
%
%   另見 DICE, JACCARD, BFSCORE.

arguments
    candidates  cell
    groundTruth {mustBeA(groundTruth, ["logical" "numeric"])}
    options.NormalizeForeground (1,1) logical = true
    options.Verbose             (1,1) logical = true
end

if size(candidates, 2) ~= 2
    error("ch08_evaluateSegmentation:badShape", ...
        "CANDIDATES 必須是 N×2 的 cell 陣列（名稱, 遮罩），但收到 %d 欄。", ...
        size(candidates, 2));
end

gt = logical(groundTruth);
n  = size(candidates, 1);

Method     = strings(n,1);
DiceScore  = zeros(n,1);
Jaccard    = zeros(n,1);
BFScore    = zeros(n,1);
Foreground = zeros(n,1);
Flipped    = false(n,1);

for k = 1:n
    bw = logical(candidates{k,2});

    if ~isequal(size(bw), size(gt))
        error("ch08_evaluateSegmentation:sizeMismatch", ...
            "第 %d 個候選（%s）的尺寸 %s 與標準答案 %s 不符。", ...
            k, string(candidates{k,1}), mat2str(size(bw)), mat2str(size(gt)));
    end

    % 分割函式對「哪一類是前景」沒有共識，比較之前要統一
    if options.NormalizeForeground && mean(bw, "all") > 0.5
        bw = ~bw;
        Flipped(k) = true;
    end

    Method(k)     = string(candidates{k,1});
    DiceScore(k)  = dice(bw, gt);
    Jaccard(k)    = jaccard(bw, gt);
    BFScore(k)    = bfscore(bw, gt);
    Foreground(k) = mean(bw, "all");
end

% 三個指標各自的排名（1 = 最好）
[~, orderDice] = sort(DiceScore, "descend");
[~, orderJacc] = sort(Jaccard,   "descend");
[~, orderBF]   = sort(BFScore,   "descend");

RankDice = zeros(n,1);  RankDice(orderDice) = 1:n;
RankJacc = zeros(n,1);  RankJacc(orderJacc) = 1:n;
RankBF   = zeros(n,1);  RankBF(orderBF)     = 1:n;

results = table(Method, DiceScore, Jaccard, BFScore, Foreground, ...
    RankDice, RankJacc, RankBF, Flipped);
results = sortrows(results, "DiceScore", "descend");

% Dice 與 Jaccard 是單調相關的，所以只需比較 Dice 與 BFScore
agree = orderDice(1) == orderBF(1);

if options.Verbose
    fprintf("\n%-20s %8s %8s %9s %8s %6s %6s\n", ...
        "方法", "Dice", "Jaccard", "BFscore", "前景%", "D排名", "B排名");
    for k = 1:height(results)
        fprintf("%-20s %8.4f %8.4f %9.4f %7.1f%% %6d %6d\n", ...
            results.Method(k), results.DiceScore(k), results.Jaccard(k), ...
            results.BFScore(k), 100*results.Foreground(k), ...
            results.RankDice(k), results.RankBF(k));
    end

    if any(results.Flipped)
        fprintf("\n註：%d 個候選的前景／背景被自動翻轉以便比較。\n", sum(results.Flipped));
    end
end

if ~agree
    best = results.Method(1);
    bestBF = results.Method(results.RankBF == 1);
    msg = sprintf("指標排名不一致：Dice 最佳是「%s」，但 BFscore 最佳是「%s」。" + ...
        "Dice 量區域重疊、BFscore 量邊界貼合——請依下游任務選擇" + ...
        "（計數／面積看 Dice，周長／輪廓／標註看 BFscore）。", best, bestBF);
    warning("ch08_evaluateSegmentation:rankingDisagreement", "%s", msg);
elseif options.Verbose
    fprintf("\n三個指標一致認為「%s」最佳。\n", results.Method(1));
end
end
