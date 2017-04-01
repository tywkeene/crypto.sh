
#!/usr/bin/env bash

set -e

function yesno() {
    read -p "$1 Continue? (y/n): "
    case $(echo -e "$REPLY" | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function warning(){
    if [[ "yes" == $(yesno "!!!THIS WILL SHRED AND DELETE THIS FILE!!!") ]]; then
        return
    else
        printf "Okay\n"
        exit -1
    fi
}

function recursive_shred(){
    warning
    printf "Shredding directory '$1'...\n"
    for file in $(ls $1); do
        if [ -d ./$1/$file ]; then
            recursive_shred ./$1/$file
        else
            shred -vfzu -n 32 ./$1/$file >/dev/null 2>&1
        fi
    done
}

function pack(){
    if [ -d $1 ]; then
        tar -czvf $1.tar.gz $1 >/dev/null 2>&1
        recursive_shred $1
        rm -rf $1
    fi
}

function unpack(){
    if [ -z $(gunzip -t $1 >/dev/null 2>&1) ]; then
        tar -xvpf $1 >/dev/null 2>&1
        rm -f $1
    fi
}

function encrypt(){
    if [ -z "$1" ]; then
        printf "filename to encrypt required\n"
        exit -1
    fi

    if [ -d $1 ]; then
        INFILE=$1.tar.gz
        OUTFILE=$1.tar.gz.x
        printf "Packing and encrypting directory $INFILE to $OUTFILE ...\n"
        pack $1
    else
        INFILE=$1
        OUTFILE=$1.x
        printf "Encrypting file $INFILE to $OUTFILE ...\n"
    fi

    gpg --output $OUTFILE --symmetric --cipher-algo AES256 $INFILE

    if [ -d $INFILE ]; then
        recursive_shred $INFILE
    else
        warning
        printf "Shredding file $INFILE\n"
        shred -vfzu -n 32 $INFILE >/dev/null 2>&1
    fi

    exit 0
}

function decrypt(){
    if [ -z "$1" ]; then
        printf "filename to decrypt required\n"
        exit -1
    fi
    OUTFILE=$(basename -s .x $1)
    printf "Decrypting $1 to $OUTFILE ...\n"
    gpg  --output $OUTFILE --decrypt $1
    unpack $OUTFILE
    exit 0
}

function usage(){
    printf "$0 -e[ncrypt] <infile> - to encrypt, overwrite, and delete file\n"
    printf "$0 -d[ecrypt] <infile> - to decrypt file\n"
    exit 0
}

if [ -z "$1" ]; then
    usage
    exit -1
fi

while getopts "he:d:" opt; do
    case "$opt" in
        h) usage
            exit 0
            ;;
        e) encrypt $2
            exit 0
            ;;
        d) decrypt $2
            exit 0
            ;;
    esac
done
