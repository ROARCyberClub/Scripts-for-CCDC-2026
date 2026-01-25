# Palt_User_mang.py

Automated Authentication: Generates and manages API keys using your firewall credentials.

User Auditing: Lists current administrative users and their assigned roles.

CRUD Operations:

Create new superusers.

Update passwords for existing users.

Delete administrative accounts.

Commit Management: Push changes from the "Candidate Configuration" to the "Running Configuration" without leaving the script.

Secure Input: Uses getpass to ensure passwords are not masked/hidden during entry.

To install and run this script, follow these four steps:

Ensure Python is installed: Make sure you have Python 3.6+ on your system.

Download the script: Clone this repository or download the .py file to your local machine.

Install the requirement: Open your terminal and install the requests library.

# fdm.py

Token-Based Authentication: Implements the FTD OAuth2 flow to securely retrieve and use access tokens.

User Management:

List: View all system users, their roles, and unique IDs.

Create: Add new users with specific roles (ADMIN, READ_WRITE, READ_ONLY).

Update: Modify passwords for existing accounts (automatically handles UUID lookups).

Delete: Remove administrative users (with safety checks to prevent deleting the default 'admin').

Deployment Integration: Trigger an FTD "Deployment" job to move changes from the pending state to the running configuration.

Secure Input: Uses getpass to ensure sensitive credentials are not echoed to the terminal.

Verify Python: Ensure you have Python 3.6+ installed on your system.

Download the script: Clone the repository or save the code as a .py file (e.g., ftd_manager.py).

Install requirements: Open your terminal or command prompt and install the requests library.

