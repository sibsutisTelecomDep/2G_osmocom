#include <netinet/ip.h>   // Для структуры IP
#include <netinet/udp.h>  // Для структуры UDP
#include <pcap.h>

#include <cctype>   // Для std::isprint
#include <iomanip>  // Для std::hex и std::setw
#include <iostream>
#include <string>
#include <zmq.hpp>

void printPayload(const u_char *packet, int length) {
    // Ethernet заголовок: 14 байт
    const struct ip *ip_header =
        (struct ip *)(packet + 14);  // Пропускаем Ethernet заголовок
    int ip_header_length = ip_header->ip_hl * 4;  // Длина IP заголовка в байтах
    const struct udphdr *udp_header =
        (struct udphdr *)(packet + 14 +
                          ip_header_length);  // Пропускаем IP заголовок
    int udp_header_length =
        sizeof(struct udphdr);  // Длина UDP заголовка в байтах
    const u_char *payload =
        packet + 14 + ip_header_length +
        udp_header_length;  // Указатель на полезную нагрузку
    int payload_length =
        length -
        (14 + ip_header_length + udp_header_length);  // Длина полезной нагрузки

    std::cout << "Captured packet length: " << length << " bytes" << std::endl;
    std::cout << "Payload length: " << payload_length << " bytes" << std::endl;
    std::cout << "Payload data (hex): ";

    for (int i = 0; i < payload_length && i < 16; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0')
                  << (int)payload[i] << " ";
    }
    std::cout << std::dec << std::endl;  // Сброс формата на десятичный

    // Вывод полезной нагрузки в текстовом формате
    std::cout << "Payload data (text): ";
    for (int i = 0; i < payload_length; ++i) {
        if (std::isprint(payload[i])) {
            std::cout << (char)payload[i];  // Печатаем символ, если он печатный
        } else {
            std::cout << '.';  // Заменяем непечатные символы на точку
        }
    }
    std::cout << std::endl;  // Переход на новую строку
}

void packetHandler(u_char *args, const struct pcap_pkthdr *header,
                   const u_char *packet) {
    zmq::socket_t *socket = reinterpret_cast<zmq::socket_t *>(args);

    // Отправка пакета через ZeroMQ
    zmq::message_t message(header->len);
    memcpy(message.data(), packet, header->len);
    socket->send(message, zmq::send_flags::none);

    // Вывод информации о полезной нагрузке в консоль
    printPayload(packet, header->len);
}
int main(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <interface> <zmq_address>"
                  << std::endl;
        return 1;
    }

    const char *interface = argv[1];
    const char *zmq_address = argv[2];

    // Инициализация ZeroMQ
    zmq::context_t context(1);
    zmq::socket_t socket(context, ZMQ_PUSH);
    socket.bind(zmq_address);

    // Инициализация pcap
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_if_t *alldevs, *device;

    if (pcap_findalldevs(&alldevs, errbuf) == -1) {
        std::cerr << "Error finding devices: " << errbuf << std::endl;
        return 1;
    }

    // Поиск нужного интерфейса
    for (device = alldevs; device != nullptr; device = device->next) {
        if (device->name == std::string(interface)) {
            break;
        }
    }

    if (device == nullptr) {
        std::cerr << "Device not found: " << interface << std::endl;
        pcap_freealldevs(alldevs);
        return 1;
    }

    // Открытие устройства для захвата пакетов
    pcap_t *handle = pcap_open_live(device->name, 65535, 1, 1000, errbuf);
    if (handle == nullptr) {
        std::cerr << "Error opening device: " << errbuf << std::endl;
        pcap_freealldevs(alldevs);
        return 1;
    }

    // Установка фильтра для захвата только UDP-пакетов
    struct bpf_program filter;
    const char *filter_exp = "udp";  // Фильтр для UDP
    if (pcap_compile(handle, &filter, filter_exp, 0, PCAP_NETMASK_UNKNOWN) ==
        -1) {
        std::cerr << "Error compiling filter: " << pcap_geterr(handle)
                  << std::endl;
        pcap_freealldevs(alldevs);
        return 1;
    }
    if (pcap_setfilter(handle, &filter) == -1) {
        std::cerr << "Error setting filter: " << pcap_geterr(handle)
                  << std::endl;
        pcap_freealldevs(alldevs);
        return 1;
    }

    // Захват пакетов
    pcap_loop(handle, 0, packetHandler, reinterpret_cast<u_char *>(&socket));

    // Освобождение ресурсов
    pcap_freealldevs(alldevs);
    pcap_close(handle);
    return 0;
}
