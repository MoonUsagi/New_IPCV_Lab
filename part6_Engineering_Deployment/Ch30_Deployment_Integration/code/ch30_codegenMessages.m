function msgs = ch30_codegenMessages(varName)
%CH30_CODEGENMESSAGES 讀出 codegen -reportinfo 存下的診斷訊息，並清掉那個變數。
%
%   MSGS = CH30_CODEGENMESSAGES(VARNAME) 讀取 `codegen(..., "-reportinfo", VARNAME)`
%   建立的報告變數，回傳 table（Type、Identifier、Text），然後把變數清掉。
%   沒有那個變數時回傳空 table——所以在 codegen 之前先呼叫一次，
%   就能確保之後讀到的不是上一次留下的報告。
%
%   ## 為什麼需要這支函式
%   **R2026b 起，codegen 失敗時不再把原因印在命令視窗**（R2026a 會印），
%   丟出的 `emlc:compilationError` 訊息只有「To view the report, open(...)」。
%   要在程式裡拿到原因，只能用 `-reportinfo`。
%
%   而 **`-reportinfo` 的變數一律建在 base 工作區，不是呼叫端的工作區**（實測 R2026b）。
%   在 Live Editor 執行腳本時兩者剛好相同，看不出差別；
%   一旦包進函式（例如 `verifyChapters` 的隔離執行），`exist("cgInfo", "var")` 就是 false。
%   這支函式從 base 工作區取出報告，呼叫端在哪裡都能用。
%
%   範例：
%     ch30_codegenMessages("cgInfo");          % 先清掉上一次的
%     try
%         codegen("f", "-args", {1}, "-reportinfo", "cgInfo");
%     catch ME
%         msgs = ch30_codegenMessages("cgInfo");
%         disp(msgs.Text)
%     end
%
%   另見 CODEGEN, CH30_BUILDMEX.

arguments
    varName (1,1) string = "cgInfo"
end

msgs = table(Size=[0 3], VariableTypes=["string" "string" "string"], ...
    VariableNames=["Type" "Identifier" "Text"]);

if ~evalin("base", "exist(""" + varName + """, ""var"")")
    return
end
info = evalin("base", varName);
evalin("base", "clear " + varName);

if ~isprop(info, "Messages") && ~isfield(info, "Messages")
    return
end
for k = 1:numel(info.Messages)
    m = info.Messages(k);
    msgs(end+1, :) = {string(m.Type), string(m.Identifier), string(m.Text)}; %#ok<AGROW>
end
end
