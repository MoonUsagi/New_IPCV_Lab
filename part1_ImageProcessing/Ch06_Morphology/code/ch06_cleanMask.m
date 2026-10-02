function [out, log] = ch06_cleanMask(BW, options)
%CH06_CLEANMASK 以形態學清理二值分割結果的標準流程。
%
%   OUT = CH06_CLEANMASK(BW) 依預設順序清理遮罩：
%   開運算 → 閉運算 → 補洞 → 面積篩選 → 移除碰邊物件。
%
%   [OUT, LOG] = CH06_CLEANMASK(___) 另外回傳一張 table，記錄每個步驟後
%   還剩幾個連通區域、前景面積多少——用來診斷是哪一步殺掉了你的物件。
%
%   名稱-值引數：
%     OpenRadius   開運算的 disk 半徑，去雜點與斷開細連結。預設 3，設 0 跳過
%     CloseRadius  閉運算的 disk 半徑，補小缺口。預設 3，設 0 跳過
%     FillHoles    是否補內部破洞。預設 true
%     MinArea      最小面積（像素）。預設 50，設 0 跳過
%     MaxArea      最大面積（像素）。預設 Inf
%     ClearBorder  是否移除碰到影像邊界的物件。預設 false
%
%   為什麼預設是「先開後閉」
%   ------------------------
%   開運算去雜點，閉運算補缺口。順序反過來（先閉後開）的話，閉運算會先把
%   雜點和鄰近的真實物件連在一起，之後的開運算就分不開了——雜點會變成物件
%   的一部分永久留下。先開後閉則是「先清乾淨，再修補」，安全得多。
%
%   關於 ClearBorder
%   ----------------
%   預設是 false，但**做量測時應該設為 true**。碰到影像邊界的物件是被切掉
%   的，它的面積、周長、圓形度全都不對，納入統計會污染結果。
%   只有在「計數」且確定物件不會被切斷時才保持 false。
%
%   範例：
%     rice = imread("rice.png");
%     bw   = imbinarize(imtophat(rice, strel("disk", 15)));
%
%     [clean, log] = ch06_cleanMask(bw, MinArea=30, ClearBorder=true);
%     disp(log)
%     fprintf("最後剩 %d 個物件\n", max(bwlabel(clean), [], "all"));
%
%     % 診斷：哪一步殺掉最多物件？
%     [~, worst] = max(-diff(log.NumObjects));
%     fprintf("損失最多的步驟：%s\n", log.Step(worst+1));
%
%   另見 IMOPEN, IMCLOSE, IMFILL, BWAREAFILT, IMCLEARBORDER.

arguments
    BW {mustBeA(BW, ["logical" "numeric"])}
    options.OpenRadius  (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    options.CloseRadius (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    options.FillHoles   (1,1) logical                                   = true
    options.MinArea     (1,1) double {mustBeNonnegative}                = 50
    options.MaxArea     (1,1) double {mustBePositive}                   = Inf
    options.ClearBorder (1,1) logical                                   = false
end

if ~islogical(BW)
    BW = logical(BW);
end

out  = BW;
Step = "原始";
NumObjects = max(bwlabel(out), [], "all");
Area = nnz(out);

    function record(name)
        Step(end+1,1)       = name;                          %#ok<AGROW>
        NumObjects(end+1,1) = max(bwlabel(out), [], "all");  %#ok<AGROW>
        Area(end+1,1)       = nnz(out);                      %#ok<AGROW>
    end

% 先開：去雜點、斷開細連結
if options.OpenRadius > 0
    out = imopen(out, strel("disk", options.OpenRadius));
    record("開運算 r=" + options.OpenRadius);
end

% 後閉：補小缺口
if options.CloseRadius > 0
    out = imclose(out, strel("disk", options.CloseRadius));
    record("閉運算 r=" + options.CloseRadius);
end

if options.FillHoles
    out = imfill(out, "holes");
    record("補洞");
end

if options.MinArea > 0 || isfinite(options.MaxArea)
    % bwareafilt 在沒有任何符合條件的物件時會回傳空遮罩而不報錯
    out = bwareafilt(out, [options.MinArea options.MaxArea]);
    record(sprintf("面積篩選 [%g %g]", options.MinArea, options.MaxArea));
end

if options.ClearBorder
    out = imclearborder(out);
    record("移除碰邊物件");
end

log = table(Step, NumObjects, Area);
end
