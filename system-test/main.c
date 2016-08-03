#include <rocket/uart.h>
#include <inttypes.h>

#include "test_data.c"
#define SILENT 0 

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
    static char s_status[]="status: xxxxxxxxxxxxxxxx  xxxxxxxxxxxxxxxx";
    uint64_t s=0xaffedead, s3;
    asm("luts %0, 0" : "=r"(s));
    asm("luts %0, 1" : "=r"(s3));
    #if !SILENT
    fmt_u64(s_status+8,s);
    fmt_u64(s_status+26,s3);
    uart_println(s_status);
    #endif
    return s;
}
void lut_reset()
{
    asm("lutl x0, 0, 0, 0");
    asm("lutl x0, 1, 0, 0");
}

void lut_load_config()
{
    int i;
    uint64_t current_word;

    for (i = 0; i < BITSTREAM_SIZE; i++) {
        current_word = bitstream[i];
        asm("lutl %0, 1, 0, 1" : :"r"(current_word));
        current_word = bitstream3[i];
        asm("lutl %0, 0, 0, 1" : :"r"(current_word));
    }
}


void run_test() {
    static char s_error_deviation[]=
      "  ERROR: (case x) xxxxxxxxxxxxxxxx (phys) != xxxxxxxxxxxxxxxx (exp) @ xxxxxxxxxxxxxxxx";
    int i;
    uint64_t phys_result;
    char term[3]={0,0,'\n'};
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
    lut_status();
    #endif

    #if !SILENT
    uart_println("case A..");
    #endif
    #if !SILENT
      #define TEST_RESULT(id,exp) { \
        if (phys_result != exp) { \
            s_error_deviation[15]=id; \
            fmt_u64(s_error_deviation+18,phys_result); \
            fmt_u64(s_error_deviation+45,exp); \
            fmt_u64(s_error_deviation+70,input_vec[i]); \
            uart_println(s_error_deviation); \
            term[1]=1; \
        } \
      }
    #else
      #define TEST_RESULT(id,exp) { \
        if (phys_result != exp) { \
            /*asm("li x31, 0xdead");*/ \
            term[1]=1; \
        } \
      }
    #endif



    for (i = 0; i < INPUT_SIZE; i++) {
        asm("lute %0, %1, 1,1" : "=r"(phys_result) : "r"(input_vec[i]));
        TEST_RESULT('A',output_vec[i]);
    }
    
    #if !SILENT
    uart_println("case B..");
    #endif
    for (i = 0; i < INPUT_SIZE; i++) {
        asm(
          
          "lute3 %0, %1, %2, %3, 0\n"
          : "=r"(phys_result) 
          : "r"(input_vec3_1[i]), "r"(input_vec3_2[i]), "r"(input_vec3_3[i]));
        TEST_RESULT('B',output_vec3[i]);
    }

    lut_status();

    uart_write(term,sizeof(term));

}
#endif

