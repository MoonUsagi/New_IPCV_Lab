function modelTbl = ch16_cascadeModels(I, options)
%CH16_CASCADEMODELS 比較內建的 Viola-Jones cascade 模型。
%
%   MODELTBL = CH16_CASCADEMODELS(I) 對每個內建模型各跑一次，
%   回傳偵測數與耗時。
%
%   名稱-值引數：
%     Models  要測的模型清單，預設十個內建模型
%
%   實測（visionteam.jpg，人工數 6 張正面人臉）
%   -------------------------------------------
%     模型                偵測數    秒數
%     FrontalFaceCART        6     0.087
%     **FrontalFaceLBP**     6     **0.016**
%     UpperBody             14     0.117
%     EyePairBig             0     0.023
%     EyePairSmall           4     0.027
%     LeftEye                6     0.043
%     RightEye               4     0.038
%     Nose                   1     0.064
%     Mouth                 15     0.038
%     ProfileFace            4     0.045
%
%   **兩個結論：**
%
%   **① FrontalFaceLBP 與 FrontalFaceCART 結果相同，但快 5 倍。**
%   LBP（Local Binary Pattern）特徵只需要比大小；
%   CART 要算 Haar 特徵的加權和。
%   **預設是 CART，但多數情況 LBP 就夠了。**
%
%   **② 部位偵測器（眼、鼻、嘴）單獨使用都很不可靠。**
%   Mouth 找到 15 個、Nose 只找到 1 個、EyePairBig 找到 0 個。
%   它們的設計用途是**在已找到的人臉範圍內**再定位部位，
%   要搭配 UseROI 使用：
%
%     faceDet = vision.CascadeObjectDetector("FrontalFaceLBP");
%     eyeDet  = vision.CascadeObjectDetector("EyePairBig", UseROI=true);
%     faces = faceDet(I);
%     eyes  = eyeDet(I, faces(1,:));      % 只在第一張臉裡找眼睛
%
%   另見 VISION.CASCADEOBJECTDETECTOR, CH16_CASCADEPARAMETERS.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.Models (1,:) string = ["FrontalFaceCART" "FrontalFaceLBP" ...
        "UpperBody" "EyePairBig" "EyePairSmall" "LeftEye" "RightEye" ...
        "Nose" "Mouth" "ProfileFace"]
end

n = numel(options.Models);
counts = nan(n,1);
times  = nan(n,1);
notes  = strings(n,1);

for k = 1:n
    m = options.Models(k);
    try
        d = vision.CascadeObjectDetector(char(m));
        % 先跑一次暖機，再計時。第一次呼叫包含模型載入成本——
        % 第 10、14 章都踩過「量到載入時間」的坑。
        d(I);
        t = tic;
        bb = d(I);
        times(k)  = toc(t);
        counts(k) = size(bb,1);
    catch ME
        notes(k) = string(ME.message);
    end
end

modelTbl = table(counts, times, notes, ...
    VariableNames=["NumDetections" "Seconds" "Note"], ...
    RowNames=options.Models);
end
