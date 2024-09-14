#############################################################################
# $Id: CMake.NCBIpkg.codegen.cmake 668504 2023-06-06 18:39:12Z gouriano $
#############################################################################
#############################################################################
##
##  NCBI C++ Toolkit Conan package code generation helper
##    Author: Andrei Gourianov, gouriano@ncbi
##


##############################################################################
# Find datatool app
if(NOT DEFINED NCBI_DATATOOL)
    if(NOT DEFINED NCBITK_TREE_ROOT)
        set(NCBI_PKG_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../..")
    else()
        set(NCBI_PKG_ROOT "${NCBITK_TREE_ROOT}")
    endif()
    if(EXISTS "${NCBI_PKG_ROOT}/bin/datatool${CMAKE_EXECUTABLE_SUFFIX}")
        set(NCBI_DATATOOL "${NCBI_PKG_ROOT}/bin/datatool${CMAKE_EXECUTABLE_SUFFIX}")
    endif()
endif()
if(NOT DEFINED NCBI_PROTOC_APP)
    if(DEFINED CONAN_BIN_DIRS_PROTOBUF)
        set(NCBI_PROTOC_APP "${CONAN_BIN_DIRS_PROTOBUF}/protoc${CMAKE_EXECUTABLE_SUFFIX}")
    elseif(TARGET protobuf::protoc)
        get_property(NCBI_PROTOC_APP TARGET protobuf::protoc PROPERTY IMPORTED_LOCATION)
    endif()
endif()
if(NOT DEFINED NCBI_GRPC_PLUGIN)
    if(DEFINED CONAN_BIN_DIRS_GRPC)
        set(NCBI_GRPC_PLUGIN "${CONAN_BIN_DIRS_GRPC}/grpc_cpp_plugin${CMAKE_EXECUTABLE_SUFFIX}")
    elseif(TARGET gRPC::grpc_cpp_plugin)
        get_property(NCBI_GRPC_PLUGIN TARGET gRPC::grpc_cpp_plugin PROPERTY IMPORTED_LOCATION)
    endif()
endif()

##############################################################################
macro(NCBI_generate_cpp)
    set(__ncbi_add_dotinc)
    NCBI_internal_generate_cpp(${ARGV})
    if(NOT "${__ncbi_add_dotinc}" STREQUAL "" AND NOT DEFINED NCBI_PTB_HAS_ROOT)
        include_directories(${__ncbi_add_dotinc})
    endif()
endmacro()

# GEN_OPTIONS:
#   for .proto specs:
#       proto   - generate PROTOBUF code (default = ON) 
#       -proto  - do not generate PROTOBUF code
#       grpc    - generate GRPC code (default = OFF) 
#       -grpc   - do not generate GRPC code
#       mock    - when grpc is ON, generate MOCK code (default = OFF) 
#       -mock   - do not generate MOCK code
#
##############################################################################
function(NCBI_internal_generate_cpp GEN_SOURCES GEN_HEADERS)
    if ("${ARGC}" LESS "3")
        message(FATAL_ERROR "NCBI_generate_cpp: no dataspecs provided")
    endif()
    cmake_parse_arguments(PARSE_ARGV 2 GEN "" "GEN_SRCOUT;GEN_HDROUT" "GEN_OPTIONS")
    set(_dt_specs .asn;.dtd;.xsd;.wsdl;.jsd;.json)
    set(_protoc_specs .proto)

    if(DEFINED NCBI_CURRENT_SOURCE_DIR)
        set(_current_dir ${NCBI_CURRENT_SOURCE_DIR})
    else()
        set(_current_dir ${CMAKE_CURRENT_SOURCE_DIR})
    endif()
    set(_all_srcfiles)
    set(_all_incfiles)
    foreach(_spec IN LISTS GEN_UNPARSED_ARGUMENTS)
        set(_DATASPEC ${_spec})
        if(NOT IS_ABSOLUTE ${_DATASPEC})
            set(_DATASPEC ${_current_dir}/${_DATASPEC})
        endif()
        get_filename_component(_path     ${_DATASPEC} DIRECTORY)
        get_filename_component(_basename ${_DATASPEC} NAME_WE)
        get_filename_component(_ext      ${_DATASPEC} EXT)
        file(RELATIVE_PATH     _relpath  ${_current_dir} ${_path})
        if("${_relpath}" STREQUAL "")
            set(_relpath .)
        endif()
        if(NOT "${GEN_GEN_SRCOUT}" STREQUAL "")
            if(IS_ABSOLUTE ${GEN_GEN_SRCOUT})
                set(_src_abspath ${GEN_GEN_SRCOUT})
            else()
                set(_src_abspath ${_path}/${GEN_GEN_SRCOUT})
            endif()
            set(_src_relpath  ${GEN_GEN_SRCOUT})
        else()
            set(_src_abspath ${_path})
            set(_src_relpath  ${_relpath})
        endif()
        if(NOT "${GEN_GEN_HDROUT}" STREQUAL "")
            if(IS_ABSOLUTE ${GEN_GEN_HDROUT})
                set(_hdr_abspath ${GEN_GEN_HDROUT})
            else()
                set(_hdr_abspath ${_path}/${GEN_GEN_HDROUT})
            endif()
            set(_hdr_relpath  ${GEN_GEN_HDROUT})
        else()
            set(_hdr_abspath ${_path})
            set(_hdr_relpath  ${_relpath})
        endif()

        if (NOT EXISTS "${_DATASPEC}")
            message(FATAL_ERROR "${_DATASPEC}: File not found")
        endif()
        set(_this_specfile   ${_DATASPEC})

        if("${_ext}" IN_LIST _dt_specs)
            if (NOT EXISTS "${NCBI_DATATOOL}" AND NOT NCBI_PTBMODE_COLLECT_DEPS AND NOT TARGET "${NCBI_DATATOOL}")
                message(FATAL_ERROR "Datatool code generator not found")
            endif()

            set(_this_srcfiles   ${_src_abspath}/${_basename}__.cpp ${_src_abspath}/${_basename}___.cpp)
            set(_this_incfiles   ${_hdr_abspath}/${_basename}__.hpp)
            list(APPEND _all_srcfiles ${_this_srcfiles})
            list(APPEND _all_incfiles ${_this_incfiles})

            if(DEFINED NCBI_PROJECT)
                set_property(GLOBAL PROPERTY NCBI_PTBPROP_DATASPEC_${NCBI_PROJECT} "${_this_specfile}")
            endif()
            if( NOT NCBI_PTBMODE_COLLECT_DEPS)
                set(_module_imports "")
                set(_imports "")
                if(EXISTS "${_path}/${_basename}.module")
                    FILE(READ "${_path}/${_basename}.module" _module_contents)
                    STRING(REGEX MATCH "MODULE_IMPORT *=[^\n]*[^ \n]" _tmp "${_module_contents}")
                    STRING(REGEX REPLACE "MODULE_IMPORT *= *" "" _tmp "${_tmp}")
                    STRING(REGEX REPLACE "  *$" "" _imp_list "${_tmp}")
                    STRING(REGEX REPLACE " " ";" _imp_list "${_imp_list}")

                    foreach(_module IN LISTS _imp_list)
                        set(_module_imports "${_module_imports} ${_module}${_ext}")
                    endforeach()
                    if (NOT "${_module_imports}" STREQUAL "")
                        set(_imports -ors -opm "${NCBI_PKG_ROOT}/res/specs" -M ${_module_imports})
                    endif()
                endif()
                set(_od ${_path}/${_basename}.def)
                set(_depends ${NCBI_DATATOOL} ${_this_specfile})
                if(EXISTS ${_od})
                    set(_depends ${_depends} ${_od})
                endif()
                set(_cmd ${NCBI_DATATOOL} -m ${_this_specfile} -oA -oc ${_basename} -oph ${_hdr_relpath} -opc ${_src_relpath} -od ${_od} -odi ${_imports})
#message("_cmd = ${_cmd}")
                set_source_files_properties(${_this_srcfiles} ${_this_incfiles} PROPERTIES GENERATED TRUE)
                add_custom_command(
                    OUTPUT ${_this_srcfiles} ${_this_incfiles} ${_src_abspath}/${_basename}.files
                    COMMAND ${_cmd} VERBATIM
                    WORKING_DIRECTORY ${_current_dir}
                    COMMENT "Generate C++ classes from ${_this_specfile}"
                    DEPENDS ${_depends}
                    VERBATIM
                )
                list(APPEND __ncbi_add_dotinc ${_hdr_abspath})
            endif()
        elseif("${_ext}" IN_LIST _protoc_specs)
            if(NOT "-proto" IN_LIST GEN_GEN_OPTIONS)
                if (NOT EXISTS "${NCBI_PROTOC_APP}")
                    find_package(protobuf QUIET CONFIG)
                    if(TARGET protobuf::protoc)
                        get_property(NCBI_PROTOC_APP TARGET protobuf::protoc PROPERTY IMPORTED_LOCATION)
                    endif()
                    if (EXISTS "${NCBI_PROTOC_APP}")
                        set(NCBI_PROTOC_APP ${NCBI_PROTOC_APP} PARENT_SCOPE)
                    endif()
                endif()
                if (NOT EXISTS "${NCBI_PROTOC_APP}")
                    message(FATAL_ERROR "Protoc code generator not found")
                endif()

                set(_this_srcfiles   ${_src_abspath}/${_basename}.pb.cc)
                set(_this_incfiles   ${_src_abspath}/${_basename}.pb.h)
                list(APPEND _all_srcfiles ${_this_srcfiles})
                list(APPEND _all_incfiles ${_this_incfiles})

                if( NOT NCBI_PTBMODE_COLLECT_DEPS)
                    set(_depends ${NCBI_PROTOC_APP} ${_this_specfile})
                    set(_cmd ${NCBI_PROTOC_APP} --cpp_out=${_src_relpath} -I${_relpath} ${_basename}${_ext})
                    add_custom_command(
                        OUTPUT ${_this_srcfiles} ${_this_incfiles}
                        COMMAND ${_cmd} VERBATIM
                        WORKING_DIRECTORY ${_current_dir}
                        COMMENT "Generate PROTOC C++ classes from ${_this_specfile}"
                        DEPENDS ${_depends}
                        VERBATIM
                    )
                endif()
            endif()

            if("grpc" IN_LIST GEN_GEN_OPTIONS)
                if (NOT EXISTS "${NCBI_GRPC_PLUGIN}")
                    find_package(gRPC QUIET CONFIG)
                    if(TARGET gRPC::grpc_cpp_plugin)
                        get_property(NCBI_GRPC_PLUGIN TARGET gRPC::grpc_cpp_plugin PROPERTY IMPORTED_LOCATION)
                    endif()
                    if (EXISTS "${NCBI_GRPC_PLUGIN}")
                        set(NCBI_GRPC_PLUGIN ${NCBI_GRPC_PLUGIN} PARENT_SCOPE)
                    endif()
                endif()
                if (NOT EXISTS "${NCBI_GRPC_PLUGIN}")
                    message(FATAL_ERROR "GRPC CPP plugin not found")
                endif()

                set(_this_srcfiles   ${_src_abspath}/${_basename}.grpc.pb.cc)
                set(_this_incfiles   ${_src_abspath}/${_basename}.grpc.pb.h)
                list(APPEND _all_srcfiles ${_this_srcfiles})
                list(APPEND _all_incfiles ${_this_incfiles})

                if( NOT NCBI_PTBMODE_COLLECT_DEPS)
                    set(_depends ${NCBI_PROTOC_APP} ${NCBI_GRPC_PLUGIN} ${_this_specfile})
                    if("mock" IN_LIST GEN_GEN_OPTIONS)
                        set(_cmd ${NCBI_PROTOC_APP} --grpc_out=generate_mock_code=true:${_src_relpath} --plugin=protoc-gen-grpc=${NCBI_GRPC_PLUGIN} -I${_relpath} ${_basename}${_ext})
                    else()
                        set(_cmd ${NCBI_PROTOC_APP} --grpc_out=${_src_relpath} --plugin=protoc-gen-grpc=${NCBI_GRPC_PLUGIN} -I${_relpath} ${_basename}${_ext})
                    endif()
                    add_custom_command(
                        OUTPUT ${_this_srcfiles} ${_this_incfiles}
                        COMMAND ${_cmd} VERBATIM
                        WORKING_DIRECTORY ${_current_dir}
                        COMMENT "Generate GRPC C++ classes from ${_this_specfile}"
                        DEPENDS ${_depends}
                        VERBATIM
                    )
                endif()
            endif()
        else()
            message(FATAL_ERROR "NCBI_generate_cpp: unsupported specification: ${_spec}")
        endif()
    endforeach()
    if(NOT "${__ncbi_add_dotinc}" STREQUAL "" AND NOT NCBI_PTBMODE_COLLECT_DEPS)
        list(REMOVE_DUPLICATES __ncbi_add_dotinc)
        set(__ncbi_add_dotinc ${__ncbi_add_dotinc} PARENT_SCOPE)
    endif()
    set(${GEN_SOURCES} ${_all_srcfiles}  PARENT_SCOPE)
    set(${GEN_HEADERS} ${_all_incfiles}  PARENT_SCOPE)
endfunction()