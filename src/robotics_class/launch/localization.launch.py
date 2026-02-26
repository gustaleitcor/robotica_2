import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():

    use_sim_time = LaunchConfiguration("use_sim_time")

    declare_use_sim_time_cmd = DeclareLaunchArgument(
        "use_sim_time", default_value="true", description="Use simulation time"
    )

    pkg_name = "robotics_class"
    pkg_share = get_package_share_directory(pkg_name)

    map_file = os.path.join(pkg_share, "maps", "class_map.yaml")
    amcl_params_file = os.path.join(pkg_share, "params", "amcl.yaml")

    map_server_node = Node(
        package="nav2_map_server",
        executable="map_server",
        name="map_server",
        output="screen",
        parameters=[{"use_sim_time": use_sim_time}, {"yaml_filename": map_file}],
    )

    amcl_node = Node(
        package="nav2_amcl",
        executable="amcl",
        name="amcl",
        output="screen",
        parameters=[amcl_params_file, {"use_sim_time": use_sim_time}],
    )

    lifecycle_manager_node = Node(
        package="nav2_lifecycle_manager",
        executable="lifecycle_manager",
        name="lifecycle_manager_localization",
        output="screen",
        parameters=[
            {"use_sim_time": use_sim_time},
            {"autostart": True},
            {"node_names": ["map_server", "amcl"]},
        ],
    )

    return LaunchDescription(
        [declare_use_sim_time_cmd, map_server_node, amcl_node, lifecycle_manager_node]
    )
