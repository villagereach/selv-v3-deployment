## **Creating database backups in the SELV-V3**

This folder (backup_database) reflects the structure of the files that are on the production instance for database backup. The folder contains:

**- file pg_backup.config:** the file contains variable settings used in other scripts

**- file pg_backup_rotated.sh:** the main script that create database backups and then saves them in the backup_files folder. The script creates three types of backups:
	1. monthly - created on the first day of the month - never deleted
	2. weekly - created on the sixth day of the week - deleted after 35 days
	3. daily - created on other days - deleted after 7 days
	Settings when a given backup type is created and deleted are specified in the pg_backup.config file.

**- file aws_s3_sync_download.sh:** this script is called before backup. The task of this script is to download data from the AWS S3 bucket to the backup_files folder.

**- file aws_s3_sync_upload.sh:** this script is called after the backup. The task of this script is to send data from the backup_files folder to AWS S3 bucket.

**- file backup_files:** directory to which data from aws s3 are synchronized

**CRON**

Above scripts are run daily using cron. 
You can edit cron jobs to change time when the backups are created or to change time when the backups should be sent to S3. 
Use `crontab -e` command to edit cron tasks.