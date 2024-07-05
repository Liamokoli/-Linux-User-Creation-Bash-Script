Bash
#!/bin/bash

# Script to create users and groups from a file

# Define log file and password storage locations
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Prompt for user data file name
read -p "Enter the name of the file containing user data: " filename

# Check if the provided file exists
if [ ! -f "$filename" ]; then
  echo "Error: File '$filename' does not exist." >&2
  exit 1
fi

# Function to create user and log actions
create_user() {
  username="$1"
  groups="$2"

  # Check if group exists, create it if not
  if ! getent group "$username" >/dev/null 2>&1; then
    if ! groupadd "$username" 2>> "$LOG_FILE"; then
      echo "Failed to create group '$username'." >&2
      return 1
    fi
  fi

  # Create user with home directory
  if ! useradd -M -g "$username" -s /bin/bash "$username" 2>> "$LOG_FILE"; then
    echo "Failed to create user '$username'." >&2
    return 1
  fi

  # Set home directory permissions
  if ! chown -R "$username:$username" "/home/$username" 2>> "$LOG_FILE"; then
    echo "Failed to set permissions for '$username' home directory." >&2
    return 1
  fi

  # Generate random password
  password=$(head /dev/urandom | tr -dc A-Za-z0-9 | fold -w 12 | head -n 1)

  # Set user password
  if ! echo "$username:$password" | chpasswd 2>> "$LOG_FILE"; then
    echo "Failed to set password for user '$username'." >&2
    return 1
  fi

  # Log user creation and password
  echo "Created user: $username (password: $password)" >> "$LOG_FILE"
  echo "$username,$password" >> "$PASSWORD_FILE"

  # Add user to additional groups (if any)
  for group in $(echo "$groups" | tr ',' ' '); do
    if ! usermod -a -G "$group" "$username" 2>> "$LOG_FILE"; then
      echo "Failed to add user '$username' to group '$group'." >&2
    fi
  done

  return 0
}

# Loop through each line in the provided file
while IFS=';' read -r username groups; do
  # Remove leading/trailing whitespace from username and groups
  username="${username##* }"
  username="${username%% *}"
  groups="${groups##* }"
  groups="${groups%% *}"

  # Create user and handle errors
  if ! create_user "$username" "$groups"; then
    echo "An error occurred while creating user '$username'." >&2
  fi
done < "$filename"

# Script completion message
echo "User creation script completed. Check $LOG_FILE for details."

# Set permissions for password file (owner-read only)
chmod 600 "$PASSWORD_FILE"