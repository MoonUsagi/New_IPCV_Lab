function manifest = downloadCourseData(options)
%DOWNLOADCOURSEDATA 取得課程所需的資料集。
%
%   DOWNLOADCOURSEDATA() 依各章 data/datalist.json 的宣告，下載尚未取得的
%   資料集到本機快取。已存在的項目會跳過，可安全重複執行。
%
%   DOWNLOADCOURSEDATA(Chapters=["17" "19"]) 只處理指定章節。
%
%   DOWNLOADCOURSEDATA(DryRun=true) 只列出將要下載什麼、共多少 MB，不實際下載。
%
%   MANIFEST = DOWNLOADCOURSEDATA(___) 回傳資料清單 table，欄位為
%   Chapter、Name、Source、SizeMB、Status、LocalPath。
%
%   名稱-值引數：
%     Chapters   章號字串陣列，預設 "all"
%     DryRun     只檢視不下載，預設 false
%     CacheDir   快取資料夾，預設 fullfile(userpath,"IPCV_Lab_data")
%     Verbose    是否列印訊息，預設 true
%
%   資料清單格式（各章 data/datalist.json）：
%     {
%       "chapter": "19",
%       "items": [
%         {"name":"coins.png", "source":"builtin",
%          "note":"MATLAB 內建影像，直接使用"},
%         {"name":"aoi_samples.zip", "source":"https://...",
%          "sizeMB":128, "sha256":"...", "license":"CC BY 4.0"}
%       ]
%     }
%
%   source 可為：
%     "builtin"        MATLAB 內建，不需下載
%     "matlab-example" 用 openExample 取得，不需下載
%     "local"          已隨教材附上，在該章 data 資料夾
%     http(s) 網址     需下載（zip 會自動解壓）
%
%   另見 CHECKENVIRONMENT, IPCVSETUP.

arguments
    options.Chapters (1,:) string  = "all"
    options.DryRun   (1,1) logical = false
    options.CacheDir (1,1) string  = fullfile(userpath, "IPCV_Lab_data")
    options.Verbose  (1,1) logical = true
end

root  = ipcvRoot();
lists = dir(fullfile(root, "part*", "Ch*", "data", "datalist.json"));

Chapter = strings(0,1); Name = strings(0,1); Source = strings(0,1);
SizeMB = zeros(0,1); Status = strings(0,1); LocalPath = strings(0,1);

for f = 1:numel(lists)
    jsonPath = fullfile(lists(f).folder, lists(f).name);
    try
        spec = jsondecode(fileread(jsonPath));
    catch ME
        warning("ipcv:badDatalist", "無法解析 %s：%s", jsonPath, ME.message);
        continue
    end

    ch = string(spec.chapter);
    if ~(isscalar(options.Chapters) && options.Chapters == "all") ...
            && ~ismember(ch, options.Chapters)
        continue
    end

    items = spec.items;
    if isstruct(items) && ~isscalar(items)
        items = num2cell(items);
    elseif isstruct(items)
        items = {items};
    end

    for i = 1:numel(items)
        it  = items{i};
        nm  = string(it.name);
        src = string(it.source);
        mb  = 0;
        if isfield(it, "sizeMB"), mb = double(it.sizeMB); end

        [st, lp] = resolveItem(ch, nm, src, mb, options, lists(f).folder);

        Chapter(end+1,1)   = ch;  %#ok<AGROW>
        Name(end+1,1)      = nm;  %#ok<AGROW>
        Source(end+1,1)    = src; %#ok<AGROW>
        SizeMB(end+1,1)    = mb;  %#ok<AGROW>
        Status(end+1,1)    = st;  %#ok<AGROW>
        LocalPath(end+1,1) = lp;  %#ok<AGROW>
    end
end

manifest = table(Chapter, Name, Source, SizeMB, Status, LocalPath);

if options.Verbose
    printSummary(manifest, options);
end

if nargout == 0
    clear manifest
end
end

% ========================================================================
function [status, localPath] = resolveItem(ch, name, src, mb, options, dataFolder)
localPath = "";

if src == "builtin" || src == "matlab-example"
    status = "不需下載";
    return
end

if src == "local"
    localPath = string(fullfile(dataFolder, name));
    status = ternaryStr(isfile(localPath) || isfolder(localPath), "已附上", "缺少（教材不完整）");
    return
end

if ~startsWith(src, "http")
    status = "來源格式不明";
    return
end

target    = fullfile(options.CacheDir, "ch" + ch, name);
localPath = string(target);

if isfile(target) || isfolder(replace(target, ".zip", ""))
    status = "已快取";
    return
end

if options.DryRun
    status = sprintf("待下載 (%.0f MB)", mb);
    return
end

if ~isfolder(fileparts(target))
    mkdir(fileparts(target));
end

try
    fprintf("  下載中：%s (%.0f MB) ...\n", name, mb);
    websave(target, src);
    if endsWith(name, ".zip")
        unzip(target, fileparts(target));
    end
    status = "已下載";
catch ME
    status = "下載失敗：" + string(ME.message);
end
end

% ------------------------------------------------------------------------
function printSummary(m, options)
line = string(repmat('-', 1, 72));
fprintf("\n%s\n  課程資料檢查\n%s\n", line, line);

if isempty(m)
    fprintf("  找不到任何 datalist.json。\n");
    fprintf("  （各章的資料清單放在 該章/data/datalist.json）\n%s\n\n", line);
    return
end

fprintf("  快取位置：%s\n", options.CacheDir);
fprintf("  項目總數：%d\n\n", height(m));

st = unique(m.Status, "stable");
for k = 1:numel(st)
    sub = m(m.Status == st(k), :);
    fprintf("  %-20s %d 項", st(k), height(sub));
    if sum(sub.SizeMB) > 0
        fprintf("（共 %.0f MB）", sum(sub.SizeMB));
    end
    fprintf("\n");
end

pending = m(startsWith(m.Status, "待下載"), :);
if ~isempty(pending)
    fprintf("\n  尚未取得，共 %.0f MB：\n", sum(pending.SizeMB));
    for k = 1:height(pending)
        fprintf("    第 %s 章  %s\n", pending.Chapter(k), pending.Name(k));
    end
    if options.DryRun
        fprintf("\n  執行 downloadCourseData 開始下載。\n");
    end
end

missing = m(startsWith(m.Status, "缺少") | startsWith(m.Status, "下載失敗"), :);
if ~isempty(missing)
    fprintf("\n  有問題的項目：\n");
    for k = 1:height(missing)
        fprintf("    第 %s 章  %s  —  %s\n", missing.Chapter(k), missing.Name(k), missing.Status(k));
    end
end

fprintf("%s\n\n", line);
end

% ------------------------------------------------------------------------
function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end
