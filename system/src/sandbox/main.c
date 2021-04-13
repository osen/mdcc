#include "genesis.h"

int main(bool hardReset)
{
    float a = 9;

    BMP_init(FALSE, BG_A, PAL0, FALSE);

    // Background
    VDP_setPaletteColor(0, RGB24_TO_VDPCOLOR(0x6495ED)); // CornflowerBlue

    VDP_setPaletteColor(1, RGB24_TO_VDPCOLOR(0xFF0000)); //Red
    VDP_setPaletteColor(2, RGB24_TO_VDPCOLOR(0x00FF00)); //Green
    VDP_setPaletteColor(3, RGB24_TO_VDPCOLOR(0x0000FF)); //Blue
    VDP_setPaletteColor(4, RGB24_TO_VDPCOLOR(0xFFFF00)); //Yellow

    while(TRUE)
    {
        // nothing to do here
        // ...

        BMP_showFPS(1);
        BMP_clear();

        a += 2;
        u16 y = a;
        u16 x = a;
        //BMP_setPixelFast((u16)a, 5, (u8)a);
        u8 *dst = bmp_buffer_write + (y * BMP_PITCH) + x;
        //*dst = 0xFF;
        //*dst = 0x22;
        *dst = 0x11;
        //VDP_setPaletteColor(1, RGB24_TO_VDPCOLOR(0xFF00FF)); //Red
/*
        if(a < 20)
        {
          BMP_setPixel(5, 5, 8);
          BMP_drawText("Hello world !", 12, 12);
        }
        else
        {
          BMP_setPixel(6, 5, 8);
          BMP_drawText("------------", 12, 13);
        }
*/

        // always call this method at the end of the frame
        BMP_flip(1);
        //SYS_doVBlankProcess();
    }

    return 0;
}

