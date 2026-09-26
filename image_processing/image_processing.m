%% Image Processing Project - Signals and Systems
% Spatial-domain convolution, feature maps, max pooling, and
% frequency-domain filtering. No personal information is stored here.

clear;
clc;
close all;

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
inputPath = fullfile(projectRoot, 'input', 'yann_lecun.jpg');
outputDir = fullfile(projectRoot, 'figures', 'generated-results');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% Load and resize the input image
inputImage = imread(inputPath);
resizedImage = imresize(inputImage, [600, 600]);

save_image_figure(inputImage, 'Original Image', ...
    fullfile(outputDir, '01-original-image.png'), true);
save_image_figure(resizedImage, 'Resized Image (600 x 600)', ...
    fullfile(outputDir, '02-resized-image.png'), true);

%% First convolutional layer
edgeEnhancementKernel = [
    -1, -1, -1;
    -1,  8, -1;
    -1, -1, -1
];

horizontalEdgeKernel = [
     1,  0, -1;
     1,  0, -1;
     1,  0, -1
];

verticalEdgeKernel = [
     1,  1,  1;
     0,  0,  0;
    -1, -1, -1
];

edgeEnhanced = apply_convolution(resizedImage, edgeEnhancementKernel, 1, 'same');
horizontalEdges = apply_convolution(resizedImage, horizontalEdgeKernel, 1, 'same');
verticalEdges = apply_convolution(resizedImage, verticalEdgeKernel, 1, 'same');

save_image_figure(edgeEnhanced, 'Edge Enhancement', ...
    fullfile(outputDir, '03-edge-enhancement.png'), false);
save_image_figure(horizontalEdges, 'Horizontal Edge Detection', ...
    fullfile(outputDir, '04-horizontal-edges.png'), false);
save_image_figure(verticalEdges, 'Vertical Edge Detection', ...
    fullfile(outputDir, '05-vertical-edges.png'), false);

layer1Features = cat(3, edgeEnhanced, horizontalEdges, verticalEdges);
save_feature_map(layer1Features, 'Layer 1 Feature Map', ...
    fullfile(outputDir, '06-layer-1-feature-map.png'));

%% Second convolutional layer
gaussianBlurKernel = [
     1,  4,  7,  4, 1;
     4, 16, 26, 16, 4;
     7, 26, 41, 26, 7;
     4, 16, 26, 16, 4;
     1,  4,  7,  4, 1
];
gaussianBlurKernel = gaussianBlurKernel / sum(gaussianBlurKernel, 'all');

largeEdgeKernel = [
     0,  0, -1,  0,  0;
     0,  0, -1,  0,  0;
     1, -1,  8, -1, -1;
     0,  0, -1,  0,  0;
     0,  0, -1,  0,  0
];

blurredFeatures = apply_convolution(layer1Features, gaussianBlurKernel, 1, 'same');
largeEdgeFeatures = apply_convolution(layer1Features, largeEdgeKernel, 1, 'same');

save_image_figure(blurredFeatures, 'Gaussian Blur', ...
    fullfile(outputDir, '07-gaussian-blur.png'), false);
save_image_figure(largeEdgeFeatures, 'Large Edge Enhancement', ...
    fullfile(outputDir, '08-large-edge-enhancement.png'), false);

layer2Features = cat(3, blurredFeatures, largeEdgeFeatures);
save_feature_map(layer2Features, 'Layer 2 Feature Map', ...
    fullfile(outputDir, '09-layer-2-feature-map.png'));

%% Max pooling
pooledFeatures = max_pooling(layer2Features, 3, 3);
save_feature_map(pooledFeatures, 'Max-Pooled Feature Map', ...
    fullfile(outputDir, '10-max-pooled-feature-map.png'));

%% Frequency-domain image processing
grayImage = to_grayscale(resizedImage);
save_image_figure(grayImage, 'Grayscale Image', ...
    fullfile(outputDir, '11-grayscale-image.png'), false);

[shiftedFFT, magnitudeSpectrum, phaseSpectrum] = image_fft(grayImage);

figure('Color', 'white');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
imagesc(log1p(magnitudeSpectrum));
axis image off;
colormap(gca, 'parula');
colorbar;
title('Magnitude Spectrum (Log Scale)');
nexttile;
imagesc(phaseSpectrum);
axis image off;
colormap(gca, 'gray');
colorbar;
title('Phase Spectrum');
exportgraphics(gcf, fullfile(outputDir, '12-fft-spectra.png'), 'Resolution', 180);

filterNames = {'Low-pass', 'High-pass', 'Band-pass', 'Laplacian'};
filterTypes = {'lowpass', 'highpass', 'bandpass', 'laplacian'};
lowCutoffs = [30, 0, 20, 0];
highCutoffs = [0, 30, 40, 0];

figure('Color', 'white', 'Position', [100, 100, 1100, 750]);
tiledlayout(4, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for i = 1:numel(filterTypes)
    [filteredImage, filterMask] = apply_frequency_filter( ...
        shiftedFFT, filterTypes{i}, lowCutoffs(i), highCutoffs(i));

    nexttile;
    imagesc(filterMask);
    axis image off;
    colormap(gca, 'gray');
    title([filterNames{i}, ' Mask']);

    nexttile;
    imagesc(filteredImage);
    axis image off;
    colormap(gca, 'gray');
    title([filterNames{i}, ' Result']);
end

exportgraphics(gcf, fullfile(outputDir, '13-frequency-domain-filters.png'), ...
    'Resolution', 180);

disp(['Processing complete. Results saved to: ', outputDir]);

%% Local functions
function output = apply_convolution(image, kernel, stride, padding)
    arguments
        image
        kernel (:, :) double
        stride (1, 1) double {mustBeInteger, mustBePositive} = 1
        padding {mustBeMember(padding, {'valid', 'same'})} = 'valid'
    end

    image = double(image);
    [kernelHeight, kernelWidth] = size(kernel);
    [height, width, channels] = size(image);

    if strcmp(padding, 'same')
        outputHeight = ceil(height / stride);
        outputWidth = ceil(width / stride);
        totalPadHeight = max((outputHeight - 1) * stride + kernelHeight - height, 0);
        totalPadWidth = max((outputWidth - 1) * stride + kernelWidth - width, 0);
        padTop = floor(totalPadHeight / 2);
        padLeft = floor(totalPadWidth / 2);
        paddedImage = zeros(height + totalPadHeight, width + totalPadWidth, channels);
        paddedImage(padTop + (1:height), padLeft + (1:width), :) = image;
    else
        outputHeight = floor((height - kernelHeight) / stride) + 1;
        outputWidth = floor((width - kernelWidth) / stride) + 1;
        paddedImage = image;
    end

    output = zeros(outputHeight, outputWidth);
    flippedKernel = rot90(kernel, 2);

    for outputRow = 1:outputHeight
        rowStart = (outputRow - 1) * stride + 1;
        rowRange = rowStart:(rowStart + kernelHeight - 1);
        for outputColumn = 1:outputWidth
            columnStart = (outputColumn - 1) * stride + 1;
            columnRange = columnStart:(columnStart + kernelWidth - 1);
            patch = paddedImage(rowRange, columnRange, :);
            for channel = 1:channels
                output(outputRow, outputColumn) = output(outputRow, outputColumn) + ...
                    sum(patch(:, :, channel) .* flippedKernel, 'all');
            end
        end
    end
end

function pooledImage = max_pooling(image, poolSize, stride)
    image = double(image);
    [height, width, channels] = size(image);
    outputHeight = floor((height - poolSize) / stride) + 1;
    outputWidth = floor((width - poolSize) / stride) + 1;
    pooledImage = zeros(outputHeight, outputWidth, channels);

    for channel = 1:channels
        for outputRow = 1:outputHeight
            rowStart = (outputRow - 1) * stride + 1;
            rowRange = rowStart:(rowStart + poolSize - 1);
            for outputColumn = 1:outputWidth
                columnStart = (outputColumn - 1) * stride + 1;
                columnRange = columnStart:(columnStart + poolSize - 1);
                patch = image(rowRange, columnRange, channel);
                pooledImage(outputRow, outputColumn, channel) = max(patch, [], 'all');
            end
        end
    end
end

function grayImage = to_grayscale(image)
    image = double(image) / 255;
    grayImage = 0.2989 * image(:, :, 1) + ...
                0.5870 * image(:, :, 2) + ...
                0.1140 * image(:, :, 3);
end

function [shiftedFFT, magnitude, phase] = image_fft(image)
    shiftedFFT = fftshift(fft2(double(image)));
    magnitude = abs(shiftedFFT);
    phase = angle(shiftedFFT);
end

function [filteredImage, filterMask] = apply_frequency_filter( ...
        shiftedFFT, filterType, lowCutoff, highCutoff)
    [height, width] = size(shiftedFFT);
    centerRow = floor(height / 2) + 1;
    centerColumn = floor(width / 2) + 1;
    [columns, rows] = meshgrid(1:width, 1:height);
    distance = hypot(rows - centerRow, columns - centerColumn);

    switch filterType
        case 'lowpass'
            filterMask = double(distance <= lowCutoff);
        case 'highpass'
            filterMask = double(distance >= highCutoff);
        case 'bandpass'
            filterMask = double(distance >= lowCutoff & distance <= highCutoff);
        case 'laplacian'
            filterMask = -(distance .^ 2);
            filterMask = filterMask / max(abs(filterMask), [], 'all');
        otherwise
            error('Unsupported filter type: %s', filterType);
    end

    filteredFFT = shiftedFFT .* filterMask;
    filteredImage = real(ifft2(ifftshift(filteredFFT)));
end

function save_image_figure(image, figureTitle, outputPath, isRGB)
    figure('Color', 'white');
    if isRGB
        image(image < 0) = 0;
        image(image > 255) = 255;
        imshow(uint8(image));
    else
        imagesc(image);
        axis image off;
        colormap(gca, 'gray');
    end
    title(figureTitle);
    exportgraphics(gcf, outputPath, 'Resolution', 180);
end

function save_feature_map(featureMaps, figureTitle, outputPath)
    [height, width, channelCount] = size(featureMaps);
    sampleStep = max(1, floor(max(height, width) / 150));
    sampledMaps = featureMaps(1:sampleStep:end, 1:sampleStep:end, :);
    [sampledHeight, sampledWidth, ~] = size(sampledMaps);
    [xGrid, yGrid] = meshgrid(1:sampledWidth, 1:sampledHeight);
    valueRange = max(sampledMaps, [], 'all') - min(sampledMaps, [], 'all');
    zOffset = max(valueRange * 1.2, 1);

    figure('Color', 'white');
    hold on;
    for channel = 1:channelCount
        zValues = sampledMaps(:, :, channel) + (channel - 1) * zOffset;
        surf(xGrid, yGrid, zValues, zValues, 'EdgeAlpha', 0.08);
    end
    xlabel('Width');
    ylabel('Height');
    zlabel('Feature value');
    title(figureTitle);
    view(45, 35);
    grid on;
    hold off;
    exportgraphics(gcf, outputPath, 'Resolution', 180);
end
