#! /bin/sh
#------------------------------------------------------------------------------
#                                                                  3.6.2
# Creates a new opt.img and a new rootfs.img concerning to the configuration
# in config/
#
# Last Update:    $Id: mkopt.sh 19191 2011-03-19 17:25:02Z felix $
#------------------------------------------------------------------------------

gen_version_info()
{
    cat <<EOF
#
# Fli4l version information
#
FLI4L_BUILDDIR='$dir_config'
FLI4L_BUILDDATE='`date +%Y-%m-%d`'
FLI4L_BUILDTIME='`date +%T`'
FLI4L_VERSION='`cat version.txt`'
EOF
}

gen_md5_sums()
{
    echo "FLI4L_MD5_RC_CFG='$1'"

    for i in kernel rootfs.img opt.img syslinux.cfg; do
        name=`echo $i | sed -e 's/\./_/g' | tr a-z A-Z`
        sum=
        if [ -f "$dir_build/$i" ]; then
            set `md5sum -b "$dir_build/$i"`
            sum=$1
        fi
        echo "FLI4L_MD5_$name='$sum'"
    done
}

get_kernel_version()
{
    kernel_version=
    if [ -f "$dir_config"/_fli4l.txt ]; then
        get_one_val kernel_version   KERNEL_VERSION   "$dir_config"/_fli4l.txt "" cont || true
    fi
    if [ -z "$kernel_version" ]; then
        get_one_val kernel_version   KERNEL_VERSION   "$dir_config"/base.txt
    fi
    if [ -z "$kernel_version" ]; then
        log_error "Can't determine kernel version"
        exit 1
    fi
}
gen_kernel_package()
{
    show_header "--- generating kernel package "
    get_kernel_version
    dep=opt/files/lib/modules/$kernel_version/modules.dep

    if [ ! -f $dep ]; then
        log_error "Unable to open $dep, check kernel version"
        show_end
        exit 1
    fi

    cat <<EOF > "$dir_config"/_kernel.txt
#
# generated for kernel version __${kernel_version}__
#
COMPLETE_KERNEL='no'
COMPLETE_KERNEL_VERSION='$kernel_version'
EOF
    cat <<EOF > check/_kernel.txt
COMPLETE_KERNEL         -               - YESNO
COMPLETE_KERNEL_VERSION COMPLETE_KERNEL - NOTEMPTY
EOF

    {
        echo "opt_format_version 1 -"
        sed -n -e 's#^\([^[:space:]]*[^/]\+\)\.k\?o:.*#\1#p' opt/files/lib/modules/$kernel_version/modules.dep |\
            while read mod; do
                case $mod  in
                    */kernel/misc/f*) ;; # ignore avm modules
                    *) echo "complete_kernel yes `basename $mod`"
                esac
        done
    } > opt/_kernel.txt
    show_end
    exit
}
check_kernel_package()
{
    get_one_val opt_complete_kernel COMPLETE_KERNEL "$dir_config"/_kernel.txt > /dev/null
    if [ "$opt_complete_kernel" != no ]; then
        show_header "--- checking kernel package "
        get_one_val complete_kernel_version COMPLETE_KERNEL_VERSION "$dir_config"/_kernel.txt
        get_kernel_version

        if [ "$kernel_version" != "$complete_kernel_version" ]; then
            log_error "Mismatch between kernel version ('$kernel_version') and generated kernel package ('$complete_kernel_version')"
            show_end
            exit 1
        fi
        show_end
    fi
}
update_version ()
{
    show_header "--- updating fli4l version string "
    ver=`cat version.txt`
    version_file=opt/etc/version
    version=`cat $version_file`
    case $version in
        3.6.2)
            cwd=`pwd`
            if [ -L $version_file ]; then
                link=`readlink $version_file`
                cd `dirname $link`
                version_file=version
            fi
            if svn info $version_file > /tmp/svnver.$$ ; then
                set `grep Revision /tmp/svnver.$$`
                cd $cwd
                echo "  setting version to '$ver-rev$2'"
                echo "$ver-rev$2" > $dir_config/etc/version
            else
                cd $cwd
                echo "   ... unable to determine svn version, leaving version unchanged"
            fi
            ;;
    esac
    show_end
}

get_one_val()
{
    var=$1
    token=$2
    file="$3"
    default=$4
    cont=$5
    _tmp=`sed -n -e "s/^[[:space:]]*$token=[\"']\([^\"']*\)[\"'].*/\1/p" "$file"`
    case x$_tmp in
        x)
            if [ "$default" ]; then
                eval $var=$default
                echo "  $token='$default'"
            else
        if [ "$cont" ]; then
            return 1
        else
            abort "unable to lookup $token (and no default value present)"
        fi
            fi
            ;;
        *)
            eval $var=$_tmp
            echo "  $token='$_tmp'"
            ;;
    esac
}
get_config_values()
{
    cfg="$dir_build"/rc.cfg
    show_header "--- extracting some information from $cfg "
    get_one_val comp_type_kernel COMP_TYPE_KERNEL "$cfg" gzip
    get_one_val comp_type_rootfs COMP_TYPE_ROOTFS "$cfg" gzip
    get_one_val kernel_version   KERNEL_VERSION   "$cfg"
    get_one_val comp_type_opt    COMP_TYPE_OPT    "$cfg" bzip2
    if [ ! "$remotehostname" ]
    then
        get_one_val remotehostname HOSTNAME "$cfg"
    fi
    get_one_val bool_recover     OPT_RECOVER      "$cfg" no
    show_end
}

append_file()
{
    file="$1"
    case "x$name" in
        x) final="`echo "$file" | sed -e "s,^$prefix/,,;s,^files/,,;s,/mybin/,/bin/,;s,/mylib/,/lib/,"`" ;;
        *) final="$name" ;;
    esac

    case "$final" in
        '' | img | opt | files | opt/files ) return ;;
    esac

    case $flags in
        utxt) conversion=ufile ;;
        dtxt) conversion=dfile ;;
        sh)   conversion=$squeeze_file ;;
        *)    conversion=file  ;;
    esac

    case x$mode in
        x)
            if [ -f "$file" ]
            then
                echo "$conversion $final '$file' 644 $uid $gid"
            else
                echo "dir  $final       755 $uid $gid"
            fi
            ;;
        *)
            echo "$conversion $final '$file' $mode $uid $gid"
            ;;
    esac
}

append_my_files()
{
    dir="$1"
    set +e
    f=`ls "$dir" 2> /dev/null| grep -v dummy`
    set -e
    if [ "$f" ]
    then
        for f in $f
        do
            case $f in
                *.sh)
                    flags=utxt
                    ;;
                *)
                    flags=none
                    ;;
            esac
            append_file "$dir/$f"
        done
    fi
}

create_archive_list()
{
    while read line
    do
        mode=
        flags=
        uid=0
        gid=0
        file=
        name=
        type=file

        eval $line
        if echo $uid | grep -q '[a-zA-Z]'
        then
            uid=`grep ^$uid: opt/etc/passwd | cut -d':' -f 3`
        fi
        if echo $gid | grep -q '[a-zA-Z]'
        then
            gid=`grep ^$gid: opt/etc/group | cut -d':' -f 3`
        fi
        case "$file" in
            opt/*)
                prefix=opt
                ;;
            img/*)
                prefix=img
                ;;
            *)
                prefix="$dir_config"
                ;;
        esac
        case "$file" in
            */mybin | */mybin/ ) mode=755; append_my_files "$file" ;;
            */mylib | */mylib/ ) mode=644; append_my_files "$file" ;;
            *)                             append_file     "$file" ;;
        esac
    done
}


check_lib_deps ()
{
    if  ! perl    -v > /dev/null 2>&1 || \
        ! readelf -v > /dev/null 2>&1 ; then
        echo "        - missing perl or readelf (binutils), skipping dependency check"
        return
    fi
    if ! perl unix/scripts/check_lib_deps.pl $verbose_dep $@; then
        abort "failed library dependency check"
    fi
}

copy_kernel ()
{
    if [ -f "$dir_config"/img/kernel-$kernel_version.$1 ]
    then
        cp "$dir_config"/img/kernel-$kernel_version.$1 "$dir_build"/kernel
    else
        if [ -f img/kernel-$kernel_version.$1 ]
        then
            cp img/kernel-$kernel_version.$1 "$dir_build"/kernel
        else
            if [ $1 = "uncompressed" -a -f img/vmlinux-$kernel_version ]
            then
               cp img/vmlinux-$kernel_version "$dir_build"/kernel
            else 
                abort "Can't find kernel-$kernel_version.$1, either use a different kernel version or a different compression method."
            fi
        fi
    fi
}

get_compression ()
{
    case $1 in
        bzip2)
            compression="bzip2 -c -v9"
            ;;
        gzip)
            compression="gzip -c -9"
            ;;
        lzma)
            get_lzma_binary $2
            compression="$lzma_binary $lzma_opt"
            ;;
        *)
            abort "unknown compression mode '$1' for $2-archive"
            ;;
    esac
}

run_compression ()
{
    arch=$1
    list="$2"
    target="$3"
    log=/tmp/mkopt.$$
    if ! $arch "$list" | $compression > "$target" 2> $log ; then
        log_error "Failed to execute '$arch "$list" | $compression > "$target"'"
        append_error $log
        rm -f $log
        abort
    fi
    rm -f $log
}
#
# lzma constants
#
lzma_root_dictionary_size=20
lzma_opt_dictionary_size=20
lzma_binary=

check_lzma ()
{
    if [ ! "$lzma_binary" ]; then
        if $1 -h > /dev/null 2>&1; then
            lzma_binary=$1
            if $lzma_binary -h 2>&1 | grep -q -- '-so'; then
                lzma_root_options="e -so -si -d$lzma_root_dictionary_size"
                lzma_opt_options=" e -so -si -d$lzma_opt_dictionary_size"
            else
            # double check
                if $lzma_binary -h 2>&1 | grep -q -- '-c'; then
                lzma_root_options='-c'
                lzma_opt_options='-c'
                else
                    cat <<EOF | log_error
"Can't find lzma option for redirection to stdout,
lzma understands neither '-so' nor '-c'."

EOF
                    abort
                fi
            fi
        fi
    fi
    if [ "$lzma_binary" ]; then
        case $2 in
            root) lzma_opt="$lzma_root_options" ;;
            opt)  lzma_opt="$lzma_opt_options" ;;
            *)    abort "Unknown file type in check_lzma, aborting"
                  ;;
        esac
        return 0
    else
        return 1
    fi
}
get_lzma_binary ()
{
    for i in lzma_alone lzma; do
        if check_lzma $i $1; then
            return 0
        fi
    done
    cat <<EOF | log_error
lzma is needed to create the opt-archive and/or the rootfs.
It is either not installed or uses different option for redirection
to stdout (mkfli4l.sh expects either '-c' or '-so').
Either install lzma or fix the command line options in unix/scripts/mkopt.sh.
EOF
    abort
}

set -e

# include function to check command-line
. ./unix/scripts/parse_cmd.sh

# check parameters from commandline and current env
parse_cmdline $*

case $bool_no_squeeze in
    true) squeeze_file=ufile ;;
    *)    squeeze_file=sfile ;;
esac

mkdir -p "$dir_config/etc"
mkdir -p "$dir_build"
rm -f "$dir_build"/modules.alias "$dir_build"/modules.dep

# remove all old versions of fli4l-file in build-dir
. ./unix/scripts/_lib_cleanup.sh
cleanup_fli4lfiles

touch "$dir_config/etc/rc.cfg"

if [ "$mk_pkg" ]; then
    gen_kernel_package
elif [ -f "$dir_config"/_kernel.txt ]; then
        check_kernel_package
fi

show_header "--- check configuration in directory \"$dir_config\" "
if ! unix/mkfli4l $mkfli4l_debug_option -c "$dir_config" -t "$dir_build" -b "$dir_build" -l "$dir_build/mkfli4l.log"
then
    append_error  "$dir_build"/mkfli4l.log
    abort
else
    show_end

#
# XXX debug "space in file names" problem
# 
    if false; then
	grep "'.* .*'" "$dir_build"/opt_full.tmp > /tmp/grep.$$
	mv /tmp/grep.$$ "$dir_build"/opt_full.tmp
	echo "   using only the following files:"
	cat "$dir_build"/opt_full.tmp
    fi
    

    gen_version_info >> "$dir_build"/rc.cfg
    cp "$dir_build"/rc.cfg "$dir_config/etc/rc.cfg"

    get_config_values

    case $bool_update_ver in
        true) update_version ;;
    esac

    case $kernel_version in
        2.6*) rootfs_format=cpio ;;
        *)    rootfs_format=tar  ;;
    esac

    case $opt_type in
        integrated)
            show_header "--- build \"rootfs\" "
            echo "  building file list for root filesystem image ... "
            {
                unix/mkfli4l --2unix < img/rootfs_distrib.list
                cat <<EOF
file boot/rc.cfg '$dir_build/rc.cfg' 600 0 0
dir  lib/modules/$kernel_version 755 0 0
file lib/modules/$kernel_version/modules.dep '$dir_build/modules.dep' 600 0 0
EOF
                [ -f "$dir_build"/modules.alias ] && echo "file lib/modules/$kernel_version/modules.alias '$dir_build/modules.alias' 600 0 0"
                cat "$dir_build"/opt_full.tmp | create_archive_list
                [ -f "$dir_config"/hosts.extra ] && echo "ufile etc/hosts.extra '$dir_config/hosts.extra' 644 0 0"
                [ -f "$hostsglobalfile" ] && echo "ufile etc/hosts.global '$hostsglobalfile' 644 0 0"
            }   > "$dir_build"/rootfs.list

            echo "  checking library dependencies ... "
            check_lib_deps "$dir_build"/rootfs.list
            echo "  building root filesystem image ... "
            get_compression  $comp_type_rootfs root
            run_compression unix/gen_init_$rootfs_format "$dir_build"/rootfs.list "$dir_build"/rootfs.img
            ;;
        *)
            show_header "--- build \"rootfs\" and \"opt-archive\" "

            echo "  building file list for opt-archive ... "
            {
                grep 'archive=opt.tar' "$dir_build"/opt_full.tmp | create_archive_list
                [ -f "$dir_config"/hosts.extra ] && echo "ufile etc/hosts.extra '$dir_config/hosts.extra' 644 0 0"
                [ -f "$hostsglobalfile" ] && echo "ufile etc/hosts.global '$hostsglobalfile' 644 0 0 " 
            } > "$dir_build"/opt.list

            echo "  building file list for root filesystem image ... "
            {
                unix/mkfli4l --2unix < img/rootfs_distrib.list
                cat <<EOF
dir  lib/modules/$kernel_version 755 0 0
file lib/modules/$kernel_version/modules.dep '$dir_build/modules.dep' 600 0 0
EOF
                [ -f "$dir_build"/modules.alias ] && echo "file lib/modules/$kernel_version/modules.alias '$dir_build/modules.alias' 600 0 0"
                grep 'archive=rootfs.tar' "$dir_build"/opt_full.tmp | create_archive_list
                case $opt_type in
                    attached) echo "file boot/opt.img '$dir_build/opt.img' 600 0 0" ;;
                esac
            }  > "$dir_build"/rootfs.list
            
            echo "  checking library dependencies ... "
            check_lib_deps "$dir_build"/rootfs.list  "$dir_build"/opt.list
            echo "  building opt-archive ... "
            case $opt_type in
                tar) compression=cat ;;
                *)   get_compression $comp_type_opt opt ;;
            esac
            run_compression unix/gen_init_tar "$dir_build"/opt.list "$dir_build"/opt.img

            echo "  building root filesystem image ... "
            get_compression  $comp_type_rootfs root
            run_compression unix/gen_init_$rootfs_format "$dir_build"/rootfs.list "$dir_build"/rootfs.img
            ;;
    esac

    show_end

    case $comp_type_kernel in
        bzip2)
            copy_kernel bz2
            ;;
        lzma)
            copy_kernel lzma
            ;;
        uncompressed)
            copy_kernel uncompressed
            ;;
        *)
            copy_kernel gz
            ;;
    esac

    # copy needed file for recover to build-dir
    case $bool_recover in
        yes)
            cp img/boot.msg "$dir_build"/BOOT.MSG
            cp img/boot_s.msg "$dir_build"/BOOT_S.MSG
            cp img/boot_z.msg "$dir_build"/BOOT_Z.MSG
            ;;
    esac

    show_header "--- generating md5 sums"
    rc_md5="`md5sum \"$dir_build\"/rc.cfg`"
    gen_md5_sums $rc_md5 >> "$dir_build"/rc.cfg
    grep ^FLI4L_MD5_ "$dir_build"/rc.cfg
    show_end
fi

cleanup

echo "creation of all build-files finished..."
echo ""

# be paranoid and set tmp_dir again
# vim: set ts=8 sw=4 sts=4:
