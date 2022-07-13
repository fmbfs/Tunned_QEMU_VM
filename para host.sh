process_args() {
    # process all input arguments
    for i in "$@"; do
        case "$1" in
        "-h"|"--help"
            print_help
            HELP=true
            exit 0 
            ;;
        --config-file=*)
        #criar comment no grub com esta variavel e o caminho
            CONFIG_JSON_PATH="${i#*=}"
            shift 
            ;;
        "--setup")
            SETUP=false
            shift
            ;;
        "--unsetup")
            UNSETUP=true
            shift
            ;;
        *)
            print_error "Unrecognised option: ${i}"
            shift
            ;;
        esac
    done
}