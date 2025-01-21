CXX = g++
CXXFLAGS = -lzmq
TARGET = main
BUILD_DIR = ./build
SRC = main.cpp

all: $(BUILD_DIR) $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TARGET): $(SRC)
	$(CXX) $(SRC) -o $@ $(CXXFLAGS)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean