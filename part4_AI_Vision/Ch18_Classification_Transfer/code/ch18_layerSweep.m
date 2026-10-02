function tbl = ch18_layerSweep(net, dsTrain, dsTest, layers, options)
%CH18_LAYERSWEEP 掃描「從哪一層抽特徵」，量每一層的遷移品質。
%
%   TBL = CH18_LAYERSWEEP(NET, DSTRAIN, DSTEST, LAYERS) 對每一層做
%   一次完整的特徵抽取 + 分類器訓練 + 評估，回傳比較表。
%
%   名稱-值引數：
%     MiniBatchSize - 轉傳（預設 32）
%     Verbose       - 印出進度（預設 true）
%
%   **這個掃描回答一個沒辦法用直覺回答的問題。**
%
%   常見的說法是「淺層學通用特徵（邊緣、紋理），深層學任務特有的
%   語意特徵；所以領域差很遠的時候應該用**淺層**」。
%   這句話聽起來很有道理。**在這個資料集上它是錯的。**
%
%   實測（resnet18、DigitDataset 每類 40／20、全域平均池化）：
%
%     層              維度    準確率
%     res2b_relu        64    0.1900
%     res3b_relu       128    0.2950
%     res4b_relu       256    0.6000
%     res5b_relu       512    **0.9000**
%     pool5            512    **0.9000**
%
%   **單調上升，越深越好，而且差距巨大（19% -> 90%）。**
%
%   為什麼「用淺層」的直覺會錯？因為那個說法混淆了兩件事：
%     - 淺層特徵比較**通用**（這是對的）
%     - 淺層特徵比較**有用**（這不一定）
%
%   通用不等於有用。`res2b_relu` 的 64 個通道大致是
%   有向邊緣與顏色斑塊的響應，對「這是數字 3 還是 8」
%   幾乎沒有判別力——**手寫數字全部都是黑白的邊緣。**
%   深層特徵雖然是為 ImageNet 的語意調出來的，
%   但它們編碼了**形狀的組合方式**，而那正是區分數字需要的。
%
%   > **「領域差很遠就用淺層」這個建議要先量再用。**
%   > 它在某些任務上成立（例如紋理分類），在這裡不成立。
%
%   注意 `pool5` 與 `res5b_relu` 的結果**完全相同**——
%   因為 `pool5` 就是 `res5b_relu` 的全域平均池化，
%   而這個函式也對 `res5b_relu` 做了一樣的事。
%   **這是一個免費的自我檢查**：若兩者不同，就是池化寫錯了。
%
%   另見 CH18_TRANSFERSVM, CH18_BACKBONESWEEP.

arguments
    net
    dsTrain
    dsTest
    layers (1,:) string {mustBeNonempty}
    options.MiniBatchSize (1,1) double {mustBePositive, mustBeInteger} = 32
    options.Verbose       (1,1) logical = true
end

allNames = string({net.Layers.Name});
missing = setdiff(layers, allNames);
if ~isempty(missing)
    error("ch18_layerSweep:noSuchLayer", ...
        "這個網路沒有下列層：%s。" + ...
        "用 string({net.Layers.Name}) 看實際的層名。", ...
        strjoin(missing, ", "));
end

n = numel(layers);
layerCol = strings(n,1);
nFeat = zeros(n,1); acc = zeros(n,1); sec = zeros(n,1);

ws = warning("off", "ch18_transferSVM:weakClass");
for k = 1:n
    if options.Verbose
        fprintf("  層 %d/%d：%s ...\n", k, n, layers(k));
    end
    t = tic;
    [~, r] = ch18_transferSVM(net, dsTrain, dsTest, layers(k), ...
        MiniBatchSize=options.MiniBatchSize);
    layerCol(k) = layers(k);
    nFeat(k) = r.NumFeatures;
    acc(k) = r.Accuracy;
    sec(k) = toc(t);
end
warning(ws);

tbl = table(layerCol, nFeat, acc, sec, ...
    VariableNames=["層" "維度" "準確率" "秒數"]);

% 最佳層在不在掃描範圍的邊緣？（第 14／16 章的教訓）
[~, iBest] = max(acc);
if iBest == n
    fprintf("\n**最佳層是掃描範圍的最後一層（%s）。**\n", layers(iBest));
    fprintf("這裡剛好就是網路的最後一層，所以沒有「掃得不夠遠」的問題；\n");
    fprintf("但若你的掃描沒到網路末端，這個結果只代表要繼續往深處掃。\n");
end
end
