#!/bin/bash -e
# download non-RPM files from http://vault.centos.org/7.4.1708/os/x86_64/

if [ $# -lt 2 ]; then
    echo "$0 <other_download_list.ini> <save_path> [<force_update>]"
    exit -1
fi

download_list=$1
if [ ! -e $download_list ];then
    echo "$download_list does not exist, please have a check!!"
    exit -1
fi

save_path=$2
url_prefix="http://vault.centos.org/7.4.1708/os/x86_64/"
echo "NOTE: please assure Internet access to $url_prefix !!"

force_update=$3

i=0
all=`cat $download_list`
for ff in $all; do
    ## skip commented_out item which starts with '#'
    if [[ "$ff" =~ ^'#' ]]; then
        echo "skip $ff"
        continue
    fi
    _type=`echo $ff | cut -d":" -f1-1`
    _name=`echo $ff | cut -d":" -f2-2`
    if [ "$_type" == "folder" ];then
        mkdir -p $save_path/$_name
    elif [ -e "$save_path/$_name" ];then
        echo "Already have $save_path/$_name"
        continue
    else
        echo "remote path: $url_prefix/$_name"
        echo "local path: $save_path/$_name"
        if wget $url_prefix/$_name; then
            file_name=`basename $_name`
            sub_path=`dirname $_name`
            if [ -e "./$file_name" ]; then
                let i+=1
                echo "$file_name is downloaded successfully"
                mv -f ./$file_name $save_path/$_name
                ls -l $save_path/$_name
            fi
        else
            echo "ERROR: failed to download $url_prefix/$_name"
        fi
    fi
done

echo "totally $i files are downloaded!"

