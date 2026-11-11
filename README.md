# Elastic ROS 2 Viewer

A read-only ROS 2 viewer built on the [Elastic Dashboard](https://github.com/Gold872/elastic_dashboard) UI. It discovers nodes and topics through DDS, shows the publishers, message types and subscribers for each topic, and displays the latest message when a topic is selected.

## Run on Linux

Load the same ROS 2 distribution and any message packages used by the system you want to inspect. Use the same `ROS_DOMAIN_ID` and compatible DDS discovery settings.

```bash
# Replace jazzy with your installed distribution.
source /opt/ros/jazzy/setup.bash
# If the ROS system uses custom message packages, source their workspace too.
# source /path/to/workspace/install/setup.bash
nix run .
```

The Viewer uses the Python interpreter beside the ROS 2 CLI when available on Linux and macOS, then falls back to `python3`. On Windows it uses `python`. That interpreter needs `rclpy` and `rosidl_runtime_py`. Set `ELASTIC_ROS_PYTHON` if your ROS environment provides a separate interpreter. For example, with a Nix ROS environment that exposes its Python under the ROS prefix:

```bash
ELASTIC_ROS_PYTHON="$(ros2 pkg prefix rclpy)/bin/python3" nix run .
```

Open **Add Widget → ROS 2 Topics**, then drag a topic and message type onto the dashboard. Each widget subscribes to its own topic, and saving the layout preserves those bindings. To show one field such as `orientation.x`, open the widget's **Edit Properties** and enter its field path. Open **ROS 2 Graph** in the bottom bar to inspect publisher and subscriber relationships.

The bridge creates subscriptions on the Viewer machine and requires no changes to the ROS programs. Large array fields show a preview of the first 32 items.

Tabs and list layouts from older Elastic layout files still load. Unsupported telemetry widgets are skipped. ROS 2 discovery runs in the desktop app.

See [CONTRIBUTING.md](CONTRIBUTING.md) for build and test commands.
