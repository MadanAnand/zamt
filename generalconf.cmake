# global configuration

if(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
  set(CMAKE_AR gcc-ar)
  set(CMAKE_RANLIB gcc-ranlib)
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
  set(CMAKE_AR llvm-ar)
  set(CMAKE_RANLIB llvm-ranlib)
endif()


# per target configuration

function(SetupTarget target_name target_modules)
  foreach(mod ${target_modules})
    target_include_directories(${target_name} PRIVATE ${mod}/include)
    string(TOUPPER ${mod} modupper)
    target_compile_definitions(${target_name} PRIVATE ZAMT_MODULE_${modupper})
  endforeach(mod)
  set_property(TARGET ${target_name} PROPERTY CXX_STANDARD 11)
  if(MSVC)
    target_compile_options(${target_name} PRIVATE /W3 /WX)
    target_compile_options(${target_name} PRIVATE $<$<CONFIG:Debug>:/RTC>)
    target_compile_options(${target_name} PRIVATE $<$<CONFIG:Release>:/GL>)
    set_target_properties(${target_name} PROPERTIES LINK_FLAGS_RELEASE "/LTCG")
  else()
    target_compile_options(${target_name} PRIVATE -Wall -pedantic -Wextra -Wconversion -Werror)
    target_compile_options(${target_name} PRIVATE $<$<CONFIG:Debug>:-fsanitize=address>)
    # TODO: remove this if llvm-3.8 or later has LLVMgold.so again
    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
      target_compile_options(${target_name} PRIVATE $<$<CONFIG:Release>:-flto>)
      target_compile_options(${target_name} PRIVATE $<$<CONFIG:RelWithDebInfo>:-flto>)
      target_compile_options(${target_name} PRIVATE $<$<CONFIG:RelWithDebInfo>:-pg>)
    endif()
    set_target_properties(${target_name} PROPERTIES LINK_FLAGS_DEBUG "-fsanitize=address")
    # TODO: remove this if llvm-3.8 or later has LLVMgold.so again
    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
      set_target_properties(${target_name} PROPERTIES LINK_FLAGS_RELEASE "-flto")
      set_target_properties(${target_name} PROPERTIES LINK_FLAGS_RELWITHDEBINFO "-flto -pg")
    endif()
  endif()
endfunction(SetupTarget)

function(LinkTarget target_name libs)
  target_link_libraries(${target_name} ${libs})
  if(Threads_FOUND)
    target_link_libraries(${target_name} ${CMAKE_THREAD_LIBS_INIT})
  endif()
endfunction(LinkTarget)

function(CollectSources target_modules)
  unset(all_cpp_sources)
  unset(extra_includes)
  unset(extra_libs)
  foreach(mod ${target_modules})
    include(${mod}/sources.cmake)
    unset(cpp_sources)
    foreach(cpp ${module_cpps})
      set(cpp_sources ${cpp_sources} ${mod}/src/${cpp})
    endforeach(cpp)
    set(all_cpp_sources ${all_cpp_sources} ${cpp_sources})
    source_group(${mod} FILES ${cpp_sources})
    set(extra_includes ${extra_includes} ${module_includes})
    set(extra_libs ${extra_libs} ${module_libs})
  endforeach(mod)
  set(collected_sources ${all_cpp_sources} PARENT_SCOPE)
  set(collected_includes ${extra_includes} PARENT_SCOPE)
  set(collected_libs ${extra_libs} PARENT_SCOPE)
endfunction(CollectSources)

function(AddExe target_name target_modules)
  CollectSources("${target_modules}")
  add_executable(${target_name} ${collected_sources})
  SetupTarget(${target_name} "${target_modules}")
  target_include_directories(${target_name} SYSTEM PRIVATE ${collected_includes})
  LinkTarget(${target_name} "${collected_libs}")
endfunction(AddExe)

function(AddLib target_name target_modules)
  CollectSources("${target_modules}")
  add_library(${target_name} STATIC ${collected_sources})
  SetupTarget(${target_name} "${target_modules}")
  target_include_directories(${target_name} SYSTEM PRIVATE ${collected_includes})
endfunction(AddLib)

function(SetTestMode target_name)
  target_compile_definitions(${target_name} PRIVATE ZAMT_TEST)
  target_compile_definitions(${target_name} PRIVATE TEST)
endfunction(SetTestMode)

function(AddTest test_name test_module other_modules test_sources)
  unset(cpp_sources)
  foreach(cpp ${test_sources})
    set(cpp_sources ${cpp_sources} ${test_module}/test/${cpp})
  endforeach(cpp)
  source_group(${test_module} FILES ${cpp_sources})
  add_executable(${test_name} ${cpp_sources})
  set(used_modules ${test_module} ${other_nodules})
  CollectSources("${used_modules}")
  SetupTarget(${test_name} "${used_modules}")
  SetTestMode(${test_name})
  target_include_directories(${test_name} SYSTEM PRIVATE ${collected_includes})
  target_link_libraries(${test_name} zamtlib)
  LinkTarget(${test_name} "${collected_libs}")
  add_test(NAME ${test_name} COMMAND ${test_name})
endfunction(AddTest)

function(AddAllTests tested_modules)
  AddLib(zamtlib "${tested_modules}")
  SetTestMode(zamtlib)
  foreach(mod ${tested_modules})
    include(${mod}/tests.cmake)
  endforeach(mod)
endfunction(AddAllTests)

