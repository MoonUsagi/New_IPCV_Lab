function report = ch26_registerCompare(options)
%CH26_REGISTERCOMPARE 在**已知變換**上比較三種點雲配準法的收斂範圍。
%
%   REPORT = CH26_REGISTERCOMPARE() 把一朵點雲旋轉一個已知角度，
%   再用各種方法配準回去，回傳 table：
%     Method        方法
%     TrueAngleDeg  真實旋轉角
%     ResidualDeg   **配準之後還剩多少旋轉誤差**
%     TransResidual 平移殘差
%     RMSE          方法自己回報的 RMSE
%     Seconds       耗時
%     Converged     ResidualDeg < 0.5 度
%
%   ## 為什麼要用已知變換
%   **配準沒有真值可看。** 兩朵點雲疊在一起「看起來很準」，
%   可能只是你從那個角度看不出差異。
%   把一朵點雲自己轉一個已知角度再配回去，**誤差就是可量的**。
%
%   ## 實測到的結論
%   `pcregistericp` 在 teapot 上的收斂範圍**只到約 2 度**：
%   | 真實旋轉 | ICP 殘差 | RMSE |
%   |---|---|---|
%   | 1.2° | **0.000°** | 0.00000 |
%   | 2.5° | 2.171° | 0.03164 |
%   | 6.2° | 3.868° | 0.04706 |
%   | 49.3° | **39.666°** | 0.31946 |
%
%   **超過 2 度就卡在局部極小值。** 給一個正確的初始猜測時，
%   同一個 20 度的變換可以配到 **0.0000 度**。
%
%   > **ICP 不是「找到最佳對齊」，是「從你給的起點往下滾」。**
%   > 初始猜測通常來自別的地方：IMU、里程計、粗略的特徵比對、
%   > 或上一幀的結果。**沒有初始猜測的 ICP 只能處理很小的位移。**
%
%   ## 回報的 RMSE 是可用的診斷
%   上表的 RMSE 隨殘差單調上升（0.000 → 0.047 → 0.319），
%   所以**即使沒有真值，RMSE 也能告訴你配準失敗了**。
%   但注意它的單位是點雲的單位，**沒有絕對的合格門檻**。
%
%   名稱-值引數：
%     Angles        要測試的旋轉角（度），預設 [1 2 5 10 20 40]
%     GridSize      降採樣的網格大小，預設 0.05
%     Methods       預設 ["icp" "ndt" "cpd"]
%     WithInitial   是否額外測「給初始猜測」的情況，預設 true
%
%   > **`pcregistercpd` 預設是非剛體配準，回傳的是位移場（`single` 陣列），
%   > 不是變換物件。** 直接寫 `tform.R` 會報
%   > 「Dot indexing is not supported for variables of type single」。
%   > 要剛體變換必須明確寫 `Transform="Rigid"`。
%
%   另見 PCREGISTERICP, PCREGISTERNDT, PCREGISTERCPD, PCTRANSFORM.

arguments
    options.Angles      (1,:) double = [1 2 5 10 20 40]
    options.GridSize    (1,1) double {mustBePositive} = 0.05
    options.Methods     (1,:) string = ["icp" "ndt" "cpd"]
    options.WithInitial (1,1) logical = true
end

% R2026b 起範例點雲隨點雲功能搬到 toolbox/shared/visionpointcloud/pcdata，
% 用 which 找，兩個版本都能用
fixed = pcdownsample(pcread(which("teapot.ply")), "gridAverage", options.GridSize);

Method        = strings(0,1);
TrueAngleDeg  = zeros(0,1);
ResidualDeg   = zeros(0,1);
TransResidual = zeros(0,1);
RMSE          = zeros(0,1);
Seconds       = zeros(0,1);
UsedInitial   = false(0,1);

for ang = options.Angles
    trueTform = rigidtform3d( ...
        eul2rotm(deg2rad([ang ang*0.6 ang*0.4])), ...
        [0.02 -0.01 0.01] * ang / 5);
    moving = pctransform(fixed, trueTform);

    for m = options.Methods
        [tf, rmse, secs, ok] = localRegister(m, moving, fixed, []);
        if ~ok, continue; end
        localAdd(m, ang, trueTform, tf, rmse, secs, false);
    end

    % ---- 給一個正確的初始猜測
    if options.WithInitial
        initial = rigidtform3d(trueTform.R', -(trueTform.R' * trueTform.Translation')');
        [tf, rmse, secs, ok] = localRegister("icp", moving, fixed, initial);
        if ok
            localAdd("icp", ang, trueTform, tf, rmse, secs, true);
        end
    end
end

report = table(Method, TrueAngleDeg, ResidualDeg, TransResidual, RMSE, ...
    Seconds, UsedInitial);
report.Converged = report.ResidualDeg < 0.5;

    function localAdd(name, ang, trueTform, tf, rmse, secs, usedInit)
        % **殘差的算法**：配準結果乘上真實變換應該是單位矩陣。
        % 寫成 tf.R * trueTform.R'（轉置）會算出兩倍的角度——
        % 那是我第一次犯的錯，得到「6 度的變換有 8 度的殘差」。
        residual = rad2deg(norm(rotm2eul(tf.R * trueTform.R)));
        transRes = norm(tf.Translation + (tf.R * trueTform.Translation')');

        Method(end+1,1)        = name;      %#ok<AGROW>
        TrueAngleDeg(end+1,1)  = rad2deg(norm(rotm2eul(trueTform.R))); %#ok<AGROW>
        ResidualDeg(end+1,1)   = residual;  %#ok<AGROW>
        TransResidual(end+1,1) = transRes;  %#ok<AGROW>
        RMSE(end+1,1)          = rmse;      %#ok<AGROW>
        Seconds(end+1,1)       = secs;      %#ok<AGROW>
        UsedInitial(end+1,1)   = usedInit;  %#ok<AGROW>
    end
end

% ========================================================================
function [tf, rmse, secs, ok] = localRegister(method, moving, fixed, initial)
tf = []; rmse = NaN; ok = false;
t0 = tic;
try
    switch lower(method)
        case "icp"
            if isempty(initial)
                [tf, ~, rmse] = pcregistericp(moving, fixed);
            else
                [tf, ~, rmse] = pcregistericp(moving, fixed, InitialTransform=initial);
            end
        case "ndt"
            [tf, ~, rmse] = pcregisterndt(moving, fixed, 0.1);
        case "cpd"
            % **一定要寫 Transform="Rigid"**，否則預設是非剛體，
            % 回傳的是位移場而不是 rigidtform3d。
            small = pcdownsample(moving, "random", 0.1);
            ref   = pcdownsample(fixed,  "random", 0.1);
            [tf, ~, rmse] = pcregistercpd(small, ref, Transform="Rigid");
    end
    ok = isa(tf, "rigidtform3d");
catch
    ok = false;
end
secs = toc(t0);
end
