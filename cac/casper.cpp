#include "TaskGraph.h"
#include "KnowledgeBase.h"
#include "Platform.h"
#include "Options.h"
#include "Build.h"

#include "tune.h"

namespace {

void composeArgsFile(cac::TaskGraph &tg, cac::KnowledgeBase &db) {
	std::string argsFileName(tg.name + ".args");
	std::ofstream fout(argsFileName);
	if (!fout.is_open()) {
		std::ostringstream msg;
		msg << "failed to open args output file '"
			<< argsFileName << "': " << strerror(errno);
		throw std::runtime_error{msg.str()};
	}

	// The final application binary is linked using CMake; we (the metaprogram)
	// generate a file with some variable values that are known only by
	// running the metaprogram. CMake loads this file. The variables are:
	//   HALIDE_GENERATORS: names of Halide generators registere in metaprogram
	//   C_KERNEL_SOURCES: list of source files with kernels written in C
	//   NODE_TYPE_IDS: platform hardware description
	fout << "HALIDE_GENERATORS ";
	for (auto &task : tg.tasks) {
		if (task->type == cac::Task::Halide)
			fout << task->func;
	}
	fout << std::endl;

	fout << "NODE_TYPE_IDS ";
	for (auto &nodeType : db.getNodeTypes()) {
		fout << nodeType.id << " ";
	}
	fout << std::endl;
}

} // namespace anon

namespace cac {

void compile(TaskGraph &tg, const std::string &platformFile,
		// TODO: eventually, these will go away from here because they
		// will be generated by the compilation flow
		const std::string &modelFile, const std::string &modelCPFile,
		const std::string &candidatesFile) {

	KnowledgeBase db;
	db.loadPlatform(platformFile);
	cac::Platform plat{db.getNodeTypes()};

	composeArgsFile(tg, db);

	cac::introspectHalideTasks(tg);
	cac::tune(tg, db, modelFile, modelCPFile, candidatesFile);
	cac::compileHalideTasks(tg, plat, db);
	cac::emitLLVMIR(tg, plat, tg.name + ".ll");
}

int tryCompile(TaskGraph &tg, const std::string &platformFile,
		// TODO: eventually, these will go away from here because they
		// will be generated by the compilation flow
		const std::string &modelFile, const std::string &modelCPFile,
		const std::string &candidatesFile) {
	try {
		compile(tg, platformFile, modelFile, modelCPFile, candidatesFile);
		return 0;
	} catch (std::exception &exc) {
		std::cerr << "ERROR: compilation failed with exception: "
			<< exc.what() << std::endl;
		return 1;
	}
}

} // namespace cac
