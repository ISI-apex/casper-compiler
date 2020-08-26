set(CASPER_COMPILER_LIB cac)

# Create a Casper executable (application)
# Arguments: app_target SOURCES source_file... HALIDE_GENERATORS gen1 ...
#   SOURCES: source files for the metaprogram, including Halide generators
#   C_KERNEL_SOURCES: source files with kernels written in C
#   BUILD_DIR: directory where to put the application binary (has a default)
function(casper_add_exec target meta_prog)
	cmake_parse_arguments(FARG
		""
		"BUILD_DIR"
		"SOURCES;C_KERNEL_SOURCES"
		${ARGN})

	if (NOT ${FARG_BUILD_DIR})
		set(FARG_BUILD_DIR "target")
	endif()

	find_package(Threads)

	## TODO: FindCasper.cmake (figure out if functions go into Find*.cmake),
	## then move these out of the function
	#find_program(LLC llc REQUIRED DOC "LLVM IR compiler")
	include_directories(${CAC_INCLUDE_DIRS})

	add_executable(${meta_prog} ${FARG_SOURCES})
	target_link_libraries(${meta_prog} LINK_PUBLIC ${CASPER_COMPILER_LIB})

	## Run the meta-program
	add_custom_command(OUTPUT ${target}.ll ${target}.args
		COMMAND ${meta_prog}
		DEPENDS ${meta_prog})

	# Generate a separate (nested) CMake project that will link the
	# application binary. We cannot link the app binary in this CMake
	# instance, because we need information from the metaprogram run,
	# which cannot be run during configure time, obviously.
	# NOTE: can't pass CMAKE_MODULE_PATH via -D because ';' expands to ' '
	file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/CMakeLists.txt
		"
		# DO NOT EDIT: this file is autogenerated by casper.cmake module
		cmake_minimum_required(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
		project(${target} LANGUAGES CXX C)
		set(CMAKE_MODULE_PATH  ${CMAKE_MODULE_PATH})
		include(casper)
		casper_app(${target} ${target}.args
			C_KERNEL_SOURCES ${FARG_C_KERNEL_SOURCES})
		"
	)
	add_custom_command(OUTPUT ${FARG_BUILD_DIR}/${target}
		COMMAND ${CMAKE_COMMAND}
			-S "${CMAKE_CURRENT_BINARY_DIR}"
			-B "${CMAKE_CURRENT_BINARY_DIR}/${FARG_BUILD_DIR}"
			-DMETA_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
			-DMETA_BUILD_DIR="${CMAKE_CURRENT_BINARY_DIR}"
			-DCMAKE_C_COMPILER="${CMAKE_C_COMPILER}"
			-DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}"
		COMMAND ${CMAKE_COMMAND}
			--build "${CMAKE_CURRENT_BINARY_DIR}/${FARG_BUILD_DIR}"
		DEPENDS ${target}.ll)
	add_custom_target(${target} ALL
		DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${FARG_BUILD_DIR}/${target})
	set_target_properties(${target} PROPERTIES
		ADDITIONAL_CLEAN_FILES ${FARG_BUILD_DIR})
endfunction()

# NOTE: This must be called from a separate nested invocation of CMake,
# distinct from the one that builds and runs the meta program; because
# the meta program generates a file (app_args_file) with information needed to
# link the app binary, and that file needs to be passed to this function.
function(casper_app target app_args_file)
	file(READ ${app_args_file} APP_VARS_FILE_CONTENT)
	separate_arguments(ARGS_FROM_FILE UNIX_COMMAND ${APP_VARS_FILE_CONTENT})
	cmake_parse_arguments(FARG
		""
		""
		"C_KERNEL_SOURCES;HALIDE_GENERATORS;NODE_TYPE_IDS"
		${ARGS_FROM_FILE} ${ARGN})

	find_program(LLC llc REQUIRED DOC "LLVM IR compiler")
	find_package(Threads)

	# Will find Casper lib in /usr/lib when Casper is installed into the
	# system, otherwise can set a variable (propagated by invocation of the
	# metaprogram CMake instance), otherwise the app is in Casper source
	# tree in apps/X/
	find_library(CASPER_RUNTIME_LIBRARY casper_runtime REQUIRED
	    PATHS ${CASPER_LIBRARIES_PATH} ${META_BUILD_DIR}/../../cac/runtime)

	# Compile the target harness
	add_custom_command(OUTPUT ${target}.o
		COMMAND ${LLC} -filetype=obj
			-o ${target}.o ${META_BUILD_DIR}/${target}.ll)

	# Locate (or compile) the kernel libraries

	# Compile C Kernels (one library for all variants of all kernels).
	# TODO: implement variants using a macro that wraps a kernel function
	# and expand to multiple definitions, one per variant.
	set(lib ${target}_kern_c)
	foreach(c_src_file ${FARG_C_KERNEL_SOURCES})
		#message(FATAL_ERROR meta src ${META_SOURCE_DIR}/${c_src_file})
	    list(APPEND c_src_files ${META_SOURCE_DIR}/${c_src_file})
	endforeach()
	add_library(${lib} ${c_src_files})
	list(APPEND kernel_libs ${lib})

	# Halide libraries that were compiled by the metaprogram when it ran
	foreach(gen ${FARG_HALIDE_GENERATORS})
		foreach(node_type_id ${FARG_NODE_TYPE_IDS})
		# naming convention contract with makeHalideArtifactName() in build.cpp
		list(APPEND kernel_libs ${META_BUILD_DIR}/lib${gen}_v${node_type_id}.a)
	    endforeach()
	endforeach()

	list(APPEND kernel_libs ${META_BUILD_DIR}/libhalide_runtime.a)

	# Link the application binary
	add_executable(${target} ${CMAKE_CURRENT_BINARY_DIR}/${target}.o)
	target_link_libraries(${target} ${kernel_libs} ${CASPER_RUNTIME_LIBRARY}
	    Threads::Threads ${CMAKE_DL_LIBS})
	set_target_properties(${target} PROPERTIES LINKER_LANGUAGE CXX)
endfunction()
