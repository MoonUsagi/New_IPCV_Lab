function report = ch30_onnxRoundTrip(options)
%CH30_ONNXROUNDTRIP 把網路匯出成 ONNX 再匯入，比較兩者的輸出。
%
%   REPORT = CH30_ONNXROUNDTRIP() 用 squeezenet（imagePretrainedNetwork）
%   做一次 exportONNXNetwork → importNetworkFromONNX，對 8 張內建影像
%   比較兩個網路的輸出，回傳 struct：
%     FileMB          ONNX 檔大小
%     ExportSeconds / ImportSeconds
%     OriginalDims / ImportedDims    輸出的 dlarray 維度標籤
%     OriginalSize / ImportedSize    輸出的大小
%     MaxAbsDiff      **對齊維度之後**的最大絕對差
%     Top1Agreement   top-1 類別一致的張數
%     OriginalNormalization / ImportedNormalization  輸入層的正規化
%     InputSize       網路的輸入大小
%     CustomLayerFiles 匯入時自動產生的自訂層檔案（部署時要一起帶走）
%     ImportedNetwork 匯入的 dlnetwork（下游示範用，不必再匯入一次）
%
%   ## 本機實測的兩件事
%   **① 輸入層的正規化「消失」了，但結果完全一樣。**
%   原網路的輸入層是 `zerocenter`（減掉平均值 104–123），匯入後是 `none`。
%   我原本懷疑正規化被丟掉了——**但輸出最大差是 0**，top-1 8/8 一致。
%   正規化被轉成了網路裡的一個減法運算，不是遺失。
%   > **看設定的欄位不夠，要比輸出。**
%
%   **② 輸出的維度標籤從 `CB` 變成 `UU`，而且轉置了**（[1000 8] → [8 1000]）。
%   下游寫 `max(y, [], 1)` 取類別，在匯入的網路上會**安靜地在錯的軸上取最大值**——
%   得到 1000 個「批次索引」而不是 8 個類別。**不報錯。**
%   本函式偵測到大小不一致時會轉置再比，並把兩邊的維度標籤都回報出來。
%
%   名稱-值引數：
%     NetworkName  預設 "squeezenet"
%     FileName     ONNX 輸出路徑，預設 tempdir 下
%
%   另見 EXPORTONNXNETWORK, IMPORTNETWORKFROMONNX, DLARRAY, DIMS.

arguments
    options.NetworkName (1,1) string = "squeezenet"
    options.FileName    (1,1) string = fullfile(tempdir, "ch30_net.onnx")
end

net = imagePretrainedNetwork(options.NetworkName);
if isfile(options.FileName)
    delete(options.FileName);
end

t0 = tic;
exportONNXNetwork(net, options.FileName);
exportSeconds = toc(t0);

% importNetworkFromONNX 會在**當前資料夾**產生自訂層的套件（+ch30_net），
% 匯入的網路執行時需要它在路徑上。放在專用資料夾並加入路徑。
% 第一版只在 tempdir 裡匯入、離開後就找不到套件，predict 失敗在
% 「Method 'predict' is not defined for class 'ch30_net.Transpose_To_ReshapeLayer1000'」——
% **匯入的網路不是一個自足的物件，它的自訂層要跟著一起部署。**
importDir = fullfile(tempdir, "ch30_onnx_import");
if ~isfolder(importDir), mkdir(importDir); end
here = pwd;
back = onCleanup(@() cd(here));
cd(importDir);
t0 = tic;
imported = importNetworkFromONNX(options.FileName);
importSeconds = toc(t0);
addpath(importDir);
pkgs = dir(fullfile(importDir, "+*"));
customLayers = strings(0,1);
for k = 1:numel(pkgs)
    f = dir(fullfile(pkgs(k).folder, pkgs(k).name, "*.m"));
    customLayers = [customLayers; string({f.name}).']; %#ok<AGROW>
end

inputSize = net.Layers(1).InputSize;
names = ["peppers.png" "football.jpg" "coins.png" "cameraman.tif" ...
         "onion.png" "saturn.png" "pears.png" "kobi.png"];
X = zeros([inputSize(1:2) 3 numel(names)], "single");
for k = 1:numel(names)
    I = imread(names(k));
    if size(I,3) == 1, I = repmat(I, 1, 1, 3); end
    X(:,:,:,k) = single(imresize(I, inputSize(1:2)));
end
dX = dlarray(X, "SSCB");

out1 = predict(net, dX);
out2 = predict(imported, dX);
y1 = extractdata(out1);
y2 = extractdata(out2);
transposed = false;
if ~isequal(size(y1), size(y2)) && isequal(size(y1), size(y2'))
    y2 = y2';
    transposed = true;
end
[~, c1] = max(y1, [], 1);
[~, c2] = max(y2, [], 1);

report = struct( ...
    NetworkName           = options.NetworkName, ...
    FileMB                = dir(options.FileName).bytes / 1e6, ...
    ExportSeconds         = exportSeconds, ...
    ImportSeconds         = importSeconds, ...
    OriginalDims          = string(dims(out1)), ...
    ImportedDims          = string(dims(out2)), ...
    OriginalSize          = size(extractdata(out1)), ...
    ImportedSize          = size(extractdata(out2)), ...
    NeededTranspose       = transposed, ...
    MaxAbsDiff            = max(abs(y1(:) - y2(:))), ...
    Top1Agreement         = nnz(c1 == c2), ...
    NumImages             = numel(names), ...
    OriginalNormalization = string(net.Layers(1).Normalization), ...
    ImportedNormalization = string(imported.Layers(1).Normalization), ...
    InputSize             = inputSize, ...
    CustomLayerFiles      = customLayers, ...
    ImportedNetwork       = imported);
end
