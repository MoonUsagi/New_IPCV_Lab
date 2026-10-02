function config = ch29_loadConfig(fileName)
%CH29_LOADCONFIG 讀 JSON 設定檔，**依照欄位規格**修正型別並驗證。
%
%   CONFIG = CH29_LOADCONFIG(FILENAME) 讀取由 CH29_SAVECONFIG 寫出的
%   （或人手編輯的）JSON，回傳一個保證能直接傳給 ch29_countGrains 的 struct。
%
%   ## 為什麼要有「欄位規格」
%   JSON 沒有型別資訊：`[1,2,3]` 讀回來不知道原本是列還是行，
%   `null` 不知道原本是 NaN 還是「沒有值」。**只有程式知道每個欄位應該是什麼。**
%   所以這裡明確列出每個欄位的型別、大小與預設值：
%   | 欄位 | 型別 | 預設 |
%   |---|---|---|
%   | BackgroundRadius | 正整數 | 15 |
%   | MinArea | 非負數 | 50 |
%   | Threshold | 0–1 或 NaN | NaN |
%   | InputFolder | string | "" |
%   | FilePattern | string | "*.png" |
%
%   ## 三種錯誤，三種處理
%   | 狀況 | 處理 |
%   |---|---|
%   | 欄位缺漏 | 用預設值，**並回報** |
%   | 多了不認得的欄位 | **報錯**（多半是拼錯字：`MinAera`） |
%   | 型別或範圍錯 | **報錯**，指出是哪個欄位 |
%
%   第二種最重要：拼錯的欄位如果被安靜地忽略，
%   **使用者以為改了參數，其實用的是預設值。**
%
%   另見 CH29_SAVECONFIG, JSONDECODE.

arguments
    fileName (1,1) string
end

if ~isfile(fileName)
    error("ipcv:ch29:noConfig", "找不到設定檔 %s。", fileName);
end
raw = jsondecode(fileread(fileName));
if ~isstruct(raw) || ~isscalar(raw)
    error("ipcv:ch29:badConfig", "設定檔的最外層必須是一個 JSON 物件。");
end

spec = localSpec();
known = string(fieldnames(spec));
given = string(fieldnames(raw));

unknown = setdiff(given, known);
if ~isempty(unknown)
    % 找最像的已知欄位，幫使用者猜他想打什麼
    hints = strings(size(unknown));
    for i = 1:numel(unknown)
        d = arrayfun(@(k) localEditDistance(lower(unknown(i)), lower(k)), known);
        [~, j] = min(d);
        hints(i) = unknown(i) + "（是不是 " + known(j) + "？）";
    end
    error("ipcv:ch29:unknownField", "設定檔有不認得的欄位：%s", strjoin(hints, "、"));
end

config = struct();
missingFields = strings(0,1);
for k = 1:numel(known)
    name = known(k);
    s = spec.(name);
    if isfield(raw, name)
        v = raw.(name);
    else
        v = s.Default;
        missingFields(end+1) = name; %#ok<AGROW>
    end
    config.(name) = localCoerce(name, v, s);
end

if ~isempty(missingFields)
    fprintf("ch29_loadConfig：%s 未指定，使用預設值。\n", strjoin(missingFields, "、"));
end
end

% ========================================================================
function spec = localSpec()
spec.BackgroundRadius = struct(Kind="posint",   Default=15);
spec.MinArea          = struct(Kind="nonneg",   Default=50);
spec.Threshold        = struct(Kind="unitOrNaN",Default=NaN);
spec.InputFolder      = struct(Kind="string",   Default="");
spec.FilePattern      = struct(Kind="string",   Default="*.png");
end

% ------------------------------------------------------------------------
function v = localCoerce(name, v, s)
% 字串形式的特殊值（ch29_saveConfig 寫的）
if (ischar(v) || isstring(v)) && ismember(string(v), ["NaN" "Inf" "-Inf"])
    v = str2double(string(v));
end
% null 讀回來是 []：對可以是 NaN 的欄位，把它當成 NaN
if isempty(v) && isnumeric(v) && s.Kind == "unitOrNaN"
    v = NaN;
end

switch s.Kind
    case "posint"
        ok = isnumeric(v) && isscalar(v) && v > 0 && v == round(v);
    case "nonneg"
        ok = isnumeric(v) && isscalar(v) && v >= 0;
    case "unitOrNaN"
        ok = isnumeric(v) && isscalar(v) && (isnan(v) || (v >= 0 && v <= 1));
    case "string"
        ok = ischar(v) || (isstring(v) && isscalar(v));
        if ok, v = string(v); end
    otherwise
        ok = false;
end
if ~ok
    error("ipcv:ch29:badField", "設定檔欄位 %s 的值不合法（要的是 %s）。", ...
        name, s.Kind);
end
if isnumeric(v)
    v = double(v);
end
end

% ------------------------------------------------------------------------
function d = localEditDistance(a, b)
%LOCALEDITDISTANCE Levenshtein 距離（用來猜拼錯的欄位名）。
a = char(a); b = char(b);
m = numel(a); n = numel(b);
D = zeros(m+1, n+1);
D(:,1) = 0:m;
D(1,:) = 0:n;
for i = 1:m
    for j = 1:n
        D(i+1,j+1) = min([D(i,j+1)+1, D(i+1,j)+1, D(i,j) + (a(i) ~= b(j))]);
    end
end
d = D(end,end);
end
