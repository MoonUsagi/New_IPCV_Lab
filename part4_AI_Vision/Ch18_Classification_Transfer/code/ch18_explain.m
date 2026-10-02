function [maps, info] = ch18_explain(net, I, classIdx, options)
%CH18_EXPLAIN 用三種方法解釋一個分類決定，並比較它們。
%
%   [MAPS, INFO] = CH18_EXPLAIN(NET, I, CLASSIDX) 對影像 I 與目標類別
%   CLASSIDX 產生三張解釋圖：Grad-CAM、遮擋敏感度、LIME。
%
%   MAPS 是 struct，含 GradCAM／Occlusion／LIME 三個欄位（都是 H-by-W）。
%
%   名稱-值引數：
%     DoLIME    - 是否計算 LIME（預設 true）。它最慢。
%     NumFeatures - LIME 的超像素數（預設 32）
%     Verbose   - 印出每種方法的耗時（預設 true）
%
%   **三種方法問的不是同一個問題**，這是本函式要強調的重點：
%
%   | 方法 | 怎麼算 | 問的問題 |
%   |---|---|---|
%   | Grad-CAM | 梯度加權的特徵圖 | 網路**內部**哪些空間位置對這個決定貢獻大 |
%   | 遮擋敏感度 | 逐塊遮住再看分數變化 | 遮住哪裡會讓分數**掉最多** |
%   | LIME | 超像素擾動 + 擬合線性代理模型 | 哪些**區域**能線性解釋這個決定 |
%
%   Grad-CAM 是**白箱**（要拿到梯度與中間層），
%   另兩個是**黑箱**（只需要能呼叫模型）。
%   所以遮擋與 LIME 可以用在你拿不到內部的模型上，代價是慢很多。
%
%   **它們常常不一致，而不一致本身就是資訊。**
%   Grad-CAM 的**有效**解析度受限於最後一層卷積的空間尺寸
%   （`resnet18` 是 7x7），所以它的圖必然是**粗糙的一團**。
%   注意 `gradCAM` 回傳的矩陣已經被放大到輸入尺寸（224x224），
%   **但那是插值出來的，不是真的細節**——
%   看到 224x224 的圖很容易誤以為它有那個精度。
%   遮擋與 LIME 的解析度取決於你設的區塊／超像素大小，
%   所以它們可以比 Grad-CAM 細，代價是慢。
%
%   實測（`resnet18`、`peppers.png`、預測 "bell pepper"）：
%
%     Grad-CAM      4.94 秒
%     遮擋敏感度    3.14 秒
%     LIME         12.55 秒（24 個超像素）
%
%   **LIME 比 Grad-CAM 慢 2.5 倍，而且它的成本隨超像素數線性成長。**
%   要細一點的解釋就要更多次前向傳播。
%
%   > **看到三張圖指向同一個區域，才算是比較可靠的證據。
%   > 只跑一種方法就下結論，是在信任一個你沒驗證過的工具。**
%
%   另見 GRADCAM, OCCLUSIONSENSITIVITY, IMAGELIME.

arguments
    net
    I {mustBeNumeric, mustBeNonempty}
    classIdx (1,1) double {mustBePositive, mustBeInteger}
    options.DoLIME      (1,1) logical = true
    options.NumFeatures (1,1) double {mustBePositive, mustBeInteger} = 32
    options.Verbose     (1,1) logical = true
end

inputSize = net.Layers(1).InputSize;
X = imresize(I, inputSize(1:2));
if size(X,3) == 1 && inputSize(3) == 3
    X = repmat(X, 1, 1, 3);
end
X = single(X);

maps = struct();
secs = struct();

% --- Grad-CAM ---------------------------------------------------------
t = tic;
maps.GradCAM = gradCAM(net, X, classIdx);
secs.GradCAM = toc(t);

% --- 遮擋敏感度 -------------------------------------------------------
t = tic;
maps.Occlusion = occlusionSensitivity(net, X, classIdx);
secs.Occlusion = toc(t);

% --- LIME -------------------------------------------------------------
if options.DoLIME
    t = tic;
    maps.LIME = imageLIME(net, X, classIdx, ...
        NumFeatures=options.NumFeatures);
    secs.LIME = toc(t);
else
    maps.LIME = [];
    secs.LIME = NaN;
end

info = struct("Seconds", secs, "InputSize", inputSize, ...
    "ClassIndex", classIdx);

if options.Verbose
    % gradCAM 回傳的圖已經被放大到輸入尺寸，**但它的有效解析度
     % 仍然是最後卷積層的空間尺寸**（resnet18 是 7x7）。
     % 看到 224x224 不代表它真的有 224x224 的細節。
    fprintf("Grad-CAM   %6.2f 秒（白箱，輸出 %dx%d，" + ...
        "但有效解析度只有最後卷積層的 7x7）\n", ...
        secs.GradCAM, size(maps.GradCAM,1), size(maps.GradCAM,2));
    fprintf("遮擋敏感度 %6.2f 秒（黑箱）\n", secs.Occlusion);
    if options.DoLIME
        fprintf("LIME       %6.2f 秒（黑箱，%d 個超像素）\n", ...
            secs.LIME, options.NumFeatures);
        slowest = max([secs.GradCAM secs.Occlusion secs.LIME]);
        fprintf("**最慢的比 Grad-CAM 慢 %.0f 倍**——黑箱方法的代價。\n", ...
            slowest / secs.GradCAM);
    end
end
end
