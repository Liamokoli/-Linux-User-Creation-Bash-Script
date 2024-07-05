Bash
#!/bin/bash

# Script location for logging purposes
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Define log file path
LOG_FILE="$SCRIPT_DIR/../var/log/user_management.log"

# Define secure password file path (using one-way hashing)
PASSWORD_FILE="$SCRIPT_DIR/../var/secure/user_passwords.txt"

# Function to generate a random password
generate_password() {
  length=16
  cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:\'\",./<>?' | fold -w $length | head -n 1
}

# Check if required directories exist
if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
  echo "Creating log directory: /var/log/user_management.log"
  sudo mkdir -p "$(dirname "$LOG_FILE")" &>/dev/null
  if [[ $? -eq 0 ]]; then
    echo "Log directory created successfully."
  else
    echo "Error: Failed to create log directory. Please check permissions."
    exit 1
  fi
fi

if [[ ! -d "$(dirname "$PASSWORD_FILE")" ]]; then
  echo "Creating secure password directory: /var/secure/user_passwords.txt"
  sudo mkdir -p "$(dirname "$PASSWORD_FILE")" &>/dev/null
  if [[ $? -eq 0 ]]; then
    echo "Secure password directory created successfully."
  else
    echo "Error: Failed to create secure password directory. Please check permissions."
    exit 1
  fi
fi

# Check if user has sudo privileges (needed for some commands)
if ! sudo -n true >/dev/null 2>&1; then
  echo "Error: This script requires sudo privileges. Please run with sudo."
  exit 1
fi

# Check if input file exists
if [[ ! -f "$1" ]]; then
  echo "Error: Input file '$1' does not exist."
  exit 1
fi

# Open log file for appending
exec >> "$LOG_FILE" 2>&1

# Process each line in the input file
while IFS=';' read -r username groups; do
  # Remove leading/trailing whitespace
  username="${username##*( )}"
  groups="${groups##*( )}"

  # Create user's personal group
  if ! sudo groupadd "$username" &>/dev/null; then
    echo "[`date +%Y-%m-%d-%H:%M:%S`] Warning: Group '$username' already exists. Skipping group creation."
  else
    echo "[`date +%Y-%m-%d-%H:%M:%S`] Created group: $username"
  fi

  # Check if user already exists
  if id -u "$username" >/dev/null 2>&1; then
    echo "[`date +%Y-%m-%d-%H:%M:%S`] Warning: User '$username' already exists. Skipping user creation."
  else
    # Generate random password
    password=$(generate_password)

    # Create user with home directory
    sudo useradd -m -s /bin/bash "$username" &>/dev/null

    if [[ $? -eq 0 ]]; then
      echo "[`date +%Y-%m-%d-%H:%M:%S`] Created user: $username (home: /home/$username)"
      # Set ownership and permissions on home directory
      sudo chown -R "$username:$username" "/home/$username"
      sudo chmod 700 "/home/$username"

      # Add user to groups (including personal group)
      user_groups=("$username" $groups)
      for group in "${user_groups[@]}"; do
        if sudo usermod -a -G "$group" "$username" &>/dev/null; then
          echo "[`date +%Y-%m-%d-%H:%M:%S`] Added user '$username' to group: $group"
        else
          echo "[`date +%Y-%m-%d-%H:%M:%S`] Error: Failed to add user '$username' to group: $group"
        fi
      done

      # Set user password (securely piped to passwd with one-way hashing)
      echo "$password" | mkpasswd -s - | sudo passwd --stdin "$username" &>/dev/null

      # Store username