// test.c (freestanding, no libc needed)

typedef unsigned int  u32;
typedef signed int    s32;

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
u32 bad_func(u32 v) {
    // Just some arithmetic to create a second call/return path
    volatile u32 t = v + 7;
    volatile u32 u = t - 3;
    sink = u;
    return u;
}

int main(void) {
    volatile u32 a = 5;
    volatile u32 b = 16;

    volatile u32 r1 = good_func(a, b);
    volatile u32 r2 = bad_func(r1);

    // Keep result observable
    sink = r2;

    // Return something deterministic
    return (int)(sink & 0xFFu);
}
