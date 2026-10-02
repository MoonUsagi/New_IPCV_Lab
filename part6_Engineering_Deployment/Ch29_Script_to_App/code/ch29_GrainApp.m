classdef ch29_GrainApp < handle
%CH29_GRAINAPP 顆粒計數的批次處理 App（程式化建立的 uifigure）。
%
%   APP = CH29_GRAINAPP() 開啟一個視窗：選資料夾、調三個參數、按「執行」，
%   結果顯示在表格裡，失敗的檔案另外列出。
%
%   APP = CH29_GRAINAPP(Visible=false) 不顯示視窗（測試用）。
%
%   ## 這個 App 刻意做得很「薄」
%   所有真正的工作都在 `ch29_runBatch` 與 `ch29_countGrains` 裡，
%   App 只做三件事：**讀介面上的值 → 呼叫函式 → 把結果放回介面**。
%   | 放在 App 裡 | 放在函式裡 |
%   |---|---|
%   | 元件的建立與排版 | 演算法 |
%   | 把欄位值組成 config | 參數驗證 |
%   | 把 table 顯示出來 | 錯誤處理、log |
%
%   **為什麼？** 因為函式可以用 `matlab.unittest` 在幾毫秒內測完，
%   而介面測試（`matlab.uitest`）一個按鍵就要好幾秒（本機量到 8 秒）。
%   邏輯放在 App 的 callback 裡，就只能用最慢、最脆弱的方式測它。
%
%   ## 為什麼用程式化的 uifigure
%   R2026a 以前 App Designer 只能存成二進位的 .mlapp，git diff 看不到改了什麼；
%   **R2026b 起它可以存成純文字（.m ＋ .xml）**，版本控制不再是理由。
%   這裡用程式化 uifigure 是為了讓教材在 -batch 模式也能建構與測試；
%   兩者用的元件完全一樣，「App 做薄、邏輯放函式」的原則也一樣。
%
%   另見 CH29_RUNBATCH, UIFIGURE, MATLAB.UITEST.TESTCASE.

    properties (SetAccess = private)
        Figure
        FolderField
        RadiusField
        MinAreaField
        ThresholdField
        AutoThresholdBox
        RunButton
        ResultTable
        FailureTable
        StatusLabel
    end

    properties (SetAccess = private)
        LastResults  = table()
        LastFailures = table()
    end

    methods
        function app = ch29_GrainApp(options)
            arguments
                options.Visible (1,1) logical = true
                options.Folder  (1,1) string  = ""
            end
            app.build(options.Visible);
            if strlength(options.Folder) > 0
                app.FolderField.Value = options.Folder;
            end
        end

        function config = currentConfig(app)
            %CURRENTCONFIG 把介面上的值組成 ch29_runBatch 要的 config。
            %   **這是 App 裡唯一需要單元測試的「邏輯」**，
            %   而它短到幾乎不會錯——這正是設計的目的。
            config = struct( ...
                BackgroundRadius = app.RadiusField.Value, ...
                MinArea          = app.MinAreaField.Value, ...
                Threshold        = NaN, ...
                InputFolder      = string(app.FolderField.Value), ...
                FilePattern      = "*.png");
            if ~app.AutoThresholdBox.Value
                config.Threshold = app.ThresholdField.Value;
            end
        end

        function run(app)
            %RUN 執行批次（按鈕的 callback 呼叫這個）。
            config = app.currentConfig();
            files = dir(fullfile(config.InputFolder, config.FilePattern));
            if isempty(files)
                app.StatusLabel.Text = "資料夾裡沒有符合 " + config.FilePattern + " 的檔案";
                return
            end
            names = string(fullfile({files.folder}, {files.name}));
            app.StatusLabel.Text = sprintf("處理中：%d 個檔案…", numel(names));
            drawnow limitrate
            [app.LastResults, app.LastFailures] = ch29_runBatch(names, config, Quiet=true);
            app.ResultTable.Data  = app.LastResults(:, ["File" "Count" "MeanArea"]);
            app.FailureTable.Data = app.LastFailures(:, ["File" "Message"]);
            app.StatusLabel.Text = sprintf("完成：%d 成功、%d 失敗", ...
                height(app.LastResults), height(app.LastFailures));
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                delete(app.Figure);
            end
        end
    end

    methods (Access = private)
        function build(app, visible)
            app.Figure = uifigure(Name="顆粒計數", Position=[100 100 720 480], ...
                Visible=visible);
            g = uigridlayout(app.Figure, [6 4]);
            g.RowHeight   = {30, 30, 30, 30, "1x", "1x"};
            g.ColumnWidth = {110, "1x", 110, "1x"};

            uilabel(g, Text="資料夾");
            app.FolderField = uieditfield(g, "text");
            app.FolderField.Layout.Column = [2 4];

            uilabel(g, Text="背景半徑");
            app.RadiusField = uieditfield(g, "numeric", Value=15, ...
                Limits=[1 200], RoundFractionalValues="on");
            uilabel(g, Text="最小面積");
            app.MinAreaField = uieditfield(g, "numeric", Value=50, Limits=[0 Inf]);

            app.AutoThresholdBox = uicheckbox(g, Text="自動門檻（Otsu）", Value=true);
            app.ThresholdField = uieditfield(g, "numeric", Value=0.2, Limits=[0 1]);
            app.RunButton = uibutton(g, Text="執行", ...
                ButtonPushedFcn=@(~,~) app.run());
            app.StatusLabel = uilabel(g, Text="就緒");

            app.ResultTable = uitable(g);
            app.ResultTable.Layout.Column = [1 4];
            app.FailureTable = uitable(g);
            app.FailureTable.Layout.Column = [1 4];
        end
    end
end
