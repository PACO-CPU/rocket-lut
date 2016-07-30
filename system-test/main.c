#include <rocket/uart.h>
#include <inttypes.h>

#include "test_data.c"
#define SILENT 1

void fmt_u64(char *p, uint64_t v);
uint64_t lut_status();
void lut_reset();
void lut_load_config();
void run_test();

int main() {
  run_test();
  while(1);
  return 0;
}
#if 1
void fmt_u64(char *p, uint64_t v) {
  static const char alp[]="0123456789abcdef";
  int i;
  for(i=60;i>=0;i-=4) *(p++)=alp[(v>>i)&0xf];
}
uint64_t lut_status() {
    static char s_status[]="status: xxxxxxxxxxxxxxxx";
    uint64_t s=0xaffedead;
    //asm("luts %0, 0" : "=r"(s));
    fmt_u64(s_status+8,s);
    #if !SILENT
    uart_println(s_status);
    #endif
    return s;
}
void lut_reset()
{
    asm("lutl x0, 0, 0, 0");
}

void lut_load_config()
{
    int i;
    uint64_t current_word;

    for (i = 0; i < BITSTREAM_SIZE; i++) {
        current_word = bitstream[i];
        asm("lutl %0, 0, 0, 1" : :"r"(current_word));
    }
}


void run_test() {
    static char s_error_deviation[]=
      "ERROR: xxxxxxxxxxxxxxxx (phys) != xxxxxxxxxxxxxxxx (exp) @ xxxxxxxxxxxxxxxx";
    int i;
    uint64_t phys_result;
    #if !SILENT
    uart_println("beginning test..");
    lut_status();
    lut_reset();
    lut_status();
    lut_load_config();
    lut_status();
    #else
    lut_reset();
    lut_load_config();
    #endif

    for (i = 0; i < INPUT_SIZE; i++) {
        phys_result=0xdeadbeef0badf00duL;
        asm("lute %0, %1, 0" : "=r"(phys_result) : "r"(input_vec[i]));

        if (phys_result != output_vec[i]) {
            #if !SILENT
            fmt_u64(s_error_deviation+7,phys_result);
            fmt_u64(s_error_deviation+34,output_vec[i]);
            fmt_u64(s_error_deviation+59,input_vec[i]);
            uart_println(s_error_deviation);
            #else
            asm("li x31, 0xdead");
            #endif
        }

    }

    lut_status();

}
#endif

