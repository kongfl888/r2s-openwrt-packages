
if [ `grep -c "CONFIG_BRIDGE_NETFILTER=y" kernel/arch/arm64/configs/nanopi-r2_linux_defconfig` -eq 0 ]; then
    sed -i '/CONFIG_BRIDGE_NETFILTER/d' kernel/arch/arm64/configs/nanopi-r2_linux_defconfig >/dev/null 2>&1
    echo "CONFIG_BRIDGE_NETFILTER=m" >> kernel/arch/arm64/configs/nanopi-r2_linux_defconfig
fi
