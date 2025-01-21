% Создаем TCP/IP сервер
clear all;
clear functions;
server = tcpserver("127.0.0.1", 5556);

try
    disp(['MATLAB listening on port 5556']);

    while true

        try
            client = [];
            startTime = tic;
            timeout = 10;

            while isempty(client) && toc(startTime) < timeout

                if server.NumBytesAvailable > 0
                    client = server;
                    break;
                end

                pause(0.1);
            end

            if isempty(client)
                disp("Timeout occurred while waiting for connection or no data received.");
                continue;
            end

            disp(['Client (potentially) connected. Starting data processing.']);

            while true

                try
                    data = read(server, server.NumBytesAvailable, "uint8");

                    if isempty(data)
                        disp('Client disconnected.');
                        break;
                    end

                    dataLength = length(data);
                    disp(['Received data length: ' num2str(dataLength)]);

                    if dataLength == 154 || dataLength == 156

                        try
                            % извлечение RSSI
                            if dataLength == 156
                                rssiIndex = 5;
                            else
                                rssiIndex = 5;
                            end

                            originalRSSI = data(rssiIndex);
                            disp(['Original RSSI: ' num2str(originalRSSI)]);

                            newRSSI = originalRSSI - 1;

                            if newRSSI > 255
                                newRSSI = 255;
                            elseif newRSSI < 0
                                newRSSI = 0;
                            end

                            data(rssiIndex) = newRSSI;
                            disp(['Modified RSSI: ' num2str(newRSSI)]);

                            write(server, data, "uint8");
                            disp(['Sent modified data (length: ' num2str(length(data)) ')']);

                        catch packetError
                            disp(['Error processing packet: ' packetError.message]);
                            write(server, data, "uint8");
                            disp(['Sent original data back due to error.']);
                        end

                    else
                        disp(['Received data with unexpected length: ' num2str(dataLength)]);
                        write(server, data, "uint8");
                        disp(['Sent original data back.']);
                    end

                catch receiveError
                    disp(['Error receiving data: ' receiveError.message]);
                    break;
                end

            end

            disp("Client data processing finished.");

        catch acceptError
            disp(['Error accepting connection: ' acceptError.message]);
            break;
        end

    end

catch bindError
    disp(['Error binding to port: ' bindError.message]);
end

clear server;
disp('MATLAB script finished.');
