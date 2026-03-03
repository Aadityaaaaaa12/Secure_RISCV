// test.c (freestanding, no libc needed)

typedef unsigned int u32;

volatile u32 sink = 0;

__attribute__((noinline))
u32 good_func(u32 a, u32 b) {
    volatile u32 x = a + 1;
    volatile u32 y = b ^ 0x12345678u;
    volatile u32 z = (x << 2) + (y >> 3);
    sink = z;
    return z;
}

__attribute__((noinline))
static void dummy_call(void)
{
    __asm__ volatile ("" ::: "memory");
}

__attribute__((noinline))
u32 bad_func(u32 v) {
    volatile u32 t = v + 7;
    volatile u32 u = t - 3;
    sink = u;

    u32 sp_bad;
    __asm__ volatile ("mv %0, sp" : "=r"(sp_bad));

    dummy_call();

    __asm__ volatile ("mv %0, sp" : "=r"(sp_bad));

    // In THIS build: sw x1,44(sp) / lw x1,44(sp)
    volatile u32 *saved_ra = (volatile u32 *)(sp_bad + 44);

    *saved_ra ^= 0x00000004u;

    return u;
}

int main(void) {
    volatile u32 a = 5;
    volatile u32 b = 16;

    volatile u32 r1 = good_func(a, b);
    volatile u32 r2 = bad_func(r1);

    sink = r2;
    return (int)(sink & 0xFFu);
}
