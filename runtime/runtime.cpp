#include <mpi.h>

#include "platform.h"

extern "C" {

static int rank = 0;
static int numprocs = 0;

static int argc = 0;
static char **argv = NULL;

void _crt_init() {
	_crt_plat_init();

	MPI_Init(&argc, &argv);
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);
	MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
}

void _crt_finalize() {
	MPI_Finalize();

	_crt_plat_finalize();
}

} // extern
