#include <stdint.h>

extern "C" {

uint32_t get_node_type_id() {
	return 1; // TODO read /proc/cpuinfo etc
}

} // extern C