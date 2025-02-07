% Определение порядка байт системы
[~, ~, endian] = computer;

% Открытие файла
fid = fopen('data_low.txt', 'r');

if fid == -1
    error('Не удалось открыть файл');
end

% Инициализация
bursts = struct('tn', {}, 'fn', {}, 'rssi', {}, 'toa', {}, 'symbols', {});
lineNum = 0;
successCount = 0;
errorCount = 0;
progressStep = 1000; % Шаг вывода прогресса

% Чтение файла построчно
while ~feof(fid)
    line = fgetl(fid);
    lineNum = lineNum + 1;

    try
        % Вывод прогресса
        if mod(lineNum, progressStep) == 0
            fprintf('Обработка строки %d...\n', lineNum);
        end

        % Обработка строки
        line = strrep(line, ' ', '');
        elements = strsplit(line, ',');
        elements = elements(~cellfun('isempty', elements));

        % Проверка количества элементов
        if numel(elements) < 156
            error('Недостаточно элементов (%d вместо 156)', numel(elements));
        end

        % Преобразование в числа
        buf = str2double(elements);

        if any(isnan(buf))
            error('Обнаружены нечисловые значения');
        end

        % Создание структуры
        burstData = struct();

        % Парсинг полей
        burstData.tn = bitand(uint8(buf(1)), 7);
        burstData.fn = int32(buf(2)) * 256 ^ 3 + int32(buf(3)) * 256 ^ 2 + ...
            int32(buf(4)) * 256 + int32(buf(5));
        burstData.rssi = -int8(buf(6));

        bytes = uint8(buf(7:8));

        if endian == 'L'
            bytes = fliplr(bytes);
        end

        burstData.toa = typecast(bytes, 'int16');

        burstData.symbols = uint8(buf(9:156));
        burstData.symbols(burstData.symbols > 0) = 1;

        % Сохранение данных
        bursts(end + 1) = burstData;
        successCount = successCount + 1;

    catch ME
        % Обработка ошибок
        errorCount = errorCount + 1;
        fprintf('Ошибка в строке %d: %s\n', lineNum, ME.message);
        continue;
    end

end

% Закрытие файла
fclose(fid);

% Вывод сводки
fprintf('\nОбработка завершена:\n');
fprintf('Всего строк:     %d\n', lineNum);
fprintf('Успешно:         %d\n', successCount);
fprintf('С ошибками:      %d\n', errorCount);
fprintf('Размер bursts:   %dx1 struct\n\n', numel(bursts));

% Сборка 8 burst'ов
full_phase = [];

for i = 1:32
    burst = bursts(i);
    bits = burst.symbols(:);

    % Повтор шагов 3-6 для каждого burst
    diff_bits = mod(cumsum([0; bits]), 2);
    symbols = 2 * diff_bits - 1;
    upsampled = zeros(sps * numel(symbols), 1);
    upsampled(1:sps:end) = symbols;
    filtered = conv(upsampled, gauss_filter', 'same');
    full_phase = [full_phase; pi / (2 * sps) * cumsum(filtered)];
end

% Генерация сигнала
t_frame = (0:length(full_phase) - 1) / Rs;
gmsk_frame = exp(1i * full_phase);

% Графики
% figure;
% subplot(2, 1, 1);
% plot(t_frame * 1e3, abs(gmsk_frame));
% title('GSM TDMA Frame - Амплитуда');
% xlabel('Время (мс)');
% ylabel('Амплитуда');
% xlim([0 5]);
% grid on;

% subplot(2, 1, 2);
% plot(t_frame * 1e3, unwrap(angle(gmsk_frame)));
% title('GSM TDMA Frame - Фаза');
% xlabel('Время (мс)');
% ylabel('Фаза (рад)');
% xlim([0 5]);
% grid on;

% Параметры спектрограммы
% window = 256; % Размер окна в отсчетах
% noverlap = 128; % Перекрытие окон
% nfft = 512; % Количество точек FFT
window = 156;
noverlap = round(window * 0.75); % 75 % перекрытие
nfft = 1024;
% nfft = 2 ^ nextpow2(window); % Ближайшая степень двойки
fs = Rs; % Частота дискретизации (2.1667 МГц)

% % Построение спектрограммы для одного burst
% figure;
% spectrogram(gmsk_signal, hamming(window), noverlap, nfft, fs, 'centered', 'yaxis');
% title('Спектрограмма GSM Burst');
% colorbar;
% clim([-80 -20]); % Динамический диапазон в dB

% Для полного TDMA фрейма
figure(1);
spectrogram(gmsk_frame, hamming(window), noverlap, nfft, fs, 'centered', 'yaxis');
title('Спектрограмма');
colorbar;
clim([-150 -50]);
