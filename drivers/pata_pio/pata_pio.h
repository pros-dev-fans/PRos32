#ifndef PATA_PIO_H
#define PATA_PIO_H

#define PATA_PIO_PRIMARY_IO       0x1F0
#define PATA_PIO_CONTROL          0x3F6
#define PATA_PIO_REG_DATA         PATA_PIO_PRIMARY_IO + 0x00
#define PATA_PIO_REG_ERROR        PATA_PIO_PRIMARY_IO + 0x01
#define PATA_PIO_REG_FEATURES     PATA_PIO_PRIMARY_IO + 0x01
#define PATA_PIO_REG_SECTOR_COUNT PATA_PIO_PRIMARY_IO + 0x02
#define PATA_PIO_REG_LBA_LOW      PATA_PIO_PRIMARY_IO + 0x03
#define PATA_PIO_REG_LBA_MID      PATA_PIO_PRIMARY_IO + 0x04
#define PATA_PIO_REG_LBA_HIGH     PATA_PIO_PRIMARY_IO + 0x05
#define PATA_PIO_REG_DRIVE        PATA_PIO_PRIMARY_IO + 0x06
#define PATA_PIO_REG_STATUS       PATA_PIO_PRIMARY_IO + 0x07
#define PATA_PIO_REG_COMMAND      PATA_PIO_PRIMARY_IO + 0x07

#define PATA_PIO_CMD_READ_SECTORS  0x20
#define PATA_PIO_CMD_WRITE_SECTORS 0x30
#define PATA_PIO_CMD_STANDBY       0xE2

#define PATA_PIO_STATUS_ERR 0x01
#define PATA_PIO_STATUS_DRQ 0x08
#define PATA_PIO_STATUS_BSY 0x80

#define PATA_PIO_MASTER 0xE0

#endif // PATA_PIO_H
