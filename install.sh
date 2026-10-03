cd "$(dirname "$(readlink -f "$0")")" || exit 1
[ -d "$HOME/storage" ] || termux-setup-storage || true
bash cioweb3apk.sh link
bash cioweb3apk.sh setup
echo
echo "Done. Start with:  cioweb3apk    (or: bash cioweb3apk.sh)"
