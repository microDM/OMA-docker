#!/bin/bash

xhost +local:docker

# Start user-space DBus if not running
if ! pgrep -x "dbus-daemon" > /dev/null; then
    echo "Starting user-space DBus service..."
    mkdir -p "$HOME/.dbus"
    dbus-daemon --session --fork --print-address > "$HOME/.dbus/session_bus_address"
fi

# Export DBus address if not set
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    export DBUS_SESSION_BUS_ADDRESS=$(cat "$HOME/.dbus/session_bus_address")
    echo "DBUS_SESSION_BUS_ADDRESS set to $DBUS_SESSION_BUS_ADDRESS"
fi

# Overlay directory
overlay_dir="/media/volume/OMA_container/overlays"
overlay_path="$overlay_dir/overlay_$USER.img"

# Create individual overlay if it does not exist
if [ ! -f "$overlay_path" ]; then
    echo "Creating overlay for $USER..."
    mkdir -p "$overlay_dir"
    dd if=/dev/zero of="$overlay_path" bs=1M count=20480 && \
    mkfs.ext3 "$overlay_path"
fi

# Check if the overlay creation succeeded
if [ ! -f "$overlay_path" ]; then
    echo "Failed to create overlay for $USER. Exiting."
    exit 1
fi

# Workspace directory for the user
workspace_base="/media/volume/Workspaces/users"
workspace_path="$workspace_base/$USER"

# Create the workspace if it doesn't exist
if [ ! -d "$workspace_path" ]; then
    echo "Creating workspace for $USER..."
    mkdir -p "$workspace_path"
fi

# Ensure shared project directory exists
proj_path="/media/volume/project_2013220"
if [ ! -d "$proj_path" ]; then
    echo "Shared project directory not found at $proj_path. Exiting."
    exit 1
fi

# Set DISPLAY if missing
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
    echo "DISPLAY not found, setting DISPLAY=:0"
fi

# Launch RStudio Desktop inside Apptainer with shared and isolated mounts
echo "Launching RStudio Desktop for $USER..."
apptainer exec --fakeroot \
    --overlay "$overlay_path" \
    --bind "$workspace_path:/mnt/volume" \
    --bind "$proj_path:/mnt/shared_projects:ro" \
    --bind "/home/$USER:/mnt/home/$USER" \
    --workdir "/tmp/$USER/apptainer_session" \
    microbiome_oma_rstudio_updated.sif rstudio --no-sandbox --disable-gpu &

echo "RStudio Desktop launched successfully for $USER."
echo "User workspace: /mnt/volume"
echo "Shared projects: /mnt/shared_projects"