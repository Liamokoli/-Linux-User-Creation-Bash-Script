#!/bin/bash

# Define script location for logging purposes
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
  echo "Error: Log directory does not exist. Creating /var/log/user_management.log..."
  sudo mkdir -p "$(dirname "$LOG_FILE")"
fi

if [[ ! -d "$(dirname "$PASSWORD_FILE")" ]]; then
  echo "Error: Secure password directory does not exist. Creating /var/secure/user_passwords.txt..."
  sudo mkdir -p "$(dirname "$PASSWORD_FILE")"
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
    echo "Warning: Group '$username' already exists. Skipping group creation."
  else
    echo "[`date +%Y-%m-%d-%H:%M:%S`] Created group: $username"
  fi

  # Check if user already exists
  if id -u "$username" >/dev/null 2>&1; then
    echo "Warning: User '$username' already exists."
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
          echo "Error: Failed to add user '$username' to group: $group"
        fi
      done

      # Set user password (securely piped to passwd with one-way hashing)
      echo "$password" | mkpasswd -s - | sudo passwd --stdin "$username" &>/dev/null

      # Store username and hashed password in secure file (comma-separated)
      echo "$username,$(echo "$password" | mkpasswd -s)" >> "$PASSWORD_FILE"
      echo "[`date +%Y-%m-%d-%H:%M:%S`] Generated password for user: $username"
    else
      echo "Error: Failed to create user: $username (check system logs for details)"
    fi
  fi
done < "$1"

# Close log file
exec >> /dev/tty

echo "Script execution complete. Refer to the log file for details: $LOG_FILE