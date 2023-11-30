echo -n Clearing machine

clean_record() {
    rm -rf /opt/vnoi/misc/records/*
}

reset_home() {
    rm -rf /home
    mkdir /home
    cd /home
    cp -r /etc/skel /home/vnoi && chown -R vnoi:vnoi /home/vnoi
}

help() {
    echo "Usage: $0 [desktop|record|all|help]"
    echo "desktop: reset /home/vnoi to default"
    echo "record: clean all records"
    echo "all: do both"
    echo "help: show this help"
}

case $1 in
    desktop)
        reset_home
        ;;
    record)
        clean_record
        ;;
    all)
        reset_home
        clean_record
        ;;
    help)
        help
        ;;
    '')
        help
        ;;
    *)
        help
        ;;
esac

echo "Done"
