#pragma once

#include <string>

namespace cac {

class TaskGraph;
class KnowledgeBase;

// TODO: the files will go away (they should be per kernel, and
// will be generated by the compilation flow)
int tune(TaskGraph &tg, KnowledgeBase &db,
		const std::string &modelFile, const std::string &modelCPFile,
	    const std::string &candidatesFile);

} // namespace cac;
