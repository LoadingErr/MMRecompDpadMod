#include "modding.h"
#include "global.h"
#include "sys_cmpdma.h"
#include "rt64_extended_gbi.h"
#include "recompconfig.h"
#include "z64interface.h"

#define INCBIN(identifier, filename)          \
    asm(".pushsection .rodata\n"              \
        "\t.local " #identifier "\n"          \
        "\t.type " #identifier ", @object\n"  \
        "\t.balign 8\n"                       \
        #identifier ":\n"                     \
        "\t.incbin \"" filename "\"\n\n"      \
                                              \
        "\t.balign 8\n"                       \
        "\t.popsection\n");                   \
    extern u8 identifier[]

INCBIN(dpad_icon, "src/dpad.rgba32.bin");

#define DPAD_W 18
#define DPAD_H 18

#define DPAD_IMG_W 32
#define DPAD_IMG_H 32

#define DPAD_DSDX (s32)(1024.0f * (float)(DPAD_IMG_W) / (DPAD_W))
#define DPAD_DTDY (s32)(1024.0f * (float)(DPAD_IMG_H) / (DPAD_H))

#define DPAD_CENTER_X 32
#define DPAD_CENTER_Y 76

#define ICON_IMG_SIZE 32
#define ICON_SIZE 16
#define ICON_DIST 14

#define ICON_DSDX (s32)(1024.0f * (float)(ICON_IMG_SIZE) / (ICON_SIZE))
#define ICON_DTDY (s32)(1024.0f * (float)(ICON_IMG_SIZE) / (ICON_SIZE))

#define BTN_DPAD (BTN_DRIGHT | BTN_DLEFT | BTN_DDOWN | BTN_DUP)
#define DPAD_TO_HELD_ITEM(btn) (btn + EQUIP_SLOT_MAX) 
#define HELD_ITEM_TO_DPAD(heldBtn) (heldBtn - EQUIP_SLOT_MAX)
#define IS_HELD_DPAD(heldBtn) ((heldBtn >= DPAD_TO_HELD_ITEM(EQUIP_SLOT_D_RIGHT)) && (heldBtn <= DPAD_TO_HELD_ITEM(EQUIP_SLOT_D_UP)))

#define BTN_DPAD_EQUIP (GameInteractor_Dpad(GI_DPAD_EQUIP, BTN_DPAD))

#define CHECK_BTN_DPAD(input)                                                                                   \
     (CHECK_BTN_ALL(input, BTN_DRIGHT) || CHECK_BTN_ALL(input, BTN_DLEFT) || CHECK_BTN_ALL(input, BTN_DDOWN) || \
      CHECK_BTN_ALL(input, BTN_DUP))

#define DPAD_BUTTON(btn) (btn) // Translates between equip slot enum and button, in case we change how enum works

#define DPAD_BUTTON_ITEM_EQUIP(form, btn) (gSaveContext.save.shipSaveInfo.dpadEquips.dpadItems[form][DPAD_BUTTON(btn)])
#define DPAD_CUR_FORM_EQUIP(btn) BUTTON_ITEM_EQUIP(CUR_FORM, DPAD_BUTTON(btn)) // Unused

#define DPAD_SLOT_EQUIP(form, btn) (gSaveContext.save.shipSaveInfo.dpadEquips.dpadSlots[form][DPAD_BUTTON(btn)])

#define DPAD_GET_CUR_FORM_BTN_ITEM(btn) (DPAD_BUTTON_ITEM_EQUIP(0, DPAD_BUTTON(btn)))
#define DPAD_GET_CUR_FORM_BTN_SLOT(btn) (DPAD_SLOT_EQUIP(0, DPAD_BUTTON(btn)))

#define DPAD_BTN_ITEM(btn)                                                         \
    ((gSaveContext.shipSaveContext.dpad.status[(DPAD_BUTTON(btn))] != BTN_DISABLED) \
         ? DPAD_BUTTON_ITEM_EQUIP(0, (DPAD_BUTTON(btn)))                           \
         : ((gSaveContext.hudVisibility == HUD_VISIBILITY_A_B_C) ? DPAD_BUTTON_ITEM_EQUIP(0, (DPAD_BUTTON(btn))) : ITEM_NONE))

#define DPAD_SET_CUR_FORM_BTN_ITEM(btn, item)                          \
        DPAD_BUTTON_ITEM_EQUIP(0, (DPAD_BUTTON(btn))) = (item);        \
        (void)0

#define DPAD_SET_CUR_FORM_BTN_SLOT(btn, item)                     \
        DPAD_SLOT_EQUIP(0, (DPAD_BUTTON(btn))) = (item);          \
        (void)0