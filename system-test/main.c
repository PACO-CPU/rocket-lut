#include <stdint.h>
#include "bitstream.h"
#include "input_vec.h"
#include "output_vec.h"

void lut_reset()
{
    asm("lutl x0, 0, 0, 1");
}

void lut_load_config()
{
    int i;
    uint64_t current_word;

    for (i = 0; i < BITSTREAM_SIZE; i++) {
        current_word = bitstream[i];
        asm("lutl %0, 0, 0, 0" : :"r"(current_word));
    }
}

void run_test()
{
    int i;
    uint64_t phys_result;

    for (i = 0; i < INPUT_SIZE; i++) {

        asm("lute %0, %1, 0" : "=r"(phys_result) : "r"(input_vec[i]));

        if (phys_result != output_vec[i]) {
            /* we have an error here */
            asm("li x31, 0xdead");
        }

    }

}

