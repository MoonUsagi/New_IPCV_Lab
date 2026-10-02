function ch29_saveConfig(config, fileName)
%CH29_SAVECONFIG 把設定存成 JSON，並**事先處理 jsonencode 會弄壞的東西**。
%
%   CH29_SAVECONFIG(CONFIG, FILENAME) 把 struct 寫成排版過的 JSON。
%
%   ## jsonencode + jsondecode 不是無損的
%   主教材 §4 實測，直接來回轉換會發生：
%   | 原本 | 讀回來 |
%   |---|---|
%   | 列向量 `[1 2 3]` | **行向量 3×1** |
%   | `NaN`、`Inf` | **`null` → `[]`** |
%   | string 陣列 `["a" "b"]` | **cell 2×1** |
%   | `single(0.1)` | double 0.1（**值也變了**） |
%   | `int32(7)` | double 7 |
%
%   其中 **NaN → []** 最危險：`ch29_countGrains` 用 NaN 表示「自動門檻」，
%   存檔再讀回來變成 `[]`，傳進去會報「必須是 1×1」——
%   **一個在記憶體裡完全正常的設定，存檔之後就不能用了。**
%
%   本函式的做法：把 NaN／Inf 存成字串 `"NaN"`／`"Inf"`／`"-Inf"`，
%   `ch29_loadConfig` 讀回來時再轉回數值。向量方向與型別由
%   `ch29_loadConfig` 依照已知的欄位規格修正。
%
%   另見 CH29_LOADCONFIG, JSONENCODE.

arguments
    config   (1,1) struct
    fileName (1,1) string
end

fields = fieldnames(config);
out = config;
for k = 1:numel(fields)
    v = config.(fields{k});
    if isnumeric(v) && isscalar(v) && ~isfinite(v)
        if isnan(v)
            out.(fields{k}) = "NaN";
        elseif v > 0
            out.(fields{k}) = "Inf";
        else
            out.(fields{k}) = "-Inf";
        end
    end
end

txt = jsonencode(out, PrettyPrint=true);
fid = fopen(fileName, "w", "n", "UTF-8");
if fid < 0
    error("ipcv:ch29:cannotWrite", "無法寫入設定檔 %s。", fileName);
end
closer = onCleanup(@() fclose(fid));
fwrite(fid, txt, "char");
end
