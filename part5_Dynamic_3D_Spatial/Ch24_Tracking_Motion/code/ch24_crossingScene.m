function scene = ch24_crossingScene(options)
%CH24_CROSSINGSCENE 產生兩個物體交會的合成場景，附精確的身分真值。
%
%   SCENE = CH24_CROSSINGSCENE() 回傳一個 struct：
%     Frames      1xN cell，RGB 影格
%     Truth       N x 2 x 2 陣列，Truth(k,:,i) 是第 i 個物體在第 k 幀的 [x y]
%     NumObjects  物體數（固定 2）
%     NumFrames   幀數
%     CrossFrame  兩者距離最近的那一幀
%     MinDistance 最近距離（像素）
%     Colors      1x2 string，兩個物體的顏色
%     Identical   兩個物體外觀是否相同
%
%   **為什麼要用合成資料？** 因為 ID 切換只有在**知道真值**時才量得出來。
%   真實影片沒有逐幀的身分標註，你只能看圖說「這裡好像換 ID 了」。
%   合成場景讓 ID 切換變成一個可以計數的數字。
%
%   **合成資料的限制要記住**：這裡的物體是理想的圓、等速直線、
%   沒有形變、沒有雜訊以外的干擾。真實場景的失敗會更多也更難看。
%   本章用它回答「**什麼條件下位置資訊不夠**」，不是用它宣稱效能。
%
%   名稱-值引數：
%     NumFrames   幀數，預設 40
%     ImageSize   [高 寬]，預設 [240 320]
%     Radius      物體半徑，預設 10
%     Identical   兩個物體是否同色，預設 true
%     MissDistance 兩條軌跡的垂直間距（像素），預設 30。
%                 **這是本章的難度旋鈕。** 兩個物體反向而行，
%                 在畫面中央擦身而過，最近時相距 MissDistance。
%                 小於 2*Radius 時兩者會併成一個區塊，
%                 偵測端只會回報一個質心——**關聯那一步就沒東西可配**。
%     Scenario    "cross"（預設）或 "meet"：
%                 - **"cross"**：兩者反向而行，**穿過去繼續走**。
%                   速度方向相反，Kalman 的預測足以分辨誰是誰。
%                 - **"meet"**：兩者相向而來，**停在一起** PauseFrames 幀，
%                   然後**各自原路折返**。
%                   等速模型會預測他們繼續前進——**方向完全猜反**。
%                   這是 ReID 真正要解決的情境。
%     PauseFrames  "meet" 情境下停在一起的幀數，預設 6
%     NoiseLevel  高斯雜訊標準差（0–255），預設 5
%     Seed        亂數種子，預設 0
%
%   範例：
%     scene = ch24_crossingScene(MissDistance=12);
%     fprintf("最近距離 %.1f px（第 %d 幀）\n", scene.MinDistance, scene.CrossFrame);
%
%   另見 CH24_MULTITRACKER, CH24_TRACKMETRICS.

arguments
    options.NumFrames  (1,1) double {mustBePositive} = 40
    options.ImageSize  (1,2) double = [240 320]
    options.Radius     (1,1) double {mustBePositive} = 10
    options.Identical  (1,1) logical = true
    options.MissDistance (1,1) double {mustBeNonnegative} = 30
    options.Scenario    (1,1) string {mustBeMember(options.Scenario, ["cross" "meet"])} = "cross"
    options.PauseFrames (1,1) double {mustBeNonnegative} = 6
    options.NoiseLevel (1,1) double {mustBeNonnegative} = 5
    options.Seed       (1,1) double = 0
end

rng(options.Seed);

H = options.ImageSize(1);
W = options.ImageSize(2);
N = options.NumFrames;

% 兩個物體**反向而行**，水平通過畫面中央，垂直錯開 MissDistance。
% 這是多物件追蹤最經典的困難情境：接近 → 重疊 → 分開。
% 分開之後，光看位置無法確定兩者是**交錯而過**還是**碰撞彈回**。
cx   = W / 2;
cy   = H / 2;
span = W * 0.40;                       % 各自走的半程距離
off  = options.MissDistance / 2;

truth = zeros(N, 2, 2);
if options.Scenario == "cross"
    % 穿越：等速直線，**速度方向相反且全程不變**。
    t = linspace(-1, 1, N)';
    truth(:,1,1) = cx + span * t;      % 物體 1：由左往右
    truth(:,1,2) = cx - span * t;      % 物體 2：由右往左
else
    % 相遇：接近 → 停留 PauseFrames 幀 → **各自原路折返**。
    % 折返那一刻，等速模型的預測方向剛好是錯的。
    P = min(options.PauseFrames, N-2);
    nMove = N - P;
    nIn   = ceil(nMove/2);
    nOut  = nMove - nIn;
    ramp  = [linspace(-1, 0, nIn)'; zeros(P,1); linspace(0, -1, nOut)'];
    truth(:,1,1) = cx + span * ramp;   % 物體 1：左 → 中 → 左
    truth(:,1,2) = cx - span * ramp;   % 物體 2：右 → 中 → 右
end
truth(:,2,1) = cy - off;
truth(:,2,2) = cy + off;

if options.Identical
    colors = ["green" "green"];
    rgbVal = {[60 200 60], [60 200 60]};
else
    colors = ["green" "magenta"];
    rgbVal = {[60 200 60], [200 60 200]};
end

[XX, YY] = meshgrid(1:W, 1:H);
frames = cell(1, N);
for k = 1:N
    img = uint8(zeros(H, W, 3)) + uint8(35);       % 深灰背景
    for i = 1:2
        d = (XX - truth(k,1,i)).^2 + (YY - truth(k,2,i)).^2;
        m = d <= options.Radius^2;
        for c = 1:3
            ch = img(:,:,c);
            ch(m) = rgbVal{i}(c);
            img(:,:,c) = ch;
        end
    end
    if options.NoiseLevel > 0
        img = uint8(double(img) + randn(H,W,3) * options.NoiseLevel);
    end
    frames{k} = img;
end

dist = vecnorm(squeeze(truth(:,:,1)) - squeeze(truth(:,:,2)), 2, 2);
[minDist, crossFrame] = min(dist);

scene = struct( ...
    Frames      = {frames}, ...
    Truth       = truth, ...
    NumObjects  = 2, ...
    NumFrames   = N, ...
    CrossFrame  = crossFrame, ...
    MinDistance = minDist, ...
    Colors      = colors, ...
    Identical   = options.Identical, ...
    Radius       = options.Radius, ...
    MissDistance = options.MissDistance, ...
    Scenario     = options.Scenario, ...
    Merged       = minDist < 2*options.Radius);
end
