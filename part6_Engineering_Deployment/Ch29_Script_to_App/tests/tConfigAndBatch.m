classdef tConfigAndBatch < matlab.unittest.TestCase
%TCONFIGANDBATCH 設定檔讀寫與批次執行器的測試。

    properties
        TempDir
    end

    methods (TestMethodSetup)
        function makeTempDir(tc)
            tc.TempDir = string(tempname);
            mkdir(tc.TempDir);
            tc.addTeardown(@() rmdir(tc.TempDir, "s"));
        end
    end

    methods (Test)
        function nanThresholdSurvivesRoundTrip(tc)
            % 直接 jsonencode/jsondecode 會把 NaN 變成 []，這裡確定修好了
            f = fullfile(tc.TempDir, "cfg.json");
            ch29_saveConfig(struct(BackgroundRadius=15, MinArea=50, Threshold=NaN, ...
                InputFolder="x", FilePattern="*.png"), f);
            c = ch29_loadConfig(f);
            tc.verifyTrue(isnan(c.Threshold));
            tc.verifyClass(c.InputFolder, "string");
        end

        function misspelledFieldIsRejected(tc)
            f = fullfile(tc.TempDir, "typo.json");
            fid = fopen(f, "w"); fprintf(fid, '{"MinAera": 80}'); fclose(fid);
            tc.verifyError(@() ch29_loadConfig(f), "ipcv:ch29:unknownField");
        end

        function missingFieldsUseDefaults(tc)
            f = fullfile(tc.TempDir, "partial.json");
            fid = fopen(f, "w"); fprintf(fid, '{"MinArea": 80}'); fclose(fid);
            c = tc.verifyWarningFree(@() ch29_loadConfig(f));
            tc.verifyEqual(c.MinArea, 80);
            tc.verifyEqual(c.BackgroundRadius, 15);
        end

        function badValueIsRejected(tc)
            f = fullfile(tc.TempDir, "bad.json");
            fid = fopen(f, "w"); fprintf(fid, '{"Threshold": 3}'); fclose(fid);
            tc.verifyError(@() ch29_loadConfig(f), "ipcv:ch29:badField");
        end

        function oneBadFileDoesNotStopBatch(tc)
            good = fullfile(tc.TempDir, "good.png");
            imwrite(imread("rice.png"), good);
            broken = fullfile(tc.TempDir, "broken.png");
            fid = fopen(broken, "w"); fwrite(fid, "not a png"); fclose(fid);
            binary = fullfile(tc.TempDir, "binary.png");
            imwrite(imread("rice.png") > 100, binary);   % 讀回來是 logical

            cfg = struct(BackgroundRadius=15, MinArea=50, Threshold=NaN);
            [res, fail] = ch29_runBatch([good broken binary], cfg, Quiet=true);
            tc.verifyEqual(height(res), 1);
            tc.verifyEqual(height(fail), 2);
            tc.verifyTrue(any(fail.Identifier == "ipcv:ch29:alreadyBinary"));
        end

        function logFileIsWritten(tc)
            logf = fullfile(tc.TempDir, "run.log");
            good = fullfile(tc.TempDir, "good.png");
            imwrite(imread("rice.png"), good);
            cfg = struct(BackgroundRadius=15, MinArea=50, Threshold=NaN);
            ch29_runBatch(good, cfg, LogFile=logf, Quiet=true);
            txt = string(fileread(logf));
            tc.verifySubstring(txt, "1 成功、0 失敗");
        end
    end
end
