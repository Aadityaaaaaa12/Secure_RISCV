#include <cstring>

#include "gcc-plugin.h"
#include "plugin-version.h"

#include "context.h"
#include "tree.h"
#include "function.h"
#include "tree-pass.h"

#include "rtl.h"
#include "memmodel.h"
#include "emit-rtl.h"

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
    if (!std::strcmp(name, "_start"))            return false;
    return true;
}

static rtx make_basic_asm_operands(const char *asm_text)
{
    const char *s  = ggc_strdup(asm_text);
    const char *oc = ggc_strdup("");

    rtvec argvec        = rtvec_alloc(0);
    rtvec constraintvec = rtvec_alloc(0);
    rtvec labelvec      = rtvec_alloc(0);

    rtx body = gen_rtx_ASM_OPERANDS(
        VOIDmode,
        s,
        oc,
        0,
        argvec,
        constraintvec,
        labelvec,
        UNKNOWN_LOCATION
    );

    MEM_VOLATILE_P(body) = 1;
    return body;
}

static bool contains_return_in_parallel(rtx pat)
{
    if (GET_CODE(pat) != PARALLEL) return false;
    for (int i = 0; i < XVECLEN(pat, 0); i++) {
        rtx e = XVECEXP(pat, 0, i);
        if (GET_CODE(e) == RETURN || GET_CODE(e) == SIMPLE_RETURN)
            return true;
    }
    return false;
}

static bool is_return_insn(rtx_insn *insn)
{
    if (!JUMP_P(insn)) return false;

    rtx pat = PATTERN(insn);
    enum rtx_code code = GET_CODE(pat);

    if (code == RETURN || code == SIMPLE_RETURN)
        return true;

    if (contains_return_in_parallel(pat))
        return true;

    return false;
}

static rtx_insn* first_real_insn()
{
    for (rtx_insn *insn = get_insns(); insn; insn = NEXT_INSN(insn)) {
        if (NOTE_P(insn)) continue;
        if (BARRIER_P(insn)) continue;
        if (DEBUG_INSN_P(insn)) continue;
        if (!INSN_P(insn) && !CALL_P(insn) && !JUMP_P(insn)) continue;
        return insn;
    }
    return nullptr;
}

static unsigned int shadowstack_rtl_exec()
{
    if (!should_instrument())
        return 0;

    const char *push_asm = ".insn r 0x0b, 0, 0x01, x0, x0, x0";
    const char *pop_asm  = ".insn r 0x0b, 0, 0x02, x0, x0, x0";

    // 1) PUSH at function entry 
    if (rtx_insn *entry = first_real_insn()) {
        rtx push = make_basic_asm_operands(push_asm);
        emit_insn_before(push, entry);
    }

    // 2) POPCHK before each return
    for (rtx_insn *insn = get_insns(); insn; )
    {
        rtx_insn *next = NEXT_INSN(insn);

        if (is_return_insn(insn)) {
            rtx pop = make_basic_asm_operands(pop_asm);
            emit_insn_before(pop, insn);
        }

        insn = next;
    }

    return 0;
}

namespace {

const pass_data shadowstack_rtl_pass_data = {
    RTL_PASS,
    "shadowstack_rtl",
    OPTGROUP_NONE,
    TV_NONE,
    0,
    0, 0, 0, 0
};

struct shadowstack_rtl_pass : rtl_opt_pass {
    shadowstack_rtl_pass(gcc::context *ctx) : rtl_opt_pass(shadowstack_rtl_pass_data, ctx) {}
    unsigned int execute(function *) override { return shadowstack_rtl_exec(); }
};

} 

int plugin_init(struct plugin_name_args *plugin_info,
                struct plugin_gcc_version *version)
{
    if (!plugin_default_version_check(version, &gcc_version))
        return 1;

    register_pass_info pass_info;
    pass_info.pass = new shadowstack_rtl_pass(g);

    pass_info.reference_pass_name = "pro_and_epilogue";
    pass_info.ref_pass_instance_number = 1;
    pass_info.pos_op = PASS_POS_INSERT_AFTER;

    register_callback(plugin_info->base_name, PLUGIN_PASS_MANAGER_SETUP, nullptr, &pass_info);
    return 0;
}
