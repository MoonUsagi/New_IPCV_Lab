function results = buildSlides(options)
%BUILDSLIDES 由各章 README.md 產生 PowerPoint 簡報（需要 MATLAB Report Generator）。
%
%   BUILDSLIDES() 對每一章的 README.md 產生一份 ChNN_Slides.pptx，放到 build/output/slides。
%   README 的結構直接對應成投影片：
%     # 標題                 → 封面
%     ## / ### 小節          → 一張投影片（內容太長時自動分成「（續）」）
%     只有子標題的 ## 小節   → 章節分隔頁
%     段落、條列、表格、程式碼 → 依序排版；**粗體**與 `程式碼` 保留格式
%   「檔案」「延伸閱讀」「環境需求」等小節不做成投影片（見 SkipSections）。
%
%   BUILDSLIDES(Chapters=["29" "30"]) 只建置指定章節。
%   BUILDSLIDES(Combined=true) 另外產生一份把所有指定章節串起來的 IPCV_Lab_Slides.pptx。
%
%   課程說明總覽：build/templates/course_overview.md 會另外產生 IPCV_Lab_Overview.pptx，
%   合併版時放在最前面。BUILDSLIDES(Overview=false) 不產生。
%
%   RESULTS = BUILDSLIDES(___) 回傳 table：Chapter、Output、Slides、Status、Seconds。
%
%   ## 為什麼從 README 產生、而不是從主教材
%   README 是每章的**摘要**：一句話、學習目標、最重要的幾課（含實測表格）、
%   沒有驗證的部分——正好是一份簡報的骨架。主教材的完整內容與圖
%   用 buildHandbook(Format="docx") 或 "pdf" 產生講義。
%   **簡報裡沒有圖**：要放圖，從 buildHandbook 的 HTML／PDF 擷取。
%
%   名稱-值引數：
%     Chapters      章號字串陣列，預設 "all"
%     Combined      是否另外產生合併版，預設 false
%     Overview      是否產生課程說明總覽（並放在合併版最前面），預設 true
%     OutputDir     預設 build/output/slides
%     SkipSections  不做成投影片的小節標題關鍵字
%     FontName      中文字型，預設 "Microsoft JhengHei"
%
%   另見 BUILDHANDBOOK, MLREPORTGEN.PPT.PRESENTATION.

arguments
    options.Chapters     (1,:) string  = "all"
    options.Combined     (1,1) logical = false
    options.Overview     (1,1) logical = true
    options.OutputDir    (1,1) string  = ""
    options.SkipSections (1,:) string  = ["檔案" "延伸閱讀" "環境需求" "執行時間"]
    options.FontName     (1,1) string  = "Microsoft JhengHei"
end

if isempty(which("mlreportgen.ppt.Presentation"))
    error("ipcv:noReportGen", "需要 MATLAB Report Generator（mlreportgen.ppt）。");
end

root = ipcvRoot();
if strlength(options.OutputDir) == 0
    options.OutputDir = fullfile(root, "build", "output", "slides");
end
if ~isfolder(options.OutputDir)
    mkdir(options.OutputDir);
end

readmes = dir(fullfile(root, "part*", "Ch*", "README.md"));
chNums = strings(numel(readmes), 1);
for k = 1:numel(readmes)
    tok = regexp(readmes(k).folder, "Ch(\d{2})_", "tokens", "once");
    if ~isempty(tok), chNums(k) = string(tok{1}); end
end
[chNums, order] = sort(chNums);
readmes = readmes(order);
if ~(isscalar(options.Chapters) && options.Chapters == "all")
    keep = ismember(chNums, options.Chapters);
    readmes = readmes(keep);
    chNums = chNums(keep);
end
if isempty(readmes)
    error("ipcv:noMatch", "找不到指定章節的 README.md。");
end

Chapter = strings(0,1); Output = strings(0,1); Slides = zeros(0,1);
Status = strings(0,1); Seconds = zeros(0,1);
allSlides = {};

fprintf("\n建置簡報：%d 章 → %s\n\n", numel(readmes), options.OutputDir);
for k = 1:numel(readmes)
    src = fullfile(readmes(k).folder, readmes(k).name);
    dst = fullfile(options.OutputDir, "Ch" + chNums(k) + "_Slides.pptx");
    fprintf("  [%2d/%2d] 第 %s 章 ... ", k, numel(readmes), chNums(k));
    t0 = tic;
    try
        deck = parseReadme(src, options.SkipSections);
        n = writeDeck(dst, {deck}, options.FontName);
        st = "成功";
        fprintf("成功（%d 張，%.1f 秒）\n", n, toc(t0));
        allSlides{end+1} = deck; %#ok<AGROW>
    catch ME
        st = "失敗：" + string(ME.message);
        n = 0;
        fprintf("失敗\n          %s\n", ME.message);
    end
    Chapter(end+1,1) = chNums(k); %#ok<AGROW>
    Output(end+1,1)  = dst;       %#ok<AGROW>
    Slides(end+1,1)  = n;         %#ok<AGROW>
    Status(end+1,1)  = st;        %#ok<AGROW>
    Seconds(end+1,1) = toc(t0);   %#ok<AGROW>
end

overviewFile = fullfile(root, "build", "templates", "course_overview.md");
if options.Overview && isfile(overviewFile)
    t0 = tic;
    overview = parseReadme(overviewFile, options.SkipSections);
    nOv = writeDeck(fullfile(options.OutputDir, "IPCV_Lab_Overview.pptx"), {overview}, options.FontName);
    fprintf("\n  課程說明總覽：IPCV_Lab_Overview.pptx（%d 張，%.1f 秒）\n", nOv, toc(t0));
    allSlides = [{overview} allSlides];
end

if options.Combined && ~isempty(allSlides)
    dst = fullfile(options.OutputDir, "IPCV_Lab_Slides.pptx");
    t0 = tic;
    nAll = writeDeck(dst, allSlides, options.FontName);
    fprintf("\n  合併版：%s（%d 張，%.1f 秒）\n", dst, nAll, toc(t0));
end

results = table(Chapter, Output, Slides, Status, Seconds);
nOK = nnz(results.Status == "成功");
fprintf("\n完成：%d 成功、%d 失敗，共 %d 張投影片\n\n", nOK, height(results) - nOK, sum(results.Slides));
if nargout == 0
    clear results
end
end

% ========================================================================
% 解析 README

function deck = parseReadme(file, skip)
lines = splitlines(string(fileread(file)));
lines = erase(lines, char(13));
deck = struct(Title="", Subtitle="", Slides={{}});
current = [];
skipping = false;
inCode = false;
codeBuf = strings(0,1);
k = 0;
while k < numel(lines)
    k = k + 1;
    raw = lines(k);
    % 程式碼區塊
    if startsWith(strtrim(stripQuote(raw)), "```")
        if inCode
            current = addBlock(current, "code", codeBuf, skipping);
            codeBuf = strings(0,1);
            inCode = false;
        else
            inCode = true;
        end
        continue
    end
    if inCode
        codeBuf(end+1,1) = stripQuote(raw); %#ok<AGROW>
        continue
    end

    line = strtrim(stripQuote(raw));
    if line == "" || line == "---"
        continue
    end

    if startsWith(line, "# ")
        deck.Title = cleanInline(extractAfter(line, 2));
        continue
    end
    if startsWith(line, "## ") || startsWith(line, "### ")
        deck = flushSlide(deck, current);
        level = strlength(extractBefore(line, " "));
        title = cleanInline(extractAfter(line, level + 1));
        if level == 2
            skipping = any(contains(title, skip));
        end
        current = struct(Title=title, Level=level, Blocks={{}});
        if skipping, current = []; end
        continue
    end
    if isempty(current) && ~skipping && deck.Title ~= "" && deck.Subtitle == "" && ~startsWith(line, "|")
        deck.Subtitle = cleanInline(line);
        continue
    end
    if skipping || isempty(current)
        continue
    end
    if startsWith(line, "|")
        current = addTableLine(current, line);
    else
        current = addBlock(current, "text", line, false);
    end
end
deck = flushSlide(deck, current);

% 只有標題、沒有內容的 ## 後面接著 ### → 章節分隔頁
for s = 1:numel(deck.Slides)
    deck.Slides{s}.IsSection = isempty(deck.Slides{s}.Blocks) && deck.Slides{s}.Level == 2;
end
% 沒有內容又不是章節分隔頁的投影片拿掉
keep = cellfun(@(sl) ~isempty(sl.Blocks) || sl.IsSection, deck.Slides);
deck.Slides = deck.Slides(keep);
end

function s = stripQuote(s)
s = regexprep(s, "^\s*>\s?", "");
end

function current = addBlock(current, kind, content, skipping)
if skipping || isempty(current), return; end
b = current.Blocks;
if kind == "text" && ~isempty(b) && b{end}.Kind == "text"
    b{end}.Lines(end+1,1) = content;
else
    b{end+1} = struct(Kind=kind, Lines=content(:), Rows={{}});
end
current.Blocks = b;
end

function current = addTableLine(current, line)
cells = strtrim(split(strip(line, "|"), "|")).';
if all(strlength(regexprep(cells, "[\-:\s]", "")) == 0)
    return                                  % 分隔列 |---|---|
end
cells = cleanInlineKeep(cells);
b = current.Blocks;
if isempty(b) || b{end}.Kind ~= "table"
    b{end+1} = struct(Kind="table", Lines=strings(0,1), Rows={{cells}});
else
    b{end}.Rows{end+1} = cells;
end
current.Blocks = b;
end

function deck = flushSlide(deck, current)
if ~isempty(current)
    deck.Slides{end+1} = current;
end
end

function t = cleanInline(t)
t = erase(cleanInlineKeep(t), ["**" "`"]);
end

function t = cleanInlineKeep(t)
% 保留 ** 與 `（排版時轉成粗體與等寬），去掉 Markdown 連結與跳脫字元
t = regexprep(t, "\[([^\]]+)\]\([^)]+\)", "$1");
t = replace(t, ["\_" "\*" "\[" "\]" "\|"], ["_" "*" "[" "]" "|"]);
end

% ========================================================================
% 產生 pptx

function n = writeDeck(file, decks, fontName)
import mlreportgen.ppt.*
if isfile(file), delete(file); end
ppt = Presentation(file);
open(ppt);
n = 0;
for d = 1:numel(decks)
    deck = decks{d};
    cover = add(ppt, "Title Slide");
    n = n + 1;
    replace(cover, "Title", deck.Title);
    replace(cover, "Subtitle", deck.Subtitle + "｜IPCV_Lab 課程教材｜MATLAB R2026b");
    for s = 1:numel(deck.Slides)
        sl = deck.Slides{s};
        if sl.IsSection
            sec = add(ppt, "Section Header");
            n = n + 1;
            replace(sec, "Title", titleParagraph(sl.Title, fontName));
            continue
        end
        n = n + addContentSlides(ppt, sl, fontName);
    end
end
close(ppt);
end

function page = addContentSlides(ppt, sl, fontName)
% 依估計高度把區塊排進投影片，放不下就開新的一張「（續）」
top = 1.65; bottom = 7.05; left = 0.6; width = 12.1;
pieces = expandBlocks(sl.Blocks, bottom - top);
page = 0;
y = bottom;                                 % 強迫第一個區塊開新頁
slide = [];
for p = 1:numel(pieces)
    h = pieces{p}.Height;
    if y + h > bottom && ~(y == top)
        page = page + 1;
        slide = add(ppt, "Title Only");
        title = sl.Title;
        if page > 1, title = title + "（續）"; end
        replace(slide, "Title", titleParagraph(title, fontName));
        y = top;
    end
    placeBlock(slide, pieces{p}, left, y, width, fontName);
    y = y + h + 0.12;
end
end

function pieces = expandBlocks(blocks, pageHeight)
% 把每個區塊轉成可排版的片段；太高的表格與文字拆成數段
pieces = {};
for b = 1:numel(blocks)
    blk = blocks{b};
    switch blk.Kind
        case "text"
            chunk = strings(0,1); hh = 0;
            for i = 1:numel(blk.Lines)
                lh = textHeight(blk.Lines(i));
                if hh + lh > pageHeight && ~isempty(chunk)
                    pieces{end+1} = struct(Kind="text", Lines=chunk, Rows={{}}, Height=hh); %#ok<AGROW>
                    chunk = strings(0,1); hh = 0;
                end
                chunk(end+1,1) = blk.Lines(i); %#ok<AGROW>
                hh = hh + lh;
            end
            if ~isempty(chunk)
                pieces{end+1} = struct(Kind="text", Lines=chunk, Rows={{}}, Height=hh); %#ok<AGROW>
            end
        case "code"
            lines = blk.Lines;
            maxLines = floor(pageHeight / 0.26) - 1;
            for i = 1:maxLines:numel(lines)
                part = lines(i:min(i + maxLines - 1, end));
                pieces{end+1} = struct(Kind="code", Lines=part, Rows={{}}, Height=0.26*numel(part) + 0.15); %#ok<AGROW>
            end
        case "table"
            header = blk.Rows{1};
            body = blk.Rows(2:end);
            rowH = cellfun(@(r) tableRowHeight(r), blk.Rows);
            chunk = {}; hh = rowH(1);
            for i = 1:numel(body)
                if hh + rowH(i+1) > pageHeight && ~isempty(chunk)
                    pieces{end+1} = struct(Kind="table", Lines=strings(0,1), Rows={[{header} chunk]}, Height=hh); %#ok<AGROW>
                    chunk = {}; hh = rowH(1);
                end
                chunk{end+1} = body{i}; %#ok<AGROW>
                hh = hh + rowH(i+1);
            end
            pieces{end+1} = struct(Kind="table", Lines=strings(0,1), Rows={[{header} chunk]}, Height=hh); %#ok<AGROW>
    end
end
end

function h = textHeight(line)
% 18pt 的全形字寬 0.25 吋，12.1 吋寬約 46 個字（扣掉邊距）；英數算半格
w = sum(double(char(line)) > 255) + 0.55 * sum(double(char(line)) <= 255);
h = 0.36 * max(1, ceil(w / 46));
end

function h = tableRowHeight(cells)
n = numel(cells);
colChars = 68 / max(n, 1) - 1;             % 12pt 全形字 0.167 吋：整列約 72 字，扣掉每格邊距
lines = 1;
for c = 1:n
    t = erase(cells(c), ["**" "`"]);
    w = sum(double(char(t)) > 255) + 0.55 * sum(double(char(t)) <= 255);
    lines = max(lines, ceil(w / colChars));
end
h = 0.12 + 0.24 * lines;
end

function placeBlock(slide, piece, left, y, width, fontName)
import mlreportgen.ppt.*
switch piece.Kind
    case "text"
        tb = TextBox();
        tb.X = inch(left); tb.Y = inch(y); tb.Width = inch(width); tb.Height = inch(piece.Height);
        for i = 1:numel(piece.Lines)
            add(tb, richParagraph(piece.Lines(i), "18pt", fontName));
        end
        add(slide, tb);
    case "code"
        tb = TextBox();
        tb.X = inch(left); tb.Y = inch(y); tb.Width = inch(width); tb.Height = inch(piece.Height);
        for i = 1:numel(piece.Lines)
            p = Paragraph(piece.Lines(i));
            p.Style = {FontFamily("Consolas"), FontSize("12pt")};
            add(tb, p);
        end
        tb.Style = {BackgroundColor("#F2F2F2")};
        add(slide, tb);
    case "table"
        rows = piece.Rows;
        nCol = numel(rows{1});
        t = Table(nCol);
        for r = 1:numel(rows)
            tr = TableRow();
            cells = rows{r};
            cells(end+1:nCol) = "";
            for c = 1:nCol
                te = TableEntry();
                append(te, richParagraph(cells(c), "12pt", fontName, r == 1));
                if r == 1
                    te.Style = {BackgroundColor("#DDE6F4")};
                end
                append(tr, te);
            end
            append(t, tr);
        end
        t.X = inch(left); t.Y = inch(y); t.Width = inch(width);
        add(slide, t);
end
end

function p = richParagraph(line, sizeText, fontName, allBold)
% **粗體** 與 `程式碼` 轉成對應格式；條列符號換成圓點
import mlreportgen.ppt.*
if nargin < 4, allBold = false; end
line = regexprep(line, "^\s*[-*]\s+", "• ");
p = Paragraph();
parts = regexp(char(line), "(\*\*[^*]+\*\*|`[^`]+`)", "split");
marks = regexp(char(line), "(\*\*[^*]+\*\*|`[^`]+`)", "match");
for i = 1:numel(parts)
    addRun(p, string(parts{i}), allBold, false, sizeText, fontName);
    if i <= numel(marks)
        m = string(marks{i});
        if startsWith(m, "**")
            addRun(p, erase(extractBetween(m, 3, strlength(m) - 2), "`"), true, false, sizeText, fontName);
        else
            addRun(p, extractBetween(m, 2, strlength(m) - 1), allBold, true, sizeText, fontName);
        end
    end
end
end

function addRun(p, txt, isBold, isCode, sizeText, fontName)
import mlreportgen.ppt.*
if strlength(txt) == 0, return; end
t = Text(txt);
% mlreportgen.ppt.FontFamily 沒有東亞字型屬性；微軟正黑體本身涵蓋英數，
% 程式碼用 Consolas，其中的中文由 PowerPoint 自動換字型
ff = FontFamily(fontName);
if isCode
    ff = FontFamily("Consolas");
end
t.Style = {ff, FontSize(sizeText)};
if isBold
    t.Style = [t.Style {Bold(true)}];
end
if isCode
    t.Style = [t.Style {FontColor("#1F4E79")}];
end
append(p, t);
end

function s = inch(v)
s = sprintf("%.2fin", v);
end

function p = titleParagraph(txt, fontName)
% 標題用 28pt，長標題最多兩行也不會壓到內容
import mlreportgen.ppt.*
p = Paragraph(txt);
p.Style = {FontFamily(fontName), FontSize("28pt")};
end
