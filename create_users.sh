Bash
#!/bin/bash

# Script location for logging purposes
SCRIPT_DIR="<span class="math-inline">\( cd "</span>( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Define log file path
LOG_FILE="$SCRIPT_DIR/../var/log/user_management.log"

# Define secure password file path (using one-way hashing)
PASSWORD_FILE="<span class="math-inline">SCRIPT\_DIR/\.\./var/secure/user\_passwords\.txt"
\# Function to generate a random password
generate\_password\(\) \{
length\=16
cat /dev/urandom \| tr \-dc 'A\-Za\-z0\-9\!@\#</span>%^&*()_+-=[]{}|;:\'\",./<>?' | fold -w $length | head -n 1
}

# Check if the script is run with a file argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <user-file>"
  exit 1
fi

# Define input file path
USER_FILE="$1"

# Create log and password files if they don't exist
touch "<span class="math-inline">LOG\_FILE"
mkdir \-p "</span>(dirname "$PASSWORD_FILE")" &>/dev/null
touch "$PASSWORD_FILE"
chmod 600 "<span class="math-inline">PASSWORD\_FILE"
log\_action\(\) \{
echo "</span>(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "<span class="math-inline">LOG\_FILE"
\}
\# Process each line in the input file
while IFS\=';' read \-r username groups; do
\# Remove leading and trailing whitespace
username\=</span>(echo <span class="math-inline">username \| xargs\)
groups\=</span>(echo $groups | xargs)

  # Check if user already exists
  if id "$username" &>/dev/null; then
    log_action "User $username already exists."
  else
    # Create personal group for the user
    groupadd "$username" &>/dev/null
    # Create user with home directory and personal group
    useradd -m -g "$username" -s /bin/bash "$username"
    if [ $? -eq 0 ]; then
      log_action "User $username created."
    else
      log_action "Failed to create user $username."
      continue
    fi

    # Set home directory permissions
    chmod 700 "/home/$username"
    chown "$username:$username" "/home/<span class="math-inline">username"
\# Generate and set password \(securely piped to chpasswd\)
password\=</span>(generate_password)
    echo "<span class="math-inline">username\:</span>(mkpasswd -s <<<"$password")" | chpasswd
    log_action "Password set for $username."

    # Store username and hashed password (consider one-way hashing here)
    echo "<span class="math-inline">username,</span>(mkpasswd -s <<<"$password")" >> "$PASSWORD_FILE"

    # Add user to additional groups
    IFS=',' read -ra group