#include <arpa/inet.h>
#include <getopt.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <zmq.h>

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>
// #include <mutex>
#include <chrono>
#include <iomanip>

struct Params {
    std::string fakeTrxAddress = "127.0.0.1";
    std::string trxconAddress = "127.0.0.1";
    int fakeTrxBasePort = 5700;
    int trxconBasePort = 6700;
};

std::string get_current_time() {
    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);

    std::stringstream ss;
    ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d %X");
    return ss.str();
}

// std::mutex log_mutex;

void log_message(const std::string& message) {
    // std::lock_guard<std::mutex> lock(log_mutex);
    std::cout << get_current_time() << ": " << message << std::endl;
}

void udp_send(int port, const char* buffer, int size,
              const std::string& address) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket creation failed");
        return;
    }

    sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    if (inet_pton(AF_INET, address.c_str(), &servaddr.sin_addr) <= 0) {
        perror("Invalid address");
        close(sockfd);
        return;
    }
    servaddr.sin_port = htons(port);

    sendto(sockfd, buffer, size, 0, (const sockaddr*)&servaddr,
           sizeof(servaddr));
    close(sockfd);
}

void udp_recv_fakeTRX(int port, void* publisher, const std::string& source) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket creation failed");
        return;
    }

    sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    servaddr.sin_port = htons(port);

    if (connect(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
        perror("connect failed");
        close(sockfd);
        return;
    }

    while (true) {
        char buffer[1024];
        int recv_len = recv(sockfd, buffer, sizeof(buffer), 0);
        if (recv_len > 0) {
            std::string received_data(buffer, recv_len);
            std::string message_with_source = source + ":" + received_data;
            log_message("Received from fakeTRX (port " + std::to_string(port) +
                        "): " + received_data);
            zmq_msg_t message;
            zmq_msg_init_size(&message, message_with_source.size());
            memcpy(zmq_msg_data(&message), message_with_source.c_str(),
                   message_with_source.size());
            zmq_sendmsg(publisher, &message, 0);
            zmq_msg_close(&message);
        } else if (recv_len < 0) {
            perror("recv failed");
            log_message("Error receiving from fakeTRX (port " +
                        std::to_string(port) + "): " + strerror(errno));
            break;
        } else {
            log_message("fakeTRX (port " + std::to_string(port) +
                        ") disconnected.");
            break;
        }
    }
    close(sockfd);
}

void udp_listen_trxcon(int port, void* publisher, const std::string& source) {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket creation failed");
        return;
    }

    sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(port);

    if (bind(sockfd, (const sockaddr*)&servaddr, sizeof(servaddr)) < 0) {
        perror("bind failed");
        close(sockfd);
        return;
    }
    while (true) {
        char buffer[1024];
        sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int recv_len = recvfrom(sockfd, buffer, sizeof(buffer), 0,
                                (sockaddr*)&client_addr, &client_len);

        if (recv_len > 0) {
            std::string received_data(buffer, recv_len);
            std::string message_with_source = source + ":" + received_data;
            log_message("Received from trxcon (port " + std::to_string(port) +
                        "): " + received_data);
            zmq_msg_t message;
            zmq_msg_init_size(&message, message_with_source.size());
            memcpy(zmq_msg_data(&message), message_with_source.c_str(),
                   message_with_source.size());
            zmq_sendmsg(publisher, &message, 0);
            zmq_msg_close(&message);
        }
    }
    close(sockfd);
}

std::string processWithMatlab(const std::string& data, void* requester) {
    zmq_msg_t request;
    zmq_msg_init_size(&request, data.size());
    memcpy(zmq_msg_data(&request), data.c_str(), data.size());

    int rc = zmq_msg_send(&request, requester, 0);
    zmq_msg_close(&request);
    if (rc == -1) {
        perror("zmq_msg_send failed");
        return "";
    }

    zmq_msg_t reply;
    zmq_msg_init(&reply);
    rc = zmq_msg_recv(&reply, requester, 0);
    if (rc == -1) {
        perror("zmq_msg_recv failed");
        zmq_msg_close(&reply);
        return "";
    }

    std::string receivedData(static_cast<char*>(zmq_msg_data(&reply)),
                             zmq_msg_size(&reply));
    zmq_msg_close(&reply);

    return receivedData;
}

int main(int argc, char* argv[]) {
    Params params;
    int numArfcns = 1;
    std::string matlabAddress = "tcp://127.0.0.1:5556";

    int opt;
    while ((opt = getopt(argc, argv, "f:t:b:p:n:m:")) != -1) {
        switch (opt) {
            case 'f':
                params.fakeTrxAddress = optarg;
                break;
            case 't':
                params.trxconAddress = optarg;
                break;
            case 'b':
                params.fakeTrxBasePort = std::stoi(optarg);
                break;
            case 'p':
                params.trxconBasePort = std::stoi(optarg);
                break;
            case 'n':
                numArfcns = std::stoi(optarg);
                if (numArfcns <= 0) {
                    std::cerr << "Number of ARFCNs must be positive.\n";
                    return 1;
                }
                break;
            case 'm':  // MATLAB
                matlabAddress = optarg;
                break;
            default:
                std::cerr << "Usage: " << argv[0]
                          << " -f <fakeTRX_address> -t <trxcon_address> -b "
                          << "<fakeTRX_base_port> -p <trxcon_base_port> [-n "
                          << "<num_arfcns>] [-m <tcp://matlab_full_address>]\n";
                return 1;
        }
    }

    log_message("Starting bridge");

    void* context = zmq_ctx_new();

    void* publisher = zmq_socket(context, ZMQ_PUB);
    void* subscriber = zmq_socket(context, ZMQ_SUB);
    zmq_bind(publisher, "tcp://127.0.0.1:5555");
    zmq_connect(subscriber, "tcp://127.0.0.1:5555");
    zmq_setsockopt(subscriber, ZMQ_SUBSCRIBE, "", 0);

    void* requester = zmq_socket(context, ZMQ_REQ);
    int rc = zmq_connect(requester, matlabAddress.c_str());
    if (rc != 0) {
        perror("zmq_connect failed");
        zmq_close(requester);
        zmq_ctx_destroy(context);
        return 1;
    }

    std::vector<int> fakeTRXControlPorts;
    std::vector<int> fakeTRXDataPorts;
    std::vector<int> trxconControlPorts;
    std::vector<int> trxconDataPorts;

    for (int n = 0; n < numArfcns; ++n) {
        fakeTRXControlPorts.push_back(params.fakeTrxBasePort + 2 * n + 1);
        fakeTRXDataPorts.push_back(params.fakeTrxBasePort + 2 * n + 2);
        trxconControlPorts.push_back(params.trxconBasePort + 2 * n + 1);
        trxconDataPorts.push_back(params.trxconBasePort + 2 * n + 2);
    }

    std::vector<std::thread> threads;

    for (int i = 0; i < numArfcns; ++i) {
        threads.push_back(std::thread(udp_recv_fakeTRX, fakeTRXControlPorts[i],
                                      publisher, "fakeTRX_control"));
        threads.push_back(std::thread(udp_recv_fakeTRX, fakeTRXDataPorts[i],
                                      publisher, "fakeTRX_data"));
        threads.push_back(std::thread(udp_listen_trxcon, trxconControlPorts[i],
                                      publisher, "trxcon_control"));
        threads.push_back(std::thread(udp_listen_trxcon, trxconDataPorts[i],
                                      publisher, "trxcon_data"));
    }

    std::thread zmq_to_udp(
        [&](std::vector<int> fakeTRXControlPorts,
            std::vector<int> fakeTRXDataPorts,
            std::vector<int> trxconControlPorts,
            std::vector<int> trxconDataPorts) {
            while (true) {
                zmq_msg_t message;
                zmq_msg_init(&message);
                zmq_recvmsg(subscriber, &message, 0);
                size_t message_size = zmq_msg_size(&message);
                char* message_data = (char*)zmq_msg_data(&message);
                std::string message_str(message_data, message_size);

                std::istringstream iss(message_str);
                std::string source;
                std::string data;
                std::getline(iss, source, ':');
                std::getline(iss, data);

                if (source == "trxcon_control") {
                    for (int i = 0; i < numArfcns; ++i) {
                        log_message("Sending to fakeTRX_control (port " +
                                    std::to_string(fakeTRXControlPorts[i]) +
                                    "): " + data);
                        udp_send(fakeTRXControlPorts[i], data.c_str(),
                                 data.size(), params.fakeTrxAddress);
                    }
                } else if (source == "trxcon_data") {
                    for (int i = 0; i < numArfcns; ++i) {
                        log_message("Sending to fakeTRX_data (port " +
                                    std::to_string(fakeTRXDataPorts[i]) +
                                    "): " + data);
                        udp_send(fakeTRXDataPorts[i], data.c_str(), data.size(),
                                 params.fakeTrxAddress);
                    }
                } else if (source == "fakeTRX_control") {
                    for (int i = 0; i < numArfcns; ++i) {
                        log_message("Sending to trxcon_control (port " +
                                    std::to_string(trxconControlPorts[i]) +
                                    "): " + data);
                        udp_send(trxconControlPorts[i], data.c_str(),
                                 data.size(), params.trxconAddress);
                    }
                } else if (source == "fakeTRX_data") {
                    for (int i = 0; i < numArfcns; ++i) {
                        log_message("Sending to trxcon_data (port " +
                                    std::to_string(trxconDataPorts[i]) +
                                    "): " + data);
                        udp_send(trxconDataPorts[i], data.c_str(), data.size(),
                                 params.trxconAddress);
                    }
                }

                zmq_msg_close(&message);
            }
        },
        fakeTRXControlPorts, fakeTRXDataPorts, trxconControlPorts,
        trxconDataPorts);
    zmq_to_udp.join();

    zmq_to_udp.join();

    for (auto& th : threads) {
        th.join();
    }
    log_message("Stopping bridge");

    zmq_close(publisher);
    zmq_close(subscriber);
    zmq_close(requester);
    zmq_ctx_destroy(context);

    return 0;
}