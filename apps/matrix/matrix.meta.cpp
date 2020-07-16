#include "casper.h"

#include <vector>

using namespace cac;

int main(int argc, char **argv) {
	TaskGraph tg;

	std::vector<double> matValsA {
		1.000000e+00, -2.000000e+00, 3.000000e+00, 4.000000e+00,
		3.000000e+00, 4.000000e+00, 5.000000e+00, -6.000000e+00,
		5.000000e+00, -6.000000e+00, 4.000000e+00, 5.000000e+00,
		-2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00,
		3.000000e+00, 4.000000e+00, 5.000000e+00, -6.000000e+00,
		5.000000e+00, -6.000000e+00, 4.000000e+00, 5.000000e+00,
	};
	Dat *matA = &tg.createDat(6, 4, matValsA);

	std::vector<double> matValsB {
		1.000000e+00, -2.000000e+00, 3.000000e+00, 4.000000e+00,
		3.000000e+00, 4.000000e+00, 5.000000e+00, -6.000000e+00,
		8.000000e+00, 3.000000e+00, -1.000000e+00, -5.000000e+00,
		-2.000000e+00, 3.000000e+00, 4.000000e+00, 5.000000e+00,
		5.000000e+00, -6.000000e+00, 4.000000e+00, 5.000000e+00,
		9.000000e+00, -6.000000e+00, -4.000000e+00, 2.000000e+00,
	};
	Dat* matB = &tg.createDat(6, 4, matValsB);

	Task& task_inv = tg.createTask(CKernel("mat_invert"), {matA});
	Task& task_abs = tg.createTask(CKernel("mat_abs"), {matB});

	Task& task_add = tg.createTask(CKernel("mat_add"), {matA, matB},
			{&task_inv, &task_abs});

	Dat *matC = &tg.createDat(6, 4);
	Scalar *offset = &tg.createIntScalar(/* width */ 8, 2);
	Task& task_bright = tg.createTask(HalideKernel("halide_bright"),
			{offset, matA, matC}, {&task_add});

	Dat* matD = &tg.createDat(6 - 2, 4 - 2);
	Task& task_blur = tg.createTask(HalideKernel("halide_blur"),
			{matC, matD}, {});

	Executable exec(tg);
	return exec.emitLLVMIR(); // to stderr
}