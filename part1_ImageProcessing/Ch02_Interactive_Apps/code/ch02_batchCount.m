function T = ch02_batchCount(ds, varargin)
%CH02_BATCHCOUNT 對整個影像資料集執行圓片計數，彙整成一張表。
%
%   T = CH02_BATCHCOUNT(DS) 對 imageDatastore DS 中的每一張影像執行
%   ch02_findChips，回傳每張影像一列的彙總 table：檔名、找到幾個、
%   平均面積、平均直徑、平均圓形度。
%
%   T = CH02_BATCHCOUNT(DS, ...) 接受所有 ch02_findChips 的名稱-值引數，
%   會原樣轉傳下去。
%
%   這是第 02 章「五步驟工作流」第 ④ 步：把單張影像的函式套用到整個資料夾。
%
%   設計重點：
%     · 用 imageDatastore 而非把影像全讀進 cell，資料集再大都不會爆記憶體
%     · 逐張處理失敗時記錄下來繼續跑，不讓一張壞圖中斷整批
%     · 先配置 cell 再一次 vertcat，避免在迴圈中反覆重新配置 table
%
%   關於參數轉傳：這裡用 varargin 把選項原樣交給 ch02_findChips，驗證由
%   它負責。`arguments` 區塊的 `options.?Name` 繼承語法只能繼承**類別**的
%   屬性，不能繼承另一支函式的引數，所以包裝函式要嘛用 varargin 轉傳、
%   要嘛把引數宣告抄一遍。抄一遍能得到輸入提示與早期驗證，但兩邊會不同步；
%   轉傳不會不同步，代價是錯誤訊息指向被呼叫的函式。這裡選擇轉傳。
%
%   範例：
%     ds = imageDatastore("影像資料夾");
%     T  = ch02_batchCount(ds);
%     disp(T)
%
%     % 換一種顏色，並放寬圓形度
%     T2 = ch02_batchCount(ds, HueRange=[0.10 0.18], MinCircularity=0.8);
%
%     % 找出計數異常的影像
%     odd = T(T.Count ~= mode(T.Count), :);
%
%   另見 CH02_FINDCHIPS, IMAGEDATASTORE.

if ~isa(ds, "matlab.io.datastore.ImageDatastore")
    error("ch02_batchCount:notDatastore", ...
        "第一個輸入必須是 imageDatastore，但收到 %s。", class(ds));
end

nv = varargin;    % 原樣轉傳給 ch02_findChips，由它負責驗證

reset(ds);
n    = numel(ds.Files);
rows = cell(n, 1);

for k = 1:n
    [I, info] = read(ds);
    [~, name] = fileparts(info.Filename);

    try
        s = ch02_findChips(I, nv{:});

        if isempty(s)
            rows{k} = summaryRow(name, 0, NaN, NaN, NaN, "無偵測結果");
        else
            rows{k} = summaryRow(name, height(s), ...
                mean(s.Area), mean(s.EquivDiameter), mean(s.Circularity), "成功");
        end
    catch ME
        rows{k} = summaryRow(name, NaN, NaN, NaN, NaN, string(ME.message));
    end
end

T = vertcat(rows{:});
end

% ========================================================================
function r = summaryRow(name, count, area, diameter, circularity, status)
r = table(string(name), count, area, diameter, circularity, string(status), ...
    VariableNames=["Name" "Count" "MeanArea" "MeanDiameter" "MeanCircularity" "Status"]);
end
