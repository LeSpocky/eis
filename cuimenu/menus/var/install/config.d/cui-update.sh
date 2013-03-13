#!/bin/sh
#---------------------------------------------------------------------
# /var/install/config.d/cui-update.sh - parameter update script
#
# Creation:     2005-08-06 dv
# Last Update:  $Id: cui-update.sh 24471 2010-06-10 21:14:01Z schlotze $
#
#----------------------------------------------------------------------

. /var/install/include/configlib

#--------------------------------------------------------------------
# Begin default values
#--------------------------------------------------------------------

CUI_USE_COLORS='yes'                      # Enable colors
CUI_USE_MOUSE='no'                        # Enable mouse input

#--------------------------------------------------------------------
# color profile "WINDOW"
#--------------------------------------------------------------------

CUI_WINDOW_WND_COLOR='BLUE'              # Window color
CUI_WINDOW_WND_SEL_COLOR='LIGHTGRAY'     # Color for selections
CUI_WINDOW_WND_TXT_COLOR='LIGHTGRAY'     # Window text color
CUI_WINDOW_SEL_TXT_COLOR='BLACK'         # Color for selected text
CUI_WINDOW_INACT_TXT_COLOR='DARKGRAY'    # Inactive text color
CUI_WINDOW_HILIGHT_COLOR='YELLOW'        # Hilighted text color
CUI_WINDOW_TITLE_TXT_COLOR='BLACK'       # Title bar text color
CUI_WINDOW_TITLE_BKG_COLOR='LIGHTGRAY'   # Title bar background color
CUI_WINDOW_STATUS_TXT_COLOR='BLACK'      # Status bar text color
CUI_WINDOW_STATUS_BKG_COLOR='LIGHTGRAY'  # Status bar background color
CUI_WINDOW_BORDER_COLOR='LIGHTGRAY'      # Border color

#--------------------------------------------------------------------
# color profile "DESKTOP"
#--------------------------------------------------------------------

CUI_DESKTOP_WND_COLOR='BLUE'             # Window color
CUI_DESKTOP_WND_SEL_COLOR='LIGHTGRAY'    # Color for selections
CUI_DESKTOP_WND_TXT_COLOR='LIGHTGRAY'    # Window text color
CUI_DESKTOP_SEL_TXT_COLOR='BLACK'        # Color for selected text
CUI_DESKTOP_INACT_TXT_COLOR='DARKGRAY'   # Inactive text color
CUI_DESKTOP_HILIGHT_COLOR='YELLOW'       # Hilighted text color
CUI_DESKTOP_TITLE_TXT_COLOR='BLACK'      # Title bar text color
CUI_DESKTOP_TITLE_BKG_COLOR='LIGHTGRAY'  # Title bar background color
CUI_DESKTOP_STATUS_TXT_COLOR='LIGHTGRAY' # Status bar text color
CUI_DESKTOP_STATUS_BKG_COLOR='BLACK'     # Status bar background color
CUI_DESKTOP_BORDER_COLOR='LIGHTGRAY'     # Border color

#--------------------------------------------------------------------
# color profile "DIALOG"
#--------------------------------------------------------------------

CUI_DIALOG_WND_COLOR='LIGHTGRAY'         # Window color
CUI_DIALOG_WND_SEL_COLOR='CYAN'          # Color for selections
CUI_DIALOG_WND_TXT_COLOR='BLACK'         # Window text color
CUI_DIALOG_SEL_TXT_COLOR='BLACK'         # Color for selected text
CUI_DIALOG_INACT_TXT_COLOR='DARKGRAY'    # Inactive text color
CUI_DIALOG_HILIGHT_COLOR='BLUE'          # Hilighted text color
CUI_DIALOG_TITLE_TXT_COLOR='WHITE'       # Title bar text color
CUI_DIALOG_TITLE_BKG_COLOR='MAGENTA'     # Title bar background color
CUI_DIALOG_STATUS_TXT_COLOR='BLACK'      # Status bar text color
CUI_DIALOG_STATUS_BKG_COLOR='LIGHTGRAY'  # Status bar background color
CUI_DIALOG_BORDER_COLOR='BLACK'          # Border color

#--------------------------------------------------------------------
# color profile "MENU"
#--------------------------------------------------------------------

CUI_MENU_WND_COLOR='CYAN'                # Window color
CUI_MENU_WND_SEL_COLOR='BLACK'           # Color for selections
CUI_MENU_WND_TXT_COLOR='BLACK'           # Window text color
CUI_MENU_SEL_TXT_COLOR='WHITE'           # Color for selected text
CUI_MENU_INACT_TXT_COLOR='DARKGRAY'      # Inactive text color
CUI_MENU_HILIGHT_COLOR='YELLOW'          # Hilighted text color
CUI_MENU_TITLE_TXT_COLOR='BLACK'         # Title bar text color
CUI_MENU_TITLE_BKG_COLOR='LIGHTGRAY'     # Title bar background color
CUI_MENU_STATUS_TXT_COLOR='BLACK'        # Status bar text color
CUI_MENU_STATUS_BKG_COLOR='LIGHTGRAY'    # Status bar background color
CUI_MENU_BORDER_COLOR='BLACK'            # Border color

#--------------------------------------------------------------------
# color profile "TERMINAL"
#--------------------------------------------------------------------

CUI_TERMINAL_WND_COLOR='BLACK'           # Window color
CUI_TERMINAL_WND_SEL_COLOR='LIGHTGRAY'   # Color for selections
CUI_TERMINAL_WND_TXT_COLOR='LIGHTGRAY'   # Window text color
CUI_TERMINAL_SEL_TXT_COLOR='BLACK'       # Color for selected text
CUI_TERMINAL_INACT_TXT_COLOR='DARKGRAY'  # Inactive text color
CUI_TERMINAL_HILIGHT_COLOR='LIGHTGRAY'   # Hilighted text color
CUI_TERMINAL_TITLE_TXT_COLOR='BLACK'     # Title bar text color
CUI_TERMINAL_TITLE_BKG_COLOR='LIGHTGRAY' # Title bar background color
CUI_TERMINAL_STATUS_TXT_COLOR='BLACK'    # Status bar text color
CUI_TERMINAL_STATUS_BKG_COLOR='LIGHTGRAY'
                                         # Status bar background color
CUI_TERMINAL_BORDER_COLOR='LIGHTGRAY'    # Border color

#--------------------------------------------------------------------
# color profile "HELP"
#--------------------------------------------------------------------

CUI_HELP_WND_COLOR='LIGHTGRAY'           # Window color
CUI_HELP_WND_SEL_COLOR='BLACK'           # Color for selections
CUI_HELP_WND_TXT_COLOR='BLACK'           # Window text color
CUI_HELP_SEL_TXT_COLOR='WHITE'           # Color for selected text
CUI_HELP_INACT_TXT_COLOR='DARKGRAY'      # Inactive text color
CUI_HELP_HILIGHT_COLOR='BLUE'            # Hilighted text color
CUI_HELP_TITLE_TXT_COLOR='LIGHTGRAY'     # Title bar text color
CUI_HELP_TITLE_BKG_COLOR='BLUE'          # Title bar background color
CUI_HELP_STATUS_TXT_COLOR='BLACK'        # Status bar text color
CUI_HELP_STATUS_BKG_COLOR='LIGHTGRAY'    # Status bar background color
CUI_HELP_BORDER_COLOR='BLACK'            # Border color

#--------------------------------------------------------------------
# End default values
#--------------------------------------------------------------------


### ---------------------------------------------------------------------------
### Write config and default files
### ---------------------------------------------------------------------------
make_config_file()
{
    internal_conf_file=$1
    {
    printgpl --conf cui "2007-11-03" "dv"

    printgroup "global options"
    printvar "CUI_USE_COLORS" "Enable colors"
    printvar "CUI_USE_MOUSE" "Enable mouse input"

    printgroup "color profile \"WINDOW\" (application's main view)"
    printvar "CUI_WINDOW_WND_COLOR" "Window color"
    printvar "CUI_WINDOW_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_WINDOW_WND_TXT_COLOR" "Window text color"
    printvar "CUI_WINDOW_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_WINDOW_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_WINDOW_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_WINDOW_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_WINDOW_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_WINDOW_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_WINDOW_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_WINDOW_BORDER_COLOR" "Window border color"

    printgroup "color profile \"DESKTOP\" (application's background)"
    printvar "CUI_DESKTOP_WND_COLOR" "Window color"
    printvar "CUI_DESKTOP_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_DESKTOP_WND_TXT_COLOR" "Window text color   "
    printvar "CUI_DESKTOP_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_DESKTOP_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_DESKTOP_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_DESKTOP_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_DESKTOP_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_DESKTOP_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_DESKTOP_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_DESKTOP_BORDER_COLOR" "Window border color"

    printgroup "color profile \"DIALOG\""
    printvar "CUI_DIALOG_WND_COLOR" "Window color"
    printvar "CUI_DIALOG_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_DIALOG_WND_TXT_COLOR" "Window text color"
    printvar "CUI_DIALOG_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_DIALOG_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_DIALOG_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_DIALOG_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_DIALOG_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_DIALOG_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_DIALOG_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_DIALOG_BORDER_COLOR" "Window border color"

    printgroup "color profile \"MENU\""
    printvar "CUI_MENU_WND_COLOR" "Window color"
    printvar "CUI_MENU_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_MENU_WND_TXT_COLOR" "Window text color   "
    printvar "CUI_MENU_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_MENU_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_MENU_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_MENU_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_MENU_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_MENU_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_MENU_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_MENU_BORDER_COLOR" "Window border color"

    printgroup "color profile \"TERMINAL\""
    printvar "CUI_TERMINAL_WND_COLOR" "Window color"
    printvar "CUI_TERMINAL_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_TERMINAL_WND_TXT_COLOR" "Window text color"
    printvar "CUI_TERMINAL_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_TERMINAL_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_TERMINAL_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_TERMINAL_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_TERMINAL_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_TERMINAL_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_TERMINAL_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_TERMINAL_BORDER_COLOR" "Window border color"

    printgroup "color profile \"HELP\""
    printvar "CUI_HELP_WND_COLOR" "Window color"
    printvar "CUI_HELP_WND_SEL_COLOR" "Color for selections"
    printvar "CUI_HELP_WND_TXT_COLOR" "Window text color"
    printvar "CUI_HELP_SEL_TXT_COLOR" "Color for selected text"
    printvar "CUI_HELP_INACT_TXT_COLOR" "Inactive text color"
    printvar "CUI_HELP_HILIGHT_COLOR" "Hilighted text color"
    printvar "CUI_HELP_TITLE_TXT_COLOR" "Title bar text color"
    printvar "CUI_HELP_TITLE_BKG_COLOR" "Title bar background color"
    printvar "CUI_HELP_STATUS_TXT_COLOR" "Status bar text color"
    printvar "CUI_HELP_STATUS_BKG_COLOR" "Status bar background color"
    printvar "CUI_HELP_BORDER_COLOR" "Window border color"
    printend
    } > $internal_conf_file
    # Set rights
    chmod 0600 $internal_conf_file
    chown root $internal_conf_file
}



### ---------------------------------------------------------------------------
### Main
### ---------------------------------------------------------------------------
default_profile="$1"

# if default_profile is a file name, we read this file as default color profile
if [ ! -z "$default_profile" -a -f "$default_profile" ]
then
    . "$default_profile"
fi

# write new config file
make_config_file /etc/config.d/cui

### ---------------------------------------------------------------------------
