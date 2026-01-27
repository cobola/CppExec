#include <iostream>
#include <cstdlib>

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <num1> <num2>" << std::endl;
        return 1;
    }

    char* end1;
    char* end2;
    double num1 = std::strtod(argv[1], &end1);
    double num2 = std::strtod(argv[2], &end2);

    if (*end1 != '\0' || *end2 != '\0') {
        std::cerr << "Error: Invalid number format" << std::endl;
        return 1;
    }

    std::cout << num1 + num2 << std::endl;
    return 0;
}
