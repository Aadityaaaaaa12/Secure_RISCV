#include <cstring>
#include "gcc-plugin.h"
#include "plugin-version.h"
#include "vec.h"
#include "tree.h"
#include "gimple.h"
#include "gimple-iterator.h"
#include "context.h"
#include "function.h"
#include "basic-block.h"
#include "tree-pass.h"
#include "stringpool.h"

int plugin_is_GPL_compatible;

static const char* current_fn_name()
{
    if (!current_function_decl) return nullptr;
    tree n = DECL_NAME(current_function_decl);
    if (!n) return nullptr;
    return IDENTIFIER_POINTER(n);
}

static bool should_instrument()
{
    const char *name = current_fn_name();
    if (!name || name[0] == '\0') return false;

    if (!std::strcmp(name, "shadow_stack_fail")) return false;
    if (!std::strcmp(name, "__stack_chk_fail"))  return false;
    return true;
}

static gimple *make_asm_stmt(const char *asm_text)
{
    gasm *g = gimple_build_asm_vec(asm_text, nullptr, nullptr, nullptr, nullptr);
    gimple_asm_set_volatile(g, true);
    return g;
}



static unsigned int shadowstack_exec()
{
    if (!should_instrument())
        return 0;

    const char *push_asm = ".insn r 0x0b, 0, 0x01, x0, x0, x0";
    const char *pop_asm  = ".insn r 0x0b, 0, 0x02, x0, x0, x0";

    /* ---- Insert SSPUSH at function entry ---- */
    basic_block entry_bb = ENTRY_BLOCK_PTR_FOR_FN(cfun)->next_bb;
    if (!entry_bb)
        return 0;

    gimple_stmt_iterator gi = gsi_start_bb(entry_bb);

    /* Skip initial labels/debug stmts so we don’t break them */
    while (!gsi_end_p(gi)) {
        gimple *s = gsi_stmt(gi);
        if (gimple_code(s) == GIMPLE_LABEL || gimple_code(s) == GIMPLE_NOP) {
            gsi_next(&gi);
            continue;
        }
        break;
    }
    gsi_insert_before(&gi, make_asm_stmt(push_asm), GSI_SAME_STMT);

    /* ---- Insert SSPOPCHK before every return ---- */
    basic_block bb;
    FOR_ALL_BB_FN(bb, cfun) {
        for (gimple_stmt_iterator it = gsi_start_bb(bb); !gsi_end_p(it); gsi_next(&it)) {
            gimple *stmt = gsi_stmt(it);
            if (gimple_code(stmt) == GIMPLE_RETURN) {
                gsi_insert_before(&it, make_asm_stmt(pop_asm), GSI_SAME_STMT);
            }
        }
    }

    return 0;
}

namespace {
const pass_data shadowstack_pass_data = {
    GIMPLE_PASS,
    "shadowstack",
    OPTGROUP_NONE,
    TV_NONE,
    PROP_gimple_any,
    0,
    0,
    0,
    0
};

struct shadowstack_pass : gimple_opt_pass {
    shadowstack_pass(gcc::context *ctx) : gimple_opt_pass(shadowstack_pass_data, ctx) {}
    unsigned int execute(function *) override { return shadowstack_exec(); }
};
}

int plugin_init(struct plugin_name_args *plugin_info,
                struct plugin_gcc_version *version)
{
    if (!plugin_default_version_check(version, &gcc_version))
        return 1;

    register_pass_info pass_info;
    pass_info.pass = new shadowstack_pass(g);
    pass_info.reference_pass_name = "cfg";
    pass_info.ref_pass_instance_number = 1;
    pass_info.pos_op = PASS_POS_INSERT_AFTER;

    register_callback(plugin_info->base_name, PLUGIN_PASS_MANAGER_SETUP, nullptr, &pass_info);
    return 0;
}
