Database Migration Tool
This PowerShell script is designed to streamline the process of migrating a database by detaching an existing database and attaching a new one with the same name. This is particularly useful when you have a new version of a database file (e.g., a .mdf file) and want to swap it into an existing SQL Server instance without causing data conflicts.

How It Works
The script automates the following steps:

Prompts for Credentials: It will ask you to enter the SQL Instance name, a database admin username, and a password.

File Selection: A file dialog will open, prompting you to select the .mdf file for the new database.

Database Detachment: It checks for any existing database with the same name and safely detaches it.

Database Attachment: It then attaches the newly selected database file.

Orphan Fix (Optional): If a specific script is found, it will automatically run it to fix any orphaned users in the new database.

Prerequisites
You must have Sysadmin privileges on the SQL Server instance to run this tool.

The sqlcmd utility must be available in your system's path.

Optional: Orphan Fix Script
The script can automatically run a fix for orphaned users. To use this feature, simply place a SQL script in the same directory as the PowerShell script and name it orphan_fix.sql. The tool will detect and execute this script on the newly attached database.

Troubleshooting
File Permissions Error
If you see an error related to file permissions during the attach process, it means the SQL admin user does not have the necessary rights to the .mdf and .ldf files.

Recommendation: Manually grant Full Control permissions to the database owner or the SQL Server service account for the database files before running the script.
