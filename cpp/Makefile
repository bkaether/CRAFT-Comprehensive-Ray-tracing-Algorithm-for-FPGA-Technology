# Compiler settings
CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2
# Include directories
INCLUDES = -I./lib

# Target executable name
TARGET = main
# Base directory for object files and source files
BUILD_DIR = ./build
SRC_DIR = ./src

# Find all .cpp files in the SRC_DIR
SOURCES = $(shell find $(SRC_DIR) -type f -name '*.cpp')
# Generate a list of object files by replacing the source directory path and extension
OBJECTS = $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(SOURCES))

# Default target
all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $^

# Rule to compile .cpp to .o
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR) $(TARGET)

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
