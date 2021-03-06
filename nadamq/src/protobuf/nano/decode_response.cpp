#include <iostream>
#include <fstream>
#include <string>
#include <stdio.h>
#include <pb_decode.h>
#include "simple.pb.h"
using namespace std;


// Main function:  Reads the entire address book from a file and prints all
//   the information inside.
int main(int argc, char* argv[]) {
  uint8_t buffer[256];

  if (argc != 2) {
    cerr << "Usage:  " << argv[0] << " <input file>" << endl;
    return -1;
  }

  std::ifstream ifs(argv[1]);
  std::string data((std::istreambuf_iterator<char>(ifs)),
                   std::istreambuf_iterator<char>());
  bool status = false;
  /* Create a stream that will write to our buffer. */
  pb_istream_t stream = pb_istream_from_buffer((uint8_t *)data.c_str(),
                                               data.size());

  CommandResponse response;
  status = pb_decode(&stream, CommandResponse_fields, &response);
  if (!status) {
    cerr << "Decoding error." << endl;
    return -1;
  }
  cout << "status: " << status << endl;
  switch (response.type) {
    case CommandType_ECHO:
      cout << "Echo response" << endl;
      break;
    case CommandType_RAM_SIZE:
      cout << "RAMSize response" << endl;
      cout << response.ram_size.result << endl;
      break;
    case CommandType_RAM_DATA_SIZE:
      cout << "RAMDataSize response" << endl;
      cout << response.ram_data_size.result << endl;
      break;
    case CommandType_RAM_BSS_SIZE:
      cout << "RAMBSSSize response" << endl;
      cout << response.ram_bss_size.result << endl;
      break;
    case CommandType_RAM_HEAP_SIZE:
      cout << "RAMHeapSize response" << endl;
      cout << response.ram_heap_size.result << endl;
      break;
    case CommandType_RAM_STACK_SIZE:
      cout << "RAMStackSize response" << endl;
      cout << response.ram_stack_size.result << endl;
      break;
    case CommandType_RAM_FREE:
      cout << "RAMFree response" << endl;
      cout << response.ram_free.result << endl;
      break;
    default:
      break;
  }
  return 0;
}
