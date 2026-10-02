%% 原版教材的線蟲活性判定腳本（保留供對照）
%
% 這是 IPCV_Lab 原版（R2024b）第 04 章的原始腳本，原樣保留作為歷史資產，
% 只做了兩件事：把編碼從 Big5 轉為 UTF-8，並加上這段說明。
%
% **這個腳本示範的流程已被第 10 章第 8 節取代**，原因有兩個：
%
% 1. 它依賴 `getMedianLength`，而後者用的是 `bwmorph(BW,"skel",Inf)`——
%    R2026a 已建議改用 `bwskel`。
%
% 2. 更重要的是，它把判斷門檻 **58** 寫死在註解裡而沒有記錄來歷。
%    第 10 章實測：改用 `bwskel` 之後，wormsBW2 的中位長度從 46.6 變成
%    58.7，**跨過門檻、分類結論反轉**——而程式不會給任何提示。
%
% 現行做法請用：
%   ch10_wormLength                  量測（可選骨架化方法）
%   ch10_wormLengthWithFingerprint   量測並回傳校正指紋
%   ch10_classifyWorm                依門檻分類，並檢查設定是否與校正時一致
%
% 另見 CH10_WORMLENGTH, CH10_CLASSIFYWORM.

%% Determine the worms are dead or alive.
% Compare the median length(58) of lines detected in alive and dead worms'
% images.
clc;close all;clear;imtool close all;

worms1 = imread('wormsBW1.png');

% Based on the median length of death and alive worms, you can select
% a threshold for classification.
classifyWorms('wormsBW1.png');

%%
worms2 = imread('wormsBW2.png');
classifyWorms('wormsBW2.png');
