add_subdirectory(include)

# TODO: make Halide optional (some apps may not have any Halide kernels)
# Note: assuming Halide's private headres are in usr/include/Halide
# Halide's private headers needed to invoke generators from Casper.
find_package(Halide REQUIRED)
find_package(Boost REQUIRED COMPONENTS program_options)
find_package(Python COMPONENTS Development REQUIRED)

set(LLVM_LINK_COMPONENTS
  Support
  )

#get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)
#get_property(translation_libs GLOBAL PROPERTY MLIR_TRANSLATION_LIBS)

set(LLVM_TARGET_DEFINITIONS mlir/ToyCombine.td)
mlir_tablegen(ToyCombine.inc -gen-rewriters)
add_public_tablegen_target(ToyCh5CombineIncGen)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include/)
add_compile_options(-Wall)

add_llvm_library(cac
  build.cpp
  casper.cpp
  halide.cpp
  ini.cpp
  mlir.cpp
  python.cpp
  #tune.cpp # integration with KB disabled for now
  InputDesc.cpp
  KnowledgeBase.cpp
  Options.cpp
  Platform.cpp
  TaskGraph.cpp
  TaskGraphImpl.cpp
  parser/AST.cpp
  mlir/BuildHelpers.cpp
  mlir/MLIRGen.cpp
  mlir/Dialect.cpp
  mlir/LowerToAffineLoops.cpp
  mlir/LowerToLLVM.cpp
  mlir/ShapeInferencePass.cpp
  mlir/ToyCombine.cpp

  DEPENDS
  ToyCh5ShapeInferenceInterfaceIncGen
  ToyCh5OpsIncGen
  ToyCh5CombineIncGen

  SHARED
)
include_directories(include/)
llvm_update_compile_flags(cac)
target_link_libraries(cac
  PRIVATE
  ${dialect_libs}
  ${translation_libs}
  MLIRAffineToStandard
  MLIRAnalysis
  MLIRCallInterfaces
  MLIRExecutionEngine
  MLIRIR
  MLIRLLVMIR
  MLIRParser
  MLIRPass
  MLIRSideEffectInterfaces
  MLIRSCFToStandard
  MLIRStandardToLLVM
  MLIRSupport
  MLIRTargetLLVMIR
  MLIRTransforms

  PUBLIC
  Halide::Halide
  Boost::program_options
  ${Python_LIBRARIES}
  #knowbase
  )

target_include_directories(cac PRIVATE ${Python_INCLUDE_DIRS})
target_link_directories(cac PRIVATE ${Python_LIBRARY_DIRS})

mlir_check_link_libraries(cac)

# We have to add the paths to all the dependencies to RPATH (it actually
# ends up in RUNPATH), otherwise apps fail to link against libcac.
# TODO: There has to be a better way.  At least, why doesn't setting
# INSTALL_RPATH_USE_LINK_PATH add the dirs for the deps?
get_target_property(CAC_INSTALL_RPATH cac INSTALL_RPATH)
#get_target_property(KNOWBASE_DIR knowbase BINARY_DIR)
set_target_properties(cac PROPERTIES
  INSTALL_RPATH "${CAC_INSTALL_RPATH}:${KNOWBASE_DIR}")
# Does not add knowbase's path to RPATH/RUNPATH:
# set_target_properties(cac PROPERTIES INSTALL_RPATH_USE_LINK_PATH ON)
