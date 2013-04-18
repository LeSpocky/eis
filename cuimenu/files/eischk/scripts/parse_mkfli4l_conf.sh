#!/bin/sh
# -------------------------------------------------------------------------
# parse/read <config-dir>/mkfli4l.conf                         3.6.2
#
# Creation:       lanspezi 2004-11-17
# Last Update:    $Id: parse_mkfli4l_conf.sh 17656 2009-10-18 18:39:00Z knibo $
# -------------------------------------------------------------------------

cleanup_pmc ()
{
    rm -f "$dir_config/mkfli4l.txt" check/mkfli4l.exp \
          "$dir_config"/_tmp_$$/mkfli4l_conf.log
    rmdir "$dir_config"/_tmp_$$
}

extract_value ()
{
    var=$1
    src=$2
    cond_val="$3"
    true_val="$4"
    false_val="$5"
    val=`sed -n -e "s/^[[:space:]]*$src=['\"]\([^'\"]*\)['\"].*/\1/p" "$dir_config/mkfli4l.conf"`
    case x$val in
        x) return ;;
    esac

    case  x$cond_val in
        x) eval "$var='$val'" ;;
        *)
            case  $cond_val in
                $val) eval "$var='$true_val'"  ;;
                *)    eval "$var='$false_val'" ;;
            esac
            ;;
    esac
    # eval echo "$var=\$$var"
}

parse_mkfli4l_conf ()
{
    if [ ! -f "$dir_config/mkfli4l.conf" ]; then
        return 0
    fi

    show_header "--- read and check the build-environment from $dir_config/mkfli4l.conf..."

    mkdir "$dir_config/_tmp_$$"
    cp "$dir_config/mkfli4l.conf" "$dir_config/mkfli4l.txt"
    cp check/mkfli4l.exp.unix check/mkfli4l.exp
    if ! unix/mkfli4l -c "$dir_config" -b "$dir_config/_tmp_$$" -t "$dir_config/_tmp_$$" -l "$dir_config/_tmp_$$/mkfli4l_conf.log" -p mkfli4l; then
        append_error "$dir_config"/_tmp_$$/mkfli4l_conf.log
        cat <<EOF | log_error

The file $dir_config/mkfli4l.conf contains errors.
Please check the contents of this file and try again.
EOF
        cleanup_pmc
        return 1
    fi

    # read config
    extract_value dir_build      BUILDDIR
    extract_value verbose        VERBOSE        yes  -v   ''
    extract_value drive          DRIVE
    extract_value suffix         FLOPPYMODE     safe -s   ''
    extract_value bool_filesonly FILESONLY      yes  true false
    extract_value remoteupdate   REMOTEUPDATE   yes  true false
    extract_value remotehostname REMOTEHOSTNAME
    extract_value remoteusername REMOTEUSERNAME
    extract_value remotepathname REMOTEPATHNAME
    extract_value remoteport     REMOTEPORT
    extract_value sshkeyfile     SSHKEYFILE
    extract_value tftpboot_path  TFTPBOOTPATH
    extract_value tftpboot_image TFTPBOOTIMAGE
    extract_value pxe_subdir     PXESUBDIR
    extract_value hostsglobalfile HOSTS_GLOBAL
    extract_value mkfli4l_debug_option MKFLI4L_DEBUG_OPTION
    extract_value bool_no_squeeze SQUEEZE_SCRIPTS yes false true
    drive=`echo $drive | sed -e 's/://'`
    if [ "$sshkeyfile" ]; then
    if [ ! -f "$sshkeyfile" ]; then
        echo "    Key file '$sshkeyfile' does not exist, ignoring key file option."
        sshkeyfile=
    fi
    fi
    show_end
    cleanup_pmc
    return 0
}
