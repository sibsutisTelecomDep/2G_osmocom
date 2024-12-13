#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <pcap.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cctype>
#include <functional>
#include <iomanip>
#include <iostream>
#include <string>
#include <thread>
#include <unordered_map>
#include <zmq.hpp>

void sendToMatlab(const u_char *payload, int payload_length, const char *ip,
                  int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "Socket creation error!" << std::endl;
        return;
    }

    struct sockaddr_in server_address;
    memset(&server_address, 0, sizeof(server_address));
    server_address.sin_family = AF_INET;
    server_address.sin_port = htons(port);
    if (inet_pton(AF_INET, ip, &server_address.sin_addr) <= 0) {
        std::cerr << "Invalid address or Address not supported!" << std::endl;
        close(sock);
        return;
    }

    if (connect(sock, (struct sockaddr *)&server_address,
                sizeof(server_address)) < 0) {
        std::cerr << "Connection to Matlab failed!" << std::endl;
        close(sock);
        return;
    }

    // Отправляем полезную нагрузку
    send(sock, payload, payload_length, 0);
    std::cout << "Payload sent to Matlab!" << std::endl;

    close(sock);
}

void printPayload(const u_char *packet, int length,
                  const char *matlab_ip = nullptr, int matlab_port = 0) {
    const struct ip *ip_header =
        (struct ip *)(packet + 14);  // Пропускаем Ethernet заголовок
    int ip_header_length = ip_header->ip_hl * 4;  // Длина IP заголовка в байтах
    const struct udphdr *udp_header =
        (struct udphdr *)(packet + 14 + ip_header_length);
    int udp_header_length = sizeof(struct udphdr);  // Длина UDP заголовка
    const u_char *payload = packet + 14 + ip_header_length + udp_header_length;
    int payload_length = length - (14 + ip_header_length + udp_header_length);

    std::cout << "Captured packet length: " << length << " bytes" << std::endl;
    std::cout << "Payload length: " << payload_length << " bytes" << std::endl;

    std::cout << "Payload data (hex): ";
    for (int i = 0; i < payload_length && i < 16; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0')
                  << (int)payload[i] << " ";
    }
    std::cout << std::dec << std::endl;

    if (matlab_ip && matlab_port > 0) {
        // Отправляем данные в Matlab
        sendToMatlab(payload, payload_length, matlab_ip, matlab_port);
    }

    std::cout << "Payload data (text): ";
    for (int i = 0; i < payload_length; ++i) {
        if (std::isprint(payload[i])) {
            std::cout << (char)payload[i];
        } else {
            std::cout << '.';
        }
    }
    std::cout << std::endl;
}

void packetReceiver(zmq::socket_t &receiver, zmq::socket_t &sender,
                    const char *matlab_ip = nullptr, int matlab_port = 0) {
    while (true) {
        zmq::message_t message;
        if (receiver.recv(message, zmq::recv_flags::none)) {
            std::cout << "Received packet of size: " << message.size()
                      << " bytes" << std::endl;

            const u_char *packet =
                reinterpret_cast<const u_char *>(message.data());
            printPayload(packet, message.size(), matlab_ip, matlab_port);

            sender.send(message, zmq::send_flags::none);
        }
    }
}

void packetCapturer(const char *interface, zmq::socket_t &sender) {
    char errbuf[PCAP_ERRBUF_SIZE];

    pcap_t *handle = pcap_open_live(interface, 65535, 1, 1000, errbuf);
    if (handle == nullptr) {
        std::cerr << "Error opening device: " << errbuf << std::endl;
        return;
    }

    struct bpf_program filter;
    const char *filter_exp = "udp";  // Фильтр для UDP
    if (pcap_compile(handle, &filter, filter_exp, 0, PCAP_NETMASK_UNKNOWN) ==
        -1) {
        std::cerr << "Error compiling filter: " << pcap_geterr(handle)
                  << std::endl;
        pcap_close(handle);
        return;
    }
    if (pcap_setfilter(handle, &filter) == -1) {
        std::cerr << "Error setting filter: " << pcap_geterr(handle)
                  << std::endl;
        pcap_close(handle);
        return;
    }

    pcap_loop(
        handle, 0,
        [](u_char *args, const struct pcap_pkthdr *header,
           const u_char *packet) {
            zmq::socket_t *sender = reinterpret_cast<zmq::socket_t *>(args);
            zmq::message_t message(header->len);
            memcpy(message.data(), packet, header->len);
            sender->send(message, zmq::send_flags::none);
        },
        reinterpret_cast<u_char *>(&sender));

    pcap_close(handle);
}

void packetModifier(zmq::socket_t &receiver, zmq::socket_t &sender,
                    std::function<void(u_char *, size_t)> modifyCallback) {
    while (true) {
        zmq::message_t message;
        if (receiver.recv(message, zmq::recv_flags::none)) {
            // Модификация пакета
            u_char *data = reinterpret_cast<u_char *>(message.data());
            size_t size = message.size();
            modifyCallback(data, size);

            sender.send(message, zmq::send_flags::none);
        }
    }
}

void statisticsCollector(zmq::socket_t &receiver) {
    std::unordered_map<std::string, int> stats;
    while (true) {
        zmq::message_t message;
        if (receiver.recv(message, zmq::recv_flags::none)) {
            const u_char *packet =
                reinterpret_cast<const u_char *>(message.data());
            const struct ip *ip_header = (struct ip *)(packet + 14);
            std::string src_ip = inet_ntoa(ip_header->ip_src);
            stats[src_ip]++;

            std::cout << "Packet statistics from " << src_ip << ": "
                      << stats[src_ip] << " packets" << std::endl;
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc < 5) {
        std::cerr << "Usage: " << argv[0]
                  << " <interface> <recv_zmq_address> <send_zmq_address> "
                     "<mode> [<additional_args>]"
                  << std::endl;
        return 1;
    }

    const char *interface = argv[1];
    const char *recv_zmq_address = argv[2];
    const char *send_zmq_address = argv[3];
    std::string mode = argv[4];

    zmq::context_t context(1);
    zmq::socket_t receiver(context, ZMQ_PULL);
    zmq::socket_t sender(context, ZMQ_PUSH);

    if (mode == "receive") {
        receiver.bind(recv_zmq_address);
        sender.connect(send_zmq_address);
        packetReceiver(receiver, sender);
    } else if (mode == "capture") {
        sender.connect(send_zmq_address);
        packetCapturer(interface, sender);
    } else if (mode == "modify") {
        if (argc < 6) {
            std::cerr << "Missing modify callback argument." << std::endl;
            return 1;
        }
        receiver.bind(recv_zmq_address);
        sender.connect(send_zmq_address);
        packetModifier(receiver, sender, [](u_char *data, size_t size) {
            // Пример модификации:
            if (size > 20) data[20] = 0xFF;
        });
    } else if (mode == "stats") {
        receiver.bind(recv_zmq_address);
        statisticsCollector(receiver);
    } else if (mode == "matlab") {
        if (argc < 7) {
            std::cerr << "Usage for Matlab mode: <matlab_ip> <matlab_port>"
                      << std::endl;
            return 1;
        }
        const char *matlab_ip = argv[5];
        int matlab_port = std::stoi(argv[6]);
        receiver.bind(recv_zmq_address);
        sender.connect(send_zmq_address);
        packetReceiver(receiver, sender, matlab_ip, matlab_port);
    } else {
        std::cerr << "Unknown mode: " << mode << std::endl;
        return 1;
    }

    return 0;
}
