# ctw

HTF -- Host Fine Tune
QFT -- Qemu Fine Tune


~/Desktop/git/ctw$ git add .

~/Desktop/git/ctw$ git commit -m "qemu_script"

~/Desktop/git/ctw$ git push


git push origin HEAD:refs/for/master


git branch lista os branches

git log para ver os commits


Passar para a main
	
    1. git checkout main 
    2. git merge testes 
    3. git push origin main 


QEMU_ARGS=( \
"-monitor" "null" \
"-object" "rng-random,filename=/dev/random,id=rng0" \
"-device" "virtio-rng-pci,rng=rng0" \
"-device" "virtio-keyboard-pci" \
"-cpu" "cortex-a57" \
"-smp" "3" \
"-machine" "type=virt" \
"-m" "4G" \
"-nodefaults" \
"-serial" "mon:stdio" \
"-kernel" "${KERNEL}" \
"-drive" "file=${IMAGE_CONTAINER},id=disk0,format=raw,if=none,cache=none" \
"-device" "virtio-blk-pci,drive=disk0" \
)



