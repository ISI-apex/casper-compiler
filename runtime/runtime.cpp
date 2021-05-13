#include "platform.h"

extern "C" {

void _crt_init() {
	_crt_plat_init();
}

void _crt_finalize() {
	_crt_plat_finalize();
}

} // extern
