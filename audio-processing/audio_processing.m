%% Audio Signal Processing - Signals and Systems
% Noise reduction, speed changes, reversal, frequency-domain mixing,
% and time/frequency visualizations.

clear;
clc;
close all;

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
inputPath = fullfile(projectRoot, 'input', 'potc.wav');
outputDir = fullfile(projectRoot, 'output');
figureDir = fullfile(projectRoot, 'figures', 'generated-results');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
if ~exist(figureDir, 'dir')
    mkdir(figureDir);
end

%% Read and inspect the original audio
[frequency, amplitude, originalData, sampleRate] = read_voice(inputPath); %#ok<ASGLU>
save_signal_plots(originalData, sampleRate, 'Original', 'original', figureDir);

%% Remove high-frequency noise and the noisy band around 1000 Hz
cleanData = low_pass_filter(originalData, sampleRate, 4800, 0, 0.99, 100);
cleanData = filter_out_frequency(cleanData, sampleRate, 1000, 250, 0, 0.99, 100);

% Apply very strong low-pass filtering only to the first and last 0.05 s.
cleanData = low_pass_filter(cleanData, sampleRate, 1, 0.05, 0.99, 100);
cleanData = low_pass_filter(cleanData, sampleRate, 1, -0.05, 0.99, 100);
cleanData = normalize_signal(cleanData);

cleanPath = fullfile(outputDir, 'cleanpotc.wav');
write_voice(cleanData, sampleRate, cleanPath);
save_signal_plots(cleanData, sampleRate, 'Cleaned', 'cleanpotc', figureDir);

%% Create fast, slow, and reversed versions
[fastData, fastRate] = change_voice_speed(cleanData, sampleRate, 2);
[slowData, slowRate] = change_voice_speed(cleanData, sampleRate, 0.5);
reversedData = reverse_voice(cleanData);

fastPath = fullfile(outputDir, 'fastpotc.wav');
slowPath = fullfile(outputDir, 'slowpotc.wav');
reversedPath = fullfile(outputDir, 'revpotc.wav');

write_voice(fastData, fastRate, fastPath);
write_voice(slowData, slowRate, slowPath);
write_voice(reversedData, sampleRate, reversedPath);

save_signal_plots(fastData, fastRate, '2x Speed', 'fastpotc', figureDir);
save_signal_plots(slowData, slowRate, '0.5x Speed', 'slowpotc', figureDir);
save_signal_plots(reversedData, sampleRate, 'Reversed', 'revpotc', figureDir);

%% Mix all processed signals in the frequency domain
audioSignals = {cleanData, fastData, slowData, reversedData};
sampleRates = [sampleRate, fastRate, slowRate, sampleRate];
[mixedData, mixedRate] = mix_voices_frequency_domain(audioSignals, sampleRates);
mixedData = normalize_signal(mixedData);

mixedPath = fullfile(outputDir, 'mixpotc.wav');
write_voice(mixedData, mixedRate, mixedPath);
save_signal_plots(mixedData, mixedRate, 'Frequency-Domain Mix', ...
    'mixpotc', figureDir);

disp(['Processing complete. Audio files saved to: ', outputDir]);

%% Local functions
function [frequency, amplitude, data, sampleRate] = read_voice(path)
    [data, sampleRate] = audioread(path);
    if size(data, 2) > 1
        data = mean(data, 2);
    end
    [frequency, amplitude] = single_sided_spectrum(data, sampleRate);
end

function normalizedData = normalize_signal(data)
    peak = max(abs(data), [], 'all');
    if peak == 0
        normalizedData = data;
    else
        normalizedData = data / peak;
    end
end

function [newData, newRate] = change_voice_speed(data, sampleRate, speedFactor)
    arguments
        data
        sampleRate (1, 1) double {mustBePositive}
        speedFactor (1, 1) double {mustBePositive}
    end
    newData = data;
    newRate = round(sampleRate * speedFactor);
end

function filteredData = low_pass_filter(data, sampleRate, cutoff, timeLimit, ...
        steepness, stopbandAttenuation)
    fullyFiltered = lowpass(data, cutoff, sampleRate, ...
        Steepness=steepness, StopbandAttenuation=stopbandAttenuation);
    filteredData = apply_filter_to_segment(data, fullyFiltered, sampleRate, timeLimit);
end

function filteredData = high_pass_filter(data, sampleRate, cutoff, timeLimit, ...
        steepness, stopbandAttenuation)
    fullyFiltered = highpass(data, cutoff, sampleRate, ...
        Steepness=steepness, StopbandAttenuation=stopbandAttenuation);
    filteredData = apply_filter_to_segment(data, fullyFiltered, sampleRate, timeLimit);
end

function output = apply_filter_to_segment(original, filtered, sampleRate, timeLimit)
    if timeLimit == 0
        output = filtered;
        return;
    end

    sampleCount = min(round(abs(timeLimit) * sampleRate), length(original));
    output = original;
    if timeLimit > 0
        output(1:sampleCount, :) = filtered(1:sampleCount, :);
    else
        indexRange = (length(original) - sampleCount + 1):length(original);
        output(indexRange, :) = filtered(indexRange, :);
    end
end

function filteredData = filter_out_frequency(data, sampleRate, centerFrequency, ...
        halfWidth, timeLimit, steepness, stopbandAttenuation)
    lowFrequencyPart = low_pass_filter(data, sampleRate, ...
        centerFrequency - halfWidth, timeLimit, steepness, stopbandAttenuation);
    highFrequencyPart = high_pass_filter(data, sampleRate, ...
        centerFrequency + halfWidth, timeLimit, steepness, stopbandAttenuation);
    filteredData = lowFrequencyPart + highFrequencyPart;
end

function reversedData = reverse_voice(data)
    reversedData = flipud(data);
end

function [mixedData, targetRate] = mix_voices_frequency_domain(signals, rates)
    targetRate = min(rates);
    signalCount = numel(signals);
    preparedSignals = cell(1, signalCount);
    maximumLength = 0;

    for i = 1:signalCount
        currentSignal = signals{i};
        currentRate = rates(i);
        if currentRate ~= targetRate
            currentSignal = resample(currentSignal, targetRate, currentRate);
        end
        preparedSignals{i} = currentSignal(:);
        maximumLength = max(maximumLength, length(currentSignal));
    end

    mixedSpectrum = zeros(maximumLength, 1);
    for i = 1:signalCount
        paddedSignal = zeros(maximumLength, 1);
        paddedSignal(1:length(preparedSignals{i})) = preparedSignals{i};
        mixedSpectrum = mixedSpectrum + fft(paddedSignal);
    end

    mixedData = real(ifft(mixedSpectrum)) / signalCount;
end

function write_voice(data, sampleRate, path)
    audiowrite(path, data, sampleRate);
end

function [frequency, amplitude] = single_sided_spectrum(data, sampleRate)
    sampleCount = length(data);
    transformed = fft(data);
    twoSided = abs(transformed / sampleCount);
    oneSidedLength = floor(sampleCount / 2) + 1;
    amplitude = twoSided(1:oneSidedLength);
    if oneSidedLength > 2
        amplitude(2:end-1) = 2 * amplitude(2:end-1);
    end
    frequency = sampleRate * (0:(oneSidedLength - 1)) / sampleCount;
end

function save_signal_plots(data, sampleRate, titleText, filePrefix, outputDir)
    [frequency, amplitude] = single_sided_spectrum(data, sampleRate);
    time = (0:(length(data) - 1)) / sampleRate;

    figure('Color', 'white');
    plot(frequency, amplitude);
    xlabel('Frequency (Hz)');
    ylabel('Amplitude');
    title([titleText, ' - Frequency Spectrum']);
    grid on;
    exportgraphics(gcf, fullfile(outputDir, [filePrefix, '-amplitude.png']), ...
        'Resolution', 180);

    figure('Color', 'white');
    plot(time, data);
    xlabel('Time (s)');
    ylabel('Amplitude');
    title([titleText, ' - Waveform']);
    grid on;
    exportgraphics(gcf, fullfile(outputDir, [filePrefix, '-waveform.png']), ...
        'Resolution', 180);

    figure('Color', 'white');
    spectrogram(data, 1000, 20, 1000, sampleRate, 'yaxis');
    title([titleText, ' - Spectrogram']);
    exportgraphics(gcf, fullfile(outputDir, [filePrefix, '-spectrogram.png']), ...
        'Resolution', 180);
end
