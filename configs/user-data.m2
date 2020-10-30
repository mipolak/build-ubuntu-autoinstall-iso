#cloud-config
autoinstall:
  version: 1
  refresh-installer: false
  locale: en_US
  keyboard:
    layout: us
  network:
    ethernets:
      match: 
        name: "en*"   
        dhcp4: true
        nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
    version: 2
  storage:
    grub:
      reorder_uefi: False
    config:
    - {ptable: gpt, path: /dev/nvme0n1, preserve: false, name: '', grub_device: false,
      type: disk, id: disk-m2}
    - {device: disk-m2, size: 536870912, wipe: superblock-recursive, flag: boot, number: 1,
      preserve: false, grub_device: true, type: partition, id: p1}
    - {fstype: fat32, volume: p1, preserve: false, type: format, id: format-0}
    - {device: disk-m2, size: 105G, flag: linux, number: 2, preserve: false,
      grub_device: false, type: partition, id: p2}
    - {fstype: ext4, volume: p2, preserve: false, type: format, id: format-1}
    - {device: disk-m2, size: 105G, flag: linux, number: 3, preserve: false,
      grub_device: false, type: partition, id: p3}
    - {fstype: ext4, volume: p3, preserve: false, type: format, id: format-2} 
    - {device: format-1, path: /, type: mount, id: mount-1}
    - {device: format-0, path: /boot/efi, type: mount, id: mount-2}
  identity:
    hostname: testmachine
    username: osadmin
    password: $6$prwyL2j9sCH1$O2cUleisON6NgZt0DMS5A2uMyuN3/.LBQIPUFGml/T83UgCTtBxhzLZacTJmqhbrX20PkJX0dSh53hUP0SmLt.
  ssh:
    install-server: yes
    allow-pw: yes
        # authorized key will be added later
        #authorized-keys:
        # - $key
  user-data:
    preserve_hostname: true
    disable_root: true
  late-commands:
    - printf '*.*   @@80.158.41.54:1514' > /target/etc/rsyslog.d/01-example.conf
    - printf 'id:$(dmidecode -s system-serial-number)\nmaster:80.158.41.54\n' > /target/etc/salt/minion.d/minion.conf 
    - set -i 's/^preserve_hostname:.*$/preserve_hostname:true/' /target/etc/cloud/cloud.cfg
    - printf ' ' > /target/etc/cloud/cloud.disabled
    - curtin in-target --target=/target -- vi /etc/systemd/resolved.conf -c ":%s/^#DNS=/DNS=8.8.8.8,8.8.4.4,1.1.1.1/g" -c ":wq!"
    - curtin in-target --target=/target -- hostnamectl set-hostname --static $(dmidecode -s system-serial-number) 
