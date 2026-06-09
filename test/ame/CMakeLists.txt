# AME smoke tests. These use the minimal bare-metal harness in src/test.inc
# rather than the first_party runtime.

find_program(GCC_BIN_RV64 "riscv64-unknown-elf-gcc")

if (NOT GCC_BIN_RV64)
    message(FATAL_ERROR "ENABLE_RISCV_AME_TESTS requires riscv64-unknown-elf-gcc")
endif()

set(ame_test_sources
    "msettyp.S"
)

set(ame_config "${CMAKE_BINARY_DIR}/config/rv64d_v256_e64.json")

foreach(test_source IN LISTS ame_test_sources)
    get_filename_component(test_name "${test_source}" NAME_WE)
    set(elf "rv64_ame_${test_source}.elf")

    add_custom_command(
        OUTPUT ${elf}
        DEPENDS
            "src/${test_source}"
            "src/test.inc"
            "src/ame_macros.inc"
            "src/link.ld"
        COMMAND ${GCC_BIN_RV64}
            -nostdlib
            -nostartfiles
            -static
            -mno-relax
            -mcmodel=medany
            -T "${CMAKE_CURRENT_SOURCE_DIR}/src/link.ld"
            -I "${CMAKE_CURRENT_SOURCE_DIR}/src"
            -o ${elf}
            "${CMAKE_CURRENT_SOURCE_DIR}/src/${test_source}"
        VERBATIM
        COMMENT "Compiling AME ${test_source}"
    )

    add_custom_target(build_ame_${test_name} ALL DEPENDS ${elf})
    list(APPEND ame_test_targets "build_ame_${test_name}")

    add_test(
        NAME "ame_${test_name}"
        COMMAND
            $<TARGET_FILE:sail_riscv_sim>
            --config "${ame_config}"
            --enable-experimental-extensions
            "${CMAKE_CURRENT_BINARY_DIR}/${elf}"
    )
endforeach()

add_custom_target(build_ame_tests DEPENDS ${ame_test_targets})
