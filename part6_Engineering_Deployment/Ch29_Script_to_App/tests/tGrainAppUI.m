classdef tGrainAppUI < matlab.uitest.TestCase
%TGRAINAPPUI ch29_GrainApp 的介面測試（matlab.uitest）。
%
%   **介面測試很慢**（本機一個按鍵約 8 秒），所以這裡只測
%   「按鈕真的有接到邏輯」這一件事。參數組合、錯誤處理全部在
%   tCountGrains 與 tConfigAndBatch 用單元測試做完了。

    methods (Test)
        function uncheckingAutoUsesManualThreshold(tc)
            app = ch29_GrainApp();
            tc.addTeardown(@delete, app);
            tc.type(app.ThresholdField, 0.25);
            tc.press(app.AutoThresholdBox);           % 取消勾選
            cfg = app.currentConfig();
            tc.verifyEqual(cfg.Threshold, 0.25);
        end

        function runButtonFillsResultTable(tc)
            folder = string(tempname); mkdir(folder);
            tc.addTeardown(@() rmdir(folder, "s"));
            imwrite(imread("rice.png"), fullfile(folder, "a.png"));
            app = ch29_GrainApp(Folder=folder);
            tc.addTeardown(@delete, app);
            tc.press(app.RunButton);
            tc.verifyEqual(height(app.LastResults), 1);
            tc.verifySubstring(string(app.StatusLabel.Text), "1 成功");
        end
    end
end
