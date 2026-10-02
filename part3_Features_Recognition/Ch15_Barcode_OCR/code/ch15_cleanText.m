function s = ch15_cleanText(txt)
%CH15_CLEANTEXT 把 ocrText 的輸出正規化成單行字串，以便與 ground truth 比較。
%
%   S = CH15_CLEANTEXT(TXT) 接受 ocrText 的 Text 屬性（可能是多行的 char
%   或 string 陣列），回傳去除多餘空白的單行 string。
%
%   為什麼需要正規化
%   ----------------
%   ocr 的 Text 屬性帶有原始的換行與對齊空白，例如：
%
%     "4 MathWorks:\n\n \n\nThe MathWorks, Inc.\n\n-3 Apple Hill Drive"
%
%   直接拿去算編輯距離的話，**大部分的「錯誤」會來自空白字元**，
%   而不是辨識錯誤。那個 CER 量到的是排版不是辨識能力。
%
%   本函式把所有連續空白（含換行）壓成單一空格並去除頭尾，
%   讓 CER 反映真正的字元辨識錯誤。
%
%   **這個決定會影響結論，所以要說明白**：正規化之後就無法評估
%   OCR 的**版面**還原能力了。若你的應用在意換行位置
%   （例如要還原表格結構），就不該這樣壓平——
%   那時要用別的評估方式（例如逐行比對）。
%
%   另見 CH15_CER, OCRTEXT.

arguments
    txt
end

% **注意 char 與 string 陣列的差別。**
% ocrText.Text 是 char 陣列。對 char 做 txt(:) 會把它拆成
% **一個一個字元**，strjoin 之後每個字母中間都會多一個空格
% （"ABC" 變成 "A B C"），CER 會被灌爆。
if ischar(txt)
    s = strjoin(string(txt), " ");     % char 列向量 -> 單一 string
else
    s = strjoin(string(txt(:))', " "); % string / cell 陣列才逐元素接
end

s = regexprep(s, "\s+", " ");
s = strtrim(s);
end
