
#!/bin/bash
mount /dev/sdc1 /mnt/backup || exit 1
rsync -av --delete /data/ /mnt/backup/data/
sync
umount /mnt/backup
