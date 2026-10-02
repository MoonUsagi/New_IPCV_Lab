function metrics = ch24_trackMetrics(result, truth, options)
%CH24_TRACKMETRICS 用真值評估追蹤結果：ID 切換、片段化、覆蓋率。
%
%   METRICS = CH24_TRACKMETRICS(RESULT, TRUTH) 比對 CH24_MULTITRACKER
%   的輸出和真值，回傳 struct：
%     IDSwitches    **ID 切換次數**——同一個真實物體換了追蹤編號的次數
%     Fragments     片段數——每個真實物體被切成幾段
%     Coverage      覆蓋率——有多少比例的（幀, 物體）被指派到某條軌跡
%     MeanError     指派正確時的平均位置誤差（像素）
%     NumTracks     總共產生幾條軌跡
%     PerObject     每個真實物體一列的細節 table
%
%   TRUTH 是 N x 2 x M 陣列（幀 × [x y] × 物體），來自 CH24_CROSSINGSCENE。
%
%   ## 為什麼要看 ID 切換，而不是只看位置誤差
%
%   追蹤有兩種完全不同的失敗：
%   | 失敗 | 位置誤差 | ID 切換 |
%   |---|---|---|
%   | 位置估歪了 | **大** | 0 |
%   | 兩個物體交會後互換身分 | **≈ 0** | **2** |
%
%   **第二種在位置誤差上完全看不出來**——每一條軌跡都貼在某個真實物體上，
%   只是貼錯了人。如果你的下游要算「這個人在店裡待了多久」「這台車從哪來」，
%   ID 切換是致命的，位置誤差反而無所謂。
%
%   > 這和第 20 章「一個指標不夠」、第 22 章「分數看不出異常圖指錯地方」
%   > 是同一件事：**指標要對應你真正在意的失敗。**
%
%   名稱-值引數：
%     MaxDistance  真值與軌跡配對的最大距離，預設 25 像素。
%                  超過這個距離就算「沒追到」，不算配對。
%
%   範例：
%     scene = ch24_crossingScene();
%     r = ch24_multiTracker(scene.Frames);
%     m = ch24_trackMetrics(r, scene.Truth);
%     fprintf("ID 切換 %d 次\n", m.IDSwitches);
%
%   另見 CH24_MULTITRACKER, CH24_CROSSINGSCENE.

arguments
    result                  table
    truth                   double
    options.MaxDistance (1,1) double {mustBePositive} = 25
end

nFrames  = size(truth, 1);
nObjects = size(truth, 3);

% 每一幀、每一個真實物體，找最近的軌跡（在 MaxDistance 以內）。
assignedId = nan(nFrames, nObjects);
assignedErr = nan(nFrames, nObjects);

for k = 1:nFrames
    rows = result(result.Frame == k, :);
    if isempty(rows)
        continue
    end
    trackXY = [rows.X rows.Y];
    used    = false(height(rows), 1);

    % 貪婪指派：每次挑全域最小的配對。物體少時和匈牙利法結果一樣，
    % 而且這裡只是評估，不是追蹤本身。
    pairCost = nan(nObjects, height(rows));
    for i = 1:nObjects
        pairCost(i,:) = vecnorm(trackXY - squeeze(truth(k,:,i)), 2, 2)';
    end
    for pick = 1:min(nObjects, height(rows))
        [mn, lin] = min(pairCost(:));
        if isnan(mn) || mn > options.MaxDistance
            break
        end
        [oi, ti] = ind2sub(size(pairCost), lin);
        assignedId(k, oi)  = rows.TrackID(ti);
        assignedErr(k, oi) = mn;
        pairCost(oi,:) = NaN;
        pairCost(:,ti) = NaN;
        used(ti) = true;
    end
end

% ---- ID 切換：同一個真實物體的指派編號改變的次數
idSwitches = 0;
fragments  = zeros(nObjects, 1);
perSwitch  = zeros(nObjects, 1);
coverage   = zeros(nObjects, 1);

for i = 1:nObjects
    ids = assignedId(:, i);
    seen = ids(~isnan(ids));
    coverage(i) = numel(seen) / nFrames;
    if isempty(seen)
        fragments(i) = 0;
        continue
    end
    changes = sum(diff(seen) ~= 0);
    perSwitch(i) = changes;
    idSwitches   = idSwitches + changes;
    fragments(i) = changes + 1;
end

PerObject = table((1:nObjects)', coverage, perSwitch, fragments, ...
    mean(assignedErr, 1, "omitnan")', ...
    VariableNames = ["物體" "覆蓋率" "ID切換" "片段數" "平均誤差"]);

metrics = struct( ...
    IDSwitches = idSwitches, ...
    Fragments  = sum(fragments), ...
    Coverage   = mean(coverage), ...
    MeanError  = mean(assignedErr(:), "omitnan"), ...
    NumTracks  = numel(unique(result.TrackID)), ...
    PerObject  = PerObject);
end
