#cloud-config
autoinstall:
  version: 1
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
    - {ptable: gpt, path: /dev/nvme0n1, wipe: superblock-recursive, preserve: false, 
      name: '', grub_device: false, type: disk, id: disk-nvme0n1}
    - {device: disk-nvme0n1, size: 536870912, wipe: superblock, flag: boot, number: 1,
      preserve: false, grub_device: true, type: partition, id: partition-0}
    - {fstype: fat32, volume: partition-0, preserve: false, type: format, id: format-0}
    - {device: disk-nvme0n1, size: 112742891520, wipe: superblock, flag: '', number: 2,
      preserve: false, type: partition, id: partition-1}
    - {fstype: ext4, volume: partition-1, preserve: false, type: format, id: format-1}
    - {device: format-1, path: /, type: mount, id: mount-1}
    - {device: disk-nvme0n1, size: 112742891520, wipe: superblock, flag: '', number: 3,
      preserve: false, type: partition, id: partition-2}
    - {fstype: ext4, volume: partition-2, preserve: false, type: format, id: format-2}
    - {device: format-0, path: /boot/efi, type: mount, id: mount-0}
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
