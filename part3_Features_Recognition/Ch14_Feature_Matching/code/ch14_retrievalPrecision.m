function [precTbl, info] = ch14_retrievalPrecision(options)
%CH14_RETRIEVALPRECISION 建立小型影像檢索資料庫並評估精確度。
%
%   [PRECTBL, INFO] = CH14_RETRIEVALPRECISION() 用 MATLAB 內建影像建立
%   一個「每個來源 × 多個變體」的資料庫，逐一查詢並計算精確度。
%
%   名稱-值引數：
%     Sources     來源影像清單，預設四張內建影像
%     NumResults  每次查詢取前幾名，預設 3
%     ImageSize   統一縮放尺寸，預設 [256 256]
%
%   **評估檢索時最容易犯的錯**
%   --------------------------
%   查詢影像若本身就在資料庫裡，**第 1 名必然是它自己**。
%   那一分是免費的，完全不反映檢索能力。
%
%   第 14 章第 13 節實測（4 個來源 × 3 變體 = 12 張，取前 3 名）：
%
%     判準              精確度
%     含查詢影像自己    100.0%（36/36）
%     **排除自己**      100.0%（24/24）
%
%   這次兩個數字相同，所以結論不變——但那是因為題目太簡單
%   （只有 4 個來源，而且視覺差異極大：辣椒／人像／電路板／布料）。
%   在有數千個類別、樣本彼此相似的真實任務上，
%   這兩個數字會差很多。
%
%   > **一定要排除查詢自身，或用資料庫外的影像當查詢。**
%   > 這與第 12 章「留出獨立測試集」是同一個原則：
%   > **拿訓練資料評估，量到的是記憶不是泛化。**
%
%   本函式因此**同時**回報兩個數字，並在它們差距明顯時提醒。
%
%   資料庫怎麼建
%   ------------
%   每個來源產生三個變體：原圖、旋轉 10°、縮小到 0.6 再放大回來
%   （模擬解析度損失）。這讓「同來源」有明確的定義，
%   精確度才有客觀的正確答案。
%
%   範例：
%     [tbl, info] = ch14_retrievalPrecision();
%     disp(tbl); disp(info.Note)
%
%   另見 INDEXIMAGES, RETRIEVEIMAGES, BAGOFFEATURES, EVALUATEIMAGERETRIEVAL.

arguments
    options.Sources    (1,:) string = ["peppers.png" "cameraman.tif" ...
                                       "circuit.tif" "fabric.png"]
    options.NumResults (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ImageSize  (1,2) double {mustBePositive} = [256 256]
end

tmp = fullfile(tempdir, "ipcv_ch14_retrieval");
if isfolder(tmp), rmdir(tmp, "s"); end
mkdir(tmp);

% --- 建資料庫：每個來源三個變體 -------------------------------------
labels = strings(0);
n = 0;
for si = 1:numel(options.Sources)
    try
        A = imread(options.Sources(si));
    catch
        continue                    % 這個 MATLAB 版本沒有這張內建影像
    end
    if size(A,3) == 1, A = repmat(A, 1, 1, 3); end
    A = imresize(A, options.ImageSize);

    for v = 1:3
        switch v
            case 1, B = A;
            case 2, B = imrotate(A, 10, "bilinear", "crop");
            case 3, B = imresize(imresize(A, 0.6), options.ImageSize);
        end
        n = n + 1;
        imwrite(B, fullfile(tmp, sprintf("img_%03d.png", n)));
        labels(n) = options.Sources(si);
    end
end

if n < 4
    error("ch14_retrievalPrecision:tooFewImages", ...
        "只建立了 %d 張影像，不足以評估檢索。" + ...
        "請檢查 Sources 中的影像是否存在於此 MATLAB 版本。", n);
end

ds = imageDatastore(tmp);

% indexImages 會印出很長的建構訊息，這裡壓下來
warnState = warning("off", "all");
cleanupObj = onCleanup(@() warning(warnState));
evalc("imgIdx = indexImages(ds);");

% --- 逐一查詢 ---------------------------------------------------------
K = options.NumResults;
hitsWithSelf = 0; totalWithSelf = 0;
hitsNoSelf   = 0; totalNoSelf   = 0;

perQueryWith = zeros(n,1);
perQueryNo   = zeros(n,1);

for qi = 1:n
    Q = imread(fullfile(tmp, sprintf("img_%03d.png", qi)));

    % 多取一名，因為排除自己之後還要湊滿 K 個
    [ids, ~] = retrieveImages(Q, imgIdx, NumResults=K+1);
    ids = ids(:)';

    % --- 含自己 ---
    topWith = ids(1:min(K, numel(ids)));
    hw = nnz(labels(topWith) == labels(qi));
    hitsWithSelf = hitsWithSelf + hw;
    totalWithSelf = totalWithSelf + numel(topWith);
    perQueryWith(qi) = hw / max(1, numel(topWith));

    % --- 排除自己 ---
    % retrieveImages 回傳的是 datastore 的索引；自己的索引就是 qi
    idsNoSelf = ids(ids ~= qi);
    topNo = idsNoSelf(1:min(K-1, numel(idsNoSelf)));
    if isempty(topNo), continue, end
    hn = nnz(labels(topNo) == labels(qi));
    hitsNoSelf = hitsNoSelf + hn;
    totalNoSelf = totalNoSelf + numel(topNo);
    perQueryNo(qi) = hn / numel(topNo);
end

precWith = 100 * hitsWithSelf / max(1, totalWithSelf);
precNo   = 100 * hitsNoSelf   / max(1, totalNoSelf);

precTbl = table( ...
    ["含查詢影像自己"; "排除查詢影像自己"], ...
    [hitsWithSelf; hitsNoSelf], ...
    [totalWithSelf; totalNoSelf], ...
    [precWith; precNo], ...
    VariableNames=["Criterion" "Hits" "Total" "PrecisionPct"]);

% --- 結論與提醒 -------------------------------------------------------
gap = precWith - precNo;
note = sprintf("資料庫 %d 張（%d 個來源 x 3 變體）。" + ...
    "含自己 %.1f%%、排除自己 %.1f%%，差距 %.1f 個百分點。", ...
    n, numel(unique(labels)), precWith, precNo, gap);

if gap > 5
    note = note + " **差距明顯——「含自己」那個數字高估了檢索能力。**";
    warning("ch14_retrievalPrecision:selfMatchInflation", ...
        "含查詢自身的精確度（%.1f%%）比排除自身（%.1f%%）高 %.1f 個百分點。" + ...
        "查詢影像就在資料庫裡，第 1 名必然是它自己——那一分是免費的。" + ...
        "**請用排除自身的數字。**", precWith, precNo, gap);
else
    note = note + " 兩者接近，但**這是因為本例的來源差異極大**" + ...
        "（只有 4 類且視覺上完全不同）。真實檢索任務會有數千個類別，" + ...
        "屆時兩個數字會差很多——評估時仍應排除查詢自身。";
end

info = struct( ...
    "NumImages",       n, ...
    "NumSources",      numel(unique(labels)), ...
    "Labels",          labels, ...
    "PrecisionWith",   precWith, ...
    "PrecisionNoSelf", precNo, ...
    "PerQueryNoSelf",  perQueryNo, ...
    "DatabaseFolder",  string(tmp), ...
    "Note",            string(note));
end
