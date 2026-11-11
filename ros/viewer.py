"""Discover ROS 2 topics and echo selected messages over local JSON lines."""

import json
import math
import os
import queue
import sys
import threading
import time
from collections.abc import Mapping, Sequence

import rclpy
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from rosidl_runtime_py.utilities import get_message


def send(event, **fields):
    print(json.dumps({"event": event, **fields}, allow_nan=False), flush=True)


def node_path(name, namespace):
    return f"{namespace.rstrip('/')}/{name}"


def discover(node):
    own_name = node.get_fully_qualified_name()
    nodes = sorted({
        node_path(name, namespace)
        for name, namespace in node.get_node_names_and_namespaces()
        if node_path(name, namespace) != own_name
    })
    topics = []
    for name, types in sorted(node.get_topic_names_and_types()):
        publishers = [
            endpoint for endpoint in node.get_publishers_info_by_topic(name)
            if node_path(endpoint.node_name, endpoint.node_namespace) != own_name
        ]
        subscribers = [
            endpoint for endpoint in node.get_subscriptions_info_by_topic(name)
            if node_path(endpoint.node_name, endpoint.node_namespace) != own_name
        ]
        if publishers or subscribers:
            topics.append({
                "name": name,
                "types": sorted(set(types)),
                "publishers": sorted({
                    node_path(endpoint.node_name, endpoint.node_namespace)
                    for endpoint in publishers
                }),
                "subscribers": sorted({
                    node_path(endpoint.node_name, endpoint.node_namespace)
                    for endpoint in subscribers
                }),
            })
    return {"nodes": nodes, "topics": topics}


def preview(value):
    """Bound the display size for messages with large arrays or strings."""
    if hasattr(value, "get_fields_and_field_types"):
        return {
            name: preview(getattr(value, name))
            for name in value.get_fields_and_field_types()
        }
    if isinstance(value, str):
        return value if len(value) <= 4096 else value[:4096] + "…"
    if isinstance(value, Mapping):
        return {key: preview(item) for key, item in value.items()}
    if getattr(value, "ndim", None) == 0:
        return preview(value.item())
    if isinstance(value, Sequence) or hasattr(value, "tolist"):
        items = [preview(item) for item in value[:32]]
        if len(value) > 32:
            items.append(f"… ({len(value) - 32} more)")
        return items
    if isinstance(value, float) and not math.isfinite(value):
        return str(value)
    if isinstance(value, int) and abs(value) > 2**53 - 1:
        return str(value)
    return value


def read_commands(commands):
    try:
        for line in sys.stdin:
            try:
                command = json.loads(line)
                if isinstance(command, dict):
                    commands.put(command)
            except json.JSONDecodeError:
                continue
    finally:
        commands.put(None)


def run(node):
    commands = queue.SimpleQueue()
    threading.Thread(target=read_commands, args=(commands,), daemon=True).start()
    subscriptions = {}
    latest = {}
    last_graph = None
    next_graph = next_sample = 0.0

    send("ready", domain=os.environ.get("ROS_DOMAIN_ID", "0"))
    while rclpy.ok():
        while not commands.empty():
            command = commands.get()
            if command is None:
                return
            topic, type_name = command["topic"], command["type"]
            key = (topic, type_name)
            if command["action"] == "unsubscribe":
                subscription = subscriptions.pop(key, None)
                if subscription is not None:
                    node.destroy_subscription(subscription)
                latest.pop(key, None)
                continue
            if command["action"] != "subscribe" or key in subscriptions:
                continue
            try:
                publishers = [
                    endpoint for endpoint in node.get_publishers_info_by_topic(topic)
                    if endpoint.topic_type == type_name
                ]
                transient = bool(publishers) and all(
                    endpoint.qos_profile.durability == DurabilityPolicy.TRANSIENT_LOCAL
                    for endpoint in publishers
                )
                qos = QoSProfile(
                    depth=1,
                    reliability=(
                        ReliabilityPolicy.RELIABLE if transient and all(
                            endpoint.qos_profile.reliability == ReliabilityPolicy.RELIABLE
                            for endpoint in publishers
                        ) else ReliabilityPolicy.BEST_EFFORT
                    ),
                    durability=(
                        DurabilityPolicy.TRANSIENT_LOCAL if transient
                        else DurabilityPolicy.VOLATILE
                    ),
                )
                subscriptions[key] = node.create_subscription(
                    get_message(type_name),
                    topic,
                    lambda message, key=key: latest.__setitem__(key, message),
                    qos,
                )
            except Exception as error:
                send("topic_error", topic=topic, type=type_name, message=str(error))

        rclpy.spin_once(node, timeout_sec=0.05)
        now = time.monotonic()
        if now >= next_graph:
            graph = discover(node)
            if graph != last_graph:
                send("graph", **graph)
                last_graph = graph
            next_graph = now + 0.75
        if now >= next_sample:
            for (topic, type_name), message in latest.items():
                try:
                    send("sample", topic=topic, type=type_name, data=preview(message))
                except (TypeError, ValueError, IndexError) as error:
                    send("topic_error", topic=topic, type=type_name, message=str(error))
            latest.clear()
            next_sample = now + 0.1


def main():
    rclpy.init(args=[])
    try:
        node = rclpy.create_node(
            f"_elastic_viewer_{os.getpid()}",
            enable_rosout=False,
            start_parameter_services=False,
        )
        try:
            run(node)
        finally:
            node.destroy_node()
    finally:
        rclpy.try_shutdown()


if __name__ == "__main__":
    main()
