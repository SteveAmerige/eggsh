#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

Usage()
{
    echo "
USAGE: $PROGRAM [OPTIONS]
    -a                  Automatically set all defaults
                        If this option is used, no other options are required

    -p <payloadDir>     Payload directory   ($PAYLOAD_DIR)
                        All payload content is located in and under this directory.
                        This entire directory is archived in the self-extracting installer.

    -i <installer>      Installer           ($INSTALLER)
                        This option specifies the path to the installer relative to the <payloadDir>.

    -o <outputPath>     Output path         ($OUTPUT_PATH)
                        Place the self-extracting installer here.
                        It is recommended that the installer end with '.bin'

    -v                  Verbose             ($VERBOSE)
    -h                  Display this help

Create a self-extracting installer.
"
    Quit "$@"
}

PROGRAM=$(basename "$0")

Quit()
{
   if [[ $# -gt 0 ]] ; then
      echo "$1"
      if [[ $# -gt 1 ]]; then
         exit $2
      fi
   fi

   rm -rf "$TMP_DIR"
   exit 0
}

trap Quit 1 2 3 4 5 6 7 8 9 10 11 12 13 14 14 15

Echo()
{
   if $VERBOSE; then
      echo "$@"
   fi
}

PAYLOAD_DIR=.
INSTALLER=installer.sh
OUTPUT_PATH=selfextract.bin
VERBOSE=false
OPTIONS_SET=false

if [[ $# -eq 0 ]]; then
   Usage
fi

while getopts "ap:i:o:hv" ARG
do
    case $ARG in
    a) OPTIONS_SET=true; shift $((OPTIND-1)); OPTIND=1;;
    p) OPTIONS_SET=true; PAYLOAD_DIR=$OPTARG; shift $((OPTIND-1)); OPTIND=1;;
    i) OPTIONS_SET=true; INSTALLER=$OPTARG; shift $((OPTIND-1)); OPTIND=1;;
    o) OPTIONS_SET=true; OUTPUT_PATH=$OPTARG; shift $((OPTIND-1)); OPTIND=1;;
    v) OPTIONS_SET=true; VERBOSE=true;;
    h) Usage;;
    *) Usage "Unrecognized argument: $ARG" 1;;
    esac
done

OUTPUT_DIR=$(readlink -f $(dirname "$OUTPUT_PATH"))
TMP_DIR=$(mktemp -d -p "$OUTPUT_DIR" "selfextract.XXXXXXXXXXX")

if $OPTIONS_SET ; then
    cd "$PAYLOAD_DIR"
    echo "Building archive in: $TMP_DIR/payload.tar..."
    tar cpf "$TMP_DIR/payload.tar" .

    echo "Assembling archive as: $TMP_DIR/selfextract.sh..."
    (
######################################################################
        cat << xxxENDxxx
#!/bin/bash

export BIN_INSTALLER=\$(readlink -f "\${BASH_SOURCE[0]}")

Usage()
{
    echo "
USAGE: \$PROGRAM [OPTIONS]
    -r                  Run $INSTALLER (default)

    -x <payloadDir>     Extract to a payload directory (must not exist); doesn't run $INSTALLER
    -o <payloadDir>     Overwrite into a payload directory; doesn't run $INSTALLER

    -v                  Verbose             (\$VERBOSE)
    -h                  Display this help

Execute a self-extracting installer. Typically, this program is run without options.
"
    Quit "\$@"
}

PROGRAM=\$(basename "\$0")

Quit()
{
   sudo rm -rf "\$TMPDIR"

   if [[ \$# -gt 0 ]] ; then
      echo "\$1"
      if [[ \$# -gt 1 ]]; then
         exit \$2
      fi
   fi

   exit 0
}

trap Quit 1 2 3 4 5 6 7 8 9 10 11 12 13 14 14 15

Echo()
{
   if \$VERBOSE; then
      echo "\$@"
   fi
}

ACTION="run"
VERBOSE=false
PAYLOAD_DIR="\$HOME/$(basename \$0 .bin)"
TMPDIR=\$(mktemp -d -p "\$HOME" "createinstaller.XXXXXXXXXXX")

while getopts "rx:X:hv" ARG
do
    case \$ARG in
    r) ACTION=run; shift \$((OPTIND-1)); OPTIND=1;;
    x) ACTION=extract; PAYLOAD_DIR=\$OPTARG; shift \$((OPTIND-1)); OPTIND=1;;
    X) ACTION=extractOverwrite; PAYLOAD_DIR=\$OPTARG; shift \$((OPTIND-1)); OPTIND=1;;
    v) VERBOSE=true; shift \$((OPTIND-1)); OPTIND=1;;
    h) Usage;;
    *) Usage "Unrecognized argument: \$ARG" 1;;
    esac
done

ARCHIVE=\$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' \$0)

echo "Validating archive..."
tail -n+\$ARCHIVE "\$0" | sudo tar xp -C \$TMPDIR

THIS_DIR=\$(pwd)

cd "\$TMPDIR"
case "\$ACTION" in
run)
   Echo "Running installer..."
   sh "$INSTALLER" "\$@"
   ;;
extract)
   if [[ -d "\$PAYLOAD_DIR" ]]; then
      Quit "Payload directory already exists: \$PAYLOAD_DIR; Use -X to overwrite"
   fi
   mkdir -p "\$PAYLOAD_DIR" || Quit "Cannot create payload directory: \$PAYLOAD_DIR"
   Echo "Extracting payload to new directory..."
   (cd \$TMPDIR; tar cpf - .)|(cd "\$PAYLOAD_DIR"; sudo tar xpf -)
   ;;
extractOverwrite)
   Echo "Extracting payload with overwrite..."
   mkdir -p "\$PAYLOAD_DIR" || Quit "Cannot create payload directory: \$PAYLOAD_DIR"
   (cd \$TMPDIR; tar cpf - .)|(cd "\$PAYLOAD_DIR"; sudo tar xpf -)
   ;;
*)
   Usage
   ;;
esac

cd "\$THIS_DIR"

sudo rm -rf "\$TMPDIR"

Quit

__ARCHIVE_BELOW__
xxxENDxxx
######################################################################
        cat "$TMP_DIR/payload.tar"
    ) > "$TMP_DIR/selfextract.sh"

    echo "Finalizing self-extracting archive as: $OUTPUT_PATH..."
    mv -f "$TMP_DIR/selfextract.sh" "$OUTPUT_PATH"
    chmod 755 "$OUTPUT_PATH"

    echo "Done."
fi

Quit
