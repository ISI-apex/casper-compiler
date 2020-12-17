set(CASPER_COMPILER_LIB cac)

# Create a Casper executable (application)
# Arguments: app_target SOURCES source_file... HALIDE_GENERATORS gen1 ...
#   SOURCES: source files for the metaprogram, including Halide generators
#   C_KERNEL_SOURCES: source files with kernels written in C
#   BUILD_DIR: directory where to put the application binary (has a default)
#   EXTRA_PACKAGES: list of packages to pass to find_package in the nested
#                   cmake project (may be needed when EXTRA_LIBRARIES
#                   contains aliases like Package::foo)
#   EXTRA_LIBRARIES: list of libraries to link the target against
# Sets:
#   ${target}_BUILD_DIR: build directory that contains target executable
function(casper_add_exec target meta_prog)
	cmake_parse_arguments(FARG
		""
		"PLATFORM;INPUT_DESC;CANDIDATES;TUNED_PARAMS;EXTRA_PYTHONPATH"
		"SOURCES;C_KERNEL_SOURCES;EXTRA_INCLUDE_DIRS;EXTRA_PACKAGES;EXTRA_LIBRARIES;TRAIN_ARGS"
		${ARGN})

	set(SPEC_FILES
		${FARG_PLATFORM}
		${FARG_INPUT_DESC}
		${FARG_CANDIDATES}
		${FARG_TUNED_PARAMS}
	)
	foreach(spec_file ${SPEC_FILES})
		configure_file(${spec_file} ${spec_file} COPYONLY)
	endforeach()

	find_package(Threads)
	find_package(Python REQUIRED COMPONENTS Interpreter)

	## TODO: FindCasper.cmake (figure out if functions go into Find*.cmake),
	## then move these out of the function
	#find_program(LLC llc REQUIRED DOC "LLVM IR compiler")
	include_directories(${CAC_INCLUDE_DIRS})

	add_executable(${meta_prog} ${FARG_SOURCES})
	target_link_libraries(${meta_prog} LINK_PUBLIC ${CASPER_COMPILER_LIB})
	# Common across invocations of metaprogram (for harness and for app)
	set(META_PROG_ARGS
		--platform ${FARG_PLATFORM}
		--python-path "${CMAKE_CURRENT_SOURCE_DIR}:${CAC_PYAPI_DIR}:${CAC_PY_DIR}:${Python_SITELIB}:${FARG_EXTRA_PYTHONPATH}"
	)
	set(TARGET_OPTS
		C_KERNEL_SOURCES ${FARG_C_KERNEL_SOURCES}
		EXTRA_INCLUDE_DIRS ${FARG_EXTRA_INCLUDE_DIRS}
		EXTRA_PACKAGES ${FARG_EXTRA_PACKAGES}
		EXTRA_LIBRARIES ${FARG_EXTRA_LIBRARIES}
	)
	set(META_PROG_DEPS
		${FARG_PLATFORM}
	)

	# This is actually required in the automated stack (with profiling
	# harness, etc).
	if (FARG_CANDIDATES)
		set(META_PROG_ARGS ${META_PROG_ARGS}
			--candidates ${FARG_CANDIDATES})
		set(META_PROG_DEPS ${META_PROG_DEPS} ${FARG_CANDIDATES})
	endif ()

	## Run the meta-program to generate profiling harness
	#set(prof_harness ${target}_prof)
	#add_custom_command(
	#	OUTPUT
	#		${prof_harness}.ll
	#		${prof_harness}.args
	#		${target}.samples.csv
	#	COMMAND ${meta_prog} --profiling-harness
	#		--profiling-samples ${target}.samples.csv
	#		--profiling-measurements ${target}.meas.csv
	#		-o ${prof_harness}.ll
	#		--build-args ${prof_harness}.args
	#		${META_PROG_ARGS}
	#	DEPENDS ${meta_prog} ${META_PROG_DEPS})

	#create_nested_proj(${prof_harness} PROFILING_HARNESS ${TARGET_OPTS})
	#build_nested_proj(${prof_harness} PROF_HARNESS_BUILD_DIR)

	#add_custom_target(${target}.harness
	#	DEPENDS ${PROF_HARNESS_BUILD_DIR}/${prof_harness})

	#add_custom_command(OUTPUT ${target}.meas.csv
	#	COMMAND ${PROF_HARNESS_BUILD_DIR}/${prof_harness}
	#	DEPENDS ${PROF_HARNESS_BUILD_DIR}/${prof_harness})
	#add_custom_target(${target}.profile DEPENDS ${target}.meas.csv)

	## TODO: path to casper's python module (install the module in
	## site-packages)
	#set(CASPER_AUTOTUNER_PATH
	#	${CMAKE_CURRENT_BINARY_DIR}/../../../autotuner)

	## Train the model using the profiling measurements
	#find_package(Python REQUIRED COMPONENTS Interpreter)
	## Actual outputs are all contents of ${target}.models/ dir
	#add_custom_command(OUTPUT ${target}.models/timestamp
	#	COMMAND ${Python_EXECUTABLE}
	#		${CASPER_AUTOTUNER_PATH}/train.py ${FARG_TRAIN_ARGS}
	#			${target}.samples.csv ${target}.meas.csv
	#			${target}.models
	#	DEPENDS ${target}.meas.csv ${target}.samples.csv)
	#add_custom_target(${target}.train DEPENDS ${target}.models/timestamp)

	## Run the meta-program to generate main application binary
	# TODO: burn the EXTRA_PYTHONPATH into the metaprogram somehow
	add_custom_command(OUTPUT ${target}.ll ${target}.args
		COMMAND ${meta_prog} -o ${target}.ll
			--build-args ${target}.args
			#--models ${target}.models
			#--input ${FARG_INPUT_DESC}
			--tuned-params ${FARG_TUNED_PARAMS}
			${META_PROG_ARGS}
		# Actual deps are all contents of ${target}.models/ dir
		DEPENDS ${meta_prog} ${META_PROG_DEPS})
			#${target}.models/timestamp)
	add_custom_target(${target}.compile DEPENDS ${target}.ll)

	# TODO: investigate cmake's 'export' feature to help with
	# accessing targets defined by the nested project from parent
	create_nested_proj(${target} APP ${TARGET_OPTS})
	build_nested_proj(${target} TARGET_BUILD_DIR)

	# Note: for some reason naming this target '${target}' does not work
	add_custom_target(${target}.link ALL
		DEPENDS ${TARGET_BUILD_DIR}/${target})

	set(${target}_BUILD_DIR ${TARGET_BUILD_DIR} PARENT_SCOPE)
endfunction()

# Generate a separate (nested) CMake project that will link the
# application binary. We cannot link the app binary in this CMake
# instance, because we need information from the metaprogram run,
# which cannot be run during configure time, obviously.
# NOTE: can't pass CMAKE_MODULE_PATH via -D because ';' expands to ' '
function(create_nested_proj proj)
	file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${proj})
	file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${proj}/CMakeLists.txt
"
# DO NOT EDIT: this file is autogenerated by casper.cmake module
cmake_minimum_required(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
project(${prj} LANGUAGES CXX C)
set(CMAKE_MODULE_PATH  ${CMAKE_MODULE_PATH})
# Forward from parent project
set(CMAKE_CXX_STANDARD ${CMAKE_CXX_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ${CMAKE_CXX_STANDARD_REQUIRED})
set(CMAKE_CXX_EXTENSIONS ${CMAKE_CXX_EXTENSIONS})
include(casper)
casper_build(${proj} ${CMAKE_CURRENT_BINARY_DIR}/${proj}.args ${ARGN})
"
	)
endfunction()

function(build_nested_proj proj build_dir_var)
	set(build_dir build)
	set(${build_dir_var}  ${proj}/${build_dir} PARENT_SCOPE)
	file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${proj}/${build_dir})

	add_custom_command(OUTPUT ${proj}/${build_dir}/${proj}
		COMMAND ${CMAKE_COMMAND}
			-S "${CMAKE_CURRENT_BINARY_DIR}/${proj}"
			-B "${CMAKE_CURRENT_BINARY_DIR}/${proj}/${build_dir}"
			-DMETA_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
			-DMETA_BUILD_DIR="${CMAKE_CURRENT_BINARY_DIR}"
			-DCMAKE_C_COMPILER="${CMAKE_C_COMPILER}"
			-DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}"
		COMMAND ${CMAKE_COMMAND}
			--build "${CMAKE_CURRENT_BINARY_DIR}/${proj}/${build_dir}/"
			-- ${proj}
		DEPENDS ${proj}.ll)

	# TODO: this breaks the 'make' build. Investigate how to add custom clean
	# without adding the target to ALL, or fix target being in ALL.
	# Define this target only for the sake of hooking it up to clean
	# add_custom_target(nested-${proj} ALL
	#			DEPENDS ${proj}/${build_dir}/${proj})
	# set_target_properties(nested-${proj} PROPERTIES
	#			ADDITIONAL_CLEAN_FILES ${proj}) # clean the whole nested dir
endfunction()

# NOTE: This must be called from a separate nested invocation of CMake,
# distinct from the one that builds and runs the meta program; because
# the meta program generates a file (app_args_file) with information needed to
# link the app binary, and that file needs to be passed to this function.
function(casper_build target app_args_file)
	file(READ ${app_args_file} APP_VARS_FILE_CONTENT)
	separate_arguments(ARGS_FROM_FILE UNIX_COMMAND ${APP_VARS_FILE_CONTENT})
	cmake_parse_arguments(FARG
		"APP;PROFILING_HARNESS"
		""
		"C_KERNEL_SOURCES;HALIDE_TASK_LIBS;NODE_TYPE_IDS;EXTRA_INCLUDE_DIRS;EXTRA_PACKAGES;EXTRA_LIBRARIES"
		${ARGS_FROM_FILE} ${ARGN})

	find_program(LLC llc REQUIRED DOC "LLVM IR compiler")
	find_package(Threads)

	foreach (pkg ${FARG_EXTRA_PACKAGES})
		find_package(${pkg})
	endforeach()

	if (${FARG_PROFILING_HARNESS})
		set(rtlib casper_runtime_prof)
	elseif(${FARG_APP})
		set(rtlib casper_runtime)
	else()
		message(FATAL_ERROR "Neither APP nor PROFILING_HARNESS given")
	endif()
	# Will find Casper lib in /usr/lib when Casper is installed into the
	# system, otherwise can set a variable (propagated by invocation of the
	# metaprogram CMake instance), otherwise the app is in Casper source
	# tree in apps/X/
	find_library(CASPER_RUNTIME_LIBRARY ${rtlib} REQUIRED
	    PATHS ${CASPER_LIBRARIES_PATH}
		${META_BUILD_DIR}/../../runtime
		${META_BUILD_DIR}/../../../runtime)

	# Compile the target harness
	add_custom_command(OUTPUT ${target}.o
		COMMAND ${LLC} -filetype=obj
			-o ${target}.o ${META_BUILD_DIR}/${target}.ll)

	# Locate (or compile) the kernel libraries

	# Compile C Kernels (one library for all variants of all kernels).
	# TODO: implement variants using a macro that wraps a kernel function
	# and expand to multiple definitions, one per variant.
	foreach(c_src_file ${FARG_C_KERNEL_SOURCES})
	    list(APPEND c_src_files ${META_SOURCE_DIR}/${c_src_file})
	endforeach()
	if (c_src_files)
		set(lib ${target}_kern_c)
		add_library(${lib} ${c_src_files})
		target_include_directories(${lib}
			PUBLIC ${FARG_EXTRA_INCLUDE_DIRS})
		target_link_libraries(${lib} ${FARG_EXTRA_LIBRARIES})
		list(APPEND kernel_libs ${lib})
	endif ()

	# Halide libraries that were compiled by the metaprogram when it ran
	foreach(halide_lib ${FARG_HALIDE_TASK_LIBS})
		list(APPEND kernel_libs ${META_BUILD_DIR}/${halide_lib})
	endforeach()

	# Link the application binary
	add_executable(${target} ${CMAKE_CURRENT_BINARY_DIR}/${target}.o)
	target_include_directories(${target}
		PUBLIC ${FARG_EXTRA_INCLUDE_DIRS})
	target_link_libraries(${target} ${kernel_libs} ${CASPER_RUNTIME_LIBRARY}
		${FARG_EXTRA_LIBRARIES}
		Threads::Threads ${CMAKE_DL_LIBS})
	set_target_properties(${target} PROPERTIES LINKER_LANGUAGE CXX)
endfunction()
