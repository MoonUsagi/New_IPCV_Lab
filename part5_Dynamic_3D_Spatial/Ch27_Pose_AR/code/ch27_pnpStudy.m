function report = ch27_pnpStudy(options)
%CH27_PNPSTUDY 在**已知姿態**上量 PnP 的雜訊敏感度與點數需求。
%
%   REPORT = CH27_PNPSTUDY() 用一個合成的立方體：先用已知的相機姿態
%   把八個角投影成影像點，加雜訊，再用 `estworldpose` 求回姿態，
%   和真值比。回傳 table：
%     NumPoints    使用的點數
%     NoiseSigma   加在影像點上的高斯雜訊（像素）
%     RotErrorDeg  旋轉誤差（度）
%     TransErrorMm 平移誤差（公釐）
%     SuccessRate  成功求解的比例
%
%   ## 為什麼要合成
%   **姿態估計沒有真值可比。** 真實的 AprilTag 影像裡，
%   你不知道標記實際在哪。合成的話真值就是你自己設的，
%   **誤差因此是可量的**——這和第 24 章的合成交會場景、
%   第 26 章的已知變換配準是同一個手法。
%
%   ## 實測到的兩件事
%   **① 誤差大致線性於雜訊**（8 個點）：
%   | 雜訊 σ | 旋轉誤差 | 平移誤差 |
%   |---|---|---|
%   | 0 px | 0.0011° | 0.01 mm |
%   | 1 px | 0.298° | 1.91 mm |
%   | 5 px | 1.347° | 9.70 mm |
%   | 10 px | 3.657° | 19.30 mm |
%
%   **② 從 4 個點加到 6 個，誤差減半；再加就沒用了**（σ=1 px）：
%   | 點數 | 旋轉誤差 | 成功率 |
%   |---|---|---|
%   | 4 | 1.010° ± 0.462 | **27/30** |
%   | 5 | 0.539° ± 0.259 | 30/30 |
%   | **6** | **0.354° ± 0.171** | 30/30 |
%   | 8 | 0.419° ± 0.130 | 30/30 |
%
%   **四個點是 PnP 的理論下限，而它同時是最不準也最容易失敗的。**
%   AprilTag 只給你四個角——所以標記的姿態精度有一個內建的天花板。
%
%   ## 一個很容易搞錯的座標框
%   **`estworldpose` 回傳的是「相機在世界座標中的姿態」，
%   而 `world2img` 吃的是「世界到相機的變換」——兩者互為反轉。**
%   直接拿 `est.R` 和你設定的外參比，會得到一個
%   **穩定但完全錯誤**的殘差（本機量到 37.17 度，而且不隨雜訊改變）。
%   正確的做法是 `invert(est)`，或者比較 `est.R * R_true` 是否為單位矩陣。
%
%   > **「殘差很大但幾乎不隨雜訊變動」是座標框搞錯的典型指紋。**
%   > 真正的數值問題會隨雜訊放大；框架問題是個常數偏移。
%
%   名稱-值引數：
%     NoiseSigmas  要測試的雜訊，預設 [0 0.5 1 2 5 10]
%     PointCounts  要測試的點數，預設 [4 5 6 8]
%     NumRepeats   每個設定重複幾次，預設 30
%     TrueEuler    真實姿態的歐拉角（度），預設 [10 -15 5]
%     TrueTrans    真實平移（公尺），預設 [0.1 -0.05 0.8]
%     Seed         亂數種子，預設 0
%
%   另見 ESTWORLDPOSE, WORLD2IMG, INVERT, RIGIDTFORM3D.

arguments
    options.NoiseSigmas (1,:) double = [0 0.5 1 2 5 10]
    options.PointCounts (1,:) double = [4 5 6 8]
    options.NumRepeats  (1,1) double {mustBePositive} = 30
    options.TrueEuler   (1,3) double = [10 -15 5]
    options.TrueTrans   (1,3) double = [0.1 -0.05 0.8]
    options.Seed        (1,1) double = 0
end

rng(options.Seed);

S = load(fullfile(toolboxdir("vision"), "visiondata", "camIntrinsicsAprilTag.mat"));
intrinsics = S.intrinsics;

Rtrue = eul2rotm(deg2rad(options.TrueEuler));
ttrue = options.TrueTrans;
extrinsicsTrue = rigidtform3d(Rtrue, ttrue);       % 世界 -> 相機

% 一個 10 公分的立方體，八個角
s = 0.1;
worldPoints = [0 0 0; s 0 0; s s 0; 0 s 0; 0 0 s; s 0 s; s s s; 0 s s];
imagePoints = world2img(worldPoints, extrinsicsTrue, intrinsics);

NumPoints    = zeros(0,1);
NoiseSigma   = zeros(0,1);
RotErrorDeg  = zeros(0,1);
TransErrorMm = zeros(0,1);
SuccessRate  = zeros(0,1);

for np = options.PointCounts
    for sigma = options.NoiseSigmas
        rotErrors   = [];
        transErrors = [];
        for r = 1:options.NumRepeats
            noisy = imagePoints(1:np,:) + randn(np,2)*sigma;
            try
                % MaxReprojectionError 要跟著雜訊放大，否則
                % RANSAC 會把所有點都判成離群點而失敗。
                est = estworldpose(noisy, worldPoints(1:np,:), intrinsics, ...
                    MaxReprojectionError = max(2, sigma*3));
                % **關鍵：轉回「世界 -> 相機」再比。**
                back = invert(est);
                rotErrors(end+1)   = rad2deg(norm(rotm2eul(back.R * Rtrue'))); %#ok<AGROW>
                transErrors(end+1) = norm(back.Translation - ttrue) * 1000;    %#ok<AGROW>
            catch
                % 求解失敗（點太少、雜訊太大、或退化組態）
            end
        end
        NumPoints(end+1,1)   = np;                                       %#ok<AGROW>
        NoiseSigma(end+1,1)  = sigma;                                    %#ok<AGROW>
        SuccessRate(end+1,1) = numel(rotErrors) / options.NumRepeats;    %#ok<AGROW>
        if isempty(rotErrors)
            RotErrorDeg(end+1,1)  = NaN;                                 %#ok<AGROW>
            TransErrorMm(end+1,1) = NaN;                                 %#ok<AGROW>
        else
            RotErrorDeg(end+1,1)  = mean(rotErrors);                     %#ok<AGROW>
            TransErrorMm(end+1,1) = mean(transErrors);                   %#ok<AGROW>
        end
    end
end

report = table(NumPoints, NoiseSigma, RotErrorDeg, TransErrorMm, SuccessRate);
end
