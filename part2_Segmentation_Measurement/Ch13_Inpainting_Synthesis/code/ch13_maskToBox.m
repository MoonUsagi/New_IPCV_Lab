function bb = ch13_maskToBox(mask)
%CH13_MASKTOBOX 由遮罩求軸對齊邊界框 [x y w h]。
%
%   BB = CH13_MASKTOBOX(MASK) 回傳 [x y width height]，
%   與 insertObjectAnnotation / bboxOverlapRatio 使用的格式相同。
%
%   注意順序：邊界框是 **[x y w h]**，也就是 [欄 列 寬 高]。
%   find 回傳的是 [列 欄]。第 11 章第 3 節已經踩過這個轉置陷阱
%   （regionprops 的 BoundaryCoordinates 是 [x y]，
%   bwboundaries 是 [row col]）——這裡是同一件事。
%
%   另見 CH13_MAKESYNTHETICSET, BBOXOVERLAPRATIO, INSERTOBJECTANNOTATION.

arguments
    mask {mustBeA(mask, ["logical" "numeric"])}
end
if ~islogical(mask), mask = logical(mask); end
if ~any(mask(:))
    error("ch13_maskToBox:emptyMask", "遮罩是空的，無法求邊界框。");
end

[r, c] = find(mask);
bb = [min(c), min(r), max(c)-min(c)+1, max(r)-min(r)+1];
end
